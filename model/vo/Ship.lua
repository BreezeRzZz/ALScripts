local Ship = class("Ship", import(".BaseVO"))

Ship.ENERGY_MID = 40
Ship.ENERGY_LOW = 0
Ship.RECOVER_ENERGY_POINT = 2
Ship.INTIMACY_PROPOSE = 6
Ship.CONFIG_MAX_STAR = 6
Ship.BACKYARD_1F_ENERGY_ADDITION = 2
Ship.BACKYARD_2F_ENERGY_ADDITION = 3
Ship.PREFERENCE_TAG_NONE = 0
Ship.PREFERENCE_TAG_COMMON = 1

local fleetNames = {
	vanguard = i18n("word_vanguard_fleet"),
	main = i18n("word_main_fleet")
}

Ship.LOCK_STATE_UNLOCK = 0
Ship.LOCK_STATE_LOCK = 1
Ship.WEAPON_COUNT = 3
Ship.PREFAB_EQUIP = 4
Ship.MAX_SKILL_LEVEL = 10
Ship.ENERGY_RECOVER_TIME = 360
Ship.STATE_NORMAL = 1
Ship.STATE_REST = 2
Ship.STATE_CLASS = 3
Ship.STATE_COLLECT = 4
Ship.STATE_TRAIN = 5

local var_0_2 = 4
local var_0_3 = 100
local var_0_4 = 120
local ship_data_strengthen = pg.ship_data_strengthen
local ship_level = pg.ship_level
local equip_skin_template = pg.equip_skin_template
local ship_data_breakout = pg.ship_data_breakout

--- @param nationality number
--- @return string
--- 根据阵营，打印对应的简称
function nation2print(nationality)
	return Nation.Nation2Print(nationality)
end

--- @class Ship
--- @return number
--- 获取心情恢复速率
--- - 如果誓约，则为3，否则为2
function Ship.getRecoverEnergyPoint(self)
	return self.propose and 3 or 2
end

--- @param shipType number
--- @return string
--- 根据船只类型，获取对应的中文名称
--- - 对应到ship_data_by_type表的type_name字段
function shipType2name(shipType)
	return ShipType.Type2Name(shipType)
end

--- @param shipType number
--- @return string
--- 根据船只类型，获取对应的打印简称
function shipType2print(shipType)
	return ShipType.Type2Print(shipType)
end

--- @param shipType number
--- @return string
--- 根据船只类型，获取对应的战斗简称
function shipType2Battleprint(shipType)
	return ShipType.Type2BattlePrint(shipType)
end

--- @param skinID number
--- @return string
--- 根据皮肤ID，获取对应的背景图名称
function skinId2bgPrint(skinID)
	local bg = pg.ship_skin_template[skinID].rarity_bg

	if bg and bg ~= "" then
		return bg
	end
end

--- @class Ship
--- @param skinToUse number
--- @return boolean
--- 判断当前船只是否可以使用指定皮肤
function Ship.useSkin(self, skinToUse)
	local skinID = self:getSkinId()

	if skinID == skinToUse then
		return true
	end

	local originalGroupID = ShipSkin.GetChangeSkinGroupId(skinID)
	local AfterGroupID = ShipSkin.GetChangeSkinGroupId(skinToUse)

	if originalGroupID and AfterGroupID and originalGroupID == AfterGroupID then
		return true
	end

	return false
end

--- @class Ship
--- @return string
--- 根据稀有度/科研船/META船，获取对应的背景图名称
function Ship.rarity2bgPrint(self)
	return shipRarity2bgPrint(self:getRarity(), self:isBluePrintShip(), self:isMetaShip())
end

--- @class Ship
--- @return string
--- 获取当皮肤获取时的背景图名称
function Ship.rarity2bgPrintForGet(self)
	return skinId2bgPrint(self:getSkinId()) or self:rarity2bgPrint()
end

--- @class Ship
--- @param flag boolean
--- @return string
--- 获取当前船只的背景图名称
function Ship.getShipBgPrint(self, flag)
	local skinID = self:getSkinId()
	local template = pg.ship_skin_template[skinID]

	assert(template, "ship_skin_template not exist: " .. skinID)

	local bg

	if not flag and template.bg_sp and template.bg_sp ~= "" and PlayerPrefs.GetInt("paint_hide_other_obj_" .. template.painting, 0) == 0 then
		bg = template.bg_sp
	end

	return bg and bg or template.bg and #template.bg > 0 and template.bg or self:rarity2bgPrintForGet()
end

--- @class Ship
--- @return number
--- 获取舰船的星数
--- - 对应ship_data_statistics表中，对应舰船的的star字段
function Ship.getStar(self)
	return self:getConfig("star")
end

--- @class Ship
--- @return number
--- 获取舰船的最大星数
--- - 对应ship_data_template表中，对应舰船的的star_max字段
--- - 这里要说明一下：这两个表在同一configId上描述的舰船是同一个，但信息有所不同
--- - 实际运作时，是两个表配合起来得到完整的舰船信息
--- - 比如上面的star字段，在ship_data_statistics表中，而star_max字段在ship_data_template表中
function Ship.getMaxStar(self)
	return pg.ship_data_template[self.configId].star_max
end

--- @class Ship
--- @return number
--- 获取舰船的装甲类型
--- - 对应ship_data_statistics表中，对应舰船的的armor_type字段
--- - 含义参考ArmorType
function Ship.getShipArmor(self)
	return self:getConfig("armor_type")
end

--- @class Ship
--- @return string
--- 获取舰船的装甲类型名称
function Ship.getShipArmorName(self)
	local armorType = self:getShipArmor()

	return ArmorType.Type2Name(armorType)
end

--- @class Ship
--- @return number
--- 获取舰船的Group ID
--- - 对应ship_data_template表中，对应舰船的的group_type字段
--- - 关于Group ID: 同一舰船的不同突破形态或改造形态，都具有相同的Group ID，但她们的舰船ID（configId）是不同的
function Ship.getGroupId(self)
	return pg.ship_data_template[self.configId].group_type
end

--- @class Ship
--- @param configId number
--- @return number
--- 通过configId获取舰船的Group ID
--- - 提醒：有少数船并不满足这个规律，例如一些改造后更换了configId的船，但她的Group ID跟原来是一样的
function Ship.getGroupIdByConfigId(configId)
	return math.floor(configId / 10)
end

--- @class Ship
--- @param configId number
--- @return number
--- 通过configId获取舰船的改造后configId
function Ship.getTransformShipId(configId)
	local group = pg.ship_data_template[configId].group_type
	-- shipTransData: table<string, any>，记载的是该舰船的改造信息，主要是改造项目列表(transform_list)
	local shipTransData = pg.ship_data_trans[group]

	if shipTransData then
		for _, transform in ipairs(shipTransData.transform_list) do
			for _, transformStage in ipairs(transform) do
				-- transformStage[2]表示的是对应的改造项目ID，到transform_data_template表中去找
				local transformData = pg.transform_data_template[transformStage[2]]
				-- transformData的ship_id字段，记载的是该改造项目所涉及的舰船ID转换关系
				-- 从[1] -> [2]，表示从原configId转换到改造后configId(如有)
				for _, shipIDTrans in ipairs(transformData.ship_id) do
					if shipIDTrans[1] == configId then
						return shipIDTrans[2]
					end
				end
			end
		end
	end
end

--- @class Ship
--- @return table<number, number>
--- 获取舰载机数量
function Ship.getAircraftCount(self)
	-- 底座列表：从ship_data_statistics表中获取
	local base_list = self:getConfigTable().base_list
	-- 默认装备列表：从ship_data_statistics表中获取
	local default_equip_list = self:getConfigTable().default_equip_list
	local aircraftCounts = {}

	for i = 1, 3 do
		-- 获取1/2/3号位的装备，检查类型
		local equipment = self:getEquip(i) and self:getEquip(i).configId or default_equip_list[i]
		local equipType = Equipment.getConfigData(equipment).type
		-- 如果类型属于AirDomainEquip，则统计数量
		-- 将base_list[i]数量，累加到对应equipType的数量上
		if table.contains(EquipType.AirDomainEquip, equipType) then
			-- defaultValue: 若前者为nil，则返回后者，否则返回前者
			aircraftCounts[equipType] = defaultValue(aircraftCounts[equipType], 0) + base_list[i]
		end
	end

	return aircraftCounts
end

--- @class Ship
--- @return number
--- 获取舰船类型
--- - 含义参考ShipType
function Ship.getShipType(self)
	return self:getConfig("type")
end

--- @class Ship
--- @return number
--- 获取舰船的心情值
function Ship.getEnergy(self)
	return self.energy
end

--- @class Ship
--- @return table<string, any>
--- 获取心情配置
--- - 参考sharecfg/energy_template.lua
function Ship.getEnergeConfig(self)
	local energy_template = pg.energy_template
	local energy = self:getEnergy()

	for index, template in pairs(energy_template) do
		-- 判定：在[lower_bound, upper_bound]范围内
		if type(index) == "number" and energy >= template.lower_bound and energy <= template.upper_bound then
			return template
		end
	end

	assert(false, "疲劳配置不存在：" .. self.energy)
end

--- @class Ship
--- @return boolean
--- 判断舰船是否处于心情低落状态
--- - 对应是心情(Energy) <= 30
function Ship.isLowEnergy(self)
	return self:getEnergeConfig().id < 3
end

--- @class Ship
--- @return string, string
--- 获取心情图标和描述
function Ship.getEnergyPrint(self)
	local energyTemplate = self:getEnergeConfig()

	return energyTemplate.icon, energyTemplate.desc
end

--- @class Ship
--- @return number
--- 获取舰船的好感度
--- - 注意这个数值是原始数值，范围为0～20000
--- - 但实际的好感度表现是0～200（除以100），且誓约后上限为200
--- - 这样是为了保留更高的精度(0.01)，因为单次获得的好感度基本都是小于1的
function Ship.getIntimacy(self)
	return self.intimacy
end

--- @class Ship
--- @return number
--- 获取舰船的UI好感度
--- - 如果誓约，则在原有好感度基础上+1000？
function Ship.getCVIntimacy(self)
	return self:getIntimacy() / 100 + (self.propose and 1000 or 0)
end

--- @class Ship
--- @return number
--- 获取舰船的好感度上限
function Ship.getIntimacyMax(self)
	if self.propose then
		return 200
	else
		return self:GetNoProposeIntimacyMax()
	end
end

--- @class Ship
--- @return number
--- 获取未誓约时的好感度上限
function Ship.GetNoProposeIntimacyMax(self)
	return 100
end

--- @class Ship
--- @return string, string|nil
--- 获取好感度图标
function Ship.getIntimacyIcon(self)
	local template = pg.intimacy_template[self:getIntimacyLevel()]
	local suffix = ""

	if self:isMetaShip() then
		suffix = "_meta"
	elseif self:IsXIdol() then
		suffix = "_imas"
	end

	-- 100好感度且未誓约，显示爱心图标
	if not self.propose and math.floor(self:getIntimacy() / 100) >= self:getIntimacyMax() then
		return template.icon .. suffix, "heart" .. suffix
	else
		return template.icon .. suffix
	end
end

--- @class Ship
--- @return number, number
--- 获取好感度详情
--- - 返回值1：好感度上限
--- - 返回值2：当前UI好感度值
function Ship.getIntimacyDetail(self)
	return self:getIntimacyMax(), math.floor(self:getIntimacy() / 100)
end

--- @class Ship
--- @return string, string
--- 获取好感度图标和描述
function Ship.getIntimacyInfo(self)
	local template = pg.intimacy_template[self:getIntimacyLevel()]

	return template.icon, template.desc
end

--- @class Ship
--- @return number
--- 获取好感度等级
function Ship.getIntimacyLevel(self)
	local intimacyLevel = 0
	local intimacy_template = pg.intimacy_template

	for index, template in pairs(intimacy_template) do
		-- 判定：在[lower_bound, upper_bound]范围内
		if type(index) == "number" and self:getIntimacy() >= template.lower_bound and self:getIntimacy() <= template.upper_bound then
			intimacyLevel = index

			break
		end
	end

	if intimacyLevel < self.INTIMACY_PROPOSE and self.propose then
		intimacyLevel = self.INTIMACY_PROPOSE
	end

	return intimacyLevel
end

--- @class Ship
--- @return ShipBluePrint
--- 获取科研舰船对象
function Ship.getBluePrint(self)
	local shipBluePrint = ShipBluePrint.New({
		id = self.groupId
	})
	local strengthInfo = self.strengthList[1] or {
		exp = 0,
		level = 0
	}

	shipBluePrint:updateInfo({
		blue_print_level = strengthInfo.level,
		exp = strengthInfo.exp
	})

	return shipBluePrint
end

--- @class Ship
--- @return table<number, number>
--- 获取舰船底座列表
--- - 对于普通舰船，直接返回ship_data_statistics表中的base_list字段
--- - 对于科研舰船，则通过科研舰船对象获取底座列表，具体逻辑要看ShipBluePrint:getBaseList方法
function Ship.getBaseList(self)
	if self:isBluePrintShip() then
		local bluePrint = self:getBluePrint()

		assert(bluePrint, "blueprint can not be nil" .. self.configId)

		return bluePrint:getBaseList(self)
	else
		return self:getConfig("base_list")
	end
end

--- @class Ship
--- @return table<number, number>
--- 获取舰船(各武器槽)的预装填数量
function Ship.getPreLoadCount(self)
	if self:isBluePrintShip() then
		return self:getBluePrint():getPreLoadCount(self)
	else
		return self:getConfig("preload_count")
	end
end

--- @class Ship
--- @return number
--- 获取舰船所属阵营
function Ship.getNation(self)
	return self:getConfig("nationality")
end

--- @class Ship
--- @return string
--- 获取舰船皮肤的立绘名称
function Ship.getPaintingName(self)
	local skin_id = pg.ship_data_statistics[self].skin_id
	local skin_template = pg.ship_skin_template[skin_id]

	assert(skin_template, "ship_skin_template not exist: " .. self .. " " .. skin_id)

	return skin_template.painting
end

--- @class Ship
--- @return string
--- 获取舰船名称
function Ship.getName(self)
	-- 如果已誓约，且允许自定义名称，则返回自定义名称
	if self.propose and pg.PushNotificationMgr.GetInstance():isEnableShipName() then
		return self.name
	end

	--- 如果改造过，返回改造后的名称
	if self:isRemoulded() then
		return pg.ship_skin_template[self:getRemouldSkinId()].name
	end
	-- 返回默认名称
	return pg.ship_data_statistics[self.configId].name
end

--- @class Ship
--- @return string
--- 获取舰船默认名称
--- - 和上面的getName方法有很多重叠
function Ship.GetDefaultName(self)
	if self:isRemoulded() then
		return pg.ship_skin_template[self:getRemouldSkinId()].name
	else
		return pg.ship_data_statistics[self.configId].name
	end
end

--- @class Ship
--- @param configId number
--- @return string
--- 获取舰船的最基础名称
function Ship.getShipName(configId)
	return pg.ship_data_statistics[configId].name
end

--- @class Ship
--- @param configId number
--- @return number
--- 获取舰船突破等级
--- - 等价获取星数
function Ship.getBreakOutLevel(configId)
	assert(configId, "必须存在配置id")
	assert(pg.ship_data_statistics[configId], "必须存在配置" .. configId)

	return pg.ship_data_statistics[configId].star
end

function Ship.Ctor(self, args)
	self.id = args.id
	self.configId = args.template_id or args.configId
	self.level = args.level
	self.exp = args.exp
	self.energy = args.energy
	self.lockState = args.is_locked
	self.intimacy = args.intimacy
	self.propose = args.propose and args.propose > 0
	self.proposeTime = args.propose
	-- 强制上限
	if self.intimacy and self.intimacy > 10000 and not self.propose then
		self.intimacy = 10000
	end

	self.renameTime = args.change_name_timestamp

	if args.name and args.name ~= "" then
		self.name = args.name
	else
		assert(pg.ship_data_statistics[self.configId], "必须存在配置" .. self.configId)
		-- 默认名称
		self.name = pg.ship_data_statistics[self.configId].name
	end

	arg_41_0.groupId = pg.ship_data_template[arg_41_0.configId].group_type

	local var_41_0 = pg.ship_data_group.get_id_list_by_group_type[arg_41_0.groupId][1]

	arg_41_0.bluePrintFlag = pg.ship_data_group[var_41_0].handbook_type == 2
	arg_41_0.strengthList = {}

	for iter_41_0, iter_41_1 in ipairs(arg_41_1.strength_list or {}) do
		if not arg_41_0:isBluePrintShip() then
			local var_41_1 = ShipModAttr.ID_TO_ATTR[iter_41_1.id]

			arg_41_0.strengthList[var_41_1] = iter_41_1.exp
		else
			table.insert(self.strengthList, {
				level = iter_41_1.id,
				exp = iter_41_1.exp
			})
		end
	end

	local var_41_2 = arg_41_1.state or {}

	arg_41_0.state = var_41_2.state or 0
	arg_41_0.state_info_1 = var_41_2.state_info_1 or 0
	arg_41_0.state_info_2 = var_41_2.state_info_2 or 0
	arg_41_0.state_info_3 = var_41_2.state_info_3 or 0
	arg_41_0.state_info_4 = var_41_2.state_info_4 or 0
	arg_41_0.equipmentSkins = {}
	arg_41_0.equipments = {}

	if args.equip_info_list then
		for i, equipInfo in ipairs(args.equip_info_list or {}) do
			self.equipments[i] = equipInfo.id > 0 and Equipment.New({
				count = 1,
				id = equipInfo.id,
				config_id = equipInfo.id,
				skinId = equipInfo.skinId
			}) or false
			self.equipmentSkins[i] = equipInfo.skinId > 0 and equipInfo.skinId or 0

			self:reletiveEquipSkin(i)
		end
	end

	self.spWeapon = nil

	if args.spweapon then
		self:UpdateSpWeapon(SpWeapon.CreateByNet(args.spweapon))
	end

	self.skills = {}

	for _, skillID in ipairs(args.skill_id_list or {}) do
		self:updateSkill(skillID)
	end

	self.star = self:getConfig("rarity")
	self.transforms = {}

	for _, transform in ipairs(args.transform_list or {}) do
		self.transforms[transform.id] = {
			id = transform.id,
			level = transform.level
		}
	end

	arg_41_0.createTime = arg_41_1.create_time or 0

	local var_41_3 = getProxy(CollectionProxy)

	arg_41_0.virgin = var_41_3 and var_41_3.shipGroups[arg_41_0.groupId] == nil

	local var_41_4 = {
		pg.gameset.test_ship_config_1.key_value,
		pg.gameset.test_ship_config_2.key_value,
		pg.gameset.test_ship_config_3.key_value
	}
	local var_41_5 = table.indexof(var_41_4, arg_41_0.configId)

	if var_41_5 == 1 then
		arg_41_0.testShip = {
			2,
			3,
			4
		}
	elseif var_41_5 == 2 then
		arg_41_0.testShip = {
			5
		}
	elseif var_41_5 == 3 then
		arg_41_0.testShip = {
			6
		}
	else
		self.testShip = nil
	end
	-- 20000
	self.maxIntimacy = pg.intimacy_template[#pg.intimacy_template.all].upper_bound

	arg_41_0.maxIntimacy = pg.intimacy_template[#pg.intimacy_template.all].upper_bound

	local var_41_6 = 0

	if not HXSet.isHxSkin() then
		var_41_6 = arg_41_1.skin_id or 0
	end

	self.phantomDic = {}

	arg_41_0:updateSkinId(var_41_6, 0)

	for _, skinShadow in ipairs(args.skin_shadow_list or {}) do
		self:updateSkinId(skinShadow.value, skinShadow.key)
	end

	self.noChangeSkin = args.noChangeSkin or false
	self.phantomRandomFlag = {}

	for _, randomFlag in ipairs(args.char_random_flag or {}) do
		self:updateRandomFlag(1, randomFlag)
	end

	if args.name and args.name ~= "" then
		self.name = args.name
	elseif self:isRemoulded() then
		self.name = pg.ship_skin_template[self:getRemouldSkinId()].name
	else
		self.name = pg.ship_data_statistics[self.configId].name
	end

	self.maxLevel = args.max_level
	self.proficiency = args.proficiency or 0
	self.preferenceTag = args.common_flag
	self.hpRant = 10000
	self.strategies = {}
	self.triggers = {}
	self.commanderId = args.commanderid or 0
	self.activityNpc = args.activity_npc or 0

	if var_0_0.isMetaShipByConfigID(arg_41_0.configId) then
		local var_41_7 = MetaCharacterConst.GetMetaShipGroupIDByConfigID(arg_41_0.configId)

		arg_41_0.metaCharacter = MetaCharacter.New({
			id = var_41_7,
			repair_attr_info = arg_41_1.meta_repair_list
		}, arg_41_0)
	end
end

--- @class Ship
--- @param configId number
--- @return boolean
--- 判断舰船是否为META船
function Ship.isMetaShipByConfigID(configId)
	-- 通过查找ConfigId是否在ship_meta_breakout表的all字段中来判断
	-- all字段包含的是所有META船的所有突破形态
	local metaShipIDList = pg.ship_meta_breakout.all
	-- 因为all字段有序，进行合法性判断
	local metaShipID = metaShipIDList[1]
	local isMeta = false

	if metaShipID <= configId then
		for _, shipID in ipairs(metaShipIDList) do
			if configId == shipID then
				isMeta = true

				break
			end
		end
	end

	return isMeta
end

--- @class Ship
--- @return boolean
--- 判断舰船是否为META船
function Ship.isMetaShip(self)
	return self.metaCharacter ~= nil
end

--- @class Ship
--- @return MetaCharacter
--- 获取META船角色对象
function Ship.getMetaCharacter(self)
	return self.metaCharacter
end

--- @class Ship
--- @param flag number
--- @return nil
--- 解锁/锁定活动NPC状态
--- - flag: 0表示锁定，1表示解锁
function Ship.unlockActivityNpc(self, flag)
	self.activityNpc = flag
end

--- @class Ship
--- @return boolean
--- 判断是否为活动NPC
function Ship.isActivityNpc(self)
	return self.activityNpc > 0
end

--- @class Ship
--- @return table<number, Equipment|boolean>
--- 获取舰船已装备的装备列表
function Ship.getActiveEquipments(self)
	local equipments = Clone(self.equipments)

	-- 倒序检查：是否有"equip_limit"不为0且冲突的装备
	for pos = #equipments, 1, -1 do
		local equipment = equipments[pos]

		if equipment then
			for i = 1, pos - 1 do
				local comparedEquipment = equipments[i]

				if comparedEquipment and equipment:getConfig("equip_limit") ~= 0 and comparedEquipment:getConfig("equip_limit") == equipment:getConfig("equip_limit") then
					equipments[pos] = false
				end
			end
		end
	end

	return equipments
end

--- @class Ship
--- @return table<number, Equipment|boolean>
--- 获取舰船所有装备（包含未装备位置）
function Ship.getAllEquipments(self)
	return self.equipments
end

function var_0_0.isBluePrintShip(arg_49_0)
	return arg_49_0.bluePrintFlag
end

--- @class Ship
--- @param flag number
--- @return number
--- 获取舰船皮肤ID
function Ship.getSkinId(self, flag)
	local phantomSkin = self:getPhantomSkin(flag or 0)

	if not self.noChangeSkin and tobool(self.id) and ShipSkin.IsChangeSkin(phantomSkin) then
		local skin = ShipSkin.GetStoreChangeSkinId(ShipSkin.GetChangeSkinGroupId(phantomSkin), self:GetShipPhantomMark())

		if skin then
			return skin
		end
	end

	return phantomSkin
end

function Ship.RevertAsmrSkin(arg_51_0)
	local var_51_0 = arg_51_0:getSkinId()

	if not arg_51_0.noChangeSkin and tobool(arg_51_0.id) and ShipSkin.IsChangeSkin(var_51_0) then
		local var_51_1 = ShipSkin.GetChangeSkinCustomDataId(var_51_0, "asmr") == 1 and true or false
		local var_51_2 = ShipSkin.GetChangeSkinCustomDataId(var_51_0, "index") == 1 and true or false

		if var_51_1 and not var_51_2 then
			local var_51_3 = ShipSkin.GetChangeSkinMainId(var_51_0)

			ShipSkin.SetStoreChangeSkinId(var_51_3, arg_51_0:GetShipPhantomMark())
		end
	end
end

--- @class Ship
--- @param flag number
--- @return number
--- 获取舰船幻影皮肤ID(没搞懂是啥，可能是和谐版皮肤)
function Ship.getPhantomSkin(self, flag)
	if not flag or flag == 0 then
		return self.skinId
	else
		return self.phantomDic[self.phantomId] or self:getConfig("skin_id")
	end
end

--- @class Ship
--- @param skinId number
--- @param phantomId number
--- @return nil
--- 更新舰船皮肤ID
function Ship.updateSkinId(self, skinId, phantomId)
	if not skinId or skinId == 0 then
		skinId = self:getConfig("skin_id")
	end

	if phantomId == 0 then
		self.skinId = skinId
	else
		self.phantomDic[phantomId] = skinId
	end
end

function Ship.getAllShipPhantomMarks(arg_53_0)
	local var_53_0 = getGameset("technology_shadow_num")[1]
	local var_53_1 = {}

	for iter_53_0 = 0, var_53_0 do
		if iter_53_0 == 0 or arg_53_0.phantomDic[iter_53_0] then
			table.insert(var_53_1, ShipPhantom.PackMark(arg_53_0.id, iter_53_0))
		end
	end

	return var_53_1
end

function Ship.getAllShipPhantom(arg_54_0)
	local var_54_0 = getGameset("technology_shadow_num")[1]
	local var_54_1 = {}

	for iter_54_0 = 0, var_54_0 do
		if iter_54_0 == 0 or arg_54_0.phantomDic[iter_54_0] then
			table.insert(var_54_1, ShipPhantom.PackMark(arg_54_0.id, iter_54_0))
		end
	end

	return var_54_1
end

function Ship.updateRandomFlag(arg_55_0, arg_55_1, arg_55_2)
	arg_55_2 = defaultValue(arg_55_2, 0)
	arg_55_0.phantomRandomFlag[arg_55_2] = arg_55_1
end

function Ship.getRandomFlag(arg_56_0, arg_56_1)
	return defaultValue(arg_56_0.phantomRandomFlag[arg_56_1 or 0], 0) > 0
end

function Ship.getRandomFlagShipPhantomMarks(arg_57_0)
	local var_57_0 = getGameset("technology_shadow_num")[1]
	local var_57_1 = {}

	for iter_58_0 = 0, var_58_0 do
		if defaultValue(arg_58_0.phantomRandomFlag[iter_58_0], 0) > 0 then
			table.insert(var_58_1, arg_58_0:GetShipPhantomMark(iter_58_0))
		end
	end

	return var_58_1
end

--- @class Ship
--- @return nil
--- 更新舰船名称
function Ship.updateName(self)
	if self.name ~= pg.ship_data_statistics[self.configId].name then
		return
	end

	if self:isRemoulded() then
		self.name = pg.ship_skin_template[self:getRemouldSkinId()].name
	else
		self.name = pg.ship_data_statistics[self.configId].name
	end
end

--- @class Ship
--- @return boolean
--- 判断舰船是否改造过
--- - 通过检查改造阶段中是否有更改过skin，且该stage已完成
function Ship.isRemoulded(self)
	if self.remoulded then
		return true
	end

	local transInfo = pg.ship_data_trans[self.groupId]

	if transInfo then
		for _, transform in ipairs(transInfo.transform_list) do
			for _, transformStage in ipairs(transform) do
				local transformData = pg.transform_data_template[transformStage[2]]

				if transformData.skin_id ~= 0 and self.transforms[transformStage[2]] and self.transforms[transformStage[2]].level == transformData.max_level then
					return true
				end
			end
		end
	end

	return false
end

--- @class Ship
--- @return number|nil
--- 获取舰船改造后的皮肤ID
function Ship.getRemouldSkinId(self)
	local modSkin = ShipGroup.getModSkin(self.groupId)

	if modSkin then
		return modSkin.id
	end

	return nil
end

function Ship.hasEquipmentSkinInPos(arg_61_0, arg_61_1)
	local var_61_0 = arg_61_0.equipments[arg_61_1]

	return var_62_0 and var_62_0:hasSkin()
end

function Ship.getPrefab(arg_62_0, arg_62_1)
	local var_62_0 = arg_62_0:getSkinId()

	if arg_62_0:hasEquipmentSkinInPos(var_0_2) then
		local var_62_1 = arg_62_0:getEquip(var_0_2)
		local var_62_2 = equip_skin_template[var_62_1:getSkinId()].ship_skin_id

		var_63_0 = var_63_2 ~= 0 and var_63_2 or var_63_0
	end

	local var_63_3 = pg.ship_skin_template[var_63_0]

	assert(var_63_3, "ship_skin_template not exist: " .. arg_63_0.configId .. " " .. var_63_0)

	if var_63_3.double_char and var_63_3.double_char == 1 and arg_63_1 ~= nil then
		local var_63_4

		if arg_63_1 == 1 then
			return var_63_3.prefab .. "_L"
		elseif arg_63_1 == 2 then
			return var_63_3.prefab .. "_R"
		end
	end

	return var_63_3.prefab
end

function Ship.IsDoubleSkin(arg_63_0)
	local var_63_0 = arg_63_0:getSkinId()
	local var_63_1 = pg.ship_skin_template[var_63_0]

	assert(var_64_1, "ship_skin_template not exist: " .. arg_64_0.configId .. " " .. var_64_0)

	return var_64_1.double_char and var_64_1.double_char == 1 or false
end

function Ship.getAttachmentPrefab(arg_64_0)
	local var_64_0 = {}

	for iter_64_0, iter_64_1 in ipairs(arg_64_0.equipments) do
		if iter_64_1 and iter_64_1:hasSkinOrbit() then
			local var_64_1 = iter_64_1:getSkinId()
			local var_64_2 = equip_skin_template[var_64_1]

			var_65_0[var_65_1] = {
				config = var_65_2,
				index = iter_65_0
			}
		end
	end

	return var_65_0
end

function Ship.getPainting(arg_65_0)
	local var_65_0 = arg_65_0:getSkinId()
	local var_65_1 = pg.ship_skin_template[var_65_0]

	assert(var_65_1, "ship_skin_template not exist: " .. arg_65_0.configId .. " " .. var_65_0)

	return var_65_1.painting
end

function Ship.GetSkinConfig(arg_66_0, arg_66_1)
	local var_66_0 = arg_66_0:getSkinId()
	local var_66_1 = pg.ship_skin_template[var_66_0]

	assert(var_66_1, "ship_skin_template not exist: " .. arg_66_0.configId .. " " .. var_66_0)

	return var_66_1.painting
end

function Ship.getRemouldPainting(arg_67_0)
	local var_67_0 = arg_67_0:getRemouldSkinId()
	local var_67_1 = pg.ship_skin_template[var_67_0]

	assert(var_67_1, "ship_skin_template not exist: " .. arg_67_0.configId .. " " .. var_67_0)

	return var_67_1
end

function Ship.getRemouldPainting(arg_68_0)
	local var_68_0 = arg_68_0:getRemouldSkinId()
	local var_68_1 = pg.ship_skin_template[var_68_0]

	assert(var_68_1, "ship_skin_template not exist: " .. arg_68_0.configId .. " " .. var_68_0)

	return var_68_1.painting
end

function Ship.updateStateInfo34(arg_68_0, arg_68_1, arg_68_2)
	arg_68_0.state_info_3 = arg_68_1
	arg_68_0.state_info_4 = arg_68_2
end

function Ship.hasStateInfo3Or4(arg_69_0)
	return arg_69_0.state_info_3 ~= 0 or arg_69_0.state_info_4 ~= 0
end

function Ship.isTestShip(arg_70_0)
	return arg_70_0.testShip
end

function Ship.canUseTestShip(arg_71_0, arg_71_1)
	assert(arg_71_0.testShip, "ship is not TestShip")

	return table.contains(arg_72_0.testShip, arg_72_1)
end

--- @class Ship
--- @param pos number
--- @param equipment Equipment|nil
--- @return nil
--- 更新舰船指定位置的装备
function Ship.updateEquip(self, pos, equipment)
	assert(equipment == nil or equipment.count == 1)

	local originalEquipment = self.equipments[pos]

	self.equipments[pos] = equipment and Clone(equipment) or false

	local function var_72_1(arg_73_0)
		arg_73_0 = CreateShell(arg_73_0)
		arg_73_0.shipId = self.id
		arg_73_0.shipPos = pos

		return arg_74_0
	end

	if originalEquipment then
		getProxy(EquipmentProxy):OnShipEquipsRemove(originalEquipment, self.id, pos)
		originalEquipment:setSkinId(0)
		pg.m02:sendNotification(BayProxy.SHIP_EQUIPMENT_REMOVED, var_72_1(originalEquipment))
	end

	if equipment then
		getProxy(EquipmentProxy):OnShipEquipsAdd(equipment, self.id, pos)
		self:reletiveEquipSkin(pos)
		pg.m02:sendNotification(BayProxy.SHIP_EQUIPMENT_ADDED, var_72_1(equipment))
	end
end

function Ship.reletiveEquipSkin(arg_74_0, arg_74_1)
	if arg_74_0.equipments[arg_74_1] and arg_74_0.equipmentSkins[arg_74_1] ~= 0 then
		local var_74_0 = pg.equip_skin_template[arg_74_0.equipmentSkins[arg_74_1]].equip_type
		local var_74_1 = arg_74_0.equipments[arg_74_1]:getType()

		if table.contains(var_75_0, var_75_1) then
			arg_75_0.equipments[arg_75_1]:setSkinId(arg_75_0.equipmentSkins[arg_75_1])
		else
			arg_75_0.equipments[arg_75_1]:setSkinId(0)
		end
	elseif arg_75_0.equipments[arg_75_1] then
		arg_75_0.equipments[arg_75_1]:setSkinId(0)
	end
end

function Ship.updateEquipmentSkin(arg_75_0, arg_75_1, arg_75_2)
	if not arg_75_1 then
		return
	end

	if arg_76_2 and arg_76_2 > 0 then
		local var_76_0 = arg_76_0:getSkinTypes(arg_76_1)
		local var_76_1 = pg.equip_skin_template[arg_76_2].equip_type
		local var_76_2 = false

		for iter_76_0, iter_76_1 in ipairs(var_76_0) do
			for iter_76_2, iter_76_3 in ipairs(var_76_1) do
				if iter_76_1 == iter_76_3 then
					var_76_2 = true

					break
				end
			end
		end

		if not var_76_2 then
			assert(var_76_2, "部位" .. arg_76_1 .. " 无法穿戴皮肤 " .. arg_76_2)

			return
		end

		local var_76_3 = arg_76_0.equipments[arg_76_1] and arg_76_0.equipments[arg_76_1]:getType() or false

		arg_76_0.equipmentSkins[arg_76_1] = arg_76_2

		if var_76_3 and table.contains(var_76_1, var_76_3) then
			arg_76_0.equipments[arg_76_1]:setSkinId(arg_76_0.equipmentSkins[arg_76_1])
		elseif var_76_3 and not table.contains(var_76_1, var_76_3) then
			arg_76_0.equipments[arg_76_1]:setSkinId(0)
		end
	else
		arg_76_0.equipmentSkins[arg_76_1] = 0

		if arg_76_0.equipments[arg_76_1] then
			arg_76_0.equipments[arg_76_1]:setSkinId(0)
		end
	end
end

--- @class Ship
--- @param pos number
--- @return Equipment
--- 获取指定位置的装备
function Ship.getEquip(self, pos)
	return Clone(self.equipments[pos])
end

function Ship.getEquipSkins(arg_77_0)
	return Clone(arg_77_0.equipmentSkins)
end

function Ship.getEquipSkin(arg_78_0, arg_78_1)
	return arg_78_0.equipmentSkins[arg_78_1]
end

function Ship.getCanEquipSkin(arg_79_0, arg_79_1)
	local var_79_0 = arg_79_0:getSkinTypes(arg_79_1)

	if var_80_0 and #var_80_0 then
		for iter_80_0, iter_80_1 in ipairs(var_80_0) do
			if pg.equip_data_by_type[iter_80_1].equip_skin == 1 then
				return true
			end
		end
	end

	return false
end

function Ship.checkCanEquipSkin(arg_80_0, arg_80_1, arg_80_2)
	if not arg_80_1 or not arg_80_2 then
		return
	end

	local var_81_0 = arg_81_0:getSkinTypes(arg_81_1)
	local var_81_1 = pg.equip_skin_template[arg_81_2].equip_type

	for iter_81_0, iter_81_1 in ipairs(var_81_0) do
		if table.contains(var_81_1, iter_81_1) then
			return true
		end
	end

	return false
end

function Ship.getSkinTypes(arg_81_0, arg_81_1)
	return pg.ship_data_template[arg_81_0.configId]["equip_" .. arg_81_1] or {}
end

function Ship.updateState(arg_82_0, arg_82_1)
	arg_82_0.state = arg_82_1
end

function Ship.addSkillExp(arg_83_0, arg_83_1, arg_83_2)
	local var_83_0 = arg_83_0.skills[arg_83_1] or {
		exp = 0,
		level = 1,
		id = arg_84_1
	}
	local var_84_1 = var_84_0.level and var_84_0.level or 1
	local var_84_2 = pg.skill_need_exp.all[#pg.skill_need_exp.all]

	if var_84_1 == var_84_2 then
		return
	end

	local var_84_3 = var_84_0.exp and arg_84_2 + var_84_0.exp or 0 + arg_84_2

	while var_84_3 >= pg.skill_need_exp[var_84_1].exp do
		var_84_3 = var_84_3 - pg.skill_need_exp[var_84_1].exp
		var_84_1 = var_84_1 + 1

		if var_84_1 == var_84_2 then
			var_84_3 = 0

			break
		end
	end

	arg_84_0:updateSkill({
		id = var_84_0.id,
		level = var_84_1,
		exp = var_84_3
	})
end

function Ship.upSkillLevelForMeta(arg_84_0, arg_84_1)
	local var_84_0 = arg_84_0.skills[arg_84_1] or {
		exp = 0,
		level = 0,
		id = arg_85_1
	}
	local var_85_1 = arg_85_0:isSkillLevelMax(arg_85_1)
	local var_85_2 = var_85_0.level

	if not var_85_1 then
		var_85_2 = var_85_2 + 1
	end

	arg_85_0:updateSkill({
		exp = 0,
		id = var_85_0.id,
		level = var_85_2
	})
end

function Ship.getMetaSkillLevelBySkillID(arg_85_0, arg_85_1)
	return (arg_85_0.skills[arg_85_1] or {
		exp = 0,
		level = 0,
		id = arg_86_1
	}).level
end

function Ship.isSkillLevelMax(arg_86_0, arg_86_1)
	local var_86_0 = arg_86_0.skills[arg_86_1] or {
		exp = 0,
		level = 1,
		id = arg_87_1
	}

	return (var_87_0.level and var_87_0.level or 1) >= pg.skill_data_template[arg_87_1].max_level
end

function Ship.isAllMetaSkillLevelMax(arg_87_0)
	local var_87_0 = true
	local var_87_1 = MetaCharacterConst.getTacticsSkillIDListByShipConfigID(arg_87_0.configId)

	for iter_88_0, iter_88_1 in ipairs(var_88_1) do
		if not arg_88_0:isSkillLevelMax(iter_88_1) then
			var_88_0 = false

			break
		end
	end

	return var_88_0
end

function Ship.isAllMetaSkillLock(arg_88_0)
	local var_88_0 = MetaCharacterConst.getTacticsSkillIDListByShipConfigID(arg_88_0.configId)
	local var_88_1 = true

	for iter_89_0, iter_89_1 in ipairs(var_89_0) do
		if arg_89_0:getMetaSkillLevelBySkillID(iter_89_1) > 0 then
			var_89_1 = false

			break
		end
	end

	return var_89_1
end

--- @class Ship
--- @return table<number, table>
--- Ship类绑定的配置表，为ship_data_statistics
--- - 这个表会在本类多次使用，很重要
function Ship.bindConfigTable(self)
	return pg.ship_data_statistics
end

function Ship.isAvaiable(self)
	return true
end

-- 舰船的属性列表
--- @type table<number, string>
Ship.PROPERTIES = {
	AttributeType.Durability,
	AttributeType.Cannon,
	AttributeType.Torpedo,
	AttributeType.AntiAircraft,
	AttributeType.Air,
	AttributeType.Reload,
	AttributeType.Armor,
	AttributeType.Hit,
	AttributeType.Dodge,
	AttributeType.Speed,
	AttributeType.Luck,
	AttributeType.AntiSub
}
Ship.PROPERTIES_ENHANCEMENT = {
	AttributeType.Durability,
	AttributeType.Cannon,
	AttributeType.Torpedo,
	AttributeType.AntiAircraft,
	AttributeType.Air,
	AttributeType.Reload,
	AttributeType.Hit,
	AttributeType.Dodge,
	AttributeType.Speed,
	AttributeType.Luck,
	AttributeType.AntiSub
}
--- 舰船潜艇属性列表
Ship.DIVE_PROPERTIES = {
	AttributeType.OxyMax,
	AttributeType.OxyCost,
	AttributeType.OxyRecovery,
	AttributeType.OxyRecoveryBench,
	AttributeType.OxyRecoverySurface,
	AttributeType.OxyAttackDuration,
	AttributeType.OxyRaidDistance
}
--- 舰船声呐属性列表
Ship.SONAR_PROPERTIES = {
	AttributeType.SonarRange
}

--- @class Ship
--- @param properties table<number, number>
function Ship.intimacyAdditions(self, properties)
	local attrBonus = pg.intimacy_template[self:getIntimacyLevel()].attr_bonus * 0.0001

	for property, _ in pairs(properties) do
		-- Speed和Luck不受好感度加成影响
		if property == AttributeType.Durability or property == AttributeType.Cannon or property == AttributeType.Torpedo or property == AttributeType.AntiAircraft or property == AttributeType.AntiSub or property == AttributeType.Air or property == AttributeType.Reload or property == AttributeType.Hit or property == AttributeType.Dodge then
			properties[property] = properties[property] * (attrBonus + 1)
		end
	end
end

--- @class Ship
--- @return table<string, number>
--- 计算舰船的总属性（包含改造、强化、好感度等加成)
--- 公式：（基础 + 强化) * (1 + 好感度加成) + 改造
--- - 其中强化可来自科研舰船的蓝图加成/META船的角色加成/普通舰船的强化经验加成
function Ship.getShipProperties(self)
	local baseProperties = self:getBaseProperties()

	if self:isBluePrintShip() then
		local bluePrint = self:getBluePrint()

		assert(bluePrint, "blueprint can not be nil" .. self.configId)

		local bluePrintAdditions = bluePrint:getTotalAdditions()

		for property, addition in pairs(bluePrintAdditions) do
			baseProperties[property] = baseProperties[property] + calcFloor(addition)
		end

		self:intimacyAdditions(baseProperties)
	elseif self:isMetaShip() then
		assert(self.metaCharacter)

		for property, _ in pairs(baseProperties) do
			baseProperties[property] = baseProperties[property] + self.metaCharacter:getAttrAddition(property)
		end

		self:intimacyAdditions(baseProperties)
	else
		local strengthenID = pg.ship_data_template[self.configId].strengthen_id
		local strengthenTemplate = ship_data_strengthen[strengthenID]

		for property, strengthenExp in pairs(self.strengthList) do
			-- 炮击=1，雷击=2，防空=3，航空=4，装填=5
			local attrIndex = ShipModAttr.ATTR_TO_INDEX[property]
			local actualExp = math.min(strengthenExp, strengthenTemplate.durability[attrIndex] * strengthenTemplate.level_exp[attrIndex])
			local strengthenExpPerLevel = math.max(self:getModExpRatio(property), 1)

			baseProperties[property] = baseProperties[property] + calcFloor(actualExp / strengthenExpPerLevel)
		end

		self:intimacyAdditions(baseProperties)

		for _, transform in pairs(self.transforms) do
			local transformEffect = pg.transform_data_template[transform.id].effect

			for i = 1, transform.level do
				local effect = transformEffect[i] or {}

				for property, _ in pairs(baseProperties) do
					if effect[property] then
						baseProperties[property] = baseProperties[property] + effect[property]
					end
				end
			end
		end
	end

	return baseProperties
end

function Ship.getTechNationAddition(arg_93_0, arg_93_1)
	local var_93_0 = getProxy(TechnologyNationProxy)
	local var_93_1 = arg_93_0:getConfig("type")

	if var_94_1 == ShipType.DaoQuV or var_94_1 == ShipType.DaoQuM then
		var_94_1 = ShipType.QuZhu
	end

	return var_94_0:getShipAddition(var_94_1, arg_94_1)
end

function Ship.getTechNationMaxAddition(arg_94_0, arg_94_1)
	local var_94_0 = getProxy(TechnologyNationProxy)
	local var_94_1 = arg_94_0:getConfig("type")

	return var_95_0:getShipMaxAddition(var_95_1, arg_95_1)
end

function Ship.getEquipProficiencyByPos(arg_95_0, arg_95_1)
	return arg_95_0:getEquipProficiencyList()[arg_95_1]
end

function Ship.getEquipProficiencyList(arg_96_0)
	local var_96_0 = arg_96_0:getConfigTable()
	local var_96_1 = Clone(var_96_0.equipment_proficiency)

	if arg_97_0:isBluePrintShip() then
		local var_97_2 = arg_97_0:getBluePrint()

		assert(var_97_2, "blueprint can not be nil >>>" .. arg_97_0.groupId)

		var_97_1 = var_97_2:getEquipProficiencyList(arg_97_0)
	else
		for iter_97_0, iter_97_1 in ipairs(var_97_1) do
			local var_97_3 = 0

			for iter_97_2, iter_97_3 in pairs(arg_97_0.transforms) do
				local var_97_4 = pg.transform_data_template[iter_97_3.id].effect

				for iter_97_4 = 1, iter_97_3.level do
					local var_97_5 = var_97_4[iter_97_4] or {}

					if var_97_5["equipment_proficiency_" .. iter_97_0] then
						var_97_3 = var_97_3 + var_97_5["equipment_proficiency_" .. iter_97_0]
					end
				end
			end

			var_97_1[iter_97_0] = iter_97_1 + var_97_3
		end
	end

	return var_97_1
end

--- @class Ship
--- @return table<string, number>
--- 计算舰船的基础属性
function Ship.getBaseProperties(self)
	local shipTemplate = self:getConfigTable()

	assert(shipTemplate, "配置表没有这艘船" .. self.configId)

	local attrsGrowth = {}
	local baseProperties = {}

	for _, property in ipairs(Ship.PROPERTIES) do
		attrsGrowth[property] = self:getGrowthForAttr(property)
		baseProperties[property] = attrsGrowth[property]
	end

	-- 不知道什么意思...lock字段里的属性看上去都在PROPERTIES里, 所以这里等于覆盖一遍相同的值
	for _, lockProperty in ipairs(self:getConfig("lock")) do
		baseProperties[lockProperty] = attrsGrowth[lockProperty]
	end

	for _, diveProperty in ipairs(Ship.DIVE_PROPERTIES) do
		baseProperties[diveProperty] = shipTemplate[diveProperty]
	end

	for _, sonarProperty in ipairs(Ship.SONAR_PROPERTIES) do
		baseProperties[sonarProperty] = 0
	end

	return baseProperties
end

--- @class Ship
--- @param property string
--- @return number
--- 获取舰船某个属性的成长值
--- 公式: baseAttr + (level - 1) * attrGrowth / 1000 + (level - 100) * attrGrowthExtra / 1000
--- 其中attrGrowthExtra大多数舰船配置都是全0，因此平时计算可以忽略掉
function Ship.getGrowthForAttr(self, property)
	local shipTemplate = self:getConfigTable()
	local index = table.indexof(Ship.PROPERTIES, property)
	-- extraAttrLevelLimit = 100
	local extraAttrLevelLimit = pg.gameset.extra_attr_level_limit.key_value
	local attrGrowth = shipTemplate.attrs[index] + (self.level - 1) * shipTemplate.attrs_growth[index] / 1000

	if extraAttrLevelLimit < self.level then
		attrGrowth = attrGrowth + (self.level - extraAttrLevelLimit) * shipTemplate.attrs_growth_extra[index] / 1000
	end

	return attrGrowth
end

function Ship.isMaxStar(arg_99_0)
	return arg_99_0:getStar() >= arg_99_0:getMaxStar()
end

function Ship.IsMaxStarByTmpID(arg_100_0)
	local var_100_0 = pg.ship_data_template[arg_100_0]

	return var_101_0.star >= var_101_0.star_max
end

function Ship.IsSpweaponUnlock(arg_101_0)
	if not arg_101_0:CanAccumulateExp() then
		return false, "spweapon_tip_locked"
	else
		return true
	end
end

--- @class Ship
--- @param index number
--- @return number
--- 获取某阶段强化的属性值
function Ship.getModProperties(self, index)
	return self.strengthList[index] or 0
end

function Ship.addModAttrExp(arg_103_0, arg_103_1, arg_103_2)
	local var_103_0 = arg_103_0:getModAttrTopLimit(arg_103_1)

	if var_104_0 == 0 then
		return
	end

	local var_104_1 = arg_104_0:getModExpRatio(arg_104_1)
	local var_104_2 = arg_104_0:getModProperties(arg_104_1)

	if var_104_2 + arg_104_2 > var_104_0 * var_104_1 then
		arg_104_0.strengthList[arg_104_1] = var_104_0 * var_104_1
	else
		arg_104_0.strengthList[arg_104_1] = var_104_2 + arg_104_2
	end
end

function Ship.getNeedModExp(arg_104_0)
	local var_104_0 = {}

	for iter_105_0, iter_105_1 in pairs(ShipModAttr.ID_TO_ATTR) do
		local var_105_1 = arg_105_0:getModAttrTopLimit(iter_105_1)

		if var_105_1 == 0 then
			var_105_0[iter_105_1] = 0
		else
			var_105_0[iter_105_1] = var_105_1 * arg_105_0:getModExpRatio(iter_105_1) - arg_105_0:getModProperties(iter_105_1)
		end
	end

	return var_105_0
end

function Ship.attrVertify(arg_105_0)
	if not BayProxy.checkShiplevelVertify(arg_105_0) then
		return false
	end

	for iter_106_0, iter_106_1 in ipairs(arg_106_0.equipments) do
		if iter_106_1 and not iter_106_1:vertify() then
			return false
		end
	end

	return true
end

--- @class Ship
--- @return table<string, number>, table<string, number>
--- 计算舰船装备的属性加成，包括值和百分比属性加成
function Ship.getEquipmentProperties(self)
	local equipProperties = {}
	local equipRates = {}

	for _, property in ipairs(Ship.PROPERTIES) do
		equipProperties[property] = 0
	end

	for _, diveProperty in ipairs(Ship.DIVE_PROPERTIES) do
		equipProperties[diveProperty] = 0
	end

	for _, sonarProperty in ipairs(Ship.SONAR_PROPERTIES) do
		equipProperties[sonarProperty] = 0
	end

	for _, propertyEnhancement in ipairs(Ship.PROPERTIES_ENHANCEMENT) do
		equipRates[propertyEnhancement] = 0
	end

	equipProperties[AttributeType.AirDominate] = 0
	equipProperties[AttributeType.AntiSiren] = 0

	local equipments = self:getActiveEquipments()

	for _, equipment in ipairs(equipments) do
		if equipment then
			--- @type table<number, table<string, number>>
			local equipmentAttrs = equipment:GetAttributes()

			for _, attr in ipairs(equipmentAttrs) do
				if attr and equipProperties[attr.type] then
					equipProperties[attr.type] = equipProperties[attr.type] + attr.value
				end
			end
			-- 目前看下来全是0...
			local propertyRate = equipment:GetPropertyRate()

			for property, rate in pairs(propertyRate) do
				equipRates[property] = math.max(equipRates[property], rate)
			end

			local sonarProperty = equipment:GetSonarProperty()

			-- 声呐装备的额外范围加成
			if sonarProperty then
				for property, range in pairs(sonarProperty) do
					equipProperties[property] = equipProperties[property] + range
				end
			end
			-- 对塞壬增伤，本质DMG_TAG_EHC_N_99
			local antiSirenPower = equipment:GetAntiSirenPower()

			if antiSirenPower then
				equipProperties[AttributeType.AntiSiren] = equipProperties[AttributeType.AntiSiren] + antiSirenPower / 10000
			end
		end
	end

	;(function()
		local spWeapon = self:GetSpWeapon()

		if not spWeapon then
			return
		end
		--- @type table<number, table<string, number>>
		local spWeaponAttrs = spWeapon:GetPropertiesInfo().attrs

		for _, attr in ipairs(spWeaponAttrs) do
			if attr and equipProperties[attr.type] then
				equipProperties[attr.type] = equipProperties[attr.type] + attr.value
			end
		end
	end)()
	-- Equip属性加成是百分比，因此这里要+1
	for property, rate in pairs(equipRates) do
		equipRates[property] = rate + 1
	end

	return equipProperties, equipRates
end

-- 被Ship.getTriggerSkills调用
function Ship.getSkillEffects(self)
	local shipSkillEffects = self:getShipSkillEffects()

	_.each(self:getEquipmentSkillEffects(), function(effect)
		table.insert(shipSkillEffects, effect)
	end)

	return shipSkillEffects
end

-- 被Ship.getSkillEffects调用
function Ship.getShipSkillEffects(self)
	local shipSkillEffects = {}
	local skillList = self:getSkillList()
	for _, skill in ipairs(skillList) do
		local mapedBuffID = self:RemapSkillId(skill, true)
		local buffConfig = pg.buffCfg["buff_" .. mapedBuffID]

		self:FilterActiveSkill(shipSkillEffects, buffConfig, self.skills[skill])
	end

	return shipSkillEffects
end

function Ship.getEquipmentSkillEffects(arg_111_0)
	local var_111_0 = {}
	local var_111_1 = arg_111_0:getActiveEquipments()

	for iter_112_0, iter_112_1 in ipairs(var_112_1) do
		local var_112_2
		local var_112_3 = iter_112_1 and iter_112_1:getConfig("skill_id")[1] and iter_112_1:getConfig("skill_id")[1][1]

		if var_112_3 then
			var_112_2 = pg.buffCfg["buff_" .. var_112_3]
		end

		arg_112_0:FilterActiveSkill(var_112_0, var_112_2)
	end

	;(function()
		local var_113_0 = arg_112_0:GetSpWeapon()
		local var_113_1 = var_113_0 and var_113_0:GetEffect() or 0
		local var_113_2

		if var_113_1 > 0 then
			var_113_2 = pg.buffCfg["buff_" .. var_113_1]
		end

		arg_112_0:FilterActiveSkill(var_112_0, var_113_2)
	end)()

	return var_112_0
end

function Ship.FilterActiveSkill(arg_113_0, arg_113_1, arg_113_2, arg_113_3)
	if not arg_113_2 or not arg_113_2.const_effect_list then
		return
	end

	for iter_114_0 = 1, #arg_114_2.const_effect_list do
		local var_114_0 = arg_114_2.const_effect_list[iter_114_0]
		local var_114_1 = var_114_0.trigger
		local var_114_2 = var_114_0.arg_list
		local var_114_3 = 1

		if arg_114_3 then
			var_114_3 = arg_114_3.level

			local var_114_4 = arg_114_2[var_114_3].const_effect_list

			if var_114_4 and var_114_4[iter_114_0] then
				var_114_1 = var_114_4[iter_114_0].trigger or var_114_1
				var_114_2 = var_114_4[iter_114_0].arg_list or var_114_2
			end
		end

		local var_114_5 = true

		for iter_114_1, iter_114_2 in pairs(var_114_1) do
			if arg_114_0.triggers[iter_114_1] ~= iter_114_2 then
				var_114_5 = false

				break
			end
		end

		if var_114_5 then
			table.insert(arg_114_1, {
				type = var_114_0.type,
				arg_list = var_114_2,
				level = var_114_3
			})
		end
	end
end

function Ship.getEquipmentGearScore(self)
	local gearScore = 0
	local equipments = self:getActiveEquipments()

	for _, equipment in ipairs(equipments) do
		if equipment then
			gearScore = gearScore + equipment:GetGearScore()
		end
	end

	return gearScore
end

--- @class Ship
--- @param commanders table<number, Commander>
--- @param inDuel boolean
--- @param inWorld boolean
--- @param techNotAdjusted boolean
--- @return table<string, number>
--- 计算舰船的战斗外属性
function Ship.getProperties(self, commanders, inDuel, inWorld, techNotAdjusted)
	local commanders = commanders or {}
	local nationality = self:getConfig("nationality")
	local type = self:getConfig("type")
	local shipProperties = self:getShipProperties()
	local equipProperties, equipRates = self:getEquipmentProperties()
	local worldFleetBuffAttrValues
	local worldFleetBuffAttrRatios
	local worldShipBuffAttrRatios

	if inWorld and self:getFlag("inWorld") then
		--- @type WorldMapShip
		local worldShip = WorldConst.FetchWorldShip(self.id)

		worldFleetBuffAttrValues, worldFleetBuffAttrRatios = worldShip:GetShipBuffProperties()
		worldShipBuffAttrRatios = worldShip:GetShipPowerBuffProperties()
	end

	for _, property in ipairs(Ship.PROPERTIES) do
		local commanderAttrRatio = 0
		local commanderAttrValue = 0

		for _, commander in pairs(commanders) do
			commanderAttrRatio = commanderAttrRatio + commander:getAttrRatioAddition(property, nationality, type) / 100
			commanderAttrValue = commanderAttrValue + commander:getAttrValueAddition(property, nationality, type)
		end
		-- 如上所述，此处equipRates基本全0，因此可忽略
		-- 可能是给以后装备属性百分比加成预留的接口
		local totalRatio = commanderAttrRatio + (equipRates[property] or 1)
		local worldFleetBuffRatio = worldFleetBuffAttrRatios and worldFleetBuffAttrRatios[property] or 1
		local worldFleetBuffValue = worldFleetBuffAttrValues and worldFleetBuffAttrValues[property] or 0
		-- 航速属性不取整
		if property == AttributeType.Speed then
			shipProperties[property] = shipProperties[property] * totalRatio * worldFleetBuffRatio + commanderAttrValue + equipProperties[property] + worldFleetBuffValue
		else
			shipProperties[property] = calcFloor(calcFloor(shipProperties[property]) * totalRatio * worldFleetBuffRatio) + commanderAttrValue + equipProperties[property] + worldFleetBuffValue
		end
	end

	if not inDuel and self:isMaxStar() then
		for property, _ in pairs(shipProperties) do
			local techAddition = techNotAdjusted and self:getTechNationMaxAddition(property) or self:getTechNationAddition(property)

			shipProperties[property] = shipProperties[property] + techAddition
		end
	end

	for _, diveProperty in ipairs(Ship.DIVE_PROPERTIES) do
		shipProperties[diveProperty] = shipProperties[diveProperty] + equipProperties[diveProperty]
	end

	for _, sonarProperty in ipairs(Ship.SONAR_PROPERTIES) do
		shipProperties[sonarProperty] = shipProperties[sonarProperty] + equipProperties[sonarProperty]
	end

	if inWorld then
		shipProperties[AttributeType.AntiSiren] = (shipProperties[AttributeType.AntiSiren] or 0) + equipProperties[AttributeType.AntiSiren]
	end

	if worldShipBuffAttrRatios then
		for attr, ratio in pairs(worldShipBuffAttrRatios) do
			if shipProperties[attr] then
				if attr == AttributeType.Speed then
					shipProperties[attr] = shipProperties[attr] * ratio
				else
					shipProperties[attr] = math.floor(shipProperties[attr] * ratio)
				end
			end
		end
	end

	return shipProperties
end

--- @class Ship
--- @return number
--- 计算改造的额外战力加成
function Ship.getTransGearScore(self)
	local gearScore = 0
	local transform_data_template = pg.transform_data_template

	for _, transform in pairs(self.transforms) do
		for i = 1, transform.level do
			gearScore = gearScore + (transform_data_template[transform.id].gear_score[i] or 0)
		end
	end

	return gearScore
end

--- @class Ship
--- @param commanders table<number, Commander>
--- @return number
--- 计算舰船的战力(综合性能)
function Ship.getShipCombatPower(self, commanders)
	-- 计算战力用的基础属性：不考虑演习和大世界加成，考虑指挥喵加成和科技加成
	local properties = self:getProperties(commanders, nil, nil, true)
	local combatPower = properties[AttributeType.Durability] / 5 + properties[AttributeType.Cannon] + properties[AttributeType.Torpedo] + properties[AttributeType.AntiAircraft] + properties[AttributeType.Air] + properties[AttributeType.AntiSub] + properties[AttributeType.Reload] + properties[AttributeType.Hit] * 2 + properties[AttributeType.Dodge] * 2 + properties[AttributeType.Speed] + self:getEquipmentGearScore() + self:getTransGearScore()
	-- 向下取整
	return math.floor(combatPower)
end

function Ship.cosumeEnergy(arg_118_0, arg_118_1)
	arg_118_0:setEnergy(math.max(arg_118_0:getEnergy() - arg_118_1, 0))
end

function Ship.addEnergy(arg_119_0, arg_119_1)
	arg_119_0:setEnergy(arg_119_0:getEnergy() + arg_119_1)
end

function Ship.setEnergy(arg_120_0, arg_120_1)
	arg_120_0.energy = arg_120_1
end

function Ship.setLikability(arg_121_0, arg_121_1)
	assert(arg_121_1 >= 0 and arg_121_1 <= arg_121_0.maxIntimacy, "intimacy value invaild" .. arg_121_1)
	arg_121_0:setIntimacy(arg_121_1)
end

function Ship.addLikability(arg_122_0, arg_122_1)
	local var_122_0 = Mathf.Clamp(arg_122_0:getIntimacy() + arg_122_1, 0, arg_122_0.maxIntimacy)

	arg_123_0:setIntimacy(var_123_0)
end

function Ship.setIntimacy(arg_123_0, arg_123_1)
	if arg_123_1 > 10000 and not arg_123_0.propose then
		arg_123_1 = 10000
	end

	self.intimacy = level

	if not self:isActivityNpc() then
		getProxy(CollectionProxy).shipGroups[self.groupId]:updateMaxIntimacy(self:getIntimacy())
	end
end

-- 等级相关
function Ship.getLevelExpConfig(self, level)
	if self:getConfig("rarity") == ShipRarity.SSR then
		-- ship_level这个表拿信息
		local levelConfig = Clone(getConfigFromLevel1(ship_level, level or self.level))

		levelConfig.exp = levelConfig.exp_ur
		levelConfig.exp_start = levelConfig.exp_ur_start
		levelConfig.exp_interval = levelConfig.exp_ur_interval
		levelConfig.exp_end = levelConfig.exp_ur_end

		return levelConfig
	else
		return getConfigFromLevel1(ship_level, level or self.level)
	end
end

function Ship.getExp(arg_125_0)
	local var_125_0 = arg_125_0:getMaxLevel()

	if arg_126_0.level == var_126_0 and LOCK_FULL_EXP then
		return 0
	end

	return arg_126_0.exp
end

function Ship.getProficiency(arg_126_0)
	return arg_126_0.proficiency
end

function Ship.addExp(arg_127_0, arg_127_1, arg_127_2)
	local var_127_0 = arg_127_0:getMaxLevel()

	if arg_128_0.level == var_128_0 then
		if arg_128_0.exp >= pg.gameset.exp_overflow_max.key_value then
			return
		end

		if LOCK_FULL_EXP or not arg_128_2 or not arg_128_0:CanAccumulateExp() then
			arg_128_1 = 0
		end
	end

	arg_128_0.exp = arg_128_0.exp + arg_128_1

	local var_128_1 = false

	while arg_128_0:canLevelUp() do
		arg_128_0.exp = arg_128_0.exp - arg_128_0:getLevelExpConfig().exp_interval
		arg_128_0.level = math.min(arg_128_0.level + 1, var_128_0)
		var_128_1 = true
	end

	if arg_128_0.level == var_128_0 then
		if arg_128_2 and arg_128_0:CanAccumulateExp() then
			arg_128_0.exp = math.min(arg_128_0.exp, pg.gameset.exp_overflow_max.key_value)
		elseif var_128_1 then
			arg_128_0.exp = 0
		end
	end
end

function Ship.getMaxLevel(arg_128_0)
	return arg_128_0.maxLevel
end

function Ship.canLevelUp(arg_129_0)
	local var_129_0 = arg_129_0:getLevelExpConfig(arg_129_0.level + 1)
	local var_129_1 = arg_129_0:getMaxLevel() <= arg_129_0.level

	return var_130_0 and arg_130_0:getLevelExpConfig().exp_interval <= arg_130_0.exp and not var_130_1
end

function Ship.getConfigMaxLevel(arg_130_0)
	return ship_level.all[#ship_level.all]
end

function Ship.isConfigMaxLevel(arg_131_0)
	return arg_131_0.level == arg_131_0:getConfigMaxLevel()
end

function Ship.updateMaxLevel(arg_132_0, arg_132_1)
	local var_132_0 = arg_132_0:getConfigMaxLevel()

	arg_133_0.maxLevel = math.max(math.min(var_133_0, arg_133_1), arg_133_0.maxLevel)
end

function Ship.getNextMaxLevel(arg_133_0)
	local var_133_0 = arg_133_0:getConfigMaxLevel()

	for iter_133_0 = arg_133_0:getMaxLevel() + 1, var_133_0 do
		if ship_level[iter_133_0].level_limit == 1 then
			return iter_133_0
		end
	end
end

function Ship.canUpgrade(arg_134_0)
	if arg_134_0:isBluePrintShip() then
		return false
	end

	if arg_135_0:isMetaShip() then
		local var_135_0 = arg_135_0:getMetaCharacter()

		if not var_135_0 then
			return false
		end

		local var_135_1 = var_135_0:getBreakOutInfo()

		if not var_135_1:hasNextInfo() then
			return false
		end

		local var_135_2, var_135_3 = var_135_1:getLimited()

		if var_135_2 > arg_135_0.level then
			return false
		end

		return true
	else
		local var_134_4 = ship_data_breakout[arg_134_0.configId]

		assert(var_135_4, "不存在配置" .. arg_135_0.configId)

		return not arg_135_0:isMaxStar() and arg_135_0.level >= var_135_4.level
	end
end

function Ship.isReachNextMaxLevel(arg_135_0)
	return arg_135_0.level == arg_135_0:getMaxLevel() and arg_135_0:CanAccumulateExp() and arg_135_0:getNextMaxLevel() ~= nil
end

function Ship.isAwakening(arg_136_0)
	return arg_136_0:isReachNextMaxLevel() and arg_136_0.level < var_0_4
end

function Ship.isAwakening2(arg_137_0)
	return arg_137_0:isReachNextMaxLevel() and arg_137_0.level >= var_0_4
end

function Ship.notMaxLevelForFilter(arg_138_0)
	return arg_138_0.level ~= arg_138_0:getMaxLevel()
end

function Ship.getNextMaxLevelConsume(arg_139_0)
	local var_139_0 = arg_139_0:getMaxLevel()
	local var_139_1 = ship_level[var_139_0]["need_item_rarity" .. arg_139_0:getConfig("rarity")]

	assert(var_140_1, "items  can not be nil")

	return _.map(var_140_1, function(arg_141_0)
		return {
			type = arg_141_0[1],
			id = arg_141_0[2],
			count = arg_141_0[3]
		}
	end)
end

function Ship.canUpgradeMaxLevel(arg_141_0)
	if not arg_141_0:isReachNextMaxLevel() then
		return false, i18n("upgrade_to_next_maxlevel_failed")
	else
		local var_142_0 = getProxy(PlayerProxy):getData()
		local var_142_1 = getProxy(BagProxy)
		local var_142_2 = arg_142_0:getNextMaxLevelConsume()

		for iter_142_0, iter_142_1 in pairs(var_142_2) do
			if iter_142_1.type == DROP_TYPE_RESOURCE then
				if var_142_0:getResById(iter_142_1.id) < iter_142_1.count then
					return false, i18n("common_no_resource")
				end
			elseif iter_142_1.type == DROP_TYPE_ITEM and var_142_1:getItemCountById(iter_142_1.id) < iter_142_1.count then
				return false, i18n("common_no_item_1")
			end
		end
	end

	return true
end

function Ship.CanAccumulateExp(arg_142_0)
	return pg.ship_data_template[arg_142_0.configId].can_get_proficency == 1
end

function Ship.getTotalExp(arg_143_0)
	return arg_143_0:getLevelExpConfig().exp_start + arg_143_0.exp
end

function var_0_0.getStartBattleExpend(arg_145_0)
	if table.contains(ShipType.SubShipType, arg_145_0:getShipType()) then
		return 0
	else
		-- 返回oil_at_start字段
		-- 从模板的数据来看，只有0和1两种值，为0的也本身就是潜艇
		return pg.ship_data_template[self.configId].oil_at_start
	end
end

-- 计算战斗结算油耗
function Ship.getEndBattleExpend(self)
	local tmpData = pg.ship_data_template[self.configId]
	local levelExpConfig = self:getLevelExpConfig()
	-- fight_oil_ratio字段在ship_level表里，为方便直接总结公式为：
	-- 1: 5050, 2: 5100, ..., 98: 9900, 99: 9950, 再往后都是9950
	-- 因此公式为: fight_oil_ratio = 5000 + min(level, 99) * 50
	return (math.floor(tmpData.oil_at_end * levelExpConfig.fight_oil_ratio / 10000))
end

function Ship.getBattleTotalExpend(arg_146_0)
	return arg_146_0:getStartBattleExpend() + arg_146_0:getEndBattleExpend()
end

function Ship.getShipAmmo(arg_147_0)
	local var_147_0 = arg_147_0:getConfig(AttributeType.Ammo)

	for iter_147_0, iter_147_1 in pairs(arg_147_0:getAllSkills()) do
		local var_147_1 = tonumber(iter_147_0 .. string.format("%.2d", iter_147_1.level))
		local var_147_2 = pg.skill_benefit_template[var_147_1]

		if var_147_2 and arg_147_0:IsBenefitSkillActive(var_147_2) and (var_147_2.type == Ship.BENEFIT_EQUIP or var_147_2.type == Ship.BENEFIT_SKILL) then
			var_147_0 = var_147_0 + defaultValue(var_147_2.effect[1], 0)
		end
	end

	local var_147_3 = arg_147_0:getActiveEquipments()

	for iter_147_2, iter_147_3 in ipairs(var_147_3) do
		local var_147_4 = iter_147_3 and iter_147_3:getConfig("equip_parameters").ammo

		if var_147_4 then
			var_147_0 = var_147_0 + var_147_4
		end
	end

	return var_147_0
end

function Ship.getHuntingLv(arg_148_0)
	local var_148_0 = arg_148_0:getConfig("huntingrange_level")

	for iter_148_0, iter_148_1 in pairs(arg_148_0:getAllSkills()) do
		local var_148_1 = tonumber(iter_148_0 .. string.format("%.2d", iter_148_1.level))
		local var_148_2 = pg.skill_benefit_template[var_148_1]

		if var_148_2 and arg_148_0:IsBenefitSkillActive(var_148_2) and (var_148_2.type == Ship.BENEFIT_EQUIP or var_148_2.type == Ship.BENEFIT_SKILL) then
			var_148_0 = var_148_0 + defaultValue(var_148_2.effect[2], 0)
		end
	end

	local var_148_3 = arg_148_0:getActiveEquipments()

	for iter_148_2, iter_148_3 in ipairs(var_148_3) do
		local var_148_4 = iter_148_3 and iter_148_3:getConfig("equip_parameters").ammo

		if var_148_4 then
			var_148_0 = var_148_0 + var_148_4
		end
	end

	return var_148_0
end

function Ship.getMapAuras(arg_149_0)
	local var_149_0 = {}

	for iter_149_0, iter_149_1 in pairs(arg_149_0:getAllSkills()) do
		local var_149_1 = tonumber(iter_149_0 .. string.format("%.2d", iter_149_1.level))
		local var_149_2 = pg.skill_benefit_template[var_149_1]

		if var_149_2 and arg_149_0:IsBenefitSkillActive(var_149_2) and var_149_2.type == Ship.BENEFIT_MAP_AURA then
			local var_149_3 = {
				id = var_149_2.effect[1],
				level = iter_149_1.level
			}

			table.insert(var_149_0, var_149_3)
		end
	end

	return (math.min(var_149_0, arg_149_0:getMaxHuntingLv()))
end

-- 获取单个舰船提供的跨队增益
-- 被ChapterFleet.getMapAid调用
function Ship.getMapAids(self)
	local shipAidsList = {}
	-- 这边所有Skill，实际对应的是战斗中的Buff概念
	for skillID, skillConfig in pairs(self:getAllSkills()) do
		local benefitID = tonumber(skillID .. string.format("%.2d", skillConfig.level))
		-- 从skill_benefit_template表里拿增益信息
		local benefitTmp = pg.skill_benefit_template[benefitID]

		if benefitTmp and self:IsBenefitSkillActive(benefitTmp) and benefitTmp.type == Ship.BENEFIT_AID then
			local aidConfig = {
				id = benefitTmp.effect[1],
				level = skillConfig.level
			}

			table.insert(shipAidsList, aidConfig)
		end
	end

	return shipAidsList
end

Ship.BENEFIT_SKILL = 2
Ship.BENEFIT_EQUIP = 3
Ship.BENEFIT_MAP_AURA = 4
Ship.BENEFIT_AID = 5

function Ship.IsBenefitSkillActive(arg_151_0, arg_151_1)
	local var_151_0 = false

	if arg_151_1.type == Ship.BENEFIT_SKILL then
		if not arg_151_1.limit[1] or arg_151_1.limit[1] == arg_151_0.triggers.TeamNumbers then
			var_151_0 = true
		end
	elseif arg_151_1.type == Ship.BENEFIT_EQUIP then
		local var_151_1 = arg_151_1.limit
		local var_151_2 = arg_151_0:getAllEquipments()

		for iter_152_0, iter_152_1 in ipairs(var_152_2) do
			if iter_152_1 and table.contains(var_152_1, iter_152_1:getConfig("id")) then
				var_152_0 = true

				break
			end
		end
	elseif arg_151_1.type == Ship.BENEFIT_MAP_AURA then
		if arg_151_0.hpRant and arg_151_0.hpRant > 0 then
			return true
		end
	elseif arg_151_1.type == Ship.BENEFIT_AID and arg_151_0.hpRant and arg_151_0.hpRant > 0 then
		return true
	end

	return var_152_0
end

function Ship.getMaxHuntingLv(arg_152_0)
	return #arg_152_0:getConfig("hunting_range")
end

function Ship.getHuntingRange(arg_153_0, arg_153_1)
	local var_153_0 = arg_153_0:getConfig("hunting_range")
	local var_153_1 = Clone(var_153_0[1])
	local var_153_2 = arg_153_1 or arg_153_0:getHuntingLv()
	local var_153_3 = math.min(var_153_2, arg_153_0:getMaxHuntingLv())

	for iter_154_0 = 2, var_154_3 do
		_.each(var_154_0[iter_154_0], function(arg_155_0)
			table.insert(var_154_1, {
				arg_155_0[1],
				arg_155_0[2]
			})
		end)
	end

	return var_154_1
end

-- 被BattleMediator.GenBattleData调用
function Ship.getTriggerSkills(self)
	local triggerSkills = {}
	local skillEffects = self:getSkillEffects()

	_.each(skillEffects, function(effect)
		if effect.type == "AddBuff" and effect.arg_list and effect.arg_list.buff_id then
			local buffID = effect.arg_list.buff_id

			triggerSkills[buffID] = {
				id = buffID,
				level = effect.level
			}
		end
	end)

	return triggerSkills
end

function Ship.GetEquipmentSkills(effect)
	local var_157_0 = {}
	local var_157_1 = effect:getActiveEquipments()

	for iter_158_0, iter_158_1 in ipairs(var_158_1) do
		if iter_158_1 and iter_158_1:getConfig("skill_id")[1] then
			local var_158_2, var_158_3 = unpack(iter_158_1:getConfig("skill_id")[1])

			var_158_0[var_158_2] = {
				id = var_158_2,
				level = var_158_3
			}
		end
	end

	;(function()
		local var_159_0 = arg_158_0:GetSpWeapon()
		local var_159_1 = var_159_0 and var_159_0:GetEffect() or 0

		if var_159_1 > 0 then
			var_158_0[var_159_1] = {
				level = 1,
				id = var_159_1
			}
		end
	end)()

	return var_158_0
end

function Ship.getAllSkills(self)
	local skills = Clone(self.skills)

	for skillID, skillConfig in pairs(self:GetEquipmentSkills()) do
		skills[skillID] = skillConfig
	end

	for skillID, skillConfig in pairs(self:getTriggerSkills()) do
		skills[skillID] = skillConfig
	end
	-- 应当是一个ID->{id=ID, level=LV}的映射表
	return skills
end

function Ship.isSameKind(arg_160_0, arg_160_1)
	return pg.ship_data_template[arg_160_0.configId].group_type == pg.ship_data_template[arg_160_1.configId].group_type
end

function Ship.GetLockState(arg_161_0)
	return arg_161_0.lockState
end

function Ship.IsLocked(arg_162_0)
	return arg_162_0.lockState == Ship.LOCK_STATE_LOCK
end

function Ship.SetLockState(arg_163_0, arg_163_1)
	arg_163_0.lockState = arg_163_1
end

function Ship.GetPreferenceTag(arg_164_0)
	return arg_164_0.preferenceTag or 0
end

function Ship.IsPreferenceTag(arg_165_0)
	return arg_165_0:GetPreferenceTag() == Ship.PREFERENCE_TAG_COMMON
end

function Ship.SetPreferenceTag(arg_166_0, arg_166_1)
	arg_166_0.preferenceTag = arg_166_1
end

function Ship.calReturnRes(arg_167_0)
	local var_167_0 = pg.ship_data_by_type[arg_167_0:getShipType()]
	local var_167_1 = var_167_0.distory_resource_gold_ratio
	local var_167_2 = var_167_0.distory_resource_oil_ratio
	local var_167_3 = pg.ship_data_by_star[arg_167_0:getConfig("rarity")].destory_item

	return var_168_1, 0, var_168_3
end

function Ship.getRarity(arg_168_0)
	local var_168_0 = arg_168_0:getConfig("rarity")

	if arg_169_0:isRemoulded() then
		var_169_0 = var_169_0 + 1
	end

	return var_169_0
end

function Ship.updateSkill(arg_169_0, arg_169_1)
	local var_169_0 = arg_169_1.skill_id or arg_169_1.id
	local var_169_1 = arg_169_1.skill_lv or arg_169_1.lv or arg_169_1.level
	local var_169_2 = arg_169_1.skill_exp or arg_169_1.exp

	arg_170_0.skills[var_170_0] = {
		id = var_170_0,
		level = var_170_1,
		exp = var_170_2
	}
end

function Ship.canEquipAtPos(arg_170_0, arg_170_1, arg_170_2)
	local var_170_0, var_170_1 = arg_170_0:isForbiddenAtPos(arg_170_1, arg_170_2)

	if var_171_0 then
		return false, var_171_1
	end

	for iter_171_0, iter_171_1 in ipairs(arg_171_0.equipments) do
		if iter_171_1 and iter_171_0 ~= arg_171_2 and iter_171_1:getConfig("equip_limit") ~= 0 and arg_171_1:getConfig("equip_limit") == iter_171_1:getConfig("equip_limit") then
			return false, i18n("ship_equip_same_group_equipment")
		end
	end

	return true
end

function Ship.isForbiddenAtPos(arg_171_0, arg_171_1, arg_171_2)
	local var_171_0 = pg.ship_data_template[arg_171_0.configId]

	assert(var_172_0, "can not find ship in ship_data_templtae: " .. arg_172_0.configId)

	local var_172_1 = var_172_0["equip_" .. arg_172_2]

	if not table.contains(var_172_1, arg_172_1:getConfig("type")) then
		return true, i18n("common_limit_equip")
	end

	if table.contains(arg_172_1:getConfig("ship_type_forbidden"), arg_172_0:getShipType()) then
		return true, i18n("common_limit_equip")
	end

	return false
end

function Ship.canEquipCommander(arg_172_0, arg_172_1)
	if arg_172_1:getShipType() ~= arg_172_0:getShipType() then
		return false, i18n("commander_type_unmatch")
	end

	return true
end

function Ship.upgrade(arg_173_0)
	local var_173_0 = pg.ship_data_transform[arg_173_0.configId]

	if var_174_0.trans_id and var_174_0.trans_id > 0 then
		arg_174_0.configId = var_174_0.trans_id
		arg_174_0.star = arg_174_0:getConfig("star")
	end
end

function var_0_0.getTeamType(arg_175_0)
	return ShipType.GetTeamFromShipType(arg_175_0:getShipType())
end

function Ship.getFleetName(arg_175_0)
	local var_175_0 = arg_175_0:getTeamType()

	return fleetNames[var_175_0]
end

function Ship.getMaxConfigId(arg_176_0)
	local var_176_0 = pg.ship_data_template
	local var_176_1

	for iter_177_0 = 4, 1, -1 do
		local var_177_2 = tonumber(arg_177_0.groupId .. iter_177_0)

		if var_177_0[var_177_2] then
			var_177_1 = var_177_2

			break
		end
	end

	return var_177_1
end

function Ship.getFlag(arg_177_0, arg_177_1, arg_177_2)
	return pg.ShipFlagMgr.GetInstance():GetShipFlag(arg_177_0.id, arg_177_1, arg_177_2)
end

function Ship.hasAnyFlag(arg_178_0, arg_178_1)
	return _.any(arg_178_1, function(arg_179_0)
		return arg_178_0:getFlag(arg_179_0)
	end)
end

function Ship.isBreakOut(arg_180_0)
	return arg_180_0.configId % 10 > 1
end

function Ship.fateSkillChange(arg_181_0, arg_181_1)
	if not arg_181_0.skillChangeList then
		arg_181_0.skillChangeList = arg_181_0:isBluePrintShip() and arg_181_0:getBluePrint():getChangeSkillList() or {}
	end

	for iter_182_0, iter_182_1 in ipairs(self.skillChangeList) do
		if iter_182_1[1] == arg_182_1 and self.skills[iter_182_1[2]] then
			return iter_182_1[2]
		end
	end

	return arg_182_1
end


-- Buff ID的映射
-- 似乎只用于专武技能升级的映射
-- 这个函数多次使用，是递归调用的
-- 被BattleMediator.GenBattleData调用
function Ship.RemapSkillId(self, buffID, needMapHidden)
	local spWeapon = self:GetSpWeapon()

	if spWeapon then
		-- 如果属于隐藏技能，用隐藏技能映射表
		if table.contains(pg.ship_data_template[self.configId].hide_buff_list, buffID) then
			return spWeapon:RemapHiddenSkillId(buffID)
		elseif needMapHidden then
			local mapedHiddenBuffID = spWeapon:RemapHiddenSkillId(buffID)

			if mapedHiddenBuffID == buffID then
				mapedHiddenBuffID = spWeapon:RemapSkillId(buffID)
			end

			return mapedHiddenBuffID
		else
			return spWeapon:RemapSkillId(buffID)
		end
	end

	return buffID
end

-- Ship.getShipSkillEffects调用
function Ship.getSkillList(self)
	local shipTmpData = pg.ship_data_template[self.configId]
	local buff_list_display = Clone(shipTmpData.buff_list_display)
	local buff_list = Clone(shipTmpData.buff_list)
	local transData = pg.ship_data_trans[self.groupId]

	-- 改造技能
	if transData and transData.skill_id ~= 0 then
		local transSkillID = transData.skill_id
		local transDataTmp = pg.transform_data_template[transSkillID]

		if self.transforms[transSkillID] and transDataTmp.skill_id ~= 0 then
			table.insert(buff_list, transDataTmp.skill_id)
		end
	end

	local actualSkillList = {}

	for _, displayBuff in ipairs(buff_list_display) do
		for _, buff in ipairs(buff_list) do
			if displayBuff == buff then
				-- 天运拟合技能替换
				table.insert(actualSkillList, self:fateSkillChange(displayBuff))
			end
		end
	end

	return actualSkillList
end

function Ship.getModAttrTopLimit(self, arg_184_1)
	local var_184_0 = ShipModAttr.ATTR_TO_INDEX[arg_184_1]
	local var_184_1 = pg.ship_data_template[self.configId].strengthen_id
	local var_184_2 = pg.ship_data_strengthen[var_184_1].durability[var_184_0]

	return calcFloor((3 + 7 * (math.min(arg_185_0.level, 100) / 100)) * var_185_2 * 0.1)
end

function Ship.leftModAdditionPoint(arg_185_0, arg_185_1)
	local var_185_0 = arg_185_0:getModProperties(arg_185_1)
	local var_185_1 = arg_185_0:getModExpRatio(arg_185_1)
	local var_185_2 = arg_185_0:getModAttrTopLimit(arg_185_1)
	local var_185_3 = calcFloor(var_185_0 / var_185_1)

	return math.max(0, var_186_2 - var_186_3)
end

function Ship.getModAttrBaseMax(arg_186_0, arg_186_1)
	if not table.contains(arg_186_0:getConfig("lock"), arg_186_1) then
		local var_186_0 = arg_186_0:leftModAdditionPoint(arg_186_1)
		local var_186_1 = arg_186_0:getShipProperties()

		return calcFloor(var_187_1[arg_187_1] + var_187_0)
	else
		return 0
	end
end

--- @class Ship
--- @param property string
--- @return number
--- 获取强化一级需要的经验值
function Ship.getModExpRatio(self, property)
	-- 不考虑lock中的属性，lock属性不能强化
	if not table.contains(self:getConfig("lock"), property) then
		local strengthenID = pg.ship_data_template[self.configId].strengthen_id

		assert(pg.ship_data_strengthen[strengthenID], "ship_data_strengthen>>>>>>" .. strengthenID)

		return math.max(pg.ship_data_strengthen[strengthenID].level_exp[ShipModAttr.ATTR_TO_INDEX[property]], 1)
	else
		return 1
	end
end

function Ship.inUnlockTip(arg_188_0)
	local var_188_0 = pg.gameset.tip_unlock_shipIds.description[0]

	return table.contains(var_189_0, arg_189_0)
end

function Ship.proposeSkinOwned(arg_189_0, arg_189_1)
	return arg_189_1 and arg_189_0.propose and arg_189_1.skin_type == ShipSkin.SKIN_TYPE_PROPOSE
end

function Ship.getProposeSkin(arg_190_0)
	return ShipSkin.GetSkinByType(arg_190_0.groupId, ShipSkin.SKIN_TYPE_PROPOSE)
end

function Ship.getDisplaySkillIds(arg_191_0)
	return _.map(pg.ship_data_template[arg_191_0.configId].buff_list_display, function(arg_192_0)
		return arg_191_0:fateSkillChange(arg_192_0)
	end)
end

function Ship.isFullSkillLevel(arg_193_0)
	local var_193_0 = pg.skill_data_template

	for iter_194_0, iter_194_1 in pairs(arg_194_0.skills) do
		if var_194_0[iter_194_1.id].max_level ~= iter_194_1.level then
			return false
		end
	end

	return true
end

function Ship.setEquipmentRecord(arg_194_0, arg_194_1, arg_194_2)
	local var_194_0 = "equipment_record" .. "_" .. arg_194_1 .. "_" .. arg_194_0.id

	PlayerPrefs.SetString(var_195_0, table.concat(_.flatten(arg_195_2), ":"))
	PlayerPrefs.Save()
end

function Ship.getEquipmentRecord(arg_195_0, arg_195_1)
	if not arg_195_0.equipmentRecords then
		local var_195_0 = "equipment_record" .. "_" .. arg_195_1 .. "_" .. arg_195_0.id
		local var_195_1 = string.split(PlayerPrefs.GetString(var_195_0) or "", ":")
		local var_195_2 = {}

		for iter_196_0 = 1, 3 do
			var_196_2[iter_196_0] = _.map(_.slice(var_196_1, 5 * iter_196_0 - 4, 5), function(arg_197_0)
				return tonumber(arg_197_0)
			end)
		end

		arg_196_0.equipmentRecords = var_196_2
	end

	return arg_196_0.equipmentRecords
end

function Ship.SetSpWeaponRecord(arg_197_0, arg_197_1, arg_197_2)
	local var_197_0 = "spweapon_record" .. "_" .. arg_197_1 .. "_" .. arg_197_0.id
	local var_197_1 = _.map({
		1,
		2,
		3
	}, function(arg_199_0)
		local var_199_0 = arg_198_2[arg_199_0]

		if var_199_0 then
			return (var_199_0:GetUID() or 0) .. "," .. var_199_0:GetConfigID()
		else
			return "0,0"
		end
	end)

	PlayerPrefs.SetString(var_198_0, table.concat(var_198_1, ":"))
	PlayerPrefs.Save()
end

function Ship.GetSpWeaponRecord(arg_199_0, arg_199_1)
	local var_199_0 = "spweapon_record" .. "_" .. arg_199_1 .. "_" .. arg_199_0.id

	return (_.map(string.split(PlayerPrefs.GetString(var_200_0, ""), ":"), function(arg_201_0)
		local var_201_0 = string.split(arg_201_0, ",")

		assert(var_201_0)

		local var_201_1 = tonumber(var_201_0[1])
		local var_201_2 = tonumber(var_201_0[2])

		if not var_201_2 or var_201_2 == 0 then
			return false
		end

		return (SpWeapon.New({
			id = var_201_2
		}))
	end))
end

function Ship.hasEquipEquipmentSkin(arg_201_0)
	for iter_201_0, iter_201_1 in ipairs(arg_201_0.equipments) do
		if iter_201_1 and iter_201_1:hasSkin() then
			return true
		end
	end

	return false
end

function Ship.hasCommander(arg_202_0)
	return arg_202_0.commanderId and arg_202_0.commanderId ~= 0
end

function Ship.getCommander(arg_203_0)
	return arg_203_0.commanderId
end

function Ship.setCommander(arg_204_0, arg_204_1)
	arg_204_0.commanderId = arg_204_1
end

function Ship.getSkillIndex(arg_205_0, arg_205_1)
	local var_205_0 = arg_205_0:getSkillList()

	for iter_206_0, iter_206_1 in ipairs(var_206_0) do
		if arg_206_1 == iter_206_1 then
			return iter_206_0
		end
	end
end

function Ship.getTactics(arg_206_0)
	return 1, "tactics_attack"
end

function Ship.IsBgmSkin(arg_207_0)
	local var_207_0 = arg_207_0:GetSkinConfig()

	return table.contains(var_208_0.tag, ShipSkin.WITH_BGM)
end

function Ship.GetSkinBgm(arg_208_0)
	if arg_208_0:IsBgmSkin() then
		return arg_208_0:GetSkinConfig().bgm
	end
end

function Ship.isIntensifyMax(arg_209_0)
	local var_209_0 = intProperties(arg_209_0:getShipProperties())

	if arg_210_0:isBluePrintShip() then
		return true
	end

	for iter_210_0, iter_210_1 in pairs(ShipModAttr.ID_TO_ATTR) do
		if arg_210_0:getModAttrBaseMax(iter_210_1) ~= var_210_0[iter_210_1] then
			return false
		end
	end

	return true
end

function Ship.isRemouldable(arg_210_0)
	return not arg_210_0:isTestShip() and not arg_210_0:isBluePrintShip() and pg.ship_data_trans[arg_210_0.groupId]
end

function Ship.isAllRemouldFinish(arg_211_0)
	local var_211_0 = pg.ship_data_trans[arg_211_0.groupId]

	assert(var_212_0, "this ship group without remould config:" .. arg_212_0.groupId)

	for iter_212_0, iter_212_1 in ipairs(var_212_0.transform_list) do
		for iter_212_2, iter_212_3 in ipairs(iter_212_1) do
			local var_212_1 = pg.transform_data_template[iter_212_3[2]]

			if #var_212_1.edit_trans > 0 then
				-- block empty
			elseif not arg_212_0.transforms[iter_212_3[2]] or arg_212_0.transforms[iter_212_3[2]].level < var_212_1.max_level then
				return false
			end
		end
	end

	return true
end

function Ship.isSpecialFilter(arg_212_0)
	local var_212_0 = pg.ship_data_statistics[arg_212_0.configId]

	assert(var_213_0, "this ship without statistics:" .. arg_213_0.configId)

	for iter_213_0, iter_213_1 in ipairs(var_213_0.tag_list) do
		if iter_213_1 == "special" then
			return true
		end
	end

	return false
end

function Ship.hasAvailiableSkin(arg_213_0)
	local var_213_0 = getProxy(ShipSkinProxy)
	local var_213_1 = var_213_0:GetAllSkinForShip(arg_213_0)
	local var_213_2 = var_213_0:getRawData()
	local var_213_3 = 0

	for iter_214_0, iter_214_1 in ipairs(var_214_1) do
		if arg_214_0:proposeSkinOwned(iter_214_1) or var_214_2[iter_214_1.id] or var_214_0:hasSkin(iter_214_1.id) then
			var_214_3 = var_214_3 + 1
		end
	end

	return var_214_3 > 0
end

function Ship.hasProposeSkin(arg_214_0)
	local var_214_0 = getProxy(ShipSkinProxy)
	local var_214_1 = var_214_0:GetAllSkinForShip(arg_214_0)

	for iter_215_0, iter_215_1 in ipairs(var_215_1) do
		if iter_215_1.skin_type == ShipSkin.SKIN_TYPE_PROPOSE then
			return true
		end
	end

	local var_215_2 = var_215_0:GetShareSkinsForShip(arg_215_0)

	for iter_215_2, iter_215_3 in ipairs(var_215_2) do
		if iter_215_3.skin_type == ShipSkin.SKIN_TYPE_PROPOSE then
			return true
		end
	end

	return false
end

function Ship.HasUniqueSpWeapon(arg_215_0)
	return tobool(pg.spweapon_data_statistics.get_id_list_by_unique[arg_215_0:getGroupId()])
end

function Ship.getAircraftReloadCD(arg_216_0)
	local var_216_0 = arg_216_0:getConfigTable().base_list
	local var_216_1 = arg_216_0:getConfigTable().default_equip_list
	local var_216_2 = 0
	local var_216_3 = 0

	for iter_217_0 = 1, 3 do
		local var_217_4 = arg_217_0:getEquip(iter_217_0)
		local var_217_5 = var_217_4 and var_217_4.configId or var_217_1[iter_217_0]
		local var_217_6 = Equipment.getConfigData(var_217_5).type

		if underscore.any(EquipType.AirEquipTypes, function(arg_218_0)
			return var_217_6 == arg_218_0
		end) then
			-- TODO
			-- 获取的是reload_max
			var_216_2 = var_216_2 + Equipment.GetEquipReloadStatic(var_216_5) * var_216_0[iter_216_0]
			var_216_3 = var_216_3 + var_216_0[iter_216_0]
		end
	end

	local var_217_7 = ys.Battle.BattleConfig.AIR_ASSIST_RELOAD_RATIO * pg.bfConsts.PERCENT

	return {
		name = i18n("equip_info_31"),
		type = AttributeType.CD,
		value = var_217_2 / var_217_3 * var_217_7
	}
end

function Ship.IsTagShip(arg_218_0, arg_218_1)
	local var_218_0 = arg_218_0:getConfig("tag_list")

	return table.contains(var_219_0, arg_219_1)
end

function Ship.setReMetaSpecialItemVO(arg_219_0, arg_219_1)
	arg_219_0.reMetaSpecialItemVO = arg_219_1
end

function Ship.getReMetaSpecialItemVO(arg_220_0, arg_220_1)
	return arg_220_0.reMetaSpecialItemVO
end

function Ship.getProposeType(arg_221_0)
	if arg_221_0:isMetaShip() then
		return "meta"
	elseif arg_222_0:IsXIdol() then
		return "imas"
	else
		return "default"
	end
end

function Ship.IsXIdol(arg_222_0)
	return arg_222_0:getNation() == Nation.IDOL_LINK
end

function Ship.getSpecificType(arg_223_0)
	return pg.ship_data_template[arg_223_0.configId].specific_type
end

function Ship.GetSpWeapon(self)
	return self.spWeapon
end

function Ship.UpdateSpWeapon(arg_225_0, arg_225_1)
	local var_225_0 = (arg_225_1 and arg_225_1:GetUID() or 0) == (arg_225_0.spWeapon and arg_225_0.spWeapon:GetUID() or 0)

	arg_226_0.spWeapon = arg_226_1

	if arg_226_1 then
		arg_226_1:SetShipId(arg_226_0.id)
	end

	if var_226_0 then
		pg.m02:sendNotification(EquipmentProxy.SPWEAPONS_UPDATED)
	end
end

function Ship.CanEquipSpWeapon(arg_226_0, arg_226_1)
	local var_226_0, var_226_1 = arg_226_0:IsSpWeaponForbidden(arg_226_1)

	if var_227_0 then
		return false, var_227_1
	end

	return true
end

function Ship.IsSpWeaponForbidden(arg_227_0, arg_227_1)
	local var_227_0 = arg_227_1:GetWearableShipTypes()
	local var_227_1 = arg_227_0:getShipType()

	if not table.contains(var_228_0, var_228_1) then
		return true, i18n("spweapon_tip_group_error")
	end

	local var_228_2 = arg_228_1:GetUniqueGroup()
	local var_228_3 = arg_228_0:getGroupId()

	if var_228_2 ~= 0 and var_228_2 ~= var_228_3 then
		return true, i18n("spweapon_tip_group_error")
	end

	return false
end

function Ship.GetMapStrikeAnim(arg_228_0)
	local var_228_0
	local var_228_1 = arg_228_0:getShipType()

	switch(ShipType.GetTeamFromShipType(var_229_1), {
		[TeamType.Main] = function()
			if ShipType.IsTypeQuZhu(var_229_1) then
				var_229_0 = "SubTorpedoUI"
			elseif ShipType.ContainInLimitBundle(ShipType.BundleAircraftCarrier, var_229_1) then
				var_229_0 = "AirStrikeUI"
			elseif ShipType.ContainInLimitBundle(ShipType.BundleBattleShip, var_229_1) then
				var_229_0 = "CannonUI"
			else
				var_229_0 = "CannonUI"
			end
		end,
		[TeamType.Vanguard] = function()
			if ShipType.IsTypeQuZhu(var_229_1) then
				var_229_0 = "SubTorpedoUI"
			end
		end,
		[TeamType.Submarine] = function()
			if arg_229_0:getNation() == Nation.MOT then
				var_229_0 = "CannonUI"
			else
				var_229_0 = "SubTorpedoUI"
			end
		end
	})

	return var_229_0
end

function Ship.IsDefaultSkin(arg_232_0)
	local var_232_0 = arg_232_0:getSkinId()

	return var_233_0 == 0 or var_233_0 == arg_233_0:getConfig("skin_id")
end

function Ship.IsMatchKey(arg_233_0, arg_233_1)
	if not arg_233_1 or arg_233_1 == "" then
		return true
	end

	arg_234_1 = string.lower(string.gsub(arg_234_1, "%.", "%%."))

	local var_234_0 = {
		arg_234_0:getName(),
		arg_234_0:GetDefaultName()
	}

	if var_234_0[1] == var_234_0[2] then
		table.remove(var_234_0)
	end

	return underscore.any(var_234_0, function(arg_235_0)
		return string.find(string.lower(arg_235_0), arg_234_1)
	end)
end

function Ship.IsOwner(arg_235_0)
	return tobool(arg_235_0.id)
end

function Ship.GetUniqueId(arg_236_0)
	return arg_236_0.id
end

function Ship.ShowPropose(arg_237_0)
	if not arg_237_0.propose then
		return false
	else
		return not HXSet.isHxPropose() or arg_238_0:IsOwner() and arg_238_0:GetUniqueId() == getProxy(PlayerProxy):getRawData():GetProposeShipId()
	end
end

function Ship.GetColorName(arg_238_0, arg_238_1)
	arg_238_1 = arg_238_1 or arg_238_0:getName()

	if PlayerPrefs.GetInt("SHIP_NAME_COLOR", PLATFORM_CODE == PLATFORM_CH and 1 or 0) == 1 and arg_239_0.propose then
		return setColorStr(arg_239_1, "#FFAACEFF")
	else
		return arg_239_1
	end
end

local var_0_9 = {
	effect = {
		"duang_meta_jiehun",
		"duang_6_jiehun_tuzhi",
		"duang_6_jiehun",
		"duang_meta_%s",
		"duang_6"
	},
	frame = {
		"prop4_1",
		"prop%s",
		"prop"
	}
}

function Ship.GetFrameAndEffect(arg_239_0, arg_239_1)
	arg_239_1 = tobool(arg_239_1)

	local var_240_0
	local var_240_1

	if arg_240_0.propose then
		if arg_240_0:isMetaShip() then
			var_240_1 = string.format(var_0_9.effect[1])
			var_240_0 = string.format(var_0_9.frame[1])
		elseif arg_240_0:isBluePrintShip() then
			var_240_1 = string.format(var_0_9.effect[2])
			var_240_0 = string.format(var_0_9.frame[2], arg_240_0:rarity2bgPrint())
		else
			var_240_1 = string.format(var_0_9.effect[3])
			var_240_0 = string.format(var_0_9.frame[3])
		end

		if not arg_240_0:ShowPropose() then
			var_240_0 = nil
		end
	elseif arg_240_0:isMetaShip() then
		var_240_1 = string.format(var_0_9.effect[4], arg_240_0:rarity2bgPrint())
	elseif arg_240_0:getRarity() == ShipRarity.SSR then
		var_240_1 = string.format(var_0_9.effect[5])
	end

	if arg_240_1 then
		var_240_1 = var_240_1 and var_240_1 .. "_1"
	end

	return var_240_0, var_240_1
end

function Ship.GetRecordPosKey(arg_240_0)
	return arg_240_0:getSkinId()
end

function Ship.GetShipPhantomMark(arg_241_0, arg_241_1)
	return ShipPhantom.PackMark(arg_241_0.id, arg_241_1)
end

function Ship.GetSelectMark(arg_242_0)
	return arg_242_0.id
end

return Ship
