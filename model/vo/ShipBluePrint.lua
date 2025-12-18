local ShipBluePrint = class("ShipBluePrint", import(".BaseVO"))

ShipBluePrint.STATE_LOCK = 1
ShipBluePrint.STATE_DEV = 2
ShipBluePrint.STATE_DEV_FINISHED = 3
ShipBluePrint.STATE_UNLOCK = 4
ShipBluePrint.TASK_STATE_LOCK = 1
ShipBluePrint.TASK_STATE_OPENING = 2
ShipBluePrint.TASK_STATE_WAIT = 3
ShipBluePrint.TASK_STATE_START = 4
ShipBluePrint.TASK_STATE_ACHIEVED = 5
ShipBluePrint.TASK_STATE_FINISHED = 6
ShipBluePrint.TASK_STATE_PAUSE = 7
ShipBluePrint.STRENGTHEN_TYPE_ATTR = "attr"
ShipBluePrint.STRENGTHEN_TYPE_DIALOGUE = "dialog"
ShipBluePrint.STRENGTHEN_TYPE_SKILL = "skill"
ShipBluePrint.STRENGTHEN_TYPE_CHANGE_SKILL = "change_skill"
ShipBluePrint.STRENGTHEN_TYPE_BASE_LIST = "base"
ShipBluePrint.STRENGTHEN_TYPE_SKIN = "skin"
ShipBluePrint.STRENGTHEN_TYPE_BREAKOUT = "breakout"
ShipBluePrint.STRENGTHEN_TYPE_PRLOAD_COUNT = "preload"
ShipBluePrint.STRENGTHEN_TYPE_EQUIPMENTPROFICIENCY = "equipmentproficiency"

local ship_data_blueprint = pg.ship_data_blueprint
local ship_strengthen_blueprint = pg.ship_strengthen_blueprint
local var_0_3 = false

function ShipBluePrint.print(...)
	if var_0_3 then
		print(...)
	end
end

function ShipBluePrint.Ctor(self, arg_2_1)
	self.configId = arg_2_1.id
	self.id = self.configId
	self.state = ShipBluePrint.STATE_LOCK
	self.startTime = 0
	self.shipId = 0
	self.duration = 0
	self.level = 0
	self.fateLevel = -1
	self.exp = 0
	self.strengthenConfig = {}
	-- configTable是ship_data_blueprint
	for level, effectID in ipairs(self:getConfig("strengthen_effect")) do
		-- ship_strengthen_blueprint对应ID的表
		local effectTmp = Clone(ship_strengthen_blueprint[effectID])

		if effectTmp.special == 1 then
			self:warpspecialEffect(effectTmp)
		end
		-- strengthenConfig配置的就是ship_strengthen_blueprint每一级对应的表
		self.strengthenConfig[level] = effectTmp
	end

	self.fateStrengthenConfig = {}

	for fateLevel, fateEffectID in ipairs(self:getConfig("fate_strengthen")) do
		local fateEffectTmp = Clone(ship_strengthen_blueprint[fateEffectID])

		if fateEffectTmp.special == 1 then
			self:warpspecialEffect(fateEffectTmp)
		end

		self.fateStrengthenConfig[fateLevel] = fateEffectTmp
	end
end

