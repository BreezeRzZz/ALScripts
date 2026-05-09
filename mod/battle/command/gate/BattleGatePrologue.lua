--- @class BattleGatePrologue : 序章战斗Gate，直接使用PROLOGUE_DUNGEON进入
local BattleGatePrologue = class("BattleGatePrologue")

ys.Battle.BattleGatePrologue = BattleGatePrologue
BattleGatePrologue.__name = "BattleGatePrologue"

--- 进入序章战斗
--- @param self BattleGatePrologue
--- @param sendData table 发送数据
function BattleGatePrologue.Entrance(self, sendData)
	local dungeonID = PROLOGUE_DUNGEON
	local dungeonTemplateID = pg.expedition_data_template[dungeonID].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local stageData = {
		prefabFleet = fleetPrefab,
		stageId = dungeonID,
		system = SYSTEM_PROLOGUE
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出序章战斗
--- @param self BattleGatePrologue
--- @param callback table 回调对象
function BattleGatePrologue.Exit(self, callback)
	callback:sendNotification(GAME.FINISH_STAGE_DONE, {
		system = SYSTEM_PROLOGUE
	})
end

return BattleGatePrologue
