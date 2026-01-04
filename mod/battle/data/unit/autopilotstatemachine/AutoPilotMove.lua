ys = ys or {}

local ys = ys
local AutoPilotMove = class("AutoPilotMove", ys.Battle.IPilot)

ys.Battle.AutoPilotMove = AutoPilotMove
AutoPilotMove.__name = "AutoPilotMove"

function AutoPilotMove.Ctor(self, ...)
	AutoPilotMove.super.Ctor(self, ...)
end

function AutoPilotMove.SetParameter(self, paramList, toIndex)
	AutoPilotMove.super.SetParameter(self, paramList, toIndex)

	self._distX = paramList.x
	self._distZ = paramList.z
end

-- 与MoveTo不同，这个Step的目标点是相对于单位当前位置的一个偏移量
-- 例如，X=10,Z=0，对于Move来说，是相当于当前位置向右移动10个单位，而对于MoveTo，是移动到坐标点(10,0)
function AutoPilotMove.Active(self, target)
	self._targetPos = Vector3(self._distX, 0, self._distZ):Add(target:GetPosition())

	AutoPilotMove.super.Active(self, target)
end

function AutoPilotMove.GetDirection(self, position)
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
