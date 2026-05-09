--- @class BattleGateHPShareActBoss : HP共享活动Boss Gate
local BattleGateHPShareActBoss = class("BattleGateHPShareActBoss")

ys.Battle.BattleGateHPShareActBoss = BattleGateHPShareActBoss
BattleGateHPShareActBoss.__name = "BattleGateHPShareActBoss"

--- 进入HP共享活动Boss战斗
--- @param self BattleGateHPShareActBoss
--- @param sendData table 发送数据
function BattleGateHPShareActBoss.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local activityData = getProxy(ActivityProxy):getActivityById(actId)
	local configId = activityData:getConfig("config_id")
	local worldBossTemplate = pg.activity_event_worldboss[configId]
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
	local activityTemplate = pg.activity_template[actId]
	local ticketId = pg.activity_event_worldboss[activityTemplate.config_id].ticket

	if playerProxy:getRawData():getResource(ticketId) <= 0 then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noTicket"))

		return
	end

	if hasOilCost and costSum > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab

	sendData.ShipVertify()

	--- 请求成功回调
	local function onSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startCost
			})
		end

		local ticketRes = id2res(ticketId)

		playerData:consume({
			[ticketRes] = 1
		})

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

--- 退出HP共享活动Boss
--- @param self BattleGateHPShareActBoss
--- @param callback table 回调对象
function BattleGateHPShareActBoss.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_HP_SHARE_ACT_BOSS]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local score = ys.Battle.BattleConst.BattleScore.S

	self.statistics._battleScore = score

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
		callback.addShipsExp(result.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = score > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(result, mainFleet, subFleet)

		callback.GeneralPlayerCosume(SYSTEM_HP_SHARE_ACT_BOSS, isWin, totalOil, result.player_exp)

		local finishData = {
			system = SYSTEM_HP_SHARE_ACT_BOSS,
			statistics = self.statistics,
			score = score,
			drops = drops,
			commanderExps = commanderExp,
			result = result.result,
			extraDrops = extraDrops
		}

		activityData:AddStage(self.stageId)
		getProxy(ActivityProxy):updateActivity(activityData)
		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表，复用ActBoss的逻辑
--- @param self BattleGateHPShareActBoss
--- @return table shipResources, table skinResources
function BattleGateHPShareActBoss.GetPreloadList(self)
	local shipResources, skinResources = ys.Battle.BattleGateActBoss.GetPreloadList(self)

	return shipResources, skinResources
end

return BattleGateHPShareActBoss
