ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class AttackState : IUnitState
--- 攻击状态（向右）。单位正在播放攻击动画。
---
--- 关键机制：
--- 1. CacheWeapon = false —— 攻击时不缓存武器子弹！
---    这意味着在攻击前摇阶段创建的子弹不会直接发射，而是等到
---    OnTrigger（spine动画触发点）时通过 SendAttackTrigger 统一发射。
---    这实现了"前摇蓄力 → 触发点发射"的子弹发射机制。
--- 2. OnTrigger 调用 target:SendAttackTrigger() —— 这是子弹实际生成的触发点，
---    对应 Spine 动画中标记的攻击关键帧（通常为 0.2s 处）。
--- 3. OnEnd 调用 ChangeToMoveState() —— 攻击动画结束后自动回到移动状态。
--- 4. 攻击状态中大多数状态切换被阻断（return），只允许 Dead/Spell/Victory/
---    Interrupt/Diving/SkillStart 的切换。其中 Interrupt/Diving 会先调用 OnTrigger
---    （确保即使攻击被打断，子弹也会发射出去）。
--- 5. GetActionName 的 actionName 参数直接来自调用方传入的攻击动作名（如 "attack"），
---    而非 ActionName 常量 —— 这允许不同武器/技能使用不同的攻击动画。
ys.Battle.AttackState = class("AttackState", ys.Battle.IUnitState)
ys.Battle.AttackState.__name = "AttackState"

local AttackState = ys.Battle.AttackState

--- @class AttackState
--- @return nil
--- 构造函数
function AttackState.Ctor(self)
	AttackState.super.Ctor()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换回 Idle
function AttackState.AddIdleState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换移动状态
function AttackState.AddMoveState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换向左移动
function AttackState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 已在攻击状态，不允许叠加新的攻击
function AttackState.AddAttackState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许死亡（单位被击沉）
function AttackState.AddDeadState(self, unitState, args)
	unitState:OnDeadState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换到技能状态
function AttackState.AddSkillState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到施法状态
function AttackState.AddSpellState(self, unitState, args)
	unitState:OnSpellState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到胜利状态
function AttackState.AddVictoryState(self, unitState, args)
	unitState:OnVictoryState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到胜利-潜水状态
function AttackState.AddVictorySwimState(self, unitState, args)
	unitState:OnVictorySwimState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换站立状态
function AttackState.AddStandState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许下潜
function AttackState.AddDiveState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许下潜(向左)
function AttackState.AddDiveLeftState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击被打断：先触发 OnTrigger（确保子弹已发射），再进入打断状态
function AttackState.AddInterruptState(self, unitState, args)
	self:OnTrigger(unitState)
	unitState:OnInterruptState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击中下潜过渡：先触发 OnTrigger（发射子弹），再进入下潜过渡
function AttackState.AddDivingState(self, unitState, args)
	self:OnTrigger(unitState)
	unitState:OnDivingState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间允许切换到技能开始状态
function AttackState.AddSkillStartState(self, unitState, args)
	unitState:OnSkillStartState()
end

--- @class AttackState
--- @param unitState UnitState
--- @param args table
--- 攻击期间不允许切换到技能结束状态
function AttackState.AddSkillEndState(self, unitState, args)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- 攻击动画触发点：生成缓存子弹。
--- 对应 Spine 动画中的攻击关键帧事件，此时会调用 BattleUnit:SendAttackTrigger()
--- 实际效果是发射 Weapon 在 CacheWeapon 阶段缓存的子弹。
function AttackState.OnTrigger(self, unitState)
	unitState:GetTarget():SendAttackTrigger()
end

--- @class AttackState
--- @param unitState UnitState
--- 攻击动画开始（空实现）
function AttackState.OnStart(self, unitState)
	return
end

--- @class AttackState
--- @param unitState UnitState
--- 攻击动画结束：自动切换回移动状态（根据当前速度方向决定 Move 或 MoveLeft）
function AttackState.OnEnd(self, unitState)
	unitState:ChangeToMoveState()
end

--- @class AttackState
--- @return boolean: false
--- 攻击状态不缓存武器子弹 —— 子弹在 OnTrigger 时统一发射
function AttackState.CacheWeapon(self)
	return false
end

--- @class AttackState
--- @return boolean: true
--- 攻击状态需要刷新 ActionKeyOffset
function AttackState.FreshActionKeyOffset(self)
	return true
end

--- @class AttackState
--- @param unitState UnitState
--- @param actionName string: 调用方传入的攻击动作名（如 "attack"），非 ActionName 常量
--- @return string: 完整的 Spine 攻击动作名（+ keyOffset 后缀）
--- 攻击动作名由调用方指定，这允许不同武器/技能使用不同的攻击动画
function AttackState.GetActionName(self, unitState, actionName)
	local fullActionName = actionName
	local keyOffset = unitState:ActionKeyOffset()

	if keyOffset then
		fullActionName = fullActionName .. keyOffset
	end

	return fullActionName
end
