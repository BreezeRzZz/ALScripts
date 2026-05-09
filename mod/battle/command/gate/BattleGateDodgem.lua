--- @class BattleGateDodgem : 躲弹幕小游戏Gate
local BattleGateDodgem = class("BattleGateDodgem")

ys.Battle.BattleGateDodgem = BattleGateDodgem
BattleGateDodgem.__name = "BattleGateDodgem"

--- 进入躲弹幕战斗
--- @param self BattleGateDodgem
--- @param sendData table 发送数据
function BattleGateDodgem.Entrance(self, sendData)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local stageData = {
		prefabFleet = fleetPrefab,
		stageId = stageId,
		system = SYSTEM_DODGEM
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出躲弹幕战斗，上报活动分数
--- @param self BattleGateDodgem
--- @param callback table 回调对象
function BattleGateDodgem.Exit(self, callback)
	local battleData = self
	local activityData = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_DODGEM)

	callback:sendNotification(GAME.ACTIVITY_OPERATION, {
		cmd = 1,
		activity_id = activityData and activityData.id,
		statistics = battleData.statistics,
		arg1 = battleData.statistics._battleScore,
		arg2 = battleData.statistics.dodgemResult.score
	})
end

return BattleGateDodgem
