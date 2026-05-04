ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class StandState : IUnitState
--- 站立状态（登场动作）。单位进入战场时的现身/登场动画。
---
--- 关键机制：
--- 1. 大多数状态切换被阻断，只允许 Interrupt、Diving、SkillStart。
---    Stand 是一个过渡状态，用于播放登场亮相动画。
--- 2. OnEnd → OnVictoryState() —— 站立动画结束后自动进入胜利状态！
---    这说明 StandState 并非常规战斗循环的起点，而是战斗胜利后的"亮相"环节。
---    战斗起点是初始 Idle 状态。
--- 3. GetActionName 返回 STAND（"stand"）动画名。
--- 4. CacheWeapon = true —— 站立状态允许缓存武器（虽然此时通常不开火）。
--- 5. FreshActionKeyOffset = false —— 不支持 action 名称后缀。
---    与 IdleState 一样，这是简单的固定动画名。
ys.Battle.StandState = class("StandState", ys.Battle.IUnitState)
ys.Battle.StandState.__name = "StandState"

local StandState = ys.Battle.StandState

--- @class StandState
--- @return nil
--- 构造函数
function StandState.Ctor(self)
	StandState.super.Ctor()
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许切换 Idle
function StandState.AddIdleState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许移动
function StandState.AddMoveState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许向左移动
function StandState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许攻击
function StandState.AddAttackState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许死亡
function StandState.AddDeadState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许使用技能
function StandState.AddSkillState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许施法
function StandState.AddSpellState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许切换胜利
function StandState.AddVictoryState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许切换胜利-潜水
function StandState.AddVictorySwimState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 已在站立状态，无需切换
function StandState.AddStandState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许下潜
function StandState.AddDiveState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许下潜(向左)
function StandState.AddDiveLeftState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态允许被打断
function StandState.AddInterruptState(self, unitState, args)
	unitState:OnInterruptState()
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态允许下潜过渡
function StandState.AddDivingState(self, unitState, args)
	unitState:OnDivingState()
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态允许技能开始
function StandState.AddSkillStartState(self, unitState, args)
	unitState:OnSkillStartState()
end

--- @class StandState
--- @param unitState UnitState
--- @param args table
--- 站立状态不允许技能结束
function StandState.AddSkillEndState(self, unitState, args)
	return
end

--- @class StandState
--- @param unitState UnitState
--- 动画触发点（空实现）
function StandState.OnTrigger(self, unitState)
	return
end

--- @class StandState
--- @param unitState UnitState
--- 动画开始（空实现）
function StandState.OnStart(self, unitState)
	return
end

--- @class StandState
--- @param unitState UnitState
--- 站立动画结束：自动进入胜利状态（亮相完成）
function StandState.OnEnd(self, unitState)
	unitState:OnVictoryState()
end

--- @class StandState
--- @return boolean: true
--- 站立状态允许缓存武器
function StandState.CacheWeapon(self)
	return true
end

--- @class StandState
--- @return boolean: false
--- 站立状态不支持 ActionKeyOffset 后缀
function StandState.FreshActionKeyOffset(self)
	return false
end

--- @class StandState
--- @param unitState UnitState
--- @return string: "stand"
--- 获取站立状态的 Spine 动作名
function StandState.GetActionName(self, unitState)
	return ActionName.STAND
end
