local Fleet = class("Fleet", import(".BaseVO"))

Fleet.C_TEAM_NAME = {
	vanguard = i18n("word_vanguard_fleet"),
	main = i18n("word_main_fleet"),
	submarine = i18n("word_sub_fleet")
}
Fleet.DEFAULT_NAME = {
	i18n("ship_formationUI_fleetName1"),
	i18n("ship_formationUI_fleetName2"),
	i18n("ship_formationUI_fleetName3"),
	i18n("ship_formationUI_fleetName4"),
	i18n("ship_formationUI_fleetName5"),
	i18n("ship_formationUI_fleetName6"),
	[11] = i18n("ship_formationUI_fleetName11"),
	[12] = i18n("ship_formationUI_fleetName12"),
	[101] = i18n("ship_formationUI_exercise_fleetName"),
	[102] = i18n("ship_formationUI_fleetName_challenge"),
	[103] = i18n("ship_formationUI_fleetName_challenge_sub")
}
Fleet.DEFAULT_NAME_FOR_DOCKYARD = {
	i18n("ship_formationUI_fleetName1"),
	i18n("ship_formationUI_fleetName2"),
	i18n("ship_formationUI_fleetName3"),
	i18n("ship_formationUI_fleetName4"),
	i18n("ship_formationUI_fleetName5"),
	i18n("ship_formationUI_fleetName6"),
	[11] = i18n("ship_formationUI_fleetName1"),
	[12] = i18n("ship_formationUI_fleetName2"),
	[101] = i18n("ship_formationUI_exercise_fleetName"),
	[102] = i18n("ship_formationUI_fleetName_challenge"),
	[103] = i18n("ship_formationUI_fleetName_challenge_sub")
}
Fleet.DEFAULT_NAME_BOSS_ACT = {
	i18n("ship_formationUI_fleetName_easy"),
	i18n("ship_formationUI_fleetName_normal"),
	i18n("ship_formationUI_fleetName_hard"),
	i18n("ship_formationUI_fleetName_extra"),
	i18n("ship_formationUI_fleetName_sp"),
	[11] = i18n("ship_formationUI_fleetName_easy_ss"),
	[12] = i18n("ship_formationUI_fleetName_normal_ss"),
	[13] = i18n("ship_formationUI_fleetName_hard_ss"),
	[14] = i18n("ship_formationUI_fleetName_extra_ss"),
	[15] = i18n("ship_formationUI_fleetName_sp_ss")
}
Fleet.DEFAULT_NAME_BOSS_SINGLE_ACT = {
	i18n("ship_formationUI_fleetName_easy"),
	i18n("ship_formationUI_fleetName_normal"),
	i18n("ship_formationUI_fleetName_hard"),
	i18n("ship_formationUI_fleetName_sp"),
	i18n("ship_formationUI_fleetName_extra"),
	[11] = i18n("ship_formationUI_fleetName_easy_ss"),
	[12] = i18n("ship_formationUI_fleetName_normal_ss"),
	[13] = i18n("ship_formationUI_fleetName_hard_ss"),
	[14] = i18n("ship_formationUI_fleetName_sp_ss"),
	[15] = i18n("ship_formationUI_fleetName_extra_ss")
}
Fleet.DEFAULT_NAME_BOSS_SINGLE_VARIABLE_ACT = {
	i18n("ship_formationUI_fleetName_1"),
	i18n("ship_formationUI_fleetName_2"),
	i18n("ship_formationUI_fleetName_3"),
	i18n("ship_formationUI_fleetName_4"),
	i18n("ship_formationUI_fleetName_5"),
	i18n("ship_formationUI_fleetName_6"),
	i18n("ship_formationUI_fleetName_7"),
	i18n("ship_formationUI_fleetName_8"),
	i18n("ship_formationUI_fleetName_9"),
	i18n("ship_formationUI_fleetName_10"),
	i18n("ship_formationUI_fleetName_11"),
	i18n("ship_formationUI_fleetName_12"),
	(i18n("ship_formationUI_fleetName_13"))
}
Fleet.DEFAULT_ELITE_NAME = {
	i18n("ship_formationUI_fleetName1"),
	i18n("ship_formationUI_fleetName2"),
	i18n("ship_formationUI_fleetName11"),
	(i18n("ship_formationUI_fleetName13"))
}
Fleet.REGULAR_FLEET_ID = 1
Fleet.REGULAR_FLEET_NUMS = 6
Fleet.SUBMARINE_FLEET_ID = 11
Fleet.SUBMARINE_FLEET_NUMS = 4
Fleet.MEGA_SUBMARINE_FLEET_OFFSET = 100

