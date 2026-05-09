--- @class BattleGateChallenge : 挑战模式Gate
local BattleGateChallenge = class("BattleGateChallenge")

ys.Battle.BattleGateChallenge = BattleGateChallenge
BattleGateChallenge.__name = "BattleGateChallenge"

--- 进入挑战模式战斗
--- @param self BattleGateChallenge
--- @param sendData table 发送数据
function BattleGateChallenge.Entrance(self, sendData)
	local mode = self.mode
	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local challengeProxy = getProxy(ChallengeProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_CHALLENGE]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local challengeInfo = challengeProxy:getUserChallengeInfo(mode)
	local regularFleetShips = challengeInfo:getRegularFleet():getShips(false)

	for _, ship in ipairs(regularFleetShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local playerData = playerProxy:getData()

	if hasOilCost and endOil > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local level = challengeInfo:getLevel()
	local nextStageID = challengeInfo:getNextStageID()
	local extraData = {
		level,
		mode
	}

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

			for _, ship in ipairs(regularFleetShips) do
				ship:cosumeEnergy(energyCost)
				bayProxy:updateShip(ship)
			end
		end

		playerProxy:updatePlayer(playerData)

		local stageData = {
			prefabFleet = {},
			stageId = nextStageID,
			system = SYSTEM_CHALLENGE,
			actId = actId,
			token = tokenData.key,
			mode = mode
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_CHALLENGE, shipIdList, {
		nextStageID,
		extraData
	}, onSuccess, onFail)
end

--- 退出挑战模式
--- @param self BattleGateChallenge
--- @param callback table 回调对象
function BattleGateChallenge.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_CHALLENGE]
	local fleetProxy = getProxy(FleetProxy)
	local challengeProxy = getProxy(ChallengeProxy)
	local battleScore = self.statistics._battleScore
	local oilUsed = 0
	local shipList = {}
	local commanderList = {}
	local mode = self.mode
	local challengeInfo = challengeProxy:getUserChallengeInfo(mode)
	local regularFleet = challengeInfo:getRegularFleet():getShips(true)

	for _, ship in ipairs(regularFleet) do
		table.insert(commanderList, ship)
	end

	local extraData = {
		challengeInfo:getLevel(),
		mode
	}
	local oilCost = 0
	local generalPackage = callback.GeneralPackage(self, commanderList)

	generalPackage.data2 = extraData

	--- 结算成功回调
	local function onSuccess(result)
		callback.addShipsExp(result.ship_exp_list, self.statistics)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C

		callback.GeneralPlayerCosume(SYSTEM_CHALLENGE, isWin, oilCost, result.player_exp, exFlag)

		local finishData = {
			system = SYSTEM_CHALLENGE,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = {},
			result = result.result,
			extraDrops = extraDrops
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)

		-- 更新挑战模式中每艘船的HP
		local shipUIDList = challengeInfo:getShipUIDList()

		local function updateShipHP(uid)
			local shipStat = self.statistics[uid]

			if shipStat then
				challengeInfo:updateShipHP(uid, shipStat.bp)
			end
		end

		for uid, _ in pairs(shipUIDList) do
			updateShipHP(uid)
		end
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateChallenge
--- @return table shipResources, table skinResources
function BattleGateChallenge.GetPreloadList(self)
	local shipList = {}
	local buffList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local challengeInfo = getProxy(ChallengeProxy):getUserChallengeInfo(self.mode)
	local regularFleet = challengeInfo:getRegularFleet()
	local regularShips = regularFleet:getShips(false)

	for _, ship in ipairs(regularShips) do
		table.insert(shipList, ship)
	end

	local regularBuffs = regularFleet:buildBattleBuffList()
	local subFleet = challengeInfo:getSubmarineFleet()
	local subShips = subFleet:getShips(false)

	for _, ship in ipairs(subShips) do
		table.insert(shipList, ship)
	end

	for _, buff in ipairs(subFleet:buildBattleBuffList()) do
		table.insert(regularBuffs, buff)
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local commanderBuffs = resMgr.GetCommanderBuffRes(regularBuffs)

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateChallenge
