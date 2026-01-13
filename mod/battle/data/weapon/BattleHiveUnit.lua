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

-- BattleAllInStrike这类技能武器最终调用此函数进行单次发射(不具有持续输出)
-- 此外还有特例是BattlePointAirStrikeUnit的DoAttack会调用此函数进行单次发射
function BattleHiveUnit.SingleFire(self, target, emitterType, extraStopFunc)
	self._tempEmitterList = {}

	local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		local aircraft, direction = self:SpawnAircraft(barrageAngle)

		ys.Battle.BattleVariable.AddExempt(aircraft:GetSpeedExemptKey(), aircraft:GetIFF(), BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER)
		aircraft:AddCreateTimer(direction, 1)

		if self._debugRecordATKAircraft then
			table.insert(self._debugRecordATKAircraft, aircraft)
		end
	end

	local function stopFunc()
		for _, emitter in ipairs(self._tempEmitterList) do
			if emitter:GetState() ~= emitter.STATE_STOP then
				return
			end
		end

		for _, emitter in ipairs(self._tempEmitterList) do
			emitter:Destroy()
		end

		self._tempEmitterList = nil

		if extraStopFunc then
			extraStopFunc()
		end
	end

	-- 默认是BattleShotgunEmitter
	emitterType = emitterType or BattleHiveUnit.EMITTER_SHOTGUN

	for _, barrageID in ipairs(self._tmpData.barrage_ID) do
		local emitter = ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID)

		self._tempEmitterList[#self._tempEmitterList + 1] = emitter
	end

	for _, emitter in ipairs(self._tempEmitterList) do
		emitter:Ready()
		emitter:Fire(target, self:GetDirection(), self:GetAttackAngle())
		emitter:SetTimeScale(false)
	end

	self._host:CloakExpose(self._tmpData.expose)
end

-- BattleHiveUnit.createMajorEmitter/SingleFire最终调用此函数生成舰载机
-- (实际是注册到BattleBulletEmitter中的spawnFunc)
-- 相当于，其他武器是用来生成子弹，这里对应的是生成舰载机
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
