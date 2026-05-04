ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class RetreatOxyState : IOxyState
--- 撤退状态：潜艇撤退回场外。此状态下潜艇可见、碰撞启用、无武器可用。
--- 氧气条不显示。撤退时潜艇浮出水面(碰撞FLOAT状态)。
---
--- 【武器可用性】无武器可用（返回空表{}）
--- 【氧气消耗/恢复】无（基类DoUpdateOxy为空操作）
--- 【状态转换条件】无主动转换逻辑（转换由OxyState管理器调度）
ys.Battle.RetreatOxyState = class("RetreatOxyState", ys.Battle.IOxyState)
ys.Battle.RetreatOxyState.__name = "RetreatOxyState"

local RetreatOxyState = ys.Battle.RetreatOxyState

--- 构造函数
--- @param self RetreatOxyState
--- @return nil
function RetreatOxyState.Ctor(self)
	RetreatOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 撤退状态：无武器可用
--- @param self RetreatOxyState
--- @return table: 空表
function RetreatOxyState.GetWeaponUseableList(self)
	return {}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为FLOAT（上浮），如果前后状态不同则启用碰撞
--- @param self RetreatOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function RetreatOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldEnable(unit)
	end
end

--- 获取潜航状态：FLOAT（撤退时浮出水面）
--- @param self RetreatOxyState
--- @return number: BattleConst.OXY_STATE.FLOAT
function RetreatOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.FLOAT
end

--- 获取气泡标记：撤退时不产生气泡
--- @param self RetreatOxyState
--- @return boolean: false
function RetreatOxyState.GetBubbleFlag(self)
	return false
end

--- 撤退状态对敌方可见
--- @param self RetreatOxyState
--- @return boolean: true
function RetreatOxyState.IsVisible(self)
	return true
end

--- 氧气条不可见：撤退时不显示氧气条
--- @param self RetreatOxyState
--- @return boolean: false
function RetreatOxyState.GetBarVisible(self)
	return false
end

--- 非自由模式
--- @param self RetreatOxyState
--- @return boolean: false
function RetreatOxyState.RunMode(self)
	return false
end
