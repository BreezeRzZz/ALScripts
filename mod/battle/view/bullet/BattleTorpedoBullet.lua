--- 鱼雷子弹视图
--- 继承 BattleBullet，新增鱼雷特有行为：加速推进、预警标记、中立化处理。
---
--- 特殊视觉效果：
--- - 预警标记：通过 TorAlert 在地面显示鱼雷接近预警线（红色三角形区域）
--- - Advance 加速：鱼雷发射后有一个加速阶段，速度翻倍
--- - Neutrailze 中立化：被声呐/反潜装备抵消时仅隐藏，不调用 miss 回调（不播放消失特效）
--- - GetZExtraOffset 覆写：鱼雷在水面运行，不需要高度 Z 轴补偿，始终返回 0
--- @class BattleTorpedoBullet : BattleBullet
--- @field _alert TorAlert 鱼雷预警标记
--- @field _speed number 当前速度

ys = ys or {}

local ys = ys
local BattleTorpedoBullet = ys.Battle.BattleTorpedoBullet
local BattleResourceManager = ys.Battle.BattleResourceManager

ys.Battle.BattleTorpedoBullet = class("BattleTorpedoBullet", ys.Battle.BattleBullet)
ys.Battle.BattleTorpedoBullet.__name = "BattleTorpedoBullet"

local BattleTorpedoBullet = ys.Battle.BattleTorpedoBullet

--- 构造函数
--- 直接调用父类 Ctor
function BattleTorpedoBullet.Ctor(self)
    BattleTorpedoBullet.super.Ctor(self)
end

--- 清理资源
--- 先销毁预警标记，再调用父类 Dispose
function BattleTorpedoBullet.Dispose(self)
    if self._alert then
        self._alert:Dispose()
    end

    BattleTorpedoBullet.super.Dispose(self)
end

--- 鱼雷加速推进
--- 将当前速度翻倍，用于鱼雷发射后的加速阶段
function BattleTorpedoBullet.Advance(self)
    self._speed = self._speed * 2
end

--- 计算 Z 轴额外偏移量（覆写父类）
--- 鱼雷在水面高度运行，不需要透视高度补偿，始终返回 0
--- @param spawnY number 出生点 Y 坐标（未使用）
--- @return number 始终返回 0
function BattleTorpedoBullet.GetZExtraOffset(spawnY)
    return 0
end

--- 创建鱼雷预警标记
--- 在地面显示一个三角预警区域，提醒玩家鱼雷正在接近
--- @param template table 预警模板数据
function BattleTorpedoBullet.MakeAlert(self, template)
    self._alert = ys.Battle.TorAlert.New(template)

    self._alert:SetPosition(self._bulletData:GetPosition(), self._bulletData:GetYAngle())
end

--- 中立化处理（覆写父类）
--- 鱼雷被抵消时仅隐藏 GameObject，不调用 miss 回调（不播放消失特效），
--- 这与普通子弹不同，因为鱼雷的中立化由声呐系统处理，视觉表现有别于常规消失
function BattleTorpedoBullet.Neutrailze(self)
    SetActive(self._go, false)
end
