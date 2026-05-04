ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class MoveLeftState : IUnitState
--- 移动状态（向左）。单位正在向左侧移动（面向左边）。
--- 与 MoveState 的关键区别：
--- 1. GetActionName 返回 MOVELEFT（而非 MOVE）
--- 2. AddAttackState 切换到 OnAttackLeftState（而非 OnAttackState）
---    —— 向左移动时攻击，动画名会自动加上 "_left" 后缀
--- CacheWeapon = true: 移动中仍可缓存武器子弹。
ys.Battle.MoveLeftState = class("MoveLeftState", ys.Battle.IUnitState)
ys.Battle.MoveLeftState.__name = "MoveLeftState"

local MoveLeftState = ys.Battle.MoveLeftState

--- @class MoveLeftState
--- @return nil
--- 构造函数
function MoveLeftState.Ctor(self)
	MoveLeftState.super.Ctor()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 停止移动，进入待机
function MoveLeftState.AddIdleState(self, unitState, args)
	unitState:OnIdleState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 转向，切成向右移动
function MoveLeftState.AddMoveState(self, unitState, args)
	unitState:OnMoveState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 已在 MoveLeft 状态，无需切换
function MoveLeftState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table: 攻击动作名
--- 切换到攻击状态(向左) —— 与 MoveState 不同，这里调用 OnAttackLeftState
function MoveLeftState.AddAttackState(self, unitState, args)
	unitState:OnAttackLeftState(args)
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到死亡状态
function MoveLeftState.AddDeadState(self, unitState, args)
	unitState:OnDeadState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到技能状态
function MoveLeftState.AddSkillState(self, unitState, args)
	return
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到施法状态
function MoveLeftState.AddSpellState(self, unitState, args)
	unitState:OnSpellState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到胜利状态
function MoveLeftState.AddVictoryState(self, unitState, args)
	unitState:OnVictoryState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到胜利-潜水状态
function MoveLeftState.AddVictorySwimState(self, unitState, args)
	unitState:OnVictorySwimState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到站立状态
function MoveLeftState.AddStandState(self, unitState, args)
	return
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜状态(向右)
function MoveLeftState.AddDiveState(self, unitState, args)
	unitState:OnDiveState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜状态(向左)
function MoveLeftState.AddDiveLeftState(self, unitState, args)
	unitState:OnDiveLeftState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到打断状态
function MoveLeftState.AddInterruptState(self, unitState, args)
	unitState:OnInterruptState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜过渡状态
function MoveLeftState.AddDivingState(self, unitState, args)
	unitState:OnDivingState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到技能开始状态
function MoveLeftState.AddSkillStartState(self, unitState, args)
	unitState:OnSkillStartState()
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @param args table
--- 切换到技能结束状态
function MoveLeftState.AddSkillEndState(self, unitState, args)
	return
end

--- @class MoveLeftState
--- @param unitState UnitState
--- 动画触发点回调（空实现）
function MoveLeftState.OnTrigger(self, unitState)
	return
end

--- @class MoveLeftState
--- @param unitState UnitState
--- 动画开始回调（空实现）
function MoveLeftState.OnStart(self, unitState)
	return
end

--- @class MoveLeftState
--- @param unitState UnitState
--- 动画结束回调（空实现）
function MoveLeftState.OnEnd(self, unitState)
	return
end

--- @class MoveLeftState
--- @return boolean: true
--- 移动状态允许缓存武器子弹
function MoveLeftState.CacheWeapon(self)
	return true
end

--- @class MoveLeftState
--- @return boolean: true
--- 移动状态需要刷新 ActionKeyOffset
function MoveLeftState.FreshActionKeyOffset(self)
	return true
end

--- @class MoveLeftState
--- @param unitState UnitState
--- @return string: "moveleft" (+ keyOffset 后缀)
--- 获取向左移动的 Spine 动作名
function MoveLeftState.GetActionName(self, unitState)
	local actionName = ActionName.MOVELEFT
	local keyOffset = unitState:ActionKeyOffset()

	if keyOffset then
		actionName = actionName .. keyOffset
	end

	return actionName
end
