--- @class BattleGateSubmarine : 潜艇任务Gate
local BattleGateSubmarine = class("BattleGateSubmarine")

ys.Battle.BattleGateSubmarine = BattleGateSubmarine
BattleGateSubmarine.__name = "BattleGateSubmarine"

--- 进入潜艇任务战斗
--- @param self BattleGateSubmarine
--- @param sendData table 发送数据
function BattleGateSubmarine.Entrance(self, sendData)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local stageData = {
		prefabFleet = fleetPrefab,
		stageId = stageId,
		system = SYSTEM_SUBMARINE_RUN
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出潜艇任务，上报活动结果
--- @param self BattleGateSubmarine
--- @param callback table 回调对象
function BattleGateSubmarine.Exit(self, callback)
	local activityData = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_SUBMARINE_RUN)

	callback:sendNotification(GAME.ACTIVITY_OPERATION, {
		cmd = 1,
		activity_id = activityData and activityData.id,
		statistics = self.statistics,
		arg1 = self.statistics._battleScore,
		arg2 = self.statistics.subRunResult.score
	})
end

return BattleGateSubmarine
