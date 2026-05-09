--- @class BattleGateBossRushEX : Boss Rush EX模式Gate
local BattleGateBossRushEX = class("BattleGateBossRushEX")

ys.Battle.BattleGateBossRushEX = BattleGateBossRushEX
BattleGateBossRushEX.__name = "BattleGateBossRushEX"

--- 进入Boss Rush EX战斗
--- @param self BattleGateBossRushEX
--- @param sendData table 发送数据
function BattleGateBossRushEX.Entrance(self, sendData)
	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_RUSH_EX]
	local hasOilCost = costTemplate.oil_cost > 0
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
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

	if hasOilCost and endOil > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	sendData.ShipVertify()

	--- 请求成功回调
	local function onSuccess(tokenData)
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
			system = SYSTEM_BOSS_RUSH_EX,
			actId = actId,
			token = tokenData.key
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_BOSS_RUSH_EX, shipIdList, {
		expeditionId
	}, onSuccess, onFail)
end

--- 退出Boss Rush EX，使用seriesAsync异步结算
--- @param self BattleGateBossRushEX
--- @param callback table 回调对象
function BattleGateBossRushEX.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_RUSH_EX]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}

	-- 收集舰队数据
	;(function()
		local actId = self.actId
		local seriesData = getProxy(ActivityProxy):getActivityById(actId):GetSeriesData()
		local currentLevel = seriesData:GetStaegLevel() + 1
		local mode = seriesData:GetMode()
		local mainFleetId, subFleetId = seriesData:GetStageFleets(mode, currentLevel)
		local activityFleets = fleetProxy:getActivityFleets()[actId]
		local mainFleet = activityFleets[mainFleetId]
		local subFleet = activityFleets[subFleetId]

		--- 处理单个舰队
		local function processFleet(fleet)
			table.insertto(commanderIdList, _.values(fleet.commanderIds))
			table.insertto(shipList, bayProxy:getSortShipsByFleet(fleet))
		end

		processFleet(mainFleet)

		if self.statistics.submarineAid then
			processFleet(subFleet)
		end
	end)()

	local generalPackage = callback.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	--- 结算回调
	local function onExitResult(serverResult)
		self.statistics.mvpShipID = serverResult.mvp

		local resultData = {
			system = SYSTEM_BOSS_RUSH_EX,
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

	-- 胜利时发送请求，否则直接异步执行
	seriesAsync({
		function(nextStep)
			if isWin then
				callback:SendRequest(generalPackage, function(resp)
					nextStep(resp)
				end)

				return
			end

			nextStep({})
		end,
		function(_, serverResult)
			onExitResult(serverResult)
		end
	})
end

--- 获取预加载资源列表，复用BossRush的逻辑
--- @param self BattleGateBossRushEX
--- @return table shipResources, table skinResources
function BattleGateBossRushEX.GetPreloadList(self)
	local shipResources, skinResources = ys.Battle.BattleGateBossRush.GetPreloadList(self)

	return shipResources, skinResources
end

return BattleGateBossRushEX
