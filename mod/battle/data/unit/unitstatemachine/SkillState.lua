ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.SkillState = class("SkillState", ys.Battle.IUnitState)
ys.Battle.SkillState.__name = "SkillState"

local SkillState = ys.Battle.SkillState

--- @class SkillState : IUnitState
--- 技能主状态：单位正在释放技能时的核心状态
--- 机制说明：
--- - 技能状态下允许攻击、法术、死亡、中断、技能子状态(SkillStart/SkillEnd)、胜利
--- - 禁止移动(Move/MoveLeft/Idle)、站立(Stand)、潜水相关(Dive/DiveLeft/Diving)
--- - OnEnd时根据目标是否正在移动，切换到MoveState或IdleState
---   - 这意味着技能释放完毕后，单位会恢复到技能前的运动状态
--- - 缓存武器(CacheWeapon=true)，技能动画前摇期间预生成子弹
function SkillState.Ctor(self)
	SkillState.super.Ctor(self)
end

--- 技能状态下禁止切换到Idle
function SkillState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 技能状态下禁止切换到Move
function SkillState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 技能状态下禁止切换到MoveLeft
function SkillState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 技能状态下允许攻击：委托给UnitState的OnAttackState处理
function SkillState.AddAttackState(self, unitState, inputInfo)
	unitState:OnAttackState(inputInfo)
end

--- 技能状态下允许死亡：委托给UnitState的OnDeadState处理
function SkillState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 技能状态下允许法术：委托给UnitState的OnSpellState处理
function SkillState.AddSpellState(self, unitState, inputInfo)
	unitState:OnSpellState()
end

--- 已经在技能状态中，不重复切换
function SkillState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 技能状态下允许胜利：委托给UnitState的OnVictoryState处理
function SkillState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 技能状态下允许胜利浮游：委托给UnitState的OnVictorySwimState处理
function SkillState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 技能状态下禁止切换到Stand
function SkillState.AddStandState(self, unitState, inputInfo)
	return
end

--- 技能状态下禁止切换到Dive
function SkillState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 技能状态下禁止切换到DiveLeft
function SkillState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 技能状态下允许中断：委托给UnitState的OnInterruptState处理
function SkillState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 技能状态下禁止切换到Diving
function SkillState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 技能状态内允许SkillStart子状态：前摇阶段的过渡
function SkillState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 技能状态下忽略SkillEnd子状态（由当前OnEnd处理后摇）
function SkillState.AddSkillEndState(self, unitState, inputInfo)
	return
end

--- 动画触发点回调：不执行任何操作
function SkillState.OnTrigger(self, unitState)
	return
end

--- 状态开始回调：不执行任何操作
function SkillState.OnStart(self, unitState)
	return
end

--- 状态结束回调：根据目标是否移动决定恢复状态
--- 如果目标正在移动 → 恢复到MoveState
--- 如果目标静止 → 恢复到IdleState
--- 这样确保技能释放完毕后，单位恢复到正确的运动状态
function SkillState.OnEnd(self, unitState)
	if unitState:GetTarget():IsMoving() then
		unitState:OnMoveState()
	else
		unitState:OnIdleState()
	end
end

--- 技能状态需要缓存武器：在动画前摇阶段预生成子弹
function SkillState.CacheWeapon(self)
	return true
end

--- 技能状态不刷新ActionKeyOffset
function SkillState.FreshActionKeyOffset(self)
	return false
end