function Fleet.Ctor(arg_1_0, arg_1_1)
	arg_1_0.id = arg_1_1.id
	arg_1_0.name = arg_1_1.name or ""
	arg_1_0.defaultName = Fleet.DEFAULT_NAME[arg_1_0.id]

	arg_1_0:updateShips(arg_1_1.ship_list)

	arg_1_0.commanderIds = {}

	for iter_1_0, iter_1_1 in ipairs(arg_1_1.commanders or {}) do
		arg_1_0.commanderIds[iter_1_1.pos] = iter_1_1.id
	end

	arg_1_0.skills = {}

	arg_1_0:updateCommanderSkills()
end

function Fleet.SeparateOut(arg_2_0)
	return {
		id = arg_2_0.id,
		name = arg_2_0.name,
		ship_list = underscore.to_array(arg_2_0.ships),
		commanders = underscore(arg_2_0.commanderIds):chain():keys():map(function(arg_3_0)
			return {
				pos = arg_3_0,
				id = arg_2_0.commanderIds[arg_3_0]
			}
		end):value()
	}
end

function Fleet.isUnlock(arg_4_0)
	local var_4_0 = {
		nil,
		nil,
		404,
		504,
		604,
		704
	}
	local var_4_1 = getProxy(ChapterProxy)
	local var_4_2 = var_4_0[arg_4_0.id]

	if var_4_2 then
		local var_4_3 = var_4_1:getChapterById(var_4_2)

		return var_4_3 and var_4_3:isClear(), i18n("formation_chapter_lock", string.sub(tostring(var_4_2), 1, 1), arg_4_0.id)
	end

	return true
end

function Fleet.containShip(arg_3_0, arg_3_1)
	return table.contains(arg_3_0.ships, arg_3_1.id)
end

function Fleet.isFirstFleet(arg_4_0)
	return arg_4_0.id == Fleet.REGULAR_FLEET_ID
end

function Fleet.outputCommanders(arg_5_0)
	local var_5_0 = {}

	for iter_7_0, iter_7_1 in pairs(arg_7_0.commanderIds) do
		assert(iter_7_1, "id is nil")
		table.insert(var_7_0, {
			pos = iter_7_0,
			id = iter_7_1
		})
	end

	return var_7_0
end

function Fleet.clearCommanders(arg_8_0)
	arg_8_0.commanderIds = {}

	arg_8_0:updateCommanderSkills()
end

function Fleet.getCommanders(arg_6_0)
	local var_6_0 = {}

	for iter_9_0, iter_9_1 in pairs(arg_9_0.commanderIds) do
		var_9_0[iter_9_0] = getProxy(CommanderProxy):getCommanderById(iter_9_1)
	end

	return var_9_0
end

function Fleet.getCommanderByPos(arg_7_0, arg_7_1)
	return arg_7_0:getCommanders()[arg_7_1]
end

function Fleet.updateCommanderByPos(arg_8_0, arg_8_1, arg_8_2)
	if arg_8_2 then
		arg_8_0.commanderIds[arg_8_1] = arg_8_2.id
	else
		arg_11_0.commanderIds[arg_11_1] = nil
	end

	arg_11_0:updateCommanderSkills()
end

function Fleet.getCommandersAddition(arg_9_0)
	local var_9_0 = {}

	for iter_12_0, iter_12_1 in pairs(CommanderConst.PROPERTIES) do
		local var_12_1 = 0

		for iter_12_2, iter_12_3 in pairs(arg_12_0:getCommanders()) do
			var_12_1 = var_12_1 + iter_12_3:getAbilitysAddition()[iter_12_1]
		end

		if var_12_1 > 0 then
			table.insert(var_12_0, {
				attrName = iter_12_1,
				value = var_12_1
			})
		end
	end

	return var_12_0
end

function Fleet.getCommandersTalentDesc(arg_10_0)
	local var_10_0 = {}

	for iter_13_0, iter_13_1 in pairs(arg_13_0:getCommanders()) do
		local var_13_1 = iter_13_1:getTalentsDesc()

		for iter_13_2, iter_13_3 in pairs(var_13_1) do
			if var_13_0[iter_13_2] then
				var_13_0[iter_13_2].value = var_13_0[iter_13_2].value + iter_13_3.value
			else
				var_13_0[iter_13_2] = {
					name = iter_13_2,
					value = iter_13_3.value,
					type = iter_13_3.type
				}
			end
		end
	end

	return var_13_0
end

function Fleet.findCommanderBySkillId(arg_11_0, arg_11_1)
	local var_11_0 = arg_11_0:getCommanders()

	for iter_14_0, iter_14_1 in pairs(var_14_0) do
		if _.any(iter_14_1:getSkills(), function(arg_15_0)
			return _.any(arg_15_0:getTacticSkill(), function(arg_16_0)
				return arg_16_0 == arg_14_1
			end)
		end) then
			return iter_14_1
		end
	end
end

