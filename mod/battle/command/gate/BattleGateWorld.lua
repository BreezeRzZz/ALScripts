--- @class BattleGateWorld : 大世界战斗Gate
local BattleGateWorld = class("BattleGateWorld")

ys.Battle.BattleGateWorld = BattleGateWorld
BattleGateWorld.__name = "BattleGateWorld"

--- 进入大世界战斗
--- @param self BattleGateWorld
--- @param sendData table BeginStageCommand实例
function BattleGateWorld.Entrance(self, sendData)
	local world = nowWorld()

	if BeginStageCommand.DockOverload() then
		world:TriggerAutoFight(false)

		return
	end

	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_WORLD]
	local hasOilCost = costTemplate.oil_cost > 0
	local shipIdList = {}
	local startGold = 0
	local startOil = 0
	local endGold = 0
	local endOil = 0
	local fleet = world:GetActiveMap():GetFleet()
	local fleetShipVOs = fleet:GetShipVOs(false)

	for _, shipVO in ipairs(fleetShipVOs) do
		shipIdList[#shipIdList + 1] = shipVO.id
	end

	local startCost, endCost = fleet:GetCost()
	local startGold = startCost.gold
	local startOil = startCost.oil
	local totalGold = startCost.gold + endCost.gold
	local totalOil = startCost.oil + endCost.oil
	local playerData = playerProxy:getData()

	if hasOilCost and totalOil > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local hpRate = self.hpRate

	sendData.ShipVertify()

	--- 服务器验证成功回调
	local function onServerSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = startOil
			})
		end

		if costTemplate.enter_energy_cost > 0 and not exFlag then
			local energyCost = pg.gameset.battle_consume_energy.key_value

			for _, shipVO in ipairs(fleetShipVOs) do
				shipVO:cosumeEnergy(energyCost)
				bayProxy:updateShip(shipVO)
			end
		end

		playerProxy:updatePlayer(playerData)

		local stageData = {
			prefabFleet = fleetPrefab,
			stageId = stageId,
			system = SYSTEM_WORLD,
			token = tokenData.key,
			hpRate = hpRate
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_WORLD, shipIdList, {
		stageId
	}, onServerSuccess, onServerFail)
end

--- 退出大世界战斗，处理WriteBack和结算
--- @param self BattleGateWorld
--- @param callback table 回调对象
function BattleGateWorld.Exit(self, callback)
	if callback.CheaterVertify() then
		return
	end

	local costTemplate = pg.battle_cost_template[SYSTEM_WORLD]
	local battleScore = self.statistics._battleScore
	local extraGold = 0
	local shipList = {}
	local activeMap = nowWorld():GetActiveMap()
	local fleet = activeMap:GetFleet()
	local shipVOs = fleet:GetShipVOs(true)
	local startCost, endCost = fleet:GetCost()
	local endOil = endCost.oil

	if self.statistics.submarineAid then
		local subFleet = activeMap:GetSubmarineFleet()

		assert(subFleet, "submarine fleet not exist.")

		local subShipVOs = subFleet:GetTeamShipVOs(TeamType.Submarine, true)

		for _, shipVO in ipairs(subShipVOs) do
			if self.statistics[shipVO.id] then
				table.insert(shipVOs, shipVO)
			end
		end

		local subStartCost, subEndCost = subFleet:GetCost()

		endOil = endOil + subEndCost.oil
	end

	local generalPackage = callback.GeneralPackage(self, shipVOs)

	--- 结算成功回调
	local function onSuccess(serverResult)
		callback.addShipsExp(serverResult.ship_exp_list, self.statistics, true)

		local commanderExp = callback.GenerateCommanderExp(serverResult, fleet, activeMap:GetSubmarineFleet())

		self.statistics.mvpShipID = serverResult.mvp

		local drops, extraDrops = callback:GeneralLoot(serverResult)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C

		callback.GeneralPlayerCosume(SYSTEM_WORLD, isWin, endOil, serverResult.player_exp, exFlag)

		self.hpDropInfo = serverResult.hp_drop_info

		local finishData = {
			system = SYSTEM_WORLD,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = commanderExp,
			result = serverResult.result,
			extraDrops = extraDrops
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
		activeMap:WriteBack(isWin, self)
	end

	callback:SendRequest(generalPackage, onSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateWorld
--- @return table shipResources, table skinResources
function BattleGateWorld.GetPreloadList(self)
	local shipList = {}
	local skinList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local world = nowWorld()
	local activeMap = world:GetActiveMap()
	local fleet = activeMap:GetFleet()

	for _, shipVO in ipairs(fleet:GetShipVOs(true)) do
		table.insert(shipList, shipVO)
	end

	local buffIdList, buffResList = activeMap:getFleetBattleBuffs(fleet)

	if world:GetSubAidFlag() == true then
		local subFleet = activeMap:GetSubmarineFleet()
		local subShipVOs = subFleet:GetTeamShipVOs(TeamType.Submarine, false)

		for _, shipVO in ipairs(subShipVOs) do
			table.insert(shipList, shipVO)
		end

		local subBuffs, subBuffsRes = activeMap:getFleetBattleBuffs(subFleet)

		for _, buff in ipairs(subBuffs) do
			table.insert(buffIdList, buff)
		end

		for _, res in ipairs(subBuffsRes) do
			table.insert(buffResList, res)
		end
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local auraBuffs = activeMap:GetChapterAuraBuffs()
	local aidBuffs = activeMap:GetChapterAidBuffs()

	for _, buffGroup in pairs(aidBuffs) do
		for _, buff in ipairs(buffGroup) do
			table.insert(auraBuffs, buff)
		end
	end

	local auraBuffRes = resMgr.GetResFromBuffList(auraBuffs)

	for _, res in ipairs(auraBuffRes) do
		table.insert(shipResources, res)
	end

	local stageEnemy = activeMap:GetCell(fleet.row, fleet.column):GetStageEnemy()
	local enemyBuffs = table.mergeArray(stageEnemy:GetBattleLuaBuffs(), activeMap:GetBattleLuaBuffs(WorldMap.FactionEnemy, stageEnemy))

	for _, buff in ipairs(enemyBuffs) do
		table.insert(buffIdList, buff)
	end

	local buffIdRes = resMgr.GetResFromBuffIDList(buffIdList)

	for _, res in ipairs(buffIdRes) do
		table.insert(shipResources, res)
	end

	local commanderBuffs = resMgr.GetCommanderBuffRes(buffResList)

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateWorld
