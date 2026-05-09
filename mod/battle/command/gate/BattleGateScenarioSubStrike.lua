--- @class BattleGateScenarioSubStrike : 关卡潜艇支援打击Gate
local BattleGateScenarioSubStrike = class("BattleGateScenarioSubStrike")

ys.Battle.BattleGateScenarioSubStrike = BattleGateScenarioSubStrike
BattleGateScenarioSubStrike.__name = "BattleGateScenarioSubStrike"

--- 进入潜艇支援打击
--- @param self BattleGateScenarioSubStrike
--- @param sendData table 发送数据
function BattleGateScenarioSubStrike.Entrance(self, sendData)
	local stageId = getProxy(ChapterProxy):getActiveChapter():getConfigMiscArg("submarine_support")
	local stageData = {
		prefabFleet = {},
		stageId = stageId,
		system = SYSTEM_SCENARIO_SUB_STRIKE
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出潜艇支援打击，写回关卡数据
--- @param self BattleGateScenarioSubStrike
--- @param callback table 回调对象
function BattleGateScenarioSubStrike.Exit(self, callback)
	local activeChapter = getProxy(ChapterProxy):getActiveChapter()
	local isScoreGood = self.statistics._battleScore >= ys.Battle.BattleConst.BattleScore.S

	activeChapter:writeBack(isScoreGood, self)

	--- 发送结算通知的回调
	local function afterChapterOp()
		callback:sendNotification(GAME.FINISH_STAGE_DONE, {
			statistics = self.statistics,
			score = self.statistics._battleScore,
			system = SYSTEM_SCENARIO_SUB_STRIKE
		})
	end

	callback:sendNotification(GAME.CHAPTER_OP, {
		type = ChapterConst.OPSubStrike,
		arg1 = self.statistics._battleScore,
		callback = afterChapterOp
	})
end

--- 获取预加载资源列表
--- @param self BattleGateScenarioSubStrike
--- @return table shipResources, table skinResources
function BattleGateScenarioSubStrike.GetPreloadList(self)
	local shipList = {}
	local skinList
	local bayProxy = getProxy(BayProxy)
	local chapterProxy = getProxy(ChapterProxy)
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local subShipIds = chapterProxy:getActiveChapter():getChapterSupportFleet():getTeamByName(TeamType.Submarine)

	for _, shipId in ipairs(subShipIds) do
		local shipVO = bayProxy:getShipById(shipId)

		table.insert(shipList, shipVO)
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)

	return shipResources, skinResources
end

return BattleGateScenarioSubStrike
