ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.InterruptState = class("InterruptState", ys.Battle.IUnitState)
ys.Battle.InterruptState.__name = "InterruptState"

local InterruptState = ys.Battle.InterruptState

--- @class InterruptState : IUnitState
--- 中断/打断状态：单位被中断（如眩晕、击退等）时的状态
--- 机制说明：
--- - 当单位被中断打断时进入此状态，对应失控/硬直动画
--- - 禁止Idle、Move、MoveLeft、Attack、Skill、Spell、Stand、潜水相关
--- - 关键机制：OnTrigger时设置sickness状态
---   - SetInterruptSickness(true)：标记单位为"sickness"状态
---   - 在BattleUnit.UpdateWeapon中检查_isSickness：sickness时不能更新武器
---   - 在BattleUnit.Update中检查_isSickness：sickness时不能更新运动
---   - 即中断期间单位完全无法行动（不能移动、不能开火）
--- - OnEnd时清除sickness并恢复移动
---   - SetInterruptSickness(false)：恢复行动能力
---   - ChangeToMoveState()：切换到移动状态
--- - 特殊：AddDivingState → OnDivingState()：中断期间可以进入潜水过渡？
---   - 这是一个非直观的设计：被中断时仍然可以开始潜水
--- - 仅允许：死亡、胜利(Victory/VictorySwim)、Diving、SkillStart
--- - 缓存武器(CacheWeapon=true)：中断动画期间预缓存武器
--- - 对应动画名：INTERRUPT
function InterruptState.Ctor(self)
	InterruptState.super.Ctor(self)
end

--- 中断状态下禁止Idle
function InterruptState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 中断状态下禁止Move
function InterruptState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 中断状态下禁止MoveLeft
function InterruptState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 中断状态下禁止Attack
function InterruptState.AddAttackState(self, unitState, inputInfo)
	return
end

--- 死亡可以打断中断状态（死亡优先级最高）
function InterruptState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 中断状态下禁止Skill
function InterruptState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 中断状态下禁止Spell
function InterruptState.AddSpellState(self, unitState, inputInfo)
	return
end

--- 胜利可以打断中断状态
function InterruptState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 胜利浮游可以打断中断状态
function InterruptState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 中断状态下禁止Stand
function InterruptState.AddStandState(self, unitState, inputInfo)
	return
end

--- 中断状态下禁止Dive
function InterruptState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 中断状态下禁止DiveLeft
function InterruptState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 已经处于中断状态，不重复
function InterruptState.AddInterruptState(self, unitState, inputInfo)
	return
end

--- 特殊设计：中断状态中允许进入潜水过渡(Diving)
--- 这意味着即使被中断/眩晕，单位仍然可以开始潜水动画
--- 这是一个非直观但有意为之的设计选择
function InterruptState.AddDivingState(self, unitState, inputInfo)
	unitState:OnDivingState()
end

--- 中断状态下允许SkillStart
function InterruptState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 中断状态下禁止SkillEnd
function InterruptState.AddSkillEndState(self, unitState, inputInfo)
	return
end

--- 中断动画触发点：设置目标为sickness状态
--- SetInterruptSickness(true) → BattleUnit._isSickness = true
--- sickness状态下：不能更新运动(BattleUnit.Update检查)、不能更新武器(BattleUnit.UpdateWeapon检查)
--- 即单位在中断动画开始时就完全失去行动能力
function InterruptState.OnTrigger(self, unitState)
	unitState:GetTarget():SetInterruptSickness(true)
end

function InterruptState.OnStart(self, unitState)
	return
end

--- 中断动画结束：清除sickness状态并恢复移动
--- 1. SetInterruptSickness(false)：恢复行动能力
--- 2. ChangeToMoveState()：切换到移动状态
function InterruptState.OnEnd(self, unitState)
	unitState:GetTarget():SetInterruptSickness(false)
	unitState:ChangeToMoveState()
end

--- 中断状态需要缓存武器
function InterruptState.CacheWeapon(self)
	return true
end

--- 中断状态不刷新ActionKeyOffset
function InterruptState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回INTERRUPT，播放中断/硬直动画
function InterruptState.GetActionName(self, unit)
	return ActionName.INTERRUPT
end
