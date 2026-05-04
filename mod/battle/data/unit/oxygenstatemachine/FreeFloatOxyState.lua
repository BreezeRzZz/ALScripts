ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class FreeFloatOxyState : IOxyState
--- 自由上浮状态：自由模式(Free Mode)下的上浮状态。
--- 与普通FloatOxyState类似，但RunMode返回true表示处于自由航行模式。
--- 此状态下可见、潜航和浮航武器均可使用、氧气持续恢复。
--- 氧气条可见(与普通FloatOxyState不同)。
---
--- 【武器可用性】潜航武器(DIVE) + 浮航武器(FLOAT) 均可使用
--- 【氧气消耗/恢复】恢复氧气(OxyRecover, STATE_FREE_FLOAT)
--- 【状态转换条件】无主动转换逻辑（RunMode标识自由模式）
ys.Battle.FreeFloatOxyState = class("FreeFloatOxyState", ys.Battle.IOxyState)
ys.Battle.FreeFloatOxyState.__name = "FreeFloatOxyState"

local FreeFloatOxyState = ys.Battle.FreeFloatOxyState

--- 构造函数
--- @param self FreeFloatOxyState
--- @return nil
function FreeFloatOxyState.Ctor(self)
	FreeFloatOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 自由上浮状态：潜航武器和浮航武器均可使用
--- @param self FreeFloatOxyState
--- @return table: {BattleConst.OXY_STATE.DIVE, BattleConst.OXY_STATE.FLOAT}
function FreeFloatOxyState.GetWeaponUseableList(self)
	return {
		BattleConst.OXY_STATE.DIVE,
		BattleConst.OXY_STATE.FLOAT
	}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为FLOAT，如果前后状态不同则启用碰撞
--- @param self FreeFloatOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function FreeFloatOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldEnable(unit)
	end
end

--- 获取潜航状态：FLOAT（自由上浮）
--- @param self FreeFloatOxyState
--- @return number: BattleConst.OXY_STATE.FLOAT
function FreeFloatOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.FLOAT
end

--- 获取气泡标记：自由上浮时不产生气泡
--- @param self FreeFloatOxyState
--- @return boolean: false
function FreeFloatOxyState.GetBubbleFlag(self)
	return false
end

--- 执行氧气更新：自由上浮时恢复氧气（使用STATE_FREE_FLOAT速率）
--- @param self FreeFloatOxyState
--- @param oxyState OxyState: 氧气状态管理器
--- @return nil
function FreeFloatOxyState.DoUpdateOxy(self, oxyState)
	oxyState:OxyRecover(ys.Battle.OxyState.STATE_FREE_FLOAT)
end

--- 自由上浮状态对敌方可见
--- @param self FreeFloatOxyState
--- @return boolean: true
function FreeFloatOxyState.IsVisible(self)
	return true
end

--- 氧气条可见：自由上浮时显示氧气条
--- @param self FreeFloatOxyState
--- @return boolean: true
function FreeFloatOxyState.GetBarVisible(self)
	return true
end

--- 自由模式
--- @param self FreeFloatOxyState
--- @return boolean: true
function FreeFloatOxyState.RunMode(self)
	return true
end
