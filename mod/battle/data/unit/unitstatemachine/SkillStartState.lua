ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.SkillStartState = class("SkillStartState", ys.Battle.IUnitState)
ys.Battle.SkillStartState.__name = "SkillStartState"

local SkillStartState = ys.Battle.SkillStartState

--- @class SkillStartState : IUnitState
--- 技能开始状态：技能动画的起手/前摇阶段
--- 机制说明：
--- - 技能释放的第一个阶段，对应技能动画的起手动作
--- - 极度受限：禁止攻击、移动、法术等几乎所有状态切换
--- - 仅允许：死亡(OnDeadState)、胜利(Victory/VictorySwim)、中断(OnInterruptState)
--- - 关键状态转换：AddSkillEndState → OnSkillEndState（前摇结束→进入技能主状态SkillState）
---   - 这是SkillStartState唯一的核心转换：前摇完成→技能主体
--- - 不缓存武器(CacheWeapon=false)，前摇阶段还没到子弹生成的时机
--- - 对应动画名：SKILL_START
function SkillStartState.Ctor(self)
	SkillStartState.super.Ctor(self)
end

--- 技能前摇期间禁止Idle
function SkillStartState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 技能前摇期间禁止Move
function SkillStartState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 技能前摇期间禁止MoveLeft
function SkillStartState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 技能前摇期间禁止Attack
function SkillStartState.AddAttackState(self, unitState, inputInfo)
	return
end

--- 死亡可以打断技能前摇
function SkillStartState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 技能前摇期间禁止Spell
function SkillStartState.AddSpellState(self, unitState, inputInfo)
	return
end

--- 已经在技能开始状态，不重复切换
function SkillStartState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 胜利可以打断技能前摇
function SkillStartState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 胜利浮游可以打断技能前摇
function SkillStartState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 技能前摇期间禁止Stand
function SkillStartState.AddStandState(self, unitState, inputInfo)
	return
end

--- 技能前摇期间禁止Dive
function SkillStartState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 技能前摇期间禁止DiveLeft
function SkillStartState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 中断可以打断技能前摇
function SkillStartState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 技能前摇期间禁止Diving
function SkillStartState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 已经在技能开始状态，不重复
function SkillStartState.AddSkillStartState(self, unitState, inputInfo)
	return
end

--- 技能前摇结束 → 进入SkillEndState（过渡到技能主体）
--- 这是SkillStartState的唯一核心状态转换
function SkillStartState.AddSkillEndState(self, unitState, inputInfo)
	unitState:OnSkillEndState()
end

function SkillStartState.OnTrigger(self, unitState)
	return
end

function SkillStartState.OnStart(self, unitState)
	return
end

--- 技能前摇OnEnd：无操作（前摇→主体的转换由AddSkillEndState处理）
function SkillStartState.OnEnd(self, unitState)
	return
end

--- 技能前摇期间不缓存武器
function SkillStartState.CacheWeapon(self)
	return false
end

--- 技能前摇期间不刷新ActionKeyOffset
function SkillStartState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回SKILL_START，播放技能起手动画
function SkillStartState.GetActionName(self, unit)
	return ActionName.SKILL_START
end
