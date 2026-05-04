ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.DiveState = class("DiveState", ys.Battle.IUnitState)
ys.Battle.DiveState.__name = "DiveState"

local DiveState = ys.Battle.DiveState

--- @class DiveState : IUnitState
--- 潜水状态（右向）：潜艇/潜水单位在水下巡航的状态
--- 机制说明：
--- - 在水下时允许Idle、Move、MoveLeft（基本运动能力保留）
--- - 关键机制：攻击(Attack)被重定向为RaidState（水下袭击）
---   - AddAttackState → OnRaidState：水下开火使用Raid动画而非Attack动画
---   - 这意味着潜艇在水下的攻击表现和水面完全不同
--- - 潜水方向切换：DiveLeft → OnDiveLeftState（改为左向潜水）
--- - 允许：法术(Spell)、胜利(Victory/VictorySwim)、中断(Interrupt)、SkillStart
--- - 禁止：Skill(与潜水互斥)、Stand、Dive(自身已在此状态)、Diving(过渡动画)
--- - 缓存武器(CacheWeapon=true)，潜水状态下子弹预生成
--- - 对应动画名：DIVE
function DiveState.Ctor(self)
	DiveState.super.Ctor(self)
end

--- 潜水状态下允许Idle（水下静止）
function DiveState.AddIdleState(self, unitState, inputInfo)
	unitState:OnIdleState()
end

--- 潜水状态下允许Move（水下移动）
function DiveState.AddMoveState(self, unitState, inputInfo)
	unitState:OnMoveState()
end

--- 潜水状态下允许MoveLeft（水下左移）
function DiveState.AddMoveLeftState(self, unitState, inputInfo)
	unitState:OnMoveLeftState()
end

--- 潜水状态下的攻击被重定向为RaidState（水下袭击）
--- 潜艇在水下开火使用Raid动画代替普通Attack动画
--- 这是潜水状态最关键的转换规则
function DiveState.AddAttackState(self, unitState, inputInfo)
	unitState:OnRaidState(inputInfo)
end

--- 潜水状态下允许死亡
function DiveState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 潜水状态下禁止Skill（潜水与技能互斥）
function DiveState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 潜水状态下允许法术
function DiveState.AddSpellState(self, unitState, inputInfo)
	unitState:OnSpellState()
end

--- 潜水状态下允许胜利
function DiveState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 潜水状态下允许胜利浮游
function DiveState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 潜水状态下禁止Stand
function DiveState.AddStandState(self, unitState, inputInfo)
	return
end

--- 已经处于Dive状态，不重复切换
function DiveState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 潜水方向切换：Dive → DiveLeft（右向潜水 → 左向潜水）
function DiveState.AddDiveLeftState(self, unitState, inputInfo)
	unitState:OnDiveLeftState()
end

--- 潜水状态下允许中断
function DiveState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 禁止在潜水状态下再进入Diving（潜水过渡动画）
function DiveState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 潜水状态下允许SkillStart
function DiveState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 潜水状态下禁止SkillEnd
function DiveState.AddSkillEndState(self, unitState, inputInfo)
	return
end

function DiveState.OnTrigger(self, unitState)
	return
end

function DiveState.OnStart(self, unitState)
	return
end

function DiveState.OnEnd(self, unitState)
	return
end

--- 潜水状态需要缓存武器
function DiveState.CacheWeapon(self)
	return true
end

--- 潜水状态不刷新ActionKeyOffset
function DiveState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回DIVE，播放潜水中动画
function DiveState.GetActionName(self, unit)
	return ActionName.DIVE
end
