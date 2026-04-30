local ChapterFleet = class("ChapterFleet", import(".LevelCellData"))

ChapterFleet.DUTY_CLEANPATH = 1
ChapterFleet.DUTY_KILLBOSS = 2
ChapterFleet.DUTY_KILLALL = 3
ChapterFleet.DUTY_IDLE = 4

function ChapterFleet.Ctor(self, arg_1_1, arg_1_2)
	self:updateNpcShipList(arg_1_2)

	self.id = arg_1_1.id
	self.name = nil
	self.fleetId = arg_1_1.fleet_id
	self.fleetType = arg_1_1.fleetType

	if arg_1_1.fleet_id then
		local var_1_0 = getProxy(FleetProxy):getFleetById(arg_1_1.fleet_id)

		self.name = var_1_0 and var_1_0:GetName() or Fleet.DEFAULT_NAME[arg_1_1.fleet_id]
	end

	self.name = self.name or Fleet.DEFAULT_NAME[self.id]

	local var_1_1 = {}
	local var_1_2 = {}
	local var_1_3 = {}

	_.each(arg_1_1.box_strategy_list, function(arg_2_0)
		var_1_1[arg_2_0.id] = arg_2_0.count
	end)
	_.each(arg_1_1.ship_strategy_list, function(arg_3_0)
		var_1_2[arg_3_0.id] = arg_3_0.count
	end)
	_.each(arg_1_1.strategy_ids, function(arg_4_0)
		if pg.strategy_data_template[arg_4_0] then
			table.insert(var_1_3, arg_4_0)
		end
	end)

	if not _.detect(var_1_3, function(arg_5_0)
		return pg.strategy_data_template[arg_5_0].type == ChapterConst.StgTypeForm
	end) then
		table.insert(var_1_3, self:getFormationStg())
	end

	self.stgPicked = var_1_1
	self.stgUsed = var_1_2
	self.stgIds = var_1_3
	self.line = {
		row = arg_1_1.pos.row,
		column = arg_1_1.pos.column
	}
	self.step = arg_1_1.step_count
	self.restAmmo = arg_1_1.bullet
	self.startPos = {
		row = arg_1_1.start_pos.row,
		column = arg_1_1.start_pos.column
	}

	self:prepareShips(arg_1_1.ship_list)
	self:updateShips(arg_1_1.ship_list)

	self.baseSpeed = self:calcBaseSpeed()
	self.rotation = Quaternion.identity
	self.slowSpeedFactor = arg_1_1.move_step_down
	self.defeatEnemies = arg_1_1.kill_count or 0
	self.visibleLevel = arg_1_1.vision_lv or 0

	self:updateCommanders(arg_1_1.commander_list)

	self.skills = {}

	self:updateCommanderSkills()
end

function ChapterFleet.setup(arg_6_0, arg_6_1)
	arg_6_0.chapter = arg_6_1

	arg_6_0:UpdateVisible()
end

function ChapterFleet.UpdateVisible(arg_7_0)
	if arg_7_0:getFleetType() == FleetType.Normal then
		arg_7_0.chapter:UpdateCellsVisible(arg_7_0)
	end
end

function ChapterFleet.GetFogVisibleLV(self)
	local totalVisibleLevel = #pg.chapter_model_fog.all

	return self.visibleLevel, pg.chapter_model_fog[math.min(self.visibleLevel, totalVisibleLevel)]
end

-- 获取视野等级
function ChapterFleet.GetVisibleRange(self, line)
	line = line or self.line

	local visibleLevel, fogConfig = self:GetFogVisibleLV()

	return underscore.map(fogConfig.vision_range, function(range)
		local offsetRow, offsetCol = unpack(range)

		return {
			row = line.row + offsetRow,
			column = line.column + offsetCol
		}
	end)
end

function ChapterFleet.fetchShipVO(arg_11_0, arg_11_1)
	local var_11_0

	if arg_11_0.npcShipList[arg_11_1] then
		var_11_0 = Clone(arg_11_0.npcShipList[arg_11_1])
	else
		var_11_0 = getProxy(BayProxy):getShipById(arg_11_1)
	end

	if arg_11_0.staticsReady then
		var_11_0.triggers.TeamNumbers = arg_11_0.statics[var_11_0:getTeamType()].count
	end

	return var_11_0
end

