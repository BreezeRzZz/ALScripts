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
			local targetList

			if self._antiSub then
				targetList = ys.Battle.BattleTargetChoise.LegalTarget(self._host)
				targetList = ys.Battle.BattleTargetChoise.TargetDiveState(nil, nil, targetList)
				targetList = ys.Battle.BattleTargetChoise.TargetDetectedUnit(nil, nil, targetList)
			else
				targetList = ys.Battle.BattleTargetChoise.TargetAircraftHarm(self._host)
			end

			if #targetList > 0 then
				self._currentState = self.STATE_PRECAST_FINISH
			end
		end
	end

	if self._currentState == self.STATE_PRECAST_FINISH then
		self:updateMovementInfo()
		self:Fire()
	end
end

function BattleHiveUnit.SetTemplateData(self, tmpData)
	BattleHiveUnit.super.SetTemplateData(self, tmpData)

	self._antiSub = table.contains(tmpData.search_condition, BattleConst.OXY_STATE.DIVE)
end

function BattleHiveUnit.Fire(self)
	self:DispatchGCD()

	self._currentState = self.STATE_ATTACK

	if self._tmpData.action_index == "" then
		self:DoAttack()
	else
		self:DispatchFireEvent(nil, self._tmpData.action_index)
	end

	self._host:CloakExpose(self._tmpData.expose)

	return true
end

function BattleHiveUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	-- HiveUnit的createMajorEmitter主要目的是创建舰载机，因此不需要使用正常武器的大多参数
	local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		local aircraft, direction = self:SpawnAircraft(barrageAngle)
		-- 创建后delay(默认1.5)秒内，不能攻击
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

-- 被BattleHiveUnit.SpawnAircraft调用
function BattleHiveUnit.TriggerBuffWhenSpawnAircraft(self, aircraft)
	local buffEffectType = BattleConst.BuffEffectType.ON_AIRCRAFT_CREATE
	local buffEffectArgs = {
		aircraft = aircraft,
		equipIndex = self._equipmentIndex
	}

	self._host:TriggerBuff(buffEffectType, buffEffectArgs)
end

function BattleHiveUnit.SetStrikePoint(self, strikePoint)
	self._strikePoint = strikePoint
end

function BattleHiveUnit.GetStrikePoint(self)
	return self._strikePoint
end

function BattleHiveUnit.GetATKAircraftList(self)
	self._debugRecordATKAircraft = self._debugRecordATKAircraft or {}

	return self._debugRecordATKAircraft
end

function BattleHiveUnit.GetDEFAircraftList(self)
	self._debugRecordDEFAircraft = self._debugRecordDEFAircraft or {}

	return self._debugRecordDEFAircraft
end

function BattleHiveUnit.GetDamageSUM(self)
	local damageSum = 0
	local defAircraftList = self:GetDEFAircraftList()

	for _, defAircraft in ipairs(defAircraftList) do
		local weaponList = defAircraft:GetWeapon()

		for _, weapon in ipairs(weaponList) do
			damageSum = damageSum + weapon:GetDamageSUM()
		end
	end

	return damageSum
end
