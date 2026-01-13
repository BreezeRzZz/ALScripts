ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAOEScaleableComponent = class("BattleAOEScaleableComponent")

ys.Battle.BattleAOEScaleableComponent = BattleAOEScaleableComponent
BattleAOEScaleableComponent.__name = "BattleAOEScaleableComponent"
BattleAOEScaleableComponent.FILL = 1
BattleAOEScaleableComponent.EXPEND = 2

function BattleAOEScaleableComponent.Ctor(self, aoe)
	self._area = aoe

	self._area:AppendComponent(self)

	local settleFunc = self._area.Settle
	-- 与普通AOE相比，每次更新的时候还会调整区域大小
	function self._area.Settle()
		self:updateScale()
		settleFunc(self._area)
	end
end

function BattleAOEScaleableComponent.Dispose(self)
	self._area = nil
	self._referenceUnit = nil
end

-- 保存参考单位当时的快照位置
function BattleAOEScaleableComponent.SetReferenceUnit(self, unit)
	self._referenceUnit = unit
	self._referencePoint = Clone(unit:GetPosition())
end

function BattleAOEScaleableComponent.ConfigData(self, scaleType, configData)
	if scaleType == BattleAOEScaleableComponent.FILL then
		self.updateScale = BattleAOEScaleableComponent.doFill
		self._upperBound = configData.upperBound
		self._lowerBound = configData.lowerBound
		self._rearBound = configData.rearBound
		self._frontOffset = configData.frontOffset
	elseif scaleType == BattleAOEScaleableComponent.EXPEND then
		self._area:SetFXStatic(false)

		self.updateScale = BattleAOEScaleableComponent.doExpend
		self._expendDuration = configData.expendDuration
		self._widthExpendSpeed = configData.widthSpeed
		self._heightExpendSpeed = configData.heightSpeed
		self._expendStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
		self._lastExpendTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end
end

-- 这类ScaleableComponent会根据参考单位位置调整区域大小和位置
-- 相当于跟随参考单位移动，并且根据参考单位位置调整区域大小
function BattleAOEScaleableComponent.doFill(self)
	local centerPos = setmetatable({}, {
		__index = self._referenceUnit:GetPosition()
	})
	local areaIFF = self._area:GetIFF()
	local height = math.abs(self._upperBound - self._lowerBound)
	local width = self._frontOffset * 2

	self._area:SetWidth(width)
	self._area:SetHeight(height)
	self._area:GetCldComponent():ResetSize(width, 5, height)

	local newZ = height * 0.5 + self._lowerBound
	local newX = centerPos.x

	self._referencePoint.x = newX
	self._referencePoint.z = newZ

	self._area:SetPosition(self._referencePoint)
end

function BattleAOEScaleableComponent.doExpend(self)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()
	-- 在expendDuration时间内，持续调整区域大小
	if currentTime - self._expendStartTime < self._expendDuration then
		local areaWidth = self._area:GetWidth()
		local areaHeight = self._area:GetHeight()
		local deltaTime = currentTime - self._lastExpendTime
		-- speed实际是每秒变化量，所以要乘以deltaTime(每帧的秒数)
		local newWidth = areaWidth + self._widthExpendSpeed * deltaTime
		local newHeight = areaHeight + self._heightExpendSpeed * deltaTime

		self._area:SetWidth(newWidth)
		self._area:SetHeight(newHeight)
		self._area:GetCldComponent():ResetSize(areaWidth, 5, areaHeight)
	end
end
