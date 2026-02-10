ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleFormulas = ys.Battle.BattleFormulas
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleSpaceLaserWeaponUnit = class("BattleSpaceLaserWeaponUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleSpaceLaserWeaponUnit = BattleSpaceLaserWeaponUnit
BattleSpaceLaserWeaponUnit.__name = "BattleSpaceLaserWeaponUnit"

-- 对应SPACE_LASER类型武器
function BattleSpaceLaserWeaponUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	local emitter = self:CreateEmitter(emitterType, barrageID, index)

	self._majorEmitterList[#self._majorEmitterList + 1] = emitter

	return emitter
end

function BattleSpaceLaserWeaponUnit.CreateEmitter(self, emitterType, barrageID, index)
	emitterType = emitterType or BattleSpaceLaserWeaponUnit.EMITTER_NORMAL

	local originalPos
	local yAngle
	local targetPos
	local _index = 0

	local function spawnFuncWithNoAimTime(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		if self._currentState == self.STATE_DISABLE then
			return
		end

		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, target, BattleSpaceLaserWeaponUnit.INTERNAL)

		_index = _index + 1
		target = self._tmpData.aim_type == BattleConst.WeaponAimType.AIM and target or nil

		bullet:SetOffsetPriority(isOffsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)
		bullet:setTrackingTarget(target)
		bullet:SetYAngle(yAngle)
		-- 攻击的持续时间为attack_time
		bullet:SetLifeTime(bullet:GetTemplate().extra_param.attack_time)
		bullet:RegisterLifeEndCB(function()
			_index = _index - 1

			if _index > 0 then
				return
			end

			if self._currentState == self.STATE_DISABLE then
				return
			end

			for _, emitter in ipairs(self._majorEmitterList) do
				if emitter:GetState() ~= emitter.STATE_STOP then
					return
				end
			end

			self:EnterCoolDown()
		end)

		local _targetPos = targetPos or target and pg.Tool.FilterY(target:GetCLDZCenterPosition())

		bullet:SetRotateInfo(_targetPos, self:GetBaseAngle(), barrageAngle)
		self:DispatchBulletEvent(bullet, originalPos or _targetPos)

		return bullet
	end

	local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		if self._currentState == self.STATE_DISABLE then
			return
		end

		local bulletID = self._emitBulletIDList[index]
		local aim_time = BattleDataFunction.GetBulletTmpDataFromID(bulletID).extra_param.aim_time

		if not aim_time or not (aim_time > 0) then
			spawnFuncWithNoAimTime(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)

			return
		end

		local bullet = self:Spawn(bulletID, target, BattleSpaceLaserWeaponUnit.INTERNAL)

		_index = _index + 1
		target = self._tmpData.aim_type == BattleConst.WeaponAimType.AIM and target or nil

		bullet:setTrackingTarget(target)
		bullet:SetOffsetPriority(isOffsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)
		bullet:SetLifeTime(bullet:GetTemplate().extra_param.aim_time)
		bullet:SetAlert(true)
		-- 如果有aim_time, 先alert for aim_type秒, 然后通过LifeEndCB触发真正的发射
		bullet:RegisterLifeEndCB(function()
			_index = _index - 1
			originalPos = pg.Tool.FilterY(bullet:GetPosition() - Vector3(offsetX, 0, offsetZ))
			yAngle = bullet:GetYAngle()
			targetPos = bullet:GetRotateInfo()

			spawnFuncWithNoAimTime(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		end)

		local alert_fx = bullet:GetTemplate().alert_fx

		if alert_fx and #alert_fx > 0 then
			bullet:SetModleID(alert_fx)
		end

		local centerPos = target and pg.Tool.FilterY(target:GetCLDZCenterPosition())

		bullet:SetRotateInfo(centerPos, self:GetBaseAngle(), barrageAngle)
		self:DispatchBulletEvent(bullet, centerPos)

		return bullet
	end

	local function stopFunc()
		return
	end

	return (ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID))
end

function BattleSpaceLaserWeaponUnit.SingleFire(self, target, emitterType, extraStopFunc, useTmpDataBulletFlag)
	assert(false, "Not Support only fire for BattleSpaceLaserWeapon")
end
