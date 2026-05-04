ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class DeadState : IUnitState
--- 死亡状态。单位已死亡，是状态机的终态之一。
---
--- 关键机制：
--- 1. 所有 AddXxxState 均为 no-op（return） —— 死亡后不允许切换到任何其他状态。
---    Dead 状态是"吸收态"：一旦进入，任何状态切换请求都被忽略。
--- 2. OnEnd 调用 target:SendDeadEvent() —— 死亡动画播放完毕后，
---    触发 DYING 事件（BattleUnitEvent.DYING），通知外部系统清理该单位。
---    DeadAction() 会在此之前通过 DeacActionClear 设置 _aliveState=false。
--- 3. GetActionName 根据单位当前是否在水下区分动画：
---    - 水下（OXY_STATE.DIVE） → DEAD_SWIM（水下死亡动画）
---    - 水面 → DEAD（水面死亡动画，带可选 keyOffset 后缀）
--- 4. CacheWeapon = true —— 死亡时不需要缓存新子弹，
---    但返回 true 意味着不会因为进入死亡状态而影响已有的缓存。
ys.Battle.DeadState = class("DeadState", ys.Battle.IUnitState)
ys.Battle.DeadState.__name = "DeadState"

local DeadState = ys.Battle.DeadState

--- @class DeadState
--- @return nil
--- 构造函数
function DeadState.Ctor(self)
	DeadState.super.Ctor()
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许切换 Idle
function DeadState.AddIdleState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许移动
function DeadState.AddMoveState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许移动
function DeadState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许攻击
function DeadState.AddAttackState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 已死亡，不允许再次死亡
function DeadState.AddDeadState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许使用技能
function DeadState.AddSkillState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许施法
function DeadState.AddSpellState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许切换到胜利
function DeadState.AddVictoryState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许切换到胜利-潜水
function DeadState.AddVictorySwimState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许站立
function DeadState.AddStandState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许下潜
function DeadState.AddDiveState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许下潜
function DeadState.AddDiveLeftState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许打断
function DeadState.AddInterruptState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许下潜过渡
function DeadState.AddDivingState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许技能开始
function DeadState.AddSkillStartState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- @param args table
--- 死亡后不允许技能结束
function DeadState.AddSkillEndState(self, unitState, args)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- 动画触发点（空实现）
function DeadState.OnTrigger(self, unitState)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- 动画开始（空实现）
function DeadState.OnStart(self, unitState)
	return
end

--- @class DeadState
--- @param unitState UnitState
--- 死亡动画播放完毕：发送 DYING 事件，触发外部系统清理
function DeadState.OnEnd(self, unitState)
	unitState:GetTarget():SendDeadEvent()
end

--- @class DeadState
--- @return boolean: true
--- 死亡状态允许缓存武器（实际上死亡后不会创建新子弹，但返回 true 避免影响现有缓存）
function DeadState.CacheWeapon(self)
	return true
end

--- @class DeadState
--- @return boolean: true
function DeadState.FreshActionKeyOffset(self)
	return true
end

--- @class DeadState
--- @param unitState UnitState
--- @return string: "dead" / "dead_swim"（+ 可选 keyOffset 后缀）
--- 根据单位是否在水下选择死亡动画：
--- - 水下状态 → DEAD_SWIM（水下溺亡动画）
--- - 水面状态 → DEAD + 可选 keyOffset 后缀
function DeadState.GetActionName(self, unitState, args)
	local actionName
	local oxyState = unitState:GetTarget():GetOxyState()
	local keyOffset = unitState:ActionKeyOffset()

	if oxyState and oxyState:GetCurrentDiveState() == ys.Battle.BattleConst.OXY_STATE.DIVE then
		-- 水下死亡动画
		actionName = ActionName.DEAD_SWIM
	elseif keyOffset ~= nil then
		-- 水面死亡动画 + keyOffset 后缀
		actionName = ActionName.DEAD .. keyOffset
	else
		-- 水面死亡动画（无后缀）
		actionName = ActionName.DEAD
	end

	return actionName
end
