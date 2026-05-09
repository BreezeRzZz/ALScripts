--- @class BattleGateLimitChallenge : 极限挑战Gate
local BattleGateLimitChallenge = class("BattleGateLimitChallenge")

ys.Battle.BattleGateLimitChallenge = BattleGateLimitChallenge
BattleGateLimitChallenge.__name = "BattleGateLimitChallenge"
BattleGateLimitChallenge.BattleSystem = SYSTEM_LIMIT_CHALLENGE

--- 进入极限挑战战斗
--- @param self BattleGateLimitChallenge
--- @param sendData table 发送数据
function BattleGateLimitChallenge.Entrance(self, sendData)
	local challengeFleetId = FleetProxy.CHALLENGE_FLEET_ID

	if not sendData.LegalFleet(challengeFleetId) then
		return
	end

	local playerProxy = getProxy(PlayerProxy)
	local playerData = playerProxy:getData()
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local limitChallengeProxy = getProxy(LimitChallengeProxy)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local fleet = fleetProxy:getFleetById(FleetProxy.CHALLENGE_FLEET_ID)
	local shipIdList = {}
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local costTemplate = pg.battle_cost_template[BattleGateLimitChallenge.BattleSystem]
	local hasOilCost = costTemplate.oil_cost > 0
	local startOil = 0
	local endOilSum = 0

	if hasOilCost then
		startOil = fleet:getStartCost().oil
		endOilSum = fleet:GetCostSum().oil
	end

	if hasOilCost and endOilSum > playerData.oil then
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
			mainFleetId = mainFleetID,
			prefabFleet = fleetPrefab,
			stageId = stageId,
			system = BattleGateLimitChallenge.BattleSystem,
			token = tokenData.key
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(BattleGateLimitChallenge.BattleSystem, shipIdList, {
		stageId
	}, onSuccess, onFail)
end

--- 退出极限挑战
--- @param self BattleGateLimitChallenge
--- @param callback table 回调对象
function BattleGateLimitChallenge.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[BattleGateLimitChallenge.BattleSystem]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local totalOil = 0
	local shipList = {}
	local commanderIdList = {}
	local stageId = self.stageId
	local mainFleet = fleetProxy:getFleetById(FleetProxy.CHALLENGE_FLEET_ID)
	local subFleet

	if self.statistics.submarineAid then
		subFleet = fleetProxy:getFleetById(FleetProxy.CHALLENGE_SUB_FLEET_ID)
	end

	-- 计算舰队消耗并收集舰船列表
	;(function()
		--- 处理单个舰队的消耗和舰船收集
		local function processFleet(fleet)
			local endOil = fleet:getEndCost().oil

			totalOil = totalOil + endOil

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

	--- 结算成功回调
	local function onSuccess(result)
		callback.addShipsExp(result.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(result, mainFleet, subFleet)

		callback.GeneralPlayerCosume(BattleGateLimitChallenge.BattleSystem, isWin, totalOil, result.player_exp)

		local finishData = {
			system = BattleGateLimitChallenge.BattleSystem,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = commanderExp,
			result = result.result,
			extraDrops = extraDrops
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)

		if isWin then
			local challengeID = LimitChallengeConst.GetChallengeIDByStageID(stageId)
			local totalTime = self.statistics._totalTime

			getProxy(LimitChallengeProxy):setPassTime(challengeID, totalTime)
		end
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateLimitChallenge
--- @return table shipResources, table skinResources
function BattleGateLimitChallenge.GetPreloadList(self)
	local shipList = {}
	local buffList = {}
	local skinList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local mainFleetId = FleetProxy.CHALLENGE_FLEET_ID
	local subFleetId = FleetProxy.CHALLENGE_SUB_FLEET_ID
	local fleetProxy = getProxy(FleetProxy)
	local mainFleet = fleetProxy:getFleetById(mainFleetId)
	local subFleet = fleetProxy:getFleetById(subFleetId)
	local bayProxy = getProxy(BayProxy)

	if mainFleet then
		local shipIds = mainFleet:GetRawShipIds()

		for _, shipId in ipairs(shipIds) do
			table.insert(shipList, bayProxy:getShipById(shipId))
		end

		buffList = mainFleet:buildBattleBuffList()
	end

	if subFleet then
		local shipIds = subFleet:GetRawShipIds()

		for _, shipId in ipairs(shipIds) do
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

	-- 加载极限挑战特定buff资源
	local challengeID = LimitChallengeConst.GetChallengeIDByStageID(self.stageId)
	local buffIds = AcessWithinNull(pg.expedition_constellation_challenge_template[challengeID], "buff_id")

	if buffIds then
		for _, buffEntry in ipairs(buffIds) do
			local buffRes = ys.Battle.BattleDataFunction.GetResFromBuff(buffEntry.ID, buffEntry.LV, {})

			for _, res in ipairs(buffRes) do
				table.insert(shipResources, res)
			end
		end
	end

	return shipResources, skinResources
end

return BattleGateLimitChallenge
