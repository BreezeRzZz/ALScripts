ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class IdleOxyState : IOxyState
--- 待机状态：潜艇的初始/默认状态。潜艇在水面待命。
--- 对敌方不可见（战斗中初始隐藏），无武器可用。
--- 碰撞数据设为FLOAT（非免疫），但IsVisible返回false。
---
--- 【武器可用性】无武器可用（返回空表{}）
--- 【氧气消耗/恢复】无（基类DoUpdateOxy为空操作）
--- 【状态转换条件】允许切换到下潜(UpdateDive返回true)
ys.Battle.IdleOxyState = class("IdleOxyState", ys.Battle.IOxyState)
ys.Battle.IdleOxyState.__name = "IdleOxyState"

local IdleOxyState = ys.Battle.IdleOxyState

--- 构造函数
--- @param self IdleOxyState
--- @return nil
function IdleOxyState.Ctor(self)
	IdleOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 待机状态：无武器可用
--- @param self IdleOxyState
--- @return table: 空表
function IdleOxyState.GetWeaponUseableList(self)
	return {}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为FLOAT，如果前后状态不同则启用碰撞
--- @param self IdleOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function IdleOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldEnable(unit)
	end
end

--- 获取潜航状态：FLOAT（待机时在水面）
--- @param self IdleOxyState
--- @return number: BattleConst.OXY_STATE.FLOAT
function IdleOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.FLOAT
end

--- 获取气泡标记：待机时不产生气泡
--- @param self IdleOxyState
--- @return boolean: false
function IdleOxyState.GetBubbleFlag(self)
	return false
end

--- 待机状态对敌方不可见（战斗中潜艇初始隐藏）
--- @param self IdleOxyState
--- @return boolean: false
function IdleOxyState.IsVisible(self)
	return false
end

--- 氧气条可见：待机时显示氧气条
--- @param self IdleOxyState
--- @return boolean: true
function IdleOxyState.GetBarVisible(self)
	return true
end

--- 非自由模式
--- @param self IdleOxyState
--- @return boolean: false
function IdleOxyState.RunMode(self)
	return false
end

--- 允许下潜：从待机可以切换到下潜
--- @param self IdleOxyState
--- @return boolean: true
function IdleOxyState.UpdateDive(self)
	return true
end
