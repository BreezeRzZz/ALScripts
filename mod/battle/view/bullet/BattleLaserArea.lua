--- 激光区域视图
--- 继承 BattleBullet，用于显示持续性激光/光束区域的视觉表现。
--- 覆写 Update 使其仅在子弹速度非零时才同步位置。
---
--- 特殊视觉效果：
--- - 条件更新：只有速度不为零时才调用 UpdatePosition。激光区域通常是静止的（速度为零），
---   这意味着它在大部分时间内不会做不必要的 Transform 同步。
---   只有当激光正在展开或收缩（速度非零）时才更新位置。
--- - 用途：激光束扫过区域、航母空袭预警线、持续性范围攻击的视觉指示器等。
--- @class BattleLaserArea : BattleBullet

ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleResourceManager = ys.Battle.BattleResourceManager
local BattleConfig = ys.Battle.BattleConfig
local BattleLaserArea = class("BattleLaserArea", ys.Battle.BattleBullet)

ys.Battle.BattleLaserArea = BattleLaserArea
BattleLaserArea.__name = "BattleLaserArea"

--- 每帧更新（覆写父类）
--- 激光区域仅在速度非零时才同步位置，静止时跳过以减少不必要的 Transform 写入。
--- @param timeStamp number 当前时间戳
function BattleLaserArea.Update(self, timeStamp)
    local bulletSpeed = self._bulletData:GetSpeed()

    -- 仅当速度非零（激光正在展开/收缩/移动）时才更新位置
    if bulletSpeed.x ~= 0 or bulletSpeed.z ~= 0 or bulletSpeed.y ~= 0 then
        self:UpdatePosition()
    end
end
