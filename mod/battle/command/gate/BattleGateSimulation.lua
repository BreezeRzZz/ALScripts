--- @class BattleGateSimulation : 模拟战Gate（皮肤体验等）
local BattleGateSimulation = class("BattleGateSimulation")

ys.Battle.BattleGateSimulation = BattleGateSimulation
BattleGateSimulation.__name = "BattleGateSimulation"

--- 进入模拟战斗
--- @param self BattleGateSimulation
--- @param sendData table 发送数据
function BattleGateSimulation.Entrance(self, sendData)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local stageData = {
		prefabFleet = fleetPrefab,
		stageId = stageId,
		system = SYSTEM_SIMULATION,
		exitCallback = self.exitCallback,
		warnMsg = self.warnMsg
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出模拟战斗
--- @param self BattleGateSimulation
--- @param callback table 回调对象
function BattleGateSimulation.Exit(self, callback)
	callback:sendNotification(GAME.FINISH_STAGE_DONE, {
		system = SYSTEM_SIMULATION,
		exitCallback = self.exitCallback
	})
end

return BattleGateSimulation
