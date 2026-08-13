local SpWeapon = class("SpWeapon", import(".BaseVO"))

SpWeapon.type = DROP_TYPE_SPWEAPON
SpWeapon.CONFIRM_OP_DISCARD = 0
SpWeapon.CONFIRM_OP_EXCHANGE = 1

function SpWeapon.Ctor(arg_1_0, arg_1_1)
	SpWeapon.super.Ctor(arg_1_0, arg_1_1)

	arg_1_0.configId = arg_1_1.id
end

function SpWeapon.CreateByNet(arg_2_0)
	if arg_2_0.template_id == 0 then
		return
	end

	local var_2_0 = {
		uid = arg_2_0.id,
		id = arg_2_0.template_id,
		attr1 = arg_2_0.attr_1,
		attr2 = arg_2_0.attr_2,
		attrTemp1 = arg_2_0.attr_temp_1,
		attrTemp2 = arg_2_0.attr_temp_2,
		pt = arg_2_0.pt
	}

	return SpWeapon.New(var_2_0)
end

function SpWeapon.bindConfigTable(arg_3_0)
	return pg.spweapon_data_statistics
end

function SpWeapon.GetUID(arg_4_0)
	return arg_4_0.uid
end

function SpWeapon.IsReal(arg_5_0)
	return tobool(arg_5_0:GetUID())
end

function SpWeapon.GetConfigID(arg_6_0)
	return arg_6_0.configId
end

function SpWeapon.GetOriginID(arg_7_0)
	return arg_7_0:getConfig("base") or arg_7_0:GetConfigID()
end

function SpWeapon.IsImportant(arg_8_0)
	return arg_8_0:getConfig("important") == 2
end

function SpWeapon.IsUnique(arg_9_0)
	return arg_9_0:getConfig("unique") ~= 0
end

function SpWeapon.GetUniqueGroup(arg_10_0)
	return arg_10_0:getConfig("unique")
end

function SpWeapon.GetType(arg_11_0)
	return arg_11_0:getConfig("type")
end

function SpWeapon.GetName(arg_12_0)
	return arg_12_0:getConfig("name")
end

function SpWeapon.GetLevel(arg_13_0)
	return arg_13_0:getConfig("level")
end

function SpWeapon.GetTechTier(arg_14_0)
	return arg_14_0:getConfig("tech")
end

function SpWeapon.GetIconPath(arg_15_0)
	return "SpWeapon/" .. arg_15_0:getConfig("icon")
end

function SpWeapon.GetRarity(arg_16_0)
	return arg_16_0:getConfig("rarity")
end

function SpWeapon.GetPt(arg_17_0)
	return arg_17_0:IsReal() and arg_17_0.pt or 0
end

function SpWeapon.SetPt(arg_18_0, arg_18_1)
	assert(arg_18_1)

	arg_18_0.pt = arg_18_1 or 0
end

function SpWeapon.GetEffect(arg_19_0)
	return arg_19_0:getConfig("effect_id")
end

function SpWeapon.GetDisplayEffect(arg_20_0)
	return arg_20_0:getConfig("effect_id_display")
end

function SpWeapon.GetUpgradableSkillIds(arg_21_0)
	return arg_21_0:getConfig("skill_upgrade")
end

function SpWeapon.GetUpgradableHiddenSkillIds(arg_22_0)
	return arg_22_0:getConfig("hide_buff_upgrade")
end

function SpWeapon.GetNextUpgradeID(arg_23_0)
	return arg_23_0:getConfig("next")
end

function SpWeapon.GetPrevUpgradeID(arg_24_0)
	return arg_24_0:getConfig("prev")
end

function SpWeapon.MigrateTo(arg_25_0, arg_25_1)
	local var_25_0 = Clone(arg_25_0)

	var_25_0.id = arg_25_1
	var_25_0.configId = arg_25_1
	var_25_0.pt = 0

	return var_25_0
end

function SpWeapon.GetLabel(arg_26_0)
	return arg_26_0:getConfig("label")