function ChapterFleet.updateNpcShipList(arg_12_0, arg_12_1)
	arg_12_0.npcShipList = {}

	for iter_12_0, iter_12_1 in ipairs(arg_12_1) do
		arg_12_0.npcShipList[iter_12_1.id] = iter_12_1
	end
end

function ChapterFleet.GetLine(arg_13_0)
	return arg_13_0.line
end

function ChapterFleet.SetLine(arg_14_0, arg_14_1)
	arg_14_0.line = {
		row = arg_14_1.row,
		column = arg_14_1.column
	}

	arg_14_0:UpdateVisible()
end

function ChapterFleet.updateCommanders(arg_15_0, arg_15_1)
	arg_15_0.commanders = {}

	local var_15_0 = getProxy(CommanderProxy)

	for iter_15_0, iter_15_1 in ipairs(arg_15_1) do
		local var_15_1 = iter_15_1.id
		local var_15_2 = var_15_0:getCommanderById(var_15_1)

		if var_15_2 then
			arg_15_0.commanders[iter_15_1.pos] = var_15_2
		end
	end
end

function ChapterFleet.getCommanders(arg_16_0)
	return arg_16_0.commanders or {}
end

function ChapterFleet.prepareShips(arg_17_0, arg_17_1)
	arg_17_0.statics = {}
	arg_17_0.statics[TeamType.Vanguard] = {
		count = 0
	}
	arg_17_0.statics[TeamType.Main] = {
		count = 0
	}
	arg_17_0.statics[TeamType.Submarine] = {
		count = 0
	}

	_.each(arg_17_1 or {}, function(arg_18_0)
		local var_18_0 = arg_17_0:fetchShipVO(arg_18_0.id)

		if var_18_0 then
			local var_18_1 = arg_17_0.statics[var_18_0:getTeamType()]

			var_18_1.count = var_18_1.count + 1
		end
	end)

	arg_17_0.staticsReady = true
end

function ChapterFleet.updateShips(arg_19_0, arg_19_1)
	arg_19_0[TeamType.Vanguard] = {}
	arg_19_0[TeamType.Main] = {}
	arg_19_0[TeamType.Submarine] = {}
	arg_19_0.ships = {}

	_.each(arg_19_1 or {}, function(arg_20_0)
		local var_20_0 = arg_19_0:fetchShipVO(arg_20_0.id)

		if var_20_0 then
			var_20_0.hpRant = arg_20_0.hp_rant
			arg_19_0.ships[var_20_0.id] = var_20_0

			table.insert(arg_19_0[var_20_0:getTeamType()], var_20_0)
		end
	end)
	arg_19_0:ResortShips()
end

function ChapterFleet.ResortShips(arg_21_0)
	local var_21_0 = {
		TeamType.Vanguard,
		TeamType.Main,
		TeamType.Submarine
	}

	_.each(var_21_0, function(arg_22_0)
		local var_22_0 = arg_21_0[arg_22_0]
		local var_22_1 = {}

		table.Ipairs(var_22_0, function(arg_23_0, arg_23_1)
			var_22_1[arg_23_1] = arg_23_0
		end)
		table.sort(var_22_0, CompareFuncs({
			function(arg_24_0)
				return arg_24_0.hpRant > 0 and 0 or 1
			end,
			function(arg_25_0)
				return var_22_1[arg_25_0]
			end
		}))
	end)
end

function ChapterFleet.getTeamByName(arg_26_0, arg_26_1)
	local var_26_0 = {}
	local var_26_1 = arg_26_0[arg_26_1]

	for iter_26_0, iter_26_1 in ipairs(var_26_1) do
		table.insert(var_26_0, iter_26_1.id)
	end

	return var_26_0
end

function ChapterFleet.flushShips(arg_27_0)
	local var_27_0 = getProxy(FleetProxy):getFleetById(arg_27_0.fleetId)

	arg_27_0.name = var_27_0 and var_27_0.name ~= "" and var_27_0.name or Fleet.DEFAULT_NAME[arg_27_0.fleetId] or Fleet.DEFAULT_NAME[arg_27_0.id]

	local var_27_1 = _.keys(arg_27_0.ships)

	for iter_27_0, iter_27_1 in ipairs(var_27_1) do
		local var_27_2 = arg_27_0:fetchShipVO(iter_27_1)

		if var_27_2 then
			var_27_2.hpRant = arg_27_0.ships[iter_27_1].hpRant
		end

		arg_27_0.ships[iter_27_1] = var_27_2
	end

	local var_27_3 = {}

	_.each(arg_27_0[TeamType.Vanguard], function(arg_28_0)
		if arg_27_0.ships[arg_28_0.id] then
			table.insert(var_27_3, arg_27_0.ships[arg_28_0.id])
		end
	end)

	arg_27_0[TeamType.Vanguard] = var_27_3

	local var_27_4 = {}

	_.each(arg_27_0[TeamType.Main], function(arg_29_0)
		if arg_27_0.ships[arg_29_0.id] then
			table.insert(var_27_4, arg_27_0.ships[arg_29_0.id])
		end
	end)

	arg_27_0[TeamType.Main] = var_27_4

	local var_27_5 = {}

	_.each(arg_27_0[TeamType.Submarine], function(arg_30_0)
		if arg_27_0.ships[arg_30_0.id] then
			table.insert(var_27_5, arg_27_0.ships[arg_30_0.id])
		end
	end)

	arg_27_0[TeamType.Submarine] = var_27_5
end

function ChapterFleet.updateShipHp(arg_31_0, arg_31_1, arg_31_2)
	local var_31_0 = arg_31_0.ships[arg_31_1]

	if var_31_0 then
		var_31_0.hpChange = arg_31_2 - var_31_0.hpRant
		var_31_0.hpRant = arg_31_2

		arg_31_0:ResortShips()
	end
end

function ChapterFleet.getShip(arg_32_0, arg_32_1)
	return arg_32_0.ships[arg_32_1]
end

function ChapterFleet.getShips(self, includingDead)
	local ships = {}
	local fleetType = self:getFleetType()

	if fleetType == FleetType.Normal then
		table.insertto(ships, self:getShipsByTeam(TeamType.Main, includingDead))
		table.insertto(ships, self:getShipsByTeam(TeamType.Vanguard, includingDead))
	elseif fleetType == FleetType.Submarine then
		table.insertto(ships, self:getShipsByTeam(TeamType.Submarine, includingDead))
	elseif fleetType == FleetType.Support then
		for _, teamType in ipairs({
			TeamType.Main,
			TeamType.Vanguard,
			TeamType.Submarine
		}) do
			table.insertto(ships, self:getShipsByTeam(teamType, includingDead))
		end
	end

	return ships
end

-- 根据队伍类型获取舰船列表
-- 被BattleMediator.GenBattleData调用
function ChapterFleet.getShipsByTeam(self, teamType, includingDead)
	local allShips = {}
	local deadShips = {}

	for _, ship in ipairs(self[teamType]) do
		if ship.hpRant > 0 then
			table.insert(allShips, ship)
		else
			table.insert(deadShips, ship)
		end
	end

	if includingDead then
		table.insertto(allShips, deadShips)
	end

	return allShips
end

function ChapterFleet.containsShip(arg_35_0, arg_35_1)
	return arg_35_0.ships[arg_35_1] and true or false
end

function ChapterFleet.replaceShip(arg_36_0, arg_36_1, arg_36_2)
	errorMsg("ChapterFleet replaceShip function used")

	if arg_36_0.ships[arg_36_1] and not arg_36_0.ships[arg_36_2.id] then
		local var_36_0 = arg_36_0.ships[arg_36_1]
		local var_36_1 = arg_36_0:fetchShipVO(arg_36_2.id)

		if var_36_1 then
			if var_36_1:getTeamType() == var_36_0:getTeamType() then
				if not var_36_0:isSameKind(var_36_1) and arg_36_0:containsSameKind(var_36_1) then
					arg_36_0:removeShip(arg_36_1)
				else
					var_36_1.hpRant = arg_36_2.hp_rant
					arg_36_0.ships[arg_36_1] = nil
					arg_36_0.ships[var_36_1.id] = var_36_1

					local var_36_2 = arg_36_0[var_36_1:getTeamType()]

					for iter_36_0 = 1, #var_36_2 do
						if var_36_2[iter_36_0].id == arg_36_1 then
							var_36_2[iter_36_0] = var_36_1

							break
						end
					end
				end
			else
				arg_36_0:removeShip(arg_36_1)
			end
		end
	end
end

