ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleBuffAddForce = class("BattleBuffAddForce", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddForce = BattleBuffAddForce
BattleBuffAddForce.__name = "BattleBuffAddForce"

function BattleBuffAddForce.Ctor(self, effectData)
	BattleBuffAddForce.super.Ctor(self, effectData)
end

function BattleBuffAddForce.SetArgs(self, owner, buff)
	self._singularity = self._tempData.arg_list.singularity or {
		x = 0,
		z = 0
	}
	self._casterGravity = self._tempData.arg_list.gravitationalCaster
	self._force = self._tempData.arg_list.force
	self._forceScalteRate = self._tempData.arg_list.scale_rate

	if not self._casterGravity then
		self._staticSingularity = Vector3.New(self._singularity.x, 0, self._singularity.z)
	else
		local casterIFF = buff:GetCaster():GetIFF()

		self._singularityOffset = Vector3.New(self._singularity.x * casterIFF, 0, self._singularity.z)
	end
end

function BattleBuffAddForce.onUpdate(self, owner, buff)
	local singularity

	if self._casterGravity then
		singularity = buff:GetCaster():GetPosition() + self._singularityOffset
	else
		singularity = self._staticSingularity
	end

	local disVec = pg.Tool.FilterY(singularity - owner:GetPosition())
	local force = self._force
	local distance = disVec.magnitude
	-- 距离过近时，避免除零错误
	if distance < 2 then
		force = 1e-08
	-- 如果是按距离反比缩放力的情况
	elseif self._forceScalteRate then
		force = math.min(distance, 1 / distance * force)
	end

	owner:SetUncontrollableSpeed(disVec, force, 1e-18)

	self._lastSingularityPos = singularity
end

function BattleBuffAddForce.onAttach(self, owner, buff)
	return
end

function BattleBuffAddForce.onRemove(self, owner, buff)
	local disVec = pg.Tool.FilterY(self._lastSingularityPos - owner:GetPosition())

	owner:SetUncontrollableSpeed(disVec, 0.1, 0.1)
end
