ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleCameraFollowGesture = class("BattleCameraFollowGesture")
ys.Battle.BattleCameraFollowGesture.__name = "BattleCameraFollowGesture"

local BattleCameraFollowGesture = ys.Battle.BattleCameraFollowGesture

--- @class BattleCameraFollowGesture
--- 摄像机跟随手势
--- 通过触摸拖拽手势控制摄像机平移。支持首次按下时重置对应轴的基准点，
--- 通过 Slider 组件的拖拽距离计算摄像机的 xz 平面偏移量。

--- @return nil
--- 构造函数，初始化零向量缓存点
function BattleCameraFollowGesture.Ctor(self)
	self._point = Vector3.zero
end

--- @param slider BattleCameraSlider 摄像机滑动手势组件
--- @return nil
--- 设置手势滑动组件
function BattleCameraFollowGesture.SetGestureComponent(self, slider)
	self._slider = slider
end

--- @param defaultPos Vector3 默认摄像机位置（手势未按下时返回）
--- @return Vector3 经过手势偏移后的摄像机位置
--- 获取跟随手势的摄像机位置
--- 若 Slider 处于按下状态，根据拖拽距离计算 xz 平面的摄像机偏移；
--- 若未按下，直接返回默认位置
function BattleCameraFollowGesture.GetCameraPos(self, defaultPos)
	if self._slider:IsPress() then
		-- 首次按下时用默认位置初始化按下基准点
		self._pressPoint = self._pressPoint or defaultPos

		-- IsFirstPress 返回两个布尔值：第一个表示 x 轴方向是否首次按下，第二个表示 z 轴方向
		local firstPressX, firstPressZ = self._slider:IsFirstPress()
		local oldPressX = self._pressPoint.x
		local oldPressY = self._pressPoint.y

		-- 若 x 轴首次按下，重置按下基准点的 x 为当前默认位置
		if firstPressX then
			self._pressPoint.x = defaultPos.x
		end

		-- 若 z 轴首次按下，重置按下基准点的 z 为当前默认位置
		if firstPressZ then
			self._pressPoint.z = defaultPos.z
		end

		-- GetDistance 返回拖拽在 x 和 z 方向上的累计距离
		local deltaX, deltaZ = self._slider:GetDistance()

		-- 从基准点开始，叠加拖拽偏移（乘以 -80 系数）
		self._point:Set(self._pressPoint.x, self._pressPoint.y, self._pressPoint.z)

		self._point.z = self._point.z + deltaZ * -80
		self._point.x = self._point.x + deltaX * -80

		return self._point
	else
		return defaultPos
	end
end

--- @return nil
--- 清理函数
function BattleCameraFollowGesture.Dispose(self)
	self._slider = nil
end
