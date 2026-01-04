ys = ys or {}

local ys = ys
local AutoPilotStay = class("AutoPilotStay", ys.Battle.IPilot)

ys.Battle.AutoPilotStay = AutoPilotStay
AutoPilotStay.__name = "AutoPilotStay"

function AutoPilotStay.Ctor(self, ...)
	AutoPilotStay.super.Ctor(self, ...)
end

-- Stay类的AIStep，永远返回零向量，表示不动，直到这个Step结束
function AutoPilotStay.GetDirection(self)
	if self:IsExpired() then
		self:Finish()
	end

	return Vector3.zero
end
