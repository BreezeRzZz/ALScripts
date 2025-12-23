local BattleDataProxy = ys.Battle.BattleDataProxy
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable

function BattleDataProxy.SetupCalculateDamage(self, calculateFunc)
	self._calculateDamage = calculateFunc or BattleFormulas.CreateContextCalculateDamage()
end

function BattleDataProxy.SetupDamageKamikazeAir(self, calculateFunc)
	self._calculateDamageKamikazeAir = calculateFunc or BattleFormulas.CalculateDamageFromAircraftToMainShip
end

function BattleDataProxy.SetupDamageKamikazeShip(self, calculateFunc)
	self._calculateDamageKamikazeShip = calculateFunc or BattleFormulas.CalculateDamageFromShipToMainShip
end

function BattleDataProxy.SetupDamageCrush(self, calculateFunc)
	self._calculateDamageCrush = calculateFunc or BattleFormulas.CalculateCrashDamage
end

function BattleDataProxy.ClearFormulas(self)
	self._calculateDamage = nil
	self._calculateDamageKamikazeAir = nil
	self._calculateDamageKamikazeShip = nil
	self._calculateDamageCrush = nil
end

-- TODO
function BattleDataProxy.HandleBulletHit(self, bullet, ship)
	if not ship then
		assert(false, "HandleBulletHit, but no vehicleData")

		return false
	elseif not bullet then
		assert(false, "HandleBulletHit, but no bulletData")

		return false
	end
	-- 灵体不处理
	if BattleAttr.IsSpirit(ship) then
		return false
	end
	-- 只判定未碰撞过的，仅一次
	if bullet:IsCollided(ship:GetUniqueID()) == true then
		return
	end

	bullet:Hit(ship:GetUniqueID(), ship:GetUnitType())

	local args = {
		_bullet = bullet,
		equipIndex = bullet:GetWeapon():GetEquipmentIndex(),
		bulletTag = bullet:GetExtraTag()
	}

	bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_COLLIDE, args)

	if ship:GetUnitType() == BattleConst.UnitType.PLAYER_UNIT and ship:GetIFF() == BattleConfig.FRIENDLY_CODE then
		ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[BattleConst.ShakeType.HIT])
	end

	return true
end
-- note: 常规伤害处理函数
-- 举例：在BattleDataProxy.updateLoop中被调用，在各子弹工厂的onBulletHitFunc中也有调用
function BattleDataProxy.HandleDamage(self, bullet, target, damageReduceDistance, meteoDamageRatio)
	-- isShowHPBar的本质是BattleEnemyUnit.IsShowHPBar, 需要IFF不为友方
	if target:GetIFF() == BattleConfig.FOE_CODE and target:IsShowHPBar() then
		self:DispatchEvent(ys.Event.New(BattleEvent.HIT_ENEMY, target))
	end

	local weapon = bullet:GetWeapon()
	local weaponHostAttr = bullet:GetWeaponHostAttr()
	local extraTag = bullet:GetExtraTag()
	local weaponTemplate = weapon:GetTemplateData()
	local args = {
		weaponType = weaponTemplate.attack_attribute,
		bulletType = bullet:GetType(),
		bulletTag = extraTag
	}

	target:TriggerBuff(BattleConst.BuffEffectType.ON_BULLET_HIT_BEFORE, args)
	-- 检查isInvincible属性
	if BattleAttr.IsInvincible(target) then
		return
	end

	local damage, extraInfo, damageFont = self._calculateDamage(bullet, target, damageReduceDistance, meteoDamageRatio)
	local isMiss = extraInfo.isMiss
	local isCri = extraInfo.isCri
	local damageAttr = extraInfo.damageAttr

	bullet:AppendDamageUnit(target:GetUniqueID())

	local weaponType = weaponTemplate.type
	local equipIndex = weapon:GetEquipmentIndex()
	local bulletHitArgs = {
		target = target,
		damage = damage,
		weaponType = weaponType,
		equipIndex = equipIndex,
		bulletTag = extraTag
	}
	local updateHPArgs = {
		isHeal = false,
		isMiss = isMiss,
		isCri = isCri,
		attr = damageAttr,
		font = damageFont,
		cldPos = bullet:GetPosition(),
		srcID = weaponHostAttr.hostUID or weaponHostAttr.battleUID
	}

	bullet:GetWeapon():WeaponStatistics(damage, isCri, isMiss)

	local dHP = target:UpdateHP(damage * -1, updateHPArgs)

	self:DamageStatistics(weaponHostAttr.id, target:GetAttrByName("id"), -dHP)

	if not isMiss and bullet:GetWeaponTempData().type ~= BattleConst.EquipmentType.ANTI_AIR then
		bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_HIT, bulletHitArgs)

		local host = bullet:GetHost()

		if host and host:IsAlive() and host:GetUnitType() ~= ys.Battle.BattleConst.UnitType.AIRFIGHTER_UNIT then
			if table.contains(BattleConst.AircraftUnitType, host:GetUnitType()) then
				host = host:GetMotherUnit()
			end

			local hostIFF = host:GetIFF()

			for _, unit in pairs(self._unitList) do
				if unit:GetIFF() == hostIFF and unit ~= host then
					unit:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_TEAMMATE_BULLET_HIT, bulletHitArgs)
				end
			end
		end
	end

	local targetUnitType = target:GetUnitType()
	local isAircraft = true

	if targetUnitType ~= BattleConst.UnitType.AIRCRAFT_UNIT and targetUnitType ~= BattleConst.UnitType.AIRFIGHTER_UNIT and targetUnitType ~= BattleConst.UnitType.FUNNEL_UNIT and targetUnitType ~= BattleConst.UnitType.UAV_UNIT then
		isAircraft = false
	end

	if target:IsAlive() then
		if not isAircraft then
			for _, attachBuff in ipairs(bullet:GetAttachBuff()) do
				if attachBuff.hit_ignore or not isMiss then
					BattleDataProxy.HandleBuffPlacer(attachBuff, bullet, target)
				end
			end
		end

		if not isMiss then
			target:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, args)
		end
	else
		bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_KILL, {
			unit = target,
			killer = bullet
		})
		-- 亡语
		self:obituary(target, isAircraft, bullet)
		self:KillCountStatistics(weaponHostAttr.id, target:GetAttrByName("id"))
	end

	return isMiss, isCri
