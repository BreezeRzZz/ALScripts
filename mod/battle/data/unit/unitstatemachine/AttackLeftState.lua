ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class AttackLeftState : IUnitState
--- 攻击状态（向左）。单位正在向左侧播放攻击动画。
---
--- 与 AttackState 几乎相同，唯一区别在 GetActionName：
--- AttackState 直接返回传入的 actionName + keyOffset，
--- AttackLeftState 返回 actionName .. "_left" + keyOffset。
--- 这是"方向镜像"模式：向左攻击的动画名自动加上 "_left" 后缀，
--- Spine 系统中会寻找对应的向左动画资源（如 "attack_left"）。
---
--- 其他机制完全同 AttackState：
--- - CacheWeapon = false（攻击时子弹不缓存）
--- - OnTrigger → SendAttackTrigger
--- - OnEnd → ChangeToMoveState
--- - 中断/下潜过渡前会先触发 OnTrigger 发射子弹
ys.Battle.AttackLeftState = class("AttackLeftState", ys.Battle.IUnitState)
ys.Battle.AttackLeftState.__name = "AttackLeftState"

local AttackLeftState = ys.Battle.AttackLeftState

--- @class AttackLeftState
--- @return nil
--- 构造函数
function AttackLeftState.Ctor(self)
	AttackLeftState.super.Ctor()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换回 Idle
function AttackLeftState.AddIdleState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换移动状态
function AttackLeftState.AddMoveState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换向左移动
function AttackLeftState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 已在攻击状态，不允许叠加
function AttackLeftState.AddAttackState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许死亡
function AttackLeftState.AddDeadState(self, unitState, args)
	unitState:OnDeadState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换技能状态
function AttackLeftState.AddSkillState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到施法状态
function AttackLeftState.AddSpellState(self, unitState, args)
	unitState:OnSpellState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到胜利状态
function AttackLeftState.AddVictoryState(self, unitState, args)
	unitState:OnVictoryState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到胜利-潜水状态
function AttackLeftState.AddVictorySwimState(self, unitState, args)
	unitState:OnVictorySwimState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换站立状态
function AttackLeftState.AddStandState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许下潜
function AttackLeftState.AddDiveState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许下潜(向左)
function AttackLeftState.AddDiveLeftState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击被打断：先触发 OnTrigger（确保子弹已发射），再进入打断状态
function AttackLeftState.AddInterruptState(self, unitState, args)
	self:OnTrigger(unitState)
	unitState:OnInterruptState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击中下潜过渡：先触发 OnTrigger（发射子弹），再进入下潜过渡
function AttackLeftState.AddDivingState(self, unitState, args)
	self:OnTrigger(unitState)
	unitState:OnDivingState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到技能开始状态
function AttackLeftState.AddSkillStartState(self, unitState, args)
	unitState:OnSkillStartState()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换到技能结束状态
function AttackLeftState.AddSkillEndState(self, unitState, args)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- 攻击动画触发点：生成缓存子弹
function AttackLeftState.OnTrigger(self, unitState)
	unitState:GetTarget():SendAttackTrigger()
end

--- @class AttackLeftState
--- @param unitState UnitState
--- 攻击动画开始（空实现）
function AttackLeftState.OnStart(self, unitState)
	return
end

--- @class AttackLeftState
--- @param unitState UnitState
--- 攻击动画结束：自动切换回移动状态
function AttackLeftState.OnEnd(self, unitState)
	unitState:ChangeToMoveState()
end

--- @class AttackLeftState
--- @return boolean: false
--- 攻击状态不缓存武器子弹
function AttackLeftState.CacheWeapon(self)
	return false
end

--- @class AttackLeftState
--- @return boolean: true
--- 攻击状态需要刷新 ActionKeyOffset
function AttackLeftState.FreshActionKeyOffset(self)
	return true
end

--- @class AttackLeftState
--- @param unitState UnitState
--- @param actionName string: 调用方传入的攻击动作名
--- @return string: 完整的 Spine 攻击动作名（actionName + "_left" + keyOffset 后缀）
--- 与 AttackState 的区别：自动追加 "_left" 后缀以使用左侧攻击的 Spine 动画
function AttackLeftState.GetActionName(self, unitState, actionName)
	local fullActionName = actionName .. "_left"
	local keyOffset = unitState:ActionKeyOffset()

	if keyOffset then
		fullActionName = fullActionName .. keyOffset
	end

	return fullActionName
end
