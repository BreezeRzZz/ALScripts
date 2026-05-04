ys = ys or {}

local ys = ys

ys.Battle.BattleDelayWave = class("BattleDelayWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleDelayWave.__name = "BattleDelayWave"

local BattleDelayWave = ys.Battle.BattleDelayWave

--- 波次类型：延迟等待波
--- 不生成任何单位，仅等待指定时间后自动通过。
--- 用于关卡中插入固定的等待间隔（如剧情空档、阶段过渡）。
function BattleDelayWave.Ctor(self)
	BattleDelayWave.super.Ctor(self)
end

--- 设置波次数据，从 triggerParams 读取延迟时长
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleDelayWave.SetWaveData(self, waveData)
	BattleDelayWave.super.SetWaveData(self, waveData)

	self._duration = self._param.timeout
end

--- 执行波次：启动一个倒计时 BattleTimer，到期后调用 doPass()
--- 定时器的 delay 参数来自 self._duration（即 triggerParams.timeout）
function BattleDelayWave.DoWave(self)
	BattleDelayWave.super.DoWave(self)

	local delayTimer
	-- 定时器到期回调：延迟结束，标记波次通过
	local function onTimerEnds()
		self:doPass()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(delayTimer)
	end

	delayTimer = pg.TimeMgr.GetInstance():AddBattleTimer("delayWave", 1, self._duration, onTimerEnds, true)
end
