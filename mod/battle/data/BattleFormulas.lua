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
-- var_0_10 -> airAssistReloadFactor(=2.2)
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

-- arg_4_0 -> fleet
function BattleFormulas.GetFleetTorpedoPower(fleet)
	-- var_4_0 -> totalTorpedoPower
	local totalTorpedoPower = bfConsts.NUM0

	-- iter_4_0 -> _
	-- iter_4_1 -> ship(BattleUnit)
	for _, ship in ipairs(fleet) do
		totalTorpedoPower = totalTorpedoPower + ship:GetTorpedoPower()
	end

	return totalTorpedoPower
end

-- arg_5_0 -> battleType
-- arg_5_1 -> unit(BattleUnit)
function BattleFormulas.AttrFixer(battleType, unit)
	-- 相关定义在const.lua中
	-- SYSTEM_DUEL对应演习模式
	if battleType == SYSTEM_DUEL then
		-- var_5_0 -> level
		-- var_5_1 -> durability
		-- var_5_2 -> durabilityRatio
		-- var_5_3 -> durabilityAdd
		local level = unit.level
		local durability = unit.durability
		local durabilityRatio, durabilityAdd = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(battleType, level)

		unit.durability = durability * durabilityRatio + durabilityAdd
	end
end

-- arg_6_0 -> battleType
-- arg_6_1 -> unit(BattleUnit)
function BattleFormulas.HealFixer(battleType, unit)
	-- var_6_0 -> healRatio
	local healRatio = 1

	if battleType == SYSTEM_DUEL then
		-- var_6_1 -> level
		local level = unit.level

		-- 如果是演习模式，回血倍率跟耐久度倍率一致
		healRatio = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(battleType, level)
	end

	return healRatio
end

-- arg_7_0 -> shipSpeed
-- 原始航速 × 0.02，得到的是每帧移动的距离
-- 区别两个术语：原始航速为Speed，转换后叫做Velocity
function BattleFormulas.ConvertShipSpeed(shipSpeed)
	return shipSpeed * shipSpeedConvertRatio
end

-- arg_8_0 -> aircraftSpeed
-- 原始飞机速度 × 0.02，得到的是每帧移动的距离
function BattleFormulas.ConvertAircraftSpeed(aircraftSpeed)
	if aircraftSpeed then
		return aircraftSpeed * aircraftSpeedConvertRatio
	else
		return nil
	end
end

-- arg_9_0 -> bulletSpeed
-- 原始子弹速度 × 0.2，得到的是每帧移动的距离
function BattleFormulas.ConvertBulletSpeed(bulletSpeed)
	return bulletSpeed * bulletSpeedConvertRatio
end

-- arg_10_0 -> bulletVelocity
-- 将每帧移动的距离转换回原始子弹速度
function BattleFormulas.ConvertBulletDataSpeed(bulletVelocity)
	return bulletVelocity / bulletSpeedConvertRatio
end

-- arg_11_0 -> isWorld
	-- 是否在大世界
function BattleFormulas.CreateContextCalculateDamage(isWorld)
	-- arg_12_0 -> bullet(BattleBulletUnit)
	-- arg_12_1 -> target(BattleUnit)
	-- arg_12_2 -> damageReduceDistance
	-- arg_12_3 -> meteoDamageRatio
	return function(bullet, target, damageReduceDistance, meteoDamageRatio)
		-- var_12_0 -> num1
		local num1 = bfConsts.NUM1
		-- var_12_1 -> num0
		local num0 = bfConsts.NUM0
		-- var_12_2 -> num10000
		local num10000 = bfConsts.NUM10000
		-- var_12_3 -> dRate
		local dRate = bfConsts.DRATE
		-- var_12_4 -> accuracyConst
		local accuracyConst = bfConsts.ACCURACY
		-- var_12_5 -> weaponHostAttr
		local weaponHostAttr = bullet:GetWeaponHostAttr()
		-- var_12_6 -> weapon(BattleWeaponUnit)
		local weapon = bullet:GetWeapon()
		-- var_12_7 -> weaponTemplate
		local weaponTemplate = bullet:GetWeaponTempData()
		-- var_12_8 -> weaponType
		local weaponType = weaponTemplate.type
		-- var_12_9 -> attackAttribute
		local attackAttribute = weaponTemplate.attack_attribute
		-- var_12_10 -> weaponConvertedAtkAttr
			-- 来自BattleFormulas.WeaponAtkAttrPreRatio(), 为属性效率(attackAttributeRatio)/10000
			-- 属性效率一般是三位数，如100，因此最后会变成0.01
			-- 为了方便，一般就简单记为属性效率/100，这样属性效率就是以1为基准的了
		local weaponConvertedAtkAttr = weapon:GetConvertedAtkAttr()
		-- var_12_11 -> bulletTemplate
		local bulletTemplate = bullet:GetTemplate()
		-- var_12_12 -> bulletDamageType(对甲比例)
		local bulletDamageType = bulletTemplate.damage_type
		-- var_12_13 -> bulletRandomDamageRate
		local bulletRandomDamageRate = bulletTemplate.random_damage_rate
		-- var_12_14 -> targetAttr
		local targetAttr = target._attr
		-- var_12_15 -> damageRatioByAttr
		local damageRatioByAttr = meteoDamageRatio or num1

		damageReduceDistance = damageReduceDistance or num0

		-- var_12_16 -> targetArmorType
		local targetArmorType = targetAttr.armorType
		-- var_12_17 -> levelDiff
		local levelDiff = weaponHostAttr.formulaLevel - targetAttr.formulaLevel
		-- var_12_18 -> critDamage
		local critDamage = num1
		local var_12_19 = false
		-- var_12_20 -> isCri
		local isCri = false
		-- var_12_21 -> baseDamage
		local baseDamage = num1
		-- var_12_22 -> bulletCorrectedDMG
			-- 子弹的correctedDMG来自武器的correctedDMG
			-- 来自BattleFormulas.WeaponDamagePreCorrection()
			-- 武器标伤(damage) * 修正系数(corrected) * 武器效率(potential) / 100
			-- 因为武器效率一般也是三位数，为了方便，也是变成以1为基准的，所以除以100就消掉了
		local bulletCorrectedDMG = bullet:GetCorrectedDMG()
		-- var_12_23 -> bulletBaseDamage
			-- (1 + 攻击属性 * 属性效率 / 100) * 武器标伤 * 修正系数 * 武器效率
		local bulletBaseDamage = (num1 + bullet:GetWeaponAtkAttr() * weaponConvertedAtkAttr) * bulletCorrectedDMG

		if attackAttribute == BattleConst.WeaponDamageAttr.CANNON then
			damageRatioByAttr = num1 + BattleAttr.GetCurrent(target, "injureRatioByCannon") + BattleAttr.GetCurrent(bullet, "damageRatioByCannon")
		elseif attackAttribute == BattleConst.WeaponDamageAttr.TORPEDO then
			damageRatioByAttr = num1 + BattleAttr.GetCurrent(target, "injureRatioByBulletTorpedo") + BattleAttr.GetCurrent(bullet, "damageRatioByBulletTorpedo")
		elseif attackAttribute == BattleConst.WeaponDamageAttr.AIR then
			-- var_12_24 -> airResistPierce(防空减伤穿透，前提：airResistPierceActive为1，即处于隐匿状态下)
			local airResistPierce = BattleAttr.GetCurrent(bullet, "airResistPierceActive") == 1 and BattleAttr.GetCurrent(bullet, "airResistPierce") or 0

			-- dRate[7] = 150
			damageRatioByAttr = damageRatioByAttr * math.min(dRate[7] / (targetAttr.antiAirPower + dRate[7]) + airResistPierce, 1) * (num1 + BattleAttr.GetCurrent(target, "injureRatioByAir") + BattleAttr.GetCurrent(bullet, "damageRatioByAir"))
		elseif attackAttribute == BattleConst.WeaponDamageAttr.ANTI_AIR then
			-- block empty
		elseif attackAttribute == BattleConst.WeaponDamageAttr.ANIT_SUB then
			-- block empty
		end

		-- var_12_25 -> luckDiff
		local luckDiff = weaponHostAttr.luck - targetAttr.luck
		-- var_12_26 -> perfectDodge(该属性为1时，表示必定闪避，不进行命中判定)
		local perfectDodge = BattleAttr.GetCurrent(target, "perfectDodge")
		-- var_12_27 -> attackRating(命中值，最小为0)
		local attackRating = math.max(weaponHostAttr.attackRating, 0)
		-- var_12_28 -> isMiss
		local isMiss

		if perfectDodge >= 1 then
			isMiss = true
		else
			-- var_12_29 -> baseAccuracyRate(基础命中率)
				-- accuracyConst[1] = 0.1, accuracyConst[2] = 2
			local baseAccuracyRate = accuracyConst[1] + attackRating / (attackRating + targetAttr.dodgeRate + accuracyConst[2]) + (luckDiff + levelDiff) * bfConsts.PERCENT1
			-- var_12_30 -> accuracyRateExtra
			local accuracyRateExtra = BattleAttr.GetCurrent(bullet, "accuracyRateExtra")
			-- var_12_31 -> shipTypeAccuracyEnhance
			local shipTypeAccuracyEnhance = BattleAttr.GetCurrent(bullet, shipTypeAccuracyEnhance[target:GetTemplate().type])
			-- var_12_32 -> dodgeRateExtra
			local dodgeRateExtra = BattleAttr.GetCurrent(target, "dodgeRateExtra")
			-- var_12_33 -> finalAccuracyRate
				-- dRate[5] = 0.1
				-- 说明命中率最小为10%，最大为100%
			local finalAccuracyRate = math.max(dRate[5], math.min(num1, baseAccuracyRate + accuracyRateExtra + shipTypeAccuracyEnhance - dodgeRateExtra))

			isMiss = not BattleFormulas.IsHappen(finalAccuracyRate * num10000)
		end

		-- 若命中
		if not isMiss then
			-- var_12_34这个值没用过，可能程序员忘记删掉了
			-- 这里我们直接删掉这个变量的定义
			-- var_12_35 -> critRate
				-- GCT表示必定暴击(Guaranteed Crit)字段，如果为1则表示必定暴击, 不用进行后续暴击率计算
				-- bfConst.DFT_CRIT_RATE = 0.05
				-- dRate[4] = 2000
				-- dRate[3] = 0.0002
			local critRate = BattleAttr.GetCurrent(bullet, "GCT") == 1 and 1 or bfConsts.DFT_CRIT_RATE + attackRating / (attackRating + targetAttr.dodgeRate + dRate[4]) + (luckDiff + levelDiff) * dRate[3] + BattleAttr.GetCurrent(bullet, "cri") + BattleAttr.GetTagAttrCri(bullet, target)

			-- RANDOM_DAMAGE_MIN = 0, RANDOM_DAMAGE_MAX = 2
			baseDamage = math.random(BattleConfig.RANDOM_DAMAGE_MIN, BattleConfig.RANDOM_DAMAGE_MAX) + bulletBaseDamage

			if BattleFormulas.IsHappen(critRate * num10000) then
				isCri = true

				-- var_12_36 -> baseCritDamage
					-- bfConsts.DFT_CRIT_EFFECT = 1.5
				local baseCritDamage = bfConsts.DFT_CRIT_EFFECT + BattleAttr.GetTagAttrCriDmg(bullet, target) + BattleAttr.GetCurrent(bullet, "criDamage") - BattleAttr.GetCurrent(target, "criDamageResist")

				critDamage = math.max(1, baseCritDamage)
			else
				isCri = false
			end
		else
			-- 如果未命中，直接结算
			baseDamage = num0

			-- var_12_37 -> extraInfo
			local extraInfo = {
				isMiss = true,
				isDamagePrevent = false,
				isCri = isCri
			}

			return baseDamage, extraInfo
		end

		-- var_12_38 -> baseRatio(=1)
		local baseRatio = bfConsts.NUM1
		-- var_12_39 -> damageRatioBullet(子弹伤害倍率)
		local damageRatioBullet = BattleAttr.GetCurrent(bullet, "damageRatioBullet")
		-- var_12_40 -> damageRatioTag(标签伤害倍率)
		local damageRatioTag = BattleAttr.GetTagAttr(bullet, target, isWorld)
		-- var_12_41 -> injureRatio(目标受伤倍率)
		local injureRatio = BattleAttr.GetCurrent(target, "injureRatio")
		-- var_12_42 -> damageAmmoToArmorRate(弹药对甲倍率)
			-- 这里是子弹的基础对甲效率 + (子弹)获得的对甲效率加成
		local damageAmmoToArmorRate = (weapon:GetFixAmmo() or bulletDamageType[targetArmorType] or baseRatio) + BattleAttr.GetCurrent(bullet, BattleConfig.DAMAGE_AMMO_TO_ARMOR_RATE_ENHANCE[targetArmorType])
		-- var_12_43 -> damageToArmorRateEnhance(子弹对甲倍率增加)
			-- 注意子弹对甲倍率与弹药对甲倍率区别。子弹(Bullet)和弹药(Ammo)是两个不同的概念，一般来说，Ammo是Bullet的一个属性
		local damageToArmorRateEnhance = BattleAttr.GetCurrent(bullet, BattleConfig.DAMAGE_TO_ARMOR_RATE_ENHANCE[targetArmorType])
		-- var_12_44 -> ammoDamageEnhance(弹药伤害倍率增加)
			-- 判定依据是子弹的弹药类型(ammo_type)
		local ammoDamageEnhance = BattleAttr.GetCurrent(bullet, ammoDamageEnhance[bulletTemplate.ammo_type])
		-- var_12_45 -> targetAmmoDamageReduce(目标弹药伤害减免)
		local targetAmmoDamageReduce = BattleAttr.GetCurrent(target, ammoDamageReduce[bulletTemplate.ammo_type])
		-- var_12_46 -> comboTag(连击标签)
			-- 表示的是子弹连续命中了某个目标后，所触发的连击标签
		local comboTag = BattleAttr.GetCurrent(bullet, "comboTag")
		-- var_12_47 -> damageRatioComboTag(连击标签伤害倍率)
		local damageRatioComboTag = BattleAttr.GetCurrent(target, comboTag)
		-- var_12_48 -> finalDamageBase
			-- dRate[1] = 25, dRate[2] = 0.02
		local finalDamageBase = math.max(baseRatio, math.floor(baseDamage * damageRatioByAttr * (baseRatio - damageReduceDistance) * damageAmmoToArmorRate * (baseRatio + damageToArmorRateEnhance) * critDamage * (baseRatio + damageRatioBullet) * damageRatioTag * (baseRatio + injureRatio) * (baseRatio + ammoDamageEnhance - targetAmmoDamageReduce) * (baseRatio + damageRatioComboTag) * (baseRatio + math.min(dRate[1], math.max(-dRate[1], levelDiff)) * dRate[2])))

		if target:GetCurrentOxyState() == BattleConst.OXY_STATE.DIVE then
			finalDamageBase = math.floor(finalDamageBase * bulletTemplate.antisub_enhancement)
		end

		-- var_12_49 -> extraInfo
		local extraInfo = {
			isMiss = isMiss,
			isCri = isCri,
			damageAttr = attackAttribute
		}

		-- var_12_50 -> damageEnhance
			-- 包括手动开炮时的第一底座增伤和首轮增伤等
		local damageEnhance = bullet:GetDamageEnhance()

		if damageEnhance ~= 1 then
			finalDamageBase = math.floor(finalDamageBase * damageEnhance)
		end

		-- var_12_51 -> finalDamageAfterRepress
			-- targetAttr.repressReduce表示海域压制减伤
		local finalDamageAfterRepress = finalDamageBase * targetAttr.repressReduce

		if bulletRandomDamageRate ~= 0 then
			finalDamageAfterRepress = finalDamageAfterRepress * (Mathf.RandomFloat(bulletRandomDamageRate) + 1)
		end

		-- var_12_52 -> damageEnhanceProjectile
		local damageEnhanceProjectile = BattleAttr.GetCurrent(bullet, "damageEnhanceProjectile")
		-- var_12_53 -> finalDamageBeforeFloor
		local finalDamageBeforeFloor = math.max(0, finalDamageAfterRepress + damageEnhanceProjectile)

		if isWorld then
			finalDamageBeforeFloor = finalDamageBeforeFloor * (bfConsts.NUM1 + BattleAttr.GetCurrent(bullet, "worldBuffResistance"))
		end

		-- var_12_54 -> finalDamage
		local finalDamage = math.floor(finalDamageBeforeFloor)
		-- var_12_55 -> damageFont
		local damageFont = bulletTemplate.DMG_font[targetArmorType]

		if damageEnhanceProjectile < 0 then
			damageFont = BattleConfig.BULLET_DECREASE_DMG_FONT
		end

		return finalDamage, extraInfo, damageFont
	end
end

-- arg_13_0 -> bullet? caster? orb?
	-- 从调用来看传入的是_orb
	-- BattleBulletUnit有GetWeapon()方法，但没有_attr
	-- 一般来说BattleUnit有_attr
	-- 待后续研究
-- arg_13_1 -> igniteAttribute
-- arg_13_2 -> igniteCoefficient
function BattleFormulas.CalculateIgniteDamage(orb, igniteAttribute, igniteCoefficient)
	-- var_13_0 -> attrs
	local attrs = orb._attr

	return orb:GetWeapon():GetCorrectedDMG() * (1 + attrs[igniteAttribute] * bfConsts.PERCENT) * igniteCoefficient
end

-- arg_14_0 -> weapon(BattleWeaponUnit)
-- arg_14_1 -> overrideDamage
function BattleFormulas.WeaponDamagePreCorrection(weapon, overrideDamage)
	-- var_14_0 -> weaponTemplate
	-- var_14_1 -> baseDamage
	-- var_14_2 -> corrected
	local weaponTemplate = weapon:GetTemplateData()
	local baseDamage = overrideDamage or weaponTemplate.damage
	local corrected = weaponTemplate.corrected

	return baseDamage * weapon:GetPotential() * corrected * bfConsts.PERCENT
end

-- arg_15_0 -> weapon(BattleWeaponUnit)
function BattleFormulas.WeaponAtkAttrPreRatio(weapon)
	return weapon:GetTemplateData().attack_attribute_ratio * bfConsts.PERCENT2
end

-- arg_16_0 -> numMeteos
function BattleFormulas.GetMeteoDamageRatio(numMeteos)
	-- var_16_0 -> meteoDamageRatios
	local meteoDamageRatios = {}
	-- var_16_1 -> meteoRate
	local meteoRate = bfConsts.METEO_RATE
	-- var_16_2 -> baseMeteoRatio(=0.05)
		-- 表示每架飞机受到的基础伤害分配比例
	local baseMeteoRatio = meteoRate[1]

	-- meteoRate[2] = 20
	if numMeteos >= meteoRate[2] then
		-- iter_16_0 -> i
		for i = 1, numMeteos + 1 do
			meteoDamageRatios[i] = baseMeteoRatio
		end

		return meteoDamageRatios
	else
		-- var_16_3 -> restMeteoRatio
			-- 剩余的可分配伤害比例
		local restMeteoRatio = 1 - baseMeteoRatio * numMeteos

		-- iter_16_1 -> i
		for i = 1, numMeteos do
			-- var_16_4 -> randomMeteoRatio
			-- meteoRate[3] = 0.6
			-- meteoRate[4] = 0.4
			local randomMeteoRatio = math.random() * restMeteoRatio * (meteoRate[3] + meteoRate[4] * (i - 1) / numMeteos)

			meteoDamageRatios[i] = randomMeteoRatio + baseMeteoRatio
			restMeteoRatio = math.max(0, restMeteoRatio - randomMeteoRatio)
		end

		meteoDamageRatios[numMeteos + 1] = restMeteoRatio

		return meteoDamageRatios
	end
end

-- arg_17_0 -> fleetAntiAirUnit(BattleFleetAntiAirUnit)
-- 计算防空炮伤害
function BattleFormulas.CalculateFleetAntiAirTotalDamage(fleetAntiAirUnit)
	-- var_17_0 -> crewUnitList
	-- var_17_1 -> totalDamage
	local crewUnitList = fleetAntiAirUnit:GetCrewUnitList()
	local totalDamage = 0

	-- iter_17_0 -> crewUnit
	-- iter_17_1 -> weaponList
	for crewUnit, weaponList in pairs(crewUnitList) do
		-- var_17_2 -> antiAirPower
		local antiAirPower = BattleAttr.GetCurrent(crewUnit, "antiAirPower")

		-- iter_17_2 -> _
		-- iter_17_3 -> weapon
		for _, weapon in ipairs(weaponList) do
			-- var_17_3 -> weaponConvertedAtkAttr
			-- var_17_4 -> weaponCorrectedDMG
			local weaponConvertedAtkAttr = weapon:GetConvertedAtkAttr()
			local weaponCorrectedDMG = weapon:GetCorrectedDMG()

			totalDamage = totalDamage + math.max(1, (antiAirPower * weaponConvertedAtkAttr + 1) * weaponCorrectedDMG)
		end
	end

	return totalDamage
end

-- arg_18_0 -> repeater(BattleRepeaterAntiAirUnit)
	-- BattleRepeaterAntiAirUnit继承自BattleWeaponUnit
	-- 计算敌方防空舰放出的飞机的伤害
function BattleFormulas.CalculateRepaterAnitiAirTotalDamage(repeater)
	-- var_18_0 -> host(BattleUnit)
	-- var_18_1 -> repeaterConvertedAtkAttr
	-- var_18_2 -> repeaterCorrectedDMG
	-- var_18_3 -> hostAntiAirPower
	local host = repeater:GetHost()
	local repeaterConvertedAtkAttr = repeater:GetConvertedAtkAttr()
	local repeaterCorrectedDMG = repeater:GetCorrectedDMG()
	local hostAntiAirPower = BattleAttr.GetCurrent(host, "antiAirPower")

	return (math.max(1, (hostAntiAirPower * repeaterConvertedAtkAttr + 1) * repeaterCorrectedDMG))
end

-- arg_19_0 -> repeater(BattleRepeaterAntiAirUnit)
-- arg_19_1 -> target(大概是BattleAircraftUnit?)
	-- 计算己方舰载机的回避情况
function BattleFormulas.RollRepeaterHitDice(repeater, target)
	-- var_19_0 -> host
	-- var_19_1 -> hostAntiAirPower
	-- var_19_2 -> hostAttackRating
	-- var_19_3 -> targetAirPower
	-- var_19_4 -> targetDodgeLimit
	-- var_19_5 -> targetDodge
	local host = repeater:GetHost()
	local hostAntiAirPower = BattleAttr.GetCurrent(host, "antiAirPower")
	local hostAttackRating = math.max(BattleAttr.GetCurrent(host, "attackRating"), 0)
	local targetAirPower = BattleAttr.GetCurrent(target, "airPower")
	local targetDodgeLimit = BattleAttr.GetCurrent(target, "dodgeLimit")
	local targetDodge = BattleAttr.GetCurrent(target, "dodge")
	-- var_19_6 -> airPowerFactor
		-- AnitAirRepeaterConfig.const_A = 32
		-- AnitAirRepeaterConfig.const_B = 12
	-- var_19_7 -> aircraftDodgeRateBeforeLimit
		-- AnitAirRepeaterConfig.const_C = 220
	local airPowerFactor = targetAirPower / AnitAirRepeaterConfig.const_A + AnitAirRepeaterConfig.const_B
	local aircraftDodgeRateBeforeLimit = airPowerFactor / (hostAntiAirPower * targetDodge + airPowerFactor + AnitAirRepeaterConfig.const_C)
	-- var_19_8 -> aircraftDodgeRate
	local aircraftDodgeRate = math.min(targetDodgeLimit, aircraftDodgeRateBeforeLimit)

	return BattleFormulas.IsHappen(aircraftDodgeRate * bfConsts.NUM10000)
end

-- arg_20_0 -> antiAirPower
	-- = 防空值的平方
	-- 不太清楚这个防空权重的用处...
function BattleFormulas.AntiAirPowerWeight(antiAirPower)
	return antiAirPower * antiAirPower
end

-- arg_21_0 -> attacker(BattleAircraftUnit)
-- arg_21_1 -> target(BattleUnit)
	-- 用于计算敌方飞机触底时对我方主力舰的伤害
function BattleFormulas.CalculateDamageFromAircraftToMainShip(attacker, target)
	-- var_21_0 -> attackerAirPower
	-- var_21_1 -> targetAntiAirPower
	-- var_21_2 -> attackerCrashDMG
	-- var_21_3 -> attackerHPRate
	-- var_21_4 -> attackerFormulaLevel
	-- var_21_5 -> targetFormulaLevel
	-- var_21_6 -> targetInjureRatio
	-- var_21_7 -> targetInjureRatioByAir
	-- var_21_8 -> planeLeakRate
	local attackerAirPower = BattleAttr.GetCurrent(attacker, "airPower")
	local targetAntiAirPower = BattleAttr.GetCurrent(target, "antiAirPower")
	local attackerCrashDMG = BattleAttr.GetCurrent(attacker, "crashDMG")
	local attackerHPRate = attacker:GetHPRate()
	local attackerFormulaLevel = BattleAttr.GetCurrent(attacker, "formulaLevel")
	local targetFormulaLevel = BattleAttr.GetCurrent(target, "formulaLevel")
	local targetInjureRatio = BattleAttr.GetCurrent(target, "injureRatio")
	local targetInjureRatioByAir = BattleAttr.GetCurrent(target, "injureRatioByAir")
	local planeLeakRate = bfConsts.PLANE_LEAK_RATE
	-- var_21_9 -> damage
		-- planeLeakRate[1] = 1
		-- planeLeakRate[2] = 1
		-- planeLeakRate[3] = 0.01
		-- planeLeakRate[4] = 0.5
		-- planeLeakRate[5] = 0.7
		-- planeLeakRate[6] = 0.3
		-- planeLeakRate[7] = 1
		-- planeLeakRate[8] = 0.005
		-- planeLeakRate[9] = 150
		-- planeLeakRate[10] = 150
		-- planeLeakRate[11] = 1
		-- planeLeakRate[12] = 1
	local damage = math.max(planeLeakRate[1], math.floor((attackerCrashDMG * (planeLeakRate[2] + attackerAirPower * planeLeakRate[3]) + attackerFormulaLevel * planeLeakRate[4]) * (attackerHPRate * planeLeakRate[5] + planeLeakRate[6]) * (planeLeakRate[7] + (attackerFormulaLevel - targetFormulaLevel) * planeLeakRate[8]) * (planeLeakRate[9] / (targetAntiAirPower + planeLeakRate[10])) * (planeLeakRate[11] + targetInjureRatio) * (planeLeakRate[12] + targetInjureRatioByAir)))

	return (math.floor(damage * BattleAttr.GetCurrent(target, "repressReduce")))
end


-- arg_22_0 -> attacker(BattleUnit)
-- arg_22_1 -> target(BattleUnit)
	-- 用于计算敌方自爆船触底时对我方主力舰的伤害
