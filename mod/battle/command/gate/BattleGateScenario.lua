--- @class BattleGateScenario : 主线关卡战斗Gate
local BattleGateScenario = class("BattleGateScenario")

ys.Battle.BattleGateScenario = BattleGateScenario
BattleGateScenario.__name = "BattleGateScenario"

--- 进入主线关卡战斗
--- @param self BattleGateScenario
--- @param sendData table BeginStageCommand实例
function BattleGateScenario.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		getProxy(ChapterProxy):StopAutoFight(ChapterConst.AUTOFIGHT_STOP_REASON.DOCK_OVERLOADED)

		return
	end

	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_SCENARIO]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local chapter = getProxy(ChapterProxy):getActiveChapter()
	local fleet = chapter.fleet
	local fleetShips = fleet:getShips(false)

	for _, ship in ipairs(fleetShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local startCost, endCost = chapter:getFleetCost(fleet, self.stageId)
	local startGold = startCost.gold
	local startOil = startCost.oil
	local totalGold = startCost.gold + endCost.gold
	local totalOil = startCost.oil + endCost.oil
	local playerData = playerProxy:getData()

	if hasOilCost and totalOil > playerData.oil then
		getProxy(ChapterProxy):StopAutoFight(ChapterConst.AUTOFIGHT_STOP_REASON.OIL_LACK)

		if not ItemTipPanel.ShowOilBuyTip(totalOil) then
			pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))
		end

		return
	end

	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab

	sendData.ShipVertify()

	local isExtraMode

	if chapter:getPlayType() == ChapterConst.TypeExtra then
		isExtraMode = true
	end

	local extraCostRate = chapter:GetExtraCostRate()

	--- 服务器验证成功回调
	local function onServerSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startOil
			})
		end

		if costTemplate.enter_energy_cost > 0 and not isExtraMode then
			local energyCost = pg.gameset.battle_consume_energy.key_value * extraCostRate

			for _, shipId in ipairs(shipIdList) do
				local ship = bayProxy:getShipById(shipId)

				if ship then
					ship:cosumeEnergy(energyCost)
					bayProxy:updateShip(ship)
				end
			end
		end

		playerProxy:updatePlayer(playerData)

		local stageData = {
			prefabFleet = fleetPrefab,
			stageId = stageId,
			system = SYSTEM_SCENARIO,
			token = tokenData.key,
			exitCallback = tokenData.exitCallback
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
		getProxy(ChapterProxy):StopAutoFight(ChapterConst.AUTOFIGHT_STOP_REASON.UNKNOWN)
	end

	BeginStageCommand.SendRequest(SYSTEM_SCENARIO, shipIdList, {
		stageId
	}, onServerSuccess, onServerFail)
end

--- 退出主线关卡，处理writeBack、掉落记录和结果发送
--- @param self BattleGateScenario
--- @param callback table 回调对象
function BattleGateScenario.Exit(self, callback)
	if callback.CheaterVertify() then
		return
	end

	local costTemplate = pg.battle_cost_template[SYSTEM_SCENARIO]
	local fleetProxy = getProxy(FleetProxy)
	local chapterProxy = getProxy(ChapterProxy)
	local battleScore = self.statistics._battleScore
	local extraGold = 0
	local endOil = 0
	local shipList = {}
	local chapter = chapterProxy:getActiveChapter()
	local isExtraMode = chapter:getPlayType() == ChapterConst.TypeExtra
	local fleet = chapter.fleet
	local fleetShips = fleet:getShips(true)

	for _, ship in ipairs(fleetShips) do
		table.insert(shipList, ship)
	end

	local stageId = self.stageId
	local startCost, endCost = chapter:getFleetCost(fleet, stageId)
	local endGold = endCost.gold
	local endOil = endCost.oil
	local extraCostRate = chapter:GetExtraCostRate()

	if self.statistics.submarineAid then
		local subFleet = chapter:GetSubmarineFleet()

		if subFleet then
			local subExtraOil = 0

			for _, ship in ipairs(subFleet:getShipsByTeam(TeamType.Submarine, true)) do
				if self.statistics[ship.id] then
					table.insert(shipList, ship)

					subExtraOil = subExtraOil + ship:getEndBattleExpend()
				end
			end

			if isExtraMode then
				subExtraOil = 0
			end

			endOil = endOil + math.min(subExtraOil, chapter:GetLimitOilCost(true)) * extraCostRate
		else
			originalPrint("finish stage error: can not find submarine fleet.")
		end
	end

	local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C

	chapter:writeBack(isWin, self)
	chapterProxy:updateChapter(chapter)

	local generalPackage = callback.GeneralPackage(self, shipList)

	--- 结算成功回调
	local function onSuccess(serverResult)
		callback.addShipsExp(serverResult.ship_exp_list, self.statistics, true)

		local commanderExp = callback.GenerateCommanderExp(serverResult, chapterProxy:getActiveChapter().fleet, chapter:GetSubmarineFleet())

		self.statistics.mvpShipID = serverResult.mvp

		local drops, extraDrops = callback:GeneralLoot(serverResult)

		callback.GeneralPlayerCosume(SYSTEM_SCENARIO, isWin, endOil, serverResult.player_exp, isExtraMode)

		local finishData = {
			system = SYSTEM_SCENARIO,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = commanderExp,
			result = serverResult.result,
			extraDrops = extraDrops,
			exitCallback = self.exitCallback
		}

		chapterProxy:updateActiveChapterShips()

		local updatedChapter = chapterProxy:getActiveChapter()

		updatedChapter:writeDrops(drops)
		chapterProxy:updateChapter(updatedChapter)

		if PlayerConst.CanDropItem(drops) then
			local allDrops = {}

			for _, drop in ipairs(drops) do
				table.insert(allDrops, drop)
			end

			for _, extraDrop in ipairs(extraDrops) do
				extraDrop.riraty = true

				table.insert(allDrops, extraDrop)
			end

			local loopChapter = getProxy(ChapterProxy):getActiveChapter(true)

			if loopChapter then
				if loopChapter:isLoop() then
					getProxy(ChapterProxy):AddExtendChapterDataArray(loopChapter.id, "TotalDrops", allDrops)
				end

				loopChapter:writeDrops(allDrops)
			end
		end

		local lastUnlockMapId = chapterProxy:getLastUnlockMap().id
		local prevUnlockMapId = chapterProxy:getLastUnlockMap().id

		if Map.lastMap and prevUnlockMapId ~= lastUnlockMapId and lastUnlockMapId < prevUnlockMapId then
			Map.autoNextPage = true
		end

		callback:sendNotification(GAME.CHAPTER_BATTLE_RESULT_REQUEST, {
			callback = function()
				callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
			end
		})
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateScenario
--- @return table shipResources, table skinResources
function BattleGateScenario.GetPreloadList(self)
	local shipList = {}
	local skinList
	local chapterProxy = getProxy(ChapterProxy)
	local chapter = chapterProxy:getActiveChapter()
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local fleet = chapter.fleet
	local fleetShips = fleet:getShips(false)

	for _, ship in ipairs(fleetShips) do
		table.insert(shipList, ship)
	end

	local buffIdList, buffResList = chapter:getFleetBattleBuffs(fleet)
	local auraBuffs = chapterProxy.GetChapterAuraBuffs(chapter)
	local aidBuffs = chapterProxy.GetChapterAidBuffs(chapter)

	for _, buffGroup in pairs(aidBuffs) do
		for _, buff in ipairs(buffGroup) do
			table.insert(auraBuffs, buff)
		end
	end

	local subAidFlag, subFleet = chapterProxy.getSubAidFlag(chapter, self.stageId)

	if subAidFlag == true or subAidFlag > 0 then
		local subShips = subFleet:getShipsByTeam(TeamType.Submarine, false)

		for _, ship in ipairs(subShips) do
			table.insert(shipList, ship)
		end

		local subBuffs, subBuffsRes = chapter:getFleetBattleBuffs(subFleet)

		for _, buff in ipairs(subBuffs) do
			table.insert(buffIdList, buff)
		end

		for _, res in ipairs(subBuffsRes) do
			table.insert(buffResList, res)
		end
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local commanderBuffs = resMgr.GetCommanderBuffRes(buffResList)

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	local buffIdResources = resMgr.GetResFromBuffIDList(buffIdList)

	for _, res in ipairs(buffIdResources) do
		table.insert(shipResources, res)
	end

	local auraResources = resMgr.GetResFromBuffList(auraBuffs)

	for _, res in ipairs(auraResources) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateScenario
