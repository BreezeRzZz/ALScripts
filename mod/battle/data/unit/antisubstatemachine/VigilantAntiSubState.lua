ys = ys or {}

local ys = ys

--- @class VigilantAntiSubState : IAntiSubState
--- 反潜警戒状态 — VIGILANT（警戒）
---
--- 水面舰船已通过声纳确认探测到敌方潜艇，正在追踪目标。
--- 但仍需进一步积累警戒值或收到仇恨链信号才能进入 ENGAGE 交战状态。
---
--- 状态特征:
---   - 计量表速度: 1.3（警戒值以较快速度上升）
---   - 衰减持续时间: 2 秒（若无新信号，2秒后开始衰减）
---   - 是否允许衰减: true
---   - 警告标记: 2（中级别警告）
---   - 武器可用: 无（反潜武器尚未解锁，需进入 ENGAGE）
---
--- 状态转换:
---   VIGILANT → ENGAGE:     仇恨链信号（HateChain）——编队共享反潜锁定
---   VIGILANT → SUSPICIOUS: 衰减超时（ToPreLevel）
ys.Battle.VigilantAntiSubState = class("VigilantAntiSubState", ys.Battle.IAntiSubState)
ys.Battle.VigilantAntiSubState.__name = "VigilantAntiSubState"

local VigilantAntiSubState = ys.Battle.VigilantAntiSubState

--- 构造函数
function VigilantAntiSubState.Ctor(self)
	VigilantAntiSubState.super.Ctor(self)
end

--- 警戒区域交战：已在 VIGILANT 状态，无需变化
--- @param ctrl AntiSubState 控制器实例
function VigilantAntiSubState.OnVigilantEngage(self, ctrl)
	return
end

--- 水雷爆炸：已在 VIGILANT 状态，保持不变
--- @param ctrl AntiSubState 控制器实例
function VigilantAntiSubState.OnMineExplode(self, ctrl)
	return
end

--- 潜艇上浮：已在 VIGILANT 状态，保持不变
--- @param ctrl AntiSubState 控制器实例
function VigilantAntiSubState.OnSubmarinFloat(self, ctrl)
	return
end

--- 仇恨链 → 直接升级到 ENGAGE 状态
--- 这是 VIGILANT → ENGAGE 的唯一触发方式
--- 当编队内其他单位通过 HATE_CHAIN 事件传递反潜锁定信号时
--- 参数 true 表示跳过 DispatchHateChain（避免无限循环）
--- @param ctrl AntiSubState 控制器实例
function VigilantAntiSubState.OnHateChain(self, ctrl)
	ctrl:OnEngageState(true)
end

--- 降级到 SUSPICIOUS 状态
--- 经过衰减期后声纳信号丢失，回归可疑状态
--- @param ctrl AntiSubState 控制器实例
function VigilantAntiSubState.ToPreLevel(self, ctrl)
	ctrl:OnSuspiciousState()
end

--- 武器不可用：VIGILANT 状态尚未解锁反潜武器
--- @return table 空表
function VigilantAntiSubState.GetWeaponUseable(self)
	return {}
end

--- 允许衰减
--- @return boolean
function VigilantAntiSubState.CanDecay(self)
	return true
end

--- 警告标记 = 2：警戒级别
--- @return number
function VigilantAntiSubState.GetWarnMark(self)
	return 2
end

--- 计量表速度 = 1.3：警戒值较快上升
--- @return number
function VigilantAntiSubState.GetMeterSpeed(self)
	return 1.3
end

--- 衰减持续时间 = 2 秒
--- @return number
function VigilantAntiSubState.DecayDuration(self)
	return 2
end