function ChapterFleet.addShip(arg_37_0, arg_37_1)
	errorMsg("ChapterFleet addShip function used")

	if not arg_37_0.ships[arg_37_1.id] then
		local var_37_0 = arg_37_0:fetchShipVO(arg_37_1.id)

		if var_37_0 then
			var_37_0.hpRant = arg_37_1.hp_rant

			local var_37_1 = arg_37_0[var_37_0:getTeamType()]

			if #var_37_1 < 3 then
				table.insert(var_37_1, var_37_0)

				arg_37_0.ships[var_37_0.id] = var_37_0

				arg_37_0:ResortShips()
			end
		end
	end
end

function ChapterFleet.removeShip(arg_38_0, arg_38_1)
	errorMsg("ChapterFleet removeShip function used")

	arg_38_0.ships[arg_38_1] = nil

	local var_38_0 = {
		TeamType.Vanguard,
		TeamType.Main,
		TeamType.Submarine
	}

	for iter_38_0 = 1, #var_38_0 do
		local var_38_1 = arg_38_0[var_38_0[iter_38_0]]

		for iter_38_1 = #var_38_1, 1, -1 do
			if var_38_1[iter_38_1].id == arg_38_1 then
				table.remove(var_38_1, iter_38_1)
			end
		end
	end
end

function ChapterFleet.switchShip(arg_39_0, arg_39_1, arg_39_2, arg_39_3)
	local var_39_0 = arg_39_0:getShipsByTeam(arg_39_1, false)
	local var_39_1 = var_39_0[arg_39_2].id
	local var_39_2 = var_39_0[arg_39_3].id
	local var_39_3
	local var_39_4
	local var_39_5
	local var_39_6

	for iter_39_0, iter_39_1 in pairs(arg_39_0.ships) do
		if iter_39_0 == var_39_1 then
			var_39_3 = iter_39_1:getTeamType()
			var_39_4 = table.indexof(arg_39_0[var_39_3], iter_39_1)
		end

		if iter_39_0 == var_39_2 then
			var_39_5 = iter_39_1:getTeamType()
			var_39_6 = table.indexof(arg_39_0[var_39_5], iter_39_1)
		end
	end

	assert(var_39_4 and var_39_6)

	if var_39_3 == var_39_5 and var_39_4 ~= var_39_6 then
		arg_39_0[var_39_3][var_39_4], arg_39_0[var_39_5][var_39_6] = arg_39_0[var_39_5][var_39_6], arg_39_0[var_39_3][var_39_4]
	end
end

function ChapterFleet.synchronousShipIndex(arg_40_0, arg_40_1)
	local var_40_0 = {
		TeamType.Vanguard,
		TeamType.Main,
		TeamType.Submarine
	}

	for iter_40_0, iter_40_1 in ipairs(var_40_0) do
		for iter_40_2 = 1, 3 do
			if arg_40_1[iter_40_1][iter_40_2] then
				local var_40_1 = arg_40_1[iter_40_1][iter_40_2].id

				arg_40_0[iter_40_1][iter_40_2] = arg_40_0.ships[var_40_1]
			else
				arg_40_0[iter_40_1][iter_40_2] = nil
			end
		end
	end
end

function ChapterFleet.isValid(arg_41_0)
	local var_41_0 = arg_41_0:getFleetType()

	if var_41_0 == FleetType.Normal then
		return _.any(arg_41_0[TeamType.Vanguard], function(arg_42_0)
			return arg_42_0.hpRant > 0
		end) and _.any(arg_41_0[TeamType.Main], function(arg_43_0)
			return arg_43_0.hpRant > 0
		end)
	elseif var_41_0 == FleetType.Submarine then
		return _.any(arg_41_0[TeamType.Submarine], function(arg_44_0)
			return arg_44_0.hpRant > 0
		end)
	elseif var_41_0 == FleetType.Support then
		return true
	end

	return false
end

function ChapterFleet.getCost(arg_45_0)
	local var_45_0 = {
		gold = 0,
		oil = 0
	}
	local var_45_1 = {
		gold = 0,
		oil = 0
	}
	local var_45_2 = arg_45_0:getShips(false)

	_.each(var_45_2, function(arg_46_0)
		var_45_0.oil = var_45_0.oil + arg_46_0:getStartBattleExpend()
		var_45_1.oil = var_45_1.oil + arg_46_0:getEndBattleExpend()
	end)

	return var_45_0, var_45_1
end

