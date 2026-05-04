ys = ys or {}

local ys = ys

--- @class CalmAntiSubState : IAntiSubState
--- 反潜警戒状态 — CALM（平静）
---
--- 水面舰船的默认反潜状态。此时舰船未探测到任何潜艇活动迹象。
---
--- 状态特征:
---   - 计量表速度: -1（警戒值持续下降，保持低水平）
---   - 衰减持续时间: 0（不衰减，因为已是基础状态）
---   - 是否允许衰减: false（无法从 CALM 进一步降级）
---   - 警告标记: 0（无警告显示）
---   - 武器可用: 无（所有反潜武器被禁用）
---
--- 状态转换:
---   CALM → SUSPICIOUS: 水雷爆炸 / 潜艇上浮 / 仇恨链
---   CALM → VIGILANT:   警戒区域交战（进入声纳范围）
ys.Battle.CalmAntiSubState = class("CalmAntiSubState", ys.Battle.IAntiSubState)
ys.Battle.CalmAntiSubState.__name = "CalmAntiSubState"

local CalmAntiSubState = ys.Battle.CalmAntiSubState

--- 构造函数
function CalmAntiSubState.Ctor(self)
	CalmAntiSubState.super.Ctor(self)
end

--- 警戒区域交战 → 升级到 VIGILANT 状态
--- 当舰船进入声纳/反潜警戒范围时触发
--- @param ctrl AntiSubState 控制器实例
function CalmAntiSubState.OnVigilantEngage(self, ctrl)
	ctrl:OnVigilantState()
end

--- 水雷爆炸 → 升级到 SUSPICIOUS 状态
--- 附近的友方水雷爆炸表明该区域可能有潜艇活动
--- @param ctrl AntiSubState 控制器实例
function CalmAntiSubState.OnMineExplode(self, ctrl)
	ctrl:OnSuspiciousState()
end

--- 潜艇上浮 → 升级到 SUSPICIOUS 状态
--- 侦测到敌方潜艇浮出水面
--- @param ctrl AntiSubState 控制器实例
function CalmAntiSubState.OnSubmarinFloat(self, ctrl)
	ctrl:OnSuspiciousState()
end

--- 仇恨链 → 升级到 SUSPICIOUS 状态
--- 编队内其他单位共享的反潜仇恨信息
--- @param ctrl AntiSubState 控制器实例
function CalmAntiSubState.OnHateChain(self, ctrl)
	ctrl:OnSuspiciousState()
end

--- 降级到前级：CALM 是最低级别，无更低状态
--- @param ctrl AntiSubState 控制器实例
function CalmAntiSubState.ToPreLevel(self, ctrl)
	return
end

--- 武器不可用：CALM 状态下所有反潜武器禁用
--- @return table 空表，表示无允许的武器状态
function CalmAntiSubState.GetWeaponUseable(self)
	return {}
end

--- 不允许衰减：CALM 是基础状态
--- @return boolean
function CalmAntiSubState.CanDecay(self)
	return false
end

--- 警告标记 = 0：无警告
--- @return number
function CalmAntiSubState.GetWarnMark(self)
	return 0
end

--- 计量表速度 = -1：警戒值持续降低（向0靠近）
--- @return number
function CalmAntiSubState.GetMeterSpeed(self)
	return -1
end

--- 衰减持续时间 = 0：CALM 已是基础状态，无需衰减
--- @return number
function CalmAntiSubState.DecayDuration(self)
	return 0
end
