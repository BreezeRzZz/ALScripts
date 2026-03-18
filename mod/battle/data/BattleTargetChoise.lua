ys = ys or {}
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleFormulas = ys.Battle.BattleFormulas
local BattleTargetChoise = {}

ys.Battle.BattleTargetChoise = BattleTargetChoise

function BattleTargetChoise.TargetNil()
	return nil
end

function BattleTargetChoise.TargetNull()
	return {}
end

function BattleTargetChoise.TargetAll()
	return ys.Battle.BattleDataProxy.GetInstance():GetUnitList()
end

function BattleTargetChoise.TargetEntityUnit()
	local entityUnits = {}
	local allUnits = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()

	for _, unit in pairs(allUnits) do
		-- 幽灵类不算
		if not unit:IsSpectre() then
			entityUnits[#entityUnits + 1] = unit
		end
	end

	return entityUnits
end

function BattleTargetChoise.TargetSpectreUnit(caster, argList, candidateList)
	local targetList = {}
	local spectreList = ys.Battle.BattleDataProxy.GetInstance():GetSpectreShipList()

	for _, spectre in pairs(spectreList) do
		targetList[#targetList + 1] = spectre
	end

	return targetList
end

function BattleTargetChoise.TargetTemplate(caster, argList, candidateList)
	local targetTemplateIDList = argList.targetTemplateIDList or {
		argList.targetTemplateID
	}
	-- 无传参，则默认从所有实体单位中选取
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, candidate in pairs(_candidateList) do
		local candidateTempID = candidate:GetTemplateID()
		local candidateIFF = candidate:GetIFF()
		-- 需要参数中指定的模板ID，且在同边
		if table.contains(targetTemplateIDList, candidateTempID) and casterIFF == candidateIFF then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

function BattleTargetChoise.TargetNationality(caster, argList, candidateList)
	if not argList.targetTemplateIDList then
		({})[1] = argList.targetTemplateID
	end
	-- 无传参，则默认从所有单位中选取
	local _candidateList = candidateList or ys.Battle.BattleDataProxy.GetInstance():GetUnitList()
	local targetList = {}
	local nationality = argList.nationality
	local nationalityType = type(nationality)

	for _, candidate in pairs(_candidateList) do
		if nationalityType == "number" then
			if candidate:GetTemplate().nationality == nationality then
				targetList[#targetList + 1] = candidate
			end
		elseif nationalityType == "table" and table.contains(nationality, candidate:GetTemplate().nationality) then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

function BattleTargetChoise.TargetShipType(caster, argList, candidateList)
	-- 无传参，则默认从所有实体单位中选取
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local targetList = {}
	local shipTypeList = argList.ship_type_list

	for _, candidate in pairs(_candidateList) do
		local candidateType = candidate:GetTemplate().type

		if table.contains(shipTypeList, candidateType) then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

function BattleTargetChoise.TargetShipTag(caster, argList, candidateList)
	-- 无传参，则默认从所有实体单位中选取
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local targetList = {}
	local shipTagList = argList.ship_tag_list

	for _, candidate in pairs(_candidateList) do
		if candidate:ContainsLabelTag(shipTagList) then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

function BattleTargetChoise.TargetShipArmor(caster, argList, candidateList)
	-- 无传参，则默认从所有实体单位中选取
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local targetList = {}
	local armorType = argList.armor_type

	for _, candidate in ipairs(_candidateList) do
		if candidate:GetAttrByName("armorType") == armorType then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

function BattleTargetChoise.getShipListByIFF(IFF)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local candidateList
	-- 友方召唤物不属于friendlyShipList
	-- 潜艇也属于friendShipList
	-- 敌方召唤物属于foeShipList
	-- 我方幽灵单位不属于friendlyShipList(也只有支援舰队这类才会是幽灵单位)
	-- 敌方幽灵单位不属于foeShipList
	if IFF == BattleConfig.FRIENDLY_CODE then
		candidateList = battleDataProxy:GetFriendlyShipList()
	elseif IFF == BattleConfig.FOE_CODE then
		candidateList = battleDataProxy:GetFoeShipList()
	end

	return candidateList
end

function BattleTargetChoise.TargetAllHelp(caster, argList, candidateList)
	local targetList = {}

	if caster then
		argList = argList or {}

		local exceptCaster = argList.exceptCaster
		local casterUID = caster:GetUniqueID()
		local casterIFF = caster:GetIFF()
		local _candidateList = candidateList or BattleTargetChoise.getShipListByIFF(casterIFF)

		for _, candidate in pairs(_candidateList) do
			local candidateUID = candidate:GetUniqueID()
			-- 如果exceptCaster为true，则排除施法者自己
			if candidate:IsAlive() and candidate:GetIFF() == casterIFF and (not exceptCaster or candidateUID ~= casterUID) then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

function BattleTargetChoise.TargetHelpLeastHP(arg_13_0, arg_13_1, arg_13_2)
	arg_13_1 = arg_13_1 or {}

	local var_13_0
	local var_13_1 = arg_13_1.targetMaxHPRatio

	if arg_13_0 then
		local var_13_2 = arg_13_2 or BattleTargetChoise.getShipListByIFF(arg_13_0:GetIFF())
		local var_13_3 = 9999999999

		for iter_13_0, iter_13_1 in pairs(var_13_2) do
			if iter_13_1:IsAlive() and var_13_3 > iter_13_1:GetCurrentHP() and (not var_13_1 or var_13_1 >= iter_13_1:GetHPRate()) then
				var_13_0 = iter_13_1
				var_13_3 = iter_13_1:GetCurrentHP()
			end
		end
	end

	return {
		var_13_0
	}
end

function BattleTargetChoise.TargetHelpLeastHPRatio(caster, argList, candidateList)
	argList = argList or {}

	local target

	if caster then
		local leastHPRatio = 100
		local _candidateList = candidateList or BattleTargetChoise.getShipListByIFF(caster:GetIFF())

		for _, candidate in pairs(_candidateList) do
			-- GetHPRate返回的是当前耐久与最大耐久之比，因此最大值为1
			if candidate:IsAlive() and leastHPRatio > candidate:GetHPRate() then
				target = candidate
				leastHPRatio = candidate:GetHPRate()
			end
		end
	end

	return {
		target
	}
end

function BattleTargetChoise.TargetHighestHP(arg_15_0, arg_15_1, arg_15_2)
	arg_15_1 = arg_15_1 or {}

	local var_15_0

	if arg_15_0 then
		local var_15_1 = arg_15_2 or BattleTargetChoise.TargetEntityUnit()
		local var_15_2 = 1

		for iter_15_0, iter_15_1 in pairs(var_15_1) do
			if iter_15_1:IsAlive() and var_15_2 < iter_15_1:GetCurrentHP() then
				var_15_0 = iter_15_1
				var_15_2 = iter_15_1:GetCurrentHP()
			end
		end
	end

	return {
		var_15_0
	}
end

function BattleTargetChoise.TargetLowestHPRatio(arg_16_0, arg_16_1, arg_16_2)
	arg_16_1 = arg_16_1 or {}

	local var_16_0
	local var_16_1 = arg_16_2 or BattleTargetChoise.TargetEntityUnit()
	local var_16_2 = 1

	for iter_16_0, iter_16_1 in pairs(var_16_1) do
		local var_16_3 = iter_16_1:GetHPRate()

		if iter_16_1:IsAlive() and var_16_3 < var_16_2 and var_16_3 > 0 then
			var_16_0 = iter_16_1
			var_16_2 = var_16_3
		end
	end

	return {
		var_16_0
	}
end

function BattleTargetChoise.TargetLowestHP(arg_17_0, arg_17_1, arg_17_2)
	arg_17_1 = arg_17_1 or {}

	local var_17_0
	local var_17_1 = arg_17_2 or BattleTargetChoise.TargetEntityUnit()
	local var_17_2 = 9999999999

	for iter_17_0, iter_17_1 in pairs(var_17_1) do
		local var_17_3 = iter_17_1:GetCurrentHP()

		if iter_17_1:IsAlive() and var_17_3 < var_17_2 and var_17_3 > 0 then
			var_17_0 = iter_17_1
			var_17_2 = var_17_3
		end
	end

	return {
		var_17_0
	}
end

function BattleTargetChoise.TargetHighestHPRatio(arg_18_0, arg_18_1, arg_18_2)
	arg_18_1 = arg_18_1 or {}

	local var_18_0
	local var_18_1 = arg_18_2 or BattleTargetChoise.TargetEntityUnit()
	local var_18_2 = 0

	for iter_18_0, iter_18_1 in pairs(var_18_1) do
		if iter_18_1:IsAlive() and var_18_2 < iter_18_1:GetHPRate() then
			var_18_0 = iter_18_1
			var_18_2 = iter_18_1:GetHPRate()
		end
	end

	return {
		var_18_0
	}
end

function BattleTargetChoise.TargetAttrCompare(arg_19_0, arg_19_1, arg_19_2)
	local var_19_0 = {}
	local var_19_1 = arg_19_2 or BattleTargetChoise.TargetEntityUnit()

	for iter_19_0, iter_19_1 in pairs(var_19_1) do
		if iter_19_1:IsAlive() and BattleFormulas.parseCompareUnitAttr(arg_19_1.attrCompare, iter_19_1, arg_19_0) then
			table.insert(var_19_0, iter_19_1)
		end
	end

	return var_19_0
end

function BattleTargetChoise.TargetAttrCeil(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local ceilAttr = argList.ceilAttr
	local maxValue = 0
	local maxCand

	for _, candidate in ipairs(_candidateList) do
		local attrValue = candidate:GetAttrByName(ceilAttr)

		if maxValue <= attrValue then
			maxValue = attrValue
			maxCand = candidate
		end
	end

	return {
		maxCand
	}
end

function BattleTargetChoise.TargetAttrFloor(arg_21_0, arg_21_1, arg_21_2)
	local var_21_0 = arg_21_2 or BattleTargetChoise.TargetEntityUnit()
	local var_21_1 = arg_21_1.floorAttr
	local var_21_2 = Mathf.Infinity
	local var_21_3

	for iter_21_0, iter_21_1 in ipairs(var_21_0) do
		local var_21_4 = iter_21_1:GetAttrByName(var_21_1)

		if var_21_4 <= var_21_2 then
			var_21_2 = var_21_4
			var_21_3 = iter_21_1
		end
	end

	return {
		var_21_3
	}
end

function BattleTargetChoise.TargetTempCompare(arg_22_0, arg_22_1, arg_22_2)
	local var_22_0 = {}
	local var_22_1 = arg_22_2 or BattleTargetChoise.TargetEntityUnit()

	for iter_22_0, iter_22_1 in pairs(var_22_1) do
		if iter_22_1:IsAlive() and var_0_2.parseCompareUnitTemplate(arg_22_1.tempCompare, iter_22_1, arg_22_0) then
			table.insert(var_22_0, iter_22_1)
		end
	end

	return var_22_0
end

function BattleTargetChoise.TargetHPCompare(arg_23_0, arg_23_1, arg_23_2)
	local var_23_0 = {}
	local var_23_1 = arg_23_2 or BattleTargetChoise.TargetEntityUnit()

	if arg_23_0 then
		local var_23_2 = arg_23_0:GetHP()

		for iter_23_0, iter_23_1 in ipairs(var_23_1) do
			if var_23_2 > iter_23_1:GetHP() then
				var_23_0[#var_23_0 + 1] = iter_23_1
			end
		end
	end

	return var_23_0
end

function BattleTargetChoise.TargetHPRatioLowerThan(arg_24_0, arg_24_1, arg_24_2)
	local var_24_0 = {}
	local var_24_1 = arg_24_1.hpRatioList[1]
	local var_24_2 = arg_24_2 or BattleTargetChoise.TargetEntityUnit()

	for iter_24_0, iter_24_1 in ipairs(var_24_2) do
		if var_24_1 > iter_24_1:GetHP() then
			var_24_0[#var_24_0 + 1] = iter_24_1
		end
	end

	return var_24_0
end

function BattleTargetChoise.TargetNationalityFriendly(arg_25_0, arg_25_1, arg_25_2)
	local var_25_0 = {}

	if arg_25_0 then
		local var_25_1 = arg_25_1.nationality
		local var_25_2 = arg_25_2 or BattleTargetChoise.TargetAllHelp(arg_25_0, arg_25_1)

		for iter_25_0, iter_25_1 in pairs(var_25_2) do
			if iter_25_1:GetTemplate().nationality == var_25_1 then
				var_25_0[#var_25_0 + 1] = iter_25_1
			end
		end
	end

	return var_25_0
end

function BattleTargetChoise.TargetNationalityFoe(arg_26_0, arg_26_1, arg_26_2)
	local var_26_0 = {}

	if arg_26_0 then
		local var_26_1 = arg_26_1.nationality
		local var_26_2 = arg_26_2 or BattleTargetChoise.TargetAllHarm(arg_26_0, arg_26_1)

		for iter_26_0, iter_26_1 in pairs(var_26_2) do
			if iter_26_1:GetTemplate().nationality == var_26_1 then
				var_26_0[#var_26_0 + 1] = iter_26_1
			end
		end
	end

	return var_26_0
end

function BattleTargetChoise.TargetShipTypeFriendly(arg_27_0, arg_27_1, arg_27_2)
	local var_27_0 = {}

	if arg_27_0 then
		local var_27_1 = arg_27_1.ship_type_list
		local var_27_2 = arg_27_2 or BattleTargetChoise.TargetAllHelp(arg_27_0, arg_27_1)

		for iter_27_0, iter_27_1 in pairs(var_27_2) do
			local var_27_3 = iter_27_1:GetTemplate().type

			if table.contains(var_27_1, var_27_3) then
				var_27_0[#var_27_0 + 1] = iter_27_1
			end
		end
	end

	return var_27_0
end

function BattleTargetChoise.TargetSelf(arg_28_0)
	return {
		arg_28_0
	}
end

function BattleTargetChoise.TargetAllHarm(caster, argList, candidateList)
	local targetList = {}
	local _candidateList
	local casterIFF = caster:GetIFF()
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()

	if candidateList then
		_candidateList = {}

		for _, candidate in ipairs(candidateList) do
			if candidate:GetIFF() * casterIFF == -1 then
				table.insert(_candidateList, candidate)
			end
		end
	elseif casterIFF == BattleConfig.FRIENDLY_CODE then
		_candidateList = battleDataProxy:GetFoeShipList()
	elseif casterIFF == BattleConfig.FOE_CODE then
		_candidateList = battleDataProxy:GetFriendlyShipList()
	end

	local _, _, _, rightFieldBound = battleDataProxy:GetFieldBound()

	if _candidateList then
		for _, candidate in pairs(_candidateList) do
			if candidate:IsAlive() and rightFieldBound > candidate:GetPosition().x and candidate:GetCurrentOxyState() ~= ys.Battle.BattleConst.OXY_STATE.DIVE then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

function BattleTargetChoise.TargetAllFoe(arg_30_0, arg_30_1, arg_30_2)
	local var_30_0 = {}
	local var_30_1
	local var_30_2 = arg_30_0:GetIFF()
	local var_30_3 = ys.Battle.BattleDataProxy.GetInstance()

	if arg_30_2 then
		var_30_1 = {}

		for iter_30_0, iter_30_1 in ipairs(arg_30_2) do
			if iter_30_1:GetIFF() * var_30_2 == -1 then
				table.insert(var_30_1, iter_30_1)
			end
		end
	elseif var_30_2 == var_0_0.FRIENDLY_CODE then
		var_30_1 = var_30_3:GetFoeShipList()
	elseif var_30_2 == var_0_0.FOE_CODE then
		var_30_1 = var_30_3:GetFriendlyShipList()
	end

	local var_30_4, var_30_5, var_30_6, var_30_7 = var_30_3:GetFieldBound()

	if var_30_1 then
		for iter_30_2, iter_30_3 in pairs(var_30_1) do
			if iter_30_3:IsAlive() and var_30_7 > iter_30_3:GetPosition().x then
				var_30_0[#var_30_0 + 1] = iter_30_3
			end
		end
	end

	return targetList
end

function BattleTargetChoise.TargetFoeUncloak(arg_31_0, arg_31_1, arg_31_2)
	local var_31_0 = {}
	local var_31_1
	local var_31_2 = arg_31_0:GetIFF()
	local var_31_3 = ys.Battle.BattleDataProxy.GetInstance()

	if arg_31_2 then
		var_31_1 = {}

		for iter_31_0, iter_31_1 in ipairs(arg_31_2) do
			if iter_31_1:GetIFF() * var_31_2 == -1 then
				table.insert(var_31_1, iter_31_1)
			end
		end
	elseif var_31_2 == var_0_0.FRIENDLY_CODE then
		var_31_1 = var_31_3:GetFoeShipList()
	elseif var_31_2 == var_0_0.FOE_CODE then
		var_31_1 = var_31_3:GetFriendlyShipList()
	end

	local var_31_4, var_31_5, var_31_6, var_31_7 = var_31_3:GetFieldBound()

	if var_31_1 then
		for iter_31_2, iter_31_3 in pairs(var_31_1) do
			if iter_31_3:IsAlive() and var_31_7 > iter_31_3:GetPosition().x and not var_0_1.IsCloak(iter_31_3) and iter_31_3:GetCurrentOxyState() ~= ys.Battle.BattleConst.OXY_STATE.DIVE then
				var_31_0[#var_31_0 + 1] = iter_31_3
			end
		end
	end

	return var_31_0
end

function BattleTargetChoise.TargetCloakState(arg_32_0, arg_32_1, arg_32_2)
	local var_32_0 = {}
	local var_32_1 = arg_32_1.cloak or 1
	local var_32_2 = arg_32_2 or BattleTargetChoise.TargetEntityUnit()

	for iter_32_0, iter_32_1 in ipairs(var_32_2) do
		if var_0_1.GetCurrent(iter_32_1, "isCloak") == var_32_1 then
			var_32_0[#var_32_0 + 1] = iter_32_1
		end
	end

	return var_32_0
end

function BattleTargetChoise.TargetFaintState(arg_33_0, arg_33_1, arg_33_2)
	local var_33_0 = {}
	local var_33_1 = arg_33_1.faint or 1
	local var_33_2 = arg_33_2 or BattleTargetChoise.TargetEntityUnit()

	for iter_33_0, iter_33_1 in ipairs(var_33_2) do
		local var_33_3 = iter_33_1:GetAimBias()

		if var_33_1 == 1 then
			if var_33_3 and var_33_3:IsFaint() then
				var_33_0[#var_33_0 + 1] = iter_33_1
			end
		elseif var_33_1 == 0 and (not var_33_3 or not var_33_3:IsFaint()) then
			var_33_0[#var_33_0 + 1] = iter_33_1
		end
	end

	return var_33_0
end

function BattleTargetChoise.TargetNearest(arg_34_0, arg_34_1, arg_34_2)
	arg_34_1 = arg_34_1 or {}

	local var_34_0 = arg_34_1.range or 9999999999
	local var_34_1
	local var_34_2 = arg_34_2

	for iter_34_0, iter_34_1 in ipairs(var_34_2) do
		local var_34_3 = arg_34_0:GetDistance(iter_34_1)

		if var_34_3 < var_34_0 then
			var_34_0 = var_34_3
			var_34_1 = iter_34_1
		end
	end

	return {
		var_34_1
	}
end

function BattleTargetChoise.TargetHarmNearest(arg_35_0, arg_35_1, arg_35_2)
	arg_35_1 = arg_35_1 or {}

	local var_35_0 = arg_35_1.range or 9999999999
	local var_35_1
	local var_35_2 = arg_35_2 and BattleTargetChoise.TargetFoeUncloak(arg_35_0, arg_35_1, arg_35_2) or BattleTargetChoise.TargetFoeUncloak(arg_35_0)

	for iter_35_0, iter_35_1 in ipairs(var_35_2) do
		local var_35_3 = arg_35_0:GetDistance(iter_35_1)

		if var_35_3 < var_35_0 then
			var_35_0 = var_35_3
			var_35_1 = iter_35_1
		end
	end

	return {
		var_35_1
	}
end

function BattleTargetChoise.TargetHarmFarthest(arg_36_0, arg_36_1, arg_36_2)
	local var_36_0 = 0
	local var_36_1

	arg_36_1 = arg_36_1 or {}

	local var_36_2 = arg_36_2 and BattleTargetChoise.TargetFoeUncloak(arg_36_0, arg_36_1, arg_36_2) or BattleTargetChoise.TargetFoeUncloak(arg_36_0)

	for iter_36_0, iter_36_1 in ipairs(var_36_2) do
		local var_36_3 = arg_36_0:GetDistance(iter_36_1)

		if var_36_0 < var_36_3 then
			var_36_0 = var_36_3
			var_36_1 = iter_36_1
		end
	end

	return {
		var_36_1
	}
end

function BattleTargetChoise.TargetHarmRandom(arg_37_0, arg_37_1, arg_37_2)
	arg_37_1 = arg_37_1 or {}

	local var_37_0 = arg_37_2 and BattleTargetChoise.TargetFoeUncloak(arg_37_0, arg_37_1, arg_37_2) or BattleTargetChoise.TargetFoeUncloak(arg_37_0)

	if #var_37_0 > 0 then
		local var_37_1 = math.random(#var_37_0)

		return {
			var_37_0[var_37_1]
		}
	else
		return {}
	end
end

function BattleTargetChoise.TargetHarmRandomByWeight(arg_38_0, arg_38_1, arg_38_2)
	arg_38_1 = arg_38_1 or {}

	local var_38_0 = arg_38_2 and BattleTargetChoise.TargetFoeUncloak(arg_38_0, arg_38_1, arg_38_2) or BattleTargetChoise.TargetFoeUncloak(arg_38_0)
	local var_38_1 = {}
	local var_38_2 = -9999

	for iter_38_0, iter_38_1 in ipairs(var_38_0) do
		local var_38_3 = iter_38_1:GetTargetedPriority() or 0

		if var_38_3 == var_38_2 then
			var_38_1[#var_38_1 + 1] = iter_38_1
		elseif var_38_2 < var_38_3 then
			var_38_1 = {
				iter_38_1
			}
			var_38_2 = var_38_3
		end
	end

	if #var_38_1 > 0 then
		local var_38_4 = math.random(#var_38_1)

		return {
			var_38_1[var_38_4]
		}
	else
		return {}
	end
end

function BattleTargetChoise.TargetWeightiest(arg_39_0, arg_39_1, arg_39_2)
	local var_39_0 = arg_39_2 or BattleTargetChoise.TargetEntityUnit()
	local var_39_1 = {}
	local var_39_2 = -9999

	for iter_39_0, iter_39_1 in ipairs(var_39_0) do
		local var_39_3 = iter_39_1:GetTargetedPriority() or 0

		if var_39_3 == var_39_2 then
			var_39_1[#var_39_1 + 1] = iter_39_1
		elseif var_39_2 < var_39_3 then
			var_39_1 = {
				iter_39_1
			}
			var_39_2 = var_39_3
		end
	end

	return var_39_1
end

function BattleTargetChoise.TargetRandom(arg_40_0, arg_40_1, arg_40_2)
	local var_40_0 = arg_40_2 or BattleTargetChoise.TargetEntityUnit()
	local var_40_1 = arg_40_1.randomCount or 1

	return (Mathf.MultiRandom(var_40_0, var_40_1))
end

function BattleTargetChoise.TargetInsideArea(arg_41_0, arg_41_1, arg_41_2)
	local var_41_0 = arg_41_2 or BattleTargetChoise.TargetAllHarm(arg_41_0)
	local var_41_1 = arg_41_1.dir or ys.Battle.BattleConst.UnitDir.RIGHT
	local var_41_2 = arg_41_1.lineX
	local var_41_3 = {}

	if var_41_1 == ys.Battle.BattleConst.UnitDir.RIGHT then
		for iter_41_0, iter_41_1 in ipairs(var_41_0) do
			if var_41_2 <= iter_41_1:GetPosition().x then
				table.insert(var_41_3, iter_41_1)
			end
		end
	elseif var_41_1 == ys.Battle.BattleConst.UnitDir.LEFT then
		for iter_41_2, iter_41_3 in ipairs(var_41_0) do
			if var_41_2 >= iter_41_3:GetPosition().x then
				table.insert(var_41_3, iter_41_3)
			end
		end
	end

	return var_41_3
end

function BattleTargetChoise.TargetAircraftHelp(arg_42_0)
	local var_42_0 = ys.Battle.BattleDataProxy.GetInstance()
	local var_42_1 = {}
	local var_42_2 = arg_42_0:GetIFF()

	for iter_42_0, iter_42_1 in pairs(var_42_0:GetAircraftList()) do
		if var_42_2 == iter_42_1:GetIFF() then
			var_42_1[#var_42_1 + 1] = iter_42_1
		end
	end

	return candidateList
end

function BattleTargetChoise.TargetAircraftHarm(arg_43_0)
	local var_43_0 = ys.Battle.BattleDataProxy.GetInstance()
	local var_43_1 = {}
	local var_43_2 = arg_43_0:GetIFF()

	for iter_43_0, iter_43_1 in pairs(var_43_0:GetAircraftList()) do
		if var_43_2 ~= iter_43_1:GetIFF() and iter_43_1:IsVisitable() then
			var_43_1[#var_43_1 + 1] = iter_43_1
		end
	end

	return var_43_1
end

function BattleTargetChoise.TargetAircraftGB(arg_44_0)
	local var_44_0 = ys.Battle.BattleDataProxy.GetInstance()
	local var_44_1 = {}
	local var_44_2 = arg_44_0:GetIFF()

	for iter_44_0, iter_44_1 in pairs(var_44_0:GetAircraftList()) do
		if var_44_2 ~= iter_44_1:GetIFF() and iter_44_1:IsVisitable() and iter_44_1:GetMotherUnit() == nil then
			var_44_1[#var_44_1 + 1] = iter_44_1
		end
	end

	return var_44_1
end

function BattleTargetChoise.TargetDiveState(arg_45_0, arg_45_1, arg_45_2)
	local var_45_0 = arg_45_1 and arg_45_1.diveState or ys.Battle.BattleConst.OXY_STATE.DIVE
	local var_45_1 = arg_45_2 or BattleTargetChoise.TargetEntityUnit()
	local var_45_2 = {}

	for iter_45_0, iter_45_1 in pairs(var_45_1) do
		if var_45_0 == iter_45_1:GetCurrentOxyState() then
			var_45_2[#var_45_2 + 1] = iter_45_1
		end
	end

	return var_45_2
end

function BattleTargetChoise.TargetDetectedUnit(arg_46_0, arg_46_1, arg_46_2)
	local var_46_0 = arg_46_2 or BattleTargetChoise.TargetEntityUnit()
	local var_46_1 = {}

	for iter_46_0, iter_46_1 in pairs(var_46_0) do
		if iter_46_1:GetDiveDetected() then
			var_46_1[#var_46_1 + 1] = iter_46_1
		end
	end

	return var_46_1
end

function BattleTargetChoise.TargetFatalDamageSrc(arg_47_0, arg_47_1, arg_47_2)
	local var_47_0 = arg_47_2 or BattleTargetChoise.TargetEntityUnit()
	local var_47_1 = arg_47_0:GetDeathSrcID()
	local var_47_2 = {}

	if var_47_1 then
		for iter_47_0, iter_47_1 in pairs(var_47_0) do
			if var_47_1 == iter_47_1:GetUniqueID() and iter_47_1:IsAlive() then
				var_47_2[#var_47_2 + 1] = iter_47_1
			end
		end
	end

	return var_47_2
end

function BattleTargetChoise.TargetAllHarmBullet(arg_48_0)
	local var_48_0 = ys.Battle.BattleDataProxy.GetInstance()
	local var_48_1 = {}
	local var_48_2 = arg_48_0:GetIFF()

	for iter_48_0, iter_48_1 in pairs(var_48_0:GetBulletList()) do
		if var_48_2 ~= iter_48_1:GetIFF() then
			var_48_1[#var_48_1 + 1] = iter_48_1
		end
	end

	return var_48_1
end

function BattleTargetChoise.TargetAllHarmBulletByType(arg_49_0, arg_49_1)
	local var_49_0 = ys.Battle.BattleDataProxy.GetInstance()
	local var_49_1 = {}
	local var_49_2 = arg_49_0:GetIFF()

	for iter_49_0, iter_49_1 in pairs(var_49_0:GetBulletList()) do
		if var_49_2 ~= iter_49_1:GetIFF() and iter_49_1:GetType() == arg_49_1 then
			var_49_1[#var_49_1 + 1] = iter_49_1
		end
	end

	return var_49_1
end

function BattleTargetChoise.TargetAllHarmTorpedoBullet(arg_50_0)
	return BattleTargetChoise.TargetAllHarmBulletByType(arg_50_0, ys.Battle.BattleConst.BulletType.TORPEDO)
end

function BattleTargetChoise.TargetFleetIndex(arg_51_0, arg_51_1)
	local var_51_0

	if arg_51_0 then
		var_51_0 = arg_51_0:GetIFF()
	else
		var_51_0 = var_0_0.FRIENDLY_CODE
	end

	local var_51_1 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(var_51_0)
	local var_51_2 = TeamType.TeamPos
	local var_51_3 = arg_51_1.fleetPos
	local var_51_4 = {}
	local var_51_5 = var_51_1:GetUnitList()
	local var_51_6 = var_51_1:GetScoutList()
	local var_51_7 = arg_51_1.exceptCaster

	if var_51_7 then
		local var_51_8 = arg_51_0:GetUniqueID()
	end

	for iter_51_0, iter_51_1 in ipairs(var_51_5) do
		local var_51_9 = iter_51_1:GetUniqueID()

		if var_51_7 and var_51_9 == casterID then
			-- block empty
		elseif iter_51_1 == var_51_1:GetFlagShip() then
			if var_51_3 == var_51_2.FLAG_SHIP then
				table.insert(var_51_4, iter_51_1)
			end
		elseif iter_51_1 == var_51_6[1] then
			if var_51_3 == var_51_2.LEADER then
				table.insert(var_51_4, iter_51_1)
			end
		elseif #var_51_6 == 3 and iter_51_1 == var_51_6[2] then
			if var_51_3 == var_51_2.CENTER then
				table.insert(var_51_4, iter_51_1)
			end
		elseif iter_51_1 == var_51_6[#var_51_6] then
			if var_51_3 == var_51_2.REAR then
				table.insert(var_51_4, iter_51_1)
			end
		elseif iter_51_1:IsMainFleetUnit() and iter_51_1:GetMainUnitIndex() == 2 then
			if var_51_3 == var_51_2.UPPER_CONSORT then
				table.insert(var_51_4, iter_51_1)
			end
		elseif iter_51_1:IsMainFleetUnit() and iter_51_1:GetMainUnitIndex() == 3 and var_51_3 == var_51_2.LOWER_CONSORT then
			table.insert(var_51_4, iter_51_1)
		end
	end

	local var_51_10 = var_51_1:GetSubList()

	for iter_51_2, iter_51_3 in ipairs(var_51_5) do
		if iter_51_2 == 1 then
			if var_51_3 == var_51_2.SUB_LEADER then
				table.insert(var_51_4, iter_51_3)
			end
		elseif var_51_3 == var_51_2.SUB_CONSORT then
			table.insert(var_51_4, iter_51_3)
		end
	end

	return var_51_4
end

function BattleTargetChoise.TargetPlayerVanguardFleet(arg_52_0, arg_52_1, arg_52_2)
	local var_52_0 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(arg_52_0:GetIFF()):GetScoutList()

	if not arg_52_2 then
		return var_52_0
	else
		local var_52_1 = #arg_52_2

		while var_52_1 > 0 do
			if not table.contains(var_52_0, arg_52_2[var_52_1]) then
				table.remove(arg_52_2, var_52_1)
			end

			var_52_1 = var_52_1 - 1
		end

		return arg_52_2
	end
end

function BattleTargetChoise.TargetPlayerMainFleet(arg_53_0, arg_53_1, arg_53_2)
	local var_53_0 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(arg_53_0:GetIFF()):GetMainList()

	if not arg_53_2 then
		return var_53_0
	else
		local var_53_1 = #arg_53_2

		while var_53_1 > 0 do
			if not table.contains(var_53_0, arg_53_2[var_53_1]) then
				table.remove(arg_53_2, var_53_1)
			end

			var_53_1 = var_53_1 - 1
		end

		return arg_53_2
	end
end

function BattleTargetChoise.TargetPlayerFlagShip(arg_54_0, arg_54_1, arg_54_2)
	local var_54_0 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(arg_54_0:GetIFF())

	return {
		var_54_0:GetFlagShip()
	}
end

function BattleTargetChoise.TargetPlayerLeaderShip(arg_55_0, arg_55_1, arg_55_2)
	local var_55_0 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(arg_55_0:GetIFF())

	return {
		var_55_0:GetLeaderShip()
	}
end

function BattleTargetChoise.TargetEnemyLeaderShip(arg_56_0, arg_56_1, arg_56_2)
	local var_56_0 = arg_56_0:GetIFF() * -1
	local var_56_1 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(var_56_0)

	return {
		var_56_1:GetLeaderShip()
	}
end

function BattleTargetChoise.TargetPlayerByType(arg_57_0, arg_57_1)
	local var_57_0 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(arg_57_0:GetIFF()):GetUnitList()
	local var_57_1 = {}
	local var_57_2 = arg_57_1.shipType

	for iter_57_0, iter_57_1 in ipairs(var_57_0) do
		if iter_57_1:GetTemplate().type == var_57_2 then
			var_57_1[#var_57_1 + 1] = iter_57_1
		end
	end

	return var_57_1
end

function BattleTargetChoise.TargetPlayerAidUnit(arg_58_0, arg_58_1)
	local var_58_0 = ys.Battle.BattleDataProxy.GetInstance():GetAidUnit()
	local var_58_1 = {}

	for iter_58_0, iter_58_1 in pairs(var_58_0) do
		table.insert(var_58_1, iter_58_1)
	end

	return var_58_1
end

function BattleTargetChoise.TargetDamageSource(arg_59_0, arg_59_1, arg_59_2)
	local var_59_0 = arg_59_2 or BattleTargetChoise.TargetAllFoe(arg_59_0)
	local var_59_1 = {}

	for iter_59_0, iter_59_1 in pairs(var_59_0) do
		if iter_59_1:GetUniqueID() == arg_59_1.damageSourceID then
			table.insert(var_59_1, iter_59_1)

			break
		end
	end

	return var_59_1
end

function BattleTargetChoise.TargetRarity(arg_60_0, arg_60_1, arg_60_2)
	local var_60_0 = arg_60_2 or BattleTargetChoise.TargetAllHelp(arg_60_0)
	local var_60_1 = {}

	for iter_60_0, iter_60_1 in ipairs(var_60_0) do
		if iter_60_1:GetRarity() == arg_60_1.rarity then
			table.insert(var_60_1, iter_60_1)
		end
	end

	return var_60_1
end

function BattleTargetChoise.TargetIllustrator(arg_61_0, arg_61_1, arg_61_2)
	local var_61_0 = arg_61_2 or BattleTargetChoise.TargetAllHelp(arg_61_0)
	local var_61_1 = {}

	for iter_61_0, iter_61_1 in ipairs(var_61_0) do
		if ys.Battle.BattleDataFunction.GetPlayerShipSkinDataFromID(iter_61_1:GetSkinID()).illustrator == arg_61_1.illustrator then
			table.insert(var_61_1, iter_61_1)
		end
	end

	return var_61_1
end

function BattleTargetChoise.TargetTeam(arg_62_0, arg_62_1, arg_62_2)
	local var_62_0 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(arg_62_0:GetIFF())
	local var_62_1 = {}
	local var_62_2 = TeamType.TeamTypeIndex[arg_62_1.teamIndex]

	if var_62_2 == TeamType.Vanguard then
		var_62_1 = var_62_0:GetScoutList()
	elseif var_62_2 == TeamType.Main then
		var_62_1 = var_62_0:GetMainList()
	elseif var_62_2 == TeamType.Submarine then
		var_62_1 = var_62_0:GetSubList()
	end

	local var_62_3 = {}

	for iter_62_0, iter_62_1 in ipairs(var_62_1) do
		if not arg_62_2 or table.contains(arg_62_2, iter_62_1) then
			table.insert(var_62_3, iter_62_1)
		end
	end

	return var_62_3
end

function BattleTargetChoise.TargetGroup(arg_63_0, arg_63_1, arg_63_2)
	local var_63_0 = arg_63_1.groupIDList
	local var_63_1 = arg_63_2 or BattleTargetChoise.TargetAllHelp(arg_63_0)
	local var_63_2 = {}
	local var_63_3 = arg_63_0:GetIFF()

	for iter_63_0, iter_63_1 in ipairs(var_63_1) do
		local var_63_4 = iter_63_1:GetTemplateID()
		local var_63_5 = ys.Battle.BattleDataFunction.GetPlayerShipModelFromID(var_63_4).group_type
		local var_63_6 = iter_63_1:GetIFF()

		if table.contains(var_63_0, var_63_5) and var_63_3 == var_63_6 then
			var_63_2[#var_63_2 + 1] = iter_63_1
		end
	end

	return var_63_2
end

function BattleTargetChoise.LegalTarget(arg_64_0)
	local var_64_0 = {}
	local var_64_1
	local var_64_2 = ys.Battle.BattleDataProxy.GetInstance()
	local var_64_3, var_64_4, var_64_5, var_64_6 = var_64_2:GetFieldBound()
	local var_64_7 = var_64_2:GetUnitList()
	local var_64_8 = arg_64_0:GetIFF()

	for iter_64_0, iter_64_1 in pairs(var_64_7) do
		if iter_64_1:IsAlive() and iter_64_1:GetIFF() ~= var_64_8 and var_64_6 > iter_64_1:GetPosition().x and not iter_64_1:IsSpectre() then
			var_64_0[#var_64_0 + 1] = iter_64_1
		end
	end

	return var_64_0
end

function BattleTargetChoise.LegalWeaponTarget(arg_65_0)
	local var_65_0 = {}
	local var_65_1
	local var_65_2 = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()
	local var_65_3 = arg_65_0:GetIFF()

	for iter_65_0, iter_65_1 in pairs(var_65_2) do
		if iter_65_1:GetIFF() ~= var_65_3 and not iter_65_1:IsSpectre() then
			var_65_0[#var_65_0 + 1] = iter_65_1
		end
	end

	return var_65_0
end
