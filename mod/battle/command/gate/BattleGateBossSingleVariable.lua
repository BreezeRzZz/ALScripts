--- @class BattleGateBossSingleVariable : Boss单人可变挑战Gate，支持variableBuffList
local BattleGateBossSingleVariable = class("BattleGateBossSingleVariable")

ys.Battle.BattleGateBossSingleVariable = BattleGateBossSingleVariable
BattleGateBossSingleVariable.__name = "BattleGateBossSingleVariable"

--- 进入Boss单人可变挑战
--- @param self BattleGateBossSingleVariable
--- @param sendData table 发送数据
function BattleGateBossSingleVariable.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_SINGLE_VARIABLE]
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
			system = SYSTEM_BOSS_SINGLE_VARIABLE,
			actId = actId,
			token = tokenData.key,
			variableBuffList = self.variableBuffList,
			continuousBattleTimes = self.continuousBattleTimes,
			totalBattleTimes = self.totalBattleTimes,
			useVariableTicket = self.useVariableTicket
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_BOSS_SINGLE_VARIABLE, shipIdList, {
		stageId,
		self.variableBuffList
	}, onSuccess, onFail)
end

--- 退出Boss单人可变挑战
--- @param self BattleGateBossSingleVariable
--- @param callback table 回调对象
function BattleGateBossSingleVariable.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_BOSS_SINGLE_VARIABLE]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local activityData = getProxy(ActivityProxy):getActivityById(self.actId)
	local oilLimit = activityData:GetEnemyDataByStageId(self.stageId):GetOilLimit()
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

	processFleetCost(mainFleet, oilLimit[1] or 0)

	if self.statistics.submarineAid then
		subFleet = activityFleets[self.mainFleetId + Fleet.MEGA_SUBMARINE_FLEET_OFFSET]

		if subFleet then
			processFleetCost(subFleet, oilLimit[2] or 0)
		else
			originalPrint("finish stage error: can not find submarin fleet.")
		end
	end

	local generalPackage = callback.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	if activityData.data1 > 0 and self.useVariableTicket == 1 then
		generalPackage.extra_param = 1
	else
		generalPackage.extra_param = 0
	end

	--- 结算成功回调
	local function onSuccess(result)
		callback.addShipsExp(result.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(result, mainFleet, subFleet)

		callback.GeneralPlayerCosume(SYSTEM_BOSS_SINGLE_VARIABLE, isWin, totalOil, result.player_exp)

		if isWin then
			local activity = getProxy(ActivityProxy):getActivityById(self.actId)
			local enemyData = activity:GetEnemyDataByStageId(self.stageId)

			activity:AddPassStage(enemyData:GetExpeditionId())
			getProxy(ActivityProxy):updateActivity(activity)

			if self.useVariableTicket == 1 then
				activity.data1 = math.max(activity.data1 - 1, 0)
			end
		end

		local finishData = {
			system = SYSTEM_BOSS_SINGLE_VARIABLE,
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
--- @param self BattleGateBossSingleVariable
--- @return table shipResources, table skinResources
function BattleGateBossSingleVariable.GetPreloadList(self)
	local shipList = {}
	local buffIdList = {}
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
			table.insert(buffIdList, buff)
		end
	end

	local subFleet = activityFleets[self.mainFleetId + Fleet.MEGA_SUBMARINE_FLEET_OFFSET]

	if subFleet then
		local subShipIds = subFleet:getTeamByName(TeamType.Submarine)

		for _, shipId in ipairs(subShipIds) do
			table.insert(shipList, bayProxy:getShipById(shipId))
		end

		local subBuffs = subFleet:buildBattleBuffList()

		for _, buff in ipairs(subBuffs) do
			table.insert(buffIdList, buff)
		end
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local activityData = getProxy(ActivityProxy):getActivityById(self.actId)
	local stageBuffRes = resMgr.GetResFromBuffIDList(activityData:GetBuffIdsByStageId(self.stageId))

	for _, res in ipairs(stageBuffRes) do
		table.insert(shipResources, res)
	end

	local strategyDataTemplate = pg.strategy_data_template
	local strategyBuffIds = {}

	for _, buffId in ipairs(self.variableBuffList) do
		table.insert(strategyBuffIds, strategyDataTemplate[buffId].buff_id)
	end

	local variableBuffRes = resMgr.GetResFromBuffIDList(strategyBuffIds)

	for _, res in ipairs(variableBuffRes) do
		table.insert(shipResources, res)
	end

	local commanderBuffs = resMgr.GetCommanderBuffRes(buffIdList)

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateBossSingleVariable
