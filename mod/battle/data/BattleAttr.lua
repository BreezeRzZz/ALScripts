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
	"fleetGS",						-- 该舰队综合性能之和(不计算指挥喵)
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
	attr.baseScale = templateData.scale / 50
	attr.modelScale = attr.baseScale
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

-- note: 应用海域压制和演习耐久加成
-- BattleDataProxy.generatePlayerUnit等使用
function BattleAttr.AttrFixer(battleType, properties)
	if battleType == SYSTEM_SCENARIO then
		properties.repressReduce = ys.Battle.BattleDataProxy.GetInstance():GetRepressReduce()
	elseif battleType == SYSTEM_DUEL or battleType == SYSTEM_SHAM then
		local level = properties.level
		local durability = properties.durability
		local durabilityRatio, durabilityAdd = ys.Battle.BattleDataFunction.durabilityRatio(battleType, level)

		properties.durability = durability * durabilityRatio + durabilityAdd
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
-- 在BattleEnemyUnit.SetAttr中调用
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
	enemyAttr.baseScale = enemyTemplateData.scale / 50
	enemyAttr.modelScale = enemyAttr.baseScale
	enemyAttr.labelTag = {}
	enemyAttr.TargetChoise = {}
	enemyAttr.guardian = {}

	BattleAttr.SetBaseAttr(enemy)
end

-- 大世界敌人的属性增强
-- 被BattleAttr.MonsterAttrFixer调用
function BattleAttr.SetEnemyWorldEnhance(monster)
	local tmpData = monster._tmpData
	local attr = monster._attr
	local level = attr.level
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local world_enhancement = tmpData.world_enhancement
	local BattleFormulas = ys.Battle.BattleFormulas

	attr.maxHP = attr.maxHP * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[1], level)
	attr.cannonPower = attr.cannonPower * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[2], level)
	attr.torpedoPower = attr.torpedoPower * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[3], level)
	attr.antiAirPower = attr.antiAirPower * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[4], level)
	attr.airPower = attr.airPower * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[5], level)
	attr.attackRating = attr.attackRating * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[6], level)
	attr.dodgeRate = attr.dodgeRate * BattleFormulas.WorldEnemyAttrEnhance(world_enhancement[7], level)

	local initData = battleDataProxy:GetInitData()
	-- 计算适应性压制
	local attackEnhance, durabilityEnhance, worldBuffResistance = BattleFormulas.WorldMapRewardAttrEnhance(initData.EnemyMapRewards, initData.FleetMapRewards)

	attr.cannonPower = attr.cannonPower * (1 + attackEnhance)
	attr.torpedoPower = attr.torpedoPower * (1 + attackEnhance)
	attr.airPower = attr.airPower * (1 + attackEnhance)
	attr.antiAirPower = attr.antiAirPower * (1 + attackEnhance)
	attr.antiSubPower = attr.antiSubPower * (1 + attackEnhance)
	attr.maxHP = math.ceil(attr.maxHP * (1 + durabilityEnhance))
	attr.worldBuffResistance = worldBuffResistance

	BattleAttr.SetBaseAttr(monster)
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
	minionAttr.baseScale = minionTemplateData.scale / 50
	minionAttr.modelScale = minionAttr.baseScale

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
-- 注意调用的实际顺序是，先SetMotherUnit，然后SetTemplate
-- 因此部分在SetMotherUnit的属性会被Template覆盖掉
	-- 例如，舰载机的航速最终是模板的值，而不是母舰的值
	-- 另外，注意属性继承表中没有最大耐久，所以耐久总是用的模板计算的值
-- 被BattleAircraftUnit.SetAttr调用(重载)
function BattleAttr.SetAircraftAttFromMother(aircraft, mother)
	local attr = aircraft._attr or {}

	aircraft._attr = attr
	attr.battleUID = aircraft:GetUniqueID()
	attr.hostUID = mother:GetUniqueID()

	if not type(mother._attr.id) == "string" or string.find(mother._attr.id, "enemy_") == nil then
		attr.id = mother._attr.id
	end

	local motherAttr = BattleAttr.GetAttr(mother)
	-- 以下按照属性继承表继承属性(全新赋值，不是引用)
	for _, attrType in ipairs(BattleAttr.AttrListInheritance) do
		attr[attrType] = motherAttr[attrType]
	end

	for attrType, attrValue in pairs(motherAttr) do
		if string.find(attrType, BattleAttr.TAG_EHC_KEY) then
			attr[attrType] = attrValue
		end
	end

	for attrType, attrValue in pairs(motherAttr) do
		if string.find(attrType, BattleAttr.TAG_CRI_EHC_KEY) then
			attr[attrType] = attrValue
		end
	end
	-- 己方舰载机的护甲类型为无甲
	attr.armorType = 0
	attr.velocity = BattleAttr.GetCurrent(mother, "baseVelocity")
	attr.labelTag = {}
	attr.TargetChoise = {}
	attr.guardian = {}
	attr.comboTag = "combo_" .. attr.hostUID
