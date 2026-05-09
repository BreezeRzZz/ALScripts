--- @class BattleGateDebug : 调试模式Gate
local BattleGateDebug = class("BattleGateDebug")

ys.Battle.BattleGateDebug = BattleGateDebug
BattleGateDebug.__name = "BattleGateDebug"

--- 进入调试战斗
--- @param self BattleGateDebug
--- @param sendData table 发送数据
function BattleGateDebug.Entrance(self, sendData)
	local fleet = getProxy(FleetProxy):getFleetById(1)

	if fleet == nil or fleet:isEmpty() then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_fleetEmpty"))

		return
	end

	local dungeonID = PROLOGUE_DUNGEON
	local stageData = {
		mainFleetId = 1,
		prefabFleet = {},
		stageId = dungeonID,
		system = SYSTEM_DEBUG
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出调试战斗（空方法）
function BattleGateDebug.Exit()
	return
end

--- 获取预加载资源列表，加载所有飞机资源
--- @param self BattleGateDebug
--- @return table shipResources, table skinResources
function BattleGateDebug.GetPreloadList(self)
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local shipList = {}
	local mainFleet = fleetProxy:getFleetById(self.mainFleetId)
	local mainShips = bayProxy:getShipsByFleet(mainFleet)

	for _, ship in ipairs(mainShips) do
		table.insert(shipList, ship)
	end

	local subFleet = fleetProxy:getFleetById(11)
	local subTeam = subFleet:getTeamByName(TeamType.Submarine)

	for _, shipId in ipairs(subTeam) do
		local shipVO = bayProxy:getShipById(shipId)

		table.insert(shipList, shipVO)
	end

	local shipResources, shipSkins = resMgr.GetPlayerShipResource(shipList, self.system)
	local commanderBuffs = resMgr.GetCommanderBuffRes(subFleet:buildBattleBuffList())

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	local allAircraft = pg.aircraft_template.all

	for _, aircraftId in ipairs(allAircraft) do
		local aircraftRes = resMgr.GetAircraftResource(aircraftId, {})

		for _, res in ipairs(aircraftRes) do
			table.insert(shipResources, res)
		end
	end

	return shipResources, shipSkins
end

return BattleGateDebug