-- TODO
function ChapterFleet.getInvestSums(arg_47_0, arg_47_1)
	local function var_47_0(arg_48_0, arg_48_1)
		local var_48_0 = arg_48_1:getProperties(arg_47_0:getCommanders())

		return arg_48_0 + var_48_0[AttributeType.Air] + var_48_0[AttributeType.Dodge]
	end

	local var_47_1 = _.reduce(arg_47_0:getShips(arg_47_1), 0, var_47_0)

	return math.pow(var_47_1, 0.6666666666666666)
end

function ChapterFleet.getDodgeSums(arg_49_0)
	local function var_49_0(arg_50_0, arg_50_1)
		return arg_50_0 + arg_50_1:getProperties(arg_49_0:getCommanders())[AttributeType.Dodge]
	end

	local var_49_1 = _.reduce(arg_49_0:getShips(false), 0, var_49_0)

	return math.pow(var_49_1, 0.6666666666666666)
end

function ChapterFleet.getAntiAircraftSums(arg_51_0)
	local function var_51_0(arg_52_0, arg_52_1)
		return arg_52_0 + arg_52_1:getProperties(arg_51_0:getCommanders())[AttributeType.AntiAircraft]
	end

	return (_.reduce(arg_51_0:getShips(false), 0, var_51_0))
end

function ChapterFleet.getAirSums(arg_53_0, arg_53_1)
	local function var_53_0(arg_54_0, arg_54_1)
		return arg_54_0 + arg_54_1:getProperties(arg_53_0:getCommanders())[AttributeType.Air]
	end

	return (_.reduce(arg_53_0:getShips(arg_53_1), 0, var_53_0))
end

function ChapterFleet.getShipAmmo(arg_55_0)
	local var_55_0 = 0

	if arg_55_0:getFleetType() == FleetType.Normal then
		for iter_55_0, iter_55_1 in pairs(arg_55_0.ships) do
			var_55_0 = math.max(var_55_0, iter_55_1:getShipAmmo())
		end
	elseif arg_55_0:getFleetType() == FleetType.Submarine then
		for iter_55_2, iter_55_3 in pairs(arg_55_0.ships) do
			var_55_0 = var_55_0 + iter_55_3:getShipAmmo()
		end
	elseif arg_55_0:getFleetType() == FleetType.Support then
		var_55_0 = 0
	end

	return var_55_0
end

function ChapterFleet.clearShipHpChange(arg_56_0)
	for iter_56_0, iter_56_1 in pairs(arg_56_0.ships) do
		arg_56_0.ships[iter_56_1.id].hpChange = 0
	end
end

function ChapterFleet.getEquipAmbushRateReduce(arg_57_0)
	local var_57_0 = 0

	for iter_57_0, iter_57_1 in pairs(arg_57_0.ships) do
		for iter_57_2, iter_57_3 in pairs(iter_57_1:getActiveEquipments()) do
			if iter_57_3 then
				var_57_0 = math.max(var_57_0, iter_57_3:getConfig("equip_parameters").ambush_extra or 0)
			end
		end
	end

	return var_57_0 / 10000
end

function ChapterFleet.getEquipDodgeRateUp(arg_58_0)
	local var_58_0 = 0

	for iter_58_0, iter_58_1 in pairs(arg_58_0.ships) do
		for iter_58_2, iter_58_3 in pairs(iter_58_1:getActiveEquipments()) do
			if iter_58_3 then
				var_58_0 = math.max(var_58_0, iter_58_3:getConfig("equip_parameters").avoid_extra or 0)
			end
		end
	end

	return var_58_0 / 10000
end

function ChapterFleet.isFormationDiffWith(arg_59_0, arg_59_1)
	local var_59_0 = {
		TeamType.Main,
		TeamType.Vanguard,
		TeamType.Submarine
	}

	for iter_59_0, iter_59_1 in ipairs(var_59_0) do
		local var_59_1 = arg_59_0[iter_59_1]
		local var_59_2 = arg_59_1[iter_59_1]

		for iter_59_2 = 1, math.max(#var_59_1, #var_59_2) do
			if var_59_1[iter_59_2] ~= var_59_2[iter_59_2] and (var_59_1[iter_59_2] == nil or var_59_2[iter_59_2] == nil or var_59_1[iter_59_2].id ~= var_59_2[iter_59_2].id) then
				return true
			end
		end
	end

	return false
end

function ChapterFleet.getShipIds(arg_60_0)
	local var_60_0 = {}
	local var_60_1 = arg_60_0:getFleetType()

	if var_60_1 == FleetType.Normal then
		_.each(arg_60_0[TeamType.Main], function(arg_61_0)
			table.insert(var_60_0, arg_61_0.id)
		end)
		_.each(arg_60_0[TeamType.Vanguard], function(arg_62_0)
			table.insert(var_60_0, arg_62_0.id)
		end)
	elseif var_60_1 == FleetType.Submarine then
		_.each(arg_60_0[TeamType.Submarine], function(arg_63_0)
			table.insert(var_60_0, arg_63_0.id)
		end)
	elseif var_60_1 == FleetType.Support then
		for iter_60_0, iter_60_1 in pairs(arg_60_0.ships) do
			table.insert(var_60_0, iter_60_1.id)
		end
	end

	return var_60_0
end

function ChapterFleet.containsSameKind(arg_64_0, arg_64_1)
	return arg_64_1 and _.any(_.values(arg_64_0.ships), function(arg_65_0)
		return arg_64_1:isSameKind(arg_65_0)
	end)
end

function ChapterFleet.increaseSlowSpeedFactor(arg_66_0)
	arg_66_0.slowSpeedFactor = arg_66_0.slowSpeedFactor + 1
end

-- LevelStageView.ClickGridCellNormal调用
function ChapterFleet.getSpeed(self)
	local skillMoveSpeed = self:triggerSkill(FleetSkill.TypeMoveSpeed) or 0

	return math.max(self.baseSpeed + skillMoveSpeed - self.slowSpeedFactor, 1)
end

-- ChapterFleet.Ctor调用
function ChapterFleet.calcBaseSpeed(self)
	local ships = self:getShips(true)
	local speedFactor = _.reduce(ships, 0, function(speedSum, ship)
		return speedSum + ship:getProperties()[AttributeType.Speed]
	end) / #ships * (1 - 0.02 * (#ships - 1))
	local moveSpeed1
	local moveSpeed2
	local fleetType = self:getFleetType()

	if fleetType == FleetType.Normal then
		-- chapter_move_speed_1 = 25
		moveSpeed1 = pg.gameset.chapter_move_speed_1.key_value
		-- chapter_move_speed_2 = 36
		moveSpeed2 = pg.gameset.chapter_move_speed_2.key_value
	elseif fleetType == FleetType.Submarine then
		-- submarine_move_speed_1 = 10
		moveSpeed1 = pg.gameset.submarine_move_speed_1.key_value
		-- submarine_move_speed_2 = 25
		moveSpeed2 = pg.gameset.submarine_move_speed_2.key_value
	elseif fleetType == FleetType.Support then
		moveSpeed1 = pg.gameset.chapter_move_speed_1.key_value
		moveSpeed2 = pg.gameset.chapter_move_speed_2.key_value
	end

	if speedFactor <= moveSpeed1 then
		return 2
	elseif moveSpeed2 < speedFactor then
		return 4
	else
		return 3
	end
end

function ChapterFleet.getDefeatCount(arg_70_0)
	return arg_70_0.defeatEnemies
end

function ChapterFleet.getStrategies(arg_71_0)
	local var_71_0 = arg_71_0:getOwnStrategies()

	for iter_71_0, iter_71_1 in pairs(arg_71_0.stgPicked) do
		var_71_0[iter_71_0] = (var_71_0[iter_71_0] or 0) + iter_71_1
	end

	for iter_71_2, iter_71_3 in pairs(arg_71_0.stgUsed) do
		if var_71_0[iter_71_2] then
			var_71_0[iter_71_2] = math.max(0, var_71_0[iter_71_2] - iter_71_3)
		end
	end

	for iter_71_4, iter_71_5 in pairs(ChapterConst.StrategyPresents) do
		var_71_0[iter_71_5] = var_71_0[iter_71_5] or 0
	end

	local var_71_1 = {}

	for iter_71_6, iter_71_7 in pairs(var_71_0) do
		table.insert(var_71_1, {
			id = iter_71_6,
			count = iter_71_7
		})
	end

	return _.sort(var_71_1, function(arg_72_0, arg_72_1)
		return arg_72_0.id < arg_72_1.id
	end)
end

function ChapterFleet.getOwnStrategies(arg_73_0)
	local var_73_0 = {}
	local var_73_1 = arg_73_0:getShips(true)

	_.each(var_73_1, function(arg_74_0)
		local var_74_0 = arg_74_0:getConfig("strategy_list")

		_.each(var_74_0, function(arg_75_0)
			var_73_0[arg_75_0[1]] = (var_73_0[arg_75_0[1]] or 0) + arg_75_0[2]
		end)
	end)

	local var_73_2 = arg_73_0:triggerSkill(FleetSkill.TypeStrategy)

	if var_73_2 then
		_.each(var_73_2, function(arg_76_0)
			var_73_0[arg_76_0[1]] = (var_73_0[arg_76_0[1]] or 0) + arg_76_0[2]
		end)
	end

	return var_73_0
end

function ChapterFleet.achievedStrategy(arg_77_0, arg_77_1, arg_77_2)
	arg_77_0.stgPicked[arg_77_1] = (arg_77_0.stgPicked[arg_77_1] or 0) + arg_77_2
end

function ChapterFleet.consumeOneStrategy(arg_78_0, arg_78_1)
	local var_78_0 = arg_78_0:getOwnStrategies()

	if var_78_0[arg_78_1] and var_78_0[arg_78_1] > 0 then
		local var_78_1 = arg_78_0.stgUsed

		var_78_1[arg_78_1] = (var_78_1[arg_78_1] or 0) + 1
	else
		local var_78_2 = arg_78_0.stgPicked

		if var_78_2[arg_78_1] then
			var_78_2[arg_78_1] = math.max(0, var_78_2[arg_78_1] - 1)
		end
	end
end

function ChapterFleet.GetStrategyCount(arg_79_0, arg_79_1)
	local var_79_0 = arg_79_0:getStrategies()
	local var_79_1 = _.detect(var_79_0, function(arg_80_0)
		return arg_80_0.id == arg_79_1
	end)

	return var_79_1 and var_79_1.count or 0
end

function ChapterFleet.getFormationStg(arg_81_0)
	return PlayerPrefs.GetInt("team_formation_" .. arg_81_0.id, 1)
end

function ChapterFleet.canUseStrategy(arg_82_0, arg_82_1)
	local var_82_0 = pg.strategy_data_template[arg_82_1.id]

	if var_82_0.type == ChapterConst.StgTypeForm then
		if arg_82_0:getFormationStg() == var_82_0.id then
			pg.TipsMgr.GetInstance():ShowTips(i18n("level_scene_formation_active_already"))

			return false
		end
	elseif var_82_0.type == ChapterConst.StgTypeConsume or var_82_0.type == ChapterConst.StgTypeBindSupportConsume then
		if arg_82_1.count <= 0 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("level_scene_not_enough"))

			return false
		end

		if var_82_0.id == ChapterConst.StrategyRepair and _.all(arg_82_0:getShips(true), function(arg_83_0)
			return arg_83_0.hpRant == 0 or arg_83_0.hpRant == 10000
		end) then
			pg.TipsMgr.GetInstance():ShowTips(i18n("level_scene_full_hp"))

			return false
		end
	end

	return true
