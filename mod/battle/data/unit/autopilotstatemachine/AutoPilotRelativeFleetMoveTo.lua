ys = ys or {}

local ys = ys
local AutoPilotRelativeFleetMoveTo = class("AutoPilotRelativeFleetMoveTo", ys.Battle.IPilot)

ys.Battle.AutoPilotRelativeFleetMoveTo = AutoPilotRelativeFleetMoveTo
AutoPilotRelativeFleetMoveTo.__name = "AutoPilotRelativeFleetMoveTo"

function AutoPilotRelativeFleetMoveTo.Ctor(self, ...)
	AutoPilotRelativeFleetMoveTo.super.Ctor(self, ...)
end

function AutoPilotRelativeFleetMoveTo.SetParameter(self, paramList, toIndex)
	AutoPilotRelativeFleetMoveTo.super.SetParameter(self, paramList, toIndex)

	self._offsetX = paramList.offsetX
	self._offsetZ = paramList.offsetZ
	self._fixX = paramList.X
	self._fixZ = paramList.Z
	self._targetFleetVO = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
end

function AutoPilotRelativeFleetMoveTo.GetDirection(self, position)
	if self:IsExpired() then
		self:Finish()

		return Vector3.zero
	end

	local refenceX
	local refenceZ
	-- 这里提到了舰队的位置，这是个抽象概念，只从游戏逻辑上存在，并没有实体化在地图上
	-- 参考BattleFleetVO.UpdateMotion
	-- 简单看了下逻辑，基本来讲是按照前排领舰的位置更新（就是前排领舰的位置）
	local fleetPos = self._targetFleetVO:GetMotion():GetPos()
	-- offset: 相对偏移量，fix: 绝对坐标
	if self._offsetX then
		refenceX = fleetPos.x + self._offsetX
	elseif self._fixX then
		refenceX = self._fixX
	else
		refenceX = position.x
	end

	if self._offsetZ then
		refenceZ = fleetPos.z + self._offsetZ
	elseif self._fixZ then
		refenceZ = self._fixZ
	else
		refenceZ = position.z
	end

	local direction = Vector3.New(refenceX, 0, refenceZ) - position

	direction.y = 0

	if direction.magnitude < self._valve then
		direction = Vector3.zero
	end

	return direction.normalized
end
