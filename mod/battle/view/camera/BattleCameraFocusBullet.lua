ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleCameraFocusBullet = class("BattleCameraFocusBullet")
ys.Battle.BattleCameraFocusBullet.__name = "BattleCameraFocusBullet"

local BattleCameraFocusBullet = ys.Battle.BattleCameraFocusBullet

--- @class BattleCameraFocusBullet
--- 摄像机枪弹聚焦
--- 用于将摄像机焦点锁定在某颗子弹上，计算跟随子弹的摄像机位置。
--- 与 BattleCameraFocusChar 类似，但针对子弹进行了简化：不做敌我偏移。

--- @return nil
--- 构造函数
function BattleCameraFocusBullet.Ctor(self)
	return
end

--- @param bullet BattleBulletUnit 要聚焦的子弹单位
--- @return nil
--- 设置要聚焦的子弹单位
function BattleCameraFocusBullet.SetUnit(self, bullet)
	self._unit = bullet
end

--- @return Vector3 聚焦点的世界坐标
--- 获取聚焦子弹时的摄像机位置
--- 取子弹位置并加上 CameraFocusHeight 高度偏移，再根据透视修正 z 轴
function BattleCameraFocusBullet.GetCameraPos(self)
	local bulletPos = self._unit:GetPosition():Clone()

	-- 向上抬高，使摄像机能从上方俯瞰子弹
	bulletPos.y = bulletPos.y + BattleVariable.CameraFocusHeight
	-- 根据高度进行透视修正：z 轴后退
	bulletPos.z = bulletPos.z - bulletPos.y / BattleVariable._camera_radian_x_tan

	return bulletPos
end

--- @return nil
--- 清理函数
function BattleCameraFocusBullet.Dispose(self)
	self._unit = nil
end
