--- @class BattleGateBossRushCollabrate : Boss Rush 协作模式Gate
local BattleGateBossRushCollabrate = class("BattleGateBossRushCollabrate")

ys.Battle.BattleGateBossRushCollabrate = BattleGateBossRushCollabrate
BattleGateBossRushCollabrate.__name = "BattleGateBossRushCollabrate"

--- 进入Boss Rush协作战斗
--- @param self BattleGateBossRushCollabrate
--- @param sendData table BeginStageCommand实例
function BattleGateBossRushCollabrate.Entrance(self, sendData)
	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_RUSH_COLLABRATE]
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
			system = SYSTEM_BOSS_RUSH_COLLABRATE,
			actId = actId,
			token = tokenData.key,
			continuousBattleTimes = self.continuousBattleTimes,
			totalBattleTimes = self.totalBattleTimes
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_BOSS_RUSH_COLLABRATE, shipIdList, {
		expeditionId
	}, onServerSuccess, onServerFail)
end

--- 退出Boss Rush协作，与BossRush类似但使用协作系统常量
--- @param self BattleGateBossRushCollabrate
--- @param callback table 回调对象
function BattleGateBossRushCollabrate.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_RUSH_COLLABRATE]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}
	local activityExpired = false

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

		--- 收集舰队数据
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

	--- 结算成功回调
	local function onFinishSuccess(serverResult)
		self.statistics.mvpShipID = serverResult.mvp

		local resultData = {
			system = SYSTEM_BOSS_RUSH_COLLABRATE,
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

--- 获取预加载资源列表，复用BossRush逻辑并追加协作buff
--- @param self BattleGateBossRushCollabrate
--- @return table shipResources, table skinResources
function BattleGateBossRushCollabrate.GetPreloadList(self)
	local shipResources, skinResources = ys.Battle.BattleGateBossRush.GetPreloadList(self)
	local seriesData = getProxy(ActivityProxy):getActivityById(self.actId):GetSeriesData()
	local aidBuff = seriesData:getConfig("aid_buff")

	if seriesData:GetBossHpRate() <= aidBuff[1] then
		local buffRes = resMgr.GetResFromBuffIDList({
			aidBuff[2]
		})

		for _, res in ipairs(buffRes) do
			table.insert(shipResources, res)
		end
	end

	return shipResources, skinResources
end

return BattleGateBossRushCollabrate
