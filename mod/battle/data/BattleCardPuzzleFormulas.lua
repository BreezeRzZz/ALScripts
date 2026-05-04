ys.Battle.BattleCardPuzzleFormulas = ys.Battle.BattleCardPuzzleFormulas or {}

local BattleCardPuzzleFormulas = ys.Battle.BattleCardPuzzleFormulas
local BattleConst = ys.Battle.BattleConst
local gameset = pg.gameset
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local AnitAirRepeaterConfig = ys.Battle.BattleConfig.AnitAirRepeaterConfig
local bfConsts = pg.bfConsts
local AMMO_DAMAGE_ENHANCE = BattleConfig.AMMO_DAMAGE_ENHANCE
local AMMO_DAMAGE_REDUCE = BattleConfig.AMMO_DAMAGE_REDUCE

-- 自定义公式注册表
BattleCardPuzzleFormulas.CUSTOM_FORMULA = {
	double_energy = "energy*5+combo+2"
}

--- 卡牌谜题伤害计算上下文（BattleDataProxyLayer的CreateContextCalculateDamage）
--- @param casterWeapon BattleWeaponUnit 攻击方武器
--- @param targetUnit BattleUnit 目标单位
--- @param damageReduce number 伤害减免率
--- @param damageEnhance number 伤害增强率
--- @return number damage 最终伤害
--- @return table damageInfo 伤害信息（isMiss, isCri, damageAttr）
--- @return string dmgFont 伤害数字字体
function BattleCardPuzzleFormulas.CreateContextCalculateDamage(casterWeapon, targetUnit, damageReduce, damageEnhance)
	local NUM1 = bfConsts.NUM1
	local NUM0 = bfConsts.NUM0
	local NUM10000 = bfConsts.NUM10000
	local DRATE = bfConsts.DRATE
	local ACCURACY = bfConsts.ACCURACY
	local hostAttr = casterWeapon:GetWeaponHostAttr()
	local weapon = casterWeapon:GetWeapon()
	local weaponTempData = casterWeapon:GetWeaponTempData()
	local weaponType = weaponTempData.type
	local attackAttribute = weaponTempData.attack_attribute
	local convertedAtkAttr = weapon:GetConvertedAtkAttr()
	local bulletTemplate = casterWeapon:GetTemplate()
	local damageType = bulletTemplate.damage_type
	local randomDamageRate = bulletTemplate.random_damage_rate
	local targetAttr = targetUnit._attr
	local enhanceRate = damageEnhance or NUM1

	damageReduce = damageReduce or NUM0

	local armorType = targetAttr.armorType
	local formulaLevelDiff = hostAttr.formulaLevel - targetAttr.formulaLevel
	local critRate = NUM1
	local isMiss = false
	local isCrit = false
	local baseDamage = NUM1
	local correctedDMG = casterWeapon:GetCorrectedDMG()
	local rawDamage = (NUM1 + casterWeapon:GetWeaponAtkAttr() * convertedAtkAttr) * correctedDMG

	-- 根据攻击属性计算伤害倍率
	if attackAttribute == BattleConst.WeaponDamageAttr.CANNON then
		enhanceRate = NUM1 + BattleAttr.GetCurrent(targetUnit, "injureRatioByCannon") + BattleAttr.GetCurrent(casterWeapon, "damageRatioByCannon")
	elseif attackAttribute == BattleConst.WeaponDamageAttr.TORPEDO then
		enhanceRate = NUM1 + BattleAttr.GetCurrent(targetUnit, "injureRatioByBulletTorpedo") + BattleAttr.GetCurrent(casterWeapon, "damageRatioByBulletTorpedo")
	elseif attackAttribute == BattleConst.WeaponDamageAttr.AIR then
		local airResistPierce = BattleAttr.GetCurrent(casterWeapon, "airResistPierceActive") == 1 and BattleAttr.GetCurrent(casterWeapon, "airResistPierce") or 0

		enhanceRate = enhanceRate * math.min(DRATE[7] / (targetAttr.antiAirPower + DRATE[7]) + airResistPierce, 1) * (NUM1 + BattleAttr.GetCurrent(targetUnit, "injureRatioByAir") + BattleAttr.GetCurrent(casterWeapon, "damageRatioByAir"))
	elseif attackAttribute == BattleConst.WeaponDamageAttr.ANTI_AIR then
		-- block empty
	elseif attackAttribute == BattleConst.WeaponDamageAttr.ANIT_SUB then
		-- block empty
	end

	local luckDiff = hostAttr.luck - targetAttr.luck

	-- 完美闪避判定
	if BattleAttr.GetCurrent(targetUnit, "perfectDodge") == 1 then
		isMiss = true
	end

	if not isMiss then
		baseDamage = rawDamage

		-- 必暴判定
		if BattleAttr.GetCurrent(casterWeapon, "GCT") == 1 then
			isCrit = true
			critRate = math.max(1, bfConsts.DFT_CRIT_EFFECT + BattleAttr.GetCurrent(casterWeapon, "criDamage") - BattleAttr.GetCurrent(targetUnit, "criDamageResist"))
		else
			isCrit = false
		end
	else
		baseDamage = NUM0

		local missInfo = {
			isMiss = true,
			isDamagePrevent = false,
			isCri = isCrit
		}

		return baseDamage, missInfo
	end

	-- 伤害系数计算
	local ammoDamageRate = (weapon:GetFixAmmo() or damageType[armorType] or NUM1) + BattleAttr.GetCurrent(casterWeapon, BattleConfig.DAMAGE_AMMO_TO_ARMOR_RATE_ENHANCE[armorType])
	local armorRateEnhance = BattleAttr.GetCurrent(casterWeapon, BattleConfig.DAMAGE_TO_ARMOR_RATE_ENHANCE[armorType])
	local ammoDamageEnhance = BattleAttr.GetCurrent(casterWeapon, AMMO_DAMAGE_ENHANCE[bulletTemplate.ammo_type])
	local ammoDamageReduce = BattleAttr.GetCurrent(targetUnit, AMMO_DAMAGE_REDUCE[bulletTemplate.ammo_type])
	local comboTag = BattleAttr.GetCurrent(casterWeapon, "comboTag")
	local comboTagValue = BattleAttr.GetCurrent(targetUnit, comboTag)
	local finalDamage = math.max(NUM1, math.floor(baseDamage * enhanceRate * (NUM1 - damageReduce) * ammoDamageRate * (NUM1 + armorRateEnhance) * critRate * (NUM1 + BattleAttr.GetCurrent(casterWeapon, "damageRatioBullet")) * BattleAttr.GetTagAttr(casterWeapon, targetUnit) * (NUM1 + BattleAttr.GetCurrent(targetUnit, "injureRatio")) * (NUM1 + ammoDamageEnhance - ammoDamageReduce) * (NUM1 + comboTagValue) * (NUM1 + math.min(DRATE[1], math.max(-DRATE[1], formulaLevelDiff)) * DRATE[2])))

	-- 潜水状态反潜倍率
	if targetUnit:GetCurrentOxyState() == BattleConst.OXY_STATE.DIVE then
		finalDamage = math.floor(finalDamage * bulletTemplate.antisub_enhancement)
	end

	local damageInfo = {
		isMiss = isMiss,
		isCri = isCrit,
		damageAttr = attackAttribute
	}
	local damageEnhanceRatio = casterWeapon:GetDamageEnhance()

	if damageEnhanceRatio ~= 1 then
		finalDamage = math.floor(finalDamage * damageEnhanceRatio)
	end

	local repressDamage = finalDamage * targetAttr.repressReduce

	-- 随机伤害浮动
	if randomDamageRate ~= 0 then
		repressDamage = repressDamage * (Mathf.RandomFloat(randomDamageRate) + 1)
	end

	local damageEnhanceProjectile = BattleAttr.GetCurrent(casterWeapon, "damageEnhanceProjectile")
	local cardPuzzleDamage = math.max(0, repressDamage + damageEnhanceProjectile) * casterWeapon:GetWeaponCardPuzzleEnhance()
	local resultDamage = math.floor(cardPuzzleDamage)
	local dmgFont = bulletTemplate.DMG_font[armorType]

	-- 减益弹幕使用特殊伤害字体
	if damageEnhanceProjectile < 0 then
		dmgFont = BattleConfig.BULLET_DECREASE_DMG_FONT
	end

	return resultDamage, damageInfo, dmgFont
end

--- 解析比较表达式（如 "hp>50"），从属性管理器取值后比较
--- @param expr string 比较表达式
--- @param attrManager table 属性管理器
--- @return boolean 比较结果
function BattleCardPuzzleFormulas.parseCompare(expr, attrManager)
	local punctStart, punctEnd = string.find(expr, "%p+")
	local operator = string.sub(expr, punctStart, punctEnd)
	local leftOperand = string.sub(expr, 1, punctStart - 1)
	local rightOperand = string.sub(expr, punctEnd + 1, #expr)
	local compareFunc = getCompareFuncByPunctuation(operator)
	local leftValue = tonumber(leftOperand) or attrManager:GetCurrent(leftOperand)
	local rightValue = tonumber(rightOperand) or attrManager:GetCurrent(rightOperand)

	return compareFunc(leftValue, rightValue)
end

--- 解析计算公式字符串，先乘除后加减
--- @param formulaStr string 公式字符串（如 "energy*5+combo+2"）
--- @param attrManager table 属性管理器
--- @return number 计算结果
function BattleCardPuzzleFormulas.parseFormula(formulaStr, attrManager)
	local operands = {}  -- 操作数列表
	local operators = {}  -- 运算符列表

	-- 提取所有操作数（单词/数字）
	for token in string.gmatch(formulaStr, "%w+%.?%w*") do
		table.insert(operands, token)
	end

	-- 提取所有运算符（非单词/非点的字符）
	for op in string.gmatch(formulaStr, "[^%w%.]") do
		table.insert(operators, op)
	end

	local addSubOperands = {}  -- 加减操作数栈
	local addSubOperators = {}  -- 加减运算符栈
	local operandIndex = 1
	local currentValue = operands[1]

	currentValue = tonumber(currentValue) or attrManager:GetCurrent(currentValue)

	-- 第一遍：处理乘除，生成加减操作数列表
	for opIdx, op in ipairs(operators) do
		operandIndex = operandIndex + 1

		local nextValue = tonumber(operands[operandIndex]) or attrManager:GetCurrent(operands[operandIndex])

		if op == "+" or op == "-" then
			table.insert(addSubOperands, currentValue)

			currentValue = nextValue

			table.insert(addSubOperators, op)
		elseif op == "*" or op == "/" then
			-- 乘除优先级高，直接计算
			currentValue = getArithmeticFuncByOperator(op)(currentValue, nextValue)
		end
	end

	table.insert(addSubOperands, currentValue)

	-- 第二遍：顺序处理加减
	local i = 1
	local result = addSubOperands[i]

	while i < #addSubOperands do
		local func = getArithmeticFuncByOperator(addSubOperators[i])

		i = i + 1
		result = func(result, addSubOperands[i])
	end

	return result
end
