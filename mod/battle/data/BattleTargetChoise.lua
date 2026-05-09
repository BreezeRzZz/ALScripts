ys = ys or {}

--- @class BattleTargetChoise : 战斗目标筛选系统，提供所有武器/技能选择目标时的筛选函数
--- 每个筛选函数的统一签名为 function(caster, argList, candidateList)
---   caster: 施法者/武器持有者单位
---   argList: 参数表（来自武器/技能配置的 target_choice 字段）
---   candidateList: 可选候选列表，不传则由函数内部获取默认候选
--- @field BattleConfig BattleConfig
--- @field BattleAttr BattleAttr
--- @field BattleFormulas BattleFormulas
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleFormulas = ys.Battle.BattleFormulas
local BattleTargetChoise = {}

ys.Battle.BattleTargetChoise = BattleTargetChoise

--- 目标为空（无目标）
--- @param caster BattleUnit
--- @return nil
function BattleTargetChoise.TargetNil()
	return nil
end

--- 目标为空表（无目标但返回空列表）
--- @param caster BattleUnit
--- @return table
function BattleTargetChoise.TargetNull()
	return {}
end

--- 目标为所有单位（不分敌我）
--- @return table 所有单位列表
function BattleTargetChoise.TargetAll()
	return ys.Battle.BattleDataProxy.GetInstance():GetUnitList()
end

--- 目标为所有非幽灵实体单位
--- @return table 实体单位列表（排除幽灵/幻影单位）
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

--- 目标为所有幽灵单位
--- @param caster BattleUnit|nil 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表（未使用）
--- @return table 幽灵单位列表
function BattleTargetChoise.TargetSpectreUnit(caster, argList, candidateList)
	local targetList = {}
	local spectreList = ys.Battle.BattleDataProxy.GetInstance():GetSpectreShipList()

	for _, spectre in pairs(spectreList) do
		targetList[#targetList + 1] = spectre
	end

	return targetList
end

--- 按模板ID筛选同阵营目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 targetTemplateIDList（或 targetTemplateID）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配的模板ID且同阵营的单位列表
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

--- 按国籍筛选目标（可以是单个国家或国家列表）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 nationality（number 或 table）
--- @param candidateList table|nil 候选列表，默认从所有单位获取
--- @return table 匹配国籍的单位列表
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

--- 按舰船类型筛选目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 ship_type_list
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配舰船类型的单位列表
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

--- 按舰船标签筛选目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 ship_tag_list
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配标签的单位列表
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

--- 按装甲类型筛选目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 armor_type
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配装甲类型的单位列表
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

--- 根据 IFF 获取对应阵营的舰船列表
--- 友方召唤物不属于 friendlyShipList；潜艇也属于 friendShipList
--- 敌方召唤物属于 foeShipList
--- 我方幽灵单位不属于 friendlyShipList（只有支援舰队这类才是幽灵）
--- 敌方幽灵单位不属于 foeShipList
--- @param IFF number 阵营标识（BattleConfig.FRIENDLY_CODE 或 BattleConfig.FOE_CODE）
--- @return table|nil 对应阵营的舰船列表
function BattleTargetChoise.getShipListByIFF(IFF)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local candidateList

	if IFF == BattleConfig.FRIENDLY_CODE then
		candidateList = battleDataProxy:GetFriendlyShipList()
	elseif IFF == BattleConfig.FOE_CODE then
		candidateList = battleDataProxy:GetFoeShipList()
	end

	return candidateList
end

--- 目标为所有友方单位（同阵营存活单位）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，可选 exceptCaster 排除施法者自身
--- @param candidateList table|nil 候选列表，默认根据 caster 阵营获取
--- @return table 友方存活单位列表
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
			-- 如果 exceptCaster 为 true，则排除施法者自己
			if candidate:IsAlive() and candidate:GetIFF() == casterIFF and (not exceptCaster or candidateUID ~= casterUID) then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为友方当前HP最低的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，可选 targetMaxHPRatio 作为HP比例上限
--- @param candidateList table|nil 候选列表，默认根据 caster 阵营获取
--- @return table 包含最低HP单位的单元素表
function BattleTargetChoise.TargetHelpLeastHP(caster, argList, candidateList)
	argList = argList or {}

	local target
	local targetMaxHPRatio = argList.targetMaxHPRatio

	if caster then
		local _candidateList = candidateList or BattleTargetChoise.getShipListByIFF(caster:GetIFF())
		local minHP = 9999999999

		for _, candidate in pairs(_candidateList) do
			-- 存活、HP更低，且（无HP比例限制 或 HP比例不超过上限）
			if candidate:IsAlive() and minHP > candidate:GetCurrentHP() and (not targetMaxHPRatio or targetMaxHPRatio >= candidate:GetHPRate()) then
				target = candidate
				minHP = candidate:GetCurrentHP()
			end
		end
	end

	return {
		target
	}
end

--- 目标为友方HP比例最低的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认根据 caster 阵营获取
--- @return table 包含最低HP比例单位的单元素表
function BattleTargetChoise.TargetHelpLeastHPRatio(caster, argList, candidateList)
	argList = argList or {}

	local target

	if caster then
		local leastHPRatio = 100
		local _candidateList = candidateList or BattleTargetChoise.getShipListByIFF(caster:GetIFF())

		for _, candidate in pairs(_candidateList) do
			-- GetHPRate 返回的是当前耐久与最大耐久之比，因此最大值为1
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

--- 目标为当前HP最高的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 包含最高HP单位的单元素表
function BattleTargetChoise.TargetHighestHP(caster, argList, candidateList)
	argList = argList or {}

	local target

	if caster then
		local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
		local maxHP = 1

		for _, candidate in pairs(_candidateList) do
			if candidate:IsAlive() and maxHP < candidate:GetCurrentHP() then
				target = candidate
				maxHP = candidate:GetCurrentHP()
			end
		end
	end

	return {
		target
	}
end

--- 目标为HP比例最低的单位（排除已死亡单位）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 包含最低HP比例单位的单元素表
function BattleTargetChoise.TargetLowestHPRatio(caster, argList, candidateList)
	argList = argList or {}

	local target
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local minHPRatio = 1

	for _, candidate in pairs(_candidateList) do
		local hpRatio = candidate:GetHPRate()

		if candidate:IsAlive() and hpRatio < minHPRatio and hpRatio > 0 then
			target = candidate
			minHPRatio = hpRatio
		end
	end

	return {
		target
	}
end

--- 目标为当前HP最低的单位（排除已死亡单位）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 包含最低HP单位的单元素表
function BattleTargetChoise.TargetLowestHP(caster, argList, candidateList)
	argList = argList or {}

	local target
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local minHP = 9999999999

	for _, candidate in pairs(_candidateList) do
		local currentHP = candidate:GetCurrentHP()

		if candidate:IsAlive() and currentHP < minHP and currentHP > 0 then
			target = candidate
			minHP = currentHP
		end
	end

	return {
		target
	}
end

--- 目标为HP比例最高的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 包含最高HP比例单位的单元素表
function BattleTargetChoise.TargetHighestHPRatio(caster, argList, candidateList)
	argList = argList or {}

	local target
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local maxHPRatio = 0

	for _, candidate in pairs(_candidateList) do
		if candidate:IsAlive() and maxHPRatio < candidate:GetHPRate() then
			target = candidate
			maxHPRatio = candidate:GetHPRate()
		end
	end

	return {
		target
	}
end

--- 按属性比较条件筛选目标（使用 BattleFormulas.parseCompareUnitAttr）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 attrCompare
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 满足属性比较条件的单位列表
function BattleTargetChoise.TargetAttrCompare(caster, argList, candidateList)
	local targetList = {}
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()

	for _, candidate in pairs(_candidateList) do
		if candidate:IsAlive() and BattleFormulas.parseCompareUnitAttr(argList.attrCompare, candidate, caster) then
			table.insert(targetList, candidate)
		end
	end

	return targetList
end

--- 目标为指定属性值最大的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 ceilAttr（属性名）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 包含属性值最大单位的单元素表
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

--- 目标为指定属性值最小的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 floorAttr（属性名）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 包含属性值最小单位的单元素表
function BattleTargetChoise.TargetAttrFloor(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local floorAttr = argList.floorAttr
	local minValue = Mathf.Infinity
	local minCand

	for _, candidate in ipairs(_candidateList) do
		local attrValue = candidate:GetAttrByName(floorAttr)

		if attrValue <= minValue then
			minValue = attrValue
			minCand = candidate
		end
	end

	return {
		minCand
	}
end

--- 按模板比较条件筛选目标（使用 BattleFormulas.parseCompareUnitTemplate）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 tempCompare
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 满足模板比较条件的单位列表
function BattleTargetChoise.TargetTempCompare(caster, argList, candidateList)
	local targetList = {}
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()

	for _, candidate in pairs(_candidateList) do
		if candidate:IsAlive() and BattleFormulas.parseCompareUnitTemplate(argList.tempCompare, candidate, caster) then
			table.insert(targetList, candidate)
		end
	end

	return targetList
end

--- 目标为HP比施法者低的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table HP低于施法者的单位列表
function BattleTargetChoise.TargetHPCompare(caster, argList, candidateList)
	local targetList = {}
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()

	if caster then
		local casterHP = caster:GetHP()

		for _, candidate in ipairs(_candidateList) do
			if casterHP > candidate:GetHP() then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为HP低于指定比例阈值的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 hpRatioList（取第一个值作为阈值）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table HP低于阈值的单位列表
function BattleTargetChoise.TargetHPRatioLowerThan(caster, argList, candidateList)
	local targetList = {}
	local hpRatioThreshold = argList.hpRatioList[1]
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()

	for _, candidate in ipairs(_candidateList) do
		if hpRatioThreshold > candidate:GetHP() then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

--- 目标为友方中指定国籍的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 nationality
--- @param candidateList table|nil 候选列表，默认从 TargetAllHelp 获取
--- @return table 友方中匹配国籍的单位列表
function BattleTargetChoise.TargetNationalityFriendly(caster, argList, candidateList)
	local targetList = {}

	if caster then
		local nationality = argList.nationality
		local _candidateList = candidateList or BattleTargetChoise.TargetAllHelp(caster, argList)

		for _, candidate in pairs(_candidateList) do
			if candidate:GetTemplate().nationality == nationality then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为敌方中指定国籍的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 nationality
--- @param candidateList table|nil 候选列表，默认从 TargetAllHarm 获取
--- @return table 敌方中匹配国籍的单位列表
function BattleTargetChoise.TargetNationalityFoe(caster, argList, candidateList)
	local targetList = {}

	if caster then
		local nationality = argList.nationality
		local _candidateList = candidateList or BattleTargetChoise.TargetAllHarm(caster, argList)

		for _, candidate in pairs(_candidateList) do
			if candidate:GetTemplate().nationality == nationality then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为友方中指定舰船类型的单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 ship_type_list
--- @param candidateList table|nil 候选列表，默认从 TargetAllHelp 获取
--- @return table 友方中匹配舰船类型的单位列表
function BattleTargetChoise.TargetShipTypeFriendly(caster, argList, candidateList)
	local targetList = {}

	if caster then
		local shipTypeList = argList.ship_type_list
		local _candidateList = candidateList or BattleTargetChoise.TargetAllHelp(caster, argList)

		for _, candidate in pairs(_candidateList) do
			local candidateType = candidate:GetTemplate().type

			if table.contains(shipTypeList, candidateType) then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为施法者自身
--- @param caster BattleUnit 施法者
--- @return table 包含施法者自身的单元素表
function BattleTargetChoise.TargetSelf(caster)
	return {
		caster
	}
end

--- 目标为所有敌方单位（取反IFF），包含场界和潜水状态校验
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，若传入则从中筛选敌方
--- @return table 敌方存活、在场界内、非潜水状态的单位列表
function BattleTargetChoise.TargetAllHarm(caster, argList, candidateList)
	local targetList = {}
	local _candidateList
	local casterIFF = caster:GetIFF()
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()

	if candidateList then
		_candidateList = {}

		for _, candidate in ipairs(candidateList) do
			-- IFF 乘积为 -1 表示不同阵营
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
			-- 存活、在场界右侧之内、非潜水状态
			if candidate:IsAlive() and rightFieldBound > candidate:GetPosition().x and candidate:GetCurrentOxyState() ~= ys.Battle.BattleConst.OXY_STATE.DIVE then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为所有敌方单位（取反IFF），含场界校验，不校验潜水状态
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，若传入则从中筛选敌方
--- @return table 敌方存活、在场界内的单位列表
function BattleTargetChoise.TargetAllFoe(caster, argList, candidateList)
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
			-- 与 TargetAllHarm 的区别：不校验潜水状态
			if candidate:IsAlive() and rightFieldBound > candidate:GetPosition().x then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为未隐身的敌方单位（排除隐身和潜水单位）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，若传入则从中筛选敌方
--- @return table 敌方存活、在场界内、非隐身、非潜水的单位列表
function BattleTargetChoise.TargetFoeUncloak(caster, argList, candidateList)
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
			-- 与 TargetAllHarm 的区别：额外排除隐身单位
			if candidate:IsAlive() and rightFieldBound > candidate:GetPosition().x and not BattleAttr.IsCloak(candidate) and candidate:GetCurrentOxyState() ~= ys.Battle.BattleConst.OXY_STATE.DIVE then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 按隐身状态筛选目标
--- @param caster BattleUnit|nil 施法者
--- @param argList table 参数表，可选 cloak（1=隐身, 0=非隐身，默认1）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配隐身状态的单位列表
function BattleTargetChoise.TargetCloakState(caster, argList, candidateList)
	local targetList = {}
	local cloakState = argList.cloak or 1
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()

	for _, candidate in ipairs(_candidateList) do
		if BattleAttr.GetCurrent(candidate, "isCloak") == cloakState then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

--- 按假寐（Faint）状态筛选目标
--- @param caster BattleUnit|nil 施法者
--- @param argList table 参数表，可选 faint（1=假寐中, 0=非假寐，默认1）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配假寐状态的单位列表
function BattleTargetChoise.TargetFaintState(caster, argList, candidateList)
	local targetList = {}
	local faintState = argList.faint or 1
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()

	for _, candidate in ipairs(_candidateList) do
		local aimBias = candidate:GetAimBias()

		if faintState == 1 then
			-- 筛选处于假寐状态的单位
			if aimBias and aimBias:IsFaint() then
				targetList[#targetList + 1] = candidate
			end
		elseif faintState == 0 and (not aimBias or not aimBias:IsFaint()) then
			-- 筛选非假寐状态的单位
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

--- 目标为最近的单位（按距离排序取最近）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，可选 range（最大搜索距离，默认 9999999999）
--- @param candidateList table 候选列表
--- @return table 包含最近单位的单元素表
function BattleTargetChoise.TargetNearest(caster, argList, candidateList)
	argList = argList or {}

	local nearestDist = argList.range or 9999999999
	local nearest
	local _candidateList = candidateList

	for _, candidate in ipairs(_candidateList) do
		local distance = caster:GetDistance(candidate)

		if distance < nearestDist then
			nearestDist = distance
			nearest = candidate
		end
	end

	return {
		nearest
	}
end

--- 目标为最近的敌方非隐身单位（在 TargetFoeUncloak 基础上取最近）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，可选 range（最大搜索距离，默认 9999999999）
--- @param candidateList table|nil 候选列表，传给 TargetFoeUncloak
--- @return table 包含最近敌方非隐身单位的单元素表
function BattleTargetChoise.TargetHarmNearest(caster, argList, candidateList)
	argList = argList or {}

	local nearestDist = argList.range or 9999999999
	local nearest
	local _candidateList = candidateList and BattleTargetChoise.TargetFoeUncloak(caster, argList, candidateList) or BattleTargetChoise.TargetFoeUncloak(caster)

	for _, candidate in ipairs(_candidateList) do
		local distance = caster:GetDistance(candidate)

		if distance < nearestDist then
			nearestDist = distance
			nearest = candidate
		end
	end

	return {
		nearest
	}
end

--- 目标为最远的敌方非隐身单位（在 TargetFoeUncloak 基础上取最远）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，传给 TargetFoeUncloak
--- @return table 包含最远敌方非隐身单位的单元素表
function BattleTargetChoise.TargetHarmFarthest(caster, argList, candidateList)
	local farthestDist = 0
	local farthest

	argList = argList or {}

	local _candidateList = candidateList and BattleTargetChoise.TargetFoeUncloak(caster, argList, candidateList) or BattleTargetChoise.TargetFoeUncloak(caster)

	for _, candidate in ipairs(_candidateList) do
		local distance = caster:GetDistance(candidate)

		if farthestDist < distance then
			farthestDist = distance
			farthest = candidate
		end
	end

	return {
		farthest
	}
end

--- 目标为随机一个敌方非隐身单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，传给 TargetFoeUncloak
--- @return table 包含随机一个敌方非隐身单位的单元素表，无候选时返回空表
function BattleTargetChoise.TargetHarmRandom(caster, argList, candidateList)
	argList = argList or {}

	local _candidateList = candidateList and BattleTargetChoise.TargetFoeUncloak(caster, argList, candidateList) or BattleTargetChoise.TargetFoeUncloak(caster)

	if #_candidateList > 0 then
		local randomIndex = math.random(#_candidateList)

		return {
			_candidateList[randomIndex]
		}
	else
		return {}
	end
end

--- 目标为按被锁定权重随机选择的敌方非隐身单位
--- 先筛选出 GetTargetedPriority 值最高的单位组，再从中随机取一个
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，传给 TargetFoeUncloak
--- @return table 包含随机选中单位的单元素表，无候选时返回空表
function BattleTargetChoise.TargetHarmRandomByWeight(caster, argList, candidateList)
	argList = argList or {}

	local _candidateList = candidateList and BattleTargetChoise.TargetFoeUncloak(caster, argList, candidateList) or BattleTargetChoise.TargetFoeUncloak(caster)
	local topPriorityList = {}
	local topPriority = -9999

	for _, candidate in ipairs(_candidateList) do
		local priority = candidate:GetTargetedPriority() or 0

		if priority == topPriority then
			topPriorityList[#topPriorityList + 1] = candidate
		elseif topPriority < priority then
			topPriorityList = {
				candidate
			}
			topPriority = priority
		end
	end

	if #topPriorityList > 0 then
		local randomIndex = math.random(#topPriorityList)

		return {
			topPriorityList[randomIndex]
		}
	else
		return {}
	end
end

--- 目标为被锁定权重最高的所有单位（不随机）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表（未使用额外字段）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 权重最高的单位列表
function BattleTargetChoise.TargetWeightiest(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local topPriorityList = {}
	local topPriority = -9999

	for _, candidate in ipairs(_candidateList) do
		local priority = candidate:GetTargetedPriority() or 0

		if priority == topPriority then
			topPriorityList[#topPriorityList + 1] = candidate
		elseif topPriority < priority then
			topPriorityList = {
				candidate
			}
			topPriority = priority
		end
	end

	return topPriorityList
end

--- 目标为随机N个单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，可选 randomCount（随机数量，默认1）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 随机选中的单位列表
function BattleTargetChoise.TargetRandom(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local randomCount = argList.randomCount or 1

	return (Mathf.MultiRandom(_candidateList, randomCount))
end

--- 目标为在场内指定方向一侧的所有敌方单位
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 lineX（分界线X坐标），可选 dir（方向，默认 RIGHT）
--- @param candidateList table|nil 候选列表，默认从 TargetAllHarm 获取
--- @return table 在场内指定侧的单位列表
function BattleTargetChoise.TargetInsideArea(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetAllHarm(caster)
	local dir = argList.dir or ys.Battle.BattleConst.UnitDir.RIGHT
	local lineX = argList.lineX
	local targetList = {}

	if dir == ys.Battle.BattleConst.UnitDir.RIGHT then
		for _, candidate in ipairs(_candidateList) do
			if lineX <= candidate:GetPosition().x then
				table.insert(targetList, candidate)
			end
		end
	elseif dir == ys.Battle.BattleConst.UnitDir.LEFT then
		for _, candidate in ipairs(_candidateList) do
			if lineX >= candidate:GetPosition().x then
				table.insert(targetList, candidate)
			end
		end
	end

	return targetList
end

--- 目标为所有友方飞机
--- @param caster BattleUnit 施法者
--- @return table 同阵营的飞机列表
function BattleTargetChoise.TargetAircraftHelp(caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, aircraft in pairs(battleDataProxy:GetAircraftList()) do
		if casterIFF == aircraft:GetIFF() then
			targetList[#targetList + 1] = aircraft
		end
	end

	return targetList
end

--- 目标为所有敌方飞机
--- @param caster BattleUnit 施法者
--- @return table 敌方可被访问的飞机列表
function BattleTargetChoise.TargetAircraftHarm(caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, aircraft in pairs(battleDataProxy:GetAircraftList()) do
		if casterIFF ~= aircraft:GetIFF() and aircraft:IsVisitable() then
			targetList[#targetList + 1] = aircraft
		end
	end

	return targetList
end

--- 目标为所有敌方陆基飞机（无母舰的敌方飞机）
--- @param caster BattleUnit 施法者
--- @return table 敌方陆基飞机列表
function BattleTargetChoise.TargetAircraftGB(caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, aircraft in pairs(battleDataProxy:GetAircraftList()) do
		-- 不同阵营、可访问、且没有母舰（即陆基飞机）
		if casterIFF ~= aircraft:GetIFF() and aircraft:IsVisitable() and aircraft:GetMotherUnit() == nil then
			targetList[#targetList + 1] = aircraft
		end
	end

	return targetList
end

--- 按潜水/浮上状态筛选目标
--- @param caster BattleUnit|nil 施法者
--- @param argList table 参数表，可选 diveState（潜水状态，默认 OXY_STATE.DIVE）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 匹配潜水状态的单位列表
function BattleTargetChoise.TargetDiveState(caster, argList, candidateList)
	local diveState = argList and argList.diveState or ys.Battle.BattleConst.OXY_STATE.DIVE
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local targetList = {}

	for _, candidate in pairs(_candidateList) do
		if diveState == candidate:GetCurrentOxyState() then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

--- 目标为被探测到的潜水单位
--- @param caster BattleUnit|nil 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 被声呐等探测到的单位列表
function BattleTargetChoise.TargetDetectedUnit(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local targetList = {}

	for _, candidate in pairs(_candidateList) do
		if candidate:GetDiveDetected() then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

--- 目标为对施法者造成致命伤害的来源单位
--- @param caster BattleUnit 施法者（通常为死亡单位）
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表，默认从 TargetEntityUnit 获取
--- @return table 致命伤害来源单位列表（存活且匹配 deathSrcID）
function BattleTargetChoise.TargetFatalDamageSrc(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetEntityUnit()
	local deathSrcID = caster:GetDeathSrcID()
	local targetList = {}

	if deathSrcID then
		for _, candidate in pairs(_candidateList) do
			if deathSrcID == candidate:GetUniqueID() and candidate:IsAlive() then
				targetList[#targetList + 1] = candidate
			end
		end
	end

	return targetList
end

--- 目标为所有敌方子弹
--- @param caster BattleUnit 施法者
--- @return table 敌方子弹列表
function BattleTargetChoise.TargetAllHarmBullet(caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, bullet in pairs(battleDataProxy:GetBulletList()) do
		if casterIFF ~= bullet:GetIFF() then
			targetList[#targetList + 1] = bullet
		end
	end

	return targetList
end

--- 目标为所有敌方指定类型的子弹
--- @param caster BattleUnit 施法者
--- @param bulletType number 子弹类型（如 BattleConst.BulletType.TORPEDO）
--- @return table 敌方指定类型子弹列表
function BattleTargetChoise.TargetAllHarmBulletByType(caster, bulletType)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, bullet in pairs(battleDataProxy:GetBulletList()) do
		if casterIFF ~= bullet:GetIFF() and bullet:GetType() == bulletType then
			targetList[#targetList + 1] = bullet
		end
	end

	return targetList
end

--- 目标为所有敌方鱼雷子弹
--- @param caster BattleUnit 施法者
--- @return table 敌方鱼雷列表
function BattleTargetChoise.TargetAllHarmTorpedoBullet(caster)
	return BattleTargetChoise.TargetAllHarmBulletByType(caster, ys.Battle.BattleConst.BulletType.TORPEDO)
end

--- 按舰队位置（旗舰/领舰/中位/后位/上僚/下僚/潜艇领舰/潜艇僚舰）筛选目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 fleetPos，可选 exceptCaster
--- @return table 匹配舰队位置的单位列表
function BattleTargetChoise.TargetFleetIndex(caster, argList)
	local casterIFF

	if caster then
		casterIFF = caster:GetIFF()
	else
		casterIFF = BattleConfig.FRIENDLY_CODE
	end

	local fleet = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(casterIFF)
	local TeamPos = TeamType.TeamPos
	local fleetPos = argList.fleetPos
	local targetList = {}
	local unitList = fleet:GetUnitList()
	local scoutList = fleet:GetScoutList()
	local exceptCaster = argList.exceptCaster

	if exceptCaster then
		local casterUID = caster:GetUniqueID()
	end

	for _, unit in ipairs(unitList) do
		local candidateUID = unit:GetUniqueID()

		if exceptCaster and candidateUID == casterID then
			-- block empty
		elseif unit == fleet:GetFlagShip() then
			if fleetPos == TeamPos.FLAG_SHIP then
				table.insert(targetList, unit)
			end
		elseif unit == scoutList[1] then
			if fleetPos == TeamPos.LEADER then
				table.insert(targetList, unit)
			end
		elseif #scoutList == 3 and unit == scoutList[2] then
			if fleetPos == TeamPos.CENTER then
				table.insert(targetList, unit)
			end
		elseif unit == scoutList[#scoutList] then
			if fleetPos == TeamPos.REAR then
				table.insert(targetList, unit)
			end
		elseif unit:IsMainFleetUnit() and unit:GetMainUnitIndex() == 2 then
			if fleetPos == TeamPos.UPPER_CONSORT then
				table.insert(targetList, unit)
			end
		elseif unit:IsMainFleetUnit() and unit:GetMainUnitIndex() == 3 and fleetPos == TeamPos.LOWER_CONSORT then
			table.insert(targetList, unit)
		end
	end

	local subList = fleet:GetSubList()

	for _, sub in ipairs(unitList) do
		if _ == 1 then
			if fleetPos == TeamPos.SUB_LEADER then
				table.insert(targetList, sub)
			end
		elseif fleetPos == TeamPos.SUB_CONSORT then
			table.insert(targetList, sub)
		end
	end

	return targetList
end

--- 目标为玩家先锋舰队（前排队列），若已有候选列表则取交集
--- @param caster BattleUnit 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表，若传入则过滤出其中属于先锋舰队的单位
--- @return table 先锋舰队单位列表
function BattleTargetChoise.TargetPlayerVanguardFleet(caster, argList, candidateList)
	local scoutList = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(caster:GetIFF()):GetScoutList()

	if not candidateList then
		return scoutList
	else
		local index = #candidateList

		while index > 0 do
			if not table.contains(scoutList, candidateList[index]) then
				table.remove(candidateList, index)
			end

			index = index - 1
		end

		return candidateList
	end
end

--- 目标为玩家主力舰队（后排），若已有候选列表则取交集
--- @param caster BattleUnit 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表，若传入则过滤出其中属于主力舰队的单位
--- @return table 主力舰队单位列表
function BattleTargetChoise.TargetPlayerMainFleet(caster, argList, candidateList)
	local mainList = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(caster:GetIFF()):GetMainList()

	if not candidateList then
		return mainList
	else
		local index = #candidateList

		while index > 0 do
			if not table.contains(mainList, candidateList[index]) then
				table.remove(candidateList, index)
			end

			index = index - 1
		end

		return candidateList
	end
end

--- 目标为玩家旗舰
--- @param caster BattleUnit 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表（未使用）
--- @return table 包含旗舰的单元素表
function BattleTargetChoise.TargetPlayerFlagShip(caster, argList, candidateList)
	local fleet = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(caster:GetIFF())

	return {
		fleet:GetFlagShip()
	}
end

--- 目标为玩家领舰（先锋第一位）
--- @param caster BattleUnit 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表（未使用）
--- @return table 包含领舰的单元素表
function BattleTargetChoise.TargetPlayerLeaderShip(caster, argList, candidateList)
	local fleet = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(caster:GetIFF())

	return {
		fleet:GetLeaderShip()
	}
end

--- 目标为敌方领舰
--- @param caster BattleUnit 施法者
--- @param argList table|nil 参数表（未使用）
--- @param candidateList table|nil 候选列表（未使用）
--- @return table 包含敌方领舰的单元素表
function BattleTargetChoise.TargetEnemyLeaderShip(caster, argList, candidateList)
	local enemyIFF = caster:GetIFF() * -1
	local fleet = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(enemyIFF)

	return {
		fleet:GetLeaderShip()
	}
end

--- 按舰船类型筛选玩家单位（同一阵营的舰队中）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 shipType
--- @return table 匹配舰船类型的玩家单位列表
function BattleTargetChoise.TargetPlayerByType(caster, argList)
	local unitList = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(caster:GetIFF()):GetUnitList()
	local targetList = {}
	local shipType = argList.shipType

	for _, unit in ipairs(unitList) do
		if unit:GetTemplate().type == shipType then
			targetList[#targetList + 1] = unit
		end
	end

	return targetList
end

--- 目标为所有友方增援单位
--- @param caster BattleUnit|nil 施法者
--- @param argList table|nil 参数表（未使用）
--- @return table 友方增援单位列表
function BattleTargetChoise.TargetPlayerAidUnit(caster, argList)
	local aidUnits = ys.Battle.BattleDataProxy.GetInstance():GetAidUnit()
	local targetList = {}

	for _, unit in pairs(aidUnits) do
		table.insert(targetList, unit)
	end

	return targetList
end

--- 按伤害来源ID筛选目标（通常用于反击类技能）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 damageSourceID
--- @param candidateList table|nil 候选列表，默认从 TargetAllFoe 获取
--- @return table 匹配伤害来源ID的单位列表（找到即停止）
function BattleTargetChoise.TargetDamageSource(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetAllFoe(caster)
	local targetList = {}

	for _, candidate in pairs(_candidateList) do
		if candidate:GetUniqueID() == argList.damageSourceID then
			table.insert(targetList, candidate)

			break
		end
	end

	return targetList
end

--- 按稀有度筛选友方目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 rarity
--- @param candidateList table|nil 候选列表，默认从 TargetAllHelp 获取
--- @return table 匹配稀有度的友方单位列表
function BattleTargetChoise.TargetRarity(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetAllHelp(caster)
	local targetList = {}

	for _, candidate in ipairs(_candidateList) do
		if candidate:GetRarity() == argList.rarity then
			table.insert(targetList, candidate)
		end
	end

	return targetList
end

--- 按画师筛选友方目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 illustrator
--- @param candidateList table|nil 候选列表，默认从 TargetAllHelp 获取
--- @return table 匹配画师的友方单位列表
function BattleTargetChoise.TargetIllustrator(caster, argList, candidateList)
	local _candidateList = candidateList or BattleTargetChoise.TargetAllHelp(caster)
	local targetList = {}

	for _, candidate in ipairs(_candidateList) do
		if ys.Battle.BattleDataFunction.GetPlayerShipSkinDataFromID(candidate:GetSkinID()).illustrator == argList.illustrator then
			table.insert(targetList, candidate)
		end
	end

	return targetList
end

--- 按编队类型筛选目标（先锋/主力/潜艇）
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 teamIndex
--- @param candidateList table|nil 候选列表，若传入则进一步过滤
--- @return table 匹配编队类型且（若传入候选列表）在候选中的单位
function BattleTargetChoise.TargetTeam(caster, argList, candidateList)
	local fleet = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(caster:GetIFF())
	local teamList = {}
	local teamType = TeamType.TeamTypeIndex[argList.teamIndex]

	if teamType == TeamType.Vanguard then
		teamList = fleet:GetScoutList()
	elseif teamType == TeamType.Main then
		teamList = fleet:GetMainList()
	elseif teamType == TeamType.Submarine then
		teamList = fleet:GetSubList()
	end

	local targetList = {}

	for _, unit in ipairs(teamList) do
		if not candidateList or table.contains(candidateList, unit) then
			table.insert(targetList, unit)
		end
	end

	return targetList
end

--- 按组别（group_type）筛选同阵营友方目标
--- @param caster BattleUnit 施法者
--- @param argList table 参数表，需含 groupIDList
--- @param candidateList table|nil 候选列表，默认从 TargetAllHelp 获取
--- @return table 匹配组别且同阵营的单位列表
function BattleTargetChoise.TargetGroup(caster, argList, candidateList)
	local groupIDList = argList.groupIDList
	local _candidateList = candidateList or BattleTargetChoise.TargetAllHelp(caster)
	local targetList = {}
	local casterIFF = caster:GetIFF()

	for _, candidate in ipairs(_candidateList) do
		local templateID = candidate:GetTemplateID()
		local groupType = ys.Battle.BattleDataFunction.GetPlayerShipModelFromID(templateID).group_type
		local candidateIFF = candidate:GetIFF()

		if table.contains(groupIDList, groupType) and casterIFF == candidateIFF then
			targetList[#targetList + 1] = candidate
		end
	end

	return targetList
end

--- 目标为所有合法敌方单位（存活、不同阵营、在场界内、非幽灵）
--- @param caster BattleUnit 施法者
--- @return table 合法敌方单位列表
function BattleTargetChoise.LegalTarget(caster)
	local targetList = {}
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local _, _, _, rightFieldBound = battleDataProxy:GetFieldBound()
	local allUnits = battleDataProxy:GetUnitList()
	local casterIFF = caster:GetIFF()

	for _, unit in pairs(allUnits) do
		if unit:IsAlive() and unit:GetIFF() ~= casterIFF and rightFieldBound > unit:GetPosition().x and not unit:IsSpectre() then
			targetList[#targetList + 1] = unit
		end
	end

	return targetList
end

--- 目标为所有合法敌方武器目标（不同阵营、非幽灵，不校验存活和场界）
--- @param caster BattleUnit 施法者
--- @return table 合法敌方武器目标列表
function BattleTargetChoise.LegalWeaponTarget(caster)
	local targetList = {}
	local allUnits = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()
	local casterIFF = caster:GetIFF()

	for _, unit in pairs(allUnits) do
		if unit:GetIFF() ~= casterIFF and not unit:IsSpectre() then
			targetList[#targetList + 1] = unit
		end
	end

	return targetList
end
