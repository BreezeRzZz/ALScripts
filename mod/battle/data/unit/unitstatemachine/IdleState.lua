ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class IdleState : IUnitState
--- 待机状态。单位的默认状态，初始进入时即为此状态。
--- 从 Idle 可以切换到大部分其他状态（Move, MoveLeft, Attack, Dead, Spell, Victory 等）。
--- CacheWeapon = true: 待机时可以缓存武器子弹。
ys.Battle.IdleState = class("IdleState", ys.Battle.IUnitState)
ys.Battle.IdleState.__name = "IdleState"

local IdleState = ys.Battle.IdleState

--- @class IdleState
--- @return nil
--- 构造函数
function IdleState.Ctor(self)
	IdleState.super.Ctor()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 已是 Idle 状态，无需切换
function IdleState.AddIdleState(self, unitState, args)
	return
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到向右移动状态
function IdleState.AddMoveState(self, unitState, args)
	unitState:OnMoveState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到向左移动状态
function IdleState.AddMoveLeftState(self, unitState, args)
	unitState:OnMoveLeftState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table: 攻击动作名
--- 切换到攻击状态(向右)
function IdleState.AddAttackState(self, unitState, args)
	unitState:OnAttackState(args)
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到死亡状态
function IdleState.AddDeadState(self, unitState, args)
	unitState:OnDeadState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到技能状态
function IdleState.AddSkillState(self, unitState, args)
	return
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到施法状态
function IdleState.AddSpellState(self, unitState, args)
	unitState:OnSpellState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到胜利状态
function IdleState.AddVictoryState(self, unitState, args)
	unitState:OnVictoryState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到胜利-潜水状态
function IdleState.AddVictorySwimState(self, unitState, args)
	unitState:OnVictorySwimState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到站立状态
function IdleState.AddStandState(self, unitState, args)
	unitState:OnDiveState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜状态(向右)
function IdleState.AddDiveState(self, unitState, args)
	unitState:OnDiveState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜状态(向左)
function IdleState.AddDiveLeftState(self, unitState, args)
	unitState:OnDiveLeftState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到打断状态
function IdleState.AddInterruptState(self, unitState, args)
	unitState:OnInterruptState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到下潜过渡状态
function IdleState.AddDivingState(self, unitState, args)
	unitState:OnDivingState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到技能开始状态
function IdleState.AddSkillStartState(self, unitState, args)
	unitState:OnSkillStartState()
end

--- @class IdleState
--- @param unitState UnitState
--- @param args table
--- 切换到技能结束状态
function IdleState.AddSkillEndState(self, unitState, args)
	return
end

--- @class IdleState
--- @param unitState UnitState
--- 动画触发点回调（空实现）
function IdleState.OnTrigger(self, unitState)
	return
end

--- @class IdleState
--- @param unitState UnitState
--- 动画开始回调（空实现）
function IdleState.OnStart(self, unitState)
	return
end

--- @class IdleState
--- @param unitState UnitState
--- 动画结束回调（空实现）
function IdleState.OnEnd(self, unitState)
	return
end

--- @class IdleState
--- @return boolean: true
--- 待机状态允许缓存武器子弹
function IdleState.CacheWeapon(self)
	return true
end

--- @class IdleState
--- @return boolean: false
--- 待机状态不需要刷新 ActionKeyOffset
function IdleState.FreshActionKeyOffset(self)
	return false
end

--- @class IdleState
--- @param unitState UnitState
--- @return string: "idle"
--- 获取当前状态的 Spine 动作名
function IdleState.GetActionName(self, unitState)
	return ActionName.IDLE
end
