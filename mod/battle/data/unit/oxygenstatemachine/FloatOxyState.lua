ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr

--- @class FloatOxyState : IOxyState
--- 上浮状态：潜艇浮出水面，可以被敌方正常攻击。
--- 此状态下潜艇可见，可被所有武器类型锁定。
--- 潜航武器和浮航武器均可使用。
--- 在此状态中氧气会持续恢复(OxyRecover, STATE_FLOAT速率)。
---
--- 【武器可用性】潜航武器(DIVE) + 浮航武器(FLOAT) 均可使用
--- 【氧气消耗/恢复】恢复氧气(OxyRecover, STATE_FLOAT)
--- 【状态转换条件】允许切换到下潜(UpdateDive返回true)
ys.Battle.FloatOxyState = class("FloatOxyState", ys.Battle.IOxyState)
ys.Battle.FloatOxyState.__name = "FloatOxyState"

local FloatOxyState = ys.Battle.FloatOxyState

--- 构造函数
--- @param self FloatOxyState
--- @return nil
function FloatOxyState.Ctor(self)
	FloatOxyState.super.Ctor(self)
end

--- 获取可使用的武器类型列表
--- 上浮状态：潜航武器和浮航武器均可使用
--- @param self FloatOxyState
--- @return table: {BattleConst.OXY_STATE.DIVE, BattleConst.OXY_STATE.FLOAT}
function FloatOxyState.GetWeaponUseableList(self)
	return {
		BattleConst.OXY_STATE.DIVE,
		BattleConst.OXY_STATE.FLOAT
	}
end

--- 更新碰撞数据
--- 将单位的碰撞状态设为FLOAT（上浮），如果前后状态不同则启用碰撞
--- @param self FloatOxyState: 新状态
--- @param unit BattleWalkUnit: 潜艇单位
--- @param prevState IOxyState: 切换前状态
--- @return nil
function FloatOxyState.UpdateCldData(self, unit, prevState)
	local prevDiveState = prevState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	unit:GetCldData().Surface = currentDiveState

	-- 从下潜切换到上浮时，启用碰撞（可被敌方正常攻击）
	if prevDiveState ~= currentDiveState then
		BattleAttr.UnitCldEnable(unit)
	end
end

--- 获取潜航状态：FLOAT（上浮）
--- @param self FloatOxyState
--- @return number: BattleConst.OXY_STATE.FLOAT
function FloatOxyState.GetDiveState(self)
	return BattleConst.OXY_STATE.FLOAT
end

--- 获取气泡标记：上浮时不产生气泡
--- @param self FloatOxyState
--- @return boolean: false
function FloatOxyState.GetBubbleFlag(self)
	return false
end

--- 执行氧气更新：上浮时恢复氧气
--- @param self FloatOxyState
--- @param oxyState OxyState: 氧气状态管理器
--- @return nil
function FloatOxyState.DoUpdateOxy(self, oxyState)
	oxyState:OxyRecover(ys.Battle.OxyState.STATE_FLOAT)
end

--- 上浮状态对敌方可见
--- @param self FloatOxyState
--- @return boolean: true
function FloatOxyState.IsVisible(self)
	return true
end

--- 氧气条不可见：上浮时不需要显示氧气条
--- @param self FloatOxyState
--- @return boolean: false
function FloatOxyState.GetBarVisible(self)
	return false
end

--- 非自由模式
--- @param self FloatOxyState
--- @return boolean: false
function FloatOxyState.RunMode(self)
	return false
end

--- 允许下潜：返回true表示可以从浮航切换到潜航
--- @param self FloatOxyState
--- @return boolean: true
function FloatOxyState.UpdateDive(self)
	return true
end
