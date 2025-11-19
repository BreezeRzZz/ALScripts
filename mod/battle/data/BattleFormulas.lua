ys.Battle.BattleFormulas = ys.Battle.BattleFormulas or {}

-- var_0_0 -> BattleFormulas
-- var_0_1 -> BattleConst
-- var_0_2 -> gameset
-- var_0_3 -> BattleAttr
-- var_0_4 -> BattleConfig
-- var_0_5 -> AnitAirRepeaterConfig
-- var_0_6 -> bfConsts(*参考BattleState.lua)
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local gameset = pg.gameset
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local AnitAirRepeaterConfig = ys.Battle.BattleConfig.AnitAirRepeaterConfig
local bfConsts = pg.bfConsts
	-- bfConst.SECONDS = 60
	-- BattleConfig.viewFPS = 30(*随设置改变)
	-- BattleConfig.calcFPS = 30(*固定)
	-- BattleConfig.BulletSpeedConvertConst = 0.1
	-- BattleConfig.ShipSpeedConvertConst = 0.01
	-- BattleConfig.AircraftSpeedConvertConst = 0.01
-- var_0_7 -> bulletSpeedConvertRatio(=0.2)
-- var_0_8 -> shipSpeedConverRatio(=0.02)
-- var_0_9 -> aircraftSpeedConvertRatio(=0.02)
local bulletSpeedConvertRatio = bfConsts.SECONDs / BattleConfig.viewFPS * BattleConfig.BulletSpeedConvertConst
local shipSpeedConvertRatio = bfConsts.SECONDs / BattleConfig.calcFPS * BattleConfig.ShipSpeedConvertConst
local aircraftSpeedConvertRatio = bfConsts.SECONDs / BattleConfig.viewFPS * BattleConfig.AircraftSpeedConvertConst
	-- BattleConfig.AIR_ASSIST_RELOAD_RATIO = 220
	-- bfConst.PERCENT = 0.01
-- var_0_10 -> airAssistReloadFactor
-- var_0_11 -> damageEnhanceFromShipType
-- var_0_12 -> ammoDamageEnhance
-- var_0_13 -> ammoDamageReduce
-- var_0_14 -> shipTypeAccuracyEnhance
local airAssistReloadFactor = BattleConfig.AIR_ASSIST_RELOAD_RATIO * bfConsts.PERCENT
local damageEnhanceFromShipType = BattleConfig.DAMAGE_ENHANCE_FROM_SHIP_TYPE
local ammoDamageEnhance = BattleConfig.AMMO_DAMAGE_ENHANCE
local ammoDamageReduce = BattleConfig.AMMO_DAMAGE_REDUCE
local shipTypeAccuracyEnhance = BattleConfig.SHIP_TYPE_ACCURACY_ENHANCE

-- arg_1_0 -> fleet(BattleFleetVO)
function BattleFormulas.GetFleetTotalHP(fleet)
	-- var_1_0 -> flagShip
	-- var_1_1 -> unitList
	-- var_1_2 -> totalHP
	local flagShip = fleet:GetFlagShip()
	local unitList = fleet:GetUnitList()
	local totalHP = bfConsts.NUM0

	-- iter_1_0 -> _
	-- iter_1_1 -> unit
	for _, unit in ipairs(unitList) do
		if unit == flagShip then
			-- bfConsts.HP_CONST = 1.5
			totalHP = totalHP + BattleAttr.GetCurrent(unit, "maxHP") * bfConsts.HP_CONST
		else
			totalHP = totalHP + BattleAttr.GetCurrent(unit, "maxHP")
		end
	end

	return totalHP
end

-- arg_2_0 -> scoutList
function BattleFormulas.GetFleetVelocity(scoutList)
	-- var_2_0 -> frontShip
	local frontShip = scoutList[1]

	-- 这一段是什么意思看不太懂
	if frontShip then
		-- var_2_1 -> frontShipVelocity
		local frontShipVelocity = BattleAttr.GetCurrent(frontShip, "fleetVelocity")

		if frontShipVelocity > bfConsts.NUM0 then
			return frontShipVelocity * bfConsts.PERCENT
		end
	end

	-- var_2_2 -> totalSpeed
	-- var_2_3 -> numShips
	local totalSpeed = bfConsts.NUM0
	local numShips = #scoutList

	-- iter_2_0 -> _
	-- iter_2_1 -> ship
	for _, ship in ipairs(scoutList) do
		totalSpeed = totalSpeed + ship:GetAttrByName("velocity")
	end

	-- var_2_4 -> speedFactor
		-- bfConsts.SPEED_CONST = 0.02
		-- 即speedFactor = 1 - 0.02 * (numShips - 1)
	local speedFactor = bfConsts.NUM1 - bfConsts.SPEED_CONST * (numShips - bfConsts.NUM1)

	-- 平均速度乘以speedFactor
	return totalSpeed / numShips * speedFactor
end

-- arg_3_0 -> fleet
function BattleFormulas.GetFleetReload(fleet)
	-- var_3_0 -> totalReload
	local totalReload = bfConsts.NUM0

	-- iter_3_0 -> _
	-- iter_3_1 -> ship(BattleUnit)
	for _, ship in ipairs(fleet) do
		totalReload = totalReload + ship:GetReload()
	end

	return totalReload
end

function BattleFormulas.GetFleetTorpedoPower(arg_4_0)
	local var_4_0 = bfConsts.NUM0

	for iter_4_0, iter_4_1 in ipairs(arg_4_0) do
		var_4_0 = var_4_0 + iter_4_1:GetTorpedoPower()
	end

	return var_4_0
end

function BattleFormulas.AttrFixer(arg_5_0, arg_5_1)
	if arg_5_0 == SYSTEM_DUEL then
		local var_5_0 = arg_5_1.level
		local var_5_1 = arg_5_1.durability
		local var_5_2, var_5_3 = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(arg_5_0, var_5_0)

		arg_5_1.durability = var_5_1 * var_5_2 + var_5_3
	end
end

function BattleFormulas.HealFixer(arg_6_0, arg_6_1)
	local var_6_0 = 1

	if arg_6_0 == SYSTEM_DUEL then
		local var_6_1 = arg_6_1.level

		var_6_0 = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(arg_6_0, var_6_1)
	end

	return var_6_0
end

function BattleFormulas.ConvertShipSpeed(arg_7_0)
	return arg_7_0 * shipSpeedConvertRatio
end

function BattleFormulas.ConvertAircraftSpeed(arg_8_0)
	if arg_8_0 then
		return arg_8_0 * aircraftSpeedConvertRatio
	else
		return nil
	end
end

function BattleFormulas.ConvertBulletSpeed(arg_9_0)
	return arg_9_0 * bulletSpeedConvertRatio
end

function BattleFormulas.ConvertBulletDataSpeed(arg_10_0)
	return arg_10_0 / bulletSpeedConvertRatio
end

function BattleFormulas.CreateContextCalculateDamage(arg_11_0)
	return function(arg_12_0, arg_12_1, arg_12_2, arg_12_3)
		local var_12_0 = bfConsts.NUM1
		local var_12_1 = bfConsts.NUM0
		local var_12_2 = bfConsts.NUM10000
		local var_12_3 = bfConsts.DRATE
		local var_12_4 = bfConsts.ACCURACY
		local var_12_5 = arg_12_0:GetWeaponHostAttr()
		local var_12_6 = arg_12_0:GetWeapon()
		local var_12_7 = arg_12_0:GetWeaponTempData()
		local var_12_8 = var_12_7.type
		local var_12_9 = var_12_7.attack_attribute
		local var_12_10 = var_12_6:GetConvertedAtkAttr()
		local var_12_11 = arg_12_0:GetTemplate()
		local var_12_12 = var_12_11.damage_type
		local var_12_13 = var_12_11.random_damage_rate
		local var_12_14 = arg_12_1._attr
		local var_12_15 = arg_12_3 or var_12_0

		arg_12_2 = arg_12_2 or var_12_1

		local var_12_16 = var_12_14.armorType
		local var_12_17 = var_12_5.formulaLevel - var_12_14.formulaLevel
		local var_12_18 = var_12_0
		local var_12_19 = false
		local var_12_20 = false
		local var_12_21 = var_12_0
		local var_12_22 = arg_12_0:GetCorrectedDMG()
		local var_12_23 = (var_12_0 + arg_12_0:GetWeaponAtkAttr() * var_12_10) * var_12_22

		if var_12_9 == BattleConst.WeaponDamageAttr.CANNON then
			var_12_15 = var_12_0 + BattleAttr.GetCurrent(arg_12_1, "injureRatioByCannon") + BattleAttr.GetCurrent(arg_12_0, "damageRatioByCannon")
		elseif var_12_9 == BattleConst.WeaponDamageAttr.TORPEDO then
			var_12_15 = var_12_0 + BattleAttr.GetCurrent(arg_12_1, "injureRatioByBulletTorpedo") + BattleAttr.GetCurrent(arg_12_0, "damageRatioByBulletTorpedo")
		elseif var_12_9 == BattleConst.WeaponDamageAttr.AIR then
			local var_12_24 = BattleAttr.GetCurrent(arg_12_0, "airResistPierceActive") == 1 and BattleAttr.GetCurrent(arg_12_0, "airResistPierce") or 0

			var_12_15 = var_12_15 * math.min(var_12_3[7] / (var_12_14.antiAirPower + var_12_3[7]) + var_12_24, 1) * (var_12_0 + BattleAttr.GetCurrent(arg_12_1, "injureRatioByAir") + BattleAttr.GetCurrent(arg_12_0, "damageRatioByAir"))
		elseif var_12_9 == BattleConst.WeaponDamageAttr.ANTI_AIR then
			-- block empty
		elseif var_12_9 == BattleConst.WeaponDamageAttr.ANIT_SUB then
			-- block empty
		end

		local var_12_25 = var_12_5.luck - var_12_14.luck
		local var_12_26 = BattleAttr.GetCurrent(arg_12_1, "perfectDodge")
		local var_12_27 = math.max(var_12_5.attackRating, 0)
		local var_12_28

		if var_12_26 >= 1 then
			var_12_28 = true
		else
			local var_12_29 = var_12_4[1] + var_12_27 / (var_12_27 + var_12_14.dodgeRate + var_12_4[2]) + (var_12_25 + var_12_17) * bfConsts.PERCENT1
			local var_12_30 = BattleAttr.GetCurrent(arg_12_0, "accuracyRateExtra")
			local var_12_31 = BattleAttr.GetCurrent(arg_12_0, shipTypeAccuracyEnhance[arg_12_1:GetTemplate().type])
			local var_12_32 = BattleAttr.GetCurrent(arg_12_1, "dodgeRateExtra")
			local var_12_33 = math.max(var_12_3[5], math.min(var_12_0, var_12_29 + var_12_30 + var_12_31 - var_12_32))

			var_12_28 = not BattleFormulas.IsHappen(var_12_33 * var_12_2)
		end

		if not var_12_28 then
			local var_12_34
			local var_12_35 = BattleAttr.GetCurrent(arg_12_0, "GCT") == 1 and 1 or bfConsts.DFT_CRIT_RATE + var_12_27 / (var_12_27 + var_12_14.dodgeRate + var_12_3[4]) + (var_12_25 + var_12_17) * var_12_3[3] + BattleAttr.GetCurrent(arg_12_0, "cri") + BattleAttr.GetTagAttrCri(arg_12_0, arg_12_1)

			var_12_21 = math.random(BattleConfig.RANDOM_DAMAGE_MIN, BattleConfig.RANDOM_DAMAGE_MAX) + var_12_23

			if BattleFormulas.IsHappen(var_12_35 * var_12_2) then
				var_12_20 = true

				local var_12_36 = bfConsts.DFT_CRIT_EFFECT + BattleAttr.GetTagAttrCriDmg(arg_12_0, arg_12_1) + BattleAttr.GetCurrent(arg_12_0, "criDamage") - BattleAttr.GetCurrent(arg_12_1, "criDamageResist")

				var_12_18 = math.max(1, var_12_36)
			else
				var_12_20 = false
			end
		else
			var_12_21 = var_12_1

			local var_12_37 = {
				isMiss = true,
				isDamagePrevent = false,
				isCri = var_12_20
			}

			return var_12_21, var_12_37
		end

		local var_12_38 = bfConsts.NUM1
		local var_12_39 = BattleAttr.GetCurrent(arg_12_0, "damageRatioBullet")
		local var_12_40 = BattleAttr.GetTagAttr(arg_12_0, arg_12_1, arg_11_0)
		local var_12_41 = BattleAttr.GetCurrent(arg_12_1, "injureRatio")
		local var_12_42 = (var_12_6:GetFixAmmo() or var_12_12[var_12_16] or var_12_38) + BattleAttr.GetCurrent(arg_12_0, BattleConfig.DAMAGE_AMMO_TO_ARMOR_RATE_ENHANCE[var_12_16])
		local var_12_43 = BattleAttr.GetCurrent(arg_12_0, BattleConfig.DAMAGE_TO_ARMOR_RATE_ENHANCE[var_12_16])
		local var_12_44 = BattleAttr.GetCurrent(arg_12_0, ammoDamageEnhance[var_12_11.ammo_type])
		local var_12_45 = BattleAttr.GetCurrent(arg_12_1, ammoDamageReduce[var_12_11.ammo_type])
		local var_12_46 = BattleAttr.GetCurrent(arg_12_0, "comboTag")
		local var_12_47 = BattleAttr.GetCurrent(arg_12_1, var_12_46)
		local var_12_48 = math.max(var_12_38, math.floor(var_12_21 * var_12_15 * (var_12_38 - arg_12_2) * var_12_42 * (var_12_38 + var_12_43) * var_12_18 * (var_12_38 + var_12_39) * var_12_40 * (var_12_38 + var_12_41) * (var_12_38 + var_12_44 - var_12_45) * (var_12_38 + var_12_47) * (var_12_38 + math.min(var_12_3[1], math.max(-var_12_3[1], var_12_17)) * var_12_3[2])))

		if arg_12_1:GetCurrentOxyState() == BattleConst.OXY_STATE.DIVE then
			var_12_48 = math.floor(var_12_48 * var_12_11.antisub_enhancement)
		end

		local var_12_49 = {
			isMiss = var_12_28,
			isCri = var_12_20,
			damageAttr = var_12_9
		}
		local var_12_50 = arg_12_0:GetDamageEnhance()

		if var_12_50 ~= 1 then
			var_12_48 = math.floor(var_12_48 * var_12_50)
		end

		local var_12_51 = var_12_48 * var_12_14.repressReduce

		if var_12_13 ~= 0 then
			var_12_51 = var_12_51 * (Mathf.RandomFloat(var_12_13) + 1)
		end

		local var_12_52 = BattleAttr.GetCurrent(arg_12_0, "damageEnhanceProjectile")
		local var_12_53 = math.max(0, var_12_51 + var_12_52)

		if arg_11_0 then
			var_12_53 = var_12_53 * (bfConsts.NUM1 + BattleAttr.GetCurrent(arg_12_0, "worldBuffResistance"))
		end

		local var_12_54 = math.floor(var_12_53)
		local var_12_55 = var_12_11.DMG_font[var_12_16]

		if var_12_52 < 0 then
			var_12_55 = BattleConfig.BULLET_DECREASE_DMG_FONT
		end

		return var_12_54, var_12_49, var_12_55
	end
end

function BattleFormulas.CalculateIgniteDamage(arg_13_0, arg_13_1, arg_13_2)
	local var_13_0 = arg_13_0._attr

	return arg_13_0:GetWeapon():GetCorrectedDMG() * (1 + var_13_0[arg_13_1] * bfConsts.PERCENT) * arg_13_2
end

function BattleFormulas.WeaponDamagePreCorrection(arg_14_0, arg_14_1)
	local var_14_0 = arg_14_0:GetTemplateData()
	local var_14_1 = arg_14_1 or var_14_0.damage
	local var_14_2 = var_14_0.corrected

	return var_14_1 * arg_14_0:GetPotential() * var_14_2 * bfConsts.PERCENT
end

function BattleFormulas.WeaponAtkAttrPreRatio(arg_15_0)
	return arg_15_0:GetTemplateData().attack_attribute_ratio * bfConsts.PERCENT2
end

function BattleFormulas.GetMeteoDamageRatio(arg_16_0)
	local var_16_0 = {}
	local var_16_1 = bfConsts.METEO_RATE
	local var_16_2 = var_16_1[1]

	if arg_16_0 >= var_16_1[2] then
		for iter_16_0 = 1, arg_16_0 + 1 do
			var_16_0[iter_16_0] = var_16_2
		end

		return var_16_0
	else
		local var_16_3 = 1 - var_16_2 * arg_16_0

		for iter_16_1 = 1, arg_16_0 do
			local var_16_4 = math.random() * var_16_3 * (var_16_1[3] + var_16_1[4] * (iter_16_1 - 1) / arg_16_0)

			var_16_0[iter_16_1] = var_16_4 + var_16_2
			var_16_3 = math.max(0, var_16_3 - var_16_4)
		end

		var_16_0[arg_16_0 + 1] = var_16_3

		return var_16_0
	end
end

function BattleFormulas.CalculateFleetAntiAirTotalDamage(arg_17_0)
	local var_17_0 = arg_17_0:GetCrewUnitList()
	local var_17_1 = 0

	for iter_17_0, iter_17_1 in pairs(var_17_0) do
		local var_17_2 = BattleAttr.GetCurrent(iter_17_0, "antiAirPower")

		for iter_17_2, iter_17_3 in ipairs(iter_17_1) do
			local var_17_3 = iter_17_3:GetConvertedAtkAttr()
			local var_17_4 = iter_17_3:GetCorrectedDMG()

			var_17_1 = var_17_1 + math.max(1, (var_17_2 * var_17_3 + 1) * var_17_4)
		end
	end

	return var_17_1
