ys = ys or {}
local BattleAttr = {}

ys.Battle.BattleAttr = BattleAttr
local BattleConst = ys.Battle.BattleConst

-- 舰载机/召唤物的属性继承列表
BattleAttr.AttrListInheritance = {
	"level",	        			-- 等级
	"formulaLevel",  				-- 用于公式计算的等级(考虑了安全海域)
	"repressReduce", 				-- 海域压制减伤
	"cannonPower",  				-- 炮击值
	"torpedoPower", 				-- 雷击值
	"antiAirPower", 				-- 防空值
	"airPower",     				-- 航空值
	"antiSubPower",					-- 反潜值
	"fleetGS",						-- 舰队实力
	"loadSpeed",					-- 装填值
	"attackRating",					-- 命中值
	"dodgeRate",				    -- 机动值
	"velocity",						-- 航速
	"luck",							-- 幸运值
	"cri",							-- 暴击率
	"criDamage",					-- 暴击伤害
	"criDamageResist",				-- 暴击伤害抵抗
	"hiveExtraHP",					-- 舰载机额外血量
	"GCT",							-- 必定暴击
	"bulletSpeedRatio",				-- 子弹速度倍率
	"torpedoSpeedExtra",			-- 鱼雷额外速度
	"damageRatioBullet",			-- 子弹伤害倍率
	"damageEnhanceProjectile",		-- 投射物伤害增强
	"healingEnhancement",			-- 治疗效果提升
	"injureRatio",					-- 受伤倍率
	"injureRatioByCannon",			-- 受炮击属性伤害倍率
	"injureRatioByBulletTorpedo", 	-- 受雷击属性伤害倍率
	"injureRatioByAir",				-- 受航空属性伤害倍率
	"damageRatioByCannon",			-- 炮击属性伤害倍率
	"damageRatioByBulletTorpedo",	-- 雷击属性伤害倍率
	"damageRatioByAir",				-- 航空属性伤害倍率
	"damagePreventRantTorpedo",		-- 鱼雷伤害减免率
	"accuracyRateExtra",			-- 额外命中率
	"dodgeRateExtra",				-- 额外闪避率
	"perfectDodge",					-- 必定闪避
	"immuneDirectHit",				-- 免疫触底攻击
	"chargeBulletAccuracy",			-- 跨射精度
	"dropBombAccuracy",				-- 航空炸弹精度
	"aircraftBooster",				-- 舰载机额外移速
	"manualEnhancement",			-- 手动增伤
	"initialEnhancement",			-- 首轮增伤
	"worldBuffResistance",			-- 大世界适应性的调整
	"airResistPierceActive",		-- 是否航空减伤穿透（航母隐匿）
	"airResistPierce"				-- 航空减伤穿透值
}

