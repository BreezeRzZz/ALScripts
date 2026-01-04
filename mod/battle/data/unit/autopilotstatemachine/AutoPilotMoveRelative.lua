ys = ys or {}

local ys = ys
local AutoPilotMoveRelative = class("AutoPilotMoveRelative", ys.Battle.IPilot)

ys.Battle.AutoPilotMoveRelative = AutoPilotMoveRelative
AutoPilotMoveRelative.__name = "AutoPilotMoveRelative"

function AutoPilotMoveRelative.Ctor(self, ...)
	AutoPilotMoveRelative.super.Ctor(self, ...)
end

function AutoPilotMoveRelative.SetParameter(self, paramList, toIndex)
	AutoPilotMoveRelative.super.SetParameter(self, paramList, toIndex)

	self._distX = paramList.x
	self._distZ = paramList.z
end
-- MoveRelative类比Move多了一个根据单位朝向调整X偏移的步骤，其余逻辑与Move相同
function AutoPilotMoveRelative.Active(self, target)
	local distX = self._distX * target:GetDirection()

	self._targetPos = Vector3(distX, 0, self._distZ):Add(target:GetPosition())

	AutoPilotMoveRelative.super.Active(self, target)
end

function AutoPilotMoveRelative.GetDirection(self, position)
	local direction = self._targetPos - position

	direction.y = 0

	if direction.magnitude < self._valve then
		direction = Vector3.zero

		if self._duration == -1 or self:IsExpired() then
			self:Finish()
		end
	end

	return direction:SetNormalize()
end
