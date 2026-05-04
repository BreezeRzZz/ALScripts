ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.DiveLeftState = class("DiveLeftState", ys.Battle.IUnitState)
ys.Battle.DiveLeftState.__name = "DiveLeftState"

local DiveLeftState = ys.Battle.DiveLeftState

--- @class DiveLeftState : IUnitState
--- 潜水状态（左向）：潜艇/潜水单位在水下向左巡航的状态
--- 机制说明：
--- - 与DiveState对称，但方向向左
--- - 允许Idle、Move、MoveLeft（基本运动能力保留）
--- - 关键机制：攻击(Attack)被重定向为RaidLeftState（左向水下袭击）
---   - AddAttackState → OnRaidLeftState：水下向左开火使用RaidLeft动画
---   - 这是DiveLeftState与DiveState的核心区别（Raid vs RaidLeft）
--- - 潜水方向切换：Dive → OnDiveState（改回右向潜水）
--- - 允许：法术(Spell)、胜利(Victory/VictorySwim)、中断(Interrupt)、SkillStart
--- - 禁止：Skill(互斥)、Stand、DiveLeft(自身)、Diving(过渡动画)
--- - 缓存武器(CacheWeapon=true)，潜水状态下子弹预生成
--- - 对应动画名：DIVELEFT
function DiveLeftState.Ctor(self)
	DiveLeftState.super.Ctor(self)
end

--- 潜水左向状态下允许Idle
function DiveLeftState.AddIdleState(self, unitState, inputInfo)
	unitState:OnIdleState()
end

--- 潜水左向状态下允许Move
function DiveLeftState.AddMoveState(self, unitState, inputInfo)
	unitState:OnMoveState()
end

--- 潜水左向状态下允许MoveLeft
function DiveLeftState.AddMoveLeftState(self, unitState, inputInfo)
	unitState:OnMoveLeftState()
end

--- 潜水左向状态下的攻击被重定向为RaidLeftState（左向水下袭击）
--- 与DiveState的关键区别：使用OnRaidLeftState而非OnRaidState
function DiveLeftState.AddAttackState(self, unitState, inputInfo)
	unitState:OnRaidLeftState(inputInfo)
end

--- 潜水左向状态下允许死亡
function DiveLeftState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 潜水左向状态下禁止Skill
function DiveLeftState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 潜水左向状态下允许法术
function DiveLeftState.AddSpellState(self, unitState, inputInfo)
	unitState:OnSpellState()
end

--- 潜水左向状态下允许胜利
function DiveLeftState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 潜水左向状态下允许胜利浮游
function DiveLeftState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 潜水左向状态下禁止Stand
function DiveLeftState.AddStandState(self, unitState, inputInfo)
	return
end

--- 潜水方向切换：DiveLeft → Dive（左向潜水 → 右向潜水）
function DiveLeftState.AddDiveState(self, unitState, inputInfo)
	unitState:OnDiveState()
end

--- 已经处于DiveLeft状态，不重复
function DiveLeftState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 潜水左向状态下允许中断
function DiveLeftState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 禁止在潜水状态下再进入Diving（过渡动画）
function DiveLeftState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 潜水左向状态下允许SkillStart
function DiveLeftState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 潜水左向状态下禁止SkillEnd
function DiveLeftState.AddSkillEndState(self, unitState, inputInfo)
	return
end

function DiveLeftState.OnTrigger(self, unitState)
	return
end

function DiveLeftState.OnStart(self, unitState)
	return
end

function DiveLeftState.OnEnd(self, unitState)
	return
end

--- 潜水左向状态需要缓存武器
function DiveLeftState.CacheWeapon(self)
	return true
end

--- 潜水左向状态不刷新ActionKeyOffset
function DiveLeftState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回DIVELEFT，播放左向潜水中动画
function DiveLeftState.GetActionName(self, unit)
	return ActionName.DIVELEFT
end
