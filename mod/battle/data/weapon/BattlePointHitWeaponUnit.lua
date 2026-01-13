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

function BattlePointHitWeaponUnit.createMajorEmitter(self, barrageID, index)
	local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority)
		local bullet
		local targetPos
		local bulletID = self._emitBulletIDList[index]

		-- 如果是手动模式，指定了一个点，就打这个点
		if self._strikePoint then
			targetPos = self._strikePoint
			bullet = self:SpawnPointBullet(bulletID, self._strikePoint)
		else
			-- 如果是自律模式，从锁定列表里选第一个目标
			-- 从上面来看，用的是BattleWeaponUnit.Tracking方法选出的目标
			-- 也就是没有特殊处理, 对于跨射武器来说一般就是扇形索敌
			-- (但由于后排位置原因，这个通用方法一般选不到任何敌人，除非是敌方船触底之类的情况)
			-- (因此一般实际是走的后面的TrackingRandom逻辑)
			local target = self._lockList[1]

			bullet = self:Spawn(bulletID, target, self.INTERNAL)
			targetPos = target:GetBeenAimedPosition() or target:GetPosition()
		end

		bullet:SetOffsetPriority(isOffsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)
		bullet:SetRotateInfo(targetPos, 0, 0)
		ys.Battle.BattleVariable.AddExempt(bullet:GetSpeedExemptKey(), bullet:GetIFF(), ys.Battle.BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER)
		self:DispatchBulletEvent(bullet)
	end

	local function stopFunc()
		self._strikePoint = nil

		self:RemoveAllLock()
	end

	BattlePointHitWeaponUnit.super.createMajorEmitter(self, barrageID, index, BattlePointHitWeaponUnit.EMITTER_NORMAL, spawnFunc, stopFunc)
end

function BattlePointHitWeaponUnit.SetPlayerChargeWeaponVO(self, playerChargeWeaponVo)
	self._playerChargeWeaponVo = playerChargeWeaponVo
end

function BattlePointHitWeaponUnit.Charge(self)
	self._currentState = self.STATE_PRECAST
	self._lockList = {}

	local chargeArgs = {}
	local chargeEvent = ys.Event.New(BattleUnitEvent.POINT_HIT_CHARGE, chargeArgs)

	self:DispatchEvent(chargeEvent)

	self._strikeMode = true
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
	-- 自律模式下，通过Tracking选择一个目标，加入到lockList里
	-- (后续emmiter的spawnFunc发射时会从lockList里选第一个目标进行攻击)
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

function BattlePointHitWeaponUnit.Fire(self, targetPos)
	if self._host:IsCease() then
		self:CancelQuickTag()

		return false
	end

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

-- 跨射武器的子弹生成主逻辑
function BattlePointHitWeaponUnit.Spawn(self, bulletID, target, bulletInType)
	local targetPos

	if target == nil then
		self:updateMovementInfo()
		-- 如果传入的target为空，则通过TrackingRandom从筛选后的列表里随机选一个目标
		target = self:TrackingRandom(self:GetFilteredList())

		if target == nil then
			-- 没有目标，目标点为0，在后续处理会处理为瞄准武器的最大索敌范围处
			targetPos = Vector3.zero
		else
			targetPos = target:GetBeenAimedPosition() or target:GetPosition()
		end
	else
		targetPos = target:GetBeenAimedPosition() or target:GetPosition()
	end

	local bullet = self._dataProxy:CreateBulletUnit(bulletID, self._host, self, targetPos)

	self:setBulletSkin(bullet, bulletID)
	self:TriggerBuffWhenSpawn(bullet)

	if bulletInType == self.INTERNAL then
		local initialEnhancement = self._host:GetAttrByName("initialEnhancement")

		bullet:SetDamageEnhance(1 + initialEnhancement)
		self:TriggerBuffWhenSpawn(bullet, BattleConst.BuffEffectType.ON_INTERNAL_BULLET_CREATE)
	end

	return bullet
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

function BattlePointHitWeaponUnit.GetFilteredList(self)
	local filteredList = BattlePointHitWeaponUnit.super.GetFilteredList(self)

	return (self:filterEnemyUnitType(filteredList))
end

function BattlePointHitWeaponUnit.filterEnemyUnitType(self, filteredList)
	local filteredPriorityList = {}
	local candidateList = {}
	local maxPriority = -9999

	for _, candidate in ipairs(filteredList) do
		-- 每个候选的被索敌优先级
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
	-- 总的来说，选出被索敌优先级最高的单位（以及加入了没有优先级的单位?）
	for _, candidate in ipairs(candidateList) do
		filteredPriorityList[#filteredPriorityList + 1] = candidate
	end

	return filteredPriorityList
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
