--- @class BattleGateBossExperiment : Boss实验战斗Gate，复用ActBoss的预加载逻辑
local BattleGateBossExperiment = class("BattleGateBossExperiment")

ys.Battle.BattleGateBossExperiment = BattleGateBossExperiment
BattleGateBossExperiment.__name = "BattleGateBossExperiment"

--- 进入Boss实验战斗
--- @param self BattleGateBossExperiment
--- @param sendData table 发送数据
function BattleGateBossExperiment.Entrance(self, sendData)
	local actId = self.actId
	local mainFleetId = self.mainFleetId
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local stageData = {
		mainFleetId = mainFleetId,
		actId = actId,
		prefabFleet = fleetPrefab,
		stageId = stageId,
		system = SYSTEM_BOSS_EXPERIMENT
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出Boss实验战斗，固定S评分
--- @param self BattleGateBossExperiment
--- @param callback table 回调对象
function BattleGateBossExperiment.Exit(self, callback)
	local score = ys.Battle.BattleConst.BattleScore.S
	local result = {
		system = SYSTEM_BOSS_EXPERIMENT,
		statistics = self.statistics,
		score = score,
		commanderExps = {}
	}

	callback:sendNotification(GAME.FINISH_STAGE_DONE, result)
end

--- 获取预加载资源列表，复用ActBoss的逻辑
--- @param self BattleGateBossExperiment
--- @return table shipResources, table skinResources
function BattleGateBossExperiment.GetPreloadList(self)
	local shipResources, skinResources = ys.Battle.BattleGateActBoss.GetPreloadList(self)

	return shipResources, skinResources
end

return BattleGateBossExperiment
