ys = ys or {}

local ys = ys

--- @class IUnitState : 单位状态机的抽象接口（基类）
--- 所有具体状态（IdleState, MoveState, AttackState 等）都继承自此类。
--- 每个 AddXxxState 方法代表状态机收到"切换到 Xxx State"的请求，
--- 由当前状态决定是否允许该切换以及如何响应。
--- 生命周期: OnStart → OnTrigger(可多次) → OnEnd
ys.Battle.IUnitState = class("IUnitState")
ys.Battle.IUnitState.__name = "IUnitState"

--- @class IUnitState
--- @return nil
--- 构造函数（空实现，子类可按需重写）
function ys.Battle.IUnitState.Ctor(self)
	return
end

--- @class IUnitState
--- @param unitState UnitState: 拥有本状态机的 UnitState 实例
--- @param args table: 额外参数（子类传递）
--- 请求切换到 Idle 状态
function ys.Battle.IUnitState.AddIdleState(self, unitState, args)
	assert(false, self.__name .. ".AddIdleState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Move（向右移动）状态
function ys.Battle.IUnitState.AddMoveState(self, unitState, args)
	assert(false, self.__name .. ".AddMoveState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 MoveLeft（向左移动）状态
function ys.Battle.IUnitState.AddMoveLeftState(self, unitState, args)
	assert(false, self.__name .. ".AddMoveLeftState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Diving（下潜过渡）状态
function ys.Battle.IUnitState.AddDivingState(self, unitState, args)
	assert(false, self.__name .. ".AddDivingState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Dive（下潜中，向右）状态
function ys.Battle.IUnitState.AddDiveState(self, unitState, args)
	assert(false, self.__name .. ".AddDiveState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 DiveLeft（下潜中，向左）状态
function ys.Battle.IUnitState.AddDiveLeftState(self, unitState, args)
	assert(false, self.__name .. ".AddDiveLeftState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Raid（突袭）状态
function ys.Battle.IUnitState.AddRaidState(self, unitState, args)
	assert(false, self.__name .. ".AddRaidState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table: 攻击动作名等附加参数
--- 请求切换到 Attack（攻击，向右）状态
function ys.Battle.IUnitState.AddAttackState(self, unitState, args)
	assert(false, self.__name .. ".AddAttackState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Dead（死亡）状态
function ys.Battle.IUnitState.AddDeadState(self, unitState, args)
	assert(false, self.__name .. ".AddDeadState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Skill（技能）状态
function ys.Battle.IUnitState.AddSkillState(self, unitState, args)
	assert(false, self.__name .. ".AddSkillState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Victory（胜利）状态
function ys.Battle.IUnitState.AddVictoryState(self, unitState, args)
	assert(false, self.__name .. ".AddVictoryState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 VictorySwim（胜利-潜水中）状态
function ys.Battle.IUnitState.AddVictorySwimState(self, unitState, args)
	assert(false, self.__name .. ".AddVictorySwimState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Spell（施法）状态
function ys.Battle.IUnitState.AddSpellState(self, unitState, args)
	assert(false, self.__name .. ".AddSpellState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Stand（站立/登场）状态
function ys.Battle.IUnitState.AddStandState(self, unitState, args)
	assert(false, self.__name .. ".AddStandState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 Interrupt（打断）状态
function ys.Battle.IUnitState.AddInterruptState(self, unitState, args)
	assert(false, self.__name .. ".AddInterruptState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 SkillStart（技能开始）状态
function ys.Battle.IUnitState.AddSkillStartState(self, unitState, args)
	assert(false, self.__name .. ".AddSkillStartState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table
--- 请求切换到 SkillEnd（技能结束）状态
function ys.Battle.IUnitState.AddSkillEndState(self, unitState, args)
	assert(false, self.__name .. ".AddSkillEndState: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- Spine 动画的"攻击触发点"回调（action trigger 事件）
--- 对应攻击动画中的关键帧，一般用于生成子弹
function ys.Battle.IUnitState.OnTrigger(self, unitState)
	assert(false, self.__name .. ".OnTrigger: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- Spine 动画开始时的回调
function ys.Battle.IUnitState.OnStart(self, unitState)
	assert(false, self.__name .. ".OnStart: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- Spine 动画结束时的回调
--- 通常在此执行状态切换（例如攻击结束后回到移动状态）
function ys.Battle.IUnitState.OnEnd(self, unitState)
	assert(false, self.__name .. ".OnEnd: this function must be override!")
end

--- @class IUnitState
--- @return boolean: true 表示当前状态允许缓存武器子弹
--- 是否需要缓存子弹（攻击动作的前摇阶段不缓存，以便在 OnTrigger 时发射）
function ys.Battle.IUnitState.CacheWeapon(self)
	assert(false, self.__name .. ".CacheWeapon: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- 刷新 ActionKeyOffset（用于 Spine 动画名后缀，如 "_move" 后缀不同动作变体）
function ys.Battle.IUnitState.FreshActionKeyOffset(self, unitState)
	assert(false, self.__name .. ".FreshActionKeyOffset: this function must be override!")
end

--- @class IUnitState
--- @param unitState UnitState
--- @param args table: 额外参数（攻击状态传递攻击动作名）
--- @return string: Spine 动作名称
--- 获取当前状态对应的 Spine 动画名称
function ys.Battle.IUnitState.GetActionName(self, unitState, args)
	assert(false, self.__name .. ".GetActionName: this function must be override!")
end
