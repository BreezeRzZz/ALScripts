ys = ys or {}

local ys = ys
local AutoPilotMoveTo = class("AutoPilotMoveTo", ys.Battle.IPilot)

ys.Battle.AutoPilotMoveTo = AutoPilotMoveTo
AutoPilotMoveTo.__name = "AutoPilotMoveTo"

function AutoPilotMoveTo.Ctor(self, ...)
	AutoPilotMoveTo.super.Ctor(self, ...)
end

-- 设定目标点为指定的X和Z坐标
function AutoPilotMoveTo.SetParameter(self, paramList, toIndex)
	AutoPilotMoveTo.super.SetParameter(self, paramList, toIndex)

	self._targetPos = Vector3(paramList.x, 0, paramList.z)
end

-- 这类AIStep会返回指向目标点的方向向量，直到距离目标点小于valve则停止不动
function AutoPilotMoveTo.GetDirection(self, position)
	local direction = self._targetPos - position

	direction.y = 0
	-- valve相当于一个死区，距离目标点小于valve就不动
	if direction.magnitude < self._valve then
		direction = Vector3.zero

		if self._duration == -1 or self:IsExpired() then
			self:Finish()
		end
	end

	return direction.normalized
end