function Fleet.updateCommanderSkills(arg_14_0)
	local var_14_0 = #arg_14_0.skills

	while var_17_0 > 0 do
		local var_17_1 = arg_17_0.skills[var_17_0]

		if not arg_17_0:findCommanderBySkillId(var_17_1.id) and var_17_1:GetSystem() == FleetSkill.SystemCommanderNeko then
			table.remove(arg_17_0.skills, var_17_0)
		end

		var_17_0 = var_17_0 - 1
	end

	local var_17_2 = arg_17_0:getCommanders()

	for iter_17_0, iter_17_1 in pairs(var_17_2) do
		for iter_17_2, iter_17_3 in ipairs(iter_17_1:getSkills()) do
			for iter_17_4, iter_17_5 in ipairs(iter_17_3:getTacticSkill()) do
				table.insert(arg_17_0.skills, FleetSkill.New(FleetSkill.SystemCommanderNeko, iter_17_5))
			end
		end
	end
end

function Fleet.buildBattleBuffList(arg_15_0)
	local var_15_0 = {}
	local var_15_1, var_15_2 = FleetSkill.triggerSkill(arg_15_0, FleetSkill.TypeBattleBuff)

	if var_18_1 and #var_18_1 > 0 then
		local var_18_3 = {}

		for iter_18_0, iter_18_1 in ipairs(var_18_1) do
			local var_18_4 = var_18_2[iter_18_0]
			local var_18_5 = arg_18_0:findCommanderBySkillId(var_18_4.id)

			var_18_3[var_18_5] = var_18_3[var_18_5] or {}

			table.insert(var_18_3[var_18_5], iter_18_1)
		end

		for iter_18_2, iter_18_3 in pairs(var_18_3) do
			table.insert(var_18_0, {
				iter_18_2,
				iter_18_3
			})
		end
	end

	local var_18_6 = arg_18_0:getCommanders()

	for iter_18_4, iter_18_5 in pairs(var_18_6) do
		local var_18_7 = iter_18_5:getTalents()

		for iter_18_6, iter_18_7 in ipairs(var_18_7) do
			local var_18_8 = iter_18_7:getBuffsAddition()

			if #var_18_8 > 0 then
				local var_18_9

				for iter_18_8, iter_18_9 in ipairs(var_18_0) do
					if iter_18_9[1] == iter_18_5 then
						var_18_9 = iter_18_9[2]

						break
					end
				end

				if not var_18_9 then
					var_18_9 = {}

					table.insert(var_18_0, {
						iter_18_5,
						var_18_9
					})
				end

				for iter_18_10, iter_18_11 in ipairs(var_18_8) do
					table.insert(var_18_9, iter_18_11)
				end
			end
		end
	end

	return var_18_0
end

function Fleet.getSkills(arg_16_0)
	return arg_16_0.skills
end

function Fleet.getShipIds(arg_17_0)
	local var_17_0 = {}
	local var_17_1 = {
		arg_17_0.mainShips,
		arg_17_0.vanguardShips,
		arg_17_0.subShips
	}

	for iter_20_0, iter_20_1 in ipairs(var_20_1) do
		for iter_20_2, iter_20_3 in ipairs(iter_20_1) do
			table.insert(var_20_0, iter_20_3)
		end
	end

	return var_20_0
end

function Fleet.GetRawShipIds(arg_18_0)
	return arg_18_0.ships
end

function Fleet.GetRawCommanderIds(arg_19_0)
	return arg_19_0.commanderIds
end

function Fleet.findSkills(arg_20_0, arg_20_1)
	return _.filter(arg_20_0:getSkills(), function(arg_21_0)
		return arg_21_0:GetType() == arg_20_1
	end)
end

function Fleet.updateShips(arg_22_0, arg_22_1)
	arg_22_0.ships = {}
	arg_22_0.vanguardShips = {}
	arg_22_0.mainShips = {}
	arg_22_0.subShips = {}

	local var_25_0 = getProxy(BayProxy)

	for iter_25_0, iter_25_1 in ipairs(arg_25_1) do
		local var_25_1 = var_25_0:getShipById(iter_25_1)

		if var_25_1 then
			arg_25_0:insertShip(var_25_1, nil, var_25_1:getTeamType())
		end
	end
end

function Fleet.switchShip(arg_23_0, arg_23_1, arg_23_2, arg_23_3)
	local var_23_0 = arg_23_0:getTeamByName(arg_23_1)

	var_26_0[arg_26_2], var_26_0[arg_26_3] = var_26_0[arg_26_3], var_26_0[arg_26_2]
end

function Fleet.getShipPos(arg_24_0, arg_24_1)
	if not arg_24_1 then
		return
	end

	local var_27_0 = arg_27_1:getTeamType()
	local var_27_1 = arg_27_0:getTeamByName(var_27_0)

	return table.indexof(var_27_1, arg_27_1.id) or -1, var_27_0
end

function Fleet.getTeamByName(arg_25_0, arg_25_1)
	if arg_25_1 == TeamType.Vanguard then
		return arg_25_0.vanguardShips
	elseif arg_25_1 == TeamType.Main then
		return arg_25_0.mainShips
	elseif arg_25_1 == TeamType.Submarine then
		return arg_25_0.subShips
	end