end

function ChapterFleet.getNextStgUser(arg_84_0, arg_84_1)
	return arg_84_0.id
end

function ChapterFleet.GetStatusStrategy(arg_85_0)
	return arg_85_0.stgIds
end

function ChapterFleet.getFleetType(arg_86_0)
	assert(arg_86_0.fleetType)

	return arg_86_0.fleetType
end

function ChapterFleet.canClearTorpedo(arg_87_0)
	local var_87_0 = arg_87_0:getShipsByTeam(TeamType.Vanguard, true)

	return _.any(var_87_0, function(arg_88_0)
		return ShipType.IsTypeQuZhu(arg_88_0:getShipType())
	end)
end

function ChapterFleet.getHuntingRange(self, pos)
	if self:getFleetType() ~= FleetType.Submarine then
		assert(false)

		return {}
	end

	local position = pos or self.startPos
	-- 用潜艇舰队的旗舰计算狩猎范围
	local submarineFlagship = self:getShipsByTeam(TeamType.Submarine, true)[1]
	local extraHuntingLv = self:triggerSkill(FleetSkill.TypeHuntingLv) or 0
	local huntingRangeTable = submarineFlagship:getHuntingRange(submarineFlagship:getHuntingLv() + extraHuntingLv)

	return (_.map(huntingRangeTable, function(grid)
		return {
			row = position.row + grid[1],
			column = position.column + grid[2]
		}
	end))