end

function SpWeapon.SetShipId(arg_27_0, arg_27_1)
	arg_27_0.shipId = arg_27_1
end

function SpWeapon.GetShipId(arg_28_0)
	return arg_28_0.shipId
end

function SpWeapon.GetSkill(arg_29_0)
	local var_29_0 = arg_29_0:GetEffect()

	return var_29_0 > 0 and getSkillConfig(var_29_0) or nil
end

function SpWeapon.GetSkillInfo(arg_30_0)
	local var_30_0 = {
		lv = 1,
		skillId = arg_30_0:GetDisplayEffect()
	}

	var_30_0.unlock = var_30_0.skillId == arg_30_0:GetEffect()

	local var_30_1 = arg_30_0:GetShipId()

	if not var_30_1 or var_30_1 == 0 then
		var_30_0.descTrigger = true
	end

	return var_30_0
end

function SpWeapon.GetUpgradableSkillInfo(arg_31_0)
	local var_31_0 = arg_31_0:GetShipId()
	local var_31_1 = {}
	local var_31_2
	local var_31_3

	if var_31_0 then
		var_31_2 = getProxy(BayProxy):getShipById(var_31_0)
		var_31_3 = arg_31_0:GetActiveUpgradableSkillList(var_31_2)
	end

	for iter_31_0, iter_31_1 in ipairs(arg_31_0:GetUpgradableSkillIds()) do
		local var_31_4 = iter_31_1[2]
		local var_31_5 = 1
		local var_31_6 = false

		if var_31_2 then
			for iter_31_2, iter_31_3 in ipairs(var_31_3) do
				if iter_31_3.mapSkillID == iter_31_1[2] and iter_31_3.originalSkillID == iter_31_1[1] then
					local var_31_7 = var_31_2.skills[iter_31_3.originalSkillID]

					var_31_5 = var_31_7 and var_31_7.level or 1
					var_31_6 = true

					break
				end
			end
		else
			var_31_6 = var_31_6 or iter_31_1[1] ~= 0
		end

		table.insert(var_31_1, {
			skillId = var_31_4,
			lv = var_31_5,
			unlock = var_31_6,
			descTrigger = not var_31_2 or nil
		})
	end

	return var_31_1
end

function SpWeapon.GetActiveUpgradableSkillList(arg_32_0, arg_32_1)
	local var_32_0 = {}

	for iter_32_0, iter_32_1 in ipairs(arg_32_1:getSkillList()) do
		local var_32_1, var_32_2 = arg_32_0:RemapSkillId(iter_32_1)

		if var_32_2 then
			table.insert(var_32_0, {
				mapSkillID = var_32_1,
				originalSkillID = iter_32_1
			})
		end
	end

	local var_32_3 = pg.ship_data_template[arg_32_1.configId].hide_buff_list

	for iter_32_2, iter_32_3 in ipairs(var_32_3) do
		local var_32_4, var_32_5 = arg_32_0:RemapSkillId(iter_32_3)

		if var_32_5 then
			table.insert(var_32_0, {
				mapSkillID = var_32_4,
				originalSkillID = iter_32_3
			})
		end
	end

	return var_32_0
end

-- 这两个都是将舰船原有的技能映射到专武升级后的技能ID上
function SpWeapon.RemapSkillId(self, buffID)
	for _, upgradableBuffID in ipairs(self:GetUpgradableSkillIds()) do
		if upgradableBuffID[1] == buffID then
			return upgradableBuffID[2], true
		end
	end

	return buffID, false
end

function SpWeapon.RemapHiddenSkillId(self, buffID)
	for _, upgradableBuffID in ipairs(self:GetUpgradableHiddenSkillIds()) do
		if upgradableBuffID[1] == buffID then
			return upgradableBuffID[2], true
		end
	end

	return buffID, false
end

function SpWeapon.GetSkillGroup(arg_35_0)
	return {
		arg_35_0:GetSkillInfo(),
		(arg_35_0:GetUpgradableSkillInfo())
	}
