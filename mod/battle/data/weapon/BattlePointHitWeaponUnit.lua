ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleAttr = ys.Battle.BattleAttr
local BattlePointHitWeaponUnit = class("BattlePointHitWeaponUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattlePointHitWeaponUnit = BattlePointHitWeaponUnit
BattlePointHitWeaponUnit.__name = "BattlePointHitWeaponUnit"

function BattlePointHitWeaponUnit.Ctor(arg_1_0)
	BattlePointHitWeaponUnit.super.Ctor(arg_1_0)

	BattlePointHitWeaponUnit._strikePoint = nil
	BattlePointHitWeaponUnit._strikeRequire = 1
	BattlePointHitWeaponUnit._strikeMode = false
end

function BattlePointHitWeaponUnit.DispatchBlink(arg_2_0, arg_2_1)
	local var_2_0 = {
		callbackFunc = arg_2_1,
		timeScale = ys.Battle.BattleConfig.FOCUS_MAP_RATE
	}
	local var_2_1 = ys.Event.New(BattleUnitEvent.CHARGE_WEAPON_FINISH, var_2_0)

	arg_2_0:DispatchEvent(var_2_1)
end

function BattlePointHitWeaponUnit.RemoveAllLock(arg_3_0)
	arg_3_0._lockList = {}
end

function BattlePointHitWeaponUnit.createMajorEmitter(arg_4_0, arg_4_1, arg_4_2)
	local function var_4_0(arg_5_0, arg_5_1, arg_5_2, arg_5_3)
		local var_5_0
		local var_5_1
		local var_5_2 = arg_4_0._emitBulletIDList[arg_4_2]

		if arg_4_0._strikePoint then
			var_5_1 = arg_4_0._strikePoint
			var_5_0 = arg_4_0:SpawnPointBullet(var_5_2, arg_4_0._strikePoint)
		else
			local var_5_3 = arg_4_0._lockList[1]

			var_5_0 = arg_4_0:Spawn(var_5_2, var_5_3, arg_4_0.INTERNAL)
			var_5_1 = var_5_3:GetBeenAimedPosition() or var_5_3:GetPosition()
		end

		var_5_0:SetOffsetPriority(arg_5_3)
		var_5_0:SetShiftInfo(arg_5_0, arg_5_1)
		var_5_0:SetRotateInfo(var_5_1, 0, 0)
		ys.Battle.BattleVariable.AddExempt(var_5_0:GetSpeedExemptKey(), var_5_0:GetIFF(), ys.Battle.BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER)
		arg_4_0:DispatchBulletEvent(var_5_0)
	end

	local function var_4_1()
		arg_4_0._strikePoint = nil

		arg_4_0:RemoveAllLock()
	end

	BattlePointHitWeaponUnit.super.createMajorEmitter(arg_4_0, arg_4_1, arg_4_2, BattlePointHitWeaponUnit.EMITTER_NORMAL, var_4_0, var_4_1)
end

function BattlePointHitWeaponUnit.SetPlayerChargeWeaponVO(arg_7_0, arg_7_1)
	arg_7_0._playerChargeWeaponVo = arg_7_1
end

function BattlePointHitWeaponUnit.Charge(arg_8_0)
	arg_8_0._currentState = arg_8_0.STATE_PRECAST
	arg_8_0._lockList = {}

	local var_8_0 = {}
	local var_8_1 = ys.Event.New(BattleUnitEvent.POINT_HIT_CHARGE, var_8_0)

	arg_8_0:DispatchEvent(var_8_1)

	arg_8_0._strikeMode = true
end

function BattlePointHitWeaponUnit.CancelCharge(arg_9_0)
	if arg_9_0._currentState ~= arg_9_0.STATE_PRECAST then
		return
	end

	arg_9_0:RemoveAllLock()

	arg_9_0._currentState = arg_9_0.STATE_READY

	local var_9_0 = {}
	local var_9_1 = ys.Event.New(BattleUnitEvent.POINT_HIT_CANCEL, var_9_0)

	arg_9_0:DispatchEvent(var_9_1)

	arg_9_0._strikeMode = nil
end
-- 被BattleFleetVO.QuickTagChrageWeapon调用
function BattlePointHitWeaponUnit.QuickTag(self)
	self._currentState = self.STATE_PRECAST
	self._lockList = {}

	self:updateMovementInfo()

	local target = self:Tracking()

	self._lockList[#self._lockList + 1] = target
end

function BattlePointHitWeaponUnit.CancelQuickTag(arg_11_0)
	arg_11_0._currentState = arg_11_0.STATE_READY
	arg_11_0._lockList = {}
end

function BattlePointHitWeaponUnit.Update(arg_12_0, arg_12_1)
	arg_12_0:UpdateReload()
end
-- TODO
function BattlePointHitWeaponUnit.Fire(self, targetPos)
	if self._currentState ~= self.STATE_PRECAST then
		return
	end

	self._strikePoint = targetPos

	self._host:CloakExpose(ys.Battle.BattleConfig.CLOAK_BOMBARD_BASE_EXPOSE)
	self._host:BombardExpose()

	self._strikeMode = false

	return BattlePointHitWeaponUnit.super.Fire(self)
end

function BattlePointHitWeaponUnit.DoAttack(arg_14_0, arg_14_1)
	ys.Battle.PlayBattleSFX(arg_14_0._tmpData.fire_sfx)

	local var_14_0 = ys.Event.New(BattleUnitEvent.CHARGE_WEAPON_FIRE, {
		weapon = arg_14_0
	})

	arg_14_0:DispatchEvent(var_14_0)
	arg_14_0:cacheBulletID()
	arg_14_0:TriggerBuffOnSteday()

	for iter_14_0, iter_14_1 in ipairs(arg_14_0._majorEmitterList) do
		iter_14_1:Ready()
	end

	for iter_14_2, iter_14_3 in ipairs(arg_14_0._majorEmitterList) do
		iter_14_3:Fire(arg_14_1, arg_14_0:GetDirection(), arg_14_0:GetAttackAngle())
		iter_14_3:SetTimeScale(false)
	end

	arg_14_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_FIRE, {}))
	arg_14_0:TriggerBuffOnFire()
	ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[BattleConst.ShakeType.FIRE])
end

function BattlePointHitWeaponUnit.TriggerBuffOnReady(arg_15_0)
	if arg_15_0._tmpData.type == BattleConst.EquipmentType.MANUAL_MISSILE then
		arg_15_0._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_MANUAL_MISSILE_READY, {})
	else
		arg_15_0._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_CHARGE_READY, {})
	end
end

function BattlePointHitWeaponUnit.Spawn(arg_16_0, arg_16_1, arg_16_2, arg_16_3)
	local var_16_0

	if arg_16_2 == nil then
		arg_16_0:updateMovementInfo()

		arg_16_2 = arg_16_0:TrackingRandom(arg_16_0:GetFilteredList())

		if arg_16_2 == nil then
			var_16_0 = Vector3.zero
		else
			var_16_0 = arg_16_2:GetBeenAimedPosition() or arg_16_2:GetPosition()
		end
	else
		var_16_0 = arg_16_2:GetBeenAimedPosition() or arg_16_2:GetPosition()
	end

	local var_16_1 = arg_16_0._dataProxy:CreateBulletUnit(arg_16_1, arg_16_0._host, arg_16_0, var_16_0)

	arg_16_0:setBulletSkin(var_16_1, arg_16_1)
	arg_16_0:TriggerBuffWhenSpawn(var_16_1)

	if arg_16_3 == arg_16_0.INTERNAL then
		local var_16_2 = arg_16_0._host:GetAttrByName("initialEnhancement")

		var_16_1:SetDamageEnhance(1 + var_16_2)
		arg_16_0:TriggerBuffWhenSpawn(var_16_1, BattleConst.BuffEffectType.ON_INTERNAL_BULLET_CREATE)
	end

	return var_16_1
end

function BattlePointHitWeaponUnit.SpawnPointBullet(arg_17_0, arg_17_1, arg_17_2)
	local var_17_0 = arg_17_0._dataProxy:CreateBulletUnit(arg_17_1, arg_17_0._host, arg_17_0, arg_17_2)

	arg_17_0:TriggerBuffWhenSpawn(var_17_0, BattleConst.BuffEffectType.ON_MANUAL_BULLET_CREATE)
	arg_17_0:setBulletSkin(var_17_0, arg_17_1)

	local var_17_1 = arg_17_0._host:GetAttrByName("initialEnhancement") + arg_17_0._host:GetAttrByName("manualEnhancement")

	var_17_0:SetDamageEnhance(ys.Battle.BattleConfig.ChargeWeaponConfig.Enhance + var_17_1)
	arg_17_0:TriggerBuffWhenSpawn(var_17_0)
	arg_17_0:TriggerBuffWhenSpawn(var_17_0, BattleConst.BuffEffectType.ON_INTERNAL_BULLET_CREATE)

	return var_17_0
end

function BattlePointHitWeaponUnit.TriggerBuffOnFire(arg_18_0)
	if arg_18_0._tmpData.type == BattleConst.EquipmentType.MANUAL_MISSILE then
		arg_18_0._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_MANUAL_MISSILE_FIRE, {})
	else
		arg_18_0._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_CHARGE_FIRE, {})
	end
end

function BattlePointHitWeaponUnit.InitialCD(arg_19_0)
	BattlePointHitWeaponUnit.super.InitialCD(arg_19_0)
	arg_19_0._playerChargeWeaponVo:InitialDeduct(arg_19_0)
	arg_19_0._playerChargeWeaponVo:Charge(arg_19_0)
end

function BattlePointHitWeaponUnit.EnterCoolDown(self)
	BattlePointHitWeaponUnit.super.EnterCoolDown(self)
	self._playerChargeWeaponVo:Charge(self)
end

function BattlePointHitWeaponUnit.OverHeat(arg_21_0)
	BattlePointHitWeaponUnit.super.OverHeat(arg_21_0)
	arg_21_0._playerChargeWeaponVo:Deduct(arg_21_0)
end

function BattlePointHitWeaponUnit.GetMinAngle(arg_22_0)
	return arg_22_0:GetAttackAngle()
end

function BattlePointHitWeaponUnit.GetLockList(arg_23_0)
	return arg_23_0._lockList
end

function BattlePointHitWeaponUnit.GetFilteredList(arg_24_0)
	local var_24_0 = BattlePointHitWeaponUnit.super.GetFilteredList(arg_24_0)

	return (arg_24_0:filterEnemyUnitType(var_24_0))
end

function BattlePointHitWeaponUnit.filterEnemyUnitType(arg_25_0, arg_25_1)
	local var_25_0 = {}
	local var_25_1 = {}
	local var_25_2 = -9999

	for iter_25_0, iter_25_1 in ipairs(arg_25_1) do
		local var_25_3 = iter_25_1:GetTargetedPriority()

		if var_25_3 == nil then
			var_25_1[#var_25_1 + 1] = iter_25_1
		elseif var_25_2 < var_25_3 then
			var_25_2 = var_25_3
			var_25_0 = {}
			var_25_0[#var_25_0 + 1] = iter_25_1
		elseif var_25_2 == var_25_3 then
			var_25_0[#var_25_0 + 1] = iter_25_1
		end
	end

	for iter_25_2, iter_25_3 in ipairs(var_25_1) do
		var_25_0[#var_25_0 + 1] = iter_25_3
	end

	return var_25_0
end

function BattlePointHitWeaponUnit.handleCoolDown(arg_26_0)
	arg_26_0._currentState = arg_26_0.STATE_READY

	arg_26_0._playerChargeWeaponVo:Plus(arg_26_0)
	arg_26_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_READY, {}))
	arg_26_0:TriggerBuffOnReady()

	arg_26_0._CDstartTime = nil
	arg_26_0._reloadBoostList = {}
end

function BattlePointHitWeaponUnit.FlushReloadMax(arg_27_0, arg_27_1)
	if BattlePointHitWeaponUnit.super.FlushReloadMax(arg_27_0, arg_27_1) then
		return true
	end

	arg_27_0._playerChargeWeaponVo:RefreshReloadingBar()
end

function BattlePointHitWeaponUnit.FlushReloadRequire(arg_28_0)
	if BattlePointHitWeaponUnit.super.FlushReloadRequire(arg_28_0) then
		return true
	end

	arg_28_0._playerChargeWeaponVo:RefreshReloadingBar()
end

function BattlePointHitWeaponUnit.QuickCoolDown(arg_29_0)
	if arg_29_0._currentState == arg_29_0.STATE_OVER_HEAT then
		arg_29_0._currentState = arg_29_0.STATE_READY

		arg_29_0._playerChargeWeaponVo:InstantCoolDown(arg_29_0)
		arg_29_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, {}))

		arg_29_0._CDstartTime = nil
		arg_29_0._reloadBoostList = {}
	end
end

function BattlePointHitWeaponUnit.ReloadBoost(arg_30_0, arg_30_1)
	local var_30_0 = 0

	for iter_30_0, iter_30_1 in ipairs(arg_30_0._reloadBoostList) do
		var_30_0 = var_30_0 + iter_30_1
	end

	local var_30_1 = var_30_0 + arg_30_1
	local var_30_2 = pg.TimeMgr.GetInstance():GetCombatTime() - arg_30_0._jammingTime - arg_30_0._CDstartTime
	local var_30_3

	if var_30_1 < 0 then
		var_30_3 = math.max(var_30_1, (arg_30_0._reloadRequire - var_30_2) * -1)
	else
		var_30_3 = math.min(var_30_1, var_30_2)
	end

	fixValue = var_30_3 - var_30_1 + arg_30_1

	table.insert(arg_30_0._reloadBoostList, fixValue)
end

function BattlePointHitWeaponUnit.AppendReloadBoost(arg_31_0, arg_31_1)
	if arg_31_0._currentState == arg_31_0.STATE_OVER_HEAT then
		arg_31_0._playerChargeWeaponVo:ReloadBoost(arg_31_0, arg_31_1)
	end
end

function BattlePointHitWeaponUnit.IsStrikeMode(arg_32_0)
	return arg_32_0._strikeMode
end
