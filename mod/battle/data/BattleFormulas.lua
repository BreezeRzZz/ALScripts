ys.Battle.BattleFormulas = ys.Battle.BattleFormulas or {}

local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local gameset = pg.gameset
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local AnitAirRepeaterConfig = ys.Battle.BattleConfig.AnitAirRepeaterConfig
local bfConsts = pg.bfConsts
-- bfConsts来源BattleState.lua
	-- bfConst.SECONDS = 60
	-- BattleConfig.viewFPS = 30(*随设置改变)
	-- BattleConfig.calcFPS = 30(*固定)
	-- BattleConfig.BulletSpeedConvertConst = 0.1
	-- BattleConfig.ShipSpeedConvertConst = 0.01
	-- BattleConfig.AircraftSpeedConvertConst = 0.01
-- bulletSpeedConvertRatio = 0.2
-- shipSpeedConverRatio = 0.02
-- aircraftSpeedConvertRatio = 0.02
local bulletSpeedConvertRatio = bfConsts.SECONDs / BattleConfig.viewFPS * BattleConfig.BulletSpeedConvertConst
local shipSpeedConvertRatio = bfConsts.SECONDs / BattleConfig.calcFPS * BattleConfig.ShipSpeedConvertConst
local aircraftSpeedConvertRatio = bfConsts.SECONDs / BattleConfig.viewFPS * BattleConfig.AircraftSpeedConvertConst
-- BattleConfig.AIR_ASSIST_RELOAD_RATIO = 220
-- bfConst.PERCENT = 0.01
-- airAssistReloadFactor = 2.2
local airAssistReloadFactor = BattleConfig.AIR_ASSIST_RELOAD_RATIO * bfConsts.PERCENT
local damageEnhanceFromShipType = BattleConfig.DAMAGE_ENHANCE_FROM_SHIP_TYPE
local ammoDamageEnhance = BattleConfig.AMMO_DAMAGE_ENHANCE
local ammoDamageReduce = BattleConfig.AMMO_DAMAGE_REDUCE
local shipTypeAccuracyEnhance = BattleConfig.SHIP_TYPE_ACCURACY_ENHANCE

--- @param fleet BattleFleetVO 
--- @return number
--- 获取舰队总HP。
--- - 旗舰按1.5倍计算
function BattleFormulas.GetFleetTotalHP(fleet)
	local flagShip = fleet:GetFlagShip()
	local unitList = fleet:GetUnitList()
	local totalHP = bfConsts.NUM0

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

--- @param scoutList table<number, BattleUnit>:表示前排
--- @return number
--- 获取(前排)航速。
function BattleFormulas.GetFleetVelocity(scoutList)
	local frontShip = scoutList[1]

	-- 这一段是什么意思看不太懂
	if frontShip then
		local frontShipVelocity = BattleAttr.GetCurrent(frontShip, "fleetVelocity")

		if frontShipVelocity > bfConsts.NUM0 then
			return frontShipVelocity * bfConsts.PERCENT
		end
	end

	local totalSpeed = bfConsts.NUM0
	local numShips = #scoutList

	for _, ship in ipairs(scoutList) do
		totalSpeed = totalSpeed + ship:GetAttrByName("velocity")
	end

	-- bfConsts.SPEED_CONST = 0.02
	-- 即speedFactor = 1 - 0.02 * (numShips - 1)
	local speedFactor = bfConsts.NUM1 - bfConsts.SPEED_CONST * (numShips - bfConsts.NUM1)

	-- 平均速度乘以speedFactor
	return totalSpeed / numShips * speedFactor
end

--- @param fleet BattleFleetVO 
--- @return number
--- 计算舰队总装填值。
function BattleFormulas.GetFleetReload(fleet)
	local totalReload = bfConsts.NUM0

	for _, ship in ipairs(fleet) do
		totalReload = totalReload + ship:GetReload()
	end

	return totalReload
end

--- @param fleet BattleFleetVO
--- @return number
--- 计算舰队总雷击值。
function BattleFormulas.GetFleetTorpedoPower(fleet)
	local totalTorpedoPower = bfConsts.NUM0

	for _, ship in ipairs(fleet) do
		totalTorpedoPower = totalTorpedoPower + ship:GetTorpedoPower()
	end

	return totalTorpedoPower
end

--- @param battleType number
--- @param unit BattleUnit
--- @return nil
--- 修正演习模式的耐久值。
function BattleFormulas.AttrFixer(battleType, unit)
	-- 相关定义在const.lua中
	-- SYSTEM_DUEL对应演习模式
	-- GetPlayerUnitDurabilityExtraAddition使用的是ship_level.lua模板
	-- 125级时，演习耐久 = 正常耐久 * 2.4
	if battleType == SYSTEM_DUEL then
		local level = unit.level
		local durability = unit.durability
		local durabilityRatio, durabilityAdd = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(battleType, level)

		unit.durability = durability * durabilityRatio + durabilityAdd
	end
end

--- @param battleType number 
--- @param unit BattleUnit
--- @return number
--- 修正演习模式的回复倍率。
function BattleFormulas.HealFixer(battleType, unit)
	local healRatio = 1

	if battleType == SYSTEM_DUEL then
		local level = unit.level

		-- 演习模式的回血倍率跟耐久度倍率一致
		healRatio = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(battleType, level)
	end

	return healRatio
end

--- @param shipSpeed number
--- @return number
--- 将原始航速属性转换为每帧移动的距离。
--- - 原始航速 * 0.02，得到的是每帧移动的距离
--- - 区别两个术语：原始航速为Speed，转换后叫做Velocity
function BattleFormulas.ConvertShipSpeed(shipSpeed)
	return shipSpeed * shipSpeedConvertRatio
end

--- @param aircraftSpeed number
--- @return number|nil
--- 将原始飞机速度属性转换为每帧移动的距离。
--- - 原始飞机速度 * 0.02，得到的是每帧移动的距离
--- - 如果没有飞机速度，返回nil
function BattleFormulas.ConvertAircraftSpeed(aircraftSpeed)
	if aircraftSpeed then
		return aircraftSpeed * aircraftSpeedConvertRatio
	else
		return nil
	end
end

--- @param bulletSpeed number
--- @return number
--- 将原始子弹速度属性转换为每帧移动的距离
--- - 原始子弹速度 * 0.2，得到的是每帧移动的距离
function BattleFormulas.ConvertBulletSpeed(bulletSpeed)
	return bulletSpeed * bulletSpeedConvertRatio
end

--- @param bulletVelocity number
--- @return number
-- 将每帧移动的距离(Velocity)转换回原始子弹速度(Speed)
function BattleFormulas.ConvertBulletDataSpeed(bulletVelocity)
	return bulletVelocity / bulletSpeedConvertRatio
end

--- @param inWorld boolean: 是否在大型作战中
--- @return function: 一个闭包函数，根据上下文计算伤害
function BattleFormulas.CreateContextCalculateDamage(inWorld)
	--- @param bullet BattleBulletUnit: 参与伤害结算的子弹实体
	--- @param target BattleUnit : 受到伤害的目标实体
	--- @param damageReduceDistance number : 距离伤害衰减比例，只有具有边际伤害的反潜设备才需要考虑
	--- @param meteoDamageRatio number : 多个舰载机被防空炮攻击时分配到的伤害比例
	--- @return number: 本次结算的伤害值
	--- @return table: 额外信息表，包含字段：是否命中、是否暴击、是否伤害被阻挡或伤害属性
	--- @return table|nil: 字体信息表
	return function(bullet, target, damageReduceDistance, meteoDamageRatio)
		local num1 = bfConsts.NUM1
		local num0 = bfConsts.NUM0
		local num10000 = bfConsts.NUM10000
		local dRate = bfConsts.DRATE
		local accuracyConst = bfConsts.ACCURACY
		-- 此处若有跨队的standHost，则使用standHost的属性
		-- 在下面的部分影响的内容有：
			-- levelDiff
			-- 命中、暴击计算
			-- bullet.GetWeaponAtkAttr()
		local weaponHostAttr = bullet:GetWeaponHostAttr()
		local weapon = bullet:GetWeapon()
		local weaponTemplate = bullet:GetWeaponTempData()
		local weaponType = weaponTemplate.type
		local attackAttribute = weaponTemplate.attack_attribute
		-- weaponConvertedAtkAttr
			-- 来自BattleFormulas.WeaponAtkAttrPreRatio(), 为属性效率(attackAttributeRatio)/10000
			-- 属性效率一般是三位数，如100，因此最后会变成0.01
			-- 为了方便，一般就简单记为属性效率/100，这样属性效率就是以1为基准的了
		local weaponConvertedAtkAttr = weapon:GetConvertedAtkAttr()
		local bulletTemplate = bullet:GetTemplate()
		-- bulletDamageType(对甲比例)
		local bulletDamageType = bulletTemplate.damage_type
		-- 随机伤害比例，只有刺猬弹使用
		local bulletRandomDamageRate = bulletTemplate.random_damage_rate
		local targetAttr = target._attr
		local damageRatioByAttr = meteoDamageRatio or num1

		damageReduceDistance = damageReduceDistance or num0

		local targetArmorType = targetAttr.armorType
		local levelDiff = weaponHostAttr.formulaLevel - targetAttr.formulaLevel
		local critDamage = num1
		local isCri = false
		local baseDamage = num1
		-- bulletCorrectedDMG
			-- 子弹的correctedDMG来自武器的correctedDMG
			-- 来自BattleFormulas.WeaponDamagePreCorrection()
			-- 武器标伤(damage) * 修正系数(corrected) * 武器效率(potential) / 100
			-- 因为武器效率一般也是三位数，为了方便，也是变成以1为基准的，所以除以100就消掉了
		local bulletCorrectedDMG = bullet:GetCorrectedDMG()
		-- bulletBaseDamage
			-- (1 + 攻击属性 * 属性效率 / 100) * 武器标伤 * 修正系数 * 武器效率
		local bulletBaseDamage = (num1 + bullet:GetWeaponAtkAttr() * weaponConvertedAtkAttr) * bulletCorrectedDMG

		if attackAttribute == BattleConst.WeaponDamageAttr.CANNON then
			damageRatioByAttr = num1 + BattleAttr.GetCurrent(target, "injureRatioByCannon") + BattleAttr.GetCurrent(bullet, "damageRatioByCannon")
		elseif attackAttribute == BattleConst.WeaponDamageAttr.TORPEDO then
			damageRatioByAttr = num1 + BattleAttr.GetCurrent(target, "injureRatioByBulletTorpedo") + BattleAttr.GetCurrent(bullet, "damageRatioByBulletTorpedo")
		elseif attackAttribute == BattleConst.WeaponDamageAttr.AIR then
			-- airResistPierce(防空减伤穿透，前提：airResistPierceActive为1，即处于隐匿状态下)
			local airResistPierce = BattleAttr.GetCurrent(bullet, "airResistPierceActive") == 1 and BattleAttr.GetCurrent(bullet, "airResistPierce") or 0
			-- dRate[7] = 150
			damageRatioByAttr = damageRatioByAttr * math.min(dRate[7] / (targetAttr.antiAirPower + dRate[7]) + airResistPierce, 1) * (num1 + BattleAttr.GetCurrent(target, "injureRatioByAir") + BattleAttr.GetCurrent(bullet, "damageRatioByAir"))
		elseif attackAttribute == BattleConst.WeaponDamageAttr.ANTI_AIR then
			-- block empty
		elseif attackAttribute == BattleConst.WeaponDamageAttr.ANIT_SUB then
			-- block empty
		end

		local luckDiff = weaponHostAttr.luck - targetAttr.luck
		-- perfectDodge为1时，表示必定闪避，不进行命中判定
		local perfectDodge = BattleAttr.GetCurrent(target, "perfectDodge")
		local attackRating = math.max(weaponHostAttr.attackRating, 0)
		local isMiss

		if perfectDodge >= 1 then
			isMiss = true
		else
			-- accuracyConst[1] = 0.1, accuracyConst[2] = 2
			local baseAccuracyRate = accuracyConst[1] + attackRating / (attackRating + targetAttr.dodgeRate + accuracyConst[2]) + (luckDiff + levelDiff) * bfConsts.PERCENT1
			local accuracyRateExtra = BattleAttr.GetCurrent(bullet, "accuracyRateExtra")
			local shipTypeAccuracyEnhance = BattleAttr.GetCurrent(bullet, shipTypeAccuracyEnhance[target:GetTemplate().type])
			local dodgeRateExtra = BattleAttr.GetCurrent(target, "dodgeRateExtra")
			-- dRate[5] = 0.1
			-- 说明命中率最小为10%，最大为100%
			local finalAccuracyRate = math.max(dRate[5], math.min(num1, baseAccuracyRate + accuracyRateExtra + shipTypeAccuracyEnhance - dodgeRateExtra))

			isMiss = not BattleFormulas.IsHappen(finalAccuracyRate * num10000)
		end

		-- 若命中
		if not isMiss then
			-- critRate
				-- GCT表示必定暴击(Guaranteed Crit)字段，如果为1则表示必定暴击, 不用进行后续暴击率计算
				-- bfConst.DFT_CRIT_RATE = 0.05
				-- dRate[4] = 2000
				-- dRate[3] = 0.0002
			local critRate = BattleAttr.GetCurrent(bullet, "GCT") == 1 and 1 or bfConsts.DFT_CRIT_RATE + attackRating / (attackRating + targetAttr.dodgeRate + dRate[4]) + (luckDiff + levelDiff) * dRate[3] + BattleAttr.GetCurrent(bullet, "cri") + BattleAttr.GetTagAttrCri(bullet, target)

			-- RANDOM_DAMAGE_MIN = 0, RANDOM_DAMAGE_MAX = 2
			baseDamage = math.random(BattleConfig.RANDOM_DAMAGE_MIN, BattleConfig.RANDOM_DAMAGE_MAX) + bulletBaseDamage

			if BattleFormulas.IsHappen(critRate * num10000) then
				isCri = true

				-- bfConsts.DFT_CRIT_EFFECT = 1.5
				local baseCritDamage = bfConsts.DFT_CRIT_EFFECT + BattleAttr.GetTagAttrCriDmg(bullet, target) + BattleAttr.GetCurrent(bullet, "criDamage") - BattleAttr.GetCurrent(target, "criDamageResist")

				critDamage = math.max(1, baseCritDamage)
			else
				isCri = false
			end
		else
			-- 如果未命中，直接结算
			baseDamage = num0

			local extraInfo = {
				isMiss = true,
				isDamagePrevent = false,
				isCri = isCri
			}

			return baseDamage, extraInfo
		end

		-- baseRatio(=1)
		local baseRatio = bfConsts.NUM1
		-- damageRatioBullet(子弹伤害倍率)
		local damageRatioBullet = BattleAttr.GetCurrent(bullet, "damageRatioBullet")
		-- damageRatioTag(标签伤害倍率)
		local damageRatioTag = BattleAttr.GetTagAttr(bullet, target, inWorld)
		-- injureRatio(目标受伤倍率)
		local injureRatio = BattleAttr.GetCurrent(target, "injureRatio")
		-- damageAmmoToArmorRate(弹药对甲倍率)
			-- 这里是子弹的基础对甲效率 + (子弹)获得的对甲效率加成
		local damageAmmoToArmorRate = (weapon:GetFixAmmo() or bulletDamageType[targetArmorType] or baseRatio) + BattleAttr.GetCurrent(bullet, BattleConfig.DAMAGE_AMMO_TO_ARMOR_RATE_ENHANCE[targetArmorType])
		-- damageToArmorRateEnhance(子弹对甲倍率增加)
			-- 注意子弹对甲倍率与弹药对甲倍率区别。子弹(Bullet)和弹药(Ammo)是两个不同的概念，一般来说，Ammo是Bullet的一个属性
		local damageToArmorRateEnhance = BattleAttr.GetCurrent(bullet, BattleConfig.DAMAGE_TO_ARMOR_RATE_ENHANCE[targetArmorType])
		-- ammoDamageEnhance(弹药伤害倍率增加)
			-- 判定依据是子弹的弹药类型(ammo_type)
		local ammoDamageEnhance = BattleAttr.GetCurrent(bullet, ammoDamageEnhance[bulletTemplate.ammo_type])
		-- targetAmmoDamageReduce(目标弹药伤害减免)
		local targetAmmoDamageReduce = BattleAttr.GetCurrent(target, ammoDamageReduce[bulletTemplate.ammo_type])
		-- comboTag(连击标签)
			-- 表示的是子弹连续命中了某个目标后，所触发的连击标签
		local comboTag = BattleAttr.GetCurrent(bullet, "comboTag")
		-- damageRatioComboTag(连击标签伤害倍率)
		local damageRatioComboTag = BattleAttr.GetCurrent(target, comboTag)
		-- finalDamageBase
			-- dRate[1] = 25, dRate[2] = 0.02
		local finalDamageBase = math.max(baseRatio, math.floor(baseDamage * damageRatioByAttr * (baseRatio - damageReduceDistance) * damageAmmoToArmorRate * (baseRatio + damageToArmorRateEnhance) * critDamage * (baseRatio + damageRatioBullet) * damageRatioTag * (baseRatio + injureRatio) * (baseRatio + ammoDamageEnhance - targetAmmoDamageReduce) * (baseRatio + damageRatioComboTag) * (baseRatio + math.min(dRate[1], math.max(-dRate[1], levelDiff)) * dRate[2])))

		if target:GetCurrentOxyState() == BattleConst.OXY_STATE.DIVE then
			finalDamageBase = math.floor(finalDamageBase * bulletTemplate.antisub_enhancement)
		end

		local extraInfo = {
			isMiss = isMiss,
			isCri = isCri,
			damageAttr = attackAttribute
		}

		-- damageEnhance
			-- 包括手动开炮时的第一底座增伤和首轮增伤等
		local damageEnhance = bullet:GetDamageEnhance()

		if damageEnhance ~= 1 then
			finalDamageBase = math.floor(finalDamageBase * damageEnhance)
		end

		-- finalDamageAfterRepress
			-- targetAttr.repressReduce表示海域压制减伤
		local finalDamageAfterRepress = finalDamageBase * targetAttr.repressReduce

		if bulletRandomDamageRate ~= 0 then
			finalDamageAfterRepress = finalDamageAfterRepress * (Mathf.RandomFloat(bulletRandomDamageRate) + 1)
		end

		-- damageEnhanceProjectile
			-- 抛射物伤害提高，只有大型作战的极少数敌人会用到，形式为附加固定伤害提高(减少)
		local damageEnhanceProjectile = BattleAttr.GetCurrent(bullet, "damageEnhanceProjectile")
		local finalDamageBeforeFloor = math.max(0, finalDamageAfterRepress + damageEnhanceProjectile)

		if inWorld then
			finalDamageBeforeFloor = finalDamageBeforeFloor * (bfConsts.NUM1 + BattleAttr.GetCurrent(bullet, "worldBuffResistance"))
		end

		local finalDamage = math.floor(finalDamageBeforeFloor)
		local damageFont = bulletTemplate.DMG_font[targetArmorType]

		if damageEnhanceProjectile < 0 then
			damageFont = BattleConfig.BULLET_DECREASE_DMG_FONT
		end

		return finalDamage, extraInfo, damageFont
	end
end

--- @param bullet BattleBulletUnit
--- @param igniteAttribute string
--- @param igniteCoefficient number
--- @return number
--- 计算单次点燃的基础伤害
--- 这个伤害还需要加上DOTBuff的number参数等
	--- 关于参数orb:
	--- - 从调用来看传入的是_orb，来源于caster，caster明显是一个unit
	--- - BattleBulletUnit有GetWeapon()方法，也能通过BattleBulletUnit.SetAttr设置属性（使用host属性，详见BattleDataFunction.CreateBattleBulletData)
	--- - 待后续研究
function BattleFormulas.CalculateIgniteDamage(bullet, igniteAttribute, igniteCoefficient)
	local attrs = bullet._attr

	return bullet:GetWeapon():GetCorrectedDMG() * (1 + attrs[igniteAttribute] * bfConsts.PERCENT) * igniteCoefficient
end

--- @param weapon BattleWeaponUnit 
--- @param overrideDamage number
--- @return number
--- 计算武器修正后的标准伤害(标伤 * 武器效率 * 修正比例)
function BattleFormulas.WeaponDamagePreCorrection(weapon, overrideDamage)
	local weaponTemplate = weapon:GetTemplateData()
	local baseDamage = overrideDamage or weaponTemplate.damage
	local corrected = weaponTemplate.corrected

	return baseDamage * weapon:GetPotential() * corrected * bfConsts.PERCENT
end

--- @param weapon BattleWeaponUnit
--- @return number
--- 计算武器攻击属性的预设比例(即属性效率)
function BattleFormulas.WeaponAtkAttrPreRatio(weapon)
	return weapon:GetTemplateData().attack_attribute_ratio * bfConsts.PERCENT2
end

--- @param numMeteos number
--- @return table<number, number>
--- 计算给定数量的舰载机，返回每架舰载机所分配到的伤害比例
function BattleFormulas.GetMeteoDamageRatio(numMeteos)
	local meteoDamageRatios = {}
	local meteoRate = bfConsts.METEO_RATE
	-- baseMeteoRatio(=0.05)
	local baseMeteoRatio = meteoRate[1]

	-- meteoRate[2] = 20
	if numMeteos >= meteoRate[2] then
		for i = 1, numMeteos + 1 do
			meteoDamageRatios[i] = baseMeteoRatio
		end

		return meteoDamageRatios
	else
		local restMeteoRatio = 1 - baseMeteoRatio * numMeteos

		for i = 1, numMeteos do
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

--- @param fleetAntiAirUnit BattleFleetAntiAirUnit
--- @return number
--- 计算防空炮伤害
--- - 本质是计算所有防空炮的总伤害
--- - 单个防空炮的伤害基于host的防空值和武器相关属性来计算
--- - 与其他伤害乘区无关
function BattleFormulas.CalculateFleetAntiAirTotalDamage(fleetAntiAirUnit)
	local crewUnitList = fleetAntiAirUnit:GetCrewUnitList()
	local totalDamage = 0

	for crewUnit, weaponList in pairs(crewUnitList) do
		local antiAirPower = BattleAttr.GetCurrent(crewUnit, "antiAirPower")

		for _, weapon in ipairs(weaponList) do
			local weaponConvertedAtkAttr = weapon:GetConvertedAtkAttr()
			local weaponCorrectedDMG = weapon:GetCorrectedDMG()

			totalDamage = totalDamage + math.max(1, (antiAirPower * weaponConvertedAtkAttr + 1) * weaponCorrectedDMG)
		end
	end

	return totalDamage
end

--- @param repeater BattleRepeaterAntiAirUnit
--- @return number
--- 计算敌方防空舰对己方舰载机的伤害
--- - 与防空舰自己的防空值有关
--- - 和己方的防空炮伤害计算方法差不多的
function BattleFormulas.CalculateRepaterAnitiAirTotalDamage(repeater)
	local host = repeater:GetHost()
	local repeaterConvertedAtkAttr = repeater:GetConvertedAtkAttr()
	local repeaterCorrectedDMG = repeater:GetCorrectedDMG()
	local hostAntiAirPower = BattleAttr.GetCurrent(host, "antiAirPower")

	return (math.max(1, (hostAntiAirPower * repeaterConvertedAtkAttr + 1) * repeaterCorrectedDMG))
end

--- @param repeater BattleRepeaterAntiAirUnit
--- @param target BattleAircraftUnit
--- @return boolean: 是否回避成功
-- 计算己方舰载机对防空舰的回避情况
function BattleFormulas.RollRepeaterHitDice(repeater, target)
	local host = repeater:GetHost()
	local hostAntiAirPower = BattleAttr.GetCurrent(host, "antiAirPower")
	local hostAttackRating = math.max(BattleAttr.GetCurrent(host, "attackRating"), 0)
	local targetAirPower = BattleAttr.GetCurrent(target, "airPower")
	local targetDodgeLimit = BattleAttr.GetCurrent(target, "dodgeLimit")
	local targetDodge = BattleAttr.GetCurrent(target, "dodge")
	-- airPowerFactor
		-- AnitAirRepeaterConfig.const_A = 32
		-- AnitAirRepeaterConfig.const_B = 12
	-- aircraftDodgeRateBeforeLimit
		-- AnitAirRepeaterConfig.const_C = 220
	local airPowerFactor = targetAirPower / AnitAirRepeaterConfig.const_A + AnitAirRepeaterConfig.const_B
	local aircraftDodgeRateBeforeLimit = airPowerFactor / (hostAntiAirPower * targetDodge + airPowerFactor + AnitAirRepeaterConfig.const_C)
	local aircraftDodgeRate = math.min(targetDodgeLimit, aircraftDodgeRateBeforeLimit)

	return BattleFormulas.IsHappen(aircraftDodgeRate * bfConsts.NUM10000)
end

--- @param antiAirPower number
--- @return number
--- 计算防空值的平方
--- 暂时不太清楚这个防空权重的用处...
function BattleFormulas.AntiAirPowerWeight(antiAirPower)
	return antiAirPower * antiAirPower
end

--- @param attacker BattleAircraftUnit
--- @param target BattlePlayerUnit
--- @return number
--- 用于计算敌方飞机触底时对我方主力舰的伤害
function BattleFormulas.CalculateDamageFromAircraftToMainShip(attacker, target)
	local attackerAirPower = BattleAttr.GetCurrent(attacker, "airPower")
	local targetAntiAirPower = BattleAttr.GetCurrent(target, "antiAirPower")
	local attackerCrashDMG = BattleAttr.GetCurrent(attacker, "crashDMG")
	local attackerHPRate = attacker:GetHPRate()
	local attackerFormulaLevel = BattleAttr.GetCurrent(attacker, "formulaLevel")
	local targetFormulaLevel = BattleAttr.GetCurrent(target, "formulaLevel")
	local targetInjureRatio = BattleAttr.GetCurrent(target, "injureRatio")
	local targetInjureRatioByAir = BattleAttr.GetCurrent(target, "injureRatioByAir")
	local planeLeakRate = bfConsts.PLANE_LEAK_RATE
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

	return (math.floor(damage * BattleAttr.GetCurrent(target, "repressReduce") * BattleAttr.GetCurrent(target, "injureRatioKamikazeAir")))
end


--- @param attacker BattleEnemyUnit
--- @param target BattlePlayerUnit
--- @return number
--- 用于计算敌方自爆船触底时对我方主力舰的伤害
function BattleFormulas.CalculateDamageFromShipToMainShip(attacker, target)
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

	return (math.floor(damage * BattleAttr.GetCurrent(target, "repressReduce") * BattleAttr.GetCurrent(target, "injureRatioKamikazeShip")))
end

--- @param attacker BattleEnemyUnit
--- @param target BattlePlayerUnit
--- @return number
--- 用于计算敌方潜艇触底时对我方主力舰的伤害
function BattleFormulas.CalculateDamageFromSubmarinToMainShip(attacker, target)
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


--- @param target BattlePlayerUnit
--- @return boolean
--- 用于判定敌方潜艇自爆时我方主力舰是否闪避伤害
function BattleFormulas.RollSubmarineDualDice(target)
	-- targetDodgeProbability
		-- MONSTER_SUB_KAMIKAZE_DUAL_K = 50
		-- MONSTER_SUB_KAMIKAZE_DUAL_P = 0.15
	local targetDodgeRate = BattleAttr.GetCurrent(target, "dodgeRate")
	local targetDodgeProbability = targetDodgeRate / (targetDodgeRate + BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_K) * BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_P

	return BattleFormulas.IsHappen(targetDodgeProbability * bfConsts.NUM10000)
end

--- @param ship1 BattleUnit
--- @param ship2 BattleUnit
--- @return number, number
--- 计算碰撞伤害，敌我双方受到同样的伤害
function BattleFormulas.CalculateCrashDamage(ship1, ship2)
	local ship1MaxHP = BattleAttr.GetCurrent(ship1, "maxHP")
	local ship2MaxHP = BattleAttr.GetCurrent(ship2, "maxHP")
	-- CRASH_RATE[1] = 0.05
	local ship1CrashBaseDMG = ship1MaxHP * bfConsts.CRASH_RATE[1]
	local ship2CrashBaseDMG = ship2MaxHP * bfConsts.CRASH_RATE[1]

	local ship1HammerDamageRatio = BattleAttr.GetCurrent(ship1, "hammerDamageRatio")
	local ship2HammerDamageRatio = BattleAttr.GetCurrent(ship2, "hammerDamageRatio")

	local ship1HammerDamagePrevent = BattleAttr.GetCurrent(ship1, "hammerDamagePrevent")
	local ship2HammerDamagePrevent = BattleAttr.GetCurrent(ship2, "hammerDamagePrevent")
	-- PreventUpperBound = 0.8
	local ship1FinalHammerDamagePrevent = math.min(ship1HammerDamagePrevent, BattleConfig.HammerCFG.PreventUpperBound)
	local ship2FinalHammerDamagePrevent = math.min(ship2HammerDamagePrevent, BattleConfig.HammerCFG.PreventUpperBound)
	-- CRASH_RATE[2] = 0.025
	local crashDMGUpperBound = math.sqrt(ship1MaxHP * ship2MaxHP) * bfConsts.CRASH_RATE[2]

	local ship1FinalCrashBaseDMG = math.min(ship1CrashBaseDMG, crashDMGUpperBound)
	local ship2FinalCrashBaseDMG = math.min(ship2CrashBaseDMG, crashDMGUpperBound)

	local ship1FinalCrashDMGBeforeRepress = math.floor(ship1FinalCrashBaseDMG * (1 + ship2HammerDamageRatio) * (1 - ship1FinalHammerDamagePrevent))
	local ship1FinalCrashDMG = math.floor(ship1FinalCrashDMGBeforeRepress * BattleAttr.GetCurrent(ship1, "repressReduce"))

	local ship2FinalCrashDMGBeforeRepress = math.floor(ship2FinalCrashBaseDMG * (1 + ship1HammerDamageRatio) * (1 - ship2FinalHammerDamagePrevent))
	local ship2FinalCrashDMG = math.floor(ship2FinalCrashDMGBeforeRepress * BattleAttr.GetCurrent(ship2, "repressReduce"))

	return ship1FinalCrashDMG, ship2FinalCrashDMG
end

--- @param damage number
--- @return number
--- 暂时不知道拿来干什么
function BattleFormulas.CalculateFleetDamage(damage)
	-- SCORE_RATE[1] = 0.7
	return damage * bfConsts.SCORE_RATE[1]
end

--- @param fleet BattleFleetVO
--- @param ship BattleUnit
--- @return number
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

--- @param reloadMax number: 武器装填上限
--- @param loadSpeed number: 装填值
--- @return number: 装填时间(秒)
--- 根据Weapon的reloadMax和单位的loadSpeed计算实际的装填时间(单位:秒)
function BattleFormulas.CalculateReloadTime(reloadMax, loadSpeed)
	-- BattleConfig.K1 = 6
	-- BattleConfig.K2 = 100
	-- BattleConfig.K3 = 3.14
	-- 装填时间 = reloadMax / (6 * sqrt((loadSpeed + 100) * 3.14))
		-- 因此可以定义为装填速度 = 6 * sqrt((loadSpeed + 100) * 3.14)
		-- 容易看出装填速度与根号下(loadSpeed+100)成正比, 与reloadMax成反比
	return reloadMax / BattleConfig.K1 / math.sqrt((loadSpeed + BattleConfig.K2) * BattleConfig.K3)
end

--- @param reloadedTime number: 已经装填的时间(秒)
--- @param loadSpeed number: 装填值
--- @return number: 已经装填的进度
--- 根据实际的装填时间和单位的loadSpeed计算已经装填的进度
function BattleFormulas.CaclulateReloaded(reloadedTime, loadSpeed)
	return math.sqrt((loadSpeed + BattleConfig.K2) * BattleConfig.K3) * reloadedTime * BattleConfig.K1
end

--- @param reloadMax number: 武器装填上限
--- @param reloadRequire number: 目标装填时间
--- @return number: 需要的装填值
--- 根据Weapon的reloadMax和目标装填时间计算需要的loadSpeed
function BattleFormulas.CaclulateReloadAttr(reloadMax, reloadRequire)
	-- requireReloadSpeed
		-- 因为游戏中loadSpeed用来指的是装填值，为了避免混淆，这里就另用reloadSpeed表示"装填速度"
	local reloadSpeed = reloadMax / BattleConfig.K1 / reloadRequire

	return math.max(reloadSpeed * reloadSpeed / BattleConfig.K3 - BattleConfig.K2, 0)
end

--- @param hiveList table<number, BattleHiveUnit>
--- @return number
--- 计算一组空袭支援飞机的"平均"装填时间
--- 算法是计算所有飞机的reloadMax的平均值，然后乘以一个系数(2.2)
function BattleFormulas.CaclulateAirAssistReloadMax(hiveList)
	local totalReloadMax = 0

	for _, hive in ipairs(hiveList) do
		totalReloadMax = totalReloadMax + hive:GetTemplateData().reload_max
	end

	return totalReloadMax / #hiveList * airAssistReloadFactor
end

--- @param rant number: 在0~10000范围内的概率值
--- @param buffDOTeffectTable table<string, any>: DOT的effect配置表
--- @param orb BattleUnit: 施加DOT的单位
--- @param target BattleUnit: 受到DOT的单位
--- @return boolean: DOT效果是否命中/触发
-- 计算DOT效果是否命中/触发
function BattleFormulas.CaclulateDOTPlace(rant, buffDOTeffectTable, orb, target)
	local buffDOTargList = buffDOTeffectTable.arg_list
	-- 检查是否是只能在带有特定标签的目标身上触发
	if buffDOTargList.tagOnly and not target:ContainsLabelTag(buffDOTargList.tagOnly) then
		return false
	end

	local dotConfigOfType = BattleConfig.DOT_CONFIG[buffDOTargList.dotType]
	local dotAccuracy = orb and orb:GetAttrByName(dotConfigOfType.hit) or bfConsts.NUM0
	local targetDotResist = target and target:GetAttrByName(dotConfigOfType.resist) or bfConsts.NUM0

	return BattleFormulas.IsHappen(rant * (bfConsts.NUM1 + dotAccuracy) * (bfConsts.NUM1 - targetDotResist))
end

--- @param buffDOTeffectTable table<string, any>: DOT的effect配置表
--- @param orb BattleUnit: 施加DOT的单位
--- @param target BattleUnit: 受到DOT的单位
--- @return number: DOT效果的持续时间(单位:秒)
--- 计算DOT效果的持续时间
function BattleFormulas.CaclulateDOTDuration(buffDOTeffectTable, orb, target)
	local buffDOTargList = buffDOTeffectTable.arg_list
	local otConfigOfType = BattleConfig.DOT_CONFIG[buffDOTargList.dotType]

	return (orb and orb:GetAttrByName(otConfigOfType.prolong) or bfConsts.NUM0) - (target and target:GetAttrByName(otConfigOfType.shorten) or bfConsts.NUM0)
end

--- @param buffDOTeffectTable table<string, any>: DOT的effect配置表
--- @param orb BattleUnit: 施加DOT的单位
--- @param target BattleUnit: 受到DOT的单位
--- @return number: DOT效果的伤害增加(或减少)倍率
--- 计算DOT效果的伤害增加(或减少)倍率
function BattleFormulas.CaclulateDOTDamageEnhanceRate(buffDOTeffectTable, orb, target)
	local buffDOTargList = buffDOTeffectTable.arg_list
	local dotConfigOfType = BattleConfig.DOT_CONFIG[buffDOTargList.dotType]

	return ((orb and orb:GetAttrByName(dotConfigOfType.enhance) or bfConsts.NUM0) - (target and target:GetAttrByName(dotConfigOfType.reduce) or bfConsts.NUM0)) * bfConsts.PERCENT2
end

--- @param bossConfigId number: META BOSS的配置ID，例飞龙META是1，皇家方舟META是2...夕立META是20
--- @param bossLevel number: META BOSS的等级
--- @return number
--- 计算META作战时，支援攻击的伤害值
function BattleFormulas.CaclulateMetaDotaDamage(bossConfigId, bossLevel)
	-- metaBossTemplate(参考world_joint_boss_template.lua和world_boss_level.lua)
	-- 附注: 飞龙META对应1~15的world_boss_level，皇家方舟META对应16~30...以此类推
	local metaBossTemplate = ys.Battle.BattleDataFunction.GetMetaBossTemplate(bossConfigId)

	-- 表示这个META BOSS过期或常驻了
	if type(metaBossTemplate.state) == "string" then
		return 0
	end

	local metaBossState = metaBossTemplate.state
	local startTime = os.time({
		year = metaBossState[1][1][1],
		month = metaBossState[1][1][2],
		day = metaBossState[1][1][3],
		hour = metaBossState[1][2][1],
		minute = metaBossState[1][2][2],
		second = metaBossState[1][2][3]
	})
	local endTime = os.time({
		year = metaBossState[2][1][1],
		month = metaBossState[2][1][2],
		day = metaBossState[2][1][3],
		hour = metaBossState[2][2][1],
		minute = metaBossState[2][2][2],
		second = metaBossState[2][2][3]
	})
	-- totalDurationDays
		-- 这个天数是向下取整的，因此即使23小时59分钟59秒也算作0天
		-- 例如，夕立META从2025年9月4日0.0.0开始，到2025年12月11日23.59.59结束
		-- 总时长为98天23小时59分钟59秒，但totalDurationDays为98天
	-- elapsedDays
		-- 同理向下取整
	local totalDurationSeconds = os.difftime(endTime, startTime)
	local totalDurationDays = math.floor(totalDurationSeconds / 86400)
	local elapsedDays = math.floor(os.difftime(pg.TimeMgr.GetInstance():GetServerTime(), startTime) / 86400)
	local metaSupportAttackArgs = pg.gameset.world_metaboss_supportattack.description
	-- daysSupportStarts = 31
	-- daysSupportDamageMax = totalDurationDays - 15
		-- 这两个参数的意义是从计算公式推出来的
		-- 也即META支援在作战开启31天后开始生效，到离结束前16天支援伤害达到最大值
	local daysSupportStarts = metaSupportAttackArgs[1]
	local daysSupportDamageMax = totalDurationDays - metaSupportAttackArgs[2]
	-- expectDamageRatio = 0.15
		-- 表示支援攻击的期望总伤害占BOSS总血量的比例，这个参数的意义也是从计算公式推出来的
	-- randDamageRatio = 0.04
	-- dotHits = 15
	local expectDamageRatio = metaSupportAttackArgs[3]
	local randDamageRatio = metaSupportAttackArgs[4]
	local dotHits = metaSupportAttackArgs[5]
	local bossHP = ys.Battle.BattleDataFunction.GetMetaBossLevelTemplate(bossConfigId, bossLevel).hp
	-- metaDOTdamageBase
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

--- @param crewList table<number, BattleUnit>: 前排舰队
--- @return number
--- 计算前排的夜战隐蔽强度上限
--- - 前排被视为一个整体
--- -  夜战隐蔽表现为瞄准偏移(AimBias)，后续均使用该术语，与航母的隐匿值/被侦测计量条区分
function BattleFormulas.CalculateMaxAimBiasRange(crewList)
	-- aimBiasFleetRangeMod = 0.18
	local aimBiasFleetRangeMod = BattleConfig.AIM_BIAS_FLEET_RANGE_MOD
	local maxAimBiasRange

	if #crewList == 1 then
		local crew = crewList[1]
		-- ! 这里的机动值似乎是初始机动，后续考虑验证逻辑链
		maxAimBiasRange = BattleAttr.GetCurrent(crewList[1], "dodgeRate") * aimBiasFleetRangeMod
	else
		local dodgeRates = {}

		for _, crew in ipairs(crewList) do
			table.insert(dodgeRates, BattleAttr.GetCurrent(crew, "dodgeRate"))
		end

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

--- @param crewList table<number, BattleUnit>: 潜艇队伍
--- @return number
--- 计算潜艇的夜战隐蔽强度上限
--- - 与前排不同，潜艇的夜战隐蔽强度是单独计算的
function BattleFormulas.CalculateMaxAimBiasRangeSub(crewList)
	-- AIM_BIAS_SUB_RANGE_MOD = 0.18
	local maxAimBiasRange = BattleAttr.GetCurrent(crewList[1], "dodgeRate") * BattleConfig.AIM_BIAS_SUB_RANGE_MOD

	-- AIM_BIAS_MAX_RANGE_SUB = 25
	return (math.min(maxAimBiasRange, BattleConfig.AIM_BIAS_MAX_RANGE_SUB))
end

--- @param crewList table<number, BattleUnit>: 敌方单位
--- @return number
--- 计算敌方单位的夜战隐蔽强度上限
--- - 敌方单位也是单独计算的
function BattleFormulas.CalculateMaxAimBiasRangeMonster(crewList)
	-- AIM_BIAS_MONSTER_RANGE_MOD = 0.4
	local maxAimBiasRange = BattleAttr.GetCurrent(crewList[1], "dodgeRate") * BattleConfig.AIM_BIAS_MONSTER_RANGE_MOD

	-- AIM_BIAS_MAX_RANGE_MONSTER = 60
	return (math.min(maxAimBiasRange, BattleConfig.AIM_BIAS_MAX_RANGE_MONSTER))
end

--- @param attackRating number
--- @return number
--- 计算我方前排(和水面潜艇)的夜战隐蔽基础衰减速度
--- 参考调用链路：BattleBuffSmokeAimBias -> SetDecayFactor -> CalculateBiasDecay
function BattleFormulas.CalculateBiasDecay(attackRating)
	-- AIM_BIAS_DECAY_MOD_MONSTER = 0.01
	-- 从上层调用看到，这里的attackRating实际上是敌方全场的最高命中值
	local biasDecay = attackRating * BattleConfig.AIM_BIAS_DECAY_MOD_MONSTER
	-- AIM_BIAS_DECAY_SPEED_MAX_SCOUT = 3
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SCOUT))
end

--- @param attackRating number
--- @return number
--- 计算敌方单位的夜战隐蔽基础衰减速度
function BattleFormulas.CalculateBiasDecayMonster(attackRating)
	-- AIM_BIAS_DECAY_MOD = 0.01
	-- 从上层调用看到，这里的attackRating实际上是我方全场的最高命中值
	local biasDecay = attackRating * BattleConfig.AIM_BIAS_DECAY_MOD

	-- AIM_BIAS_DECAY_SPEED_MAX_MONSTER = 3
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER))
end

--- @param attackRating number
--- @return number
--- 计算敌方单位在烟雾中时的夜战隐蔽衰减速度
function BattleFormulas.CalculateBiasDecayMonsterInSmoke(attackRating)
	-- AIM_BIAS_DECAY_MOD = 0.01
	-- AIM_BIAS_DECAY_SMOKE = 1
		-- 实际上是没有变化的，可能是为了代码可读性，区分了不同场景
	-- 从上层调用看到，这里的attackRating实际上是我方全场的最高命中值
	local biasDecay = attackRating * BattleConfig.AIM_BIAS_DECAY_MOD * BattleConfig.AIM_BIAS_DECAY_SMOKE

	-- AIM_BIAS_DECAY_SPEED_MAX_MONSTER = 3
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER))
end

--- @param attackRating number
--- @return number
--- 计算我方潜艇的夜战隐蔽基础衰减速度
function BattleFormulas.CalculateBiasDecayDiving(attackRating)
	-- AIM_BIAS_DECAY_SUB_CONST = 50
	-- AIM_BIAS_DECAY_MOD = 0.01
	-- 从上层调用看到，这里的attackRating实际上是敌方全场的最高命中值
	local biasDecay = math.max(0, attackRating - BattleConfig.AIM_BIAS_DECAY_SUB_CONST) * BattleConfig.AIM_BIAS_DECAY_MOD

	-- AIM_BIAS_DECAY_SPEED_MAX_SUB = 100
	return (math.min(biasDecay, BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SUB))
end

--- @param enemyEnhancement number
--- @param enemyLevel number
--- @return number
--- 计算大型作战敌人属性提高倍率
function BattleFormulas.WorldEnemyAttrEnhance(enemyEnhancement, enemyLevel)
	-- WORLD_ENEMY_ENHANCEMENT_CONST_C = 1.1
	-- WORLD_ENEMY_ENHANCEMENT_CONST_B = 80
	return 1 + enemyEnhancement / (1 + BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_C^(BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_B - enemyLevel))
end

local cachedMapRewards = setmetatable({}, {
	__index = function(table, key)
		return 0
	end
})

--- @param enemyMapRewards table<number, number>
--- @param fleetMapRewards table<number, number>
--- @return number, number, number
--- 计算适应性Buff的属性增强倍率
--- 适应性似乎是用mapRewards来指代的...
function BattleFormulas.WorldMapRewardAttrEnhance(enemyMapRewards, fleetMapRewards)
	enemyMapRewards = enemyMapRewards or cachedMapRewards
	fleetMapRewards = fleetMapRewards or cachedMapRewards

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
	-- worldDamageFix = 0.1
	-- attr_world_damage_fix = 1000
	local worldDamageFix = gameset.attr_world_damage_fix.key_value / 10000
	local tempWorldAttrEnhance

	if enemyMapRewards[1] == 0 then
		tempWorldAttrEnhance = worldValueRanges[1][2]
	else
		tempWorldAttrEnhance = fleetMapRewards[1] / enemyMapRewards[1]
	end

	local finalWorldAttrEnhanceX = 1 - math.clamp(tempWorldAttrEnhance, worldValueRanges[1][1], worldValueRanges[1][2])

	if enemyMapRewards[2] == 0 then
		tempWorldAttrEnhance = worldValueRanges[2][2]
	else
		tempWorldAttrEnhance = fleetMapRewards[2] / enemyMapRewards[2]
	end

	local finalWorldAttrEnhanceY = 1 - math.clamp(tempWorldAttrEnhance, worldValueRanges[2][1], worldValueRanges[2][2])

	if enemyMapRewards[3] == 0 then
		tempWorldAttrEnhance = worldValueRanges[3][2]
	else
		tempWorldAttrEnhance = fleetMapRewards[3] / enemyMapRewards[3]
	end

	local finalWorldAttrEnhanceZ = math.max(1 - math.clamp(tempWorldAttrEnhance, worldValueRanges[3][1], worldValueRanges[3][2]), -worldDamageFix)

	return finalWorldAttrEnhanceX, finalWorldAttrEnhanceY, finalWorldAttrEnhanceZ
end

--- @param enemyMapRewards table<number, number>
--- @param fleetMapRewards table<number, number>
--- @return number
--- 计算适应性Buff的治疗倍率
function BattleFormulas.WorldMapRewardHealingRate(enemyMapRewards, fleetMapRewards)
	-- attr_world_value_H1 = 7000
	-- attr_world_value_H2 = 10000
	local worldHealingRateRange = {
		gameset.attr_world_value_H1.key_value / 10000,
		gameset.attr_world_value_H2.key_value / 10000
	}

	enemyMapRewards = enemyMapRewards or cachedMapRewards
	fleetMapRewards = fleetMapRewards or cachedMapRewards

	local tempWorldHealingRate

	if enemyMapRewards[3] == 0 then
		tempWorldHealingRate = worldHealingRateRange[2]
	else
		tempWorldHealingRate = fleetMapRewards[3] / enemyMapRewards[3]
	end

	return math.clamp(tempWorldHealingRate, worldHealingRateRange[1], worldHealingRateRange[2])
end

--- @return number, table<number, boolean>
--- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLock()
	return 0, {
		false,
		true,
		false
	}
end

--- @return number
--- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLockA2M()
	return 0
end

--- @return number
--- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLockS2M()
	return 0
end

--- @return number, number
--- 这个函数仅用于Debug，见BattleDebugConsole.lua
function BattleFormulas.CalcDamageLockCrush()
	return 0, 0
end

--- @return number, number
--- 用于BattleDodgemCommand，用途暂不明
function BattleFormulas.UnilateralCrush()
	return 0, 100000
end

--- @param repressReduce number
--- @return number
--- 计算普通图章节的压制减伤倍率
--- 这个传入的repressReduce对应压制层数 * chapter_template的mitigation_rate(一般为2)
--- 所以一般可认为，每层压制提供2%的伤害减免
function BattleFormulas.ChapterRepressReduce(repressReduce)
	return 1 - repressReduce * 0.01
end

--- @param rant number: 0~10000范围内的概率值
--- @return boolean
--- 判定概率是否发生，常用
--- 等价于rant%的概率发生，并向下取整到0.01%
function BattleFormulas.IsHappen(rant)
	if rant <= 0 then
		return false
	elseif rant >= 10000 then
		return true
	else
		return rant >= math.random(10000)
	end
end

--- @param weightRstList table<number, table<string, any>>: {weight = number, rst = any}的列表
--- @return any
--- 根据权重，随机选择一个结果
function BattleFormulas.WeightRandom(weightRstList)
	local weightList, totalWeight = BattleFormulas.GenerateWeightList(weightRstList)

	return (BattleFormulas.WeightListRandom(weightList, totalWeight))
end

--- @param weightList table<table<string, number>, any>: 权重区间列表
--- @param totalWeight number
--- @return any
--- 根据权重区间列表，随机选择一个结果
function BattleFormulas.WeightListRandom(weightList, totalWeight)
	local randomWeight = math.random(0, totalWeight)

	for weightRange, rst in pairs(weightList) do
		local minWeight = weightRange.min
		local maxWeight = weightRange.max

		if minWeight <= randomWeight and randomWeight <= maxWeight then
			return rst
		end
	end
end

--- @param weightRstList table<number, table<string, any>>: {weight = number, rst = any}的列表
--- @return table<table<string, number>, any>, number
--- 生成权重区间列表和总权重，用于权重随机选择
function BattleFormulas.GenerateWeightList(weightRstList)
	local weightList = {}
	local totalWeight = -1

	for _, weightRstPair in ipairs(weightRstList) do
		local weight = weightRstPair.weight
		local rst = weightRstPair.rst

		local minWeight = totalWeight + 1

		totalWeight = totalWeight + weight

		local maxWeight = totalWeight
		-- key是区间，value是对应的实体的列表
		weightList[{
			min = minWeight,
			max = maxWeight
		}] = rst
	end

	return weightList, totalWeight
end

--- @param list table<number, table<number, any>>: {rant = number, rst = any}的列表
--- @return boolean, any
--- 检查一组概率列表，判断是否有事件发生
--- 返回第一个发生的事件及其结果，否则返回false和nil、
--- 这个函数没有被用过。
function BattleFormulas.IsListHappen(list)
	for _, rantPair in ipairs(list) do
		if BattleFormulas.IsHappen(rantPair[1]) then
			return true, rantPair[2]
		end
	end

	return false, nil
end

--- @param targetPos Vector3
--- @param sourcePos Vector3
--- @return number
--- 计算子弹发射的XZ平面角度
--- = 180 / pi * arctan(dz/dx)，得到的是度数
--- 这个函数没有被用过。
function BattleFormulas.BulletYAngle(targetPos, sourcePos)
	return math.rad2Deg * math.atan2(sourcePos.z - targetPos.z, sourcePos.x - targetPos.x)
end

--- @param point table: 不知道是啥结构，只知道是一个表
--- @param quota number
--- @return table | nil
--- 这个函数没有被用过。
function BattleFormulas.RandomPosNull(point, quota)
	quota = quota or 10

	local distance = point.distance or 10
	local distanceSqr = distance * distance
	local allTargets = ys.Battle.BattleTargetChoise.TargetAll()

	for i = 1, quota do
		local canHit = true
		local randomPoint = BattleFormulas.RandomPos(point)

		for _, target in pairs(allTargets) do
			local position = target:GetPosition()

			if distanceSqr > Vector3.SqrDistance(randomPoint, position) then
				canHit = false

				break
			end
		end

		if canHit then
			return randomPoint
		end
	end

	return nil
end

--- @param point Vector3
--- @return Vector3
--- 计算一个随机位置
function BattleFormulas.RandomPos(point)
	local x = point[1] or 0
	local y = point[2] or 0
	local z = point[3] or 0

	if point.rangeX or point.rangeY or point.rangeZ then
		local deltaX = BattleFormulas.RandomDelta(point.rangeX)
		local deltaY = BattleFormulas.RandomDelta(point.rangeY)
		local deltaZ = BattleFormulas.RandomDelta(point.rangeZ)

		return Vector3(x + deltaX, y + deltaY, z + deltaZ)
	else
		local deltaX = BattleFormulas.RandomPosXYZ(point, "X1", "X2")
		local deltaY = BattleFormulas.RandomPosXYZ(point, "Y1", "Y2")
		local deltaZ = BattleFormulas.RandomPosXYZ(point, "Z1", "Z2")

		return Vector3(x + deltaX, y + deltaY, z + deltaZ)
	end
end

--- @param point Vector3
--- @param coordLeft string: 坐标左边界的键名
--- @param coordRight string: 坐标右边界的键名
--- @return number
--- 计算在指定坐标区间内的随机坐标值
function BattleFormulas.RandomPosXYZ(point, coordLeft, coordRight)
	coordLeft = point[coordLeft]
	coordRight = point[coordRight]

	if coordLeft and coordRight then
		return math.random(coordLeft, coordRight)
	else
		return 0
	end
end

--- @param point table: 不知道是啥结构，只知道是一个表
--- @return Vector3
--- 这个函数没有被用过。
function BattleFormulas.RandomPosCenterRange(point)
	local deltaX = BattleFormulas.RandomDelta(point.rangeX)
	local deltaY = BattleFormulas.RandomDelta(point.rangeY)
	local deltaZ = BattleFormulas.RandomDelta(point.rangeZ)

	return Vector3(deltaX, deltaY, deltaZ)
end
	
--- @param deltaRange number
--- @return number
--- 计算一个在[-deltaRange, +deltaRange]范围内的随机整数
function BattleFormulas.RandomDelta(deltaRange)
	if deltaRange and deltaRange > 0 then
		return math.random(deltaRange + deltaRange) - deltaRange
	else
		return 0
	end
end

--- @param argString string: 参数字符串
--- @param compareValue number: 用于比较的数值
--- @return boolean: 比较结果
--- 进行简单的数值比较
function BattleFormulas.simpleCompare(argString, compareValue)
	-- "%p+" 表示匹配一个或多个标点符号
	-- 这里的标点符号实际上是比较运算符，例如">=", "<"
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")
	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local valueString = string.sub(argString, punctuationStringEnd + 1, #argString)
	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local value = tonumber(valueString)

	return compareFunc(compareValue, value)
end

--- @param argString string: 参数字符串
--- @param leftUnit BattleUnit: 左侧单位
--- @param rightUnit BattleUnit: 右侧单位
--- @return boolean: 比较结果
--- 进行单位属性的比较
function BattleFormulas.parseCompareUnitAttr(argString, leftUnit, rightUnit)
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")

	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local leftValueString = string.sub(argString, 1, punctuationStringStart - 1)
	local rightValueString = string.sub(argString, punctuationStringEnd + 1, #argString)
	
	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local leftValue = tonumber(leftValueString) or leftUnit:GetAttrByName(leftValueString)
	local rightValue = tonumber(rightValueString) or rightUnit:GetAttrByName(rightValueString)

	return compareFunc(leftValue, rightValue)
end

--- @param argString string: 参数字符串
--- @param leftUnit BattleUnit: 左侧单位
--- @param rightUnit BattleUnit: 右侧单位
--- @return boolean: 比较结果
--- 进行单位模板属性的比较
function BattleFormulas.parseCompareUnitTemplate(argString, leftUnit, rightUnit)
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")

	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local leftValueString = string.sub(argString, 1, punctuationStringStart - 1)
	local rightValueString = string.sub(argString, punctuationStringEnd + 1, #argString)

	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local leftValue = tonumber(leftValueString) or leftUnit:GetTemplateValue(leftValueString)
	local rightValue = tonumber(rightValueString) or rightUnit:GetTemplateValue(rightValueString)

	return compareFunc(leftValue, rightValue)
end

--- @param argString string: 参数字符串
--- @param effect BattleBuffEffect: Buff效果实例
--- @return boolean: 比较结果
--- 进行Buff附加数据的比较
function BattleFormulas.parseCompareBuffAttachData(argString, effect)
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")

	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local effectName = string.sub(argString, 1, punctuationStringStart - 1)

	if effect.__name ~= effectName then
		return true
	end

	local value = tonumber(string.sub(argString, punctuationStringEnd + 1, #argString))
	local attachValue = effect:GetEffectAttachData()

	return getCompareFuncByPunctuation(punctuationString)(attachValue, value)
end

--- @param argString string: 参数字符串
--- @param fleetAttr BattleFleetAttrComponent: 舰队的总属性
--- @return boolean: 比较结果
--- 进行舰队属性的比较，比如进图要求检查
function BattleFormulas.parseCompare(argString, fleetAttr)
	local punctuationStringStart, punctuationStringEnd = string.find(argString, "%p+")

	local punctuationString = string.sub(argString, punctuationStringStart, punctuationStringEnd)
	local leftValueString = string.sub(argString, 1, punctuationStringStart - 1)
	local rightValueString = string.sub(argString, punctuationStringEnd + 1, #argString)

	local compareFunc = getCompareFuncByPunctuation(punctuationString)
	local leftValue = tonumber(leftValueString) or fleetAttr:GetCurrent(leftValueString)
	local rightValue = tonumber(rightValueString) or fleetAttr:GetCurrent(rightValueString)

	return compareFunc(leftValue, rightValue)
end

--- @param formulaString string: 计算公式字符串
--- @param fleetAttr BattleAttrComponent: 属性组件
--- @return number: 计算结果
--- 这个函数解析一个计算公式字符串，并计算出结果
--- 但我看了一眼，这个函数只在CardPuzzle中使用，而这是一个废弃的模式
function BattleFormulas.parseFormula(formulaString, fleetAttr)
	local variableTable = {}
	local operatorTable = {}

	-- "%w+%.?%w*" 表示匹配一个或多个字母数字字符，后面可选跟一个点号和一个或多个字母数字字符
	-- 这表示匹配变量名或数字
	for variable in string.gmatch(formulaString, "%w+%.?%w*") do
		table.insert(variableTable, variable)
	end

	-- "[^%w%.]" 表示匹配一个非字母数字且非点号的字符
	-- 这表示匹配运算符
	for operator in string.gmatch(formulaString, "[^%w%.]") do
		table.insert(operatorTable, operator)
	end

	-- 似乎是在构建一个中缀表达式的计算?
	local operatorsLeft = {}
	local valuesForCalc = {}
	local varIndex = 1
	local currentValue = variableTable[1]

	currentValue = tonumber(currentValue) or fleetAttr:GetCurrent(currentValue)

	for _, operator in ipairs(operatorTable) do
		varIndex = varIndex + 1

		local varValue = tonumber(variableTable[varIndex]) or fleetAttr:GetCurrent(variableTable[varIndex])

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

	local i = 1
	local resultValue = valuesForCalc[i]

	while i < #valuesForCalc do
		local operatorFunc = getArithmeticFuncByOperator(operatorsLeft[i])

		i = i + 1
		resultValue = operatorFunc(resultValue, valuesForCalc[i])
	end

	return resultValue
end
