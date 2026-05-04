ys = ys or {}

local ys = ys

ys.Battle.BattleGuideWave = class("BattleGuideWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleGuideWave.__name = "BattleGuideWave"

local BattleGuideWave = ys.Battle.BattleGuideWave

--- 波次类型：新手引导波
--- 触发新手引导系统 (NewGuideMgr)，展示指定的引导步骤。
--- 引导播放完成后通过回调 doPass()；若引导功能禁用或系列引导已结束则跳过。
function BattleGuideWave.Ctor(self)
	BattleGuideWave.super.Ctor(self)
end

--- 设置波次数据，从 triggerParams 读取引导配置
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleGuideWave.SetWaveData(self, waveData)
	BattleGuideWave.super.SetWaveData(self, waveData)

	self._guideType = self._param.type or 0  -- 引导类型：0=普通引导，1=系列引导
	self._guideStep = self._param.id          -- 引导步骤 ID
	self._event     = self._param.event       -- 引导触发事件名
end

--- 执行波次：根据引导状态分三种情况处理
--- 1. 引导功能禁用 -> 直接通过
--- 2. 系列引导已全部完成 -> 视为失败跳过（避免不必要的等待）
--- 3. 否则播放引导步骤，播放完成后回调 doPass()
function BattleGuideWave.DoWave(self)
	BattleGuideWave.super.DoWave(self)

	if not pg.NewGuideMgr.ENABLE_GUIDE then
		-- 引导系统全局关闭
		self:doPass()
	elseif self._guideType == 1 and pg.SeriesGuideMgr.GetInstance():isEnd() then
		-- 系列引导已全部完成，该波次无需再播放
		self:doFail()
	else
		-- 播放指定引导步骤
		pg.NewGuideMgr.GetInstance():Play(self._guideStep, {
			self._event
		}, function()
			self:doPass()
		end)
	end
end
