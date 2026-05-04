ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.DivingState = class("DivingState", ys.Battle.IUnitState)
ys.Battle.DivingState.__name = "DivingState"

local DivingState = ys.Battle.DivingState

--- @class DivingState : IUnitState
--- 潜水过渡状态：单位从水面进入水下时的过渡动画状态
--- 机制说明：
--- - 这是水面→水下的过渡状态，对应潜水动画的播放
--- - 极度受限：禁止攻击、移动、法术、中断等几乎所有操作
--- - 仅允许：死亡(OnDeadState)、胜利(Victory/VictorySwim)、SkillStart
--- - 注意：中断(Interrupt)在此状态被忽略！潜水过渡不能被中断打断
--- - OnEnd执行两个关键操作：
---   1. ChangeOxyState(OxyState.STATE_DIVE)：将氧气状态设为潜水
---   2. ChangeToMoveState()：切换到移动状态
---   - 这意味着潜水过渡动画结束后，单位正式进入水下状态(DiveState/DiveLeftState)
--- - 不缓存武器(CacheWeapon=false)，过渡动画期间不需要生成子弹
--- - 没有GetActionName（不需要特定动画名，由调用方决定）
function DivingState.Ctor(self)
	DivingState.super.Ctor(self)
end

--- 潜水过渡期间禁止Idle
function DivingState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间禁止Move
function DivingState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间禁止MoveLeft
function DivingState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间禁止Attack
function DivingState.AddAttackState(self, unitState, inputInfo)
	return
end

--- 死亡可以打断潜水过渡
function DivingState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 潜水过渡期间禁止Skill
function DivingState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间禁止Spell
function DivingState.AddSpellState(self, unitState, inputInfo)
	return
end

--- 胜利可以打断潜水过渡
function DivingState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 胜利浮游可以打断潜水过渡
function DivingState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 潜水过渡期间禁止Stand
function DivingState.AddStandState(self, unitState, inputInfo)
	return
end

--- 已经在潜水过渡状态中，禁止重复Dive
function DivingState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间禁止DiveLeft
function DivingState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间禁止中断：这是DivingState的关键行为
--- 潜水过渡动画不能被中断打断
function DivingState.AddInterruptState(self, unitState, inputInfo)
	return
end

--- 已经处于潜水过渡状态，不重复
function DivingState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 潜水过渡期间允许SkillStart
function DivingState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 潜水过渡期间禁止SkillEnd
function DivingState.AddSkillEndState(self, unitState, inputInfo)
	return
end

function DivingState.OnTrigger(self, unitState)
	return
end

function DivingState.OnStart(self, unitState)
	return
end

--- 潜水过渡动画结束：设置氧气状态为DIVE，然后切换到移动状态
--- 1. ChangeOxyState(OxyState.STATE_DIVE)：标记正式进入潜水状态
--- 2. ChangeToMoveState()：恢复移动能力（根据方向进入DiveState或DiveLeftState）
--- 这是潜水流程的最后一个步骤：过渡→正式潜水
function DivingState.OnEnd(self, unitState)
	unitState:ChangeOxyState(ys.Battle.OxyState.STATE_DIVE)
	unitState:ChangeToMoveState()
end

--- 潜水过渡期间不缓存武器
function DivingState.CacheWeapon(self)
	return false
end

--- 潜水过渡期间不刷新ActionKeyOffset
function DivingState.FreshActionKeyOffset(self)
	return false
end
