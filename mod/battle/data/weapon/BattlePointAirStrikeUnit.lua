ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleAttr = ys.Battle.BattleAttr
local BattlePointAirStrikeUnit = class("BattlePointAirStrikeUnit", ys.Battle.BattlePointHitWeaponUnit)

ys.Battle.BattlePointAirStrikeUnit = BattlePointAirStrikeUnit
BattlePointAirStrikeUnit.__name = "BattlePointAirStrikeUnit"

function BattlePointAirStrikeUnit.Ctor(self)
	BattlePointAirStrikeUnit.super.Ctor(self)

	BattlePointAirStrikeUnit._strikePoint = nil
	BattlePointAirStrikeUnit._strikeMode = false
end

function BattlePointAirStrikeUnit.RemoveAllLock(self)
	self._lockList = {}
end

function BattlePointAirStrikeUnit.Charge(self)
	self._currentState = self.STATE_PRECAST
	self._lockList = {}

	local pointHitChargeArgs = {}
	local pointHitChargeEvent = ys.Event.New(BattleUnitEvent.POINT_HIT_CHARGE, pointHitChargeArgs)

	self:DispatchEvent(pointHitChargeEvent)

	self._strikeMode = true
end

function BattlePointAirStrikeUnit.CancelCharge(self)
	if self._currentState ~= self.STATE_PRECAST then
		return
	end

	self:RemoveAllLock()

	self._currentState = self.STATE_READY

	local pointHitCancelArgs = {}
	local pointHitCancelEvent = ys.Event.New(BattleUnitEvent.POINT_HIT_CANCEL, pointHitCancelArgs)

	self:DispatchEvent(pointHitCancelEvent)

	self._strikeMode = nil
end

function BattlePointAirStrikeUnit.SetAirUnit(self, hiveIDList)
	self._hiveList = {}

	for _, hiveID in ipairs(hiveIDList) do
		local hiveUnit = ys.Battle.BattleDataFunction.CreateWeaponUnit(hiveID, self._host, nil, -1)
		local createWeaponEvent = ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_TEMPORARY_WEAPON, {
			weapon = hiveUnit
		})

		self._host:DispatchEvent(createWeaponEvent)
		table.insert(self._hiveList, hiveUnit)
	end
end

function BattlePointAirStrikeUnit.DoAttack(self, target)
	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)

	local chargeWeaponFireEvent = ys.Event.New(BattleUnitEvent.CHARGE_WEAPON_FIRE, {
		weapon = self
	})

	self:DispatchEvent(chargeWeaponFireEvent)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_POINT_STRIKE_STEADY, {})

	for _, hive in ipairs(self._hiveList) do
		local strikePoint = self._strikePoint or self._lockList[1]:GetPosition()

		hive:SetStrikePoint(strikePoint)
		hive:updateMovementInfo()
		hive:SingleFire()
	end

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_FIRE, {}))
	self:TriggerBuffOnFire()

	self._strikePoint = nil

	self:RemoveAllLock()
end

function BattlePointAirStrikeUnit.SetReloadTime(self, reloadMax)
	self._reloadMax = reloadMax
end

function BattlePointAirStrikeUnit.AddCDTimer(self, reloadRequire)
	self._currentState = self.STATE_OVER_HEAT
	self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._reloadRequire = reloadRequire
end

function BattlePointAirStrikeUnit.TriggerBuffOnReady(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_POINT_STRIKE_READY, {})
end

function BattlePointAirStrikeUnit.TriggerBuffOnFire(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_POINT_STRIKE, {})
end

function BattlePointAirStrikeUnit.GetReloadFinishTimeStamp(self)
	local totalBoost = 0

	for _, boost in ipairs(self._reloadBoostList) do
		totalBoost = totalBoost + boost
	end

	return self._reloadRequire + self._CDstartTime + self._jammingTime + totalBoost
end

function BattlePointAirStrikeUnit.GetLockList(self)
	return self._lockList
end

function BattlePointAirStrikeUnit.GetFilteredList(self)
	local filteredList = BattlePointAirStrikeUnit.super.GetFilteredList(self)

	return (self:filterEnemyUnitType(filteredList))
end

function BattlePointAirStrikeUnit.filterEnemyUnitType(self, filteredList)
	local filteredPriorityList = {}
	local candidateList = {}
	local maxPriority = -9999

	for _, candidate in ipairs(filteredList) do
		local targetedPriority = candidate:GetTargetedPriority()

		if targetedPriority == nil then
			candidateList[#candidateList + 1] = candidate
		elseif maxPriority < targetedPriority then
			maxPriority = targetedPriority
			filteredPriorityList = {}
			filteredPriorityList[#filteredPriorityList + 1] = candidate
		elseif maxPriority == targetedPriority then
			filteredPriorityList[#filteredPriorityList + 1] = candidate
		end
	end

	for _, candidate in ipairs(candidateList) do
		filteredPriorityList[#filteredPriorityList + 1] = candidate
	end

	return filteredPriorityList
end

function BattlePointAirStrikeUnit.handleCoolDown(self)
	self._currentState = self.STATE_READY

	self._playerChargeWeaponVo:Plus(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_READY, {}))
	self:TriggerBuffOnReady()

	self._CDstartTime = nil
	self._reloadBoostList = {}
end

function BattlePointAirStrikeUnit.FlushReloadMax(self, reloadFactor)
	if BattlePointAirStrikeUnit.super.FlushReloadMax(self, reloadFactor) then
		return true
	end

	self._playerChargeWeaponVo:RefreshReloadingBar()
end

function BattlePointAirStrikeUnit.FlushReloadRequire(self)
	if BattlePointAirStrikeUnit.super.FlushReloadRequire(self) then
		return true
	end

	self._playerChargeWeaponVo:RefreshReloadingBar()
end

function BattlePointAirStrikeUnit.QuickCoolDown(self)
	if self._currentState == self.STATE_OVER_HEAT then
		self._currentState = self.STATE_READY

		self._playerChargeWeaponVo:InstantCoolDown(self)
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, {}))

		self._CDstartTime = nil
		self._reloadBoostList = {}
	end
end

function BattlePointAirStrikeUnit.IsStrikeMode(self)
	return self._strikeMode
end
