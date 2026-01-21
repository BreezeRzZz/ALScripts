ys = ys or {}

local ys = ys

ys.Battle.BattleJoyStickBotBaseStrategy = class("BattleJoyStickBotBaseStrategy")

local BattleJoyStickBotBaseStrategy = ys.Battle.BattleJoyStickBotBaseStrategy

BattleJoyStickBotBaseStrategy.__name = "BattleJoyStickBotBaseStrategy"

function BattleJoyStickBotBaseStrategy.Ctor(self, fleetVO)
	self._hrz = 0
	self._vtc = 0
	self._fleetVO = fleetVO
	self._motionVO = fleetVO:GetMotion()
end

function BattleJoyStickBotBaseStrategy.GetStrategyType(self)
	return nil
end

function BattleJoyStickBotBaseStrategy.SetBoardBound(self, upperBound, lowerBound, leftBound, rightBound)
	self._upperBound = upperBound
	self._lowerBound = lowerBound
	self._leftBound = leftBound
	self._rightBound = rightBound
	self._totalWidth = rightBound - leftBound
	self._totalHeight = upperBound - lowerBound
end

function BattleJoyStickBotBaseStrategy.Input(self, foeShipList, foeAircraftList)
	self._foeShipList = foeShipList
	self._foeAircraftList = foeAircraftList
end

function BattleJoyStickBotBaseStrategy.Output(self)
	self:analysis()

	return self._hrz, self._vtc
end

function BattleJoyStickBotBaseStrategy.Dispose(self)
	self._foeShipList = nil
	self._foeAircraftList = nil
	self._motionVO = nil
end

function BattleJoyStickBotBaseStrategy.analysis(self)
	return
end

function BattleJoyStickBotBaseStrategy.getDirection(pos, target)
	local direction = (target - pos).normalized

	return direction.x, direction.z
end
