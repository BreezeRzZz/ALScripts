ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

--- @class EngageAntiSubState : IAntiSubState
--- 反潜警戒状态 — ENGAGE（交战）
---
--- 水面舰船已锁定敌方潜艇目标，进入交战状态。
--- 这是反潜警戒的最高级别，此时反潜武器（深水炸弹等）可以使用。
---
--- 状态特征:
---   - 计量表速度: 5（警戒值快速上升，维持 ENGAGE 锁定）
---   - 衰减持续时间: 3 秒（若无新信号，3秒后开始衰减）
---   - 是否允许衰减: true
---   - 警告标记: 3（最高级别警告）
---   - 武器可用: { OXY_STATE.FLOAT }——当潜艇处于水面状态时可使用反潜武器
---     （即深水炸弹等反潜武器在潜艇潜航时无法使用，需潜艇浮出水面）
---
--- 状态转换:
---   ENGAGE → VIGILANT: 衰减超时（ToPreLevel）——锁定丢失
---
--- 注意：进入 ENGAGE 时 AntiSubState 控制器会设置 _engageRage = true，
--- 这意味着即使在衰减期，只要有新的潜艇信号（水雷/上浮），会直接重新进入 ENGAGE。
ys.Battle.EngageAntiSubState = class("EngageAntiSubState", ys.Battle.IAntiSubState)
ys.Battle.EngageAntiSubState.__name = "EngageAntiSubState"

local EngageAntiSubState = ys.Battle.EngageAntiSubState

--- 构造函数
function EngageAntiSubState.Ctor(self)
	EngageAntiSubState.super.Ctor(self)
end

--- 警戒区域交战：已在 ENGAGE 状态，无需变化
--- @param ctrl AntiSubState 控制器实例
function EngageAntiSubState.OnVigilantEngage(self, ctrl)
	return
end

--- 水雷爆炸：已在 ENGAGE 状态，保持不变
--- @param ctrl AntiSubState 控制器实例
function EngageAntiSubState.OnMineExplode(self, ctrl)
	return
end

--- 潜艇上浮：已在 ENGAGE 状态，保持不变
--- @param ctrl AntiSubState 控制器实例
function EngageAntiSubState.OnSubmarinFloat(self, ctrl)
	return
end

--- 降级到 VIGILANT 状态
--- 交战状态衰减后锁定丢失，回退到警戒状态
--- @param ctrl AntiSubState 控制器实例
function EngageAntiSubState.ToPreLevel(self, ctrl)
	ctrl:OnVigilantState()
end

--- 仇恨链：已在 ENGAGE 状态，保持不变
--- @param ctrl AntiSubState 控制器实例
function EngageAntiSubState.OnHateChain(self, ctrl)
	return
end

--- 武器可用：仅当潜艇处于水面 (FLOAT) 状态时允许使用反潜武器
--- 这意味着深水炸弹等反潜武器需要潜艇浮出水面才能有效攻击
--- @return table 包含 OXY_STATE.FLOAT 的列表
function EngageAntiSubState.GetWeaponUseable(self)
	return {
		BattleConst.OXY_STATE.FLOAT
	}
end

--- 允许衰减：ENGAGE 状态会随时间衰减
--- @return boolean
function EngageAntiSubState.CanDecay(self)
	return true
end

--- 警告标记 = 3：交战级别（最高）
--- @return number
function EngageAntiSubState.GetWarnMark(self)
	return 3
end

--- 计量表速度 = 5：警戒值快速上升以维持 ENGAGE 锁定
--- @return number
function EngageAntiSubState.GetMeterSpeed(self)
	return 5
end

--- 衰减持续时间 = 3 秒：相对较长，给予稳定锁定窗口
--- @return number
function EngageAntiSubState.DecayDuration(self)
	return 3
end
