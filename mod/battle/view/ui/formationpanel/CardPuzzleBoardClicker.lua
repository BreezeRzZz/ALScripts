ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local CardPuzzleBoardClicker = class("CardPuzzleBoardClicker")

ys.Battle.CardPuzzleBoardClicker = CardPuzzleBoardClicker
CardPuzzleBoardClicker.__name = "CardPuzzleBoardClicker"
-- 点击状态枚举
CardPuzzleBoardClicker.CLICK_STATE_CLICK = "CLICK_STATE_CLICK"
CardPuzzleBoardClicker.CLICK_STATE_DRAG = "CLICK_STATE_DRAG"
CardPuzzleBoardClicker.CLICK_STATE_RELEASE = "CLICK_STATE_RELEASE"
CardPuzzleBoardClicker.CLICK_STATE_NONE = "CLICK_STATE_NONE"

--- 卡牌拼图棋盘点击控制器
--- 管理棋盘上的点击/拖拽输入，通过 Unity StickController 组件监听摇杆输入
--- 将屏幕坐标转换为标准化偏移量后传递给 CardPuzzleInfo

function CardPuzzleBoardClicker.Ctor(self, go)
	self._go = go

	self:Init()
end

function CardPuzzleBoardClicker.Init(self)
	SetActive(self._go, true)

	-- 初始化位移和方向变量
	self._distX, self._distY = 0, 0
	self._dirX, self._dirY = 0, 0
	self._prePress = false
	self._isPress = false

	local cameraFixMgr = pg.CameraFixMgr.GetInstance()

	self._screenWidth, self._screenHeight = cameraFixMgr:GetCurrentWidth(), cameraFixMgr:GetCurrentHeight()

	-- 绑定 Unity 摇杆控制器回调
	self._go:GetComponent("StickController"):SetStickFunc(function(stickData, eventID)
		self:updateStick(stickData, eventID)
	end)
end

--- 设置关联的卡牌拼图组件
--- @param cardPuzzleInfo CardPuzzleInfo 卡牌拼图信息对象
function CardPuzzleBoardClicker.SetCardPuzzleComponent(self, cardPuzzleInfo)
	self._cardPuzzleInfo = cardPuzzleInfo
end

--- 摇杆更新回调，处理点击/拖拽/释放状态转换
--- @param stickData table 摇杆数据（含 x, y 坐标）
--- @param eventID number 事件ID，-1 表示释放
function CardPuzzleBoardClicker.updateStick(self, stickData, eventID)
	if not self._cardPuzzleInfo:GetClickEnable() then
		return
	end

	self._initX = false
	self._initY = false

	if eventID == -1 then
		-- 释放状态
		self._startX = nil
		self._startY = nil
		self._isPress = false
	else
		self._isPress = true

		local posX = stickData.x
		local posY = stickData.y

		if self._startX == nil then
			-- 首次按下，记录起始位置
			self._startX = posX
			self._startY = posY
			self._initX = true
			self._initY = true
		else
			local deltaX = posX - self._lastPosX

			-- 方向改变时重置起始位置
			if deltaX * self._dirX < 0 then
				self._startX = posX
				self._initX = true
			end

			if deltaX ~= 0 then
				self._dirX = deltaX
			end

			local deltaY = posY - self._lastPosY

			if deltaY * self._dirY < 0 then
				self._startY = posY
				self._initY = true
			end

			if deltaY ~= 0 then
				self._dirY = deltaY
			end
		end

		-- 计算标准化位移（0~1 范围）
		self._distX = (posX - self._startX) / self._screenWidth
		self._distY = (posY - self._startY) / self._screenHeight
	end

	self._lastPosX = stickData.x
	self._lastPosY = stickData.y

	-- 判断当前点击状态
	local clickState

	if not self._prePress and self._isPress then
		clickState = CardPuzzleBoardClicker.CLICK_STATE_CLICK
	elseif self._prePress and self._isPress then
		clickState = CardPuzzleBoardClicker.CLICK_STATE_DRAG
	elseif self._prePress and not self._isPress then
		clickState = CardPuzzleBoardClicker.CLICK_STATE_RELEASE
	else
		clickState = CardPuzzleBoardClicker.CLICK_STATE_NONE
	end

	self._cardPuzzleInfo:UpdateClickPos(self._lastPosX, self._lastPosY, clickState)

	self._prePress = self._isPress
end

--- 获取当前拖拽距离
--- @return number distX X方向偏移量（标准化）
--- @return number distY Y方向偏移量（标准化）
function CardPuzzleBoardClicker.GetDistance(self)
	return self._distX, self._distY
end

--- 是否首次按下
--- @return boolean initX X方向首次按下
--- @return boolean initY Y方向首次按下
function CardPuzzleBoardClicker.IsFirstPress(self)
	return self._initX, self._initY
end

--- 是否正在按下
function CardPuzzleBoardClicker.IsPress(self)
	return self._isPress
end

function CardPuzzleBoardClicker.Dispose(self)
	return
end