end

-- 从模板设置舰载机属性
-- 由于BattleAirFighterUnit是从BattleAircraftUnit继承的
-- 所以BattleAirFighterUnit.SetTemplate -> BattleAircraftUnit.SetTemplate -> BattleAttr.SetAircraftAttFromTemp?
-- (这又会产生属性覆盖了...主要是耐久就总是不取整了) 
function BattleAttr.SetAircraftAttFromTemp(aircraft)
	aircraft._attr = aircraft._attr or {}

	local hiveExtraHP = BattleAttr.GetCurrent(aircraft, "hiveExtraHP")

	aircraft._attr.velocity = aircraft._attr.velocity or ys.Battle.BattleFormulas.ConvertAircraftSpeed(aircraft._tmpData.speed)

	local level = aircraft._attr.level or 1
	-- 己方飞机的耐久计算公式与敌方飞机不同，不取整?
	aircraft._attr.maxHP = aircraft._attr.maxHP or aircraft._tmpData.max_hp + aircraft._tmpData.hp_growth / 1000 * (level - 1) + hiveExtraHP
	aircraft._attr.crashDMG = aircraft._tmpData.crash_DMG
	-- dodge(闪避系数)和dodgeRate(机动)是两个不同的东西，不要搞混
	aircraft._attr.dodge = aircraft._tmpData.dodge
	aircraft._attr.dodgeLimit = aircraft._tmpData.dodge_limit
end

-- 用于计算敌方飞机的属性
-- 被BattleAirFighterUnit.SetAttr调用(重载)
function BattleAttr.SetAirFighterAttr(airFighter, tmpData)
	local attr = airFighter._attr or {}

	airFighter._attr = attr

	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local dungeonLevel = battleDataProxy:GetDungeonLevel()

	attr.battleUID = airFighter:GetUniqueID()
	attr.hostUID = 0
	attr.id = 0
	attr.level = dungeonLevel
	attr.formulaLevel = dungeonLevel

	-- 敌方飞机也会受到海域压制影响
	if battleDataProxy:IsCompletelyRepress() then
		attr.formulaLevel = math.max(attr.formulaLevel - 10, 1)
	end

	local growthFactor = (dungeonLevel - 1) / 1000

	attr.maxHP = math.floor(tmpData.max_hp + tmpData.hp_growth * growthFactor)
	attr.attackRating = tmpData.accuracy + tmpData.ACC_growth * growthFactor

	local attackPower = tmpData.attack_power + tmpData.AP_growth * growthFactor

	attr.dodge = tmpData.dodge
	attr.dodgeLimit = tmpData.dodge_limit
	attr.cannonPower = attackPower
	attr.torpedoPower = attackPower
	attr.antiAirPower = attackPower
	attr.antiSubPower = attackPower
	attr.airPower = attackPower
	attr.loadSpeed = 0
	attr.armorType = 1
	attr.dodgeRate = 0
	attr.luck = 50
	attr.velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(tmpData.speed)
	attr.repressReduce = 1
	attr.TargetChoise = {}
	attr.guardian = {}
	attr.crashDMG = tmpData.crash_DMG
end

