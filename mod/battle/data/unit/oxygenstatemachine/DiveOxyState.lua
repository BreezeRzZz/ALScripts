ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class DiveOxyState : IOxyState
--- 下潜状态：潜艇完全没入水中，免疫非反潜武器的伤害。
--- 此状态下不可见、不可被常规武器锁定、不可使用任何武器（空武器列表）。
--- 碰撞数据设置为免疫状态(UnitCldImmune)。
---
--- 【武器可用性】无武器可用（返回空表{}）
--- 【氧气消耗】无（基类DoUpdateOpy为空操作——氧气在OxyState.UpdateOxygen驱动下通过其他机制消耗）
--- 【状态转换条件】无主动转换逻辑（转换由OxyState管理器调度）
ys.Battle.DiveOxyState = class("DiveOxyState", ys.Battle.IOxyState)
ys.Battle.DiveOxyState.__name = "DiveOxyState"

local DiveOxyState = ys.Battle.DiveOxyState

--- 构造函数
--- @param self DiveOxyState
--- @return nil
function DiveOxyState.Ctor(self)
	DiveOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 下潜状态：无任何武器可用
--- @param self DiveOxyState
--- @return table: 空表
function DiveOxyState.GetWeaponUseableList(self)
	return {}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为DIVE（下潜），如果前后状态不同则设为碰撞免疫
--- @param self DiveOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function DiveOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	-- 潜航状态变化时，设置碰撞免疫（免疫非反潜武器）
	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldImmune(unit)
	end
end

--- 获取潜航状态：DIVE（下潜）
--- @param self DiveOxyState
--- @return number: BattleConst.OXY_STATE.DIVE
function DiveOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.DIVE
end

--- 获取气泡标记：下潜时产生气泡（暴露位置）
--- @param self DiveOxyState
--- @return boolean: true
function DiveOxyState.GetBubbleFlag(self)
	return true
end

--- 下潜状态对敌方不可见（免疫常规武器锁定）
--- @param self DiveOxyState
--- @return boolean: false
function DiveOxyState.IsVisible(self)
	return false
end

--- 氧气条可见：下潜时需要显示氧气条
--- @param self DiveOxyState
--- @return boolean: true
function DiveOxyState.GetBarVisible(self)
	return true
end

--- 非自由模式
--- @param self DiveOxyState
--- @return boolean: false
function DiveOxyState.RunMode(self)
	return false
end
