local Commander = class("Commander", import("..BaseVO"))
local commander_level = pg.commander_level
local commander_attribute_template = pg.commander_attribute_template
local var_0_3 = 0
local var_0_4 = 1

function Commander.rarity2Print(arg_1_0)
	if not Commander.prints then
		Commander.prints = {
			"n",
			"n",
			"r",
			"sr",
			"ssr"
		}
	end

	return Commander.prints[arg_1_0]
end

function Commander.rarity2Frame(arg_2_0)
	if not Commander.frames then
		Commander.frames = {
			"2",
			"2",
			"2",
			"3",
			"4"
		}
	end

	return Commander.frames[arg_2_0]
end

function Commander.Ctor(arg_3_0, arg_3_1)
	arg_3_0.id = arg_3_1.id
	arg_3_0.configId = arg_3_1.template_id or arg_3_0.id
	arg_3_0.level = arg_3_1.level
	arg_3_0.exp = arg_3_1.exp
	arg_3_0.isLock = arg_3_1.is_locked
	arg_3_0.pt = arg_3_1.used_pt

	if arg_3_1.name and arg_3_1.name ~= "" then
		arg_3_0.name = arg_3_1.name
	end

	local var_3_0 = pg.gameset.commander_rename_coldtime.key_value

	arg_3_0.renameTime = (arg_3_1.rename_time or 0) + var_3_0
	arg_3_0.talentOrigins = {}

	for iter_3_0, iter_3_1 in ipairs(arg_3_1.ability_origin) do
		local var_3_1 = CommanderTalent.New({
			id = iter_3_1
		})

		var_3_1:setOrigin(var_3_1)
		table.insert(arg_3_0.talentOrigins, var_3_1)
	end

	arg_3_0.talents = {}

	for iter_3_2, iter_3_3 in ipairs(arg_3_1.ability) do
		local var_3_2 = CommanderTalent.New({
			id = iter_3_3
		})

		arg_3_0:addTalent(var_3_2)
	end

	arg_3_0.notLearnedList = {}
	arg_3_0.abilityTime = arg_3_1.ability_time
	arg_3_0.skills = {}

	for iter_3_4, iter_3_5 in ipairs(arg_3_1.skill) do
		local var_3_3 = CommanderSkill.New({
			id = iter_3_5.id,
			exp = iter_3_5.exp
		})

		table.insert(arg_3_0.skills, var_3_3)
	end

	arg_3_0.abilitys = {}

	arg_3_0:updateAbilitys()

	arg_3_0.maxLevel = commander_level.all[#commander_level.all]
	arg_3_0.groupId = arg_3_0:getConfig("group_type")
	arg_3_0.cleanTime = arg_3_1.home_clean_time or 0
	arg_3_0.playTime = arg_3_1.home_play_time or 0
	arg_3_0.feedTime = arg_3_1.home_feed_time or 0
end

function Commander.IsRegularTalent(arg_4_0)
	return arg_4_0:getConfig("ability_refresh_type") == var_0_4
end

function Commander.getRenameTime(arg_5_0)
	return arg_5_0.renameTime
end

function Commander.setRenameTime(arg_6_0, arg_6_1)
	arg_6_0.renameTime = arg_6_1
end

function Commander.canModifyName(arg_7_0)
	return pg.TimeMgr.GetInstance():GetServerTime() >= arg_7_0.renameTime
end

function Commander.getRenameTimeDesc(arg_8_0)
	local var_8_0 = pg.TimeMgr.GetInstance():GetServerTime()
	local var_8_1 = arg_8_0.renameTime
	local var_8_2, var_8_3, var_8_4, var_8_5 = pg.TimeMgr.GetInstance():parseTimeFrom(var_8_1 - var_8_0)

	if var_8_2 < 1 then
		if var_8_3 < 1 then
			return var_8_4 .. i18n("word_minute")
		else
			return var_8_3 .. i18n("word_hour")
		end
	else
		return var_8_2 .. i18n("word_date")
	end
end

function Commander.setLock(arg_9_0, arg_9_1)
	assert(type(arg_9_1) == "number")

	arg_9_0.isLock = arg_9_1
end

function Commander.getLock(arg_10_0)
	return arg_10_0.isLock
end

function Commander.isLocked(arg_11_0)
	return arg_11_0.isLock == 1
end

function Commander.bindConfigTable(arg_12_0)
	return pg.commander_data_template
end

function Commander.getSkill(arg_13_0, arg_13_1)
	return _.detect(arg_13_0.skills, function(arg_14_0)
		return arg_14_0.id == arg_13_1
	end)
end

function Commander.getSkills(arg_15_0)
	return arg_15_0.skills
end

local function var_0_5(arg_16_0, arg_16_1)
	table.sort(arg_16_1, function(arg_17_0, arg_17_1)
		return arg_17_0.configId < arg_17_1.configId
	end)

	for iter_16_0, iter_16_1 in ipairs(arg_16_1) do
		if arg_16_0:IsLearnedTalent(iter_16_1.id) then
			return iter_16_1
		end
	end

	return arg_16_1[1]
end

function Commander.GetDisplayTalents(arg_18_0)
	if arg_18_0:IsRegularTalent() then
		local var_18_0 = {}

		for iter_18_0, iter_18_1 in ipairs(arg_18_0:getConfig("ability_show")) do
			local var_18_1 = CommanderTalent.New({
				id = iter_18_1
			})

			if not var_18_0[var_18_1.groupId] then
				var_18_0[var_18_1.groupId] = {}
			end

			table.insert(var_18_0[var_18_1.groupId], var_18_1)
		end

		local var_18_2 = {}
		local var_18_3 = {}

		for iter_18_2, iter_18_3 in pairs(var_18_0) do
			local var_18_4 = var_0_5(arg_18_0, iter_18_3)

			table.insert(var_18_2, var_18_4)

			var_18_3[var_18_4.id] = arg_18_0:IsLearnedTalent(var_18_4.id)
		end

		table.sort(var_18_2, function(arg_19_0, arg_19_1)
			return (var_18_3[arg_19_0.id] and 1 or 0) > (var_18_3[arg_19_1.id] and 1 or 0)
		end)

		do return var_18_2 end
		return
	end

	return arg_18_0:getTalents()
end

function Commander.IsLearnedTalent(arg_20_0, arg_20_1)
	for iter_20_0, iter_20_1 in ipairs(arg_20_0.talents) do
		if iter_20_1.id == arg_20_1 then
			return true
		end
	end

	return false
end

function Commander.getTalents(arg_21_0)
	return arg_21_0.talents
end

function Commander.getTalentOrigins(arg_22_0)
	return arg_22_0.talentOrigins
end

function Commander.addTalent(arg_23_0, arg_23_1)
	local var_23_0 = _.detect(arg_23_0.talentOrigins, function(arg_24_0)
		return arg_24_0.groupId == arg_23_1.groupId
	end)

	arg_23_1:setOrigin(var_23_0)
	table.insert(arg_23_0.talents, arg_23_1)
end

function Commander.deleteTablent(arg_25_0, arg_25_1)
	for iter_25_0, iter_25_1 in ipairs(arg_25_0.talents) do
		if iter_25_1.id == arg_25_1 then
			table.remove(arg_25_0.talents, iter_25_0)

			break
		end
	end
end

function Commander.getTalent(arg_26_0, arg_26_1)
	for iter_26_0, iter_26_1 in pairs(arg_26_0.talents) do
		if iter_26_1 == arg_26_1 then
			return iter_26_1
		end
	end
end

function Commander.resetTalents(arg_27_0)
	arg_27_0.talents = Clone(arg_27_0.talentOrigins)
end

function Commander.getNotLearnedList(arg_28_0)
	return arg_28_0.notLearnedList
end

function Commander.updateNotLearnedList(arg_29_0, arg_29_1)
	arg_29_0.notLearnedList = arg_29_1
end

function Commander.getResetTalentConsume(arg_30_0)
	return pg.gameset.commander_skill_reset_cost.description[1][arg_30_0.pt]
end

function Commander.getTotalPoint(arg_31_0)
	return math.floor(arg_31_0.level / CommanderConst.TALENT_POINT_LEVEL) * CommanderConst.TALENT_POINT
end

function Commander.getTalentPoint(arg_32_0)
	return arg_32_0:getTotalPoint() - arg_32_0.pt
end

function Commander.updatePt(arg_33_0, arg_33_1)
	arg_33_0.pt = arg_33_1
end

function Commander.getPt(arg_34_0)
	return arg_34_0.pt
end

function Commander.fullTalentCnt(arg_35_0)
	return #arg_35_0.talents >= CommanderConst.MAX_TELENT_COUNT
end

function Commander.hasTalent(arg_36_0, arg_36_1)
	return arg_36_0:getSameGroupTalent(arg_36_1.groupId) ~= nil
end

function Commander.getSameGroupTalent(arg_37_0, arg_37_1)
	for iter_37_0, iter_37_1 in ipairs(arg_37_0.talents) do
		if iter_37_1.groupId == arg_37_1 then
			return iter_37_1
		end
	end
end

function Commander.getTalentsDesc(arg_38_0)
	local var_38_0 = {}
	local var_38_1 = arg_38_0:getTalents()

	for iter_38_0, iter_38_1 in ipairs(var_38_1) do
		for iter_38_2, iter_38_3 in pairs(iter_38_1:getDesc()) do
			if var_38_0[iter_38_2] then
				var_38_0[iter_38_2].value = var_38_0[iter_38_2].value + iter_38_3.value
			else
				var_38_0[iter_38_2] = {
					name = iter_38_2,
					value = iter_38_3.value,
					type = iter_38_3.type
				}
			end
		end
	end

	return var_38_0
end

function Commander.getAbilitys(self)
	return self.abilitys
end

-- note: 指挥喵能力值成长公式
-- Commander.Ctor/Commander.updateLevel中会调用
function Commander.updateAbilitys(self)
	-- commander_grow_form_a = 24
	local commander_grow_form_a = pg.gameset.commander_grow_form_a.key_value
	-- commander_grow_form_b = 304
	local commander_grow_form_b = pg.gameset.commander_grow_form_b.key_value

	local function getAbilityValue(abilityName)
		-- baseValue对应的是commander_data_template表中的xxx_value字段
		local baseValue = self:getConfig(abilityName .. "_value")
		-- 计算公式: floor(baseValue + baseValue * (level - 1) * 24 / 304)
		return math.floor(baseValue + baseValue * (self.level - 1) * commander_grow_form_a / commander_grow_form_b)
	end

	local abilities = {
		"command",
		"tactic",
		"support"
	}
	local abilityIds = {
		101,
		102,
		103
	}

	for abilityIndex, abilityName in ipairs(abilities) do
		local abilityValue = getAbilityValue(abilityName)

		self.abilitys[abilityName] = {
			value = abilityValue,
			id = abilityIds[abilityIndex]
		}
	end
end

-- 指挥喵能力加成
function Commander.getAbilitysAddition(self)
	-- commander_form_a = 6
	local commander_form_a = pg.gameset.commander_form_a.key_value
	-- commander_form_b = 1500
	local commander_form_b = pg.gameset.commander_form_b.key_value
	-- commander_form_c = 250
	local commander_form_c = pg.gameset.commander_form_c.key_value
	-- commander_form_n = 1
	local commander_form_n = pg.gameset.commander_form_n.key_value

	local function getAdditionForProperty(property)
		local totalRatioForProperty = 0

		for _, ability in pairs(self.abilitys) do
			local abilityTempData = commander_attribute_template[ability.id]

			if abilityTempData["rate_" .. property] then
				local abilityRatioForProperty = abilityTempData["rate_" .. property] / 10000

				if abilityRatioForProperty > 0 then
					totalRatioForProperty = totalRatioForProperty + ability.value * abilityRatioForProperty
				end
			end
		end

		-- 公式: (6 - 1500 / (totalRatioForProperty + 250)) * 1, 四舍五入保留三位小数
		-- 等价公式: 6 * totalRatioForProperty / (totalRatioForProperty + 250)
		return tonumber(string.format("%0.3f", (commander_form_a - commander_form_b / (totalRatioForProperty + commander_form_c)) * commander_form_n))
	end

	local abilityRatioAdditions = {}

	for _, property in ipairs(CommanderConst.PROPERTIES) do
		abilityRatioAdditions[property] = getAdditionForProperty(property)
	end

	return abilityRatioAdditions
end

-- 指挥喵天赋加成
function Commander.getTalentsAddition(self, talentAdditionType, property, nationality, shipType)
	local totalAdditionsForProperty = 0
	local talents = self:getTalents()

	for _, talent in pairs(talents) do
		local numberAdditions, ratioAdditions = talent:getAttrsAddition()
		local additions

		if talentAdditionType == CommanderConst.TALENT_ADDITION_NUMBER then
			additions = numberAdditions
		elseif talentAdditionType == CommanderConst.TALENT_ADDITION_RATIO then
			additions = ratioAdditions
		end

		local additionForProperty = additions[property]
		local satisfied = true

		if additionForProperty then
			if #additionForProperty.nation > 0 and not table.contains(additionForProperty.nation, nationality) then
				satisfied = false
			end

			if #additionForProperty.shiptype > 0 and not table.contains(additionForProperty.shiptype, shipType) then
				satisfied = false
			end
		else
			satisfied = false
		end

		if satisfied then
			totalAdditionsForProperty = totalAdditionsForProperty + additionForProperty.value
		end
	end

	return totalAdditionsForProperty
end

-- 被Ship.getProperties调用
-- 能力加成
function Commander.getAttrRatioAddition(self, property, nationality, shipType)
	if table.contains(CommanderConst.PROPERTIES, property) then
		return self:getAbilitysAddition()[property] + self:getTalentsAddition(CommanderConst.TALENT_ADDITION_RATIO, property, nationality, shipType) / 100
	else
		return 0
	end
end

-- 被Ship.getProperties调用
-- 天赋加成
function Commander.getAttrValueAddition(self, property, nationality, shipType)
	if table.contains(CommanderConst.PROPERTIES, property) then
		return (self:getTalentsAddition(CommanderConst.TALENT_ADDITION_NUMBER, property, nationality, shipType))
	else
		return 0
	end
end

function Commander.addExp(arg_47_0, arg_47_1)
	if arg_47_0:isMaxLevel() then
		return
	end

	arg_47_0.exp = arg_47_0.exp + arg_47_1

	while not arg_47_0:isMaxLevel() and arg_47_0:canLevelUp() do
		arg_47_0.exp = arg_47_0.exp - arg_47_0:getNextLevelExp()

		arg_47_0:updateLevel()
	end
end

function Commander.ReduceExp(arg_48_0, arg_48_1)
	arg_48_0.exp = arg_48_0.exp - arg_48_1

	while arg_48_0.exp < 0 do
		arg_48_0.level = arg_48_0.level - 1
		arg_48_0.exp = arg_48_0:getNextLevelExp() + arg_48_0.exp
	end
end

function Commander.canLevelUp(arg_49_0)
	return arg_49_0.exp >= arg_49_0:getNextLevelExp()
end

function Commander.isMaxLevel(arg_50_0)
	return arg_50_0:getMaxLevel() <= arg_50_0.level
end

function Commander.getMaxLevel(arg_51_0)
	return arg_51_0.maxLevel
end

function Commander.updateLevel(self)
	self.level = self.level + 1

	self:updateAbilitys()

	if self.level % CommanderConst.TALENT_POINT_LEVEL == 0 then
		self.notLearnedList = {}
	end
end

function Commander.getConfigExp(arg_53_0, arg_53_1)
	arg_53_1 = math.max(arg_53_1, 1)

	local var_53_0 = commander_level[arg_53_1]

	return var_53_0["exp_" .. arg_53_0:getRarity()] or var_53_0.exp
end

function Commander.getNextLevelExp(arg_54_0)
	return arg_54_0:getConfigExp(arg_54_0.level)
end

function Commander.UpdateLevelAndExp(arg_55_0, arg_55_1, arg_55_2)
	arg_55_0.exp = arg_55_2
	arg_55_0.level = arg_55_1
end

function Commander.getName(arg_56_0, arg_56_1)
	if arg_56_1 then
		return arg_56_0:getConfig("name")
	else
		return arg_56_0.name or arg_56_0:getConfig("name")
	end
end

function Commander.setName(arg_57_0, arg_57_1)
	arg_57_0.name = arg_57_1
end

function Commander.getRarity(arg_58_0)
	return arg_58_0:getConfig("rarity")
end

function Commander.isSSR(arg_59_0)
	return arg_59_0:getRarity() == 5
end

function Commander.isSR(arg_60_0)
	return arg_60_0:getRarity() == 4
end

function Commander.isR(arg_61_0)
	return arg_61_0:getRarity() == 3
end

function Commander.getPainting(arg_62_0)
	return arg_62_0:getConfig("painting")
end

function Commander.getLevel(arg_63_0)
	return arg_63_0.level
end

function Commander.getDestoryedExp(arg_64_0, arg_64_1)
	local var_64_0 = 0

	for iter_64_0 = 1, arg_64_0.level - 1 do
		var_64_0 = var_64_0 + arg_64_0:getConfigExp(iter_64_0)
	end

	local var_64_1 = var_64_0 + arg_64_0.exp

	local function var_64_2()
		local var_65_0 = 0
		local var_65_1 = 0
		local var_65_2 = arg_64_0:getTalents()

		for iter_65_0, iter_65_1 in ipairs(var_65_2) do
			var_65_0 = var_65_0 + iter_65_1:getDestoryExpValue()
			var_65_1 = var_65_1 + iter_65_1:getDestoryExpRetio()
		end

		return var_65_0, var_65_1 / 10000
	end

	local var_64_3 = pg.gameset.commander_exp_a.key_value / 10000
	local var_64_4 = pg.gameset.commander_exp_same_rate.key_value / 10000
	local var_64_5 = arg_64_1 == arg_64_0.groupId and var_64_4 or 1
	local var_64_6, var_64_7 = var_64_2()

	return (arg_64_0:getConfig("exp") + var_64_1 * var_64_3) * var_64_5 * (1 + var_64_7) + var_64_6
end

function Commander.getDestoryedSkillExp(arg_66_0, arg_66_1)
	if arg_66_1 == arg_66_0.groupId then
		return pg.gameset.commander_skill_exp.key_value
	end

	return 0
end

function Commander.updateAbilityTime(arg_67_0, arg_67_1)
	arg_67_0.abilityTime = arg_67_1
end

function Commander.GetNextResetAbilityTime(arg_68_0)
	if pg.gameset.commander_ability_reset_time.key_value == 1 then
		return pg.TimeMgr.GetInstance():GetNextTimeByTimeStamp(arg_68_0.abilityTime) + 86400
	else
		return arg_68_0.abilityTime + pg.gameset.commander_ability_reset_coldtime.key_value
	end
end

function Commander.isLevelUp(arg_69_0, arg_69_1)
	return arg_69_0.level > 1 and arg_69_0.exp - arg_69_1 < 0
end

function Commander.isSameGroup(arg_70_0, arg_70_1)
	return arg_70_1 == arg_70_0.groupId
end

function Commander.getUpgradeConsume(arg_71_0)
	local var_71_0 = arg_71_0:getConfig("exp_cost")

	return var_71_0 + var_71_0 * (arg_71_0.level - 1) * (0.85 + 0.15 * arg_71_0.level)
end

function Commander.canEquipToEliteChapter(arg_72_0, arg_72_1, arg_72_2, arg_72_3)
	local var_72_0 = getProxy(ChapterProxy):getChapterById(arg_72_0):getEliteFleetCommanders() or {}

	return Commander.canEquipToFleetList(var_72_0, arg_72_1, arg_72_2, arg_72_3)
end

function Commander.canEquipToFleetList(arg_73_0, arg_73_1, arg_73_2, arg_73_3)
	local var_73_0 = getProxy(CommanderProxy)
	local var_73_1 = var_73_0:getCommanderById(arg_73_3)

	if not var_73_1 then
		return false, i18n("commander_not_found")
	end

	for iter_73_0, iter_73_1 in pairs(arg_73_0) do
		if iter_73_0 == arg_73_1 then
			for iter_73_2, iter_73_3 in pairs(iter_73_1) do
				local var_73_2 = var_73_0:getCommanderById(iter_73_3)

				if var_73_2 and var_73_2.groupId == var_73_1.groupId and iter_73_2 ~= arg_73_2 then
					return false, i18n("commander_can_not_select_same_group")
				end
			end
		else
			for iter_73_4, iter_73_5 in pairs(iter_73_1) do
				if arg_73_3 == iter_73_5 then
					return false, i18n("commander_is_in_fleet_already")
				end
			end
		end
	end

	return true
end

function Commander.ExistCleanFlag(arg_74_0)
	local var_74_0 = pg.TimeMgr.GetInstance():GetServerTime()

	return not pg.TimeMgr.GetInstance():IsSameDay(arg_74_0.cleanTime, var_74_0)
end

function Commander.ExitFeedFlag(arg_75_0)
	local var_75_0 = pg.TimeMgr.GetInstance():GetServerTime()

	return not pg.TimeMgr.GetInstance():IsSameDay(arg_75_0.feedTime, var_75_0)
end

function Commander.ExitPlayFlag(arg_76_0)
	local var_76_0 = pg.TimeMgr.GetInstance():GetServerTime()

	return not pg.TimeMgr.GetInstance():IsSameDay(arg_76_0.playTime, var_76_0)
end

function Commander.UpdateHomeOpTime(arg_77_0, arg_77_1, arg_77_2)
	if arg_77_1 == 1 then
		arg_77_0.cleanTime = arg_77_2
	elseif arg_77_1 == 2 then
		arg_77_0.feedTime = arg_77_2
	elseif arg_77_1 == 3 then
		arg_77_0.playTime = arg_77_2
	end
end

function Commander.IsSameTalent(arg_78_0)
	local var_78_0 = arg_78_0:getTalentOrigins()
	local var_78_1 = arg_78_0:getTalents()

	if #var_78_0 == #var_78_1 and _.all(var_78_0, function(arg_79_0)
		return _.any(var_78_1, function(arg_80_0)
			return arg_80_0.id == arg_79_0.id
		end)
	end) then
		return true
	end

	return false
end

function Commander.CanReset(arg_81_0)
	return arg_81_0:GetNextResetAbilityTime() <= pg.TimeMgr.GetInstance():GetServerTime()
end

function Commander.ShouldTipLock(arg_82_0)
	return arg_82_0:isSSR() and not arg_82_0:isLocked()
end

return Commander
