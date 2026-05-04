ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleFleetBound = class("BattleFleetBound")

ys.Battle.BattleFleetBound = BattleFleetBound
BattleFleetBound.__name = "BattleFleetBound"

--- @class BattleFleetBound
--- @param iff number 敌我识别码
--- 舰队边界组件：管理战场各类边界数值
function BattleFleetBound.Ctor(self, iff)
	self._iff = iff
end

function BattleFleetBound.Dispose(self)
	self._iff = nil
end

--- 获取所有边界值：上界、下界、绝对左界、绝对右界、缓冲左界、缓冲右界
function BattleFleetBound.GetBound(self)
	return self._upperBound, self._lowerBound, self._absoluteLeft, self._absoluteRight, self._bufferLeft, self._bufferRight
end

function BattleFleetBound.GetAbsoluteRight(self)
	return self._absoluteRight
end

--- 根据关卡配置区域数据初始化边界
function BattleFleetBound.ConfigAreaData(self, totalArea, playerArea)
	self._totalArea = setmetatable({}, {
		__index = totalArea
	})
	self._playerArea = setmetatable({}, {
		__index = playerArea
	})
	self._totalLeftBound = self._totalArea[1]
	self._totalRightBound = self._totalArea[1] + self._totalArea[3]
	self._totalUpperBound = self._totalArea[2] + self._totalArea[4]
	self._totalLowerBound = self._totalArea[2]
	self._upperBound = self._playerArea[2] + self._playerArea[4]
	self._lowerBound = self._playerArea[2]
	self._middleLine = self._playerArea[1] + self._playerArea[3]
end

--- 通用模式边界切换：友方占据左半场，敌方占据右半场
function BattleFleetBound.SwtichCommon(self)
	if self._iff == BattleConfig.FRIENDLY_CODE then
		self._absoluteLeft = self._playerArea[1]
		self._absoluteRight = BattleConfig.MaxRight
		self._bufferLeft = BattleConfig.MaxLeft
		self._bufferRight = self._middleLine
	elseif self._iff == BattleConfig.FOE_CODE then
		self._absoluteLeft = self._middleLine
		self._absoluteRight = self._totalRightBound
		self._bufferLeft = self._middleLine
		self._bufferRight = BattleConfig.MaxRight
	end
end

--- 决斗进攻模式边界切换：友方占据右半场，敌方在左半场
function BattleFleetBound.SwtichDuelAggressive(self)
	if self._iff == BattleConfig.FRIENDLY_CODE then
		self._absoluteLeft = self._middleLine
		self._absoluteRight = self._totalRightBound
		self._bufferLeft = self._middleLine
		self._bufferRight = BattleConfig.MaxRight
	elseif self._iff == BattleConfig.FOE_CODE then
		self._absoluteLeft = self._playerArea[1]
		self._absoluteRight = BattleConfig.MaxRight
		self._bufferLeft = BattleConfig.MaxLeft
		self._bufferRight = self._middleLine
	end
end

--- DBRGL模式边界切换：友方限制在中线内，允许跨全场
function BattleFleetBound.SwtichDBRGL(self)
	if self._iff == BattleConfig.FRIENDLY_CODE then
		self._absoluteLeft = self._playerArea[1]
		self._absoluteRight = self._middleLine
		self._bufferLeft = BattleConfig.MaxLeft
		self._bufferRight = BattleConfig.MaxRight
	elseif self._iff == BattleConfig.FOE_CODE then
		self._absoluteLeft = self._middleLine
		self._absoluteRight = self._totalRightBound
		self._bufferLeft = self._middleLine
		self._bufferRight = BattleConfig.MaxRight
	end
end

--- 卡牌谜题输入修正：将输入位置限制在合法边界内
function BattleFleetBound.FixCardPuzzleInput(self, position)
	local clampedX = math.clamp(position.x, self._absoluteLeft, self._absoluteRight)
	local clampedZ = math.clamp(position.z, self._lowerBound, self._upperBound)

	position:Set(clampedX, 0, clampedZ)
end
