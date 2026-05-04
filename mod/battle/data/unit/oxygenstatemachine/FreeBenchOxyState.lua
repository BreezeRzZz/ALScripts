ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class FreeBenchOxyState : IOxyState
--- 自由待机状态：自由模式(Free Mode)下的待机/休息状态。
--- 介于自由下潜(Dive)和自由上浮(Float)之间的状态。
--- 此状态下不可见（IsVisible=false），无武器可用，
--- 碰撞数据为DIVE(免疫)，但GetDiveState返回FLOAT，
--- 氧气持续恢复(OxyRecover, STATE_FREE_BENCH)。
--- 特点：产生气泡(GetBubbleFlag=true，暴露位置)但自身不可见。
---
--- 【武器可用性】无武器可用（返回空表{}）
--- 【氧气消耗/恢复】恢复氧气(OxyRecover, STATE_FREE_BENCH)
--- 【状态转换条件】无主动转换逻辑（RunMode标识自由模式）
ys.Battle.FreeBenchOxyState = class("FreeBenchOxyState", ys.Battle.IOxyState)
ys.Battle.FreeBenchOxyState.__name = "FreeBenchOxyState"

local FreeBenchOxyState = ys.Battle.FreeBenchOxyState

--- 构造函数
--- @param self FreeBenchOxyState
--- @return nil
function FreeBenchOxyState.Ctor(self)
	FreeBenchOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 自由待机状态：无武器可用
--- @param self FreeBenchOxyState
--- @return table: 空表
function FreeBenchOxyState.GetWeaponUseableList(self)
	return {}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为FLOAT，如果前后状态不同则设为碰撞免疫
--- 注意：碰撞设为免疫但Surface标记为FLOAT
--- @param self FreeBenchOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function FreeBenchOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldImmune(unit)
	end
end

--- 获取潜航状态：FLOAT（自由待机时标记为浮航状态）
--- @param self FreeBenchOxyState
--- @return number: BattleConst.OXY_STATE.FLOAT
function FreeBenchOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.FLOAT
end

--- 获取气泡标记：自由待机时产生气泡（暴露位置）
--- @param self FreeBenchOxyState
--- @return boolean: true
function FreeBenchOxyState.GetBubbleFlag(self)
	return true
end

--- 执行氧气更新：自由待机时恢复氧气（使用STATE_FREE_BENCH速率）
--- @param self FreeBenchOxyState
--- @param oxyState OxyState: 氧气状态管理器
--- @return nil
function FreeBenchOxyState.DoUpdateOxy(self, oxyState)
	oxyState:OxyRecover(ys.Battle.OxyState.STATE_FREE_BENCH)
end

--- 自由待机状态对敌方不可见
--- @param self FreeBenchOxyState
--- @return boolean: false
function FreeBenchOxyState.IsVisible(self)
	return false
end

--- 氧气条可见：自由待机时显示氧气条
--- @param self FreeBenchOxyState
--- @return boolean: true
function FreeBenchOxyState.GetBarVisible(self)
	return true
end

--- 自由模式
--- @param self FreeBenchOxyState
--- @return boolean: true
function FreeBenchOxyState.RunMode(self)
	return true
end