end

function BattleFormulas.CalculateRepaterAnitiAirTotalDamage(arg_18_0)
	local var_18_0 = arg_18_0:GetHost()
	local var_18_1 = arg_18_0:GetConvertedAtkAttr()
	local var_18_2 = arg_18_0:GetCorrectedDMG()
	local var_18_3 = BattleAttr.GetCurrent(var_18_0, "antiAirPower")

	return (math.max(1, (var_18_3 * var_18_1 + 1) * var_18_2))
end

function BattleFormulas.RollRepeaterHitDice(arg_19_0, arg_19_1)
	local var_19_0 = arg_19_0:GetHost()
	local var_19_1 = BattleAttr.GetCurrent(var_19_0, "antiAirPower")
	local var_19_2 = math.max(BattleAttr.GetCurrent(var_19_0, "attackRating"), 0)
	local var_19_3 = BattleAttr.GetCurrent(arg_19_1, "airPower")
	local var_19_4 = BattleAttr.GetCurrent(arg_19_1, "dodgeLimit")
	local var_19_5 = BattleAttr.GetCurrent(arg_19_1, "dodge")
	local var_19_6 = var_19_3 / AnitAirRepeaterConfig.const_A + AnitAirRepeaterConfig.const_B
	local var_19_7 = var_19_6 / (var_19_1 * var_19_5 + var_19_6 + AnitAirRepeaterConfig.const_C)
	local var_19_8 = math.min(var_19_4, var_19_7)

	return BattleFormulas.IsHappen(var_19_8 * bfConsts.NUM10000)
end

function BattleFormulas.AntiAirPowerWeight(arg_20_0)
	return arg_20_0 * arg_20_0
end

function BattleFormulas.CalculateDamageFromAircraftToMainShip(arg_21_0, arg_21_1)
	local var_21_0 = BattleAttr.GetCurrent(arg_21_0, "airPower")
	local var_21_1 = BattleAttr.GetCurrent(arg_21_1, "antiAirPower")
	local var_21_2 = BattleAttr.GetCurrent(arg_21_0, "crashDMG")
	local var_21_3 = arg_21_0:GetHPRate()
	local var_21_4 = BattleAttr.GetCurrent(arg_21_0, "formulaLevel")
	local var_21_5 = BattleAttr.GetCurrent(arg_21_1, "formulaLevel")
	local var_21_6 = BattleAttr.GetCurrent(arg_21_1, "injureRatio")
	local var_21_7 = BattleAttr.GetCurrent(arg_21_1, "injureRatioByAir")
	local var_21_8 = bfConsts.PLANE_LEAK_RATE
	local var_21_9 = math.max(var_21_8[1], math.floor((var_21_2 * (var_21_8[2] + var_21_0 * var_21_8[3]) + var_21_4 * var_21_8[4]) * (var_21_3 * var_21_8[5] + var_21_8[6]) * (var_21_8[7] + (var_21_4 - var_21_5) * var_21_8[8]) * (var_21_8[9] / (var_21_1 + var_21_8[10])) * (var_21_8[11] + var_21_6) * (var_21_8[12] + var_21_7)))

	return (math.floor(var_21_9 * BattleAttr.GetCurrent(arg_21_1, "repressReduce")))
end

function BattleFormulas.CalculateDamageFromShipToMainShip(arg_22_0, arg_22_1)
	local var_22_0 = BattleAttr.GetCurrent(arg_22_0, "cannonPower")
	local var_22_1 = BattleAttr.GetCurrent(arg_22_0, "torpedoPower")
	local var_22_2 = arg_22_0:GetHPRate()
	local var_22_3 = BattleAttr.GetCurrent(arg_22_0, "formulaLevel")
	local var_22_4 = BattleAttr.GetCurrent(arg_22_1, "formulaLevel")
	local var_22_5 = BattleAttr.GetCurrent(arg_22_1, "injureRatio")
	local var_22_6 = bfConsts.LEAK_RATE
	local var_22_7 = math.max(var_22_6[1], math.floor(((var_22_0 + var_22_1) * var_22_6[2] + var_22_3 * var_22_6[7]) * (var_22_6[5] + var_22_5) * (var_22_2 * var_22_6[3] + var_22_6[4]) * (var_22_6[5] + (var_22_3 - var_22_4) * var_22_6[6])))

	return (math.floor(var_22_7 * BattleAttr.GetCurrent(arg_22_1, "repressReduce")))
end

function BattleFormulas.CalculateDamageFromSubmarinToMainShip(arg_23_0, arg_23_1)
	local var_23_0 = BattleAttr.GetCurrent(arg_23_0, "torpedoPower")
	local var_23_1 = arg_23_0:GetHPRate()
	local var_23_2 = BattleAttr.GetCurrent(arg_23_0, "formulaLevel")
	local var_23_3 = BattleAttr.GetCurrent(arg_23_1, "formulaLevel")
	local var_23_4 = BattleAttr.GetCurrent(arg_23_1, "injureRatio")
	local var_23_5 = bfConsts.SUBMARINE_KAMIKAZE

	return (math.max(var_23_5[1], math.floor((var_23_0 * var_23_5[2] + var_23_2 * var_23_5[3]) * (var_23_5[4] + var_23_4) * (var_23_1 * var_23_5[5] + var_23_5[6]) * (var_23_5[7] + (var_23_2 - var_23_3) * var_23_5[8]))))
end

function BattleFormulas.RollSubmarineDualDice(arg_24_0)
	local var_24_0 = BattleAttr.GetCurrent(arg_24_0, "dodgeRate")
	local var_24_1 = var_24_0 / (var_24_0 + BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_K) * BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_P

	return BattleFormulas.IsHappen(var_24_1 * bfConsts.NUM10000)
end

function BattleFormulas.CalculateCrashDamage(arg_25_0, arg_25_1)
	local var_25_0 = BattleAttr.GetCurrent(arg_25_0, "maxHP")
	local var_25_1 = BattleAttr.GetCurrent(arg_25_1, "maxHP")
	local var_25_2 = var_25_0 * bfConsts.CRASH_RATE[1]
	local var_25_3 = var_25_1 * bfConsts.CRASH_RATE[1]
	local var_25_4 = BattleAttr.GetCurrent(arg_25_0, "hammerDamageRatio")
	local var_25_5 = BattleAttr.GetCurrent(arg_25_1, "hammerDamageRatio")
	local var_25_6 = BattleAttr.GetCurrent(arg_25_0, "hammerDamagePrevent")
	local var_25_7 = BattleAttr.GetCurrent(arg_25_1, "hammerDamagePrevent")
	local var_25_8 = math.min(var_25_6, BattleConfig.HammerCFG.PreventUpperBound)
	local var_25_9 = math.min(var_25_7, BattleConfig.HammerCFG.PreventUpperBound)
	local var_25_10 = math.sqrt(var_25_0 * var_25_1) * bfConsts.CRASH_RATE[2]
	local var_25_11 = math.min(var_25_2, var_25_10)
	local var_25_12 = math.min(var_25_3, var_25_10)
	local var_25_13 = math.floor(var_25_11 * (1 + var_25_5) * (1 - var_25_8))
	local var_25_14 = math.floor(var_25_13 * BattleAttr.GetCurrent(arg_25_0, "repressReduce"))
	local var_25_15 = math.floor(var_25_12 * (1 + var_25_4) * (1 - var_25_9))
	local var_25_16 = math.floor(var_25_15 * BattleAttr.GetCurrent(arg_25_1, "repressReduce"))

	return var_25_14, var_25_16
end

function BattleFormulas.CalculateFleetDamage(arg_26_0)
	return arg_26_0 * bfConsts.SCORE_RATE[1]
end

function BattleFormulas.CalculateFleetOverDamage(arg_27_0, arg_27_1)
	if arg_27_1 == arg_27_0:GetFlagShip() then
		return BattleAttr.GetCurrent(arg_27_1, "maxHP") * bfConsts.SCORE_RATE[2]
	else
		return BattleAttr.GetCurrent(arg_27_1, "maxHP") * bfConsts.SCORE_RATE[3]
	end
end

function BattleFormulas.CalculateReloadTime(arg_28_0, arg_28_1)
	return arg_28_0 / BattleConfig.K1 / math.sqrt((arg_28_1 + BattleConfig.K2) * BattleConfig.K3)
end

function BattleFormulas.CaclulateReloaded(arg_29_0, arg_29_1)
	return math.sqrt((arg_29_1 + BattleConfig.K2) * BattleConfig.K3) * arg_29_0 * BattleConfig.K1
end

function BattleFormulas.CaclulateReloadAttr(arg_30_0, arg_30_1)
	local var_30_0 = arg_30_0 / BattleConfig.K1 / arg_30_1

	return math.max(var_30_0 * var_30_0 / BattleConfig.K3 - BattleConfig.K2, 0)
end

function BattleFormulas.CaclulateAirAssistReloadMax(arg_31_0)
	local var_31_0 = 0

	for iter_31_0, iter_31_1 in ipairs(arg_31_0) do
		var_31_0 = var_31_0 + iter_31_1:GetTemplateData().reload_max
	end

	return var_31_0 / #arg_31_0 * airAssistReloadFactor
end

function BattleFormulas.CaclulateDOTPlace(arg_32_0, arg_32_1, arg_32_2, arg_32_3)
	local var_32_0 = arg_32_1.arg_list

	if var_32_0.tagOnly and not arg_32_3:ContainsLabelTag(var_32_0.tagOnly) then
		return false
	end

	local var_32_1 = BattleConfig.DOT_CONFIG[var_32_0.dotType]
	local var_32_2 = arg_32_2 and arg_32_2:GetAttrByName(var_32_1.hit) or bfConsts.NUM0
	local var_32_3 = arg_32_3 and arg_32_3:GetAttrByName(var_32_1.resist) or bfConsts.NUM0

	return BattleFormulas.IsHappen(arg_32_0 * (bfConsts.NUM1 + var_32_2) * (bfConsts.NUM1 - var_32_3))
end

function BattleFormulas.CaclulateDOTDuration(arg_33_0, arg_33_1, arg_33_2)
	local var_33_0 = arg_33_0.arg_list
	local var_33_1 = BattleConfig.DOT_CONFIG[var_33_0.dotType]

	return (arg_33_1 and arg_33_1:GetAttrByName(var_33_1.prolong) or bfConsts.NUM0) - (arg_33_2 and arg_33_2:GetAttrByName(var_33_1.shorten) or bfConsts.NUM0)
end

function BattleFormulas.CaclulateDOTDamageEnhanceRate(arg_34_0, arg_34_1, arg_34_2)
	local var_34_0 = arg_34_0.arg_list
	local var_34_1 = BattleConfig.DOT_CONFIG[var_34_0.dotType]

	return ((arg_34_1 and arg_34_1:GetAttrByName(var_34_1.enhance) or bfConsts.NUM0) - (arg_34_2 and arg_34_2:GetAttrByName(var_34_1.reduce) or bfConsts.NUM0)) * bfConsts.PERCENT2
end

function BattleFormulas.CaclulateMetaDotaDamage(arg_35_0, arg_35_1)
	local var_35_0 = ys.Battle.BattleDataFunction.GetMetaBossTemplate(arg_35_0)

	if type(var_35_0.state) == "string" then
		return 0
	end

	local var_35_1 = var_35_0.state
	local var_35_2 = os.time({
		year = var_35_1[1][1][1],
		month = var_35_1[1][1][2],
		day = var_35_1[1][1][3],
		hour = var_35_1[1][2][1],
		minute = var_35_1[1][2][2],
		second = var_35_1[1][2][3]
	})
	local var_35_3 = os.time({
		year = var_35_1[2][1][1],
		month = var_35_1[2][1][2],
		day = var_35_1[2][1][3],
		hour = var_35_1[2][2][1],
		minute = var_35_1[2][2][2],
		second = var_35_1[2][2][3]
	})
	local var_35_4 = os.difftime(var_35_3, var_35_2)
	local var_35_5 = math.floor(var_35_4 / 86400)
	local var_35_6 = math.floor(os.difftime(pg.TimeMgr.GetInstance():GetServerTime(), var_35_2) / 86400)
	local var_35_7 = pg.gameset.world_metaboss_supportattack.description
	local var_35_8 = var_35_7[1]
	local var_35_9 = var_35_5 - var_35_7[2]
	local var_35_10 = var_35_7[3]
	local var_35_11 = var_35_7[4]
	local var_35_12 = var_35_7[5]
	local var_35_13 = ys.Battle.BattleDataFunction.GetMetaBossLevelTemplate(arg_35_0, arg_35_1).hp
	local var_35_14 = math.floor(var_35_13 * var_35_10 / var_35_12 / (1 + 0.5 * var_35_11) / (var_35_9 - var_35_8) * math.min(var_35_6 - var_35_8 + 1, var_35_9 - var_35_8))

	return var_35_14 + math.random(math.floor(var_35_11 * var_35_14))
end

function BattleFormulas.CalculateMaxAimBiasRange(arg_36_0)
	local var_36_0 = BattleConfig.AIM_BIAS_FLEET_RANGE_MOD
	local var_36_1

	if #arg_36_0 == 1 then
		local var_36_2 = arg_36_0[1]

		var_36_1 = BattleAttr.GetCurrent(arg_36_0[1], "dodgeRate") * var_36_0
	else
		local var_36_3 = {}

		for iter_36_0, iter_36_1 in ipairs(arg_36_0) do
			table.insert(var_36_3, BattleAttr.GetCurrent(iter_36_1, "dodgeRate"))
		end

		table.sort(var_36_3, function(arg_37_0, arg_37_1)
			return arg_37_1 < arg_37_0
		end)

		var_36_1 = (var_36_3[1] + var_36_3[2] * 0.6 + (var_36_3[3] or 0) * 0.3) / #var_36_3 * var_36_0
	end

	return (math.min(var_36_1, BattleConfig.AIM_BIAS_MAX_RANGE_SCOUT))
end

function BattleFormulas.CalculateMaxAimBiasRangeSub(arg_38_0)
	local var_38_0 = BattleAttr.GetCurrent(arg_38_0[1], "dodgeRate") * BattleConfig.AIM_BIAS_SUB_RANGE_MOD

	return (math.min(var_38_0, BattleConfig.AIM_BIAS_MAX_RANGE_SUB))
end

function BattleFormulas.CalculateMaxAimBiasRangeMonster(arg_39_0)
	local var_39_0 = BattleAttr.GetCurrent(arg_39_0[1], "dodgeRate") * BattleConfig.AIM_BIAS_MONSTER_RANGE_MOD

	return (math.min(var_39_0, BattleConfig.AIM_BIAS_MAX_RANGE_MONSTER))
end

function BattleFormulas.CalculateBiasDecay(arg_40_0)
	local var_40_0 = arg_40_0 * BattleConfig.AIM_BIAS_DECAY_MOD_MONSTER

	return (math.min(var_40_0, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SCOUT))
end

function BattleFormulas.CalculateBiasDecayMonster(arg_41_0)
	local var_41_0 = arg_41_0 * BattleConfig.AIM_BIAS_DECAY_MOD

	return (math.min(var_41_0, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER))
end

function BattleFormulas.CalculateBiasDecayMonsterInSmoke(arg_42_0)
	local var_42_0 = arg_42_0 * BattleConfig.AIM_BIAS_DECAY_MOD * BattleConfig.AIM_BIAS_DECAY_SMOKE

	return (math.min(var_42_0, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER))
end

function BattleFormulas.CalculateBiasDecayDiving(arg_43_0)
	local var_43_0 = math.max(0, arg_43_0 - BattleConfig.AIM_BIAS_DECAY_SUB_CONST) * BattleConfig.AIM_BIAS_DECAY_MOD

	return (math.min(var_43_0, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SUB))
end

function BattleFormulas.WorldEnemyAttrEnhance(arg_44_0, arg_44_1)
	return 1 + arg_44_0 / (1 + BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_C^(BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_B - arg_44_1))
end

local var_0_15 = setmetatable({}, {
	__index = function(arg_45_0, arg_45_1)
		return 0
	end
})

function BattleFormulas.WorldMapRewardAttrEnhance(arg_46_0, arg_46_1)
	arg_46_0 = arg_46_0 or var_0_15
	arg_46_1 = arg_46_1 or var_0_15

	local var_46_0
	local var_46_1
	local var_46_2
	local var_46_3 = {
		{
			gameset.attr_world_value_X1.key_value / 10000,
			gameset.attr_world_value_X2.key_value / 10000
		},
		{
			gameset.attr_world_value_Y1.key_value / 10000,
			gameset.attr_world_value_Y2.key_value / 10000
		},
		{
			gameset.attr_world_value_Z1.key_value / 10000,
			gameset.attr_world_value_Z2.key_value / 10000
		}
	}
	local var_46_4 = gameset.attr_world_damage_fix.key_value / 10000
	local var_46_5

	if arg_46_0[1] == 0 then
		var_46_5 = var_46_3[1][2]
	else
		var_46_5 = arg_46_1[1] / arg_46_0[1]
	end

	local var_46_6 = 1 - math.clamp(var_46_5, var_46_3[1][1], var_46_3[1][2])

	if arg_46_0[2] == 0 then
		var_46_5 = var_46_3[2][2]
	else
		var_46_5 = arg_46_1[2] / arg_46_0[2]
	end

	local var_46_7 = 1 - math.clamp(var_46_5, var_46_3[2][1], var_46_3[2][2])

	if arg_46_0[3] == 0 then
		var_46_5 = var_46_3[3][2]
	else
		var_46_5 = arg_46_1[3] / arg_46_0[3]
	end

	local var_46_8 = math.max(1 - math.clamp(var_46_5, var_46_3[3][1], var_46_3[3][2]), -var_46_4)

	return var_46_6, var_46_7, var_46_8
end

function BattleFormulas.WorldMapRewardHealingRate(arg_47_0, arg_47_1)
	local var_47_0 = {
		gameset.attr_world_value_H1.key_value / 10000,
		gameset.attr_world_value_H2.key_value / 10000
	}

	arg_47_0 = arg_47_0 or var_0_15
	arg_47_1 = arg_47_1 or var_0_15

	local var_47_1

	if arg_47_0[3] == 0 then
		var_47_1 = var_47_0[2]
	else
		var_47_1 = arg_47_1[3] / arg_47_0[3]
	end

	return math.clamp(var_47_1, var_47_0[1], var_47_0[2])
end

function BattleFormulas.CalcDamageLock()
	return 0, {
		false,
		true,
		false
	}
end

function BattleFormulas.CalcDamageLockA2M()
	return 0
end

function BattleFormulas.CalcDamageLockS2M()
	return 0
end

function BattleFormulas.CalcDamageLockCrush()
	return 0, 0
end

function BattleFormulas.UnilateralCrush()
	return 0, 100000
end

function BattleFormulas.ChapterRepressReduce(arg_53_0)
	return 1 - arg_53_0 * 0.01
end

function BattleFormulas.IsHappen(arg_54_0)
	if arg_54_0 <= 0 then
		return false
	elseif arg_54_0 >= 10000 then
		return true
	else
		return arg_54_0 >= math.random(10000)
	end
end

function BattleFormulas.WeightRandom(arg_55_0)
	local var_55_0, var_55_1 = BattleFormulas.GenerateWeightList(arg_55_0)

	return (BattleFormulas.WeightListRandom(var_55_0, var_55_1))
end

function BattleFormulas.WeightListRandom(arg_56_0, arg_56_1)
	local var_56_0 = math.random(0, arg_56_1)

	for iter_56_0, iter_56_1 in pairs(arg_56_0) do
		local var_56_1 = iter_56_0.min
		local var_56_2 = iter_56_0.max

		if var_56_1 <= var_56_0 and var_56_0 <= var_56_2 then
			return iter_56_1
		end
	end
end

function BattleFormulas.GenerateWeightList(arg_57_0)
	local var_57_0 = {}
	local var_57_1 = -1

	for iter_57_0, iter_57_1 in ipairs(arg_57_0) do
		local var_57_2 = iter_57_1.weight
		local var_57_3 = iter_57_1.rst
		local var_57_4 = var_57_1 + 1
		local var_57_5

		var_57_1 = var_57_1 + var_57_2

		local var_57_6 = var_57_1

		var_57_0[{
			min = var_57_4,
			max = var_57_6
		}] = var_57_3
	end

	return var_57_0, var_57_1
end

function BattleFormulas.IsListHappen(arg_58_0)
	for iter_58_0, iter_58_1 in ipairs(arg_58_0) do
		if BattleFormulas.IsHappen(iter_58_1[1]) then
			return true, iter_58_1[2]
		end
	end

	return false, nil
end

function BattleFormulas.BulletYAngle(arg_59_0, arg_59_1)
	return math.rad2Deg * math.atan2(arg_59_1.z - arg_59_0.z, arg_59_1.x - arg_59_0.x)
end

function BattleFormulas.RandomPosNull(arg_60_0, arg_60_1)
	arg_60_1 = arg_60_1 or 10

	local var_60_0 = arg_60_0.distance or 10
	local var_60_1 = var_60_0 * var_60_0
	local var_60_2 = ys.Battle.BattleTargetChoise.TargetAll()
	local var_60_3
	local var_60_4

	for iter_60_0 = 1, arg_60_1 do
		local var_60_5 = true
		local var_60_6 = BattleFormulas.RandomPos(arg_60_0)

		for iter_60_1, iter_60_2 in pairs(var_60_2) do
			local var_60_7 = iter_60_2:GetPosition()

			if var_60_1 > Vector3.SqrDistance(var_60_6, var_60_7) then
				var_60_5 = false

				break
			end
		end

		if var_60_5 then
			return var_60_6
		end
	end

	return nil
end

function BattleFormulas.RandomPos(arg_61_0)
	local var_61_0 = arg_61_0[1] or 0
	local var_61_1 = arg_61_0[2] or 0
	local var_61_2 = arg_61_0[3] or 0

	if arg_61_0.rangeX or arg_61_0.rangeY or arg_61_0.rangeZ then
		local var_61_3 = BattleFormulas.RandomDelta(arg_61_0.rangeX)
		local var_61_4 = BattleFormulas.RandomDelta(arg_61_0.rangeY)
		local var_61_5 = BattleFormulas.RandomDelta(arg_61_0.rangeZ)

		return Vector3(var_61_0 + var_61_3, var_61_1 + var_61_4, var_61_2 + var_61_5)
	else
		local var_61_6 = BattleFormulas.RandomPosXYZ(arg_61_0, "X1", "X2")
		local var_61_7 = BattleFormulas.RandomPosXYZ(arg_61_0, "Y1", "Y2")
		local var_61_8 = BattleFormulas.RandomPosXYZ(arg_61_0, "Z1", "Z2")

		return Vector3(var_61_0 + var_61_6, var_61_1 + var_61_7, var_61_2 + var_61_8)
	end
end

function BattleFormulas.RandomPosXYZ(arg_62_0, arg_62_1, arg_62_2)
	arg_62_1 = arg_62_0[arg_62_1]
	arg_62_2 = arg_62_0[arg_62_2]

	if arg_62_1 and arg_62_2 then
		return math.random(arg_62_1, arg_62_2)
	else
		return 0
	end
end

function BattleFormulas.RandomPosCenterRange(arg_63_0)
	local var_63_0 = BattleFormulas.RandomDelta(arg_63_0.rangeX)
	local var_63_1 = BattleFormulas.RandomDelta(arg_63_0.rangeY)
	local var_63_2 = BattleFormulas.RandomDelta(arg_63_0.rangeZ)

	return Vector3(var_63_0, var_63_1, var_63_2)
end

function BattleFormulas.RandomDelta(arg_64_0)
	if arg_64_0 and arg_64_0 > 0 then
		return math.random(arg_64_0 + arg_64_0) - arg_64_0
	else
		return 0
	end
end

function BattleFormulas.simpleCompare(arg_65_0, arg_65_1)
	local var_65_0, var_65_1 = string.find(arg_65_0, "%p+")
	local var_65_2 = string.sub(arg_65_0, var_65_0, var_65_1)
	local var_65_3 = string.sub(arg_65_0, var_65_1 + 1, #arg_65_0)
	local var_65_4 = getCompareFuncByPunctuation(var_65_2)
	local var_65_5 = tonumber(var_65_3)

	return var_65_4(arg_65_1, var_65_5)
end

function BattleFormulas.parseCompareUnitAttr(arg_66_0, arg_66_1, arg_66_2)
	local var_66_0, var_66_1 = string.find(arg_66_0, "%p+")
	local var_66_2 = string.sub(arg_66_0, var_66_0, var_66_1)
	local var_66_3 = string.sub(arg_66_0, 1, var_66_0 - 1)
	local var_66_4 = string.sub(arg_66_0, var_66_1 + 1, #arg_66_0)
	local var_66_5 = getCompareFuncByPunctuation(var_66_2)
	local var_66_6 = tonumber(var_66_3) or arg_66_1:GetAttrByName(var_66_3)
	local var_66_7 = tonumber(var_66_4) or arg_66_2:GetAttrByName(var_66_4)

	return var_66_5(var_66_6, var_66_7)
end

function BattleFormulas.parseCompareUnitTemplate(arg_67_0, arg_67_1, arg_67_2)
	local var_67_0, var_67_1 = string.find(arg_67_0, "%p+")
	local var_67_2 = string.sub(arg_67_0, var_67_0, var_67_1)
	local var_67_3 = string.sub(arg_67_0, 1, var_67_0 - 1)
	local var_67_4 = string.sub(arg_67_0, var_67_1 + 1, #arg_67_0)
	local var_67_5 = getCompareFuncByPunctuation(var_67_2)
	local var_67_6 = tonumber(var_67_3) or arg_67_1:GetTemplateValue(var_67_3)
	local var_67_7 = tonumber(var_67_4) or arg_67_2:GetTemplateValue(var_67_4)

	return var_67_5(var_67_6, var_67_7)
end

function BattleFormulas.parseCompareBuffAttachData(arg_68_0, arg_68_1)
	local var_68_0, var_68_1 = string.find(arg_68_0, "%p+")
	local var_68_2 = string.sub(arg_68_0, var_68_0, var_68_1)
	local var_68_3 = string.sub(arg_68_0, 1, var_68_0 - 1)

	if arg_68_1.__name ~= var_68_3 then
		return true
	end

	local var_68_4 = tonumber(string.sub(arg_68_0, var_68_1 + 1, #arg_68_0))
	local var_68_5 = arg_68_1:GetEffectAttachData()

	return getCompareFuncByPunctuation(var_68_2)(var_68_5, var_68_4)
end

function BattleFormulas.parseCompare(arg_69_0, arg_69_1)
	local var_69_0, var_69_1 = string.find(arg_69_0, "%p+")
	local var_69_2 = string.sub(arg_69_0, var_69_0, var_69_1)
	local var_69_3 = string.sub(arg_69_0, 1, var_69_0 - 1)
	local var_69_4 = string.sub(arg_69_0, var_69_1 + 1, #arg_69_0)
	local var_69_5 = getCompareFuncByPunctuation(var_69_2)
	local var_69_6 = tonumber(var_69_3) or arg_69_1:GetCurrent(var_69_3)
	local var_69_7 = tonumber(var_69_4) or arg_69_1:GetCurrent(var_69_4)

	return var_69_5(var_69_6, var_69_7)
end

function BattleFormulas.parseFormula(arg_70_0, arg_70_1)
	local var_70_0 = {}
	local var_70_1 = {}

	for iter_70_0 in string.gmatch(arg_70_0, "%w+%.?%w*") do
		table.insert(var_70_0, iter_70_0)
	end

	for iter_70_1 in string.gmatch(arg_70_0, "[^%w%.]") do
		table.insert(var_70_1, iter_70_1)
	end

	local var_70_2 = {}
	local var_70_3 = {}
	local var_70_4 = 1
	local var_70_5 = var_70_0[1]

	var_70_5 = tonumber(var_70_5) or arg_70_1:GetCurrent(var_70_5)

	for iter_70_2, iter_70_3 in ipairs(var_70_1) do
		var_70_4 = var_70_4 + 1

		local var_70_6 = tonumber(var_70_0[var_70_4]) or arg_70_1:GetCurrent(var_70_0[var_70_4])

		if iter_70_3 == "+" or iter_70_3 == "-" then
			table.insert(var_70_3, var_70_5)

			var_70_5 = var_70_6

			table.insert(var_70_2, iter_70_3)
		elseif iter_70_3 == "*" or iter_70_3 == "/" then
			var_70_5 = getArithmeticFuncByOperator(iter_70_3)(var_70_5, var_70_6)
		end
	end

	table.insert(var_70_3, var_70_5)

	local var_70_7 = 1
	local var_70_8 = var_70_3[var_70_7]

	while var_70_7 < #var_70_3 do
		local var_70_9 = getArithmeticFuncByOperator(var_70_2[var_70_7])

		var_70_7 = var_70_7 + 1
		var_70_8 = var_70_9(var_70_8, var_70_3[var_70_7])
	end

	return var_70_8
end