function ShipBluePrint.warpspecialEffect(self, template)
	local special_effect = {}
	local effectDescList = string.split(template.effect_desc, "|")
	local index = 0

	if type(template.effect_attr) == "table" then
		for _, attrTable in ipairs(template.effect_attr) do
			index = index + 1
			-- 每一项的格式是一个表
				-- 第一项是类别，属于字符串
				-- 第二项是具体数值，是一个表，格式示例：{"durability"，596}
				-- 第三项是描述，属于字符串
			table.insert(special_effect, {
				ShipBluePrint.STRENGTHEN_TYPE_ATTR,
				attrTable,
				effectDescList[index] or ""
			})
		end

		template.effect_attr = nil
	end

	if template.effect_breakout ~= 0 then
		index = index + 1
		-- 这是突破效果，表示突破后的舰船ID
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_BREAKOUT,
			template.effect_breakout,
			effectDescList[index] or ""
		})

		template.effect_breakout = nil
	end

	if type(template.effect_skill) == "table" then
		index = index + 1
		-- 目前看起来全空，不用管
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_SKILL,
			template.effect_skill,
			effectDescList[index] or ""
		})

		template.effect_skill = nil
	end

	if type(template.change_skill) == "table" then
		index = index + 1
		-- 天运会修改的技能
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_CHANGE_SKILL,
			template.change_skill,
			effectDescList[index] or ""
		})

		template.change_skill = nil
	end

	if type(template.effect_base) == "table" then
		index = index + 1
		-- 目前看起来全空，不用管
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_BASE_LIST,
			template.effect_base,
			effectDescList[index] or ""
		})

		template.effect_base = nil
	end

	if type(template.effect_preload) == "table" then
		index = index + 1
		-- 目前看起来全空，不用管
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_PRLOAD_COUNT,
			template.effect_preload,
			effectDescList[index] or ""
		})

		template.effect_preload = nil
	end

	if type(template.effect_dialog) == "table" then
		index = index + 1
		-- 不用管
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_DIALOGUE,
			template.effect_dialog,
			effectDescList[index] or ""
		})

		template.effect_dialog = nil
	end

	if template.effect_skin ~= 0 then
		index = index + 1
		-- 不用管
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_SKIN,
			template.effect_skin,
			effectDescList[index] or ""
		})

		template.effect_skin = nil
	end

	if type(template.effect_equipment_proficiency) == "table" then
		local index = index + 1
		-- 武器效率提高，格式：{equipIndex, value}
		table.insert(special_effect, {
			ShipBluePrint.STRENGTHEN_TYPE_EQUIPMENTPROFICIENCY,
			template.effect_equipment_proficiency,
			effectDescList[index] or ""
		})
	end

	template.special_effect = special_effect
end

function ShipBluePrint.updateInfo(arg_4_0, arg_4_1)
	arg_4_0.startTime = arg_4_1.start_time or 0
	arg_4_0.shipId = arg_4_1.ship_id or 0
	arg_4_0.level = arg_4_1.blue_print_level and math.min(arg_4_1.blue_print_level, arg_4_0:getMaxLevel()) or 0
	arg_4_0.fateLevel = arg_4_0.level == arg_4_0:getMaxLevel() and arg_4_1.blue_print_level - arg_4_0:getMaxLevel() or -1
	arg_4_0.exp = arg_4_1.exp or 0
	arg_4_0.duration = arg_4_1.start_duration or 0

	arg_4_0:updateState()
end

function ShipBluePrint.updateStartUpTime(arg_5_0, arg_5_1)
	arg_5_0.duration = arg_5_1
end

function ShipBluePrint.updateState(arg_6_0)
	if arg_6_0:isFetched() then
		arg_6_0.state = ShipBluePrint.STATE_UNLOCK
	elseif arg_6_0.startTime == 0 then
		arg_6_0.state = ShipBluePrint.STATE_LOCK
	elseif arg_6_0:isFinishedAllTasks() then
		arg_6_0.state = ShipBluePrint.STATE_DEV_FINISHED
	else
		arg_6_0.state = ShipBluePrint.STATE_DEV
	end
end

function ShipBluePrint.addExp(arg_7_0, arg_7_1)
	assert(arg_7_1, "exp can not be nil")

	arg_7_0.exp = arg_7_0.exp + arg_7_1

	local var_7_0 = arg_7_0:getMaxLevel()

	if var_7_0 > arg_7_0.level then
		while arg_7_0:canLevelUp() do
			local var_7_1 = arg_7_0:getNextLevelExp()

			arg_7_0.exp = arg_7_0.exp - var_7_1
			arg_7_0.level = math.min(arg_7_0.level + 1, var_7_0)
		end

		if arg_7_0.level == var_7_0 then
			arg_7_0.fateLevel = 0
		end
	end

	if arg_7_0:canFateSimulation() then
		local var_7_2 = arg_7_0:getMaxFateLevel()

		while arg_7_0:canFateLevelUp() do
			local var_7_3 = arg_7_0:getNextFateLevelExp()

			arg_7_0.exp = arg_7_0.exp - var_7_3
			arg_7_0.fateLevel = math.min(arg_7_0.fateLevel + 1, var_7_2)
		end
	end