end

function ChapterFleet.inHuntingRange(arg_91_0, arg_91_1, arg_91_2)
	return _.any(arg_91_0:getHuntingRange(), function(arg_92_0)
		return arg_92_0.row == arg_91_1 and arg_92_0.column == arg_91_2
	end)
end

function ChapterFleet.getSummonCost(arg_93_0)
	local var_93_0 = arg_93_0:getShips(false)

	return _.reduce(var_93_0, 0, function(arg_94_0, arg_94_1)
		return arg_94_0 + arg_94_1:getEndBattleExpend()
	end)
end

function ChapterFleet.getMapAura(arg_95_0)
	local var_95_0 = {}

	for iter_95_0, iter_95_1 in pairs(arg_95_0.ships) do
		local var_95_1 = iter_95_1:getMapAuras()

		for iter_95_2, iter_95_3 in ipairs(var_95_1) do
			table.insert(var_95_0, iter_95_3)
		end
	end

	return var_95_0
end

-- 获取该舰队提供的跨队增益
-- 被ChapterProxy.GetChapterAidBuffs调用
function ChapterFleet.getMapAid(self)
	local fleetAids = {}

	for _, ship in pairs(self.ships) do
		local shipAids = ship:getMapAids()

		for _, shipAid in ipairs(shipAids) do
			local shipAidList = fleetAids[ship] or {}

			table.insert(shipAidList, shipAid)

			fleetAids[ship] = shipAidList
		end
	end

	return fleetAids
end

function ChapterFleet.updateCommanderSkills(arg_97_0)
	local var_97_0 = arg_97_0:getCommanders()

	for iter_97_0, iter_97_1 in pairs(var_97_0) do
		_.each(iter_97_1:getSkills(), function(arg_98_0)
			_.each(arg_98_0:getTacticSkill(), function(arg_99_0)
				table.insert(arg_97_0.skills, FleetSkill.New(FleetSkill.SystemCommanderNeko, arg_99_0))
			end)
		end)
	end
end

function ChapterFleet.getSkills(arg_100_0)
	return arg_100_0.skills
end

function ChapterFleet.getSkill(arg_101_0, arg_101_1)
	return _.detect(arg_101_0:getSkills(), function(arg_102_0)
		return arg_102_0.id == arg_101_1
	end)
end

function ChapterFleet.findSkills(arg_103_0, arg_103_1)
	return _.filter(arg_103_0:getSkills(), function(arg_104_0)
		return arg_104_0:GetType() == arg_103_1
	end)
end

function ChapterFleet.triggerSkill(self, skillType)
	-- ChapterLevelData.triggerSkill
	return self.chapter:triggerSkill(self, skillType)
end

function ChapterFleet.findCommanderBySkillId(arg_106_0, arg_106_1)
	local var_106_0 = arg_106_0:getCommanders()

	for iter_106_0, iter_106_1 in pairs(var_106_0) do
		if _.any(iter_106_1:getSkills(), function(arg_107_0)
			return _.any(arg_107_0:getTacticSkill(), function(arg_108_0)
				return arg_108_0 == arg_106_1
			end)
		end) then
			return iter_106_1
		end
	end
end

function ChapterFleet.getFleetAirDominanceValue(arg_109_0)
	local var_109_0 = 0

	for iter_109_0, iter_109_1 in ipairs(arg_109_0:getShips(false)) do
		var_109_0 = var_109_0 + calcAirDominanceValue(iter_109_1, arg_109_0:getCommanders())
	end

	return var_109_0
end

function ChapterFleet.StaticTransformChapterFleet2Fleet(arg_110_0, arg_110_1)
	local var_110_0 = _.pluck(arg_110_0:getShipsByTeam(TeamType.Vanguard, arg_110_1), "id")

	table.insertto(var_110_0, _.pluck(arg_110_0:getShipsByTeam(TeamType.Main, arg_110_1), "id"))

	local var_110_1 = {}

	for iter_110_0, iter_110_1 in pairs(arg_110_0.commanders) do
		table.insert(var_110_1, {
			pos = iter_110_0,
			id = iter_110_1 and iter_110_1.id
		})
	end

	return TypedFleet.New({
		fleetType = FleetType.Normal,
		ship_list = var_110_0,
		commanders = var_110_1
	})
end

return ChapterFleet
