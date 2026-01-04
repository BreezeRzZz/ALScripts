ys = ys or {}

local ys = ys
local AutoPilotHiveRelativeStay = class("AutoPilotHiveRelativeStay", ys.Battle.IPilot)

ys.Battle.AutoPilotHiveRelativeStay = AutoPilotHiveRelativeStay
AutoPilotHiveRelativeStay.__name = "AutoPilotHiveRelativeStay"

function AutoPilotHiveRelativeStay.Ctor(self, ...)
	AutoPilotHiveRelativeStay.super.Ctor(self, ...)
end

function AutoPilotHiveRelativeStay.SetParameter(self, paramList, toIndex)
	AutoPilotHiveRelativeStay.super.SetParameter(self, paramList, toIndex)

	self._distX = paramList.x
	self._distZ = paramList.z
end

function AutoPilotHiveRelativeStay.GetDirection(self, position)
	local hiveUnit = self._pilot:GetHiveUnit()

	if not hiveUnit:IsAlive() then
		self._pilot:OnHiveUnitDead()

		return Vector3.zero
	end
	-- 这类是基于hive（创建舰载机的单位）位置，朝向(hive位置加上偏移量)移动
	-- 吐槽：那这里的RelativeStay有点容易误导，想表达的是“相对Hive保持位置”的意思(minion那边也是类似的)
	local hivePosition = hiveUnit:GetPosition()
	local direction = Vector3(hivePosition.x + self._distX, position.y, hivePosition.z + self._distZ) - position

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