end
-- TODO
function BattleDataProxy.HandleMeteoDamage(arg_8_0, arg_8_1, arg_8_2)
	local var_8_0 = BattleFormulas.GetMeteoDamageRatio(#arg_8_2)

	for iter_8_0, iter_8_1 in ipairs(arg_8_2) do
		arg_8_0:HandleDamage(arg_8_1, iter_8_1, nil, var_8_0[iter_8_0])
	end
end
-- TODO
-- DOT等使用，不需要子弹
function BattleDataProxy.HandleDirectDamage(self, target, damage, caster, damageReason, isReflect)
	local srcID

	if caster then
		srcID = caster:GetAttrByName("id")
	end

	local extraInfo = {
		isMiss = false,
		isCri = false,
		isHeal = false,
		damageReason = damageReason,
		srcID = srcID,
		isReflect = isReflect
	}
	local targetID = target:GetAttrByName("id")
	local targetDHP = target:UpdateHP(damage * -1, extraInfo)
	local isTargetAlive = target:IsAlive()

	self:DamageStatistics(srcID, targetID, -targetDHP)

	if not isTargetAlive and srcID then
		self:KillCountStatistics(srcID, targetID)
	end

	if not isTargetAlive then
		local targetUnitType = target:GetUnitType()
		local isAircraft = true

		if targetUnitType ~= BattleConst.UnitType.AIRCRAFT_UNIT and targetUnitType ~= BattleConst.UnitType.AIRFIGHTER_UNIT and targetUnitType ~= BattleConst.UnitType.FUNNEL_UNIT and targetUnitType ~= BattleConst.UnitType.UAV_UNIT then
			isAircraft = false
		end

		self:obituary(target, isAircraft, caster)
	end
end

function BattleDataProxy.obituary(arg_10_0, arg_10_1, arg_10_2, arg_10_3)
	for iter_10_0, iter_10_1 in pairs(arg_10_0._unitList) do
		if iter_10_1 ~= arg_10_1 then
			if iter_10_1:GetIFF() == arg_10_1:GetIFF() then
				if arg_10_2 then
					iter_10_1:TriggerBuff(BattleConst.BuffEffectType.ON_FRIENDLY_AIRCRAFT_DYING, {
						unit = arg_10_1,
						killer = arg_10_3
					})
				elseif not arg_10_1:GetWorldDeathMark() then
					iter_10_1:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_SHIP_DYING, {
						unit = arg_10_1,
						killer = arg_10_3
					})
				end
			elseif arg_10_2 then
				iter_10_1:TriggerBuff(BattleConst.BuffEffectType.ON_FOE_AIRCRAFT_DYING, {
					unit = arg_10_1,
					killer = arg_10_3
				})
			else
				iter_10_1:TriggerBuff(BattleConst.BuffEffectType.ON_FOE_DYING, {
					unit = arg_10_1,
					killer = arg_10_3
				})
			end
		end
	end