-- 被BattleDataProxy.SpawnFusionUnit调用
-- fusion是融合体(例如，宝多六花、南梦芽、飞鸟川千濑的合体技能，会让前排的两艘船合体成一艘船)，该函数处理这个融合体的属性计算
function BattleAttr.SetFusionAttrFromElement(fusionUnit, caster, candidateList, attrInheritList)
	local casterAttr = BattleAttr.GetAttr(caster)
	local casterLevel = casterAttr.level
	local fusionAttr = fusionUnit._attr or {}

	fusionUnit._attr = fusionAttr
	fusionAttr.id = casterAttr.id
	fusionAttr.level = casterLevel
	fusionAttr.formulaLevel = casterLevel
	fusionAttr.battleUID = fusionUnit:GetUniqueID()
	-- 与召唤物、舰载机的继承逻辑一样
	for _, attrType in ipairs(BattleAttr.AttrListInheritance) do
		fusionAttr[attrType] = casterAttr[attrType]
	end

	for attrType, attrValue in pairs(casterAttr) do
		if string.find(attrType, BattleAttr.TAG_EHC_KEY) then
			fusionAttr[attrType] = attrValue
		end
	end

	for attrType, attrValue in pairs(casterAttr) do
		if string.find(attrType, BattleAttr.TAG_CRI_EHC_KEY) then
			fusionAttr[attrType] = attrValue
		end
	end

	local fusionMaxHP = caster:GetHP()
	-- 融合体的最大耐久是所有参与融合的单位当前耐久之和
	for _, candidate in ipairs(candidateList) do
		fusionMaxHP = fusionMaxHP + candidate:GetHP()
	end

	fusionAttr.maxHP = fusionMaxHP
	-- 每个参与融合的单位对融合体的耐久贡献比例
	fusionAttr.hpProvideRate = {}
	fusionAttr.hpProvideRate[BattleAttr.GetCurrent(caster, "id")] = caster:GetHP() / fusionMaxHP

	for _, candidate in ipairs(candidateList) do
		fusionAttr.hpProvideRate[BattleAttr.GetCurrent(candidate, "id")] = candidate:GetHP() / fusionMaxHP
	end

	local function FusionInheritAttrValue(attrType)
		-- 这个attrInheritList是调用该函数时传入的参数(来自BattleSkillFusion的attr_inherit_list字段)
		-- 实际表示的是，融合体继承Caster的各属性的比例(例如3，表示3倍继承). 默认是1倍继承
		local attrInheritRatio = attrInheritList[attrType] or 1

		fusionAttr[attrType] = BattleAttr.GetCurrent(caster, attrType) * attrInheritRatio
	end

	FusionInheritAttrValue("cannonPower")
	FusionInheritAttrValue("torpedoPower")
	FusionInheritAttrValue("antiAirPower")
	FusionInheritAttrValue("antiSubPower")
	FusionInheritAttrValue("baseAntiSubPower")
	FusionInheritAttrValue("airPower")
	FusionInheritAttrValue("loadSpeed")
	FusionInheritAttrValue("attackRating")
	FusionInheritAttrValue("dodgeRate")
	FusionInheritAttrValue("luck")
	FusionInheritAttrValue("velocity")
	FusionInheritAttrValue("baseVelocity")

	fusionAttr.armorType = BattleAttr.GetCurrent(caster, "armorType")
	fusionAttr.aimBias = 0
	fusionAttr.aimBiasDecaySpeed = 0
	fusionAttr.aimBiasDecaySpeedRatio = 0
	fusionAttr.aimBiasExtraACC = 0
	fusionAttr.healingRate = 1
	fusionAttr.comboTag = "combo_" .. fusionAttr.battleUID
	fusionAttr.labelTag = {}
	fusionAttr.barrageCounterMod = 1
	fusionAttr.TargetChoise = {}
	fusionAttr.guardian = {}

	BattleAttr.SetBaseAttr(fusionUnit)
end


-- note: 通过Buff更新属性的主函数
function BattleAttr.FlashByBuff(owner, attrType, newAttrValue)
	owner._attr[attrType] = newAttrValue + (owner._baseAttr[attrType] or 0)
	-- 特殊处理了FROM_TAG_EHC_KEY类属性(前缀)
	-- 概况的话，如果有任何一个标签增伤属性不为0，那么FROM_TAG_EHC_KEY就设为1，否则设为0
	-- 注意这里设置的不是任何一种特定的FROM_TAG_EHC_KEY，而是这个前缀本身
	-- 这相当于一种tag，表示是否存在标签增伤效果
	-- 这个特性在下面的BattleAttr.GetTagAttr中被使用
	if string.find(attrType, BattleAttr.FROM_TAG_EHC_KEY) then
		local fromTagEhcExists = 0

		for _attrType, _attrValue in pairs(owner._attr) do
			if string.find(_attrType, BattleAttr.FROM_TAG_EHC_KEY) and _attrValue ~= 0 then
				fromTagEhcExists = 1

				break
			end
		end

		BattleAttr.SetCurrent(owner, BattleAttr.FROM_TAG_EHC_KEY, fromTagEhcExists)
	end
end

-- 重新计算航速
-- 航速上限1.8倍，下限0.2倍
function BattleAttr.FlashVelocity(unit, mulValue, addValue)
	local maxVelocity = BattleAttr.GetBase(unit, "velocity") * 1.8
	local minVelocity = BattleAttr.GetBase(unit, "velocity") * 0.2
	local velocityBeforeClamp = unit._baseAttr.velocity * mulValue + addValue
	local finalVelocity = Mathf.Clamp(velocityBeforeClamp, minVelocity, maxVelocity)

	BattleAttr.SetCurrent(unit, "velocity", finalVelocity)
