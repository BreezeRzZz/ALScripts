ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleCameraSlider = class("BattleCameraSlider")

local BattleCameraSlider = class("BattleCameraSlider")

ys.Battle.BattleCameraSlider = BattleCameraSlider
BattleCameraSlider.__name = "BattleCameraSlider"

--- 相机滑动手柄，用于触摸拖拽滑动视角
--- 依赖StickController组件处理触摸事件
--- @param go GameObject StickController所在的GameObject
function BattleCameraSlider.Ctor(self, go)
	self._go = go

	self:Init()
end

--- 初始化滑动手柄，绑定触摸回调
function BattleCameraSlider.Init(self)
	SetActive(self._go, true)

	self._distX, self._distY = 0, 0
	self._dirX, self._dirY = 0, 0
	self._isPress = false

	local cameraFixMgr = pg.CameraFixMgr.GetInstance()

	self._screenWidth, self._screenHeight = cameraFixMgr.actualWidth, cameraFixMgr.actualHeight

	-- 绑定StickController的回调
	self._go:GetComponent("StickController"):SetStickFunc(function(pos, state)
		self:updateStick(pos, state)
	end)
end

--- 更新滑块状态（由StickController回调触发）
--- @param pos Vector2 触摸位置
--- @param state number 触摸状态：-1表示释放，其他表示按下/移动
function BattleCameraSlider.updateStick(self, pos, state)
	self._initX = false
	self._initY = false

	if state == -1 then
		-- 手指抬起，重置起始位置
		self._startX = nil
		self._startY = nil
		self._isPress = false
	else
		self._isPress = true

		local curX = pos.x
		local curY = pos.y

		if self._startX == nil then
			-- 第一次按下，记录起始位置
			self._startX = curX
			self._startY = curY
			self._initX = true
			self._initY = true
		else
			-- 方向反转检测：如果移动方向与之前记录的方向相反，重置起始点
			local deltaX = curX - self._lastPosX

			if deltaX * self._dirX < 0 then
				self._startX = curX
				self._initX = true
			end

			if deltaX ~= 0 then
				self._dirX = deltaX
			end

			local deltaY = curY - self._lastPosY

			if deltaY * self._dirY < 0 then
				self._startY = curY
				self._initY = true
			end

			if deltaY ~= 0 then
				self._dirY = deltaY
			end
		end

		-- 计算相对屏幕的滑动距离（归一化到0~1范围）
		self._distX = (curX - self._startX) / self._screenWidth
		self._distY = (curY - self._startY) / self._screenHeight
	end

	self._lastPosX = pos.x
	self._lastPosY = pos.y
end

--- 获取当前滑动距离（归一化）
--- @return number distX, number distY
function BattleCameraSlider.GetDistance(self)
	return self._distX, self._distY
end

--- 检查是否首次按下（可用于触发首次滑动事件）
--- @return boolean initX, boolean initY
function BattleCameraSlider.IsFirstPress(self)
	return self._initX, self._initY
end

--- 检查当前是否按下
--- @return boolean
function BattleCameraSlider.IsPress(self)
	return self._isPress
end
