--- @class BattleGateBossSingle : Boss单人挑战Gate
local BattleGateBossSingle = class("BattleGateBossSingle")

ys.Battle.BattleGateBossSingle = BattleGateBossSingle
BattleGateBossSingle.__name = "BattleGateBossSingle"

--- 进入Boss单人挑战战斗
--- @param self BattleGateBossSingle
--- @param sendData table 发送数据
function BattleGateBossSingle.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_SINGLE]
	local hasOilCost = costTemplate.oil_cost > 0
	local activityData = getProxy(ActivityProxy):getActivityById(actId)
	local stageId = self.stageId
	local mainFleetId = self.mainFleetId
	local fleet = fleetProxy:getActivityFleets()[actId][mainFleetId]
	local shipIdList = {}
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local enemyData = activityData:GetEnemyDataByStageId(stageId)
	local successCount = 0
	local playerData = playerProxy:getRawData()
	local costSum = fleet:GetCostSum().oil
	local oilLimit = enemyData:GetOilLimit()
	local actualCost = math.min(costSum, oilLimit[1])

	if hasOilCost and actualCost > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	sendData.ShipVertify()

	local startOil = fleet:getStartCost().oil

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
			mainFleetId = mainFleetId,
			prefabFleet = {},
			stageId = stageId,
			system = SYSTEM_BOSS_SINGLE,
			actId = actId,
			token = tokenData.key,
			continuousBattleTimes = self.continuousBattleTimes,
			totalBattleTimes = self.totalBattleTimes
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_BOSS_SINGLE, shipIdList, {
		stageId
	}, onSuccess, onFail)
end

--- 退出Boss单人挑战
--- @param self BattleGateBossSingle
--- @param callback table 回调对象
function BattleGateBossSingle.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_SINGLE]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local oilLimit = getProxy(ActivityProxy):getActivityById(self.actId):GetEnemyDataByStageId(self.stageId):GetOilLimit()
	local activityFleets = fleetProxy:getActivityFleets()[self.actId]
	local mainFleet = activityFleets[self.mainFleetId]
	local subFleet
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}
	local hasOilCost = costTemplate.oil_cost > 0

	--- 处理单个舰队的消耗
	--- @param fleet table 舰队对象
	--- @param limit number 油量上限
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

	processFleetCost(mainFleet, oilLimit[1] or 0)

	if self.statistics.submarineAid then
		subFleet = activityFleets[self.mainFleetId + 10]

		if subFleet then
			processFleetCost(subFleet, oilLimit[2] or 0)
		else
			originalPrint("finish stage error: can not find submarin fleet.")
		end
	end

	local generalPackage = callback.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	--- 结算成功回调
	local function onSuccess(result)
		callback.addShipsExp(result.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(result, mainFleet, subFleet)

		callback.GeneralPlayerCosume(SYSTEM_BOSS_SINGLE, isWin, totalOil, result.player_exp)

		if isWin then
			local activity = getProxy(ActivityProxy):getActivityById(self.actId)
			local enemyData = activity:GetEnemyDataByStageId(self.stageId)

			activity:AddDailyCount(enemyData.id)
			activity:AddPassStage(enemyData:GetExpeditionId())
			getProxy(ActivityProxy):updateActivity(activity)
		end

		local finishData = {
			system = SYSTEM_BOSS_SINGLE,
			statistics = self.statistics,
			score = battleScore,
			result = result.result,
			drops = drops,
			commanderExps = commanderExp,
			extraDrops = extraDrops
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

			if getProxy(ContextProxy):getCurrentContext():getContextByMediator(BossSingleContinuousOperationMediator) then
				getProxy(ChapterProxy):AddBossSingleRewards(allDrops)
			end
		end

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateBossSingle
--- @return table shipResources, table skinResources
function BattleGateBossSingle.GetPreloadList(self)
	local shipResources, skinResources = ys.Battle.BattleGateActBoss.GetPreloadList(self)
	local activity = getProxy(ActivityProxy):getActivityById(self.actId)
	local buffRes = ys.Battle.BattleResourceManager.GetInstance().GetResFromBuffIDList(activity:GetBuffIdsByStageId(self.stageId))

	for _, res in ipairs(buffRes) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateBossSingle
