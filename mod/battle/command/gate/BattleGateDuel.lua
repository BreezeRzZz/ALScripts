--- @class BattleGateDuel : 演习（竞技场）Gate
local BattleGateDuel = class("BattleGateDuel")

ys.Battle.BattleGateDuel = BattleGateDuel
BattleGateDuel.__name = "BattleGateDuel"

--- 进入演习战斗
--- @param self BattleGateDuel
--- @param sendData table 发送数据
function BattleGateDuel.Entrance(self, sendData)
	local mainFleetId = self.mainFleetId

	if not sendData.LegalFleet(self.mainFleetId) then
		return
	end

	if not getProxy(MilitaryExerciseProxy):getSeasonInfo():canExercise() then
		pg.TipsMgr.GetInstance():ShowTips(i18n("exercise_count_insufficient"))

		return
	end

	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local fleetProxy = getProxy(FleetProxy)
	local subFleet
	local subShips
	local rivalId = self.rivalId
	local rivalData = getProxy(MilitaryExerciseProxy):getRivalById(rivalId)
	local costTemplate = pg.battle_cost_template[SYSTEM_DUEL]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local fleet = fleetProxy:getFleetById(mainFleetId)
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local playerData = playerProxy:getData()

	if hasOilCost and endOil > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	-- 计算对手总等级用于RivalLevelVertiry验校
	local rivalTotalLevel = 0

	for _, mainShip in ipairs(rivalData.mainShips) do
		rivalTotalLevel = rivalTotalLevel + mainShip.level
	end

	for _, vanguardShip in ipairs(rivalData.vanguardShips) do
		rivalTotalLevel = rivalTotalLevel + vanguardShip.level
	end

	RivalLevelVertiry = rivalTotalLevel

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

		local arenaList = ys.Battle.BattleConfig.ARENA_LIST
		local randomStage = arenaList[math.random(#arenaList)]

		playerProxy:updatePlayer(playerData)

		local stageData = {
			mainFleetId = mainFleetId,
			prefabFleet = {},
			stageId = randomStage,
			system = SYSTEM_DUEL,
			rivalId = rivalId,
			token = tokenData.key,
			mode = mode
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_DUEL, shipIdList, {
		rivalId
	}, onSuccess, onFail)
end

--- 退出演习战斗
--- @param self BattleGateDuel
--- @param callback table 回调对象
function BattleGateDuel.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_DUEL]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local oilUsed = 0
	local shipList = {}
	local fleet = fleetProxy:getFleetById(self.mainFleetId)
	local sortShips = bayProxy:getSortShipsByFleet(fleet)
	local endOilCost = fleet:getEndCost().oil
	local generalPackage = callback.GeneralPackage(self, sortShips)

	--- 结算成功回调
	local function onSuccess(result)
		callback.addShipsExp(result.ship_exp_list, self.statistics, false)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C

		callback.GeneralPlayerCosume(SYSTEM_DUEL, isWin, endOilCost, result.player_exp, exFlag)
		getProxy(MilitaryExerciseProxy):reduceExerciseCount()

		local finishData = {
			system = SYSTEM_DUEL,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = {},
			result = result.result,
			extraDrops = extraDrops
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateDuel
--- @return table shipResources, table skinResources
function BattleGateDuel.GetPreloadList(self)
	local shipList = {}
	local skinList
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local mainFleet = fleetProxy:getFleetById(self.mainFleetId)
	local mainShips = bayProxy:getShipsByFleet(mainFleet)

	for _, ship in ipairs(mainShips) do
		table.insert(shipList, ship)
	end

	local rivalShips = getProxy(MilitaryExerciseProxy):getRivalById(self.rivalId):getShips()

	for _, ship in ipairs(rivalShips) do
		table.insert(shipList, ship)
	end

	local shipResources, skinResources = ys.Battle.BattleResourceManager.GetInstance().GetPlayerShipResource(shipList, self.system)

	return shipResources, skinResources
end

return BattleGateDuel