function BattleFormulas.CalculateDamageFromShipToMainShip(attacker, target)
	-- var_22_0 -> attackerCannonPower
	-- var_22_1 -> attackerTorpedoPower
	-- var_22_2 -> attackerHPRate
	-- var_22_3 -> attackerFormulaLevel
	-- var_22_4 -> targetFormulaLevel
	-- var_22_5 -> targetInjureRatio
	-- var_22_6 -> leakRate
	-- var_22_7 -> damage
	local attackerCannonPower = BattleAttr.GetCurrent(attacker, "cannonPower")
	local attackerTorpedoPower = BattleAttr.GetCurrent(attacker, "torpedoPower")
	local attackerHPRate = attacker:GetHPRate()
	local attackerFormulaLevel = BattleAttr.GetCurrent(attacker, "formulaLevel")
	local targetFormulaLevel = BattleAttr.GetCurrent(target, "formulaLevel")
	local targetInjureRatio = BattleAttr.GetCurrent(target, "injureRatio")
	local leakRate = bfConsts.LEAK_RATE
	-- leakRate[1] = 10
	-- leakRate[2] = 2.2
	-- leakRate[3] = 0.7
	-- leakRate[4] = 0.3
	-- leakRate[5] = 1
	-- leakRate[6] = 0.005
	-- leakRate[7] = 0.5
	local damage = math.max(leakRate[1], math.floor(((attackerCannonPower + attackerTorpedoPower) * leakRate[2] + attackerFormulaLevel * leakRate[7]) * (leakRate[5] + targetInjureRatio) * (attackerHPRate * leakRate[3] + leakRate[4]) * (leakRate[5] + (attackerFormulaLevel - targetFormulaLevel) * leakRate[6])))

	return (math.floor(damage * BattleAttr.GetCurrent(target, "repressReduce")))
end

-- arg_23_0 -> attacker(BattleUnit)
-- arg_23_1 -> target(BattleUnit)
	-- 用于计算敌方潜艇触底时对我方主力舰的伤害
function BattleFormulas.CalculateDamageFromSubmarinToMainShip(attacker, target)
	-- var_23_0 -> attackerTorpedoPower
	-- var_23_1 -> attackerHPRate
	-- var_23_2 -> attackerFormulaLevel
	-- var_23_3 -> targetFormulaLevel
	-- var_23_4 -> targetInjureRatio
	-- var_23_5 -> submarineKamikazeParams
	local attackerTorpedoPower = BattleAttr.GetCurrent(attacker, "torpedoPower")
	local attackerHPRate = attacker:GetHPRate()
	local attackerFormulaLevel = BattleAttr.GetCurrent(attacker, "formulaLevel")
	local targetFormulaLevel = BattleAttr.GetCurrent(target, "formulaLevel")
	local targetInjureRatio = BattleAttr.GetCurrent(target, "injureRatio")
	local submarineKamikazeParams = bfConsts.SUBMARINE_KAMIKAZE

	-- submarineKamikazeParams[1] = 80
	-- submarineKamikazeParams[2] = 3.5
	-- submarineKamikazeParams[3] = 1.5
	-- submarineKamikazeParams[4] = 1
	-- submarineKamikazeParams[5] = 0.5
	-- submarineKamikazeParams[6] = 0.5
	-- submarineKamikazeParams[7] = 1
	-- submarineKamikazeParams[8] = 0.005
	return (math.max(submarineKamikazeParams[1], math.floor((attackerTorpedoPower * submarineKamikazeParams[2] + attackerFormulaLevel * submarineKamikazeParams[3]) * (submarineKamikazeParams[4] + targetInjureRatio) * (attackerHPRate * submarineKamikazeParams[5] + submarineKamikazeParams[6]) * (submarineKamikazeParams[7] + (attackerFormulaLevel - targetFormulaLevel) * submarineKamikazeParams[8]))))
end

-- arg_24_0 -> target(BattleUnit)
	-- 用于判定敌方潜艇自爆时我方主力舰是否闪避伤害
function BattleFormulas.RollSubmarineDualDice(target)
	-- var_24_0 -> targetDodgeRate
	-- var_24_1 -> targetDodgeProbability
		-- MONSTER_SUB_KAMIKAZE_DUAL_K = 50
		-- MONSTER_SUB_KAMIKAZE_DUAL_P = 0.15
	local targetDodgeRate = BattleAttr.GetCurrent(target, "dodgeRate")
	local targetDodgeProbability = targetDodgeRate / (targetDodgeRate + BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_K) * BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_P

	return BattleFormulas.IsHappen(targetDodgeProbability * bfConsts.NUM10000)
end

-- arg_25_0 -> ship1
-- arg_25_1 -> ship2
	-- 计算碰撞伤害，敌我双方受到同样的伤害
function BattleFormulas.CalculateCrashDamage(ship1, ship2)
	-- var_25_0 -> ship1MaxHP
	-- var_25_1 -> ship2MaxHP
	local ship1MaxHP = BattleAttr.GetCurrent(ship1, "maxHP")
	local ship2MaxHP = BattleAttr.GetCurrent(ship2, "maxHP")
	-- var_25_2 -> ship1CrashBaseDMG(CRASH_RATE[1] = 0.05)
	-- var_25_3 -> ship2CrashBaseDMG
	local ship1CrashBaseDMG = ship1MaxHP * bfConsts.CRASH_RATE[1]
	local ship2CrashBaseDMG = ship2MaxHP * bfConsts.CRASH_RATE[1]
	-- var_25_4 -> ship1HammerDamageRatio
	-- var_25_5 -> ship2HammerDamageRatio
	local ship1HammerDamageRatio = BattleAttr.GetCurrent(ship1, "hammerDamageRatio")
	local ship2HammerDamageRatio = BattleAttr.GetCurrent(ship2, "hammerDamageRatio")
	-- var_25_6 -> ship1HammerDamagePrevent
	-- var_25_7 -> ship2HammerDamagePrevent
	local ship1HammerDamagePrevent = BattleAttr.GetCurrent(ship1, "hammerDamagePrevent")
	local ship2HammerDamagePrevent = BattleAttr.GetCurrent(ship2, "hammerDamagePrevent")
	-- var_25_8 -> ship1FinalHammerDamagePrevent(PreventUpperBound = 0.8)
	-- var_25_9 -> ship2FinalHammerDamagePrevent
	local ship1FinalHammerDamagePrevent = math.min(ship1HammerDamagePrevent, BattleConfig.HammerCFG.PreventUpperBound)
	local ship2FinalHammerDamagePrevent = math.min(ship2HammerDamagePrevent, BattleConfig.HammerCFG.PreventUpperBound)
	-- var_25_10 -> crashDMGUpperBound(CRASH_RATE[2] = 0.025)
	local crashDMGUpperBound = math.sqrt(ship1MaxHP * ship2MaxHP) * bfConsts.CRASH_RATE[2]
	-- var_25_11 -> ship1FinalCrashBaseDMG
	-- var_25_12 -> ship2FinalCrashBaseDMG
	local ship1FinalCrashBaseDMG = math.min(ship1CrashBaseDMG, crashDMGUpperBound)
	local ship2FinalCrashBaseDMG = math.min(ship2CrashBaseDMG, crashDMGUpperBound)
	-- var_25_13 -> ship1FinalCrashDMGBeforeRepress
	-- var_25_14 -> ship1FinalCrashDMG
	local ship1FinalCrashDMGBeforeRepress = math.floor(ship1FinalCrashBaseDMG * (1 + ship2HammerDamageRatio) * (1 - ship1FinalHammerDamagePrevent))
	local ship1FinalCrashDMG = math.floor(ship1FinalCrashDMGBeforeRepress * BattleAttr.GetCurrent(ship1, "repressReduce"))
	-- var_25_15 -> ship2FinalCrashDMGBeforeRepress
	-- var_25_16 -> ship2FinalCrashDMG
	local ship2FinalCrashDMGBeforeRepress = math.floor(ship2FinalCrashBaseDMG * (1 + ship1HammerDamageRatio) * (1 - ship2FinalHammerDamagePrevent))
	local ship2FinalCrashDMG = math.floor(ship2FinalCrashDMGBeforeRepress * BattleAttr.GetCurrent(ship2, "repressReduce"))

	return ship1FinalCrashDMG, ship2FinalCrashDMG
end

-- arg_26_0 -> damage
	-- 暂时不知道拿来干什么
function BattleFormulas.CalculateFleetDamage(damage)
	-- SCORE_RATE[1] = 0.7
	return damage * bfConsts.SCORE_RATE[1]
end

-- arg_27_0 -> fleet(BattleFleetVO)
-- arg_27_1 -> ship(BattleUnit)
	-- 暂时不知道拿来干什么
function BattleFormulas.CalculateFleetOverDamage(fleet, ship)
	if ship == fleet:GetFlagShip() then
		-- SCORE_RATE[2] = 0.8(加上SCORE_RATE[1]一共是1.5. 这个数值可以对应到GetFleetTotalHP中的1.5倍旗舰血量?)
		return BattleAttr.GetCurrent(ship, "maxHP") * bfConsts.SCORE_RATE[2]
	else
		-- SCORE_RATE[3] = 0.3(加上SCORE_RATE[1]一共是1.0)
		return BattleAttr.GetCurrent(ship, "maxHP") * bfConsts.SCORE_RATE[3]
	end
end

-- arg_28_0 -> reloadMax
-- arg_28_1 -> loadSpeed
	-- 根据Weapon的reloadMax和单位的loadSpeed计算实际的装填时间(单位:秒)
function BattleFormulas.CalculateReloadTime(reloadMax, loadSpeed)
	-- BattleConfig.K1 = 6
	-- BattleConfig.K2 = 100
	-- BattleConfig.K3 = 3.14
	-- 装填时间 = reloadMax / (6 * sqrt((loadSpeed + 100) * 3.14))
		-- 因此可以定义为装填速度 = 6 * sqrt((loadSpeed + 100) * 3.14)
		-- 容易看出装填速度与根号下(loadSpeed+100)成正比, 与reloadMax成反比
	return reloadMax / BattleConfig.K1 / math.sqrt((loadSpeed + BattleConfig.K2) * BattleConfig.K3)
end

-- arg_29_0 -> reloadedTime
-- arg_29_1 -> loadSpeed
	-- 根据实际的装填时间和单位的loadSpeed计算已经装填的进度
function BattleFormulas.CaclulateReloaded(reloadedTime, loadSpeed)
	return math.sqrt((loadSpeed + BattleConfig.K2) * BattleConfig.K3) * reloadedTime * BattleConfig.K1
end

-- arg_30_0 -> reloadMax
-- arg_30_1 -> reloadRequire(目标装填时间)
	-- 根据Weapon的reloadMax和目标装填时间计算需要的loadSpeed
function BattleFormulas.CaclulateReloadAttr(reloadMax, reloadRequire)
	-- var_30_0 -> requireReloadSpeed
		-- 因为游戏中loadSpeed用来指的是装填值，为了避免混淆，这里就另用reloadSpeed表示"装填速度"
	local reloadSpeed = reloadMax / BattleConfig.K1 / reloadRequire

	return math.max(reloadSpeed * reloadSpeed / BattleConfig.K3 - BattleConfig.K2, 0)
end

-- arg_31_0 -> hiveList
	-- 计算一组空袭支援飞机的"平均"装填时间
	-- 算法是计算所有飞机的reloadMax的平均值，然后乘以一个系数(2.2)
function BattleFormulas.CaclulateAirAssistReloadMax(hiveList)
	-- var_31_0 -> totalReloadMax
	local totalReloadMax = 0

	-- iter_31_0 -> _
	-- iter_31_1 -> hive(BattleHiveUnit?)
	for _, hive in ipairs(hiveList) do
		totalReloadMax = totalReloadMax + hive:GetTemplateData().reload_max
	end

	return totalReloadMax / #hiveList * airAssistReloadFactor
end

-- arg_32_0 -> rant
-- arg_32_1 -> buffDOTeffect
-- arg_32_2 -> orb
-- arg_32_3 -> target
	-- 计算DOT效果是否命中/触发
function BattleFormulas.CaclulateDOTPlace(rant, buffDOTeffect, orb, target)
	-- var_32_0 -> buffDOTargList
	local buffDOTargList = buffDOTeffect.arg_list

	-- 是否是只能在带有特定标签的目标身上触发?
	if buffDOTargList.tagOnly and not target:ContainsLabelTag(buffDOTargList.tagOnly) then
		return false
	end

	-- var_32_1 -> dotConfigOfType
	local dotConfigOfType = BattleConfig.DOT_CONFIG[buffDOTargList.dotType]
	-- var_32_2 -> dotAccuracy
	local dotAccuracy = orb and orb:GetAttrByName(dotConfigOfType.hit) or bfConsts.NUM0
	-- var_32_3 -> targetDotResist
	local targetDotResist = target and target:GetAttrByName(dotConfigOfType.resist) or bfConsts.NUM0

	return BattleFormulas.IsHappen(rant * (bfConsts.NUM1 + dotAccuracy) * (bfConsts.NUM1 - targetDotResist))
end

-- arg_33_0 -> buffDOTeffect
-- arg_33_1 -> orb
-- arg_33_2 -> target
	-- 计算DOT效果的持续时间
function BattleFormulas.CaclulateDOTDuration(buffDOTeffect, orb, target)
	-- var_33_0 -> buffDOTargList
	-- var_33_1 -> dotConfigOfType
	local buffDOTargList = buffDOTeffect.arg_list
	local otConfigOfType = BattleConfig.DOT_CONFIG[buffDOTargList.dotType]

	return (orb and orb:GetAttrByName(otConfigOfType.prolong) or bfConsts.NUM0) - (target and target:GetAttrByName(otConfigOfType.shorten) or bfConsts.NUM0)
end

-- arg_34_0 -> buffDOTeffect
-- arg_34_1 -> orb
-- arg_34_2 -> target
	-- 计算DOT效果的伤害增加(或减少)倍率
function BattleFormulas.CaclulateDOTDamageEnhanceRate(buffDOTeffect, orb, target)
	-- var_34_0 -> buffDOTargList
	-- var_34_1 -> dotConfigOfType
	local buffDOTargList = buffDOTeffect.arg_list
	local dotConfigOfType = BattleConfig.DOT_CONFIG[buffDOTargList.dotType]

	return ((orb and orb:GetAttrByName(dotConfigOfType.enhance) or bfConsts.NUM0) - (target and target:GetAttrByName(dotConfigOfType.reduce) or bfConsts.NUM0)) * bfConsts.PERCENT2
end

-- arg_35_0 -> bossConfigId
-- arg_35_1 -> bossLevel
	-- 计算META作战时，支援攻击的伤害值
function BattleFormulas.CaclulateMetaDotaDamage(bossConfigId, bossLevel)
	-- var_35_0 -> metaBossTemplate(参考world_joint_boss_template.lua)
	local metaBossTemplate = ys.Battle.BattleDataFunction.GetMetaBossTemplate(bossConfigId)

	-- 表示这个META BOSS过期或常驻了
	if type(metaBossTemplate.state) == "string" then
		return 0
	end

	-- var_35_1 -> metaBossState
	local metaBossState = metaBossTemplate.state
	-- var_35_2 -> startTime
	local startTime = os.time({
		year = metaBossState[1][1][1],
		month = metaBossState[1][1][2],
		day = metaBossState[1][1][3],
		hour = metaBossState[1][2][1],
		minute = metaBossState[1][2][2],
		second = metaBossState[1][2][3]
	})
	-- var_35_3 -> endTime
	local endTime = os.time({
		year = metaBossState[2][1][1],
		month = metaBossState[2][1][2],
		day = metaBossState[2][1][3],
		hour = metaBossState[2][2][1],
		minute = metaBossState[2][2][2],
		second = metaBossState[2][2][3]
	})
	-- var_35_4 -> totalDurationSeconds
	-- var_35_5 -> totalDurationDays
		-- 这个天数是向下取整的，因此即使23小时59分钟59秒也算作0天
		-- 例如，夕立META从2025年9月4日0.0.0开始，到2025年12月11日23.59.59结束
		-- 总时长为98天23小时59分钟59秒，但totalDurationDays为98天
	-- var_35_6 -> elapsedDays
		-- 同理向下取整
	local totalDurationSeconds = os.difftime(endTime, startTime)
	local totalDurationDays = math.floor(totalDurationSeconds / 86400)
	local elapsedDays = math.floor(os.difftime(pg.TimeMgr.GetInstance():GetServerTime(), startTime) / 86400)
	-- var_35_7 -> metaSupportAttackArgs
	local metaSupportAttackArgs = pg.gameset.world_metaboss_supportattack.description
	-- var_35_8 -> daysSupportStarts (= 31)
	-- var_35_9 -> daysSupportDamageMax( = totalDurationDays - 15)
		-- 这两个参数的意义是从计算公式推出来的
		-- 也即META支援在作战开启31天后开始生效，到离结束前16天支援伤害达到最大值
	local daysSupportStarts = metaSupportAttackArgs[1]
	local daysSupportDamageMax = totalDurationDays - metaSupportAttackArgs[2]
	-- var_35_10 -> expectDamageRatio( = 0.15)
		-- 表示支援攻击的期望总伤害占BOSS总血量的比例，这个参数的意义也是从计算公式推出来的
	-- var_35_11 -> randDamageRatio( = 0.04)
	-- var_35_12 -> dotHits( = 15)
	local expectDamageRatio = metaSupportAttackArgs[3]
	local randDamageRatio = metaSupportAttackArgs[4]
		-- 从后面看出来，这个值表示随机伤害的浮动范围为4%
	local dotHits = metaSupportAttackArgs[5]
	-- var_35_13 -> bossHP
	local bossHP = ys.Battle.BattleDataFunction.GetMetaBossLevelTemplate(bossConfigId, bossLevel).hp
	-- var_35_14 -> metaDOTdamageBase
		-- = floor(bossHP * 0.15 / 15 / (1 + 0.5 * 0.04) / (daysSupportDamageMax - 31) * min(elapsedDays - 31 + 1, daysSupportDamageMax - 31))
		-- 化简一下，为floor(bossHP * 0.01 / 1.02 / (totalDurationDays - 46) * min(elapsedDays - 30, totalDurationDays - 46))
		-- 我们取totalDurationDays = 98天, bossHP = 1540000为例（夕立META）
		-- 在第31天开始有伤害，伤害比例为 0.01 / 1.02 / 52 = 0.0189%，伤害值为290
		-- 在第82天伤害达到最大值，伤害比例为 0.01 / 1.02 / 52 * 52 = 0.980% ，伤害值为15098
	local metaDOTdamageBase = math.floor(bossHP * expectDamageRatio / dotHits / (1 + 0.5 * randDamageRatio) / (daysSupportDamageMax - daysSupportStarts) * math.min(elapsedDays - daysSupportStarts + 1, daysSupportDamageMax - daysSupportStarts))

	-- 这里随机值为[0, floor(0.04 * metaDOTdamageBase)]
	-- 也即最终伤害在[metaDOTdamageBase, metaDOTdamageBase * 1.04]之间浮动
	-- 承接上面那个例子：
		-- 第31天伤害在290~301之间浮动
		-- 第82天及之后伤害在15098~15701之间浮动
	-- 上面的1.02对应的是期望值，因此计算期望的话：
		-- 第31天的伤害比例为0.01 / 1.02 / 52 * 1.02 = 0.0192%, 伤害值为296; 
		-- 第82天及之后伤害比例为0.01 / 1.02 / 52 * 52 * 1.02 = 1.0%, 伤害值为15400(因取整有偏差)

	-- 以上计算的均为单次DOT伤害，查看Buff 8832就能了解到:
		-- 在计时器经过16s后触发，经过1.3s延迟后：
		-- Buff 8834: 持续1.7s, 每0.16s造成一次伤害, 共10次
		-- Buff 8835: 持续16s，每3s造成一次伤害, 共5次
		-- 因此总伤害需要乘以15，承接上述例子则第31天总伤害在4350~4515之间浮动，期望4440，第82天及之后总伤害在226470~235515之间浮动，期望231000
			-- 如果换算成BOSS总血量的百分比，则分别是0.282%~0.293%，期望0.288%和14.71%~15.29%，期望15.0%(从这里就能看出是特意设计的)
			-- 注意随机数是每次DOT单独计算的
	return metaDOTdamageBase + math.random(math.floor(randDamageRatio * metaDOTdamageBase))
end

-- arg_36_0 -> crewList
	-- 计算前排的夜战隐蔽强度上限
		-- 前排被视为一个整体
		-- 夜战隐蔽表现为瞄准偏移(AimBias)，后续均使用该术语，与航母的隐匿值/被侦测计量条区分
function BattleFormulas.CalculateMaxAimBiasRange(crewList)
	-- var_36_0 -> aimBiasFleetRangeMod(=0.18)
	local aimBiasFleetRangeMod = BattleConfig.AIM_BIAS_FLEET_RANGE_MOD
	local maxAimBiasRange

	if #crewList == 1 then
		-- var_36_2 -> crew
		-- 这个变量定义了又不用，程序员又忘了
		local crew = crewList[1]
		-- var_36_1 -> maxAimBiasRange
			-- ! 这里的机动值似乎是初始机动，后续考虑验证逻辑链
		maxAimBiasRange = BattleAttr.GetCurrent(crewList[1], "dodgeRate") * aimBiasFleetRangeMod
	else
		-- var_36_3 -> dodgeRates
		local dodgeRates = {}

		-- iter_36_0 -> _
		-- iter_36_1 -> crew(BattleUnit)
		for _, crew in ipairs(crewList) do
			table.insert(dodgeRates, BattleAttr.GetCurrent(crew, "dodgeRate"))
		end

		-- arg_37_0 -> A
		-- arg_37_1 -> B
		-- 对机动值按降序排列
			-- 如果机动值一样，不交换，即保持原有顺序(稳定排序)
		table.sort(dodgeRates, function(A, B)
			return B < A
		end)

		maxAimBiasRange = (dodgeRates[1] + dodgeRates[2] * 0.6 + (dodgeRates[3] or 0) * 0.3) / #dodgeRates * aimBiasFleetRangeMod
	end

	-- AIM_BIAS_MAX_RANGE_SCOUT = 25
	return (math.min(maxAimBiasRange, BattleConfig.AIM_BIAS_MAX_RANGE_SCOUT))
end

-- arg_38_0 -> crewList
	-- 计算潜艇的夜战隐蔽强度上限
		-- 与前排不同，潜艇的夜战隐蔽强度是单独计算的
function BattleFormulas.CalculateMaxAimBiasRangeSub(crewList)
	-- var_38_0 -> maxAimBiasRange
		-- AIM_BIAS_SUB_RANGE_MOD = 0.18
	local maxAimBiasRange = BattleAttr.GetCurrent(crewList[1], "dodgeRate") * BattleConfig.AIM_BIAS_SUB_RANGE_MOD

	-- AIM_BIAS_MAX_RANGE_SUB = 25
	return (math.min(maxAimBiasRange, BattleConfig.AIM_BIAS_MAX_RANGE_SUB))
end

-- arg_39_0 -> crewList
	-- 计算敌方单位的夜战隐蔽强度上限
		-- 敌方单位也是单独计算的
function BattleFormulas.CalculateMaxAimBiasRangeMonster(crewList)
	-- var_39_0 -> maxAimBiasRange
		-- AIM_BIAS_MONSTER_RANGE_MOD = 0.4
	local maxAimBiasRange = BattleAttr.GetCurrent(crewList[1], "dodgeRate") * BattleConfig.AIM_BIAS_MONSTER_RANGE_MOD

	-- AIM_BIAS_MAX_RANGE_MONSTER = 60
	return (math.min(maxAimBiasRange, BattleConfig.AIM_BIAS_MAX_RANGE_MONSTER))
end

-- arg_40_0 -> attackRating
	-- 计算我方前排(和水面潜艇)的夜战隐蔽基础衰减速度
	-- 参考调用链路：BattleBuffSmokeAimBias -> SetDecayFactor -> CalculateBiasDecay
function BattleFormulas.CalculateBiasDecay(attackRating)
	-- var_40_0 -> biasDecay
		-- AIM_BIAS_DECAY_MOD_MONSTER = 0.01
		-- 从上层调用看到，这里的attackRating实际上是敌方全场的最高命中值
	local biasDecay = attackRating * BattleConfig.AIM_BIAS_DECAY_MOD_MONSTER
	-- AIM_BIAS_DECAY_SPEED_MAX_SCOUT = 3
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SCOUT))
end

-- arg_41_0 -> attackRating
	-- 计算敌方单位的夜战隐蔽基础衰减速度
function BattleFormulas.CalculateBiasDecayMonster(attackRating)
	-- var_41_0 -> biasDecay
		-- AIM_BIAS_DECAY_MOD = 0.01
		-- 从上层调用看到，这里的attackRating实际上是我方全场的最高命中值
	local biasDecay = attackRating * BattleConfig.AIM_BIAS_DECAY_MOD

	-- AIM_BIAS_DECAY_SPEED_MAX_MONSTER = 3
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER))
end

-- arg_42_0 -> attackRating
	-- 计算敌方单位在烟雾中时的夜战隐蔽衰减速度
function BattleFormulas.CalculateBiasDecayMonsterInSmoke(attackRating)
	-- var_42_0 -> biasDecay
		-- AIM_BIAS_DECAY_MOD = 0.01
		-- AIM_BIAS_DECAY_SMOKE = 1
			-- 实际上是没有变化的，可能是为了代码可读性，区分了不同场景
		-- 从上层调用看到，这里的attackRating实际上是我方全场的最高命中值
	local biasDecay = attackRating * BattleConfig.AIM_BIAS_DECAY_MOD * BattleConfig.AIM_BIAS_DECAY_SMOKE

	-- AIM_BIAS_DECAY_SPEED_MAX_MONSTER = 3
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER))
end

-- arg_43_0 -> attackRating
	-- 计算我方潜艇的夜战隐蔽基础衰减速度
function BattleFormulas.CalculateBiasDecayDiving(attackRating)
	-- var_43_0 -> biasDecay
		-- AIM_BIAS_DECAY_SUB_CONST = 50
		-- AIM_BIAS_DECAY_MOD = 0.01
		-- 从上层调用看到，这里的attackRating实际上是敌方全场的最高命中值
	local biasDecay = math.max(0, attackRating - BattleConfig.AIM_BIAS_DECAY_SUB_CONST) * BattleConfig.AIM_BIAS_DECAY_MOD

	-- AIM_BIAS_DECAY_SPEED_MAX_SUB = 100
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SUB))
end

-- arg_44_0 -> enemyEnhancement
-- arg_44_1 -> enemyLevel
	-- 计算大世界敌人属性提高倍率
function BattleFormulas.WorldEnemyAttrEnhance(enemyEnhancement, enemyLevel)
	-- WORLD_ENEMY_ENHANCEMENT_CONST_C = 1.1
	-- WORLD_ENEMY_ENHANCEMENT_CONST_B = 80
	return 1 + enemyEnhancement / (1 + BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_C^(BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_B - enemyLevel))
end

-- var_0_15 -> cachedMapRewards
	-- 应该是一个缓存
local cachedMapRewards = setmetatable({}, {
	-- arg_45_0 -> table
	-- arg_45_1 -> key
	__index = function(table, key)
		return 0
	end
})

-- arg_46_0 -> enemyMapRewards
-- arg_46_1 -> fleetMapRewards
	-- 计算适应性Buff的属性增强倍率
	-- 适应性似乎使用mapRewards来指代的...
function BattleFormulas.WorldMapRewardAttrEnhance(enemyMapRewards, fleetMapRewards)
	enemyMapRewards = enemyMapRewards or cachedMapRewards
	fleetMapRewards = fleetMapRewards or cachedMapRewards

	-- var_46_0 ~ var_46_2 这三个变量定义了都没用过，我直接删掉了
	-- var_46_3 -> worldValueRanges(适应性Buff区间)
		-- X: 敌方属性倍率，Y: 敌方耐久倍率, Z: 不太清楚, worldBuffResistance?
		-- attr_world_value_X1 = 7000
		-- attr_world_value_X2 = 13000
		-- attr_world_value_Y1 = 7000
		-- attr_world_value_Y2 = 13000
		-- attr_world_value_Z1 = 10000
		-- attr_world_value_Z2 = 10000
	local worldValueRanges = {
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
	-- var_46_4 -> worldDamageFix(= 0.1)
		-- attr_world_damage_fix = 1000
	local worldDamageFix = gameset.attr_world_damage_fix.key_value / 10000
	-- var_46_5 -> tempWorldAttrEnhance
	local tempWorldAttrEnhance

	if enemyMapRewards[1] == 0 then
		tempWorldAttrEnhance = worldValueRanges[1][2]
	else
		tempWorldAttrEnhance = fleetMapRewards[1] / enemyMapRewards[1]
	end

	-- var_46_6 -> finalWorldAttrEnhanceX
	local finalWorldAttrEnhanceX = 1 - math.clamp(tempWorldAttrEnhance, worldValueRanges[1][1], worldValueRanges[1][2])

	if enemyMapRewards[2] == 0 then
		tempWorldAttrEnhance = worldValueRanges[2][2]
	else
		tempWorldAttrEnhance = fleetMapRewards[2] / enemyMapRewards[2]
	end
	-- var_46_7 -> finalWorldAttrEnhanceY
	local finalWorldAttrEnhanceY = 1 - math.clamp(tempWorldAttrEnhance, worldValueRanges[2][1], worldValueRanges[2][2])

	if enemyMapRewards[3] == 0 then
		tempWorldAttrEnhance = worldValueRanges[3][2]
	else
		tempWorldAttrEnhance = fleetMapRewards[3] / enemyMapRewards[3]
	end
	-- var_46_8 -> finalWorldAttrEnhanceZ
	local finalWorldAttrEnhanceZ = math.max(1 - math.clamp(tempWorldAttrEnhance, worldValueRanges[3][1], worldValueRanges[3][2]), -worldDamageFix)

	return finalWorldAttrEnhanceX, finalWorldAttrEnhanceY, finalWorldAttrEnhanceZ
end

-- arg_47_0 -> enemyMapRewards
-- arg_47_1 -> fleetMapRewards
	-- 计算适应性Buff的治疗倍率
function BattleFormulas.WorldMapRewardHealingRate(enemyMapRewards, fleetMapRewards)
	-- var_47_0 -> worldHealingRateRange(治疗倍率区间)
		-- attr_world_value_H1 = 7000
		-- attr_world_value_H2 = 10000
	local worldHealingRateRange = {
		gameset.attr_world_value_H1.key_value / 10000,
		gameset.attr_world_value_H2.key_value / 10000
	}

	enemyMapRewards = enemyMapRewards or cachedMapRewards
	fleetMapRewards = fleetMapRewards or cachedMapRewards

	-- var_47_1 -> tempWorldHealingRate
	local tempWorldHealingRate

	if enemyMapRewards[3] == 0 then
		tempWorldHealingRate = worldHealingRateRange[2]
	else
		tempWorldHealingRate = fleetMapRewards[3] / enemyMapRewards[3]
	end

	return math.clamp(tempWorldHealingRate, worldHealingRateRange[1], worldHealingRateRange[2])
end

-- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLock()
	return 0, {
		false,
		true,
		false
	}
end

-- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLockA2M()
	return 0
end

-- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLockS2M()
	return 0
end

-- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLockCrush()
	return 0, 0
end

-- 用于BattleDodgemCommand，用途暂不明
function BattleFormulas.UnilateralCrush()
	return 0, 100000
end

-- arg_53_0 -> repressReduce
	-- 计算普通图章节的压制减伤倍率
function BattleFormulas.ChapterRepressReduce(repressReduce)
	return 1 - repressReduce * 0.01
end

-- arg_54_0 -> rant
	-- 判定概率是否发生，常用
	-- 等价于rant%的概率发生，并向下取整到0.01%
function BattleFormulas.IsHappen(rant)
	if rant <= 0 then
		return false
	elseif rant >= 10000 then
		return true
	else
		return rant >= math.random(10000)
	end
end

-- arg_55_0 -> weightRstList
	-- 根据权重，随机选择一个结果
function BattleFormulas.WeightRandom(weightRstList)
	-- var_55_0 -> weightList
	-- var_55_1 -> totalWeight
	local weightList, totalWeight = BattleFormulas.GenerateWeightList(weightRstList)

	return (BattleFormulas.WeightListRandom(weightList, totalWeight))
end

-- arg_56_0 -> weightList
-- arg_56_1 -> totalWeight
	-- 根据权重区间列表和总权重，随机选择一个结果
function BattleFormulas.WeightListRandom(weightList, totalWeight)
	-- var_56_0 -> randomWeight
	local randomWeight = math.random(0, totalWeight)

	-- iter_56_0 -> weightRange
	-- iter_56_1 -> rst
	for weightRange, rst in pairs(weightList) do
		-- var_56_1 -> minWeight
		-- var_56_2 -> maxWeight
		local minWeight = weightRange.min
		local maxWeight = weightRange.max

		if minWeight <= randomWeight and randomWeight <= maxWeight then
			return rst
		end
	end
end

-- arg_57_0 -> weightRstList
	-- 生成权重区间列表和总权重，用于权重随机选择
function BattleFormulas.GenerateWeightList(weightRstList)
	-- var_57_0 -> weightList(实际是weightRangeList, 为了一致性我没改变量名)
	-- var_57_1 -> totalWeight
	local weightList = {}
	local totalWeight = -1

	-- iter_57_0 -> _
	-- iter_57_1 -> weightRstPair
	for _, weightRstPair in ipairs(weightRstList) do
		-- var_57_2 -> weight
		-- var_57_3 -> rst(可能表示result?)
			-- 从后续调用看出，对应的是那个对象本身
		local weight = weightRstPair.weight
		local rst = weightRstPair.rst
		-- var_57_4 -> minWeight
		-- var_57_5 未使用，我删掉了
		local minWeight = totalWeight + 1

		totalWeight = totalWeight + weight

		-- var_57_6 -> maxWeight
		local maxWeight = totalWeight

		weightList[{
			min = minWeight,
			max = maxWeight
		}] = rst
	end

	return weightList, totalWeight
end

-- arg_58_0 -> list
	-- 检查一组概率列表，判断是否有事件发生
	-- 返回第一个发生的事件及其结果，否则返回false和nil、
	-- 这个函数没有被用过。
function BattleFormulas.IsListHappen(list)
	-- iter_58_0 -> _
	-- iter_58_1 -> rantPair({rant, rst})
	for _, rantPair in ipairs(list) do
		if BattleFormulas.IsHappen(rantPair[1]) then
			return true, rantPair[2]
		end
	end

	return false, nil
end

-- arg_59_0 -> targetPos
-- arg_59_1 -> sourcePos
	-- 计算子弹发射的XZ平面角度
	-- = 180 / pi * arctan(dz/dx)，得到的是度数
	-- 这个函数没有被用过。
function BattleFormulas.BulletYAngle(targetPos, sourcePos)
	return math.rad2Deg * math.atan2(sourcePos.z - targetPos.z, sourcePos.x - targetPos.x)
end


function BattleFormulas.RandomPosNull(arg_60_0, arg_60_1)
	arg_60_1 = arg_60_1 or 10

	-- var_60_0 -> distance
	-- var_60_0 -> distanceSqr
	local var_60_0 = arg_60_0.distance or 10
	local var_60_1 = var_60_0 * var_60_0
	-- var_60_2 -> allTargets
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

-- arg_61_0 -> point
function BattleFormulas.RandomPos(point)
	-- var_61_0 -> x
	-- var_61_1 -> y
	-- var_61_2 -> z
	local x = point[1] or 0
	local y = point[2] or 0
	local z = point[3] or 0

	if point.rangeX or point.rangeY or point.rangeZ then
		-- var_61_3 -> deltaX
		-- var_61_4 -> deltaY
		-- var_61_5 -> deltaZ
		local deltaX = BattleFormulas.RandomDelta(point.rangeX)
		local deltaY = BattleFormulas.RandomDelta(point.rangeY)
		local deltaZ = BattleFormulas.RandomDelta(point.rangeZ)

		return Vector3(x + deltaX, y + deltaY, z + deltaZ)
	else
		-- var_61_6 -> deltaX
		-- var_61_7 -> deltaY
		-- var_61_8 -> deltaZ
		local deltaX = BattleFormulas.RandomPosXYZ(point, "X1", "X2")
		local deltaY = BattleFormulas.RandomPosXYZ(point, "Y1", "Y2")
		local deltaZ = BattleFormulas.RandomPosXYZ(point, "Z1", "Z2")

		return Vector3(x + deltaX, y + deltaY, z + deltaZ)
	end
end

-- arg_62_0 -> point
-- arg_62_1 -> coordLeft
-- arg_62_2 -> coordRight
	-- 计算在指定坐标区间内的随机坐标值
function BattleFormulas.RandomPosXYZ(point, coordLeft, coordRight)
	coordLeft = point[coordLeft]
	coordRight = point[coordRight]

	if coordLeft and coordRight then
		return math.random(coordLeft, coordRight)
	else
		return 0
	end
end

-- arg_63_0 -> point
	-- 这个函数没有被用过。
function BattleFormulas.RandomPosCenterRange(point)
	-- var_63_0 -> deltaX
	-- var_63_1 -> deltaY
	-- var_63_2 -> deltaZ
	local deltaX = BattleFormulas.RandomDelta(point.rangeX)
	local deltaY = BattleFormulas.RandomDelta(point.rangeY)
	local deltaZ = BattleFormulas.RandomDelta(point.rangeZ)

	return Vector3(deltaX, deltaY, deltaZ)
end

-- arg_64_0 -> deltaRange
	-- 计算一个在[-deltaRange, +deltaRange]范围内的随机整数
function BattleFormulas.RandomDelta(deltaRange)
	if deltaRange and deltaRange > 0 then
		return math.random(deltaRange + deltaRange) - deltaRange
	else
		return 0
	end
end

-- arg_65_0 -> argString
-- arg_65_1 -> compareValue
function BattleFormulas.simpleCompare(argString, compareValue)
	-- var_65_0 -> punctuationStringStart
	-- var_65_1 -> punctuationStringEnd
		-- "%p+" 表示匹配一个或多个标点符号
	-- 这里的标点符号实际上是比较运算符，例如">=", "<"
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")
	-- var_65_2 -> punctuationString
	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	-- var_65_3 -> valueString
	local valueString = string.sub(argString, punctuationStringEnd + 1, #argString)
	-- var_65_4 -> compareFunc
	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	-- var_65_5 -> value
	local value = tonumber(valueString)

	return compareFunc(compareValue, value)
end

-- arg_66_0 -> argString
-- arg_66_1 -> leftUnit
-- arg_66_2 -> rightUnit
function BattleFormulas.parseCompareUnitAttr(argString, leftUnit, rightUnit)
	-- var_66_0 -> punctuationStringStart
	-- var_66_1 -> punctuationStringEnd
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")
	-- var_66_2 -> punctuationString
	-- var_66_3 -> leftValueString
	-- var_66_4 -> rightValueString
	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local leftValueString = string.sub(argString, 1, punctuationStringStart - 1)
	local rightValueString = string.sub(argString, punctuationStringEnd + 1, #argString)
	-- var_66_5 -> compareFunc
	-- var_66_6 -> leftValue
	-- var_66_7 -> rightValue
	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local leftValue = tonumber(leftValueString) or leftUnit:GetAttrByName(leftValueString)
	local rightValue = tonumber(rightValueString) or rightUnit:GetAttrByName(rightValueString)

	return compareFunc(leftValue, rightValue)
end

-- arg_67_0 -> argString
-- arg_67_1 -> leftUnit
-- arg_67_2 -> rightUnit
function BattleFormulas.parseCompareUnitTemplate(argString, leftUnit, rightUnit)
	-- var_67_0 -> punctuationStringStart
	-- var_67_1 -> punctuationStringEnd
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")
	-- var_67_2 -> punctuationString
	-- var_67_3 -> leftValueString
	-- var_67_4 -> rightValueString
	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local leftValueString = string.sub(argString, 1, punctuationStringStart - 1)
	local rightValueString = string.sub(argString, punctuationStringEnd + 1, #argString)
	-- var_67_5 -> compareFunc
	-- var_67_6 -> leftValue
	-- var_67_7 -> rightValue
	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local leftValue = tonumber(leftValueString) or leftUnit:GetTemplateValue(leftValueString)
	local rightValue = tonumber(rightValueString) or rightUnit:GetTemplateValue(rightValueString)

	return compareFunc(leftValue, rightValue)
end

-- arg_68_0 -> argString
-- arg_68_1 -> effect(BattleBuffEffect)
function BattleFormulas.parseCompareBuffAttachData(argString, effect)
	-- var_68_0 -> punctuationStringStart
	-- var_68_1 -> punctuationStringEnd
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")
	-- var_68_2 -> punctuationString
	-- var_68_3 -> effectName
	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local effectName = string.sub(argString, 1, punctuationStringStart - 1)

	if effect.__name ~= effectName then
		return true
	end

	-- var_68_4 -> value
	-- var_68_5 -> attachValue
	local value = tonumber(string.sub(argString, punctuationStringEnd + 1, #argString))
	local attachValue = effect:GetEffectAttachData()

	return getCompareFuncByPunctuation(punctuationString)(attachValue, value)
end

-- arg_69_0 -> argString
-- arg_69_1 -> attrs
function BattleFormulas.parseCompare(argString, attrs)
	-- var_69_0 -> punctuationStringStart
	-- var_69_1 -> punctuationStringEnd
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")
	-- var_69_2 -> punctuationString
	-- var_69_3 -> leftValueString
	-- var_69_4 -> rightValueString
	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local leftValueString = string.sub(argString, 1, punctuationStringStart - 1)
	local rightValueString = string.sub(argString, punctuationStringEnd + 1, #argString)
	-- var_69_5 -> compareFunc
	-- var_69_6 -> leftValue
	-- var_69_7 -> rightValue
	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local leftValue = tonumber(leftValueString) or attrs:GetCurrent(leftValueString)
	local rightValue = tonumber(rightValueString) or attrs:GetCurrent(rightValueString)

	return compareFunc(leftValue, rightValue)
end

-- arg_70_0 -> formulaString
-- arg_70_1 -> attrs(BattleAttr)
	-- 这个函数解析一个计算公式字符串，并计算出结果
	-- 但我看了一眼，这个函数只在CardPuzzle中使用，这是一个废弃的模式
function BattleFormulas.parseFormula(formulaString, attrs)
	-- var_70_0 -> variableTable
	-- var_70_1 -> operatorTable
	local variableTable = {}
	local operatorTable = {}

	-- iter_70_0 -> variable
		-- "%w+%.?%w*" 表示匹配一个或多个字母数字字符，后面可选跟一个点号和一个或多个字母数字字符
		-- 这表示匹配变量名或数字
	for variable in string.gmatch(formulaString, "%w+%.?%w*") do
		table.insert(variableTable, variable)
	end

	-- iter_70_1 -> operator
		-- "[^%w%.]" 表示匹配一个非字母数字且非点号的字符
		-- 这表示匹配运算符
	for operator in string.gmatch(formulaString, "[^%w%.]") do
		table.insert(operatorTable, operator)
	end

	-- 似乎是在构建一个中缀表达式的计算?
	-- var_70_2 -> operatorsLeft
	-- var_70_3 -> valuesForCalc
	local operatorsLeft = {}
	local valuesForCalc = {}
	local varIndex = 1
	-- var_70_5 -> currentValue?
	local currentValue = variableTable[1]

	currentValue = tonumber(currentValue) or attrs:GetCurrent(currentValue)

	-- iter_70_2 -> _
	-- iter_70_3 -> operator
	for _, operator in ipairs(operatorTable) do
		-- var_70_4 -> varIndex
		varIndex = varIndex + 1

		-- var_70_6 -> varValue
		local varValue = tonumber(variableTable[varIndex]) or attrs:GetCurrent(variableTable[varIndex])

		-- 下面的逻辑是处理运算符优先级的，如果是加减法就先把当前值存下来，乘除法就直接计算
		if operator == "+" or operator == "-" then
			table.insert(valuesForCalc, currentValue)

			currentValue = varValue

			table.insert(operatorsLeft, operator)
		elseif operator == "*" or operator == "/" then
			currentValue = getArithmeticFuncByOperator(operator)(currentValue, varValue)
		end
	end

	table.insert(valuesForCalc, currentValue)

	-- var_70_7 -> i
	-- var_70_8 -> resultValue
	local i = 1
	local resultValue = valuesForCalc[i]

	while i < #valuesForCalc do
		-- var_70_9 -> operatorFunc
		local operatorFunc = getArithmeticFuncByOperator(operatorsLeft[i])

		i = i + 1
		resultValue = operatorFunc(resultValue, valuesForCalc[i])
	end

	return resultValue
end
