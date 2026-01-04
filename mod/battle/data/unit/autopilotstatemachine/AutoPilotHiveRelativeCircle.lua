ys = ys or {}

local ys = ys
local up = Vector3.up
local AutoPilotHiveRelativeCircle = class("AutoPilotHiveRelativeCircle", ys.Battle.IPilot)

ys.Battle.AutoPilotHiveRelativeCircle = AutoPilotHiveRelativeCircle
AutoPilotHiveRelativeCircle.__name = "AutoPilotHiveRelativeCircle"

function AutoPilotHiveRelativeCircle.Ctor(self, ...)
	AutoPilotHiveRelativeCircle.super.Ctor(self, ...)
end

function AutoPilotHiveRelativeCircle.SetParameter(self, paramList, toIndex)
	AutoPilotHiveRelativeCircle.super.SetParameter(self, paramList, toIndex)

	self._radius = paramList.radius

	if paramList.antiClockWise == true then
		self.GetDirection = AutoPilotHiveRelativeCircle._antiClockWise
	else
		self.GetDirection = AutoPilotHiveRelativeCircle._clockWise
	end
end

function AutoPilotHiveRelativeCircle._clockWise(self, position)
	if self:IsExpired() then
		self:Finish()

		return Vector3.zero
	end

	local hiveUnit = self._pilot:GetHiveUnit()

	if not hiveUnit:IsAlive() then
		self._pilot:OnHiveUnitDead()

		return Vector3.zero
	end

	local hivePosition = hiveUnit:GetPosition()
	-- 就是基于hive位置做圆周运动，逻辑跟普通的Circle一样
	if (position - hivePosition).magnitude > self._radius then
		return (hivePosition - position).normalized
	else
		local direction = (hivePosition - position).normalized
		local dx = -direction.z
		local dz = direction.x

		return Vector3(dx, 0, dz)
	end
end

function AutoPilotHiveRelativeCircle._antiClockWise(self, position)
	if self._duration > 0 and pg.TimeMgr.GetInstance():GetCombatTime() - self._startTime > self._duration then
		self:Finish()

		return Vector3.zero
	end

	local hiveUnit = self._pilot:GetHiveUnit()

	if not hiveUnit:IsAlive() then
		self._pilot:OnHiveUnitDead()

		return Vector3.zero
	end

	local hivePosition = hiveUnit:GetPosition()

	if (position - hivePosition).magnitude > self._radius then
		return (hivePosition - position).normalized
	else
		local direction = (hivePosition - position).normalized
		local dx = direction.z
		local dz = -direction.x

		return Vector3(dx, 0, dz)
	end
end
