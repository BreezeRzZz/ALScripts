--- 缩放子弹视图
--- 继承 BattleBullet，新增模型缩放功能。每帧根据数据层碰撞体的尺寸动态调 Transform.localScale。
---
--- 特殊视觉效果：
--- - 动态缩放：子弹模型的 scale 根据数据层的碰撞盒大小 (GetBoxSize().x * 2) 实时调整。
---   这使得类似激光、护盾墙等尺寸可变的"子弹"能在视觉上正确反映其实际碰撞范围。
--- - 用途：主要用于光束 (Beam)、护盾墙等非传统子弹，其视觉尺寸在发射过程中会变化。
--- @class BattleScaleBullet : BattleBullet

ys = ys or {}

local ys = ys

ys.Battle.BattleScaleBullet = class("BattleScaleBullet", ys.Battle.BattleBullet)
ys.Battle.BattleScaleBullet.__name = "BattleScaleBullet"

local BattleScaleBullet = ys.Battle.BattleScaleBullet

--- 构造函数
--- 直接调用父类 Ctor
function BattleScaleBullet.Ctor(self)
    BattleScaleBullet.super.Ctor(self)
end

--- 每帧更新（覆写父类）
--- 在父类 Update 之后额外调用 updateModelScale 调整模型缩放
--- @param timeStamp number 当前时间戳
function BattleScaleBullet.Update(self, timeStamp)
    BattleScaleBullet.super.Update(self, timeStamp)
    self:updateModelScale()
end

--- 更新模型缩放
--- 根据数据层碰撞盒尺寸动态调整 Transform.localScale
--- scale.x = 碰撞盒宽度 * 2（因为 GetBoxSize 返回的是半尺寸），y/z 保持不变
function BattleScaleBullet.updateModelScale(self)
    local newScale

    -- 从数据层获取碰撞盒尺寸，x 方向 * 2 作为新的 scale.x
    newScale.x, newScale = self._bulletData:GetBoxSize().x * 2, self._tf.localScale
    self._tf.localScale = newScale
end
