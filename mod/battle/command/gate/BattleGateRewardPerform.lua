--- @class BattleGateRewardPerform : 奖励表演关Gate，有actId时为活动关否则为远征表演关
local BattleGateRewardPerform = class("BattleGateRewardPerform")

ys.Battle.BattleGateRewardPerform = BattleGateRewardPerform
BattleGateRewardPerform.__name = "BattleGateRewardPerform"

--- 进入奖励表演战斗
--- @param self BattleGateRewardPerform
--- @param sendData table 发送数据
function BattleGateRewardPerform.Entrance(self, sendData)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local mainFleetId

	if not fleetPrefab or #fleetPrefab == 0 then
		mainFleetId = self.mainFleetId
	end

	local stageData = {
		mainFleetId = mainFleetId,
		prefabFleet = fleetPrefab,
		stageId = stageId,
		system = SYSTEM_REWARD_PERFORM,
		actId = self.actId
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出奖励表演，根据是否有actId走不同的结算流程
--- @param self BattleGateRewardPerform
--- @param callback table 回调对象
function BattleGateRewardPerform.Exit(self, callback)
	local battleData = self

	if self.actId then
		if battleData.statistics._battleScore > ys.Battle.BattleConst.BattleScore.C then
			callback:sendNotification(GAME.ACTIVITY_OPERATION, {
				cmd = 2,
				activity_id = self.actId,
				statistics = battleData.statistics,
				arg1 = battleData.stageId
			})
		else
			callback:sendNotification(GAME.FINISH_STAGE_DONE, {
				statistics = self.statistics,
				score = self.statistics._battleScore,
				system = SYSTEM_REWARD_PERFORM
			})
		end
	else
		local expeditionActivity = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_EXPEDITION)
		local dataList = expeditionActivity.data1_list
		local stageKey

		for index = 1, #dataList do
			if bit.rshift(dataList[index], 4) == battleData.stageId then
				stageKey = index

				break
			end
		end

		callback:sendNotification(GAME.ACTIVITY_OPERATION, {
			cmd = 3,
			activity_id = expeditionActivity and expeditionActivity.id,
			statistics = battleData.statistics,
			arg1 = battleData.statistics._battleScore,
			arg2 = stageKey
		})
	end
end

return BattleGateRewardPerform
