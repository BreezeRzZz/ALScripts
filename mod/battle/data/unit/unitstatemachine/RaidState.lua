ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.RaidState = class("RaidState", ys.Battle.IUnitState)
ys.Battle.RaidState.__name = "RaidState"

local RaidState = ys.Battle.RaidState

--- @class RaidState : IUnitState
--- 袭击状态（右向）：水下单位攻击时的状态
--- 机制说明：
--- - 这是潜水单位在水下开火时使用的攻击状态，对应水下攻击动画
--- - 由DiveState.AddAttackState触发：潜水状态下攻击被重定向到此状态
--- - 禁止Idle、Move、MoveLeft、Attack（已处于攻击状态）、Skill、Stand、潜水相关
--- - 允许：死亡、法术、胜利、中断、SkillStart
--- - OnTrigger → target:SendAttackTrigger()：在动画触发点（前摇）发送攻击事件
---   - SendAttackTrigger会触发SPAWN_CACHE_BULLET事件，让BattleCharacter生成缓存子弹
---   - 这是子弹实际生成的时机：由Spine动画的action触发点驱动
--- - OnEnd → ChangeToMoveState()：袭击动画完成后恢复到移动状态
--- - 不缓存武器(CacheWeapon=false)：不在状态切换时缓存，而是在OnTrigger时由SendAttackTrigger处理
--- - 对应动画名：RAID
function RaidState.Ctor(self)
	RaidState.super.Ctor(self)
end

--- 袭击状态中禁止Idle
function RaidState.AddIdleState(self, unitState, inputInfo)
	return
end

--- 袭击状态中禁止Move
function RaidState.AddMoveState(self, unitState, inputInfo)
	return
end

--- 袭击状态中禁止MoveLeft
function RaidState.AddMoveLeftState(self, unitState, inputInfo)
	return
end

--- 已经处于袭击状态，禁止重复Attack
function RaidState.AddAttackState(self, unitState, inputInfo)
	return
end

--- 死亡可以打断袭击
function RaidState.AddDeadState(self, unitState, inputInfo)
	unitState:OnDeadState()
end

--- 袭击状态中禁止Skill
function RaidState.AddSkillState(self, unitState, inputInfo)
	return
end

--- 袭击状态中允许法术
function RaidState.AddSpellState(self, unitState, inputInfo)
	unitState:OnSpellState()
end

--- 胜利可以打断袭击
function RaidState.AddVictoryState(self, unitState, inputInfo)
	unitState:OnVictoryState()
end

--- 胜利浮游可以打断袭击
function RaidState.AddVictorySwimState(self, unitState, inputInfo)
	unitState:OnVictorySwimState()
end

--- 袭击状态中禁止Stand
function RaidState.AddStandState(self, unitState, inputInfo)
	return
end

--- 袭击状态中禁止Dive
function RaidState.AddDiveState(self, unitState, inputInfo)
	return
end

--- 袭击状态中禁止DiveLeft
function RaidState.AddDiveLeftState(self, unitState, inputInfo)
	return
end

--- 袭击状态中允许中断
function RaidState.AddInterruptState(self, unitState, inputInfo)
	unitState:OnInterruptState()
end

--- 袭击状态中禁止Diving
function RaidState.AddDivingState(self, unitState, inputInfo)
	return
end

--- 袭击状态中允许SkillStart
function RaidState.AddSkillStartState(self, unitState, inputInfo)
	unitState:OnSkillStartState()
end

--- 袭击状态中禁止SkillEnd
function RaidState.AddSkillEndState(self, unitState, inputInfo)
	return
end

--- 袭击动画触发点：发送攻击事件，触发子弹生成
--- SendAttackTrigger → BattleUnitEvent.SPAWN_CACHE_BULLET → BattleCharacter.onSpawnCacheBullet
--- 这是子弹实际从缓存中发射的时机
function RaidState.OnTrigger(self, unitState)
	unitState:GetTarget():SendAttackTrigger()
end

function RaidState.OnStart(self, unitState)
	return
end

--- 袭击动画结束 → 恢复到移动状态
function RaidState.OnEnd(self, unitState)
	unitState:ChangeToMoveState()
end

--- 袭击状态不需要预缓存武器（子弹由OnTrigger中的SendAttackTrigger发射）
function RaidState.CacheWeapon(self)
	return false
end

--- 袭击状态不刷新ActionKeyOffset
function RaidState.FreshActionKeyOffset(self)
	return false
end

--- 获取动画名称：返回RAID，播放水下袭击动画
function RaidState.GetActionName(self, unit)
	return ActionName.RAID
end
