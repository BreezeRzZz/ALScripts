--- @class BattleGateActBoss : 活动Boss Gate，处理入场、结算和资源预加载
local BattleGateActBoss = class("BattleGateActBoss")

ys.Battle.BattleGateActBoss = BattleGateActBoss
BattleGateActBoss.__name = "BattleGateActBoss"

--- 进入活动Boss战斗
--- @param self BattleGateActBoss
--- @param sendData table BeginStageCommand实例
function BattleGateActBoss.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local continuousTimes = self.continuousBattleTimes
	local totalTimes = self.totalBattleTimes
	local actId = self.actId
	local activityData = getProxy(ActivityProxy):getActivityById(actId)
	local configId = activityData:getConfig("config_id")
	local worldBossTemplate = pg.activity_event_worldboss[configId]
	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local fleetProxy = getProxy(FleetProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_ACT_BOSS]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local stageId = self.stageId
	local mainFleetId = self.mainFleetId
	local fleet = fleetProxy:getActivityFleets()[actId][mainFleetId]
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local startCost = fleet:getStartCost().oil
	local costSum = fleet:GetCostSum().oil
	local oilLimit = worldBossTemplate.use_oil_limit[mainFleetId]

	if activityData:IsOilLimit(stageId) and oilLimit[1] > 0 then
		costSum = math.min(costSum, oilLimit[1])
	end

	local playerData = playerProxy:getData()

	if hasOilCost and costSum > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab

	sendData.ShipVertify()

	--- 服务器验证成功后的回调，消耗资源并组装战斗数据
	local function onServerSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startCost
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

		local stageData = {
			mainFleetId = mainFleetId,
			actId = actId,
			prefabFleet = fleetPrefab,
			stageId = stageId,
			system = SYSTEM_ACT_BOSS,
			token = tokenData.key,
			continuousBattleTimes = continuousTimes,
			totalBattleTimes = totalTimes
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败的回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_ACT_BOSS, shipIdList, {
		stageId
	}, onServerSuccess, onServerFail)
end

--- 退出活动Boss，处理结算和奖励
--- @param self BattleGateActBoss
--- @param callback table 回调对象
function BattleGateActBoss.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_ACT_BOSS]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local activityData = getProxy(ActivityProxy):getActivityById(self.actId)
	local configId = activityData:getConfig("config_id")
	local oilLimit = pg.activity_event_worldboss[configId].use_oil_limit[self.mainFleetId]
	local isOilLimited = activityData:IsOilLimit(self.stageId)
	local activityFleets = fleetProxy:getActivityFleets()[self.actId]
	local mainFleet = activityFleets[self.mainFleetId]
	local subFleet
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}
	local hasOilCost = costTemplate.oil_cost > 0

	--- 处理单个舰队的油耗和舰船列表收集
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

	processFleetCost(mainFleet, isOilLimited and oilLimit[1] or 0)

	if self.statistics.submarineAid then
		subFleet = activityFleets[self.mainFleetId + 10]

		if subFleet then
			processFleetCost(subFleet, isOilLimited and oilLimit[2] or 0)
		else
			originalPrint("finish stage error: can not find submarin fleet.")
		end
	end

	local generalPackage = callback.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	--- 结算成功回调，处理经验、掉落和奖励通知
	local function onFinishSuccess(serverResult)
		callback.addShipsExp(serverResult.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = serverResult.mvp

		local drops, extraDrops = callback:GeneralLoot(serverResult)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(serverResult, mainFleet, subFleet)

		callback.GeneralPlayerCosume(SYSTEM_ACT_BOSS, isWin, totalOil, serverResult.player_exp)

		local isLastBonus

		if isWin then
			isLastBonus = (function()
				local currentActivity = getProxy(ActivityProxy):getActivityById(self.actId)
				local checkStageId = self.stageId

				return currentActivity.data1KeyValueList[1][checkStageId] == 1 and currentActivity.data1KeyValueList[2][checkStageId] <= 0
			end)()

			callback:sendNotification(GAME.ACT_BOSS_NORMAL_UPDATE, {
				stageId = self.stageId
			})
		end

		local finishData = {
			system = SYSTEM_ACT_BOSS,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = commanderExp,
			result = serverResult.result,
			extraDrops = extraDrops,
			isLastBonus = isLastBonus
		}

		if PlayerConst.CanDropItem(drops) then
			local allDrops = {}

			for _, drop in ipairs(drops) do
				table.insert(allDrops, drop)
			end

			for _, extraDrop in ipairs(extraDrops) do
				extraDrop.riraty = true

				table.insert(allDrops, extraDrop)
			end

			if getProxy(ContextProxy):getCurrentContext():getContextByMediator(ContinuousOperationMediator) then
				getProxy(ChapterProxy):AddActBossRewards(allDrops)
			end
		end

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	callback:SendRequest(generalPackage, onFinishSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateActBoss
--- @return table shipResources, table skinResources
function BattleGateActBoss.GetPreloadList(self)
	local shipList = {}
	local buffList = {}
	local skinList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local activityFleets = fleetProxy:getActivityFleets()[self.actId]
	local mainFleet = activityFleets[self.mainFleetId]

	if mainFleet then
		local shipIds = mainFleet.ships

		for _, shipId in ipairs(shipIds) do
			table.insert(shipList, bayProxy:getShipById(shipId))
		end

		local fleetBuffs = mainFleet:buildBattleBuffList()

		for _, buff in ipairs(fleetBuffs) do
			table.insert(buffList, buff)
		end
	end

	local subFleet = activityFleets[self.mainFleetId + 10]

	if subFleet then
		local subTeam = subFleet:getTeamByName(TeamType.Submarine)

		for _, shipId in ipairs(subTeam) do
			table.insert(shipList, bayProxy:getShipById(shipId))
		end

		local subBuffs = subFleet:buildBattleBuffList()

		for _, buff in ipairs(subBuffs) do
			table.insert(buffList, buff)
		end
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local commanderBuffs = resMgr.GetCommanderBuffRes(buffList)

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateActBoss
