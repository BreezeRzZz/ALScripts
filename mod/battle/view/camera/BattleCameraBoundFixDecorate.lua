ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleCameraBoundFixDecorate = class("BattleCameraBoundFixDecorate")
ys.Battle.BattleCameraBoundFixDecorate.__name = "BattleCameraBoundFixDecorate"

local BattleCameraBoundFixDecorate = ys.Battle.BattleCameraBoundFixDecorate

--- @class BattleCameraBoundFixDecorate
--- 摄像机边界修正装饰器
--- 负责根据地图边界限制摄像机位置，防止摄像机超出可视范围。
--- 考虑了屏幕宽高比导致的半宽偏移，以及透视投影带来的纵向偏移。

--- @return nil
--- 构造函数
function BattleCameraBoundFixDecorate.Ctor(self)
	return
end

--- @param upperBound number 地图上边界
--- @param lowerBound number 地图下边界
--- @param leftBound number 地图左边界
--- @param rightBound number 地图右边界
--- @return number, number, number, number 修正后的上、下、左、右边界
--- 设置地图边界数据并计算摄像机约束参数
function BattleCameraBoundFixDecorate.SetMapData(self, upperBound, lowerBound, leftBound, rightBound)
	-- 各边界留出固定余量，防止摄像机边缘切到地图边界
	self._cameraUpperBound = upperBound + 30
	self._cameraLowerBound = lowerBound - 5
	self._cameraLeftBound = leftBound - 3
	self._cameraRightBound = rightBound + 3
	-- 摄像机半宽 = 正交大小 * 屏幕宽高比
	self._cameraHalfWidth = BattleConfig.CAMERA_SIZE * pg.CameraFixMgr.GetInstance().targetRatio
	-- 计算实际限制点：左限制点 = 左边界 + 半宽，右限制点 = 右边界 - 半宽
	self._cameraLeftBoundPoint = self._cameraLeftBound + self._cameraHalfWidth
	self._cameraRightBoundPoint = self._cameraRightBound - self._cameraHalfWidth
	-- 投影常数，用于根据 y 坐标计算 z 方向上的透视偏移
	self._projectionConst = BattleConfig.CAMERA_SIZE / BattleVariable._camera_radian_x_sin

	return self._cameraUpperBound, self._cameraLowerBound, self._cameraLeftBound, self._cameraRightBound
end

--- @param cameraPos Vector3 原始摄像机位置
--- @return Vector3 修正后的摄像机位置
--- 获取修正边界后的摄像机位置
--- z 轴的修正需要额外考虑 y 坐标带来的透视投影偏移
function BattleCameraBoundFixDecorate.GetCameraPos(self, cameraPos)
	-- 根据 y 坐标计算 z 方向上的透视投影偏移量
	local projectionDelta = cameraPos.y / BattleVariable._camera_radian_x_tan + self._projectionConst

	-- 夹紧 z 轴到边界范围内
	if cameraPos.z < self._cameraLowerBound then
		cameraPos.z = self._cameraLowerBound
	elseif cameraPos.z > self._cameraUpperBound - projectionDelta then
		cameraPos.z = self._cameraUpperBound - projectionDelta
	end

	-- 夹紧 x 轴到左右限制点范围内
	if cameraPos.x < self._cameraLeftBoundPoint then
		cameraPos.x = self._cameraLeftBoundPoint
	elseif cameraPos.x > self._cameraRightBoundPoint then
		cameraPos.x = self._cameraRightBoundPoint
	end

	return cameraPos
end

--- @return nil
--- 清理函数，释放所有边界数据
function BattleCameraBoundFixDecorate.Dispose(self)
	self._cameraUpperBound = nil
	self._cameraLowerBound = nil
	self._cameraLeftBound = nil
	self._cameraRightBound = nil
	self._cameraHalfWidth = nil
	self._cameraLeftBoundPoint = nil
	self._cameraRightBoundPoint = nil
	self._projectionConst = nil
end
