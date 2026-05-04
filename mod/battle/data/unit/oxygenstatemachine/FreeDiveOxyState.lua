ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class FreeDiveOxyState : IOxyState
--- 自由下潜状态：自由模式(Free Mode)下的下潜状态。
--- 与普通DiveOxyState类似，但RunMode返回true表示处于自由航行模式。
--- 此状态下不可见、仅潜航武器可用、氧气持续消耗。
---
--- 【武器可用性】仅潜航武器(DIVE)可用
--- 【氧气消耗/恢复】消耗氧气(OxyConsume)——自由潜航时持续消耗
--- 【状态转换条件】无主动转换逻辑（RunMode标识自由模式，由管理器调度）
ys.Battle.FreeDiveOxyState = class("FreeDiveOxyState", ys.Battle.IOxyState)
ys.Battle.FreeDiveOxyState.__name = "FreeDiveOxyState"

local FreeDiveOxyState = ys.Battle.FreeDiveOxyState

--- 构造函数
--- @param self FreeDiveOxyState
--- @return nil
function FreeDiveOxyState.Ctor(self)
	FreeDiveOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 自由下潜状态：仅潜航武器可用
--- @param self FreeDiveOxyState
--- @return table: {BattleConst.OXY_STATE.DIVE}
function FreeDiveOxyState.GetWeaponUseableList(self)
	return {
		BattleConst.OXY_STATE.DIVE
	}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为DIVE，如果前后状态不同则设为碰撞免疫
--- @param self FreeDiveOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function FreeDiveOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldImmune(unit)
	end
end

--- 获取潜航状态：DIVE（自由下潜）
--- @param self FreeDiveOxyState
--- @return number: BattleConst.OXY_STATE.DIVE
function FreeDiveOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.DIVE
end

--- 获取气泡标记：自由下潜时产生气泡
--- @param self FreeDiveOxyState
--- @return boolean: true
function FreeDiveOxyState.GetBubbleFlag(self)
	return true
end

--- 执行氧气更新：自由下潜时消耗氧气
--- @param self FreeDiveOxyState
--- @param oxyState OxyState: 氧气状态管理器
--- @return nil
function FreeDiveOxyState.DoUpdateOxy(self, oxyState)
	oxyState:OxyConsume()
end

--- 自由下潜状态对敌方不可见
--- @param self FreeDiveOxyState
--- @return boolean: false
function FreeDiveOxyState.IsVisible(self)
	return false
end

--- 氧气条可见：自由下潜时显示氧气条
--- @param self FreeDiveOxyState
--- @return boolean: true
function FreeDiveOxyState.GetBarVisible(self)
	return true
end

--- 自由模式
--- @param self FreeDiveOxyState
--- @return boolean: true
function FreeDiveOxyState.RunMode(self)
	return true
end