--- @param attrs table<any, string|nil>
--- @return nil
--- 将属性添加到可继承属性中
function BattleAttr.InsertInheritedAttr(attrs)
	for _, attr in pairs(attrs) do
		BattleAttr.AttrListInheritance[#BattleAttr.AttrListInheritance + 1] = attr
	end
end
-- 以下是动态添加的可继承属性
-- 1. 弹药伤害增强
BattleAttr.InsertInheritedAttr(ys.Battle.BattleConfig.AMMO_DAMAGE_ENHANCE)
-- 2. 受弹药伤害减免
BattleAttr.InsertInheritedAttr(ys.Battle.BattleConfig.AMMO_DAMAGE_REDUCE)
-- 3. 弹药对甲倍率增强
BattleAttr.InsertInheritedAttr(ys.Battle.BattleConfig.DAMAGE_AMMO_TO_ARMOR_RATE_ENHANCE)
-- 4. 对甲倍率增强
BattleAttr.InsertInheritedAttr(ys.Battle.BattleConfig.DAMAGE_TO_ARMOR_RATE_ENHANCE)
-- 5. 舰种命中率提高
BattleAttr.InsertInheritedAttr(ys.Battle.BattleConfig.SHIP_TYPE_ACCURACY_ENHANCE)
-- 此处是Tag的处理方式，通过定义通用前缀
BattleAttr.TAG_EHC_KEY = "DMG_TAG_EHC_"
BattleAttr.FROM_TAG_EHC_KEY = "DMG_FROM_TAG_"
BattleAttr.TAG_CRI_EHC_KEY = "CRI_TAG_EHC_"
BattleAttr.TAG_CRIDMG_EHC_KEY = "CRIDMG_TAG_EHC_"
BattleAttr.ATTACK_ATTR_TYPE = {
	[BattleConst.WeaponDamageAttr.CANNON] = "cannonPower",
	[BattleConst.WeaponDamageAttr.TORPEDO] = "torpedoPower",
	[BattleConst.WeaponDamageAttr.ANTI_AIR] = "antiAirPower",
	[BattleConst.WeaponDamageAttr.AIR] = "airPower",
	[BattleConst.WeaponDamageAttr.ANIT_SUB] = "antiSubPower"
}

--- @param attr table<string, number>: 属性表
--- @param attrType number: 参考BattleConst.WeaponDamageAttr
--- @return number
--- 获取对应的攻击属性的数值
function BattleAttr.GetAtkAttrByType(attr, attrType)
	local attackAttrString = BattleAttr.ATTACK_ATTR_TYPE[attrType]

	return math.max(attr[attackAttrString], 0)
end

--- @param host any: 可以是例如BattleUnit或BattleBulletUnit等
--- @param attr table<string, number>: 属性表
--- @return nil
--- 设置属性到host
function BattleAttr.SetAttr(host, attr)
	host._attr = setmetatable({}, {
		__index = attr
	})
end

--- @param host any: 可以是例如BattleUnit或BattleBulletUnit等
--- @return table<string, number>: 属性表
--- 获取host的属性表
function BattleAttr.GetAttr(host)
	return host._attr
end

--- @param host any
--- @return nil
--- 设置host的基础属性，通过克隆当前属性实现
--- - 当前属性之后的变化不会影响基础属性
function BattleAttr.SetBaseAttr(host)
	host._baseAttr = Clone(host._attr)
end

--- @param host any
--- @return boolean
--- 判定是否无敌
--- - 通过isInvincible属性判定
function BattleAttr.IsInvincible(host)
	local isInvincible = host._attr.isInvincible

	return isInvincible and isInvincible > 0
end

--- @param host any
--- @return nil
--- 施加无敌效果
--- - 增加isInvincible属性的值
function BattleAttr.AppendInvincible(host)
	local isInvincible = host._attr.isInvincible or 0

	host._attr.isInvincible = isInvincible + 1
end

--- @param host any
--- @param value number
--- @return nil
--- 这个函数没有被用过。
function BattleAttr.AddImmuneAreaLimit(host, value)
	local newImmuneAreaLimit = (host._attr.immuneAreaLimit or 0) + value

	host._attr.immuneAreaLimit = newImmuneAreaLimit

	host._move:ImmuneAreaLimit(newImmuneAreaLimit > 0)
end

--- @param host any
--- @param value number
--- @return nil
--- 这个函数没有被用过。
function BattleAttr.AddImmuneMaxAreaLimit(host, value)
	local newImmuneMaxAreaLimit = (host._attr.immuneMaxAreaLimit or 0) + value

	host._attr.immuneMaxAreaLimit = newImmuneMaxAreaLimit

	host._move:ImmuneMaxAreaLimit(newImmuneMaxAreaLimit > 0)
end

--- @param host any
--- @return boolean
--- 判定是否免疫区域限制
function BattleAttr.IsImmuneAreaLimit(host)
	local immuneAreaLimit = host._attr.immuneAreaLimit

	return immuneAreaLimit and immuneAreaLimit > 0
end

--- @param host any
--- @return boolean
--- 判定是否免疫最大区域限制
function BattleAttr.IsImmuneMaxAreaLimit(host)
	local immuneMaxAreaLimit = host._attr.immuneMaxAreaLimit

	return immuneMaxAreaLimit and immuneMaxAreaLimit > 0
end

--- @param host any
--- @return boolean
--- 判定是否可见（用于索敌）
function BattleAttr.IsVisitable(host)
	local isUnVisitable = host._attr.isUnVisitable

	return not isUnVisitable or isUnVisitable <= 0
end

--- @param host any
--- @return nil
--- 设置不可见
function BattleAttr.UnVisitable(host)
	local isUnVisitable = host._attr.isUnVisitable or 0

	host._attr.isUnVisitable = isUnVisitable + 1
end

--- @param host any
--- @return nil
--- 设置可见
function BattleAttr.Visitable(host)
	local isUnVisitable = host._attr.isUnVisitable or 0

	host._attr.isUnVisitable = isUnVisitable - 1
end

--- @param host any
--- @return boolean
--- 判定是否灵体状态(与死亡有关?)
function BattleAttr.IsSpirit(host)
	local isSpirit = host._attr.isSpirit

	return isSpirit and isSpirit > 0
end

--- @param host any
--- @return nil
--- 设置灵体状态
function BattleAttr.Spirit(host)
	local isSpirit = host._attr.isSpirit or 0

	host._attr.isSpirit = isSpirit + 1
end

--- @param host any
--- @return nil
--- 取消灵体状态，变为实体
function BattleAttr.Entity(host)
	local isSpirit = host._attr.isSpirit or 0

	host._attr.isSpirit = isSpirit - 1
end

--- @param host any
--- @return boolean
--- 判定是否被眩晕/停滞
function BattleAttr.IsStun(host)
	local isStun = host._attr.isStun

	return isStun and isStun > 0
end

--- @param host any
--- @return nil
--- 设置眩晕/停滞状态
function BattleAttr.Stun(host)
	local isStun = host._attr.isStun or 0

	host._attr.isStun = isStun + 1
end

--- @param host any
--- @return nil
--- 取消眩晕/停滞状态
function BattleAttr.CancelStun(host)
	local isStun = host._attr.isStun or 0

	host._attr.isStun = isStun - 1
end

--- @param host any
--- @return boolean
--- 判定是否处于隐匿状态
function BattleAttr.IsCloak(host)
	return (host._attr.isCloak or 0) == 1
end

--- @param host any
--- @return nil
--- 设置为隐匿状态
function BattleAttr.Cloak(host)
	host._attr.isCloak = 1
	host._attr.airResistPierceActive = 1
end

--- @param host any
--- @return nil
--- 设置为非隐匿状态(破隐)
function BattleAttr.Uncloak(host)
	host._attr.isCloak = 0
	host._attr.airResistPierceActive = 0
end

--- @param host any
--- @return boolean
--- 判定是否处于夜战隐蔽状态(这里是反过来的，返回true表示不在隐蔽状态)
function BattleAttr.IsLockAimBias(host)
	return (host._attr.lockAimBias or 0) >= 1
end

--- @param host any
--- @return boolean
--- 判定是否免疫碰撞(不参与碰撞检测)
function BattleAttr.IsUnitCldImmune(host)
	return (host._attr.unitCldImmune or 0) >= 1
end

--- @param host any
--- @return nil
--- 设置免疫碰撞状态
function BattleAttr.UnitCldImmune(host)
	local unitCldImmune = host._attr.unitCldImmune or 0

	host._attr.unitCldImmune = unitCldImmune + 1
end

--- @param host any
--- @return nil
--- 启用碰撞
function BattleAttr.UnitCldEnable(host)
	local unitCldImmune = host._attr.unitCldImmune or 0

	host._attr.unitCldImmune = unitCldImmune - 1
end

--- @param host any
--- @return string
--- 获取当前目标最高优先级的标签
function BattleAttr.GetCurrentTargetSelect(host)
	-- targetChoise
		-- targetChoise是目标身上具有的targetTag列表
		-- targetTag用于确定索敌方式
	local targetTag
	--- @type table<number, string>
	local targetChoise = BattleAttr.GetCurrent(host, "TargetChoise")
	--- @type table<string, number>
	local targetSelectPriority = ys.Battle.BattleConfig.TARGET_SELECT_PRIORITY

	-- 选出SelectPriority最高的tag
	-- 多个最高，则选第一个，因为后续不会更新
	for _, tag in ipairs(targetChoise) do
		if not targetTag or targetSelectPriority[tag] > targetSelectPriority[targetTag] then
			targetTag = tag
		end
	end

	return targetTag
end

--- @param host any
--- @param targetTag string
--- @return nil
--- 将tag添加到host的targetTag列表中
function BattleAttr.AddTargetSelect(host, targetTag)
	table.insert(BattleAttr.GetCurrent(host, "TargetChoise"), targetTag)
end

--- @param host any
--- @param targetTag string
--- @return nil
--- 移除tag从host的targetTag列表中
function BattleAttr.RemoveTargetSelect(host, targetTag)
	local targetChoise = BattleAttr.GetCurrent(host, "TargetChoise")

	for i, tag in ipairs(targetChoise) do
		if tag == targetTag then
			table.remove(targetChoise, i)

			break
		end
	end
end
--- @param host any
--- @return number|nil: 对应的是GetUniqueID,我猜是number,当然也可能string之类的，先按number处理
--- 获取当前对象的守护者ID(守护者机制指的是: 原本选择对象的攻击，会转而攻击守护者)
--- - 会返回守护者ID列表中的最后一个ID
function BattleAttr.GetCurrentGuardianID(host)
	local guardianList = BattleAttr.GetCurrent(host, "guardian")
	local guardianCount = #guardianList

	if guardianCount == 0 then
		return nil
	else
		return guardianList[guardianCount]
	end
end

--- @param host any
--- @param newGuardian number
--- @return nil
--- 将新守护者的ID添加到守护者列表中
function BattleAttr.AddGuardianID(host, newGuardian)
	local guardianList = BattleAttr.GetCurrent(host, "guardian")

	if not table.contains(guardianList, newGuardian) then
		table.insert(guardianList, newGuardian)
	end
end

--- @param host any
--- @param removeGuardian number
--- @return nil
--- 移除守护者ID从守护者列表中
function BattleAttr.RemoveGuardianID(host, removeGuardian)
	local guardianList = BattleAttr.GetCurrent(host, "guardian")

	for i, guardian in ipairs(guardianList) do
		if guardian == removeGuardian then
			table.remove(guardianList, i)

			return
		end
	end
end
--- @param playerUnit BattlePlayerUnit
--- @param templateData table
--- @param extraInfo table
--- @return nil
--- 设置战斗外属性
function BattleAttr.SetPlayerAttrFromOutBattle(playerUnit, templateData, extraInfo)
	local attr = playerUnit._attr or {}

	playerUnit._attr = attr
	-- 以下是所有战斗外属性
	attr.id = templateData.id
	attr.battleUID = playerUnit:GetUniqueID()
	attr.level = templateData.level
	attr.formulaLevel = templateData.level
	attr.maxHP = templateData.durability
	attr.HPRate = 1
	attr.DMGRate = 0
	attr.cannonPower = templateData.cannon
	attr.torpedoPower = templateData.torpedo
	attr.antiAirPower = templateData.antiaircraft
	attr.antiSubPower = templateData.antisub or 0
	attr.baseAntiSubPower = extraInfo and extraInfo.antisub or templateData.antisub
	attr.airPower = templateData.air
	attr.loadSpeed = templateData.reload
	attr.armorType = templateData.armorType
	attr.attackRating = templateData.hit
	attr.dodgeRate = templateData.dodge
	attr.velocity = ys.Battle.BattleFormulas.ConvertShipSpeed(templateData.speed)
	attr.baseVelocity = attr.velocity
	attr.luck = templateData.luck
	attr.repressReduce = templateData.repressReduce or 1
	attr.oxyMax = templateData.oxy_max
	attr.oxyCost = templateData.oxy_cost
	attr.oxyRecovery = templateData.oxy_recovery
	attr.oxyRecoverySurface = templateData.oxy_recovery_surface
	attr.oxyRecoveryBench = templateData.oxy_recovery_bench
	attr.oxyAtkDuration = templateData.attack_duration
	attr.raidDist = templateData.raid_distance
	attr.sonarRange = templateData.sonarRange or 0
	-- 隐匿基础上限 = 机动 + 50
	attr.cloakExposeBase = extraInfo and extraInfo.dodge + ys.Battle.BattleConfig.CLOAK_EXPOSE_CONST or 0
	attr.cloakExposeExtra = 0
	-- cloakRestore: 隐匿回复线，如果破隐，需要到此值之下才能回复隐匿
	-- CLOAK_BASE_RESTORE_DELTA = -60
	attr.cloakRestore = attr.cloakExposeBase + attr.cloakExposeExtra + ys.Battle.BattleConfig.CLOAK_BASE_RESTORE_DELTA
	-- cloakRecovery:隐匿回复速度(/s), = 5
	attr.cloakRecovery = ys.Battle.BattleConfig.CLOAK_RECOVERY
	-- cloakStrikeAdditive: 每次空袭额外增加的暴露值, = 6，即后续是基础+6*n
	attr.cloakStrikeAdditive = ys.Battle.BattleConfig.CLOAK_STRIKE_ADDITIVE
	-- 相同
	attr.cloakBombardAdditive = ys.Battle.BattleConfig.CLOAK_STRIKE_ADDITIVE
	-- 隐匿航空穿透：= 0.1
	attr.airResistPierce = ys.Battle.BattleConfig.BASE_ARP
	attr.aimBias = 0
	attr.aimBiasDecaySpeed = 0
	attr.aimBiasDecaySpeedRatio = 0
	attr.aimBiasExtraACC = 0
	attr.healingRate = 1
	attr.DMG_TAG_EHC_N_99 = templateData[AttributeType.AntiSiren] or 0
	attr.comboTag = "combo_" .. attr.battleUID
	attr.labelTag = {}
	attr.barrageCounterMod = 1
	attr.TargetChoise = {}
	attr.guardian = {}
	attr.injureRatioKamikazeAir = 1
	attr.injureRatioKamikazeShip = 1

	BattleAttr.SetBaseAttr(playerUnit)
end
-- TODO
function BattleAttr.AttrFixer(arg_35_0, arg_35_1)
	if arg_35_0 == SYSTEM_SCENARIO then
		arg_35_1.repressReduce = ys.Battle.BattleDataProxy.GetInstance():GetRepressReduce()
	elseif arg_35_0 == SYSTEM_DUEL or arg_35_0 == SYSTEM_SHAM then
		local var_35_0 = arg_35_1.level
		local var_35_1 = arg_35_1.durability
		local var_35_2, var_35_3 = ys.Battle.BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(arg_35_0, var_35_0)

		arg_35_1.durability = var_35_1 * var_35_2 + var_35_3
	end
end

function BattleAttr.InitDOTAttr(attr, templateData)
	local DOT_CONFIG_DEFAULT = ys.Battle.BattleConfig.DOT_CONFIG_DEFAULT
	local DOT_CONFIG = ys.Battle.BattleConfig.DOT_CONFIG

	for _, dotAttrTable in ipairs(DOT_CONFIG) do
		for baseDOTAttrName, DOTAttrName in pairs(dotAttrTable) do
			-- 如果是DOT命中率提高，则使用templateData中的值，否则使用默认值
			-- 默认值全是0
			if baseDOTAttrName == "hit" then
				attr[DOTAttrName] = templateData[DOTAttrName] or DOT_CONFIG_DEFAULT[baseDOTAttrName]
			else
				attr[DOTAttrName] = DOT_CONFIG_DEFAULT[baseDOTAttrName]
			end
		end
	end
end
-- 计算敌人属性
-- 第二个参数没用到，删掉了
function BattleAttr.SetEnemyAttr(enemy)
	local enemyTemplateData = enemy._tmpData
	local enemyLevel = enemy:GetLevel()
	local enemyAttr = enemy._attr or {}

	enemy._attr = enemyAttr
	enemyAttr.battleUID = enemy:GetUniqueID()
	enemyAttr.level = enemyLevel
	enemyAttr.formulaLevel = enemyLevel

	local growthRatio = (enemyLevel - 1) / 1000
	-- 注意点：
		-- 1. 敌人的属性计算中，耐久是向上取整的，而舰船是向下取整的
		-- 2. 敌人的属性计算中，其他属性都不取整，而舰船都是向下取整的（除了航速）
	enemyAttr.maxHP = math.ceil(enemyTemplateData.durability + enemyTemplateData.durability_growth * growthRatio)
	enemyAttr.HPRate = 1
	enemyAttr.DMGRate = 0
	enemyAttr.cannonPower = enemyTemplateData.cannon + enemyTemplateData.cannon_growth * growthRatio
	enemyAttr.torpedoPower = enemyTemplateData.torpedo + enemyTemplateData.torpedo_growth * growthRatio
	enemyAttr.antiAirPower = enemyTemplateData.antiaircraft + enemyTemplateData.antiaircraft_growth * growthRatio
	enemyAttr.airPower = enemyTemplateData.air + enemyTemplateData.air_growth * growthRatio
	enemyAttr.antiSubPower = enemyTemplateData.antisub + enemyTemplateData.antisub_growth * growthRatio
	enemyAttr.loadSpeed = enemyTemplateData.reload + enemyTemplateData.reload_growth * growthRatio
	enemyAttr.armorType = enemyTemplateData.armor_type
	enemyAttr.attackRating = enemyTemplateData.hit + enemyTemplateData.hit_growth * growthRatio
	enemyAttr.dodgeRate = enemyTemplateData.dodge + enemyTemplateData.dodge_growth * growthRatio
	enemyAttr.velocity = ys.Battle.BattleFormulas.ConvertShipSpeed(enemyTemplateData.speed + enemyTemplateData.speed_growth * growthRatio)
	enemyAttr.baseVelocity = enemyAttr.velocity
	enemyAttr.luck = enemyTemplateData.luck + enemyTemplateData.luck_growth * growthRatio
	enemyAttr.bulletSpeedRatio = 0
	enemyAttr.id = "enemy_" .. tostring(enemyTemplateData.id)
	enemyAttr.repressReduce = 1
	enemyAttr.healingRate = 1
	enemyAttr.comboTag = "combo_" .. enemyAttr.battleUID
	enemyAttr.labelTag = {}
	enemyAttr.TargetChoise = {}
	enemyAttr.guardian = {}

	BattleAttr.SetBaseAttr(enemy)
end

function BattleAttr.SetEnemyWorldEnhance(arg_38_0)
	local var_38_0 = arg_38_0._tmpData
	local var_38_1 = arg_38_0._attr
	local var_38_2 = var_38_1.level
	local var_38_3 = ys.Battle.BattleDataProxy.GetInstance()
	local var_38_4 = var_38_0.world_enhancement
	local var_38_5 = ys.Battle.BattleFormulas

	var_38_1.maxHP = var_38_1.maxHP * var_38_5.WorldEnemyAttrEnhance(var_38_4[1], var_38_2)
	var_38_1.cannonPower = var_38_1.cannonPower * var_38_5.WorldEnemyAttrEnhance(var_38_4[2], var_38_2)
	var_38_1.torpedoPower = var_38_1.torpedoPower * var_38_5.WorldEnemyAttrEnhance(var_38_4[3], var_38_2)
	var_38_1.antiAirPower = var_38_1.antiAirPower * var_38_5.WorldEnemyAttrEnhance(var_38_4[4], var_38_2)
	var_38_1.airPower = var_38_1.airPower * var_38_5.WorldEnemyAttrEnhance(var_38_4[5], var_38_2)
	var_38_1.attackRating = var_38_1.attackRating * var_38_5.WorldEnemyAttrEnhance(var_38_4[6], var_38_2)
	var_38_1.dodgeRate = var_38_1.dodgeRate * var_38_5.WorldEnemyAttrEnhance(var_38_4[7], var_38_2)

	local var_38_6 = var_38_3:GetInitData()
	local var_38_7, var_38_8, var_38_9 = var_38_5.WorldMapRewardAttrEnhance(var_38_6.EnemyMapRewards, var_38_6.FleetMapRewards)

	var_38_1.cannonPower = var_38_1.cannonPower * (1 + var_38_7)
	var_38_1.torpedoPower = var_38_1.torpedoPower * (1 + var_38_7)
	var_38_1.airPower = var_38_1.airPower * (1 + var_38_7)
	var_38_1.antiAirPower = var_38_1.antiAirPower * (1 + var_38_7)
	var_38_1.antiSubPower = var_38_1.antiSubPower * (1 + var_38_7)
	var_38_1.maxHP = math.ceil(var_38_1.maxHP * (1 + var_38_8))
	var_38_1.worldBuffResistance = var_38_9

	BattleAttr.SetBaseAttr(arg_38_0)
end

--- @param minion BattleMinionUnit
--- @return nil
--- 设置召唤物属性
--- 第二个参数没用，删掉了
function BattleAttr.SetMinionAttr(minion)
	local master = minion:GetMaster()
	local masterAttr = BattleAttr.GetAttr(master)
	local minionTemplateData = minion._tmpData
	local masterLevel = masterAttr.level
	local minionAttr = minion._attr or {}

	minion._attr = minionAttr
	minionAttr.battleUID = minion:GetUniqueID()
	-- 按照上述继承列表继承属性
	for _, inheritAttrName in ipairs(BattleAttr.AttrListInheritance) do
		minionAttr[inheritAttrName] = masterAttr[inheritAttrName]
	end
	-- 继承标记增伤属性
	for attrName, attrValue in pairs(masterAttr) do
		if string.find(attrName, BattleAttr.TAG_EHC_KEY) then
			minionAttr[attrName] = attrValue
		end
	end
	-- 继承标记暴击提高属性
	for attrName, attrValue in pairs(masterAttr) do
		if string.find(attrName, BattleAttr.TAG_CRI_EHC_KEY) then
			minionAttr[attrName] = attrValue
		end
	end
	-- 继承等级
	minionAttr.id = masterAttr.id
	minionAttr.level = masterLevel
	minionAttr.formulaLevel = masterLevel

	-- 下面的逻辑要覆盖掉上面继承的一些属性
	local function inheritAttr(tmpAttr, attrName)
		local attrGrowth = minionTemplateData[tmpAttr .. "_growth"]
		-- 如果是0，用模板里的基础属性
		if attrGrowth == 0 then
			minionAttr[attrName] = minionTemplateData[tmpAttr]
		-- 如果对应的成长属性是-1,表示直接继承master的该属性
		-- 注意耐久值继承的是master的当前血量而不是最大血量
		-- (这个逻辑也太随意了，template里写-1表示继承master，纯magic number...你要不用个boolean字段表示继承呢?)
		elseif attrGrowth == -1 then
			if tmpAttr == "durability" then
				minionAttr[attrName] = master:GetCurrentHP()
			else
				minionAttr[attrName] = masterAttr[attrName]
			end
		else
			-- 这表示的是按比例继承master的该属性
			-- 继承比例为(attrGrowth * 0.01)%
			minionAttr[attrName] = masterAttr[attrName] * attrGrowth * 0.0001
		end
	end

	minionAttr.HPRate = 1
	minionAttr.DMGRate = 0
	-- 左侧是战斗外属性名，右侧是战斗内属性名
	inheritAttr("durability", "maxHP")
	inheritAttr("cannon", "cannonPower")
	inheritAttr("torpedo", "torpedoPower")
	inheritAttr("antiaircraft", "antiAirPower")
	inheritAttr("air", "airPower")
	inheritAttr("antisub", "antiSubPower")
	inheritAttr("reload", "loadSpeed")
	inheritAttr("hit", "attackRating")
	inheritAttr("dodge", "dodgeRate")
	inheritAttr("luck", "luck")
	-- 重新设置装甲类型
	minionAttr.armorType = minionTemplateData.armor_type

	inheritAttr("speed", "velocity")
	-- 以下内容相当于没有继承
	minionAttr.velocity = ys.Battle.BattleFormulas.ConvertShipSpeed(minionAttr.velocity)
	minionAttr.baseVelocity = minionAttr.velocity
	minionAttr.bulletSpeedRatio = 0
	minionAttr.repressReduce = 1
	minionAttr.healingRate = 1
	minionAttr.comboTag = "combo_" .. minionAttr.battleUID
	minionAttr.labelTag = {}
	minionAttr.TargetChoise = {}
	minionAttr.guardian = {}

	BattleAttr.SetBaseAttr(minion)
end

function BattleAttr.IsWorldMapRewardAttrWarning(arg_41_0, arg_41_1)
	for iter_41_0 = 1, 3 do
		if arg_41_1[iter_41_0] / (arg_41_0[iter_41_0] ~= 0 and arg_41_0[iter_41_0] or 1) < pg.gameset.world_mapbuff_tips.key_value / 10000 then
			return true
		end
	end

	return false
end

--- @param battleType number
--- @param monster BattleEnemyUnit
--- @return nil
-- 修正怪物属性
-- 被BattleDataProxy.SpawnMonster调用
function BattleAttr.MonsterAttrFixer(battleType, monster)
	if battleType == SYSTEM_SCENARIO then
		local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
		local maxRepressLevel = battleDataProxy:IsCompletelyRepress() and battleDataProxy:GetRepressLevel() or 0
		local monsterLevel = BattleAttr.GetCurrent(monster, "level")
		-- 当安全海域时，怪物等级按压制等级降低
		BattleAttr.SetCurrent(monster, "formulaLevel", math.max(1, monsterLevel - maxRepressLevel))
	elseif battleType == SYSTEM_WORLD then
		BattleAttr.SetEnemyWorldEnhance(monster)
	end
end

-- 设置舰载机属性，从生成者继承
-- 这是一部分，下面的SetAircraftAttFromTemp是另一部分
function BattleAttr.SetAircraftAttFromMother(arg_43_0, arg_43_1)
	local var_43_0 = arg_43_0._attr or {}

	arg_43_0._attr = var_43_0
	var_43_0.battleUID = arg_43_0:GetUniqueID()
	var_43_0.hostUID = arg_43_1:GetUniqueID()

	if not type(arg_43_1._attr.id) == "string" or string.find(arg_43_1._attr.id, "enemy_") == nil then
		var_43_0.id = arg_43_1._attr.id
	end

	local var_43_1 = BattleAttr.GetAttr(arg_43_1)

	for iter_43_0, iter_43_1 in ipairs(BattleAttr.AttrListInheritance) do
		var_43_0[iter_43_1] = var_43_1[iter_43_1]
	end

	for iter_43_2, iter_43_3 in pairs(var_43_1) do
		if string.find(iter_43_2, BattleAttr.TAG_EHC_KEY) then
			var_43_0[iter_43_2] = iter_43_3
		end
	end

	for iter_43_4, iter_43_5 in pairs(var_43_1) do
		if string.find(iter_43_4, BattleAttr.TAG_CRI_EHC_KEY) then
			var_43_0[iter_43_4] = iter_43_5
		end
	end

	var_43_0.armorType = 0
	var_43_0.velocity = BattleAttr.GetCurrent(arg_43_1, "baseVelocity")
	var_43_0.labelTag = {}
	var_43_0.TargetChoise = {}
	var_43_0.guardian = {}
	var_43_0.comboTag = "combo_" .. var_43_0.hostUID
end

function BattleAttr.SetAircraftAttFromTemp(arg_44_0)
	arg_44_0._attr = arg_44_0._attr or {}

	local var_44_0 = BattleAttr.GetCurrent(arg_44_0, "hiveExtraHP")

	arg_44_0._attr.velocity = arg_44_0._attr.velocity or ys.Battle.BattleFormulas.ConvertAircraftSpeed(arg_44_0._tmpData.speed)

	local var_44_1 = arg_44_0._attr.level or 1

	arg_44_0._attr.maxHP = arg_44_0._attr.maxHP or arg_44_0._tmpData.max_hp + arg_44_0._tmpData.hp_growth / 1000 * (var_44_1 - 1) + var_44_0
	arg_44_0._attr.crashDMG = arg_44_0._tmpData.crash_DMG
	arg_44_0._attr.dodge = arg_44_0._tmpData.dodge
	arg_44_0._attr.dodgeLimit = arg_44_0._tmpData.dodge_limit
end
-- TODO
function BattleAttr.SetAirFighterAttr(arg_45_0, arg_45_1)
	local var_45_0 = arg_45_0._attr or {}

	arg_45_0._attr = var_45_0

	local var_45_1 = ys.Battle.BattleDataProxy.GetInstance()
	local var_45_2 = var_45_1:GetDungeonLevel()

	var_45_0.battleUID = arg_45_0:GetUniqueID()
	var_45_0.hostUID = 0
	var_45_0.id = 0
	var_45_0.level = var_45_2
	var_45_0.formulaLevel = var_45_2

	if var_45_1:IsCompletelyRepress() then
		var_45_0.formulaLevel = math.max(var_45_0.formulaLevel - 10, 1)
	end

	local var_45_3 = (var_45_2 - 1) / 1000

	var_45_0.maxHP = math.floor(arg_45_1.max_hp + arg_45_1.hp_growth * var_45_3)
	var_45_0.attackRating = arg_45_1.accuracy + arg_45_1.ACC_growth * var_45_3

	local var_45_4 = arg_45_1.attack_power + arg_45_1.AP_growth * var_45_3

	var_45_0.dodge = arg_45_1.dodge
	var_45_0.dodgeLimit = arg_45_1.dodge_limit
	var_45_0.cannonPower = var_45_4
	var_45_0.torpedoPower = var_45_4
	var_45_0.antiAirPower = var_45_4
	var_45_0.antiSubPower = var_45_4
	var_45_0.airPower = var_45_4
	var_45_0.loadSpeed = 0
	var_45_0.armorType = 1
	var_45_0.dodgeRate = 0
	var_45_0.luck = 50
	var_45_0.velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(arg_45_1.speed)
	var_45_0.repressReduce = 1
	var_45_0.TargetChoise = {}
	var_45_0.guardian = {}
	var_45_0.crashDMG = arg_45_1.crash_DMG
end

function BattleAttr.SetFusionAttrFromElement(arg_46_0, arg_46_1, arg_46_2, arg_46_3)
	local var_46_0 = BattleAttr.GetAttr(arg_46_1)
	local var_46_1 = var_46_0.level
	local var_46_2 = arg_46_0._attr or {}

	arg_46_0._attr = var_46_2
	var_46_2.id = var_46_0.id
	var_46_2.level = var_46_1
	var_46_2.formulaLevel = var_46_1
	var_46_2.battleUID = arg_46_0:GetUniqueID()

	for iter_46_0, iter_46_1 in ipairs(BattleAttr.AttrListInheritance) do
		var_46_2[iter_46_1] = var_46_0[iter_46_1]
	end

	for iter_46_2, iter_46_3 in pairs(var_46_0) do
		if string.find(iter_46_2, BattleAttr.TAG_EHC_KEY) then
			var_46_2[iter_46_2] = iter_46_3
		end
	end

	for iter_46_4, iter_46_5 in pairs(var_46_0) do
		if string.find(iter_46_4, BattleAttr.TAG_CRI_EHC_KEY) then
			var_46_2[iter_46_4] = iter_46_5
		end
	end

	local var_46_3 = arg_46_1:GetHP()

	for iter_46_6, iter_46_7 in ipairs(arg_46_2) do
		var_46_3 = var_46_3 + iter_46_7:GetHP()
	end

	var_46_2.maxHP = var_46_3
	var_46_2.hpProvideRate = {}
	var_46_2.hpProvideRate[BattleAttr.GetCurrent(arg_46_1, "id")] = arg_46_1:GetHP() / var_46_3

	for iter_46_8, iter_46_9 in ipairs(arg_46_2) do
		var_46_2.hpProvideRate[BattleAttr.GetCurrent(iter_46_9, "id")] = iter_46_9:GetHP() / var_46_3
	end

	local function var_46_4(arg_47_0)
		local var_47_0 = arg_46_3[arg_47_0] or 1

		var_46_2[arg_47_0] = BattleAttr.GetCurrent(arg_46_1, arg_47_0) * var_47_0
	end

	var_46_4("cannonPower")
	var_46_4("torpedoPower")
	var_46_4("antiAirPower")
	var_46_4("antiSubPower")
	var_46_4("baseAntiSubPower")
	var_46_4("airPower")
	var_46_4("loadSpeed")
	var_46_4("attackRating")
	var_46_4("dodgeRate")
	var_46_4("luck")
	var_46_4("velocity")
	var_46_4("baseVelocity")

	var_46_2.armorType = BattleAttr.GetCurrent(arg_46_1, "armorType")
	var_46_2.aimBias = 0
	var_46_2.aimBiasDecaySpeed = 0
	var_46_2.aimBiasDecaySpeedRatio = 0
	var_46_2.aimBiasExtraACC = 0
	var_46_2.healingRate = 1
	var_46_2.comboTag = "combo_" .. var_46_2.battleUID
	var_46_2.labelTag = {}
	var_46_2.barrageCounterMod = 1
	var_46_2.TargetChoise = {}
	var_46_2.guardian = {}

	BattleAttr.SetBaseAttr(arg_46_0)
end

function BattleAttr.FlashByBuff(arg_48_0, arg_48_1, arg_48_2)
	arg_48_0._attr[arg_48_1] = arg_48_2 + (arg_48_0._baseAttr[arg_48_1] or 0)

	if string.find(arg_48_1, BattleAttr.FROM_TAG_EHC_KEY) then
		local var_48_0 = 0

		for iter_48_0, iter_48_1 in pairs(arg_48_0._attr) do
			if string.find(iter_48_0, BattleAttr.FROM_TAG_EHC_KEY) and iter_48_1 ~= 0 then
				var_48_0 = 1

				break
			end
		end

		BattleAttr.SetCurrent(arg_48_0, BattleAttr.FROM_TAG_EHC_KEY, var_48_0)
	end
end
-- TODO
-- 航速上限1.8倍，下限0.2倍
function BattleAttr.FlashVelocity(unit, mulValue, addValue)
	local maxVelocity = BattleAttr.GetBase(unit, "velocity") * 1.8
	local minVelocity = BattleAttr.GetBase(unit, "velocity") * 0.2
	local velocityBeforeClamp = unit._baseAttr.velocity * mulValue + addValue
	local finalVelocity = Mathf.Clamp(velocityBeforeClamp, minVelocity, maxVelocity)

	BattleAttr.SetCurrent(unit, "velocity", finalVelocity)
end

function BattleAttr.HasSonar(arg_50_0)
	local var_50_0 = arg_50_0:GetTemplate().type

	return ys.Battle.BattleConfig.VAN_SONAR_PROPERTY[var_50_0] ~= nil
end

function BattleAttr.SetCurrent(arg_51_0, arg_51_1, arg_51_2)
	arg_51_0._attr[arg_51_1] = arg_51_2
end

--- @param host any
--- @param attrType string
--- @return any
--- 获取当前的属性值
function BattleAttr.GetCurrent(host, attrType)
	local isPrimalBattleAttr = AttributeType.IsPrimalBattleAttr(attrType) or false

	return BattleAttr._attrFunc[isPrimalBattleAttr](host, attrType)
end

--- @param host any
--- @param attrType string
--- @return number
--- 区别是主要属性最小值为0，且一定是数值
function BattleAttr._getPrimalAttr(host, attrType)
	return math.max(host._attr[attrType], 0)
end

--- @param host any
--- @param attrType string
--- @return any
--- 次要属性可能不是数值，如table
function BattleAttr._getSecondaryAttr(host, attrType)
	return host._attr[attrType] or 0
end

BattleAttr._attrFunc = {
	[true] = BattleAttr._getPrimalAttr,
	[false] = BattleAttr._getSecondaryAttr
}

function BattleAttr.GetBase(arg_55_0, arg_55_1)
	return arg_55_0._baseAttr[arg_55_1] or 0
end

function BattleAttr.GetCurrentTags(arg_56_0)
	return arg_56_0._attr.labelTag or {}
end

function BattleAttr.Increase(unit, attrType, number)
	if number then
		unit._attr[attrType] = (unit._attr[attrType] or 0) + number
	end
end

function BattleAttr.RatioIncrease(arg_58_0, arg_58_1, arg_58_2)
	if arg_58_2 then
		arg_58_0._attr[arg_58_1] = arg_58_0._attr[arg_58_1] + arg_58_0._baseAttr[arg_58_1] * arg_58_2 / 10000
	end
end

function BattleAttr.GetTagAttr(bullet, target, inWorld)
	local labelTagList = target:GetLabelTag()
	local tagEhcTable = {}

	for _, labelTag in ipairs(labelTagList) do
		tagEhcTable[BattleAttr.TAG_EHC_KEY .. labelTag] = true
	end

	local totalTagEhcValue = 1

	for tagEhcKey, _ in pairs(tagEhcTable) do
		local tagEhcValue = BattleAttr.GetCurrent(bullet, tagEhcKey)

		if tagEhcValue ~= 0 then
			if inWorld then
				tagEhcValue = ys.Battle.BattleDataFunction.GetLimitAttributeRange(tagEhcKey, tagEhcValue)
			end

			totalTagEhcValue = totalTagEhcValue * (1 + tagEhcValue)
		end
	end

	if BattleAttr.GetCurrent(target, BattleAttr.FROM_TAG_EHC_KEY) > 0 then
		local var_59_4 = bullet:GetWeaponTempData().attack_attribute
		local var_59_5 = BattleAttr.FROM_TAG_EHC_KEY .. var_59_4 .. "_"
		local var_59_6 = BattleAttr.GetCurrentTags(bullet)

		for iter_59_4, iter_59_5 in pairs(var_59_6) do
			if iter_59_5 > 0 then
				local var_59_7 = var_59_5 .. iter_59_4
				local var_59_8 = BattleAttr.GetCurrent(target, var_59_7)

				if var_59_8 ~= 0 then
					totalTagEhcValue = totalTagEhcValue * (1 + var_59_8)
				end
			end
		end
	end

	return totalTagEhcValue
end

function BattleAttr.GetTagAttrCri(arg_60_0, arg_60_1)
	local var_60_0 = arg_60_1:GetLabelTag()
	local var_60_1 = {}

	for iter_60_0, iter_60_1 in ipairs(var_60_0) do
		var_60_1[BattleAttr.TAG_CRI_EHC_KEY .. iter_60_1] = true
	end

	local var_60_2 = 0

	for iter_60_2, iter_60_3 in pairs(var_60_1) do
		local var_60_3 = BattleAttr.GetCurrent(arg_60_0, iter_60_2)

		if var_60_3 ~= 0 then
			var_60_2 = var_60_2 + var_60_3
		end
	end

	return var_60_2
end

function BattleAttr.GetTagAttrCriDmg(arg_61_0, arg_61_1)
	local var_61_0 = arg_61_1:GetLabelTag()
	local var_61_1 = {}

	for iter_61_0, iter_61_1 in ipairs(var_61_0) do
		var_61_1[BattleAttr.TAG_CRIDMG_EHC_KEY .. iter_61_1] = true
	end

	local var_61_2 = 0

	for iter_61_2, iter_61_3 in pairs(var_61_1) do
		local var_61_3 = BattleAttr.GetCurrent(arg_61_0, iter_61_2)

		if var_61_3 ~= 0 then
			var_61_2 = var_61_2 + var_61_3
		end
	end

	return var_61_2
end
