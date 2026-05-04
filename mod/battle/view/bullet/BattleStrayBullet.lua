--- 散弹/流弹视图（Shotgun/Scatter 类型子弹）
--- 继承 BattleBullet，覆写 SetSpawn 实现螺旋式随机偏移飞行轨迹。
---
--- 特殊视觉效果：
--- - 螺旋飞行：_doStray 实现一种类似"随机游走"的视觉效果，子弹在飞向目标的过程中
---   会产生逐渐衰减的侧向摆动（count 值逐渐衰减 → 摆动幅度减小 → 轨迹趋于直线）
--- - SetSpawn 覆写：在父类的基础上额外初始化弹道参数（目标点、速度方向、步数、随机偏转计数）
--- @class BattleStrayBullet : BattleBullet
--- @field _targetPos Vector3 目标位置（爆点）
--- @field _spawnDir Vector3 出生时的速度方向（归一化）
--- @field _velocity number 换算后的子弹速度
--- @field _step number 到达目标所需的帧数（距离 / 速度）
--- @field _count number 随机偏转计数，控制螺旋幅度（初始值 [-300, 300)）

ys = ys or {}

local ys = ys
local BattleResourceManager = ys.Battle.BattleResourceManager

ys.Battle.BattleStrayBullet = class("BattleStrayBullet", ys.Battle.BattleBullet)
ys.Battle.BattleStrayBullet.__name = "BattleStrayBullet"

local BattleStrayBullet = ys.Battle.BattleStrayBullet

--- 构造函数
--- 直接调用父类 Ctor
function BattleStrayBullet.Ctor(self, arg1, arg2)
    BattleStrayBullet.super.Ctor(self, arg1, arg2)
end

--- 设置子弹出生点（覆写父类）
--- 在父类 SetSpawn 的基础上，额外初始化弹道参数：
--- - 记录目标点（爆点位置）
--- - 记录初始速度方向
--- - 计算到达目标所需帧数 step
--- - 生成随机偏转计数 count（控制螺旋视觉效果）
--- - 将 updateSpeed 替换为 _doStray（覆盖数据层的速度更新逻辑）
--- @param spawnPos Vector3 出生坐标
function BattleStrayBullet.SetSpawn(self, spawnPos)
    BattleStrayBullet.super.SetSpawn(self, spawnPos)

    -- 记录目标位置（爆炸点）
    self._targetPos = Clone(self._bulletData:GetExplodePostion())
    self._spawnDir = self._speed.normalized

    -- 计算考虑了 bulletSpeedRatio 加成后的换算速度
    local speedRatio = 1 + ys.Battle.BattleAttr.GetCurrent(self._bulletData, "bulletSpeedRatio")

    self._velocity = self._bulletData:GetVelocity() * speedRatio
    self._velocity = ys.Battle.BattleFormulas.ConvertBulletSpeed(self._velocity)
    -- 到达目标所需的帧数
    self._step = Vector3.Distance(self._targetPos, self._spawnPos) / self._velocity
    -- 随机偏转计数：[-300, 300)，控制侧向摆动幅度
    self._count = math.random(600) - 300
    -- 覆盖数据层的 updateSpeed 为视图层自定义螺旋逻辑
    self.updateSpeed = BattleStrayBullet._doStray
end

--- 螺旋飞行逻辑（替代数据层 updateSpeed）
--- 每帧执行，产生逐渐衰减的侧向偏移效果：
--- 1. 计算到目标的方向向量
--- 2. 叠加一个垂直方向的分量（_count 控制幅度，逐帧衰减 ×1/1.06）
--- 3. 归一化后乘以速度，得到最终速度向量
--- 当 step <= 0 或目标不存在时，恢复为原来的 updateSpeed（由数据层驱动）
function BattleStrayBullet._doStray(self)
    local targetPos = self._targetPos

    if self._step > 0 and targetPos and not targetPos:EqualZero() then
        -- 偏转计数衰减（1.06 是衰减因子，使摆动逐渐减小）
        self._count = self._count / 1.06
        self._step = self._step - 1

        local bulletPos = self._bulletData:GetPosition()
        local velocity = self._velocity

        -- 方向向量 = 指向目标
        self._speed = Vector3(targetPos.x - bulletPos.x, 0, targetPos.z - bulletPos.z).normalized
        -- 叠加垂直侧向分量：(speed.z * count/100, 0, -speed.x * count/100) 实现绕运动方向的旋转偏移
        self._speed = self._speed + Vector3(self._speed.z * self._count / 100, 0, -self._speed.x * self._count / 100)
        self._speed = self._speed.normalized
        self._speed = Vector3(self._speed.x * velocity, 0, self._speed.z * velocity)
    else
        -- 到达目标或目标无效，恢复数据层的原始速度更新逻辑
        self.updateSpeed = BattleStrayBullet._updateSpeed
    end
end