end

function SpWeapon.GetConfigAttributes(arg_36_0)
	return {
		arg_36_0:getConfig("value_1"),
		arg_36_0:getConfig("value_2")
	}
end

function SpWeapon.GetAttributesRange(arg_37_0)
	return {
		arg_37_0:getConfig("value_1_random"),
		arg_37_0:getConfig("value_2_random")
	}
end

function SpWeapon.GetAttributes(arg_38_0)
	local var_38_0 = arg_38_0:GetConfigAttributes()

	if arg_38_0:IsReal() then
		var_38_0[1] = var_38_0[1] + arg_38_0.attr1
		var_38_0[2] = var_38_0[2] + arg_38_0.attr2
	end

	return var_38_0
end

function SpWeapon.GetBaseAttributes(arg_39_0)
	return {
		arg_39_0.attr1 or 0,
		arg_39_0.attr2 or 0
	}
end

function SpWeapon.SetBaseAttributes(arg_40_0, arg_40_1)
	arg_40_0.attr1 = arg_40_1[1]
	arg_40_0.attr2 = arg_40_1[2]
end

function SpWeapon.GetAttributeOptions(arg_41_0)
	return {
		arg_41_0.attrTemp1 or 0,
		arg_41_0.attrTemp2 or 0
	}
end

function SpWeapon.SetAttributeOptions(arg_42_0, arg_42_1)
	arg_42_0.attrTemp1 = arg_42_1[1]
	arg_42_0.attrTemp2 = arg_42_1[2]
end

function SpWeapon.GetPropertiesInfo(arg_43_0)
	local var_43_0 = {
		attrs = {}
	}
	local var_43_1 = arg_43_0:GetAttributes()

	table.insert(var_43_0.attrs, {
		type = arg_43_0:getConfig("attribute_1"),
		value = var_43_1[1]
	})
	table.insert(var_43_0.attrs, {
		type = arg_43_0:getConfig("attribute_2"),
		value = var_43_1[2]
	})

	var_43_0.weapon = {
		sub = {}
	}
	var_43_0.equipInfo = {
		sub = {}
	}

	local var_43_2 = arg_43_0:GetWearableShipTypes()

	var_43_0.part = {
		var_43_2,
		var_43_2
	}

	return var_43_0
end

function SpWeapon.GetWearableShipTypes(arg_44_0)
	local var_44_0 = arg_44_0:getConfig("usability")

	if var_44_0 and #var_44_0 > 0 then
		return var_44_0
	end

	return pg.spweapon_type[arg_44_0:GetType()].ship_type
end

function SpWeapon.IsCraftable(arg_45_0)
	return not arg_45_0:IsUnCraftable() and arg_45_0:GetUpgradeConfig().create_use_gold > 0
end

function SpWeapon.GetUpgradeConfig(arg_46_0)
	local var_46_0 = arg_46_0:getConfig("upgrade_id")

	return pg.spweapon_upgrade[var_46_0]
end

function SpWeapon.IsUnCraftable(arg_47_0)
	return arg_47_0:getConfig("uncraftable") == 1
end

function SpWeapon.CalculateHistoryPt(arg_48_0, arg_48_1)
	local var_48_0 = _.reduce(arg_48_0, 0, function(arg_49_0, arg_49_1)
		return arg_49_0 + Item.getConfigData(arg_49_1.id).usage_arg[1] * arg_49_1.count
	end)

	return (_.reduce(arg_48_1, var_48_0, function(arg_50_0, arg_50_1)
		return arg_50_0 + (0 + arg_50_1:GetUpgradeConfig().upgrade_supply_pt)
	end))
end

function SpWeapon.IsMatchKey(arg_51_0, arg_51_1)
	local var_51_0 = {
		arg_51_0:getConfig("name")
	}

	return EquipmentTools.IsMatchKey(var_51_0, arg_51_1)
end

return SpWeapon
