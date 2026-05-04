ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class MoveState : IUnitState
--- 移动状态（向右）。单位正在向右侧移动。
--- 从此状态可以切换到 Idle、MoveLeft、Attack、Dead、Spell、Victory、Dive 等。
--- 与 MoveLeftState 的对比：Attack 时切换到自己对应的 OnAttackState（而非 OnAttackLeftState）。
--- CacheWeapon = true: 移动中仍可缓存武器子弹。
--- FreshActionKeyOffset = true: 支持动作名的 keyOffset 后缀。
ys.Battle.MoveState = class("MoveState", ys.Battle.IUnitState)
ys.Battle.MoveState.__name = "MoveState"

local MoveState = ys.Battle.MoveState

--- @class MoveState
--- @return nil
--- 构造函数
function MoveState.Ctor(self)
	MoveState.super.Ctor()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 停止移动，进入待机
function MoveState.AddIdleState(self, unitState, args)
	unitState:OnIdleState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 已在 Move 状态，无需切换
function MoveState.AddMoveState(self, unitState, args)
	return
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 转向，切成向左移动
function MoveState.AddMoveLeftState(self, unitState, args)
	unitState:OnMoveLeftState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table: 攻击动作名
--- 切换到攻击状态(向右)
function MoveState.AddAttackState(self, unitState, args)
	unitState:OnAttackState(args)
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到死亡状态
function MoveState.AddDeadState(self, unitState, args)
	unitState:OnDeadState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到技能状态
function MoveState.AddSkillState(self, unitState, args)
	return
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到施法状态
function MoveState.AddSpellState(self, unitState, args)
	unitState:OnSpellState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到胜利状态
function MoveState.AddVictoryState(self, unitState, args)
	unitState:OnVictoryState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到胜利-潜水状态
function MoveState.AddVictorySwimState(self, unitState, args)
	unitState:OnVictorySwimState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到站立状态
function MoveState.AddStandState(self, unitState, args)
	return
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜状态(向右)
function MoveState.AddDiveState(self, unitState, args)
	unitState:OnDiveState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜状态(向左)
function MoveState.AddDiveLeftState(self, unitState, args)
	unitState:OnDiveLeftState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到打断状态
function MoveState.AddInterruptState(self, unitState, args)
	unitState:OnInterruptState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜过渡状态
function MoveState.AddDivingState(self, unitState, args)
	unitState:OnDivingState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到技能开始状态
function MoveState.AddSkillStartState(self, unitState, args)
	unitState:OnSkillStartState()
end

--- @class MoveState
--- @param unitState UnitState
--- @param args table
--- 切换到技能结束状态
function MoveState.AddSkillEndState(self, unitState, args)
	return
end

--- @class MoveState
--- @param unitState UnitState
--- 动画触发点回调（空实现）
function MoveState.OnTrigger(self, unitState)
	return
end

--- @class MoveState
--- @param unitState UnitState
--- 动画开始回调（空实现）
function MoveState.OnStart(self, unitState)
	return
end

--- @class MoveState
--- @param unitState UnitState
--- 动画结束回调（空实现）
function MoveState.OnEnd(self, unitState)
	return
end

--- @class MoveState
--- @return boolean: true
--- 移动状态允许缓存武器子弹
function MoveState.CacheWeapon(self)
	return true
end

--- @class MoveState
--- @param unitState UnitState
--- @return boolean: true
--- 移动状态需要刷新 ActionKeyOffset（支持动画名后缀）
function MoveState.FreshActionKeyOffset(self, unitState)
	return true
end

--- @class MoveState
--- @param unitState UnitState
--- @return string: "move" (+ keyOffset 后缀)
--- 获取当前状态的 Spine 动作名，支持 ActionKeyOffset 后缀
function MoveState.GetActionName(self, unitState)
	local actionName = ActionName.MOVE
	local keyOffset = unitState:ActionKeyOffset()

	if keyOffset then
		actionName = actionName .. keyOffset
	end

	return actionName
end
