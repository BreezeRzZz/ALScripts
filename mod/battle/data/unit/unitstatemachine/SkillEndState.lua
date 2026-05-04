ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.SkillEndState = class("SkillEndState", ys.Battle.IUnitState)
ys.Battle.SkillEndState.__name = "SkillEndState"

local SkillEndState = ys.Battle.SkillEndState

--- @class SkillEndState : IUnitState
--- 技能结束状态：技能动画的收尾/后摇阶段
--- 机制说明：
--- - 技能释放的收尾阶段，对应SkillState结束后的过渡动画
--- - 极度受限：禁止攻击、移动、法术等大多数状态切换
--- - 仅允许：死亡、胜利(Victory/VictorySwim)、中断
--- - OnEnd时调用ChangeToMoveState()：强制恢复到移动状态
---   - 不同于SkillState的OnEnd（根据IsMoving决定Idle/Move），SkillEnd总是恢复到Move
---   - 这确保技能收招后单位立即进入可移动状态
--- - 不缓存武器(CacheWeapon=false)，后摇阶段不需要生成子弹
--- - 对应动画名：SKILL_END
function SkillEndState.Ctor(self)
	SkillEndState.super.Ctor(self)
end

--- 技能后摇期间禁止Idle
function SkillEndState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 技能后摇期间禁止Move
function SkillEndState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 技能后摇期间禁止MoveLeft
function SkillEndState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 技能后摇期间禁止Attack
function SkillEndState.AddAttackState(self, unitState, inputInfo)
	return
end

--- 死亡可以打断技能后摇
function SkillEndState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 技能后摇期间禁止Spell
function SkillEndState.AddSpellState(self, unitState, inputInfo)
	return
end

--- 已经在技能结束状态，不重复
function SkillEndState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 胜利可以打断技能后摇
function SkillEndState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 胜利浮游可以打断技能后摇
function SkillEndState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 技能后摇期间禁止Stand
function SkillEndState.AddStandState(self, unitState, inputInfo)
	return
end

--- 技能后摇期间禁止Dive
function SkillEndState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 技能后摇期间禁止DiveLeft
function SkillEndState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 中断可以打断技能后摇
function SkillEndState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 技能后摇期间禁止Diving
function SkillEndState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 技能后摇期间禁止SkillStart
function SkillEndState.AddSkillStartState(self, unitState, inputInfo)
	return
end

--- 已经在技能结束状态，不重复
function SkillEndState.AddSkillEndState(self, unitState, inputInfo)
	return
end

function SkillEndState.OnTrigger(self, unitState)
	return
end

function SkillEndState.OnStart(self, unitState)
	return
end

--- 技能后摇结束 → 强制恢复到移动状态
--- 与SkillState.OnEnd不同：SkillEnd总是回到MoveState，而非根据IsMoving判断
function SkillEndState.OnEnd(self, unitState)
	unitState:ChangeToMoveState()
end

--- 技能后摇期间不缓存武器
function SkillEndState.CacheWeapon(self)
	return false
end

--- 技能后摇期间不刷新ActionKeyOffset
function SkillEndState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回SKILL_END，播放技能收招动画
function SkillEndState.GetActionName(self, unit)
	return ActionName.SKILL_END
end