end

function Fleet.CanInsertShip(arg_26_0, arg_26_1, arg_26_2)
	if arg_26_0:isFull() or arg_26_0:containShip(arg_26_1) or not arg_26_1:isAvaiable() or #arg_26_0:getTeamByName(arg_26_2) >= TeamType.GetTeamShipMax(arg_26_2) then
		return false
	end

	return true
end

function Fleet.insertShip(arg_27_0, arg_27_1, arg_27_2, arg_27_3)
	if not arg_27_0:CanInsertShip(arg_27_1, arg_27_3) then
		errorMsg("fleet insert error")
		pg.TipsMgr.GetInstance():ShowTips("fleet insert error")
	else
		local var_30_0 = arg_30_0:getTeamByName(arg_30_3)

		arg_30_2 = arg_30_2 or #var_30_0 + 1

		local var_30_1 = arg_30_3 == TeamType.Main and #arg_30_0.vanguardShips or 0

		table.insert(var_30_0, arg_30_2, arg_30_1.id)
		table.insert(arg_30_0.ships, var_30_1 + arg_30_2, arg_30_1.id)
	end
end

function Fleet.canRemove(arg_28_0, arg_28_1)
	local var_28_0, var_28_1 = arg_28_0:getShipPos(arg_28_1)

	if var_31_0 > 0 and #(arg_31_0:getTeamByName(var_31_1) or {}) == 1 and arg_31_0:isFirstFleet() then
		return false
	else
		return true
	end
end

function Fleet.isRegularFleet(arg_29_0)
	return arg_29_0.id >= Fleet.SUBMARINE_FLEET_ID and arg_29_0.id < Fleet.SUBMARINE_FLEET_ID + Fleet.SUBMARINE_FLEET_NUMS or arg_29_0.id >= Fleet.REGULAR_FLEET_ID and arg_29_0.id < Fleet.REGULAR_FLEET_ID + Fleet.REGULAR_FLEET_NUMS
end

function Fleet.isSubmarineFleet(arg_30_0)
	return arg_30_0.id >= Fleet.SUBMARINE_FLEET_ID and arg_30_0.id < Fleet.SUBMARINE_FLEET_ID + Fleet.SUBMARINE_FLEET_NUMS
end

function Fleet.isPVPFleet(arg_31_0)
	return arg_31_0.id == FleetProxy.PVP_FLEET_ID
end

function Fleet.getFleetType(arg_32_0)
	assert(false)
end

function Fleet.removeShip(arg_33_0, arg_33_1)
	assert(arg_33_0:containShip(arg_33_1), "ship are not in fleet")

	local var_36_0 = arg_36_1.id

	for iter_36_0, iter_36_1 in ipairs(arg_36_0.ships) do
		if iter_36_1 == var_36_0 then
			table.remove(arg_36_0.ships, iter_36_0)

			break
		end
	end

	for iter_36_2, iter_36_3 in ipairs(arg_36_0.vanguardShips) do
		if iter_36_3 == var_36_0 then
			return table.remove(arg_36_0.vanguardShips, iter_36_2), TeamType.Vanguard
		end
	end

	for iter_36_4, iter_36_5 in ipairs(arg_36_0.mainShips) do
		if iter_36_5 == var_36_0 then
			return table.remove(arg_36_0.mainShips, iter_36_4), TeamType.Main
		end
	end

	for iter_36_6, iter_36_7 in ipairs(arg_36_0.subShips) do
		if iter_36_7 == var_36_0 then
			return table.remove(arg_36_0.subShips, iter_36_6), TeamType.Submarine
		end
	end

	return nil
end

