ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleHiveUnit = class("BattleHiveUnit", ys.Battle.BattleWeaponUnit)
ys.Battle.BattleHiveUnit.__name = "BattleHiveUnit"

local BattleHiveUnit = ys.Battle.BattleHiveUnit

function BattleHiveUnit.Ctor(self)
	BattleHiveUnit.super.Ctor(self)
end

function BattleHiveUnit.Update(self)
	self:UpdateReload()
	self:updateMovementInfo()

	if self._currentState == self.STATE_READY then
		if self._host:GetUnitType() ~= BattleConst.UnitType.PLAYER_UNIT then
			if self._preCastInfo.time == nil then
				self._currentState = self.STATE_PRECAST_FINISH
			else
				self:PreCast()
			end
		else
			local var_2_0

			if self._antiSub then
				var_2_0 = ys.Battle.BattleTargetChoise.LegalTarget(self._host)
				var_2_0 = ys.Battle.BattleTargetChoise.TargetDiveState(nil, nil, var_2_0)
				var_2_0 = ys.Battle.BattleTargetChoise.TargetDetectedUnit(nil, nil, var_2_0)
			else
				var_2_0 = ys.Battle.BattleTargetChoise.TargetAircraftHarm(self._host)
			end

			if #var_2_0 > 0 then
				self._currentState = self.STATE_PRECAST_FINISH
			end
		end
	end

	if self._currentState == self.STATE_PRECAST_FINISH then
		self:updateMovementInfo()
		self:Fire()
	end
end

function BattleHiveUnit.SetTemplateData(arg_3_0, arg_3_1)
	BattleHiveUnit.super.SetTemplateData(arg_3_0, arg_3_1)

	arg_3_0._antiSub = table.contains(arg_3_1.search_condition, BattleConst.OXY_STATE.DIVE)
end

function BattleHiveUnit.Fire(arg_4_0)
	arg_4_0:DispatchGCD()

	arg_4_0._currentState = arg_4_0.STATE_ATTACK

	if arg_4_0._tmpData.action_index == "" then
		arg_4_0:DoAttack()
	else
		arg_4_0:DispatchFireEvent(nil, arg_4_0._tmpData.action_index)
	end

	arg_4_0._host:CloakExpose(arg_4_0._tmpData.expose)

	return true
end

function BattleHiveUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	-- HiveUnit的createMajorEmitter主要目的是创建舰载机，因此不需要使用正常武器的大多参数
	local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		local aircraft, direction = self:SpawnAircraft(barrageAngle)

		aircraft:AddCreateTimer(direction, 1.5)

		if self._debugRecordDEFAircraft then
			table.insert(self._debugRecordDEFAircraft, aircraft)
		end
	end

	BattleHiveUnit.super.createMajorEmitter(self, barrageID, index, nil, spawnFunc, nil)
end

function BattleHiveUnit.SingleFire(arg_7_0, arg_7_1, arg_7_2, arg_7_3)
	arg_7_0._tempEmitterList = {}

	local function var_7_0(arg_8_0, arg_8_1, arg_8_2, arg_8_3, arg_8_4)
		local var_8_0, var_8_1 = arg_7_0:SpawnAircraft(arg_8_2)

		ys.Battle.BattleVariable.AddExempt(var_8_0:GetSpeedExemptKey(), var_8_0:GetIFF(), BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER)
		var_8_0:AddCreateTimer(var_8_1, 1)

		if arg_7_0._debugRecordATKAircraft then
			table.insert(arg_7_0._debugRecordATKAircraft, var_8_0)
		end
	end

	local function var_7_1()
		for iter_9_0, iter_9_1 in ipairs(arg_7_0._tempEmitterList) do
			if iter_9_1:GetState() ~= iter_9_1.STATE_STOP then
				return
			end
		end

		for iter_9_2, iter_9_3 in ipairs(arg_7_0._tempEmitterList) do
			iter_9_3:Destroy()
		end

		arg_7_0._tempEmitterList = nil

		if arg_7_3 then
			arg_7_3()
		end
	end

	arg_7_2 = arg_7_2 or BattleHiveUnit.EMITTER_SHOTGUN

	for iter_7_0, iter_7_1 in ipairs(arg_7_0._tmpData.barrage_ID) do
		local var_7_2 = ys.Battle[arg_7_2].New(var_7_0, var_7_1, iter_7_1)

		arg_7_0._tempEmitterList[#arg_7_0._tempEmitterList + 1] = var_7_2
	end

	for iter_7_2, iter_7_3 in ipairs(arg_7_0._tempEmitterList) do
		iter_7_3:Ready()
		iter_7_3:Fire(arg_7_1, arg_7_0:GetDirection(), arg_7_0:GetAttackAngle())
		iter_7_3:SetTimeScale(false)
	end

	arg_7_0._host:CloakExpose(arg_7_0._tmpData.expose)
end

function BattleHiveUnit.SpawnAircraft(self, barrageAngle)
	local aircraft = self._dataProxy:CreateAircraft(self._host, self._tmpData.id, self:GetPotential(), self._skinID)

	if self:GetStandHost() then
		aircraft:SetAttr(self:GetStandHost())
	end

	local angle = self:GetBaseAngle() + barrageAngle
	local angleRad = math.deg2Rad * angle
	local direction = Vector3(math.cos(angleRad), 0, math.sin(angleRad))

	self:TriggerBuffWhenSpawnAircraft(aircraft)

	if self._strikePoint then
		aircraft:SetStrikePoint(self._strikePoint)
	end

	return aircraft, direction
end

function BattleHiveUnit.TriggerBuffWhenSpawnAircraft(arg_11_0, arg_11_1)
	local var_11_0 = BattleConst.BuffEffectType.ON_AIRCRAFT_CREATE
	local var_11_1 = {
		aircraft = arg_11_1,
		equipIndex = arg_11_0._equipmentIndex
	}

	arg_11_0._host:TriggerBuff(var_11_0, var_11_1)
end

function BattleHiveUnit.SetStrikePoint(arg_12_0, arg_12_1)
	arg_12_0._strikePoint = arg_12_1
end

function BattleHiveUnit.GetStrikePoint(arg_13_0)
	return arg_13_0._strikePoint
end

function BattleHiveUnit.GetATKAircraftList(arg_14_0)
	arg_14_0._debugRecordATKAircraft = arg_14_0._debugRecordATKAircraft or {}

	return arg_14_0._debugRecordATKAircraft
end

function BattleHiveUnit.GetDEFAircraftList(arg_15_0)
	arg_15_0._debugRecordDEFAircraft = arg_15_0._debugRecordDEFAircraft or {}

	return arg_15_0._debugRecordDEFAircraft
end

function BattleHiveUnit.GetDamageSUM(arg_16_0)
	local var_16_0 = 0
	local var_16_1 = arg_16_0:GetDEFAircraftList()

	for iter_16_0, iter_16_1 in ipairs(var_16_1) do
		local var_16_2 = iter_16_1:GetWeapon()

		for iter_16_2, iter_16_3 in ipairs(var_16_2) do
			var_16_0 = var_16_0 + iter_16_3:GetDamageSUM()
		end
	end

	return var_16_0
end
