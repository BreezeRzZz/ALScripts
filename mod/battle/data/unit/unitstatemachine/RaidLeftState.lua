ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.RaidLeftState = class("RaidLeftState", ys.Battle.IUnitState)
ys.Battle.RaidLeftState.__name = "RaidLeftState"

local RaidLeftState = ys.Battle.RaidLeftState

--- @class RaidLeftState : IUnitState
--- 袭击状态（左向）：水下单位向左攻击时的状态
--- 机制说明：
--- - 与RaidState对称，但方向向左
--- - 由DiveLeftState.AddAttackState触发：潜水左向时攻击被重定向到此状态
--- - 禁止Idle、Move、MoveLeft、Attack、Skill、Stand、潜水相关
--- - 允许：死亡、法术、胜利、中断、SkillStart
--- - OnTrigger → target:SendAttackTrigger()：在动画触发点发送攻击事件
---   - 与RaidState.OnTrigger完全相同的逻辑：触发SPAWN_CACHE_BULLET事件
--- - OnEnd → ChangeToMoveState()：袭击动画完成后恢复到移动状态
--- - 不缓存武器(CacheWeapon=false)
--- - 对应动画名：RAIDLEFT
function RaidLeftState.Ctor(self)
	RaidLeftState.super.Ctor(self)
end

--- 袭击左向状态中禁止Idle
function RaidLeftState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中禁止Move
function RaidLeftState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中禁止MoveLeft
function RaidLeftState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 已经处于袭击左向状态，禁止重复Attack
function RaidLeftState.AddAttackState(self, unitState, inputInfo)
	return
end

--- 死亡可以打断袭击
function RaidLeftState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 袭击左向状态中禁止Skill
function RaidLeftState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中允许法术
function RaidLeftState.AddSpellState(self, unitState, inputInfo)
	unitState:OnSpellState()
end

--- 胜利可以打断袭击
function RaidLeftState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 胜利浮游可以打断袭击
function RaidLeftState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 袭击左向状态中禁止Stand
function RaidLeftState.AddStandState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中禁止Dive
function RaidLeftState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中禁止DiveLeft
function RaidLeftState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中允许中断
function RaidLeftState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 袭击左向状态中禁止Diving
function RaidLeftState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 袭击左向状态中允许SkillStart
function RaidLeftState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 袭击左向状态中禁止SkillEnd
function RaidLeftState.AddSkillEndState(self, unitState, inputInfo)
	return
end

--- 袭击左向动画触发点：发送攻击事件，触发子弹生成
--- 与RaidState.OnTrigger相同的逻辑
function RaidLeftState.OnTrigger(self, unitState)
	unitState:GetTarget():SendAttackTrigger()
end

function RaidLeftState.OnStart(self, unitState)
	return
end

--- 袭击左向动画结束 → 恢复到移动状态
function RaidLeftState.OnEnd(self, unitState)
	unitState:ChangeToMoveState()
end

--- 袭击左向状态不需要预缓存武器
function RaidLeftState.CacheWeapon(self)
	return false
end

--- 袭击左向状态不刷新ActionKeyOffset
function RaidLeftState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回RAIDLEFT，播放左向水下袭击动画
function RaidLeftState.GetActionName(self, unit)
	return ActionName.RAIDLEFT
end
