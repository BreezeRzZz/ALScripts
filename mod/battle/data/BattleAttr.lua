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
	attr.cloakExposeBase = extraInfo and extraInfo.dodge + ys.Battle.BattleConfig.CLOAK_EXPOSE_CONST or 0
	attr.cloakExposeExtra = 0
	attr.cloakRestore = attr.cloakExposeBase + attr.cloakExposeExtra + ys.Battle.BattleConfig.CLOAK_BASE_RESTORE_DELTA
	attr.cloakRecovery = ys.Battle.BattleConfig.CLOAK_RECOVERY
	attr.cloakStrikeAdditive = ys.Battle.BattleConfig.CLOAK_STRIKE_ADDITIVE
	attr.cloakBombardAdditive = ys.Battle.BattleConfig.CLOAK_STRIKE_ADDITIVE
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

	BattleAttr.SetBaseAttr(playerUnit)
end

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

function BattleAttr.InitDOTAttr(arg_36_0, arg_36_1)
	local var_36_0 = ys.Battle.BattleConfig.DOT_CONFIG_DEFAULT
	local var_36_1 = ys.Battle.BattleConfig.DOT_CONFIG

	for iter_36_0, iter_36_1 in ipairs(var_36_1) do
		for iter_36_2, iter_36_3 in pairs(iter_36_1) do
			if iter_36_2 == "hit" then
				arg_36_0[iter_36_3] = arg_36_1[iter_36_3] or var_36_0[iter_36_2]
			else
				arg_36_0[iter_36_3] = var_36_0[iter_36_2]
			end
		end
	end
end

function BattleAttr.SetEnemyAttr(arg_37_0, arg_37_1)
	local var_37_0 = arg_37_0._tmpData
	local var_37_1 = arg_37_0:GetLevel()
	local var_37_2 = arg_37_0._attr or {}

	arg_37_0._attr = var_37_2
	var_37_2.battleUID = arg_37_0:GetUniqueID()
	var_37_2.level = var_37_1
	var_37_2.formulaLevel = var_37_1

	local var_37_3 = (var_37_1 - 1) / 1000

	var_37_2.maxHP = math.ceil(var_37_0.durability + var_37_0.durability_growth * var_37_3)
	var_37_2.HPRate = 1
	var_37_2.DMGRate = 0
	var_37_2.cannonPower = var_37_0.cannon + var_37_0.cannon_growth * var_37_3
	var_37_2.torpedoPower = var_37_0.torpedo + var_37_0.torpedo_growth * var_37_3
	var_37_2.antiAirPower = var_37_0.antiaircraft + var_37_0.antiaircraft_growth * var_37_3
	var_37_2.airPower = var_37_0.air + var_37_0.air_growth * var_37_3
	var_37_2.antiSubPower = var_37_0.antisub + var_37_0.antisub_growth * var_37_3
	var_37_2.loadSpeed = var_37_0.reload + var_37_0.reload_growth * var_37_3
	var_37_2.armorType = var_37_0.armor_type
	var_37_2.attackRating = var_37_0.hit + var_37_0.hit_growth * var_37_3
	var_37_2.dodgeRate = var_37_0.dodge + var_37_0.dodge_growth * var_37_3
	var_37_2.velocity = ys.Battle.BattleFormulas.ConvertShipSpeed(var_37_0.speed + var_37_0.speed_growth * var_37_3)
	var_37_2.baseVelocity = var_37_2.velocity
	var_37_2.luck = var_37_0.luck + var_37_0.luck_growth * var_37_3
	var_37_2.bulletSpeedRatio = 0
	var_37_2.id = "enemy_" .. tostring(var_37_0.id)
	var_37_2.repressReduce = 1
	var_37_2.healingRate = 1
	var_37_2.comboTag = "combo_" .. var_37_2.battleUID
	var_37_2.labelTag = {}
	var_37_2.TargetChoise = {}
	var_37_2.guardian = {}

	BattleAttr.SetBaseAttr(arg_37_0)
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

function BattleAttr.SetMinionAttr(arg_39_0, arg_39_1)
	local var_39_0 = arg_39_0:GetMaster()
	local var_39_1 = BattleAttr.GetAttr(var_39_0)
	local var_39_2 = arg_39_0._tmpData
	local var_39_3 = var_39_1.level
	local var_39_4 = arg_39_0._attr or {}

	arg_39_0._attr = var_39_4
	var_39_4.battleUID = arg_39_0:GetUniqueID()

	for iter_39_0, iter_39_1 in ipairs(BattleAttr.AttrListInheritance) do
		var_39_4[iter_39_1] = var_39_1[iter_39_1]
	end

	for iter_39_2, iter_39_3 in pairs(var_39_1) do
		if string.find(iter_39_2, BattleAttr.TAG_EHC_KEY) then
			var_39_4[iter_39_2] = iter_39_3
		end
	end

	for iter_39_4, iter_39_5 in pairs(var_39_1) do
		if string.find(iter_39_4, BattleAttr.TAG_CRI_EHC_KEY) then
			var_39_4[iter_39_4] = iter_39_5
		end
	end

	var_39_4.id = var_39_1.id
	var_39_4.level = var_39_3
	var_39_4.formulaLevel = var_39_3

	local function var_39_5(arg_40_0, arg_40_1)
		local var_40_0 = var_39_2[arg_40_0 .. "_growth"]

		if var_40_0 == 0 then
			var_39_4[arg_40_1] = var_39_2[arg_40_0]
		elseif var_40_0 == -1 then
			if arg_40_0 == "durability" then
				var_39_4[arg_40_1] = var_39_0:GetCurrentHP()
			else
				var_39_4[arg_40_1] = var_39_1[arg_40_1]
			end
		else
			var_39_4[arg_40_1] = var_39_1[arg_40_1] * var_40_0 * 0.0001
		end
	end

	var_39_4.HPRate = 1
	var_39_4.DMGRate = 0

	var_39_5("durability", "maxHP")
	var_39_5("cannon", "cannonPower")
	var_39_5("torpedo", "torpedoPower")
	var_39_5("antiaircraft", "antiAirPower")
	var_39_5("air", "airPower")
	var_39_5("antisub", "antiSubPower")
	var_39_5("reload", "loadSpeed")
	var_39_5("hit", "attackRating")
	var_39_5("dodge", "dodgeRate")
	var_39_5("luck", "luck")

	var_39_4.armorType = var_39_2.armor_type

	var_39_5("speed", "velocity")

	var_39_4.velocity = ys.Battle.BattleFormulas.ConvertShipSpeed(var_39_4.velocity)
	var_39_4.baseVelocity = var_39_4.velocity
	var_39_4.bulletSpeedRatio = 0
	var_39_4.repressReduce = 1
	var_39_4.healingRate = 1
	var_39_4.comboTag = "combo_" .. var_39_4.battleUID
	var_39_4.labelTag = {}
	var_39_4.TargetChoise = {}
	var_39_4.guardian = {}

	BattleAttr.SetBaseAttr(arg_39_0)
end

function BattleAttr.IsWorldMapRewardAttrWarning(arg_41_0, arg_41_1)
	for iter_41_0 = 1, 3 do
		if arg_41_1[iter_41_0] / (arg_41_0[iter_41_0] ~= 0 and arg_41_0[iter_41_0] or 1) < pg.gameset.world_mapbuff_tips.key_value / 10000 then
			return true
		end
	end

	return false
end

function BattleAttr.MonsterAttrFixer(arg_42_0, arg_42_1)
	if arg_42_0 == SYSTEM_SCENARIO then
		local var_42_0 = ys.Battle.BattleDataProxy.GetInstance()
		local var_42_1 = var_42_0:IsCompletelyRepress() and var_42_0:GetRepressLevel() or 0
		local var_42_2 = BattleAttr.GetCurrent(arg_42_1, "level")

		BattleAttr.SetCurrent(arg_42_1, "formulaLevel", math.max(1, var_42_2 - var_42_1))
	elseif arg_42_0 == SYSTEM_WORLD then
		BattleAttr.SetEnemyWorldEnhance(arg_42_1)
	end
end

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

function BattleAttr.FlashVelocity(arg_49_0, arg_49_1, arg_49_2)
	local var_49_0 = BattleAttr.GetBase(arg_49_0, "velocity") * 1.8
	local var_49_1 = BattleAttr.GetBase(arg_49_0, "velocity") * 0.2
	local var_49_2 = arg_49_0._baseAttr.velocity * arg_49_1 + arg_49_2
	local var_49_3 = Mathf.Clamp(var_49_2, var_49_1, var_49_0)

	BattleAttr.SetCurrent(arg_49_0, "velocity", var_49_3)
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

function BattleAttr.Increase(arg_57_0, arg_57_1, arg_57_2)
	if arg_57_2 then
		arg_57_0._attr[arg_57_1] = (arg_57_0._attr[arg_57_1] or 0) + arg_57_2
	end
end

function BattleAttr.RatioIncrease(arg_58_0, arg_58_1, arg_58_2)
	if arg_58_2 then
		arg_58_0._attr[arg_58_1] = arg_58_0._attr[arg_58_1] + arg_58_0._baseAttr[arg_58_1] * arg_58_2 / 10000
	end
end

function BattleAttr.GetTagAttr(arg_59_0, arg_59_1, arg_59_2)
	local var_59_0 = arg_59_1:GetLabelTag()
	local var_59_1 = {}

	for iter_59_0, iter_59_1 in ipairs(var_59_0) do
		var_59_1[BattleAttr.TAG_EHC_KEY .. iter_59_1] = true
	end

	local var_59_2 = 1

	for iter_59_2, iter_59_3 in pairs(var_59_1) do
		local var_59_3 = BattleAttr.GetCurrent(arg_59_0, iter_59_2)

		if var_59_3 ~= 0 then
			if arg_59_2 then
				var_59_3 = ys.Battle.BattleDataFunction.GetLimitAttributeRange(iter_59_2, var_59_3)
			end

			var_59_2 = var_59_2 * (1 + var_59_3)
		end
	end

	if BattleAttr.GetCurrent(arg_59_1, BattleAttr.FROM_TAG_EHC_KEY) > 0 then
		local var_59_4 = arg_59_0:GetWeaponTempData().attack_attribute
		local var_59_5 = BattleAttr.FROM_TAG_EHC_KEY .. var_59_4 .. "_"
		local var_59_6 = BattleAttr.GetCurrentTags(arg_59_0)

		for iter_59_4, iter_59_5 in pairs(var_59_6) do
			if iter_59_5 > 0 then
				local var_59_7 = var_59_5 .. iter_59_4
				local var_59_8 = BattleAttr.GetCurrent(arg_59_1, var_59_7)

				if var_59_8 ~= 0 then
					var_59_2 = var_59_2 * (1 + var_59_8)
				end
			end
		end
	end

	return var_59_2
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