end

function BattleDataProxy.HandleAircraftMissDamage(arg_11_0, arg_11_1, arg_11_2)
	if arg_11_2 == nil then
		return
	end

	local var_11_0 = arg_11_2:GetCloakList()

	for iter_11_0, iter_11_1 in ipairs(var_11_0) do
		iter_11_1:CloakExpose(arg_11_0._airExpose)
	end

	local var_11_1 = arg_11_1:GetPosition()
	local var_11_2 = arg_11_2:NearestUnitByType(var_11_1, ShipType.CloakShipTypeList)

	if var_11_2 then
		var_11_2:CloakExpose(arg_11_0._airExposeEX)
	end

	local var_11_3 = arg_11_2:RandomMainVictim({
		"immuneDirectHit"
	})

	if var_11_3 then
		local var_11_4 = arg_11_0._calculateDamageKamikazeAir(arg_11_1, var_11_3)

		var_11_3:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
		arg_11_0:HandleDirectDamage(var_11_3, var_11_4, arg_11_1)
	end
end

function BattleDataProxy.HandleShipMissDamage(arg_12_0, arg_12_1, arg_12_2)
	if arg_12_2 == nil then
		return
	end

	local var_12_0 = arg_12_2:GetCloakList()

	for iter_12_0, iter_12_1 in ipairs(var_12_0) do
		iter_12_1:CloakExpose(arg_12_0._shipExpose)
	end

	local var_12_1 = arg_12_1:GetPosition()
	local var_12_2 = arg_12_2:NearestUnitByType(var_12_1, ShipType.CloakShipTypeList)

	if var_12_2 then
		var_12_2:CloakExpose(arg_12_0._shipExposeEX)
	end

	local var_12_3 = arg_12_2:RandomMainVictim({
		"immuneDirectHit"
	})

	if var_12_3 then
		local var_12_4 = arg_12_1:GetTemplate().type

		if table.contains(TeamType.SubShipType, var_12_4) then
			local var_12_5 = BattleFormulas.CalculateDamageFromSubmarinToMainShip(arg_12_1, var_12_3)

			var_12_3:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
			arg_12_0:HandleDirectDamage(var_12_3, var_12_5, arg_12_1)

			if var_12_3:IsAlive() and BattleFormulas.RollSubmarineDualDice(arg_12_1) then
				local var_12_6 = BattleFormulas.CalculateDamageFromSubmarinToMainShip(arg_12_1, var_12_3)

				var_12_3:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
				arg_12_0:HandleDirectDamage(var_12_3, var_12_6, arg_12_1)
			end
		else
			local var_12_7 = arg_12_0._calculateDamageKamikazeShip(arg_12_1, var_12_3)

			var_12_3:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
			arg_12_0:HandleDirectDamage(var_12_3, var_12_7, arg_12_1)
		end
	end
end

function BattleDataProxy.HandleCrashDamage(arg_13_0, arg_13_1, arg_13_2)
	local var_13_0, var_13_1 = arg_13_0._calculateDamageCrush(arg_13_1, arg_13_2)

	arg_13_0:HandleDirectDamage(arg_13_1, var_13_0, arg_13_2, BattleConst.UnitDeathReason.CRUSH)
	arg_13_0:HandleDirectDamage(arg_13_2, var_13_1, arg_13_1, BattleConst.UnitDeathReason.CRUSH)
end
-- TODO
function BattleDataProxy.HandleBuffPlacer(arg_14_0, arg_14_1, arg_14_2)
	local var_14_0 = BattleDataFunction.GetBuffTemplate(arg_14_0.buff_id).effect_list
	local var_14_1 = false

	if var_14_0[1].type == "BattleBuffDOT" then
		if BattleFormulas.CaclulateDOTPlace(arg_14_0.rant, var_14_0[1], arg_14_1, arg_14_2) then
			var_14_1 = true
		end
	elseif BattleFormulas.IsHappen(arg_14_0.rant or 10000) then
		var_14_1 = true
	end

	if var_14_1 then
		local var_14_2 = arg_14_0.buff_level or arg_14_0.level
		local var_14_3 = ys.Battle.BattleBuffUnit.New(arg_14_0.buff_id, var_14_2, arg_14_1)

		var_14_3:SetGroupLevel(arg_14_0.group_level)
		var_14_3:SetOrb(arg_14_1, arg_14_0.level)
		arg_14_2:AddBuff(var_14_3)
	end
