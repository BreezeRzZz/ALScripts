ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleSubmarineAidVO = class("BattleSubmarineAidVO", ys.Battle.BattlePlayerWeaponVO)
ys.Battle.BattleSubmarineAidVO.__name = "BattleSubmarineAidVO"

local BattleSubmarineAidVO = ys.Battle.BattleSubmarineAidVO

-- 潜艇特殊技能VO，GCD复用空袭支援的冷却配置
BattleSubmarineAidVO.GCD = BattleConfig.AirAssistCFG.GCD

--- @class BattleSubmarineAidVO : BattlePlayerWeaponVO
--- @param self BattleSubmarineAidVO
--- 构造函数，调用父类Ctor并传入GCD
function BattleSubmarineAidVO.Ctor(self)
	BattleSubmarineAidVO.super.Ctor(self, BattleSubmarineAidVO.GCD)
end

--- 设置潜艇特殊技能是否可用
--- @param self BattleSubmarineAidVO
--- @param useable boolean 是否可用
function BattleSubmarineAidVO.SetUseable(self, useable)
	self._useable = useable
	self._current = useable and 1 or 0
	self._max = 1

	self:DispatchOverLoadChange()
	self:DispatchCountChange()
end

--- 获取是否可用
--- @param self BattleSubmarineAidVO
--- @return boolean 是否可用
function BattleSubmarineAidVO.GetUseable(self)
	return self._useable
end

--- 检测是否过载（充能未满或次数耗尽）
--- @param self BattleSubmarineAidVO
--- @return boolean 是否过载
function BattleSubmarineAidVO.IsOverLoad(self)
	return self._current < self._max or self._count < 1
end

--- 使用特殊技能，减少一次次数并重置充能
--- @param self BattleSubmarineAidVO
function BattleSubmarineAidVO.Cast(self)
	self._count = self._count - 1

	self:resetCurrent()
	self:DispatchOverLoadChange()
	self:DispatchCountChange()
end
