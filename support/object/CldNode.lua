pg = pg or {}

local pg = pg
local CldNode = class("CldNode")

pg.CldNode = CldNode

function CldNode.Ctor(self, arg_1_1)
	self.cylinder = false
end

function CldNode.UpdateBox(self, min, max, position)
	self.min = min:Copy2(self.min)
	self.max = max:Copy2(self.max)

	if position then
		self.min:Add(position)
		self.max:Add(position)
	end

	return self
end

function CldNode.UpdateStaticBox(self, min, max)
	self.min = min
	self.max = max

	return self
end

function CldNode.UpdateCylinder(self, center, tickness, range)
	if range < 0 then
		range = -range
	end

	self.center = center:Copy2(self.center)
	self.range = range
	-- 这里的range是指半径
	local box = Vector3(range, tickness, range)

	self.min = center - box
	self.max = center + box
	self.cylinder = true

	return self
end
