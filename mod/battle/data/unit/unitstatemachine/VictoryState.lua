ys = ys or {}

local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

--- @class VictoryState : IUnitState
--- 胜利状态（水面）。战斗胜利后单位播放胜利动画。
---
--- 关键机制：
--- 1. 所有 AddXxxState 均为 no-op —— Victory 是吸收态/终态。
---    进入胜利后，单位不再响应任何状态切换请求。
--- 2. OnEnd → OnStandState() —— 胜利动画结束后回到站立状态。
---    配合 StandState.OnEnd → OnVictoryState()，可形成
---    Stand → Victory → Stand → ... 的循环（反复亮相动画）。
---    实际用途：胜利结算时单位循环播放 victory 和 stand 动画。
--- 3. GetActionName 返回 VICTORY（"victory"）动作名。
--- 4. CacheWeapon = true —— 胜利时不需要缓存新子弹，
---    但返回 true 不影响现有缓存。
--- 5. FreshActionKeyOffset = false —— 不支持 keyOffset 后缀。
--- 6. 与 VictorySwimState 的区别：此状态用于水面/非潜水单位，
---    潜水单位使用 VictorySwimState（动画名 "victory_swim"）。
ys.Battle.VictoryState = class("VictoryState", ys.Battle.IUnitState)
ys.Battle.VictoryState.__name = "VictoryState"

local VictoryState = ys.Battle.VictoryState

--- @class VictoryState
--- @return nil
--- 构造函数
function VictoryState.Ctor(self)
	VictoryState.super.Ctor()
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许切换 Idle
function VictoryState.AddIdleState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许移动
function VictoryState.AddMoveState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许向左移动
function VictoryState.AddMoveLeftState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许攻击
function VictoryState.AddAttackState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许死亡
function VictoryState.AddDeadState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许使用技能
function VictoryState.AddSkillState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许施法
function VictoryState.AddSpellState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 已在胜利状态，无需切换
function VictoryState.AddVictoryState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许切换胜利-潜水
function VictoryState.AddVictorySwimState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许站立
function VictoryState.AddStandState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许下潜
function VictoryState.AddDiveState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许下潜(向左)
function VictoryState.AddDiveLeftState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许打断
function VictoryState.AddInterruptState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许下潜过渡
function VictoryState.AddDivingState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许技能开始
function VictoryState.AddSkillStartState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- @param args table
--- 胜利状态不允许技能结束
function VictoryState.AddSkillEndState(self, unitState, args)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- 动画触发点（空实现）
function VictoryState.OnTrigger(self, unitState)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- 动画开始（空实现）
function VictoryState.OnStart(self, unitState)
	return
end

--- @class VictoryState
--- @param unitState UnitState
--- 胜利动画结束：回到站立状态，形成 Stand -> Victory 循环
function VictoryState.OnEnd(self, unitState)
	unitState:OnStandState()
end

--- @class VictoryState
--- @return boolean: true
--- 胜利状态允许缓存武器
function VictoryState.CacheWeapon(self)
	return true
end

--- @class VictoryState
--- @return boolean: false
--- 胜利状态不支持 ActionKeyOffset 后缀
function VictoryState.FreshActionKeyOffset(self)
	return false
end

--- @class VictoryState
--- @param unitState UnitState
--- @return string: "victory"
--- 获取胜利状态的 Spine 动作名
function VictoryState.GetActionName(self, unitState)
	return ActionName.VICTORY
end
