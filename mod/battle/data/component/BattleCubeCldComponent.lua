ys = ys or {}

local ys = ys
local BattleCubeCldComponent = class("BattleCubeCldComponent", ys.Battle.BattleCldComponent)

ys.Battle.BattleCubeCldComponent = BattleCubeCldComponent
BattleCubeCldComponent.__name = "BattleCubeCldComponent"

function BattleCubeCldComponent.Ctor(self, cldBoxX, cldBoxY, cldBoxZ, offsetX, offsetZ)
	ys.Battle.BattleCubeCldComponent.super.Ctor(self)
	-- offset决定的是碰撞盒中心点相对于单位中心点的偏移，一般都是0
	self._offsetX = offsetX
	self._offsetZ = offsetZ
	self._offset = Vector3(offsetX, 0, offsetZ)
	self._boxSize = Vector3.zero
	self._min = Vector3.zero
	self._max = Vector3.zero

	self:ResetSize(cldBoxX, cldBoxY, cldBoxZ)

	self._box = pg.CldNode.New()
end

function BattleCubeCldComponent.ResetOffset(self, offsetX, offsetZ)
	self._offsetX = offsetX
	self._offsetZ = offsetZ
	self._offset.x = offsetX
	self._offset.z = offsetZ
end

function BattleCubeCldComponent.ResetSize(self, cldBoxX, cldBoxY, cldBoxZ)
	local halfBoxX = cldBoxX * 0.5
	local halfBoxY = cldBoxY * 0.5
	local halfBoxZ = cldBoxZ * 0.5
	-- boxSize是按照Box一半算的
	self._boxSize.x = halfBoxX
	self._boxSize.y = halfBoxY
	self._boxSize.z = halfBoxZ
	self._min.x = self._offsetX - halfBoxX
	self._min.y = -halfBoxY
	self._min.z = self._offsetZ - halfBoxZ
	self._max.x = self._offsetX + halfBoxX
	self._max.y = halfBoxY
	self._max.z = self._offsetZ + halfBoxZ
end

function BattleCubeCldComponent.GetCldBox(self, position)
	if position then
		self._cldData.LeftBound = position.x - math.abs(self._min.x)
		self._cldData.RightBound = position.x + math.abs(self._max.x)
		self._cldData.LowerBound = position.z - math.abs(self._min.z)
		self._cldData.UpperBound = position.z + math.abs(self._max.z)
	end
	-- CldNode.UpdateBox
	return self._box:UpdateBox(self._min, self._max, position)
end

function BattleCubeCldComponent.GetCldBoxSize(self)
	return self._boxSize
end