end

function ShipBluePrint.getNextLevelExp(arg_8_0)
	if arg_8_0.level == arg_8_0:getMaxLevel() then
		return -1
	else
		local var_8_0 = arg_8_0.level + 1

		return arg_8_0.strengthenConfig[var_8_0].need_exp
	end
end

function ShipBluePrint.getNextFateLevelExp(arg_9_0)
	if arg_9_0.fateLevel == arg_9_0:getMaxFateLevel() then
		return -1
	else
		local var_9_0 = arg_9_0.fateLevel + 1

		return arg_9_0.fateStrengthenConfig[var_9_0].need_exp
	end
end

function ShipBluePrint.canLevelUp(arg_10_0)
	if arg_10_0.level == arg_10_0:getMaxLevel() then
		return false
	end

	if arg_10_0:getNextLevelExp() <= arg_10_0.exp then
		return true
	end

	return false
end

function ShipBluePrint.canFateSimulation(arg_11_0)
	return #arg_11_0.fateStrengthenConfig > 0 and arg_11_0.fateLevel >= 0
end

function ShipBluePrint.canFateLevelUp(arg_12_0)
	if arg_12_0.fateLevel == arg_12_0:getMaxFateLevel() then
		return false
	end

	if arg_12_0:getNextFateLevelExp() <= arg_12_0.exp then
		return true
	end

	return false
end

