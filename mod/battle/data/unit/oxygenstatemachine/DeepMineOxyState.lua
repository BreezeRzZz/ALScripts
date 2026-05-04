ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class DeepMineOxyState : IOxyState
--- 深潜/深渊潜航状态：潜艇最深潜水模式。
--- 此状态下不可见、仅潜航武器可用、产生气泡。
--- 无氧气消耗/恢复逻辑（DoUpdateOxy未定义，使用基类空操作）。
--- 注意：此文件有两个UpdateCldData定义，第二个（简化版）会覆盖第一个。
---
--- 【武器可用性】仅潜航武器(DIVE)可用
--- 【氧气消耗/恢复】无（基类DoUpdateOxy为空操作——深潜时氧气可能通过外部逻辑管理）
--- 【状态转换条件】无主动转换逻辑（转换由OxyState管理器调度）
ys.Battle.DeepMineOxyState = class("DeepMineOxyState", ys.Battle.IOxyState)
ys.Battle.DeepMineOxyState.__name = "DeepMineOxyState"

local DeepMineOxyState = ys.Battle.DeepMineOxyState

--- 构造函数
--- @param self DeepMineOxyState
--- @return nil
function DeepMineOxyState.Ctor(self)
	DeepMineOxyState.super.Ctor(self)
end

--- 更新碰撞数据（第一个版本，会被下方第二个版本覆盖）
--- 将单位的碰撞状态设为当前潜航状态(DIVE)
--- @param self DeepMineOxyState
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态（未使用，因为被覆盖）
--- @return nil
function DeepMineOxyState.UpdateCldData(self, unit, prevState)
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState
end

--- 获取可使用的武器类型列表
--- 深潜状态：仅潜航武器可用
--- @param self DeepMineOxyState
--- @return table: {BattleConst.OXY_STATE.DIVE}
function DeepMineOxyState.GetWeaponUseableList(self)
	return {
		BattleConst.OXY_STATE.DIVE
	}
end

--- 更新碰撞数据（第二个版本，覆盖第一个——实际生效的无操作版本）
--- 深潜状态下的碰撞数据更新为空操作
--- @param self DeepMineOxyState
--- @param unit BattleWalkUnit: 潜艇单位
--- @return nil
function DeepMineOxyState.UpdateCldData(self, unit)
	return
end

--- 获取潜航状态：DIVE（深潜）
--- @param self DeepMineOxyState
--- @return number: BattleConst.OXY_STATE.DIVE
function DeepMineOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.DIVE
end

--- 获取气泡标记：深潜时不产生气泡
--- @param self DeepMineOxyState
--- @return boolean: false
function DeepMineOxyState.GetBubbleFlag(self)
	return false
end

--- 深潜状态对敌方不可见
--- @param self DeepMineOxyState
--- @return boolean: false
function DeepMineOxyState.IsVisible(self)
	return false
end

--- 氧气条可见：深潜时显示氧气条
--- @param self DeepMineOxyState
--- @return boolean: true
function DeepMineOxyState.GetBarVisible(self)
	return true
end

--- 非自由模式
--- @param self DeepMineOxyState
--- @return boolean: false
function DeepMineOxyState.RunMode(self)
	return false
end
