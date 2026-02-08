ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAOEMobilizedComponent = class("BattleAOEMobilizedComponent")

ys.Battle.BattleAOEMobilizedComponent = BattleAOEMobilizedComponent
BattleAOEMobilizedComponent.__name = "BattleAOEMobilizedComponent"
BattleAOEMobilizedComponent.STAY = 0
BattleAOEMobilizedComponent.FOLLOW = 1
BattleAOEMobilizedComponent.REFERENCE = 2

-- 该Component用于让AOE跟随某个单位移动或者以某个点为参考移动（根据UpdatePosition的实现）
function BattleAOEMobilizedComponent.Ctor(self, area)
	self._area = area
	-- area对应AOE Data
	self._area:AppendComponent(self)
	-- AOE的Settle函数会调用updatePosition来更新位置
	local Settle = self._area.Settle

	function self._area.Settle()
		self:updatePosition()
		Settle(self._area)
	end
end

function BattleAOEMobilizedComponent.Dispose(self)
	self._area = nil
	self._referenceUnit = nil
end

function BattleAOEMobilizedComponent.SetReferenceUnit(self, referenceUnit)
	self._referenceUnit = referenceUnit
	self._referencePoint = Clone(referenceUnit:GetPosition())
end

function BattleAOEMobilizedComponent.ConfigData(self, mode, params)
	if mode == BattleAOEMobilizedComponent.STAY then
		self.updatePosition = BattleAOEMobilizedComponent.doStay
	elseif mode == BattleAOEMobilizedComponent.FOLLOW then
		self.updatePosition = BattleAOEMobilizedComponent.doFollow
	elseif mode == BattleAOEMobilizedComponent.REFERENCE then
		self.updatePosition = BattleAOEMobilizedComponent.doReference
		self._speedVector = Vector3.New(params.speedX, 0, 0)
	end
end

-- 1. STAY: 不移动
function BattleAOEMobilizedComponent.doStay(self)
	return
end

-- 2. FOLLOW: 跟随referenceUnit移动
function BattleAOEMobilizedComponent.doFollow(self)
	local referencePos = setmetatable({}, {
		__index = self._referenceUnit:GetPosition()
	})

	self._area:SetPosition(referencePos)
end

-- 3. REFERENCE: 以某个点(referenceUnit的初始位置?)为参考移动
function BattleAOEMobilizedComponent.doReference(self)
	self._referencePoint:Add(self._speedVector)
	self._area:SetPosition(self._referencePoint)
end