end

function BattleDataProxy.HandleDOTPlace(arg_15_0, arg_15_1, arg_15_2)
	local var_15_0 = arg_15_0.arg_list
	local var_15_1 = BattleConfig.DOT_CONFIG[var_15_0.dotType]
	local var_15_2 = arg_15_1:GetAttrByName(var_15_1.hit)

	if BattleFormulas.IsHappen(var_15_0.ACC + arg_15_1:GetAttrByName(var_15_1.hit) - arg_15_2:GetAttrByName(var_15_1.resist)) then
		return true
	end

	return false
end
-- TODO
function BattleDataProxy.HandleShipCrashDamageList(arg_16_0, arg_16_1, arg_16_2)
	local var_16_0 = arg_16_1:GetHostileCldList()

	for iter_16_0, iter_16_1 in pairs(var_16_0) do
		if not table.contains(arg_16_2, iter_16_0) then
			arg_16_1:RemoveHostileCld(iter_16_0)
		end
	end

	for iter_16_2, iter_16_3 in ipairs(arg_16_2) do
		if var_16_0[iter_16_3] == nil then
			local var_16_1

			local function var_16_2()
				arg_16_0:HandleCrashDamage(arg_16_0._unitList[iter_16_3], arg_16_1)
			end

			local var_16_3 = pg.TimeMgr.GetInstance():AddBattleTimer("shipCld", nil, BattleConfig.SHIP_CLD_INTERVAL, var_16_2, true)

			arg_16_1:AppendHostileCld(iter_16_3, var_16_3)
			var_16_2()

			if not arg_16_1:IsAlive() then
				break
			end
		end
	end
end

function BattleDataProxy.HandleShipCrashDecelerate(arg_18_0, arg_18_1, arg_18_2)
	if arg_18_2 == 0 and arg_18_1:IsCrash() then
		arg_18_1:SetCrash(false)
	elseif arg_18_2 > 0 and not arg_18_1:IsCrash() then
		arg_18_1:SetCrash(true)
	end
end

function BattleDataProxy.HandleWallHitByBullet(arg_19_0, arg_19_1, arg_19_2)
	return (arg_19_1:GetCldFunc()(arg_19_2))
end

function BattleDataProxy.HandleWallHitByShip(arg_20_0, arg_20_1, arg_20_2)
	arg_20_1:GetCldFunc()(arg_20_2)
end

function BattleDataProxy.HandleWallDamage(arg_21_0, arg_21_1, arg_21_2)
	if arg_21_2:GetIFF() == BattleConfig.FOE_CODE and arg_21_2:IsShowHPBar() then
		arg_21_0:DispatchEvent(ys.Event.New(BattleEvent.HIT_ENEMY, arg_21_2))
	end

	local var_21_0 = BattleAttr.GetCurrent(arg_21_1, "id")

	if BattleAttr.IsInvincible(arg_21_2) then
		return
	end

	local var_21_1, var_21_2, var_21_3 = arg_21_0._calculateDamage(arg_21_1, arg_21_2)
	local var_21_4 = var_21_2.isMiss
	local var_21_5 = var_21_2.isCri
	local var_21_6 = var_21_2.damageAttr
	local var_21_7 = {
		isHeal = false,
		isMiss = var_21_4,
		isCri = var_21_5,
		attr = var_21_6,
		font = var_21_3,
		cldPos = arg_21_1:GetPosition(),
		srcID = var_21_0
	}
	local var_21_8 = arg_21_2:UpdateHP(var_21_1 * -1, var_21_7)

	arg_21_0:DamageStatistics(var_21_0, arg_21_2:GetAttrByName("id"), -var_21_8)

	if arg_21_2:IsAlive() then
		if not var_21_4 then
			arg_21_2:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
		end
	else
		arg_21_0:obituary(arg_21_2, false, arg_21_1)
		arg_21_0:KillCountStatistics(var_21_0, arg_21_2:GetAttrByName("id"))
	end

	return var_21_4, var_21_5
end
