ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class RaidOxyState : IOxyState
--- 攻击状态：潜艇在水下发射鱼雷进行攻击。
--- 此状态下潜艇不可见（免疫非反潜武器），仅潜航武器(DIVE)可使用。
--- 在此状态中氧气会持续消耗(OxyConsume)。
---
--- 【武器可用性】仅潜航武器(DIVE)可用
--- 【氧气消耗/恢复】消耗氧气(OxyConsume)——攻击时加速消耗
--- 【状态转换条件】无主动转换逻辑（转换由OxyState管理器调度）
ys.Battle.RaidOxyState = class("RaidOxyState", ys.Battle.IOxyState)
ys.Battle.RaidOxyState.__name = "RaidOxyState"

local RaidOxyState = ys.Battle.RaidOxyState

--- 构造函数
--- @param self RaidOxyState
--- @return nil
function RaidOxyState.Ctor(self)
	RaidOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 攻击状态：仅潜航武器可用（在水下发射鱼雷）
--- @param self RaidOxyState
--- @return table: {BattleConst.OXY_STATE.DIVE}
function RaidOxyState.GetWeaponUseableList(self)
	return {
		BattleConst.OXY_STATE.DIVE
	}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为DIVE，如果前后状态不同则设为碰撞免疫
--- @param self RaidOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function RaidOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldImmune(unit)
	end
end

--- 获取潜航状态：DIVE（攻击时在水下）
--- @param self RaidOxyState
--- @return number: BattleConst.OXY_STATE.DIVE
function RaidOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.DIVE
end

--- 获取气泡标记：攻击时产生气泡（暴露位置）
--- @param self RaidOxyState
--- @return boolean: true
function RaidOxyState.GetBubbleFlag(self)
	return true
end

--- 攻击状态对敌方不可见
--- @param self RaidOxyState
--- @return boolean: false
function RaidOxyState.IsVisible(self)
	return false
end

--- 氧气条可见：攻击时显示氧气条
--- @param self RaidOxyState
--- @return boolean: true
function RaidOxyState.GetBarVisible(self)
	return true
end

--- 非自由模式
--- @param self RaidOxyState
--- @return boolean: false
function RaidOxyState.RunMode(self)
	return false
end

--- 执行氧气更新：攻击时消耗氧气
--- @param self RaidOxyState
--- @param oxyState OxyState: 氧气状态管理器
--- @return nil
function RaidOxyState.DoUpdateOxy(self, oxyState)
	oxyState:OxyConsume()
end
