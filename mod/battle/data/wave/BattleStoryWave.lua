ys = ys or {}

local ys = ys

ys.Battle.BattleStoryWave = class("BattleStoryWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleStoryWave.__name = "BattleStoryWave"

local BattleStoryWave = ys.Battle.BattleStoryWave

--- 波次类型：剧情/过场动画波
--- 播放指定 ID 的章节剧情（ChapterStory）。
--- 会判断关卡进度、自律模式、复刻状态等条件决定是否播放。
--- 剧情播放完成后调用 doPass/doFail 并传递剧情标记。
function BattleStoryWave.Ctor(self)
	BattleStoryWave.super.Ctor(self)
end

--- 设置波次数据，从 triggerParams.id 读取剧情 ID
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleStoryWave.SetWaveData(self, waveData)
	BattleStoryWave.super.SetWaveData(self, waveData)

	self._storyID = self._param.id
end

--- 执行波次：
--- 仅在 SYSTEM_SCENARIO 模式下才做条件判断（主线关卡）。
--- 条件分支：
---   - progress 检查：如果当前章节进度 + progress_boss 不足指定进度，跳过剧情
---   - 复刻检查：如果是复刻关，跳过剧情
---   - 自律模式：记录自律开关状态
--- 若所有条件满足，播放剧情；否则直接 doPass
function BattleStoryWave.DoWave(self)
	BattleStoryWave.super.DoWave(self)

	local shouldPlay = true    -- 是否应该播放剧情
	local isAutoFight = false  -- 是否自律模式

	if ys.Battle.BattleDataProxy.GetInstance():GetInitData().battleType == SYSTEM_SCENARIO then
		local chapter = getProxy(ChapterProxy):getActiveChapter(true)

		isAutoFight = chapter and chapter:IsAutoFight() or isAutoFight

		-- 进度条件检查：章节进度不足时不播放
		if self._param.progress then
			if not chapter then
				shouldPlay = false
			elseif math.min(chapter.progress + chapter:getConfig("progress_boss"), 100) < self._param.progress then
				shouldPlay = false
			end
		end

		-- 复刻检查：复刻关不播放剧情
		local map = chapter and getProxy(ChapterProxy):getMapById(chapter:getConfig("map"))

		if map and map:getRemaster() then
			shouldPlay = false
		end
	end

	if shouldPlay then
		-- 隐藏已有的消息框，准备播放剧情
		pg.MsgboxMgr.GetInstance():hide()

		-- 剧情结束回调：isError=true 时 doFail，否则 doPass
		-- 将剧情标记(flag)传递给 doPass/doFail，用于后续波次的 blockFlags 检查
		local function onStoryEnd(isError, flag)
			if isError then
				self:doFail(flag)
			else
				self:doPass(flag)
			end
		end

		local isMemory = ys.Battle.BattleDataProxy.GetInstance():GetInitData().isMemory

		ChapterOpCommand.PlayChapterStory(self._storyID, onStoryEnd, isAutoFight, isMemory)
		gcAll()
	else
		self:doPass()
	end
end

--- 剧情通过：将剧情标记写入 WaveFlags，供后续波次的 blockFlags 条件检查
--- @param flag string 剧情标记
function BattleStoryWave.doPass(self, flag)
	ys.Battle.BattleDataProxy.GetInstance():AddWaveFlag(flag)
	BattleStoryWave.super.doPass(self)
end

--- 剧情失败：同样写入 WaveFlags 标记
--- @param flag string 剧情标记
function BattleStoryWave.doFail(self, flag)
	ys.Battle.BattleDataProxy.GetInstance():AddWaveFlag(flag)
	BattleStoryWave.super.doFail(self)
end
