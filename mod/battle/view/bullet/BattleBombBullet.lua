--- 炸弹子弹视图（空投/轰炸类型）
--- 继承 BattleBullet，新增爆炸事件处理和平滑移动插值。
---
--- 特殊视觉效果：
--- - 爆炸回调：监听数据层 EXPLODE 事件，触发命中特效（不同于普通子弹的 HIT 事件）
--- - 平滑移动：UpdatePosition 使用 Lerp 插值，使炸弹下落轨迹更平滑自然
--- - 预警标记：通过 _alert (TorAlert) 在地面显示炸弹落点预警圈
--- @class BattleBombBullet : BattleBullet
--- @field _alert TorAlert 地面预警标记（红色圆圈）

ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleResourceManager = ys.Battle.BattleResourceManager
local BattleConfig = ys.Battle.BattleConfig
local BattleBombBullet = class("BattleBombBullet", ys.Battle.BattleBullet)

ys.Battle.BattleBombBullet = BattleBombBullet
BattleBombBullet.__name = "BattleBombBullet"

--- 构造函数
--- 直接调用父类 Ctor
function BattleBombBullet.Ctor(self)
    BattleBombBullet.super.Ctor(self)
end

--- 清理资源
--- 先销毁预警标记，再调用父类 Dispose
function BattleBombBullet.Dispose(self)
    if self._alert then
        self._alert:Dispose()
    end

    BattleBombBullet.super.Dispose(self)
end

--- 注册数据层事件监听（覆写父类）
--- 炸弹额外监听 EXPLODE 事件，爆炸时触发 onBulletExplode
function BattleBombBullet.AddBulletEvent(self)
    self._bulletData:RegisterEventListener(self, BattleBulletEvent.EXPLODE, self.onBulletExplode)
end

--- 移除数据层事件监听（覆写父类）
function BattleBombBullet.RemoveBulletEvent(self)
    self._bulletData:UnregisterEventListener(self, BattleBulletEvent.EXPLODE)
end

--- 炸弹爆炸回调（从数据层 EXPLODE 事件触发）
--- 直接调用命中回调函数，不同于普通子弹需要传入目标 UID
function BattleBombBullet.onBulletExplode(self, event)
    self._bulletHitFunc(self)
end

--- 同步位置到 Transform（覆写父类）
--- 使用 Lerp 线性插值实现平滑移动，BulletMotionRate 控制插值速率，
--- 让炸弹下落轨迹比直接 snap 到数据位置更自然。
function BattleBombBullet.UpdatePosition(self)
    local lerpedPos = Vector3.Lerp(self._tf.localPosition, self:GetPosition(), BattleConfig.BulletMotionRate)

    self._tf.localPosition = lerpedPos

    self._cacheTFPos:Set(lerpedPos.x, lerpedPos.y, lerpedPos.z)
end
