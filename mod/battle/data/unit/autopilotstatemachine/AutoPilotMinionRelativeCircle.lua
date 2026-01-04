ys = ys or {}

local ys = ys
local up = Vector3.up
local AutoPilotMinionRelativeCircle = class("AutoPilotMinionRelativeCircle", ys.Battle.IPilot)

ys.Battle.AutoPilotMinionRelativeCircle = AutoPilotMinionRelativeCircle
AutoPilotMinionRelativeCircle.__name = "AutoPilotMinionRelativeCircle"

function AutoPilotMinionRelativeCircle.Ctor(self, ...)
	AutoPilotMinionRelativeCircle.super.Ctor(self, ...)
end

function AutoPilotMinionRelativeCircle.SetParameter(self, paramList, toIndex)
	AutoPilotMinionRelativeCircle.super.SetParameter(self, paramList, toIndex)

	self._radius = paramList.radius

	if paramList.antiClockWise == true then
		self.GetDirection = AutoPilotMinionRelativeCircle._antiClockWise
	else
		self.GetDirection = AutoPilotMinionRelativeCircle._clockWise
	end

	self._nextBuffID = paramList.buffID
end

function AutoPilotMinionRelativeCircle._clockWise(self, position)
	if self:IsExpired() then
		self:Finish()

		return Vector3.zero
	end

	local master = self._pilot:GetTarget():GetMaster()

	if not master:IsAlive() then
		if self._nextBuffID then
			local buff = ys.Battle.BattleBuffUnit.New(self._nextBuffID)
			self._pilot:GetTarget():AddBuff(buff)
		end

		return Vector3.zero
	end

	local masterPosition = master:GetPosition()

	if (position - masterPosition).magnitude > self._radius then
		return (masterPosition - position).normalized
	else
		local direction = (masterPosition - position).normalized
		local dx = -direction.z
		local dz = direction.x

		return Vector3(dx, 0, dz)
	end
end

function AutoPilotMinionRelativeCircle._antiClockWise(self, position)
	if self._duration > 0 and pg.TimeMgr.GetInstance():GetCombatTime() - self._startTime > self._duration then
		self:Finish()

		return Vector3.zero
	end

	local master = self._pilot:GetTarget():GetMaster()

	if not master:IsAlive() then
		if self._nextBuffID then
			local buff = ys.Battle.BattleBuffUnit.New(self._nextBuffID)
			self._pilot:GetTarget():AddBuff(buff)
		end

		return Vector3.zero
	end

	local masterPosition = master:GetPosition()

	if (position - masterPosition).magnitude > self._radius then
		return (masterPosition - position).normalized
	else
		local direction = (masterPosition - position).normalized
		local dx = direction.z
		local dz = -direction.x

		return Vector3(dx, 0, dz)
	end
end
