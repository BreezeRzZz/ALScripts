--- @class BattleGateCooperate : 共斗（HP共享）模式Gate
local BattleGateCooperate = class("BattleGateCooperate")

ys.Battle.BattleGateCooperate = BattleGateCooperate
BattleGateCooperate.__name = "BattleGateCooperate"

--- 进入共斗战斗
--- @param self BattleGateCooperate
--- @param sendData table 发送数据
function BattleGateCooperate.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local fleetProxy = getProxy(FleetProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_HP_SHARE_ACT_BOSS]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local regularFleet = fleetProxy:getActivityFleets()[actId][Fleet.REGULAR_FLEET_ID]

	for _, shipId in ipairs(regularFleet.ships) do
		shipIdList[#shipIdList + 1] = shipId
	end

	local startCost = regularFleet:getStartCost().oil
	local costSum = regularFleet:GetCostSum().oil
	local sortShips = bayProxy:getSortShipsByFleet(regularFleet)
	local playerData = playerProxy:getData()

	if hasOilCost and costSum > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab

	sendData.ShipVertify()

	local isExtraMode

	if chapter:getPlayType() == ChapterConst.TypeExtra then
		isExtraMode = true
	end

	--- 请求成功回调
	local function onSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startCost
			})
		end

		if costTemplate.enter_energy_cost > 0 and not isExtraMode then
			local energyCost = pg.gameset.battle_consume_energy.key_value

			for _, ship in ipairs(sortShips) do
				ship:cosumeEnergy(energyCost)
				bayProxy:updateShip(ship)
			end
		end

		playerProxy:updatePlayer(playerData)

		local fleetId = Fleet.REGULAR_FLEET_ID
		local stageData = {
			mainFleetId = fleetId,
			prefabFleet = fleetPrefab,
			stageId = stageId,
			actId = actId,
			system = SYSTEM_HP_SHARE_ACT_BOSS,
			token = tokenData.key
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_HP_SHARE_ACT_BOSS, shipIdList, {
		stageId
	}, onSuccess, onFail)
end

--- 退出共斗战斗
--- @param self BattleGateCooperate
--- @param callback table 回调对象
function BattleGateCooperate.Exit(self, callback)
	if client.CheaterVertify() then
		return
	end

	local costTemplate = pg.battle_cost_template[SYSTEM_HP_SHARE_ACT_BOSS]
	local fleetProxy = getProxy(FleetProxy)
	local chapterProxy = getProxy(ChapterProxy)
	local score = ys.Battle.BattleConst.BattleScore.S
	local goldTotal = 0
	local extraGold = 0
	local subOil
	local mainFleet = fleetProxy:getActivityFleets()[self.actId][self.mainFleetId]
	local mainShips = bayProxy:getSortShipsByFleet(mainFleet)
	local totalOil = mainFleet:getEndCost().oil

	if self.statistics.submarineAid then
		local subFleet = fleetProxy:getActivityFleets()[self.actId][Fleet.SUBMARINE_FLEET_ID]

		if subFleet then
			local subShips = bayProxy:getSortShipsByFleet(subFleet)

			for _, ship in ipairs(subShips) do
				if self.statistics[ship.id] then
					table.insert(mainShips, ship)

					totalOil = totalOil + ship:getEndBattleExpend()
				end
			end
		else
			originalPrint("finish stage error: can not find submarine fleet.")
		end
	end

	local generalPackage = client.GeneralPackage(self, mainShips)
	local enemyInfo = {}

	for _, enemy in ipairs(self.statistics._enemyInfoList) do
		table.insert(enemyInfo, {
			enemy_id = enemy.id,
			damage_taken = enemy.damage,
			total_hp = enemy.totalHp
		})
	end

	generalPackage.enemy_info = enemyInfo

	--- 结算成功回调
	local function onSuccess(result)
		client.addShipsExp(result.ship_exp_list, self.statistics)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = client:GeneralLoot(result)
		local isWin = score > ys.Battle.BattleConst.BattleScore.C

		BattleGateCooperate.GeneralPlayerCosume(SYSTEM_HP_SHARE_ACT_BOSS, isWin, totalOil, result.player_exp)

		local finishData = {
			system = SYSTEM_HP_SHARE_ACT_BOSS,
			statistics = self.statistics,
			score = score,
			drops = drops,
			commanderExps = {},
			result = result.result,
			extraDrops = extraDrops
		}

		client:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	client:SendRequest(generalPackage, onSuccess)
end

return BattleGateCooperate
