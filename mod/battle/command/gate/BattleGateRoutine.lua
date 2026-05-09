--- @class BattleGateRoutine : 日常副本Gate
local BattleGateRoutine = class("BattleGateRoutine")

ys.Battle.BattleGateRoutine = BattleGateRoutine
BattleGateRoutine.__name = "BattleGateRoutine"

--- 进入日常副本战斗
--- @param self BattleGateRoutine
--- @param sendData table 发送数据
function BattleGateRoutine.Entrance(self, sendData)
	if not sendData.LegalFleet(self.mainFleetId) then
		return
	end

	if BeginStageCommand.DockOverload() then
		return
	end

	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local fleetProxy = getProxy(FleetProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_ROUTINE]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local fleet = fleetProxy:getFleetById(self.mainFleetId)
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local startCost = fleet:getStartCost().oil
	local costSum = fleet:GetCostSum().oil
	local playerData = playerProxy:getData()

	if hasOilCost and costSum > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local mainFleetId = self.mainFleetId
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab

	sendData.ShipVertify()

	--- 请求成功回调，消耗资源并发送开始通知
	local function onSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startCost
			})
		end

		if costTemplate.enter_energy_cost > 0 and not exFlag then
			local energyCost = pg.gameset.battle_consume_energy.key_value

			for _, ship in ipairs(sortShips) do
				ship:cosumeEnergy(energyCost)
				bayProxy:updateShip(ship)
			end
		end

		playerProxy:updatePlayer(playerData)

		local stageData = {
			mainFleetId = mainFleetId,
			prefabFleet = fleetPrefab,
			stageId = stageId,
			system = SYSTEM_ROUTINE,
			token = tokenData.key
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 请求失败回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_ROUTINE, shipIdList, {
		stageId
	}, onSuccess, onFail)
end

--- 退出日常副本，处理奖励和快速战斗
--- @param self BattleGateRoutine
--- @param callback table 回调对象
function BattleGateRoutine.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_ROUTINE]
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
		callback.addShipsExp(result.ship_exp_list, self.statistics, true)

		self.statistics.mvpShipID = result.mvp

		local drops, extraDrops = callback:GeneralLoot(result)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C

		callback.GeneralPlayerCosume(SYSTEM_ROUTINE, isWin, endOilCost, result.player_exp, exFlag)

		local dailyLevelProxy = getProxy(DailyLevelProxy)

		if isWin then
			dailyLevelProxy.data[dailyLevelProxy.dailyLevelId] = (dailyLevelProxy.data[dailyLevelProxy.dailyLevelId] or 0) + 1
		end

		if battleScore == ys.Battle.BattleConst.BattleScore.S then
			dailyLevelProxy:AddQuickStage(self.stageId)
		end

		local finishData = {
			system = SYSTEM_ROUTINE,
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

return BattleGateRoutine
