ys = ys or {}

local ys = ys
local AutoPilotMinionRelativeStay = class("AutoPilotMinionRelativeStay", ys.Battle.IPilot)

ys.Battle.AutoPilotMinionRelativeStay = AutoPilotMinionRelativeStay
AutoPilotMinionRelativeStay.__name = "AutoPilotMinionRelativeStay"

function AutoPilotMinionRelativeStay.Ctor(self, ...)
	AutoPilotMinionRelativeStay.super.Ctor(self, ...)
end

function AutoPilotMinionRelativeStay.SetParameter(self, paramList, toIndex)
	AutoPilotMinionRelativeStay.super.SetParameter(self, paramList, toIndex)

	self._distX = paramList.x
	self._distZ = paramList.z
	self._nextBuffID = paramList.buffID
end
-- 这种AIStep是给minion用的，目标点是相对于其master的位置的一个偏移量
function AutoPilotMinionRelativeStay.GetDirection(self, position)
	local master = self._pilot:GetTarget():GetMaster()
	-- 如果master死了，则给minion加一个buff然后不动(实现亡语效果)
	if not master:IsAlive() then
		if self._nextBuffID then
			local buff = ys.Battle.BattleBuffUnit.New(self._nextBuffID)

			self._pilot:GetTarget():AddBuff(buff)
		end

		return Vector3.zero
	end

	local masterPosition = master:GetPosition()
	local direction = Vector3(masterPosition.x + self._distX, position.y, masterPosition.z + self._distZ) - position

	if self:IsExpired() then
		self:Finish()
	end

	if direction.magnitude < 0.4 then
		return Vector3.zero
	else
		direction.y = 0

		return direction:SetNormalize()
	end
end