function ShipBluePrint.getMaxLevel(arg_13_0)
	return arg_13_0.strengthenConfig[#arg_13_0.strengthenConfig].lv
end

function ShipBluePrint.getMaxFateLevel(arg_14_0)
	return arg_14_0.fateStrengthenConfig[#arg_14_0.fateStrengthenConfig].lv - 30
end

function ShipBluePrint.isMaxLevel(arg_15_0)
	return arg_15_0.level == arg_15_0:getMaxLevel()
end

function ShipBluePrint.isMaxFateLevel(arg_16_0)
	return arg_16_0.fateLevel == arg_16_0:getMaxFateLevel()
end

function ShipBluePrint.isMaxIntensifyLevel(arg_17_0)
	if #arg_17_0:getConfig("fate_strengthen") > 0 then
		return arg_17_0:isMaxFateLevel()
	else
		return arg_17_0:isMaxLevel()
	end
end

function ShipBluePrint.getBluePrintAddition(self, property)
	-- BLUEPRINT_ATTRS 与常规一致，按顺序为炮击、雷击、防空、航空、装填
	local propertyIndex = table.indexof(ShipModAttr.BLUEPRINT_ATTRS, property)
	-- 每级需要的经验值
	local propertyExp = self:getConfig("attr_exp")[propertyIndex]

	if propertyExp then
		local totalStrengthenExp = 0

		for level = 1, self.level do
			totalStrengthenExp = totalStrengthenExp + self.strengthenConfig[level].effect[propertyIndex]
		end

		local restExp = 0

		if not self:isMaxLevel() then
			-- need_exp字段
			local nextLevelExp = self:getNextLevelExp()
			-- self.exp应该是当前等级的exp, 所以要除以nextLevelExp，得到当前等级的经验百分比
			-- 因此可以获得下一级的部分强化经验值
			-- 注意区分船的exp和强化exp，不是同一个概念
			restExp = self.exp / nextLevelExp * self.strengthenConfig[self.level + 1].effect[propertyIndex]
		end

		local bluePrintAddition = (totalStrengthenExp + restExp) / propertyExp
		local restStrengthenExp = (totalStrengthenExp + restExp) % propertyExp

		return bluePrintAddition, restStrengthenExp
	else
		return 0, 0
	end
end

function ShipBluePrint.getShipVO(arg_19_0)
	return Ship.New({
		configId = tonumber(arg_19_0.id .. "1")
	})
end

function ShipBluePrint.isFetched(arg_20_0)
	return arg_20_0.shipId ~= 0
end

function ShipBluePrint.getState(arg_21_0)
	return arg_21_0.state
end

function ShipBluePrint.start(arg_22_0, arg_22_1)
	arg_22_0.state = ShipBluePrint.STATE_DEV
	arg_22_0.startTime = arg_22_1
	arg_22_0.duration = 0
end

function ShipBluePrint.reset(arg_23_0)
	arg_23_0.state = ShipBluePrint.STATE_LOCK
	arg_23_0.startTime = 0
end

function ShipBluePrint.isLock(arg_24_0)
	return arg_24_0.state == ShipBluePrint.STATE_LOCK
end

function ShipBluePrint.isDeving(arg_25_0)
	return arg_25_0.state == ShipBluePrint.STATE_DEV
end

function ShipBluePrint.isFinished(arg_26_0)
	return arg_26_0.state == ShipBluePrint.STATE_DEV_FINISHED
end

function ShipBluePrint.finish(arg_27_0)
	arg_27_0.state = ShipBluePrint.STATE_DEV_FINISHED
end

function ShipBluePrint.unlock(arg_28_0, arg_28_1)
	arg_28_0.shipId = arg_28_1
	arg_28_0.state = ShipBluePrint.STATE_UNLOCK
	arg_28_0.duration = 0
end

function ShipBluePrint.isUnlock(arg_29_0)
	return arg_29_0.state == ShipBluePrint.STATE_UNLOCK
end

function ShipBluePrint.getItemId(arg_30_0)
	return arg_30_0:getConfig("strengthen_item")
end

function ShipBluePrint.bindConfigTable(arg_31_0)
	return pg.ship_data_blueprint
end

function ShipBluePrint.getTaskIds(arg_32_0)
	return _.map(arg_32_0:getConfig("unlock_task"), function(arg_33_0)
		return arg_33_0[1]
	end)
end

function ShipBluePrint.getTaskOpenTimeStamp(arg_34_0, arg_34_1)
	local var_34_0 = table.indexof(arg_34_0:getTaskIds(), arg_34_1)

	return arg_34_0:getConfig("unlock_task")[var_34_0][2] + arg_34_0.startTime + 1
end

function ShipBluePrint.isFinishedAllTasks(arg_35_0)
	local var_35_0 = getProxy(TaskProxy)

	return _.all(arg_35_0:getTaskIds(), function(arg_36_0)
		return arg_35_0:getTaskStateById(arg_36_0) == ShipBluePrint.TASK_STATE_FINISHED
	end)
end

function ShipBluePrint.getTaskStateById(arg_37_0, arg_37_1)
	if arg_37_0:isLock() then
		if arg_37_0.duration > 0 then
			return ShipBluePrint.TASK_STATE_PAUSE
		else
			return ShipBluePrint.TASK_STATE_LOCK
		end
	elseif arg_37_0:getTaskOpenTimeStamp(arg_37_1) > pg.TimeMgr.GetInstance():GetServerTime() then
		return ShipBluePrint.TASK_STATE_WAIT
	else
		local var_37_0 = getProxy(TaskProxy):getTaskVO(arg_37_1)

		if var_37_0 and var_37_0:isReceive() then
			return ShipBluePrint.TASK_STATE_FINISHED
		elseif var_37_0 and var_37_0:isFinish() then
			return ShipBluePrint.TASK_STATE_ACHIEVED
		elseif var_37_0 then
			return ShipBluePrint.TASK_STATE_START
		else
			return ShipBluePrint.TASK_STATE_OPENING
		end
	end
end

function ShipBluePrint.getExpRetio(arg_38_0, arg_38_1)
	local var_38_0 = arg_38_0:getConfig("attr_exp")

	assert(arg_38_1 > 0 and arg_38_1 <= #var_38_0, "invalid index" .. arg_38_1)

	return var_38_0[arg_38_1]
end

function ShipBluePrint.specialStrengthens(arg_39_0)
	local var_39_0 = {}
	local var_39_1 = noEmptyStr(arg_39_0:getConfig("normal_display"))

	if var_39_1 then
		table.insert(var_39_0, {
			level = 0,
			des = {},
			extraDes = var_39_1
		})
	end

	for iter_39_0, iter_39_1 in ipairs(arg_39_0.strengthenConfig) do
		if iter_39_1.special == 1 then
			table.insert(var_39_0, {
				des = iter_39_1.special_effect,
				extraDes = iter_39_1.extra_desc,
				level = iter_39_1.lv
			})
		end
	end

	return var_39_0
end

function ShipBluePrint.getSpecials(arg_40_0)
	return arg_40_0.strengthenConfig[arg_40_0.level].special_effect
end

function ShipBluePrint.getTopLimitAttrValue(arg_41_0, arg_41_1)
	if arg_41_0.level == 0 then
		return 0
	else
		local var_41_0 = arg_41_0.strengthenConfig[arg_41_0.level].effect
		local var_41_1 = var_41_0[arg_41_1]

		assert(var_41_0[arg_41_1], "strengthen config effect" .. arg_41_1)

		local var_41_2 = arg_41_0:getConfig("attr_exp")[arg_41_1]

		return math.floor(var_41_1 / var_41_2)
	end
end

function ShipBluePrint.getItemExp(arg_42_0)
	local var_42_0 = arg_42_0:getConfig("strengthen_item")

	return Item.getConfigData(var_42_0).usage_arg[1]
end

function ShipBluePrint.getShipProperties(arg_43_0, arg_43_1, arg_43_2)
	assert(arg_43_1, "shipVO can not be nil" .. arg_43_0.shipId)

	local var_43_0 = arg_43_1:getBaseProperties()

	arg_43_2 = defaultValue(arg_43_2, true)

	local var_43_1 = arg_43_0:getTotalAdditions()

	for iter_43_0, iter_43_1 in pairs(var_43_0) do
		var_43_0[iter_43_0] = var_43_0[iter_43_0] + (var_43_1[iter_43_0] or 0)
	end

	if arg_43_1:getIntimacyLevel() > 0 and arg_43_2 then
		local var_43_2 = pg.intimacy_template[arg_43_1:getIntimacyLevel()].attr_bonus * 0.0001

		for iter_43_2, iter_43_3 in pairs(var_43_0) do
			if iter_43_2 == AttributeType.Durability or iter_43_2 == AttributeType.Cannon or iter_43_2 == AttributeType.Torpedo or iter_43_2 == AttributeType.AntiAircraft or iter_43_2 == AttributeType.Air or iter_43_2 == AttributeType.Reload or iter_43_2 == AttributeType.Hit or iter_43_2 == AttributeType.AntiSub or iter_43_2 == AttributeType.Dodge then
				var_43_0[iter_43_2] = var_43_0[iter_43_2] * (var_43_2 + 1)
			end
		end
	end

	return var_43_0
end

function ShipBluePrint.getTotalAdditions(self)
	local totalAdditions = {}
	-- specialAddition就是对effect_attr的累加
	local specialAddition = self:attrSpecialAddition()

	for _, property in ipairs(Ship.PROPERTIES) do
		local bluePrintAddition, var_44_3 = self:getBluePrintAddition(property)

		totalAdditions[property] = bluePrintAddition + (specialAddition[property] or 0)
	end

	return totalAdditions
end

function ShipBluePrint.attrSpecialAddition(self)
	local specialAddition = {}

	for level = 1, self.level do
		-- 来自ship_strengthen_blueprint
		local strengthenTmp = self.strengthenConfig[level]

		if strengthenTmp.special == 1 and type(strengthenTmp.special_effect) == "table" then
			for _, specialEffectItem in ipairs(strengthenTmp.special_effect) do
				if specialEffectItem[1] == ShipBluePrint.STRENGTHEN_TYPE_ATTR then
					local effectAttrTable = specialEffectItem[2]
					-- 累加effect_attr
					specialAddition[effectAttrTable[1]] = (specialAddition[effectAttrTable[1]] or 0) + effectAttrTable[2]
				end
			end
		end
	end

	for j = 1, self.fateLevel do
		local fateStrengthenTmp = self.fateStrengthenConfig[j]

		if fateStrengthenTmp.special == 1 and type(fateStrengthenTmp.special_effect) == "table" then
			for iter_45_4, iter_45_5 in ipairs(fateStrengthenTmp.special_effect) do
				if iter_45_5[1] == ShipBluePrint.STRENGTHEN_TYPE_ATTR then
					local effectAttrTable = iter_45_5[2]
					-- 累加effect_attr
					specialAddition[effectAttrTable[1]] = (specialAddition[effectAttrTable[1]] or 0) + effectAttrTable[2]
				end
			end
		end
	end

	return specialAddition
end

function ShipBluePrint.getUseageMaxItem(arg_46_0)
	local var_46_0 = 0

	for iter_46_0 = arg_46_0.level + 1, arg_46_0:getMaxLevel() do
		assert(arg_46_0.strengthenConfig[iter_46_0], "strengthen config >> " .. iter_46_0)

		var_46_0 = var_46_0 + arg_46_0.strengthenConfig[iter_46_0].need_exp
	end

	return math.max(math.ceil((var_46_0 - arg_46_0.exp) / arg_46_0:getItemExp()), 0)
end

function ShipBluePrint.getFateUseageMaxItem(arg_47_0)
	local var_47_0 = 0

	for iter_47_0 = arg_47_0.fateLevel + 1, arg_47_0:getMaxFateLevel() do
		assert(arg_47_0.fateStrengthenConfig[iter_47_0], "strengthen config >> " .. iter_47_0)

		var_47_0 = var_47_0 + arg_47_0.fateStrengthenConfig[iter_47_0].need_exp
	end

	return math.max(math.ceil((var_47_0 - arg_47_0.exp) / arg_47_0:getItemExp()), 0)
end

function ShipBluePrint.getOpenTaskList(arg_48_0)
	return arg_48_0:getConfig("unlock_task_open_condition")
end

function ShipBluePrint.getStrengthenConfig(arg_49_0, arg_49_1)
	return arg_49_0.strengthenConfig[arg_49_1]
end

function ShipBluePrint.getFateStrengthenConfig(arg_50_0, arg_50_1)
	return arg_50_0.fateStrengthenConfig[arg_50_1]
end

function ShipBluePrint.getUnlockVoices(arg_51_0)
	local var_51_0 = {}

	for iter_51_0 = 1, arg_51_0.level do
		local var_51_1 = arg_51_0:getStrengthenConfig(iter_51_0)

		if var_51_1.special == 1 then
			local var_51_2 = var_51_1.special_effect

			if type(var_51_2) == "table" then
				for iter_51_1, iter_51_2 in ipairs(var_51_2) do
					if iter_51_2[1] == ShipBluePrint.STRENGTHEN_TYPE_DIALOGUE then
						for iter_51_3, iter_51_4 in ipairs(iter_51_2[2]) do
							table.insert(var_51_0, iter_51_4)
						end
					end
				end
			end
		end
	end

	return var_51_0
end

function ShipBluePrint.getUnlockLevel(arg_52_0, arg_52_1)
	local var_52_0 = arg_52_0:getMaxLevel()

	for iter_52_0 = 1, var_52_0 do
		local var_52_1 = arg_52_0:getStrengthenConfig(iter_52_0).special_effect

		if type(var_52_1) == "table" then
			for iter_52_1, iter_52_2 in ipairs(var_52_1) do
				if iter_52_2[1] == ShipBluePrint.STRENGTHEN_TYPE_DIALOGUE then
					for iter_52_3, iter_52_4 in ipairs(iter_52_2[2]) do
						if arg_52_1 == iter_52_4 then
							return iter_52_0
						end
					end
				end
			end
		end
	end

	return 0
end

function ShipBluePrint.getBaseList(self, ship)
	assert(ship, "shipVO can not be nil" .. self.shipId)

	for iter_53_0 = self.level, 1, -1 do
		local var_53_0 = self:getStrengthenConfig(iter_53_0)

		if var_53_0.special == 1 then
			local var_53_1 = var_53_0.special_effect

			for iter_53_1, iter_53_2 in ipairs(var_53_1) do
				if iter_53_2[1] == ShipBluePrint.STRENGTHEN_TYPE_BASE_LIST then
					return iter_53_2[2]
				end
			end
		end
	end

	return ship:getConfig("base_list")
end

function ShipBluePrint.getPreLoadCount(arg_54_0, arg_54_1)
	assert(arg_54_1, "shipVO can not be nil" .. arg_54_0.shipId)

	for iter_54_0 = arg_54_0.level, 1, -1 do
		local var_54_0 = arg_54_0:getStrengthenConfig(iter_54_0)

		if var_54_0.special == 1 then
			local var_54_1 = var_54_0.special_effect

			for iter_54_1, iter_54_2 in ipairs(var_54_1) do
				if iter_54_2[1] == ShipBluePrint.STRENGTHEN_TYPE_PRLOAD_COUNT then
					return iter_54_2[2]
				end
			end
		end
	end

	return arg_54_1:getConfig("preload_count")
end

function ShipBluePrint.getEquipProficiencyList(arg_55_0, arg_55_1)
	assert(arg_55_1, "shipVO can not be nil" .. arg_55_0.shipId)

	local var_55_0 = {}

	for iter_55_0 = 1, arg_55_0.level do
		local var_55_1 = arg_55_0:getStrengthenConfig(iter_55_0)

		if var_55_1.special == 1 then
			local var_55_2 = var_55_1.special_effect

			for iter_55_1, iter_55_2 in ipairs(var_55_2) do
				if iter_55_2[1] == ShipBluePrint.STRENGTHEN_TYPE_EQUIPMENTPROFICIENCY then
					local var_55_3 = iter_55_2[2][1]
					local var_55_4 = iter_55_2[2][2]

					var_55_0[var_55_3] = (var_55_0[var_55_3] or 0) + var_55_4
				end
			end
		end
	end

	local var_55_5 = Clone(arg_55_1:getConfig("equipment_proficiency"))

	for iter_55_3, iter_55_4 in pairs(var_55_0) do
		var_55_5[iter_55_3] = var_55_5[iter_55_3] + iter_55_4
	end

	return var_55_5
end

function ShipBluePrint.isFinishPrevTask(arg_56_0)
	local var_56_0 = true
	local var_56_1 = true

	for iter_56_0, iter_56_1 in ipairs(arg_56_0:getOpenTaskList()) do
		local var_56_2 = getProxy(TaskProxy):getTaskVO(iter_56_1)

		if not var_56_2 or not var_56_2:isFinish() then
			return false, false
		else
			var_56_1 = (var_56_2:isReceive() or false) and var_56_1
		end
	end

	return var_56_0, var_56_1
end

function ShipBluePrint.isShipModMaxLevel(arg_57_0, arg_57_1)
	assert(arg_57_1, "shipVO can not be nil" .. arg_57_0.shipId)

	local var_57_0 = arg_57_0:getStrengthenConfig(math.min(arg_57_0.level + 1, arg_57_0:getMaxLevel()))

	if not arg_57_0:isMaxLevel() and arg_57_1.level < var_57_0.need_lv then
		return true, var_57_0.need_lv
	else
		return false
	end
end

function ShipBluePrint.isShipModMaxFateLevel(arg_58_0, arg_58_1)
	assert(arg_58_1, "shipVO can not be nil" .. arg_58_0.shipId)

	local var_58_0 = arg_58_0:getFateStrengthenConfig(math.min(arg_58_0.fateLevel + 1, arg_58_0:getMaxFateLevel()))

	if not arg_58_0:isMaxFateLevel() and arg_58_1.level < var_58_0.need_lv then
		return true, var_58_0.need_lv
	else
		return false
	end
end

function ShipBluePrint.isShipModMaxIntensifyLevel(arg_59_0, arg_59_1)
	if arg_59_0:canFateSimulation() then
		return arg_59_0:isShipModMaxFateLevel(arg_59_1)
	else
		return arg_59_0:isShipModMaxLevel(arg_59_1)
	end
end

function ShipBluePrint.getChangeSkillList(arg_60_0)
	return arg_60_0:getConfig("change_skill")
end

function ShipBluePrint.isRarityUR(arg_61_0)
	return arg_61_0:getShipVO():getRarity() >= ShipRarity.SSR
end

function ShipBluePrint.getFateMaxLeftOver(arg_62_0)
	local var_62_0 = arg_62_0:isRarityUR() and pg.gameset.fate_sim_ur.key_value or pg.gameset.fate_sim_ssr.key_value
	local var_62_1 = var_62_0 - arg_62_0:getFateUseNum()

	return var_62_1 < 0 and var_62_0 or var_62_1
end

function ShipBluePrint.getFateUseNum(arg_63_0)
	local var_63_0 = 0

	if arg_63_0:isMaxLevel() then
		local var_63_1 = 0

		for iter_63_0, iter_63_1 in ipairs(arg_63_0.fateStrengthenConfig) do
			if iter_63_1.lv <= 30 + arg_63_0.fateLevel then
				var_63_1 = var_63_1 + iter_63_1.need_exp
			end
		end

		local var_63_2 = var_63_1 + arg_63_0.exp
		local var_63_3 = arg_63_0:getItemExp()

		var_63_0 = math.floor(var_63_2 / var_63_3)
	end

	return var_63_0
end

function ShipBluePrint.isPursuing(arg_64_0)
	return arg_64_0:getConfig("is_pursuing") == 1
end

function ShipBluePrint.getPursuingPrice(arg_65_0, arg_65_1)
	arg_65_1 = arg_65_1 or 100

	return arg_65_0:getConfig("price") * arg_65_1 / 100
end

function ShipBluePrint.getUnlockItem(arg_66_0)
	local var_66_0 = getProxy(BagProxy)

	for iter_66_0, iter_66_1 in ipairs(arg_66_0:getConfig("gain_item_id")) do
		if var_66_0:getItemCountById(iter_66_1) > 0 then
			return iter_66_1
		end
	end
end

function ShipBluePrint.isPursuingCostTip(arg_67_0)
	return arg_67_0:isPursuing() and arg_67_0:isUnlock() and not arg_67_0:isMaxIntensifyLevel() and not arg_67_0:isShipModMaxIntensifyLevel(getProxy(BayProxy):getShipById(arg_67_0.shipId)) and getProxy(TechnologyProxy):calcPursuingCost(arg_67_0, 1) == 0
end

function ShipBluePrint.setPhantomQuestProgress(arg_68_0, arg_68_1, arg_68_2)
	arg_68_0.phantomQuestProgress = arg_68_0.phantomQuestProgress or {}
	arg_68_0.phantomQuestProgress[arg_68_1] = arg_68_2
end

function ShipBluePrint.getPhantomQuestCostDrop(arg_69_0)
	if arg_69_0.config.type == 5 then
		return Drop.New({
			type = DROP_TYPE_RESOURCE,
			id = PlayerConst.ResDiamond,
			count = arg_69_0.config.target_num
		})
	else
		return nil
	end
end

function ShipBluePrint.getPhantomQuestProgress(arg_70_0, arg_70_1)
	assert(arg_70_0.shipId)

	return switch(arg_70_1, {
		function()
			return getProxy(BayProxy):getShipById(arg_70_0.shipId).level
		end,
		function()
			return arg_70_0.level + (arg_70_0.level < arg_70_0:getMaxLevel() and 0 or arg_70_0.fateLevel)
		end,
		function()
			return arg_70_0.phantomQuestProgress[3] or 0
		end,
		function()
			return getProxy(BayProxy):getShipById(arg_70_0.shipId).propose and 1 or 0
		end,
		function()
			return Drop.New({
				type = DROP_TYPE_RESOURCE,
				id = PlayerConst.ResDiamond
			}):getOwnedCount()
		end
	})
end

function ShipBluePrint.getPhantomQuestInfo(arg_76_0, arg_76_1)
	local var_76_0 = pg.technology_shadow_unlock[arg_76_1]

	return {
		config = var_76_0,
		progress = arg_76_0:getPhantomQuestProgress(var_76_0.type),
		unlocked = tobool(getProxy(BayProxy):getShipById(arg_76_0.shipId).phantomDic[arg_76_1])
	}
end

function ShipBluePrint.getAllPhantomQuestInfo(arg_77_0)
	return underscore.map(pg.technology_shadow_unlock.all, function(arg_78_0)
		return arg_77_0:getPhantomQuestInfo(arg_78_0)
	end)
end

function ShipBluePrint.isUnlockShipPhantom(arg_79_0)
	local var_79_0 = getGameset("technology_shadow_unlock_lv")[1]

	return arg_79_0:isFetched() and var_79_0 <= getProxy(BayProxy):getShipById(arg_79_0.shipId).level
end

function var_0_0.IsFate(arg_80_0)
	return #arg_80_0:getConfig("fate_strengthen") > 0
end

return ShipBluePrint
