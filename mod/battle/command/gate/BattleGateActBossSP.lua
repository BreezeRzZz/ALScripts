--- @class BattleGateActBossSP : 活动Boss SP模式Gate，与ActBoss类似但支持buff列表和SP特有逻辑
local BattleGateActBossSP = class("BattleGateActBossSP")

ys.Battle.BattleGateActBossSP = BattleGateActBossSP
BattleGateActBossSP.__name = "BattleGateActBossSP"
BattleGateActBossSP.BattleSystem = SYSTEM_ACT_BOSS_SP

--- 进入活动Boss SP战斗
--- @param self BattleGateActBossSP
--- @param sendData table BeginStageCommand实例
function BattleGateActBossSP.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local activityData = getProxy(ActivityProxy):getActivityById(actId)
	local playerProxy = getProxy(PlayerProxy)
	local playerData = playerProxy:getData()
	local bayProxy = getProxy(BayProxy)
	local fleetProxy = getProxy(FleetProxy)
	local buffIds = getProxy(ActivityProxy):GetActivityBossRuntime(actId).buffIds
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local mainFleetId = self.mainFleetId
	local fleet = fleetProxy:getActivityFleets()[actId][mainFleetId]
	local shipIdList = {}
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local costTemplate = pg.battle_cost_template[BattleGateActBossSP.BattleSystem]
	local hasOilCost = costTemplate.oil_cost > 0
	local startOil = 0
	local endOil = 0

	if hasOilCost then
		startOil = fleet:getStartCost().oil
		endOil = fleet:GetCostSum().oil
	end

	if endOil > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	sendData.ShipVertify()

	--- 服务器验证成功回调
	local function onServerSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startOil
			})
		end

		if costTemplate.enter_energy_cost > 0 then
			local energyCost = pg.gameset.battle_consume_energy.key_value

			for _, ship in ipairs(sortShips) do
				ship:cosumeEnergy(energyCost)
				bayProxy:updateShip(ship)
			end
		end

		playerProxy:updatePlayer(playerData)

		-- 刷新活动数据（可能在验证期间变化）
		activityData = getProxy(ActivityProxy):getActivityById(actId)

		activityData:UpdateHistoryBuffs(buffIds)
		getProxy(ActivityProxy):updateActivity(activityData)

		local stageData = {
			mainFleetId = mainFleetId,
			actId = actId,
			prefabFleet = fleetPrefab,
			stageId = stageId,
			system = BattleGateActBossSP.BattleSystem,
			token = tokenData.key
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(BattleGateActBossSP.BattleSystem, shipIdList, {
		stageId,
		buffIds
	}, onServerSuccess, onServerFail)
end

--- 退出活动Boss SP
--- @param self BattleGateActBossSP
--- @param callback table 回调对象
function BattleGateActBossSP.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[BattleGateActBossSP.BattleSystem]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local activityData = getProxy(ActivityProxy):getActivityById(self.actId):getConfig("config_id")
	local worldBossTemplate = pg.activity_event_worldboss[activityData]
	local activityFleets = fleetProxy:getActivityFleets()[self.actId]
	local mainFleet = activityFleets[self.mainFleetId]
	local subFleet
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}
	local hasOilCost = costTemplate.oil_cost > 0

	--- 处理单个舰队的消耗
	local function processFleetCost(fleet, limit)
		if hasOilCost then
			local endOil = fleet:getEndCost().oil

			if limit > 0 then
				local startOil = fleet:getStartCost().oil

				endOil = math.clamp(limit - startOil, 0, endOil)
			end

			totalOil = totalOil + endOil
		end

		table.insertto(shipList, bayProxy:getSortShipsByFleet(fleet))
		table.insertto(commanderIdList, fleet.commanderIds)
	end

	processFleetCost(mainFleet, 0)

	if self.statistics.submarineAid then
		subFleet = activityFleets[self.mainFleetId + 10]

		if subFleet then
			processFleetCost(subFleet, 0)
		else
			originalPrint("finish stage error: can not find submarin fleet.")
		end
	end

	local generalPackage = callback.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	--- 结算成功回调
	local function onFinishSuccess(serverResult)
		callback.addShipsExp(serverResult.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = serverResult.mvp

		local drops, extraDrops = callback:GeneralLoot(serverResult)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(serverResult, mainFleet, activityFleets[self.mainFleetId + 10])

		callback.GeneralPlayerCosume(BattleGateActBossSP.BattleSystem, isWin, totalOil, serverResult.player_exp)

		local finishData = {
			system = BattleGateActBossSP.BattleSystem,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = commanderExp,
			result = serverResult.result,
			extraDrops = extraDrops
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	callback:SendRequest(generalPackage, onFinishSuccess)
end

--- 获取预加载资源列表，在ActBoss基础上追加SP buff资源
--- @param self BattleGateActBossSP
--- @return table shipResources, table skinResources
function BattleGateActBossSP.GetPreloadList(self)
	local shipResources, skinResources = ys.Battle.BattleGateActBoss.GetPreloadList(self)
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local buffIds = getProxy(ActivityProxy):GetActivityBossRuntime(self.actId).buffIds
	local buffIDList = _.map(buffIds, function(configId)
		return ActivityBossBuff.New({
			configId = configId
		}):GetBuffID()
	end)
	local buffResList = resMgr.GetResFromBuffIDList(buffIDList)

	for _, res in ipairs(buffResList) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateActBossSP
