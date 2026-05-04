ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleCameraFocusChar = class("BattleCameraFocusChar")
ys.Battle.BattleCameraFocusChar.__name = "BattleCameraFocusChar"

local BattleCameraFocusChar = ys.Battle.BattleCameraFocusChar

--- @class BattleCameraFocusChar
--- 摄像机角色聚焦
--- 用于将摄像机焦点锁定在某个角色单位上，计算跟随角色的摄像机位置。
--- 与 BattleCameraFocusBullet 的区别：增加了敌我判定，敌方角色向右偏移，我方向左偏移。

--- @return nil
--- 构造函数，初始化零向量缓存点
function BattleCameraFocusChar.Ctor(self)
	self._point = Vector3.zero
end

--- @param unit BattleUnit 要聚焦的角色单位
--- @return nil
--- 设置要聚焦的角色单位
function BattleCameraFocusChar.SetUnit(self, unit)
	self._unit = unit
end

--- @return Vector3 聚焦点的世界坐标
--- 获取聚焦角色时的摄像机位置
--- 根据单位位置计算摄像机聚焦点，考虑高度偏移、透视修正和敌我横向偏移
function BattleCameraFocusChar.GetCameraPos(self)
	local unitPos = self._unit:GetPosition()

	self._point:Set(unitPos.x, unitPos.y, unitPos.z)

	-- 向上抬高 CameraFocusHeight，使摄像机从合适高度俯瞰角色
	self._point.y = self._point.y + BattleVariable.CameraFocusHeight
	-- 根据高度进行透视修正：z 轴后退
	self._point.z = self._point.z - self._point.y / BattleVariable._camera_radian_x_tan

	-- 根据敌我阵营做横向偏移：敌方偏右，我方偏左
	if self._unit:GetIFF() == BattleConfig.FOE_CODE then
		self._point.x = self._point.x + 7
	else
		self._point.x = self._point.x - 7
	end

	return self._point
end

--- @return nil
--- 清理函数
function BattleCameraFocusChar.Dispose(self)
	self._unit = nil
end
