ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.SpellState = class("SpellState", ys.Battle.IUnitState)
ys.Battle.SpellState.__name = "SpellState"

local SpellState = ys.Battle.SpellState

--- @class SpellState : IUnitState
--- 法术/特殊技能状态：单位释放特殊技能时的状态
--- 机制说明：
--- - 法术状态下允许攻击、死亡、中断、胜利、SkillStart子状态
--- - 法术状态下的攻击方向自适应：根据目标速度方向决定正面/左向攻击
---   - target.speed.x >= 0 → OnAttackState（正面攻击动画）
---   - target.speed.x < 0 → OnAttackLeftState（左向/反向攻击动画）
---   - 这是SpellState的独特机制：法术中可以响应目标方向变化
--- - Idle可以打断法术(OnIdleState)：与SkillState的关键区别
---   - SkillState禁止Idle切换，SpellState允许
--- - 禁止Move/MoveLeft/Skill/Spell(自身)/Stand/潜水相关
--- - 缓存武器(CacheWeapon=true)，法术动画前摇期间预生成子弹
function SpellState.Ctor(self)
	SpellState.super.Ctor(self)
end

--- 法术状态下允许Idle：直接切换到Idle状态
--- 与SkillState的关键区别：Idle可以打断法术
function SpellState.AddIdleState(self, unitState, inputInfo)
	unitState:OnIdleState()
end

--- 法术状态下禁止Move
function SpellState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 法术状态下禁止MoveLeft
function SpellState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 法术状态下的攻击方向自适应：根据目标速度方向选择动画
--- target.speed.x >= 0 → OnAttackState（正面攻击）
--- target.speed.x < 0 → OnAttackLeftState（左向/反向攻击）
function SpellState.AddAttackState(self, unitState, inputInfo)
	if unitState:GetTarget():GetSpeed().x >= 0 then
		unitState:OnAttackState(inputInfo)
	else
		unitState:OnAttackLeftState(inputInfo)
	end
end

--- 法术状态下允许死亡
function SpellState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 法术状态下禁止Skill：法术和技能互斥
function SpellState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 已经在法术状态中，不重复
function SpellState.AddSpellState(self, unitState, inputInfo)
	return
end

--- 法术状态下允许胜利
function SpellState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 法术状态下允许胜利浮游
function SpellState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 法术状态下禁止Stand
function SpellState.AddStandState(self, unitState, inputInfo)
	return
end

--- 法术状态下禁止Dive
function SpellState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 法术状态下禁止DiveLeft
function SpellState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 法术状态下允许中断
function SpellState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 法术状态下禁止Diving
function SpellState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 法术状态下允许SkillStart子状态
function SpellState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 法术状态下禁止SkillEnd子状态
function SpellState.AddSkillEndState(self, unitState, inputInfo)
	return
end

function SpellState.OnTrigger(self, unitState)
	return
end

function SpellState.OnStart(self, unitState)
	return
end

--- 法术结束：无操作（状态转换由AddXxx方法处理）
function SpellState.OnEnd(self, unitState)
	return
end

--- 法术状态需要缓存武器：预生成子弹
function SpellState.CacheWeapon(self)
	return true
end

--- 法术状态不刷新ActionKeyOffset
function SpellState.FreshActionKeyOffset(self)
	return false
end
