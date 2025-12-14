ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleAttr = ys.Battle.BattleAttr
local BattlePointAirStrikeUnit = class("BattlePointAirStrikeUnit", ys.Battle.BattlePointHitWeaponUnit)

ys.Battle.BattlePointAirStrikeUnit = BattlePointAirStrikeUnit
BattlePointAirStrikeUnit.__name = "BattlePointAirStrikeUnit"

function BattlePointAirStrikeUnit.Ctor(arg_1_0)
	BattlePointAirStrikeUnit.super.Ctor(arg_1_0)

	BattlePointAirStrikeUnit._strikePoint = nil
	BattlePointAirStrikeUnit._strikeMode = false
end

function BattlePointAirStrikeUnit.RemoveAllLock(arg_2_0)
	arg_2_0._lockList = {}
end

function BattlePointAirStrikeUnit.Charge(arg_3_0)
	arg_3_0._currentState = arg_3_0.STATE_PRECAST
	arg_3_0._lockList = {}

	local var_3_0 = {}
	local var_3_1 = ys.Event.New(BattleUnitEvent.POINT_HIT_CHARGE, var_3_0)

	arg_3_0:DispatchEvent(var_3_1)

	arg_3_0._strikeMode = true
end

function BattlePointAirStrikeUnit.CancelCharge(arg_4_0)
	if arg_4_0._currentState ~= arg_4_0.STATE_PRECAST then
		return
	end

	arg_4_0:RemoveAllLock()

	arg_4_0._currentState = arg_4_0.STATE_READY

	local var_4_0 = {}
	local var_4_1 = ys.Event.New(BattleUnitEvent.POINT_HIT_CANCEL, var_4_0)

	arg_4_0:DispatchEvent(var_4_1)

	arg_4_0._strikeMode = nil
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

function BattlePointAirStrikeUnit.DoAttack(arg_6_0, arg_6_1)
	ys.Battle.PlayBattleSFX(arg_6_0._tmpData.fire_sfx)

	local var_6_0 = ys.Event.New(BattleUnitEvent.CHARGE_WEAPON_FIRE, {
		weapon = arg_6_0
	})

	arg_6_0:DispatchEvent(var_6_0)
	arg_6_0._host:TriggerBuff(BattleConst.BuffEffectType.ON_POINT_STRIKE_STEADY, {})

	for iter_6_0, iter_6_1 in ipairs(arg_6_0._hiveList) do
		local var_6_1 = arg_6_0._strikePoint or arg_6_0._lockList[1]:GetPosition()

		iter_6_1:SetStrikePoint(var_6_1)
		iter_6_1:updateMovementInfo()
		iter_6_1:SingleFire()
	end

	arg_6_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_FIRE, {}))
	arg_6_0:TriggerBuffOnFire()

	arg_6_0._strikePoint = nil

	arg_6_0:RemoveAllLock()
end

function BattlePointAirStrikeUnit.SetReloadTime(arg_7_0, arg_7_1)
	arg_7_0._reloadMax = arg_7_1
end

function BattlePointAirStrikeUnit.AddCDTimer(arg_8_0, arg_8_1)
	arg_8_0._currentState = arg_8_0.STATE_OVER_HEAT
	arg_8_0._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	arg_8_0._reloadRequire = arg_8_1
end

function BattlePointAirStrikeUnit.TriggerBuffOnReady(arg_9_0)
	arg_9_0._host:TriggerBuff(BattleConst.BuffEffectType.ON_POINT_STRIKE_READY, {})
end

function BattlePointAirStrikeUnit.TriggerBuffOnFire(arg_10_0)
	arg_10_0._host:TriggerBuff(BattleConst.BuffEffectType.ON_POINT_STRIKE, {})
end

function BattlePointAirStrikeUnit.GetReloadFinishTimeStamp(arg_11_0)
	local var_11_0 = 0

	for iter_11_0, iter_11_1 in ipairs(arg_11_0._reloadBoostList) do
		var_11_0 = var_11_0 + iter_11_1
	end

	return arg_11_0._reloadRequire + arg_11_0._CDstartTime + arg_11_0._jammingTime + var_11_0
end

function BattlePointAirStrikeUnit.GetLockList(arg_12_0)
	return arg_12_0._lockList
end

function BattlePointAirStrikeUnit.GetFilteredList(arg_13_0)
	local var_13_0 = BattlePointAirStrikeUnit.super.GetFilteredList(arg_13_0)

	return (arg_13_0:filterEnemyUnitType(var_13_0))
end

function BattlePointAirStrikeUnit.filterEnemyUnitType(arg_14_0, arg_14_1)
	local var_14_0 = {}
	local var_14_1 = {}
	local var_14_2 = -9999

	for iter_14_0, iter_14_1 in ipairs(arg_14_1) do
		local var_14_3 = iter_14_1:GetTargetedPriority()

		if var_14_3 == nil then
			var_14_1[#var_14_1 + 1] = iter_14_1
		elseif var_14_2 < var_14_3 then
			var_14_2 = var_14_3
			var_14_0 = {}
			var_14_0[#var_14_0 + 1] = iter_14_1
		elseif var_14_2 == var_14_3 then
			var_14_0[#var_14_0 + 1] = iter_14_1
		end
	end

	for iter_14_2, iter_14_3 in ipairs(var_14_1) do
		var_14_0[#var_14_0 + 1] = iter_14_3
	end

	return var_14_0
end

function BattlePointAirStrikeUnit.handleCoolDown(arg_15_0)
	arg_15_0._currentState = arg_15_0.STATE_READY

	arg_15_0._playerChargeWeaponVo:Plus(arg_15_0)
	arg_15_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_READY, {}))
	arg_15_0:TriggerBuffOnReady()

	arg_15_0._CDstartTime = nil
	arg_15_0._reloadBoostList = {}
end

function BattlePointAirStrikeUnit.FlushReloadMax(arg_16_0, arg_16_1)
	if BattlePointAirStrikeUnit.super.FlushReloadMax(arg_16_0, arg_16_1) then
		return true
	end

	arg_16_0._playerChargeWeaponVo:RefreshReloadingBar()
end

function BattlePointAirStrikeUnit.FlushReloadRequire(arg_17_0)
	if BattlePointAirStrikeUnit.super.FlushReloadRequire(arg_17_0) then
		return true
	end

	arg_17_0._playerChargeWeaponVo:RefreshReloadingBar()
end

function BattlePointAirStrikeUnit.QuickCoolDown(arg_18_0)
	if arg_18_0._currentState == arg_18_0.STATE_OVER_HEAT then
		arg_18_0._currentState = arg_18_0.STATE_READY

		arg_18_0._playerChargeWeaponVo:InstantCoolDown(arg_18_0)
		arg_18_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, {}))

		arg_18_0._CDstartTime = nil
		arg_18_0._reloadBoostList = {}
	end
end

function BattlePointAirStrikeUnit.IsStrikeMode(arg_19_0)
	return arg_19_0._strikeMode
end