function Fleet.isFull(arg_34_0)
	local var_34_0 = arg_34_0:getFleetType()

	if var_37_0 == FleetType.Normal then
		assert(#arg_37_0.vanguardShips <= TeamType.VanguardMax and #arg_37_0.mainShips <= TeamType.MainMax)

		return #arg_37_0.vanguardShips == TeamType.VanguardMax and #arg_37_0.mainShips == TeamType.MainMax
	elseif var_37_0 == FleetType.Submarine then
		assert(#arg_37_0.subShips <= TeamType.SubmarineMax)

		return #arg_37_0.subShips == TeamType.SubmarineMax
	end

	return false
end

function Fleet.isEmpty(arg_35_0)
	return #arg_35_0.ships == 0
end

function Fleet.isCommanderEmpty(arg_39_0)
	for iter_39_0, iter_39_1 in pairs(arg_39_0.commanderIds) do
		if iter_39_1 and iter_39_1 ~= 0 then
			return false
		end
	end

	return true
end

function Fleet.isLegalToFight(arg_36_0)
	local var_36_0 = arg_36_0:getFleetType()

	if var_40_0 == FleetType.Normal then
		if #arg_40_0.vanguardShips == 0 then
			return TeamType.Vanguard, 1
		elseif #arg_40_0.mainShips == 0 then
			return TeamType.Main, 1
		end
	elseif var_40_0 == FleetType.Submarine and #arg_40_0.subShips == 0 then
		return TeamType.Submarine, 1
	end

	return true
end

function Fleet.getSkillNum(arg_37_0)
	local var_37_0 = {
		"zhupao",
		"yulei",
		"fangkongpao",
		"jianzaiji"
	}
	local var_41_1 = {}

	for iter_41_0, iter_41_1 in pairs(var_41_0) do
		var_41_1[iter_41_1] = 0
	end

	local var_41_2 = getProxy(BayProxy):getRawData()
	local var_41_3 = ys.Battle.BattleConst.EquipmentType

	for iter_41_2, iter_41_3 in ipairs(arg_41_0.ships) do
		for iter_41_4, iter_41_5 in ipairs(var_41_2[iter_41_3]:getActiveEquipments()) do
			if iter_41_5 > 0 then
				local var_41_4 = Equipment.New({
					id = iter_41_5
				}):getConfig("weapon_id")

				for iter_41_6, iter_41_7 in ipairs(var_41_4) do
					if iter_41_7 > 0 then
						local var_41_5 = pg.weapon_property[iter_41_7].type

						if var_41_5 == var_41_3.POINT_HIT_AND_LOCK then
							var_41_1.zhupao = var_41_1.zhupao + 1
						elseif var_41_5 == var_41_3.TORPEDO or var_41_5 == var_41_3.MANUAL_TORPEDO then
							var_41_1.yulei = var_41_1.yulei + 1
						elseif var_41_5 == var_41_3.ANTI_AIR then
							var_41_1.fangkongpao = var_41_1.fangkongpao + 1
						elseif var_41_5 == var_41_3.INTERCEPT_AIRCRAFT then
							var_41_1.jianzaiji = var_41_1.jianzaiji + 1
						end
					end
				end
			end
		end
	end

	return var_41_1
end

function Fleet.GetPropertiesSum(arg_38_0)
	local var_38_0 = {
		cannon = 0,
		antiAir = 0,
		air = 0,
		torpedo = 0
	}
	local var_42_1 = getProxy(BayProxy):getRawData()

	for iter_42_0, iter_42_1 in ipairs(arg_42_0.ships) do
		local var_42_2 = var_42_1[iter_42_1]:getProperties(arg_42_0:getCommanders())

		var_42_0.cannon = var_42_0.cannon + math.floor(var_42_2.cannon)
		var_42_0.torpedo = var_42_0.torpedo + math.floor(var_42_2.torpedo)
		var_42_0.antiAir = var_42_0.antiAir + math.floor(var_42_2.antiaircraft)
		var_42_0.air = var_42_0.air + math.floor(var_42_2.air)
	end

	return var_42_0
end

function Fleet.GetCostSum(arg_39_0)
	local var_39_0 = {
		gold = 0,
		oil = 0
	}
	local var_43_1 = arg_43_0:getStartCost()
	local var_43_2 = arg_43_0:getEndCost()

	if arg_43_0:getFleetType() == FleetType.Submarine then
		var_43_0.oil = var_43_2.oil
	else
		var_43_0.oil = var_43_1.oil + var_43_2.oil
	end

	return var_43_0
end

function Fleet.getStartCost(arg_40_0)
	local var_40_0 = {
		gold = 0,
		oil = 0
	}
	local var_44_1 = getProxy(BayProxy):getRawData()

	for iter_44_0, iter_44_1 in ipairs(arg_44_0.ships) do
		local var_44_2 = var_44_1[iter_44_1]:getStartBattleExpend()

		var_44_0.oil = var_44_0.oil + var_44_2
	end

	return var_44_0
end

function Fleet.getEndCost(arg_41_0)
	local var_41_0 = {
		gold = 0,
		oil = 0
	}
	local var_45_1 = getProxy(BayProxy):getRawData()

	for iter_45_0, iter_45_1 in ipairs(arg_45_0.ships) do
		local var_45_2 = var_45_1[iter_45_1]:getEndBattleExpend()

		var_45_0.oil = var_45_0.oil + var_45_2
	end

	return var_45_0
end

function Fleet.GetGearScoreSum(arg_42_0, arg_42_1)
	local var_42_0

	if arg_46_1 == nil then
		var_46_0 = arg_46_0.ships
	else
		var_46_0 = arg_46_0:getTeamByName(arg_46_1)
	end

	local var_46_1 = 0
	local var_46_2 = getProxy(BayProxy):getRawData()

	for iter_46_0, iter_46_1 in ipairs(var_46_0) do
		var_46_1 = var_46_1 + var_46_2[iter_46_1]:getShipCombatPower(arg_46_0:getCommanders())
	end

	return var_46_1
end

function Fleet.GetEnergyStatus(arg_43_0)
	local var_43_0 = false
	local var_43_1 = ""
	local var_43_2 = ""
	local var_43_3 = getProxy(BayProxy)

	local function var_47_4(arg_48_0)
		for iter_48_0 = 1, 3 do
			if arg_48_0[iter_48_0] then
				local var_48_0 = var_47_3:getShipById(arg_48_0[iter_48_0])

				if var_48_0.energy == Ship.ENERGY_LOW then
					var_47_0 = true
					var_47_2 = var_47_2 .. "「" .. var_48_0:getConfig("name") .. "」"
				end
			end
		end
	end

	var_47_4(arg_47_0.mainShips)
	var_47_4(arg_47_0.vanguardShips)
	var_47_4(arg_47_0.subShips)

	if var_47_0 then
		var_47_1 = arg_47_0:GetName()
	end

	return var_47_0, i18n("ship_energy_low_warn", var_47_1, var_47_2)
end

function Fleet.genRobotDataString(arg_45_0)
	local var_45_0 = getProxy(BayProxy):getRawData()
	local var_45_1 = "99999,"

	for iter_49_0 = 1, 3 do
		if arg_49_0.vanguardShips[iter_49_0] and arg_49_0.vanguardShips[iter_49_0] > 0 then
			var_49_1 = var_49_1 .. var_49_0[arg_49_0.vanguardShips[iter_49_0]].configId .. "," .. var_49_0[arg_49_0.vanguardShips[iter_49_0]].level .. ",\"{"

			for iter_49_1, iter_49_2 in pairs(var_49_0[arg_49_0.vanguardShips[iter_49_0]]:getActiveEquipments()) do
				var_49_1 = var_49_1 .. (iter_49_2 and iter_49_2.id or 0)

				if iter_49_1 < 5 then
					var_49_1 = var_49_1 .. ","
				end
			end

			var_49_1 = var_49_1 .. "}\","
		else
			var_49_1 = var_49_1 .. "" .. "," .. "" .. ",{" .. "},"
		end
	end

	for iter_49_3 = 1, 3 do
		if arg_49_0.mainShips[iter_49_3] and arg_49_0.mainShips[iter_49_3] > 0 then
			var_49_1 = var_49_1 .. var_49_0[arg_49_0.mainShips[iter_49_3]].configId .. "," .. var_49_0[arg_49_0.mainShips[iter_49_3]].level .. ",\"{"

			for iter_49_4, iter_49_5 in pairs(var_49_0[arg_49_0.mainShips[iter_49_3]]:getActiveEquipments()) do
				var_49_1 = var_49_1 .. (iter_49_5 and iter_49_5.id or 0)

				if iter_49_4 < 5 then
					var_49_1 = var_49_1 .. ","
				end
			end

			var_49_1 = var_49_1 .. "}\","
		else
			var_49_1 = var_49_1 .. "" .. "," .. "" .. ",{" .. "},"
		end
	end

	local var_49_2 = arg_49_0:GetGearScoreSum(TeamType.Vanguard)
	local var_49_3 = arg_49_0:GetGearScoreSum(TeamType.Main)

	return var_49_1 .. math.floor(var_49_2 + var_49_3) .. ","
end

function Fleet.getIndex(arg_46_0)
	if arg_46_0.id >= Fleet.SUBMARINE_FLEET_ID and arg_46_0.id < Fleet.SUBMARINE_FLEET_ID + Fleet.SUBMARINE_FLEET_NUMS then
		return arg_46_0.id - Fleet.SUBMARINE_FLEET_ID + 1
	elseif arg_46_0.id >= Fleet.REGULAR_FLEET_ID and arg_46_0.id < Fleet.REGULAR_FLEET_ID + Fleet.REGULAR_FLEET_NUMS then
		return arg_46_0.id - Fleet.REGULAR_FLEET_ID + 1
	end

	return arg_50_0.id
end

function Fleet.getShipCount(arg_47_0)
	return #arg_47_0.ships
end

function Fleet.avgLevel(arg_48_0)
	local var_48_0 = 0

	for iter_52_0, iter_52_1 in ipairs(arg_52_0.ships) do
		var_52_0 = getProxy(BayProxy):getShipById(iter_52_1).level + var_52_0
	end

	return math.floor(var_52_0 / #arg_52_0.ships)
end

function Fleet.clearFleet(arg_49_0)
	local var_49_0 = Clone(arg_49_0.ships)
	local var_49_1 = getProxy(BayProxy)

	for iter_53_0, iter_53_1 in ipairs(var_53_0) do
		local var_53_2 = var_53_1:getShipById(iter_53_1)

		arg_53_0:removeShip(var_53_2)
	end
end

function Fleet.EnergyCheck(arg_50_0, arg_50_1, arg_50_2, arg_50_3, arg_50_4)
	arg_50_4 = arg_50_4 or "ship_energy_low_warn"

	local var_54_0 = {}

	for iter_54_0, iter_54_1 in ipairs(arg_54_0) do
		if iter_54_1.energy == Ship.ENERGY_LOW then
			table.insert(var_54_0, iter_54_1)
		end
	end

	if #var_54_0 > 0 then
		local var_54_1 = ""
		local var_54_2 = _.map(var_54_0, function(arg_55_0)
			return "「" .. arg_55_0:getConfig("name") .. "」"
		end)

		if PLATFORM_CODE ~= PLATFORM_US or #var_54_2 == 1 then
			for iter_54_2, iter_54_3 in ipairs(var_54_2) do
				var_54_1 = var_54_1 .. iter_54_3
			end
		else
			if arg_54_4 == "ship_energy_low_warn_no_exp" or arg_54_4 == "ship_energy_low_warn" or arg_54_4 == "ship_energy_low_desc" then
				arg_54_4 = "multiple_" .. arg_54_4
			end

			for iter_54_4 = 1, #var_54_2 - 2 do
				local var_54_3 = var_54_2[iter_54_4]

				var_54_1 = var_54_1 .. var_54_3 .. ", "
			end

			var_54_1 = var_54_1 .. var_54_2[#var_54_2 - 1] .. " and " .. var_54_2[#var_54_2]
		end

		existCall(arg_54_3, false)
		pg.MsgboxMgr.GetInstance():ShowMsgBox({
			content = i18n(arg_54_4, arg_54_1, var_54_1),
			onYes = function()
				arg_54_2(true)
			end,
			onNo = function()
				arg_54_2(false)
			end
		})
	else
		existCall(arg_54_3, true)
		arg_54_2(true)
	end
end

function Fleet.getFleetAirDominanceValue(arg_54_0)
	local var_54_0 = getProxy(BayProxy)
	local var_54_1 = arg_54_0:getCommanders()
	local var_54_2 = 0

	for iter_58_0, iter_58_1 in ipairs(arg_58_0.ships) do
		var_58_2 = (function(arg_59_0, arg_59_1)
			return arg_59_0 + calcAirDominanceValue(var_58_0:getShipById(arg_59_1), var_58_1)
		end)(var_58_2, iter_58_1)
	end

	return var_58_2
end

function Fleet.RemoveUnusedItems(arg_56_0)
	local var_56_0 = Clone(arg_56_0.ships)
	local var_56_1 = getProxy(BayProxy)

	for iter_60_0, iter_60_1 in ipairs(var_60_0) do
		if not var_60_1:getShipById(iter_60_1) then
			arg_60_0:removeShipById(iter_60_1)
		end
	end

	local var_60_2 = getProxy(CommanderProxy)
	local var_60_3 = {}

	for iter_60_2, iter_60_3 in pairs(arg_60_0.commanderIds) do
		if not var_60_2:getCommanderById(iter_60_3) then
			table.insert(var_60_3, iter_60_2)
		end
	end

	if #var_60_3 > 0 then
		for iter_60_4, iter_60_5 in pairs(var_60_3) do
			arg_60_0.commanderIds[iter_60_5] = nil
		end

		arg_60_0.skills = {}

		arg_60_0:updateCommanderSkills()
	end
end

function Fleet.removeShipById(arg_57_0, arg_57_1)
	for iter_57_0, iter_57_1 in ipairs(arg_57_0.ships) do
		if iter_57_1 == arg_57_1 then
			table.remove(arg_57_0.ships, iter_57_0)

			break
		end
	end

	for iter_61_2, iter_61_3 in ipairs(arg_61_0.vanguardShips) do
		if iter_61_3 == arg_61_1 then
			return table.remove(arg_61_0.vanguardShips, iter_61_2), TeamType.Vanguard
		end
	end

	for iter_61_4, iter_61_5 in ipairs(arg_61_0.mainShips) do
		if iter_61_5 == arg_61_1 then
			return table.remove(arg_61_0.mainShips, iter_61_4), TeamType.Main
		end
	end

	for iter_61_6, iter_61_7 in ipairs(arg_61_0.subShips) do
		if iter_61_7 == arg_61_1 then
			return table.remove(arg_61_0.subShips, iter_61_6), TeamType.Submarine
		end
	end
end

function Fleet.HaveShipsInEvent(arg_58_0)
	local var_58_0 = getProxy(BayProxy):getRawData()

	for iter_62_0, iter_62_1 in ipairs(arg_62_0.ships) do
		if var_62_0[iter_62_1]:getFlag("inEvent") then
			return true, i18n("elite_disable_ship_escort")
		end
	end
end

function Fleet.GetFleetSonarRange(arg_59_0)
	local var_59_0 = getProxy(BayProxy)
	local var_59_1 = 0
	local var_59_2 = 0
	local var_59_3 = 0
	local var_59_4 = 0
	local var_59_5 = ys.Battle.BattleConfig

	for _, shipID in ipairs(self.ships) do
		--- @type Ship
		local ship = bayProxy:getShipById(shipID)

		if ship then
			local shipType = ship:getShipType()
			local sonarProperty = BattleConfig.VAN_SONAR_PROPERTY[shipType]

			if sonarProperty then
				-- 此处getShipProperties计算的是舰船的白字属性，即只计算（基础 + 强化) * (1 + 好感度加成) + 改造
				-- 对于驱逐/导驱V: a = 2, b = 32, minRange = 45, maxRange = 100
				-- 对于轻巡: a = 2.86, b = 0, minRange = 30, maxRange = 80
				-- 公式: sonarRange = (AntiSub / a) - b
				-- 1. 两种公式何时相等：x/2 - 32 > x/2.86 => x > 212.83
					-- 反潜 <= 212时，轻巡的基础声呐范围更高；反潜 >= 213时，驱逐/导驱V的基础声呐范围更高
				-- 2. 驱逐/导驱V达到最大声呐范围所需反潜：x/2 - 32 = 100 -> x = 264；最小：x/2 - 32 = 45 -> x = 154
				-- 3. 轻巡达到最大声呐范围所需反潜：x/2.86 = 80 -> x = 228.8；最小：x/2.86 = 30 -> x = 85.8
				local baseSonarRange = (ship:getShipProperties()[AttributeType.AntiSub] or 0) / sonarProperty.a - sonarProperty.b

				sonarRange = math.max(sonarRange, Mathf.Clamp(baseSonarRange, sonarProperty.minRange, sonarProperty.maxRange))
			end

			if table.contains(ShipType.MainShipType, var_63_7) then
				var_63_4 = var_63_4 + (var_63_6:getShipProperties()[AttributeType.AntiSub] or 0)
			end

			for _, equipment in ipairs(ship:getActiveEquipments()) do
				if equipment then
					equipmentExtraSonarRange = equipmentExtraSonarRange + (equipment:getConfig("equip_parameters").range or 0)
				end
			end
		end
	end

	if sonarRange ~= 0 then
		local MAIN_SONAR_PROPERTY = BattleConfig.MAIN_SONAR_PROPERTY
		-- a = 24, minRange = 0, maxRange = 15
		-- 4. 主力单位达到最大声呐范围所需反潜：x/24 = 15 -> x = 360；最小：x/24 = 0 -> x = 0
		local mainSonarRange = mainAntiSub / MAIN_SONAR_PROPERTY.a

		extraSonarRange = equipmentExtraSonarRange + Mathf.Clamp(mainSonarRange, MAIN_SONAR_PROPERTY.minRange, MAIN_SONAR_PROPERTY.maxRange)
	end

	return sonarRange + extraSonarRange
end

function Fleet.getInvestSums(arg_60_0)
	local var_60_0 = getProxy(BayProxy)

	local function var_64_1(arg_65_0, arg_65_1)
		local var_65_0 = var_64_0:getShipById(arg_65_1):getProperties(arg_64_0:getCommanders())

		return arg_65_0 + var_65_0[AttributeType.Air] + var_65_0[AttributeType.Dodge]
	end

	local var_64_2 = _.reduce(arg_64_0.ships, 0, var_64_1)

	return math.pow(var_64_2, 0.6666666666666666)
end

function Fleet.ExistActNpcShip(arg_62_0)
	local var_62_0 = getProxy(BayProxy)

	for iter_66_0, iter_66_1 in ipairs(arg_66_0.ships) do
		local var_66_1 = var_66_0:RawGetShipById(iter_66_1)

		if var_66_1 and var_66_1:isActivityNpc() then
			return true
		end
	end

	return false
end

function Fleet.GetName(arg_63_0)
	return noEmptyStr(arg_63_0.name) or Fleet.DEFAULT_NAME[arg_63_0.id]
end

function Fleet.ChangeToElite(arg_64_0)
	local var_64_0 = arg_64_0:getFleetType()
	local var_64_1 = {
		id = arg_64_0.id,
		[TeamType.FormShips] = {},
		[TeamType.FormCommander] = {
			0,
			0
		}
	}

	for iter_64_0, iter_64_1 in ipairs(arg_64_0.commanderIds) do
		var_64_1[TeamType.FormCommander][iter_64_0] = iter_64_1
	end

	switch(var_64_0, {
		[FleetType.Normal] = function()
			var_64_1[TeamType.FormShips] = table.mergeArray(arg_64_0.mainShips, arg_64_0.vanguardShips)
		end,
		[FleetType.Submarine] = function()
			var_64_1[TeamType.FormShips] = underscore.to_array(arg_64_0.subShips)
		end,
		[FleetType.Support] = function()
			var_64_1[TeamType.FormShips] = underscore.to_array(arg_64_0.mainShips)
		end
	})

	return var_64_1, var_64_0
end

function Fleet.allClear(arg_72_0)
	arg_72_0:clearFleet()
	arg_72_0:clearCommanders()
end

function Fleet.isAllEmpty(arg_73_0)
	return arg_73_0:isEmpty() and arg_73_0:isCommanderEmpty()
end

return Fleet
