ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class VictorySwimState : IUnitState
--- 胜利状态（潜水中）。潜艇/潜水单位在战斗胜利后的胜利动画。
---
--- 与 VictoryState 的对比：
--- 1. 相同点：所有 AddXxxState 均为 no-op（吸收态），CacheWeapon = true，
---    FreshActionKeyOffset = false。
--- 2. 不同点：
---    - GetActionName 返回 VICTORY_SWIM（而非 VICTORY）
---    - OnEnd 为 NO-OP（而非回到 StandState）
---      这意味着潜水单位的胜利动画是单向终结的，不会循环 Stand→Victory。
---      潜水单位胜利后直接留在 VictorySwim 动画上，不动了。
--- 3. 触发条件：UnitState.ChangeState 中，当请求 STATE_VICTORY 时，
---    如果检测到单位的 OxyState 为 DIVE（潜水中），则使用 VictorySwimState
---    而不是 VictoryState。
ys.Battle.VictorySwimState = class("VictorySwimState", ys.Battle.IUnitState)
ys.Battle.VictorySwimState.__name = "VictorySwimState"

local VictorySwimState = ys.Battle.VictorySwimState

--- @class VictorySwimState
--- @return nil
--- 构造函数
function VictorySwimState.Ctor(self)
	VictorySwimState.super.Ctor()
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许切换 Idle
function VictorySwimState.AddIdleState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许移动
function VictorySwimState.AddMoveState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许向左移动
function VictorySwimState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许攻击
function VictorySwimState.AddAttackState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许死亡
function VictorySwimState.AddDeadState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许使用技能
function VictorySwimState.AddSkillState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许施法
function VictorySwimState.AddSpellState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许切换 Victory
function VictorySwimState.AddVictoryState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 已在胜利-潜水状态，无需切换
function VictorySwimState.AddVictorySwimState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许站立
function VictorySwimState.AddStandState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许下潜
function VictorySwimState.AddDiveState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许下潜(向左)
function VictorySwimState.AddDiveLeftState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许打断
function VictorySwimState.AddInterruptState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许下潜过渡
function VictorySwimState.AddDivingState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许技能开始
function VictorySwimState.AddSkillStartState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许技能结束
function VictorySwimState.AddSkillEndState(self, unitState, args)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- 动画触发点（空实现）
function VictorySwimState.OnTrigger(self, unitState)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- 动画开始（空实现）
function VictorySwimState.OnStart(self, unitState)
	return
end

--- @class VictorySwimState
--- @param unitState UnitState
--- 胜利-潜水动画结束：与 VictoryState 不同，这里是 NO-OP。
--- 潜水单位的胜利动画单向终结，不再循环。
function VictorySwimState.OnEnd(self, unitState)
	return
end

--- @class VictorySwimState
--- @return boolean: true
--- 胜利状态允许缓存武器
function VictorySwimState.CacheWeapon(self)
	return true
end

--- @class VictorySwimState
--- @return boolean: false
--- 胜利状态不支持 ActionKeyOffset 后缀
function VictorySwimState.FreshActionKeyOffset(self)
	return false
end

--- @class VictorySwimState
--- @param unitState UnitState
--- @return string: "victory_swim"
--- 获取胜利-潜水状态的 Spine 动作名
function VictorySwimState.GetActionName(self, unitState)
	return ActionName.VICTORY_SWIM
end
