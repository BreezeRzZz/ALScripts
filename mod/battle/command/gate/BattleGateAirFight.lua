--- @class BattleGateAirFight : 航空战Gate，处理航空战斗的进入和结算
local BattleGateAirFight = class("BattleGateAirFight")

ys.Battle.BattleGateAirFight = BattleGateAirFight
BattleGateAirFight.__name = "BattleGateAirFight"

--- 进入航空战斗
--- @param self BattleGateAirFight
--- @param sendData table 发送数据（包含stageId等）
function BattleGateAirFight.Entrance(self, sendData)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab
	local stageData = {
		prefabFleet = fleetPrefab,
		stageId = stageId,
		system = SYSTEM_AIRFIGHT
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出航空战斗，根据评分处理活动进度
--- @param self BattleGateAirFight
--- @param callback table 回调对象
function BattleGateAirFight.Exit(self, callback)
	local activityData = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_AIRFIGHT_BATTLE)

	if self.statistics._battleScore >= ys.Battle.BattleConst.BattleScore.B and activityData and not activityData:isEnd() then
		local maxProgress = activityData:GetMaxProgress()
		local perDayCount = activityData:GetPerDayCount()
		local perLevelProgress = activityData:GetPerLevelProgress()
		local levelCount = maxProgress / perLevelProgress
		local completedProgress = 0

		for levelIndex = 1, levelCount do
			completedProgress = completedProgress + (activityData:getKVPList(1, levelIndex) or 0)
		end

		local timeMgr = pg.TimeMgr.GetInstance()
		local daysPassed = timeMgr:DiffDay(activityData.data1, timeMgr:GetServerTime()) + 1

		if completedProgress < math.min(daysPassed * perDayCount, maxProgress) then
			local stageId = self.stageId
			local stagesConfig = activityData:getConfig("config_client").stages
			local stageOrder = table.indexof(stagesConfig, stageId)
			local currentLevel = math.floor((stageOrder - 1) / math.floor(#stagesConfig / levelCount)) + 1
			local levelProgress = activityData:getKVPList(1, currentLevel) or 0
			local isLevelRewarded = activityData:getKVPList(2, currentLevel) == 1

			if levelProgress < perLevelProgress and not isLevelRewarded then
				callback:sendNotification(GAME.ACTIVITY_OPERATION, {
					cmd = 1,
					activity_id = activityData and activityData.id,
					arg1 = currentLevel,
					statistics = self.statistics
				})

				return
			end
		end
	end

	callback:sendNotification(GAME.FINISH_STAGE_DONE, {
		statistics = self.statistics,
		score = self.statistics._battleScore,
		system = SYSTEM_AIRFIGHT
	})
end

return BattleGateAirFight
