--- @class BattleGateBossRush : Boss Rush模式Gate
local BattleGateBossRush = class("BattleGateBossRush")

ys.Battle.BattleGateBossRush = BattleGateBossRush
BattleGateBossRush.__name = "BattleGateBossRush"

--- 进入Boss Rush战斗
--- @param self BattleGateBossRush
--- @param sendData table BeginStageCommand实例
function BattleGateBossRush.Entrance(self, sendData)
	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_RUSH]
	local hasOilCost = costTemplate.oil_cost > 0
	local seriesData = getProxy(ActivityProxy):getActivityById(actId):GetSeriesData()
	local currentLevel = seriesData:GetStaegLevel() + 1
	local expeditionId = seriesData:GetExpeditionIds()[currentLevel]
	local mode = seriesData:GetMode()
	local mainFleetId, subFleetId = seriesData:GetStageFleets(mode, currentLevel)
	local activityFleets = fleetProxy:getActivityFleets()[actId]
	local mainFleet = activityFleets[mainFleetId]
	local subFleet = activityFleets[subFleetId]
	local shipIdList = {}
	local sortShips = bayProxy:getSortShipsByFleet(mainFleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local playerData = playerProxy:getRawData()
	local costSum = mainFleet:GetCostSum().oil

	if hasOilCost and costSum > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	sendData.ShipVertify()

	local startOil = mainFleet:getStartCost().oil

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

		local stageData = {
			prefabFleet = {},
			stageId = expeditionId,
			system = SYSTEM_BOSS_RUSH,
			actId = actId,
			token = tokenData.key,
			continuousBattleTimes = self.continuousBattleTimes,
			totalBattleTimes = self.totalBattleTimes,
			curIndex = self.curIndex,
			maxIndex = self.maxIndex
		}

		if self.curIndex then
			sendData:sendNotification(GAME.CONTINUE_STAGE_DONE, stageData)
		else
			sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
		end
	end

	--- 服务器验证失败回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_BOSS_RUSH, shipIdList, {
		expeditionId
	}, onServerSuccess, onServerFail)
end

--- 退出Boss Rush，处理PassStage和活动更新
--- @param self BattleGateBossRush
--- @param callback table 回调对象
function BattleGateBossRush.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_RUSH]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}
	local activityExpired = false

	-- 收集当前关卡的舰队数据
	;(function()
		local actId = self.actId
		local seriesData = getProxy(ActivityProxy):getActivityById(actId):GetSeriesData()

		if not seriesData then
			activityExpired = true

			return
		end

		local currentLevel = seriesData:GetStaegLevel() + 1
		local mode = seriesData:GetMode()
		local mainFleetId, subFleetId = seriesData:GetStageFleets(mode, currentLevel)
		local activityFleets = fleetProxy:getActivityFleets()[actId]
		local mainFleet = activityFleets[mainFleetId]
		local subFleet = activityFleets[subFleetId]

		--- 收集舰队的指挥官和舰船数据
		local function collectFleetData(fleet)
			table.insertto(commanderIdList, _.values(fleet.commanderIds))
			table.insertto(shipList, bayProxy:getSortShipsByFleet(fleet))
		end

		collectFleetData(mainFleet)

		if self.statistics.submarineAid then
			collectFleetData(subFleet)
		end
	end)()

	if activityExpired then
		callback:sendNotification(GAME.FINISH_STAGE_ERROR)

		return
	end

	local generalPackage = callback.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	--- 结算成功回调，更新活动通关状态
	local function onFinishSuccess(serverResult)
		self.statistics.mvpShipID = serverResult.mvp

		local resultData = {
			system = SYSTEM_BOSS_RUSH,
			statistics = self.statistics,
			score = battleScore,
			result = serverResult.result
		}
		local actId = self.actId
		local activity = getProxy(ActivityProxy):getActivityById(actId)

		activity:GetSeriesData():PassStage(resultData)
		getProxy(ActivityProxy):updateActivity(activity)
		callback:sendNotification(GAME.FINISH_STAGE_DONE, resultData)
	end

	callback:SendRequest(generalPackage, onFinishSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateBossRush
--- @return table shipResources, table skinResources
function BattleGateBossRush.GetPreloadList(self)
	local shipList = {}
	local buffList = {}
	local skinList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local seriesData = getProxy(ActivityProxy):getActivityById(self.actId):GetSeriesData()
	local currentLevel = seriesData:GetStaegLevel() + 1
	local fleetIds = seriesData:GetFleetIds()
	local mainFleetId = fleetIds[currentLevel]
	local subFleetId = fleetIds[#fleetIds]

	if seriesData:GetMode() == BossRushSeriesData.MODE.SINGLE then
		mainFleetId = fleetIds[1]
	end

	local activityFleets = fleetProxy:getActivityFleets()[self.actId]
	local mainFleet = activityFleets[mainFleetId]
	local subFleet = activityFleets[subFleetId]

	if mainFleet then
		local mainShipIds = mainFleet:GetRawShipIds()

		for _, shipId in ipairs(mainShipIds) do
			table.insert(shipList, bayProxy:getShipById(shipId))
		end

		buffList = mainFleet:buildBattleBuffList()
	end

	if subFleet then
		local subShipIds = subFleet:GetRawShipIds()

		for _, shipId in ipairs(subShipIds) do
			table.insert(shipList, bayProxy:getShipById(shipId))
		end

		for _, buff in ipairs(subFleet:buildBattleBuffList()) do
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

return BattleGateBossRush