end

-- BattlePlayerCharacter.SonarAcitve
-- 判定该舰种是否有声呐属性
function BattleAttr.HasSonar(unitData)
	local unitType = unitData:GetTemplate().type

	return ys.Battle.BattleConfig.VAN_SONAR_PROPERTY[unitType] ~= nil
end

function BattleAttr.SetCurrent(host, attrType, attrValue)
	host._attr[attrType] = attrValue
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

-- 计算对某个tag的伤害增加(总效果)
-- 被BattleFormulas.CreateContextCalculateDamage调用
function BattleAttr.GetTagAttr(bullet, target, inWorld)
	local targetLabelTagSet = target:GetLabelTag()
	local tagEhcTable = {}

	for _, targetLabelTag in ipairs(targetLabelTagSet) do
		tagEhcTable[BattleAttr.TAG_EHC_KEY .. targetLabelTag] = true
	end

	local totalTagEhcValue = 1

	for tagEhcKey, _ in pairs(tagEhcTable) do
		-- 对于同tag的增伤，请参考BattleBuffAddAttr的处理方式：同tag加算，如果有group，则取group内最大值
		-- (这也是除了injureRatio以外的通用属性增伤处理方式)
		local tagEhcValue = BattleAttr.GetCurrent(bullet, tagEhcKey)

		if tagEhcValue ~= 0 then
			if inWorld then
				tagEhcValue = ys.Battle.BattleDataFunction.GetLimitAttributeRange(tagEhcKey, tagEhcValue)
			end
			-- 乘算
			totalTagEhcValue = totalTagEhcValue * (1 + tagEhcValue)
		end
	end

	if BattleAttr.GetCurrent(target, BattleAttr.FROM_TAG_EHC_KEY) > 0 then
		local attack_attribute = bullet:GetWeaponTempData().attack_attribute
		local fromTagEhcKeyPrefix = BattleAttr.FROM_TAG_EHC_KEY .. attack_attribute .. "_"
		local bulletTags = BattleAttr.GetCurrentTags(bullet)

		for bulletTag, bulletTagValue in pairs(bulletTags) do
			if bulletTagValue > 0 then
				local fromTagEhcKey = fromTagEhcKeyPrefix .. bulletTag
				local bulletTagEhcValue = BattleAttr.GetCurrent(target, fromTagEhcKey)
				-- 与之前的一起乘算
				if bulletTagEhcValue ~= 0 then
					totalTagEhcValue = totalTagEhcValue * (1 + bulletTagEhcValue)
				end
			end
		end
	end

	return totalTagEhcValue
end

-- 用于计算对某个tag的暴击率增加(总效果)
-- 被BattleFormulas.CreateContextCalculateDamage调用
function BattleAttr.GetTagAttrCri(bullet, target)
	local targetLabelTagList = target:GetLabelTag()
	local targetLabelTagSet = {}

	for _, targetLabelTag in ipairs(targetLabelTagList) do
		targetLabelTagSet[BattleAttr.TAG_CRI_EHC_KEY .. targetLabelTag] = true
	end

	local totalCriEhc = 0

	for criEhcKey, _ in pairs(targetLabelTagSet) do
		local criEhcValue = BattleAttr.GetCurrent(bullet, criEhcKey)
		-- 均为加算
		if criEhcValue ~= 0 then
			totalCriEhc = totalCriEhc + criEhcValue
		end
	end

	return totalCriEhc
end

-- 用于计算对某个tag的暴击伤害增加(总效果)
-- 被BattleFormulas.CreateContextCalculateDamage调用
function BattleAttr.GetTagAttrCriDmg(bullet, target)
	local targetLabelTagList = target:GetLabelTag()
	local targetLabelTagSet = {}

	for _, targetLabelTag in ipairs(targetLabelTagList) do
		targetLabelTagSet[BattleAttr.TAG_CRIDMG_EHC_KEY .. targetLabelTag] = true
	end

	local totalCriDmgEhc = 0

	for criDmgEhcKey, _ in pairs(targetLabelTagSet) do
		local tagCriDmgEhcValue = BattleAttr.GetCurrent(bullet, criDmgEhcKey)
		-- 均为加算
		if tagCriDmgEhcValue ~= 0 then
			totalCriDmgEhc = totalCriDmgEhc + tagCriDmgEhcValue
		end
	end

	return totalCriDmgEhc
end
