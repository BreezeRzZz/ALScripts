ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleSubmarineFuncVO = class("BattleSubmarineFuncVO")
ys.Battle.BattleSubmarineFuncVO.__name = "BattleSubmarineFuncVO"

local BattleSubmarineFuncVO = ys.Battle.BattleSubmarineFuncVO

--- @class BattleSubmarineFuncVO
--- @param self BattleSubmarineFuncVO
--- @param maxValue number 最大CD时间（下潜/上浮/冲刺/切换的冷却时长）
--- 构造函数，设置初始充能值为maxValue，激活状态为true
function BattleSubmarineFuncVO.Ctor(self, maxValue)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._current = maxValue
	self._defaultMax = maxValue
	self._active = true

	self:ResetMax()
end

--- 每帧更新：若激活且充能未满，根据时间差更新充能进度
--- @param self BattleSubmarineFuncVO
--- @param timeStamp number 当前战斗时间戳
function BattleSubmarineFuncVO.Update(self, timeStamp)
	if self._active and self._current < self._max then
		-- 从上次重置开始算起经过的时间
		local elapsed = timeStamp - self._reloadStartTime

		if elapsed >= self._max then
			-- CD已完成，恢复到最大值
			self:ResetMax()

			self._current = self._max
			self._reloadStartTime = nil

			self:DispatchOverLoadChange()
		else
			-- CD进行中，更新当前充能
			self._current = elapsed
		end
	end
end

--- 设置激活状态（控制是否允许充能恢复）
--- @param self BattleSubmarineFuncVO
--- @param active boolean 是否激活
function BattleSubmarineFuncVO.SetActive(self, active)
	self._active = active
end

--- 重置当前充能为0，记录开始充能的时间
--- @param self BattleSubmarineFuncVO
function BattleSubmarineFuncVO.ResetCurrent(self)
	self._current = 0
	self._reloadStartTime = pg.TimeMgr.GetInstance():GetCombatTime()

	self:DispatchOverLoadChange()
end

--- 将最大值重置为默认最大值
--- @param self BattleSubmarineFuncVO
function BattleSubmarineFuncVO.ResetMax(self)
	self._max = self._defaultMax
end

--- 手动设置最大值（用于Buff等动态修改CD）
--- @param self BattleSubmarineFuncVO
--- @param max number 新的最大值
function BattleSubmarineFuncVO.SetMax(self, max)
	self._max = max
end

--- 获取当前最大值
--- @param self BattleSubmarineFuncVO
--- @return number 当前最大CD值
function BattleSubmarineFuncVO.GetMax(self)
	return self._max
end

--- 获取总容量（潜艇功能VO固定返回0，用_count代替）
--- @param self BattleSubmarineFuncVO
--- @return number 0
function BattleSubmarineFuncVO.GetTotal(self)
	return 0
end

--- 获取当前充能值
--- @param self BattleSubmarineFuncVO
--- @return number 当前充能值
function BattleSubmarineFuncVO.GetCurrent(self)
	return self._current
end

--- 判断是否处于过载状态（充能未满）
--- @param self BattleSubmarineFuncVO
--- @return boolean 是否过载
function BattleSubmarineFuncVO.IsOverLoad(self)
	return self._current < self._max
end

--- 派发过载状态变更事件
--- @param self BattleSubmarineFuncVO
function BattleSubmarineFuncVO.DispatchOverLoadChange(self)
	local overLoadEvent = ys.Event.New(ys.Battle.BattleEvent.OVER_LOAD_CHANGE)

	self:DispatchEvent(overLoadEvent)
end

--- 销毁清理：移除定时器并分离事件分发器
--- @param self BattleSubmarineFuncVO
function BattleSubmarineFuncVO.Dispose(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._focusTimer)

	self._focusTimer = nil

	ys.EventDispatcher.DetachEventDispatcher(self)
end
