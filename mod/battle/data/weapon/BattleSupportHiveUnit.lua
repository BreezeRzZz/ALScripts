ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleSupportHiveUnit = class("BattleSupportHiveUnit", ys.Battle.BattleWeaponUnit)
ys.Battle.BattleSupportHiveUnit.__name = "BattleSupportHiveUnit"

local BattleSupportHiveUnit = ys.Battle.BattleSupportHiveUnit

function BattleSupportHiveUnit.Ctor(self)
	BattleSupportHiveUnit.super.Ctor(self)
end

function BattleSupportHiveUnit.Update(self)
	self:UpdateReload()
	self:updateMovementInfo()

	if self._currentState == self.STATE_READY then
		-- 显然不会是PLAYER_UNIT，而是SUPPORT_UNIT
		if self._host:GetUnitType() ~= BattleConst.UnitType.PLAYER_UNIT then
			if self._preCastInfo.time == nil then
				self._currentState = self.STATE_PRECAST_FINISH
			else
				self:PreCast()
			end
		-- 有目标就准备开火
		elseif #ys.Battle.BattleTargetChoise.TargetAircraftGB(self._host) > 0 then
			self._currentState = self.STATE_PRECAST_FINISH
		end
	end

	if self._currentState == self.STATE_PRECAST_FINISH then
		self:updateMovementInfo()
		self:Fire()
	end
end

function BattleSupportHiveUnit.Fire(self)
	-- 一般是0.5s，但大多数应该用不到
	self:DispatchGCD()

	self._currentState = self.STATE_ATTACK

	self:DoAttack()

	return true
end

function BattleSupportHiveUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	local function defaultSpawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		local aircraft, direction = self:SpawnAircraft(barrageAngle)
		-- 创建后1.5s才能攻击
		aircraft:AddCreateTimer(direction, 1.5)

		if self._debugRecordDEFAircraft then
			table.insert(self._debugRecordDEFAircraft, aircraft)
		end
	end

	BattleSupportHiveUnit.super.createMajorEmitter(self, barrageID, index, nil, defaultSpawnFunc, nil)
end

function BattleSupportHiveUnit.SpawnAircraft(self, barrageAngle)
	local aircraft = self._dataProxy:CreateAircraft(self._host, self._tmpData.id, self:GetPotential(), self._skinID)
	local angle = self:GetBaseAngle() + barrageAngle
	local angleRad = math.deg2Rad * angle
	local direction = Vector3(math.cos(angleRad), 0, math.sin(angleRad))

	return aircraft, direction
end

function BattleSupportHiveUnit.GetATKAircraftList(self)
	self._debugRecordATKAircraft = self._debugRecordATKAircraft or {}

	return self._debugRecordATKAircraft
end

function BattleSupportHiveUnit.GetDEFAircraftList(self)
	self._debugRecordDEFAircraft = self._debugRecordDEFAircraft or {}

	return self._debugRecordDEFAircraft
end

function BattleSupportHiveUnit.GetDamageSUM(self)
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
