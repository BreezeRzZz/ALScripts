ys = ys or {}

local ys = ys

--- @class SuspiciousAntiSubState : IAntiSubState
--- 反潜警戒状态 — SUSPICIOUS（可疑）
---
--- 水面舰船探测到可能存在潜艇的间接迹象，但尚未通过声纳确认。
--- 这是从 CALM 到 VIGILANT 的中间过渡状态。
---
--- 状态特征:
---   - 计量表速度: 1（警戒值开始缓慢上升）
---   - 衰减持续时间: 1 秒（若无新信号，1秒后开始衰减）
---   - 是否允许衰减: true
---   - 警告标记: 1（低级别警告）
---   - 武器可用: 无（反潜武器仍被禁用）
---
--- 状态转换:
---   SUSPICIOUS → VIGILANT:   声纳探测 / 水雷爆炸 / 潜艇上浮 / 警戒区域 / 仇恨链
---   SUSPICIOUS → CALM:       衰减超时（ToPreLevel）
ys.Battle.SuspiciousAntiSubState = class("SuspiciousAntiSubState", ys.Battle.IAntiSubState)
ys.Battle.SuspiciousAntiSubState.__name = "SuspiciousAntiSubState"

local SuspiciousAntiSubState = ys.Battle.SuspiciousAntiSubState

--- 构造函数
function SuspiciousAntiSubState.Ctor(self)
	SuspiciousAntiSubState.super.Ctor(self)
end

--- 警戒区域交战 → 升级到 VIGILANT 状态
--- 在可疑状态下进入声纳范围，直接跳到警戒
--- @param ctrl AntiSubState 控制器实例
function SuspiciousAntiSubState.OnVigilantEngage(self, ctrl)
	ctrl:OnVigilantState()
end

--- 水雷爆炸 → 升级到 VIGILANT 状态
--- 在可疑状态下再次侦测到水雷，确认潜艇存在
--- @param ctrl AntiSubState 控制器实例
function SuspiciousAntiSubState.OnMineExplode(self, ctrl)
	ctrl:OnVigilantState()
end

--- 潜艇上浮 → 升级到 VIGILANT 状态
--- 在可疑状态下观测到潜艇上浮，确认威胁
--- @param ctrl AntiSubState 控制器实例
function SuspiciousAntiSubState.OnSubmarinFloat(self, ctrl)
	ctrl:OnVigilantState()
end

--- 降级到 CALM 状态
--- 经过衰减期后若无新的潜艇活动信号，回归平静
--- @param ctrl AntiSubState 控制器实例
function SuspiciousAntiSubState.ToPreLevel(self, ctrl)
	ctrl:OnCalmState()
end

--- 仇恨链 → 升级到 VIGILANT 状态
--- 编队内共享的反潜信息确认了潜艇威胁
--- @param ctrl AntiSubState 控制器实例
function SuspiciousAntiSubState.OnHateChain(self, ctrl)
	ctrl:OnVigilantState()
end

--- 武器不可用：SUSPICIOUS 状态下仍未确认目标
--- @return table 空表
function SuspiciousAntiSubState.GetWeaponUseable(self)
	return {}
end

--- 允许衰减
--- @return boolean
function SuspiciousAntiSubState.CanDecay(self)
	return true
end

--- 警告标记 = 1：可疑级别
--- @return number
function SuspiciousAntiSubState.GetWarnMark(self)
	return 1
end

--- 计量表速度 = 1：警戒值缓慢上升
--- @return number
function SuspiciousAntiSubState.GetMeterSpeed(self)
	return 1
end

--- 衰减持续时间 = 1 秒
--- @return number
function SuspiciousAntiSubState.DecayDuration(self)
	return 1
end
