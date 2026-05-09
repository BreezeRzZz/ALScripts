ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas

ys.Battle.BattleDataFunction = ys.Battle.BattleDataFunction or {}

local BattleDataFunction = ys.Battle.BattleDataFunction
local puzzle_card_template = pg.puzzle_card_template
local puzzle_ship_template = pg.puzzle_ship_template
local puzzle_combat_template = pg.puzzle_combat_template
local puzzle_card_affix = pg.puzzle_card_affix

--- 通过地图ID获取地图配置(lazy load)
--- @param dungeonID number 地图ID
--- @return table 地图配置
function BattleDataFunction.GetDungeonTmpDataByID(dungeonID)
	return require("GameCfg.dungeon." .. dungeonID)
end

--- 清除地图配置的缓存
--- @param dungeonID number 地图ID
function BattleDataFunction.ClearDungeonCfg(dungeonID)
	package.loaded["GameCfg.dungeon." .. dungeonID] = nil
end

--- 获取技能模板
--- 利用ConvertedSkill的__index元方法实现lazy load
--- @param skillID number 技能ID
--- @param skillLevel number 技能等级(默认1)
--- @return table 技能模板
function BattleDataFunction.GetSkillTemplate(skillID, skillLevel)
	skillLevel = skillLevel or 1

	local skillIDString = "skill_" .. skillID
	local levelDataTable = pg.ConvertedSkill[skillIDString]
	local skillTemplate = levelDataTable[skillLevel] or levelDataTable[0]

	skillTemplate.name = getSkillName(skillID)

	return skillTemplate
end

--- 将skillCfg转换为ConvertedSkill格式
--- 使用__index元方法实现lazy转换
function BattleDataFunction.ConvertSkillTemplate()
	pg.ConvertedSkill = {}

	setmetatable(pg.ConvertedSkill, {
		__index = function(convertedSkillTable, skillIDString)
			local skillIDKey = skillIDString
			local rawSkillConfig = pg.skillCfg[skillIDString]

			if rawSkillConfig then
				local levelDataTable = {}
				local baseTemplate = {}

				for key, value in pairs(rawSkillConfig) do
					baseTemplate[key] = Clone(value)
				end

				levelDataTable[0] = baseTemplate

				for levelIndex, levelOverrideData in ipairs(rawSkillConfig) do
					local levelFullData = Clone(baseTemplate)

					for overrideKey, overrideValue in pairs(levelOverrideData) do
						levelFullData[overrideKey] = overrideValue
					end

					levelDataTable[levelIndex] = levelFullData
				end

				pg.ConvertedSkill[skillIDKey] = levelDataTable

				return levelDataTable
			end
		end
	})
end

--- 获取Buff模板
--- @param buffID number Buff ID
--- @param buffLevel number Buff等级(默认1)
--- @return table Buff模板
function BattleDataFunction.GetBuffTemplate(buffID, buffLevel)
	buffLevel = buffLevel or 1

	local buffIDString = "buff_" .. buffID
	local levelDataTable = pg.ConvertedBuff[buffIDString]

	return levelDataTable[buffLevel] or levelDataTable[0]
end

--- 将buffCfg转换为ConvertedBuff格式
--- 使用__index元方法实现lazy转换
function BattleDataFunction.ConvertBuffTemplate()
	pg.ConvertedBuff = {}

	setmetatable(pg.ConvertedBuff, {
		__index = function(convertedBuffTable, buffIDString)
			local buffIDKey = buffIDString
			local rawBuffConfig = pg.buffCfg[buffIDString]

			if rawBuffConfig then
				local levelDataTable = {}
				local baseTemplate = {}

				for key, value in pairs(rawBuffConfig) do
					baseTemplate[key] = Clone(value)
				end

				levelDataTable[0] = baseTemplate

				for levelIndex, levelOverrideData in ipairs(rawBuffConfig) do
					local levelFullData = Clone(baseTemplate)
					-- 这里一般来说，overrideKey只有"effect_list"一个键
					-- overrideValue则是这个等级的effect_list表
					for overrideKey, overrideValue in pairs(levelOverrideData) do
						levelFullData[overrideKey] = overrideValue
					end

					levelDataTable[levelIndex] = levelFullData
				end

				pg.ConvertedBuff[buffIDKey] = levelDataTable

				return levelDataTable
			end
		end
	})
end

--- 获取Buff所需的子弹/特效资源列表
--- 递归遍历Buff及其引用的技能，收集所有需要的资源路径
--- @param shipConfigID number 舰船配置ID
--- @param equipSkillMap table 装备技能映射 {[skillID] = {level = N}}
--- @param system any 战斗系统类型(用于SkillTranform)
--- @param skinID number 皮肤ID(用于SkinAdapt)
--- @param shipTransformUnit BattleUnit|nil 舰船变换单位(用于Remap)
--- @return table 资源路径列表
function BattleDataFunction.GetBuffBulletRes(shipConfigID, equipSkillMap, system, skinID, shipTransformUnit)
	local resList = {}
	local visitedBuffSet = {}

	equipSkillMap = equipSkillMap or {}

	local shipTemplate = BattleDataFunction.GetPlayerShipModelFromID(shipConfigID)

	--- 对技能ID进行重映射（变形/隐藏技能处理）
	local function remapSkillID(skillID)
		if not shipTransformUnit then
			return skillID
		end

		if table.contains(shipTemplate.hide_buff_list, skillID) then
			return shipTransformUnit:RemapHiddenSkillId(skillID)
		end

		local remapResult = shipTransformUnit:RemapHiddenSkillId(skillID)

		if remapResult == skillID then
			remapResult = shipTransformUnit:RemapSkillId(skillID)
		end

		return remapResult
	end

	--- 处理技能ID列表，收集对应Buff的资源
	local function processSkillIDList(skillIDList)
		for _, skillID in ipairs(skillIDList) do
			local skillLevel

			if equipSkillMap[skillID] then
				skillLevel = equipSkillMap[skillID].level
			else
				skillLevel = 1
			end

			skillID = remapSkillID(skillID)

			local transformedSkillID = BattleDataFunction.SkillTranform(system, skillID)
			local skillResources = BattleDataFunction.GetResFromBuff(transformedSkillID, skillLevel, visitedBuffSet, skinID)

			for _, resource in ipairs(skillResources) do
				resList[#resList + 1] = resource
			end
		end
	end

	processSkillIDList(shipTemplate.buff_list)
	processSkillIDList(shipTemplate.hide_buff_list)

	local equipSkillIDs = {}

	for equipSkillID, _ in pairs(equipSkillMap) do
		table.insert(equipSkillIDs, equipSkillID)
	end

	processSkillIDList(equipSkillIDs)

	-- 空袭时刻技能资源
	local airassistTimeList = shipTemplate.airassist_time

	for _, skillID in ipairs(airassistTimeList) do
		local airAssistResources = BattleDataFunction.GetResFromSkill(skillID, 1, nil, skinID)

		for _, resource in ipairs(airAssistResources) do
			resList[#resList + 1] = resource
		end
	end

	-- 舰船变换技能资源（如μ兵装等）
	local shipTransformData = BattleDataFunction.GetShipTransformDataTemplate(shipConfigID)

	if shipTransformData and shipTransformData.skill_id ~= 0 and pg.transform_data_template[shipTransformData.skill_id].skill_id ~= 0 then
		local transformSkillID = pg.transform_data_template[shipTransformData.skill_id].skill_id
		local transformSkillLevel

		if equipSkillMap[transformSkillID] then
			transformSkillLevel = equipSkillMap[transformSkillID].level
		else
			transformSkillLevel = 1
		end

		local transformSkillResources = BattleDataFunction.GetResFromBuff(transformSkillID, transformSkillLevel, visitedBuffSet, skinID)

		for _, resource in ipairs(transformSkillResources) do
			resList[#resList + 1] = resource
		end
	end

	if BattleDataFunction.GetShipMetaFromDataTemplate(shipConfigID) then
		processSkillIDList(shipTemplate.buff_list_display)
	end

	return resList
end

--- 获取武器资源并追加到目标列表
--- @param weaponID number 武器ID
--- @param resourceList table 资源列表(会被修改)
function BattleDataFunction.getWeaponResource(weaponID, resourceList)
	local weaponResources = ys.Battle.BattleResourceManager.GetWeaponResource(weaponID)

	for _, resource in ipairs(weaponResources) do
		resourceList[#resourceList + 1] = resource
	end
end

--- 从Buff模板递归收集所有需要的资源
--- @param buffID number Buff ID
--- @param buffLevel number Buff等级
--- @param visitedBuffSet table 已访问的Buff集合(防循环)
--- @param skinAdaptID number 皮肤适配ID
--- @return table 资源路径列表
function BattleDataFunction.GetResFromBuff(buffID, buffLevel, visitedBuffSet, skinAdaptID)
	local resList = {}
	local visitedKey = buffID .. "_" .. buffLevel

	if visitedBuffSet[visitedKey] then
		return resList
	else
		visitedBuffSet[visitedKey] = true
	end

	local buffTemplate = BattleDataFunction.GetBuffTemplate(buffID, buffLevel)

	if buffTemplate.init_effect and buffTemplate.init_effect ~= "" then
		local initEffectFXID = buffTemplate.init_effect

		if buffTemplate.skin_adapt then
			initEffectFXID = BattleDataFunction.SkinAdaptFXID(initEffectFXID, skinAdaptID)
		end

		resList[#resList + 1] = ys.Battle.BattleResourceManager.GetFXPath(initEffectFXID)
	end

	if buffTemplate.last_effect and buffTemplate.last_effect ~= "" then
		local lastEffectFXList = type(buffTemplate.last_effect) == "table" and buffTemplate.last_effect or {
			buffTemplate.last_effect
		}

		for _, fxID in ipairs(lastEffectFXList) do
			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetFXPath(fxID)
		end
	end

	if buffTemplate.last_effect_stack_list then
		for _, fxID in pairs(buffTemplate.last_effect_stack_list) do
			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetFXPath(fxID)
		end
	end

	for _, effectItem in ipairs(buffTemplate.effect_list) do
		local buffEffectSkillID = effectItem.arg_list.skill_id

		if buffEffectSkillID ~= nil then
			local skillResources = BattleDataFunction.GetResFromSkill(buffEffectSkillID, buffLevel, visitedBuffSet, skinAdaptID)

			for _, resource in ipairs(skillResources) do
				resList[#resList + 1] = resource
			end
		end

		local buffEffectSkillIDList = effectItem.arg_list.skill_id_list

		if buffEffectSkillIDList ~= nil then
			for _, skillID in ipairs(buffEffectSkillIDList) do
				local skillIDListResources = BattleDataFunction.GetResFromSkill(skillID, buffLevel, visitedBuffSet, skinAdaptID)

				for _, resource in ipairs(skillIDListResources) do
					resList[#resList + 1] = resource
				end
			end
		end

		local damageAttrList = effectItem.arg_list.damage_attr_list

		if damageAttrList ~= nil then
			for _, damageAttrSkillID in pairs(damageAttrList) do
				local damageAttrResources = BattleDataFunction.GetResFromSkill(damageAttrSkillID, buffLevel, visitedBuffSet, skinAdaptID)

				for _, resource in ipairs(damageAttrResources) do
					resList[#resList + 1] = resource
				end
			end
		end

		local bulletID = effectItem.arg_list.bullet_id

		if bulletID then
			local bulletResources = ys.Battle.BattleResourceManager.GetBulletResource(bulletID)

			for _, resource in ipairs(bulletResources) do
				resList[#resList + 1] = resource
			end
		end

		local weaponID = effectItem.arg_list.weapon_id

		if weaponID then
			BattleDataFunction.getWeaponResource(weaponID, resList)
		end

		local aircraftIDList = effectItem.arg_list.aircraft_id_list

		if aircraftIDList then
			for _, aircraftID in ipairs(aircraftIDList) do
				BattleDataFunction.getWeaponResource(aircraftID, resList)
			end
		end

		local skinID = effectItem.arg_list.skin_id

		if skinID then
			local equipSkinBulletRes = ys.Battle.BattleResourceManager.GetEquipSkinBulletRes(skinID)

			for _, resource in ipairs(equipSkinBulletRes) do
				resList[#resList + 1] = resource
			end
		end

		local shipSkinID = effectItem.arg_list.ship_skin_id

		if shipSkinID then
			local shipSkinData = BattleDataFunction.GetPlayerShipSkinDataFromID(shipSkinID)

			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetCharacterPath(shipSkinData.prefab)
		end

		local buffIDInEffect = effectItem.arg_list.buff_id

		if buffIDInEffect then
			local buffIDInEffectResources = BattleDataFunction.GetResFromBuff(buffIDInEffect, buffLevel, visitedBuffSet, skinAdaptID)

			for _, resource in ipairs(buffIDInEffectResources) do
				if type(resource) == "string" then
					resList[#resList + 1] = resource
				elseif type(resource) == "table" then
					for _, innerResource in ipairs(resource) do
						resList[#resList + 1] = innerResource
					end
				end
			end
		end

		local buffSkinID = effectItem.arg_list.buff_skin_id

		if buffSkinID then
			local buffSkinIDResources = BattleDataFunction.GetResFromBuff(buffSkinID, buffLevel, visitedBuffSet, skinAdaptID)

			for _, resource in ipairs(buffSkinIDResources) do
				if type(resource) == "string" then
					resList[#resList + 1] = resource
				elseif type(resource) == "table" then
					for _, innerResource in ipairs(resource) do
						resList[#resList + 1] = innerResource
					end
				end
			end
		end

		local effectFXID = effectItem.arg_list.effect

		if effectFXID then
			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetFXPath(effectFXID)
		end
	end

	return resList
end

--- 获取Buff列表的资源
--- @param buffInfoList table Buff信息列表 [{{id=..., level=...}, ...}]
--- @param visitedBuffSet table 已访问的Buff集合
--- @param skinID number 皮肤ID
--- @return table 资源路径列表
function BattleDataFunction.GetBuffListRes(buffInfoList, visitedBuffSet, skinID)
	local resList = {}
	local localVisitedBuffSet = {}

	for _, buffInfo in ipairs(buffInfoList) do
		local buffID = buffInfo.id
		local buffLevel = buffInfo.level

		for _, resource in ipairs(BattleDataFunction.GetResFromBuff(buffID, buffLevel, localVisitedBuffSet, skinID)) do
			resList[#resList + 1] = resource
		end
	end

	return resList
end

--- 从技能模板收集所有需要的资源（立绘、特效、武器等）
--- @param skillID number 技能ID
--- @param skillLevel number 技能等级(默认1)
--- @param visitedBuffSet table 已访问的Buff集合
--- @param skinAdaptID number 皮肤适配ID
--- @return table 资源路径列表
function BattleDataFunction.GetResFromSkill(skillID, skillLevel, visitedBuffSet, skinAdaptID)
	skillLevel = skillLevel or 1

	local resList = {}
	local skillTemplate = BattleDataFunction.GetSkillTemplate(skillID, skillLevel)

	--- 处理effect_list中的effect，递归收集资源
	local function processEffectList(effectList)
		for _, effectItem in ipairs(effectList) do
			if effectItem.type == "BattleBuffShieldWall" then
				print(effectItem.arg_list.effect)
			end

			if effectItem.type == ys.Battle.BattleSkillGridmanFloat.__name then
				table.insert(resList, "UI/combatgridmanskillfloat")
			end

			if effectItem.type == ys.Battle.BattleSkillFusion.__name then
				local fusionArgList = effectItem.arg_list
				local shipResources = ys.Battle.BattleResourceManager.GetShipResource(fusionArgList.fusion_id, fusionArgList.ship_skin_id)

				for _, resource in ipairs(shipResources) do
					table.insert(resList, resource)
				end

				local fusionWeaponIDList = fusionArgList.weapon_id_list

				for _, weaponID in ipairs(fusionWeaponIDList) do
					BattleDataFunction.getWeaponResource(weaponID, resList)
				end

				local fusionBuffList = fusionArgList.buff_list

				for _, buffID in ipairs(fusionBuffList) do
					local buffResources = BattleDataFunction.GetResFromBuff(buffID, skillLevel, visitedBuffSet)

					for _, resource in ipairs(buffResources) do
						resList[#resList + 1] = resource
					end
				end
			end

			local effectWeaponID = effectItem.arg_list.weapon_id

			if effectWeaponID ~= nil then
				BattleDataFunction.getWeaponResource(effectWeaponID, resList)
			end

			local effectBuffID = effectItem.arg_list.buff_id

			if effectBuffID then
				local buffResources = BattleDataFunction.GetResFromBuff(effectBuffID, skillLevel, visitedBuffSet)

				for _, resource in ipairs(buffResources) do
					resList[#resList + 1] = resource
				end
			end

			local damageBuffID = effectItem.arg_list.damage_buff_id

			if damageBuffID then
				local damageBuffLevel = effectItem.arg_list.damage_buff_lv or 1
				local damageBuffResources = BattleDataFunction.GetResFromBuff(damageBuffID, damageBuffLevel, visitedBuffSet)

				for _, resource in ipairs(damageBuffResources) do
					resList[#resList + 1] = resource
				end
			end

			local effectFXID = effectItem.arg_list.effect

			if effectFXID then
				resList[#resList + 1] = ys.Battle.BattleResourceManager.GetFXPath(effectFXID)
			end

			local finaleEffectFXID = effectItem.arg_list.finale_effect

			if finaleEffectFXID then
				resList[#resList + 1] = ys.Battle.BattleResourceManager.GetFXPath(finaleEffectFXID)
			end

			local spawnData = effectItem.arg_list.spawnData

			if spawnData then
				local monsterResources = ys.Battle.BattleResourceManager.GetMonsterRes(spawnData)

				for _, resource in ipairs(monsterResources) do
					resList[#resList + 1] = resource
				end
			end
		end
	end

	if type(skillTemplate.painting) == "string" then
		resList[#resList + 1] = ys.Battle.BattleResourceManager.GetHrzIcon(skillTemplate.painting)
		resList[#resList + 1] = ys.Battle.BattleResourceManager.GetSquareIcon(skillTemplate.painting)
	end

	if type(skillTemplate.castCV) == "table" then
		ys.Battle.BattleResourceManager.GetInstance():AddPreloadCV(skillTemplate.castCV.skinID)
	end

	if skillTemplate.focus_duration then
		if skillTemplate.cutin_cover then
			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetInstance().GetPaintingPath(skillTemplate.cutin_cover)
		elseif skillTemplate.cutin_cover_DAL then
			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetInstance().GetPaintingPath(skillTemplate.cutin_cover_DAL)
			resList[#resList + 1] = "UI/SkillPaintingDAL"
		elseif skinAdaptID then
			local paintingName = BattleDataFunction.GetPlayerShipSkinDataFromID(skinAdaptID).painting

			resList[#resList + 1] = ys.Battle.BattleResourceManager.GetInstance().GetPaintingPath(paintingName)
		end
	end

	processEffectList(skillTemplate.effect_list)

	for _, levelData in ipairs(skillTemplate) do
		processEffectList(levelData.effect_list)
	end

	return resList
end

--- 获取舰船技能触发次数统计
--- 遍历舰船的技能和装备Buff，统计匹配trigger的次数
--- @param unitDataTemplate table 单位数据模板
--- @param triggerList table 需要匹配的trigger列表
--- @return number 匹配的触发次数
function BattleDataFunction.GetShipSkillTriggerCount(unitDataTemplate, triggerList)
	--- 统计技能列表中匹配trigger的次数
	local function countTriggerMatches(skillBuffList)
		local matchCount = 0

		for _, buffInfo in pairs(skillBuffList) do
			local effectList = BattleDataFunction.GetBuffTemplate(buffInfo.id).effect_list

			for _, effectItem in ipairs(effectList) do
				local triggerList_inEffect = effectItem.trigger

				for _, triggerType in ipairs(triggerList_inEffect) do
					if table.contains(triggerList, triggerType) then
						matchCount = matchCount + 1
					end
				end
			end
		end

		return matchCount
	end

	local baseTriggerCount = 0
	local skillList = unitDataTemplate.skills or {}
	local totalTriggerCount = baseTriggerCount + countTriggerMatches(skillList)
	local equipSkillInfoList = BattleDataFunction.GetEquipSkill(unitDataTemplate.equipment)
	local equipBuffInfoList = {}

	for _, equipSkillInfo in ipairs(equipSkillInfoList) do
		table.insert(equipBuffInfoList, {
			id = equipSkillInfo.buffID
		})
	end

	return totalTriggerCount + countTriggerMatches(equipBuffInfoList)
end

--- 获取歌曲列表（Diva系统的BGM）
--- @param buffMap table Buff映射表
--- @return table {initList = {...}, otherList = {...}}
function BattleDataFunction.GetSongList(buffMap)
	local songData = {
		initList = {},
		otherList = {}
	}

	for buffID, _ in pairs(buffMap) do
		local buffTemplate = BattleDataFunction.GetBuffTemplate(buffID, 1)

		for _, effectItem in ipairs(buffTemplate.effect_list) do
			if effectItem.type == ys.Battle.BattleBuffDiva.__name then
				if table.contains(effectItem.trigger, "onInitGame") then
					for _, bgmName in ipairs(effectItem.arg_list.bgm_list) do
						songData.initList[bgmName] = true
					end
				end

				if not table.contains(effectItem.trigger, "onInitGame") or #effectItem.trigger > 1 then
					for _, bgmName in ipairs(effectItem.arg_list.bgm_list) do
						songData.otherList[bgmName] = true
					end
				end
			end
		end
	end

	return songData
end

--- 获取卡牌资源（卡牌谜题系统）
--- @param cardID number 卡牌ID
--- @return table 资源路径列表
function BattleDataFunction.GetCardRes(cardID)
	local resList = {}
	local cardEffectConfig = ys.Battle.BattleCardPuzzleCard.GetCardEffectConfig(cardID)

	for _, effectItem in ipairs(cardEffectConfig.effect_list) do
		local cardFXResources = BattleDataFunction.GetCardFXRes(effectItem)

		for _, resource in ipairs(cardFXResources) do
			table.insert(resList, resource)
		end
	end

	for _, effectItem in pairs(cardEffectConfig.effect_list) do
		local cardFXResources = BattleDataFunction.GetCardFXRes(effectItem)

		for _, resource in ipairs(cardFXResources) do
			table.insert(resList, resource)
		end
	end

	return resList
end

--- 获取卡牌特效资源
--- @param effectItemList table 特效列表
--- @return table 资源路径列表
function BattleDataFunction.GetCardFXRes(effectItemList)
	local resList = {}

	for _, effectItem in ipairs(effectItemList) do
		if effectItem.type == "BattleCardPuzzleSkillCreateCard" then
			local cardResources = BattleDataFunction.GetCardRes(effectItem.arg_list.card_id)

			for _, resource in ipairs(cardResources) do
				table.insert(resList, resource)
			end
		elseif effectItem.type == "BattleCardPuzzleSkillFire" then
			local weaponResources = ys.Battle.BattleResourceManager.GetWeaponResource(effectItem.arg_list.weapon_id)

			for _, resource in ipairs(weaponResources) do
				table.insert(resList, resource)
			end
		elseif effectItem.type == "BattleCardPuzzleSkillAddBuff" then
			local buffResources = BattleDataFunction.GetResFromBuff(effectItem.arg_list.buff_id, 1, {})

			for _, resource in ipairs(buffResources) do
				table.insert(resList, resource)
			end
		end
	end

	return resList
end

--- 判断技能是否需要切入立绘
--- @param skillID number 技能ID
--- @return boolean
function BattleDataFunction.NeedSkillPainting(skillID)
	local needPainting = false

	if BattleDataFunction.GetSkillTemplate(skillID).focus_duration then
		needPainting = true
	end

	return needPainting
end

--- 皮肤适配特效ID
--- @param fxID string 特效ID
--- @param skinID number 皮肤ID
--- @return string 适配后的特效ID
function BattleDataFunction.SkinAdaptFXID(fxID, skinID)
	return fxID .. "_" .. skinID
end

--- 获取舰队装填值
--- @param fleetVO BattleFleetVO
--- @return number
function BattleDataFunction.GetFleetReload(fleetVO)
	return BattleFormulas.GetFleetReload(fleetVO)
end

--- 获取舰队鱼雷总威力
--- @param fleetVO BattleFleetVO
--- @return number
function BattleDataFunction.GetFleetTorpedoPower(fleetVO)
	return BattleFormulas.GetFleetTorpedoPower(fleetVO)
end

--- 按指定顺序重新排列舰队列表
--- 用于refreshFleetFormation中根据索引列表重新排序unitList
--- @param indexList table 目标索引顺序
--- @param unitList table 单位列表
--- @return table 排序后的单位列表
function BattleDataFunction.SortFleetList(indexList, unitList)
	local sortedUnitList = {}

	for newIndex, oldIndex in ipairs(indexList) do
		sortedUnitList[#sortedUnitList + 1] = unitList[oldIndex]

		sortedUnitList[newIndex]:SetFormationIndex(newIndex)
	end

	return sortedUnitList
end

--- 获取属性限制范围
--- 从battle_attribute_range配置获取属性的最小/最大值限制
--- @param attrName string 属性名
--- @param attrValue number 属性值
--- @return number 限制后的属性值
function BattleDataFunction.GetLimitAttributeRange(attrName, attrValue)
	if pg.battle_attribute_range[attrName] then
		return math.clamp(attrValue, pg.battle_attribute_range[attrName].min / 10000, pg.battle_attribute_range[attrName].max / 10000)
	end

	return attrValue
end

--- 获取卡牌谜题卡牌模板
--- @param cardID number
--- @return table
function BattleDataFunction.GetPuzzleCardDataTemplate(cardID)
	assert(puzzle_card_template[cardID] ~= nil, ">>puzzle_card_template<< 找不到卡牌配置：" .. cardID)

	return puzzle_card_template[cardID]
end

--- 获取卡牌谜题舰船模板
--- @param shipID number
--- @return table
function BattleDataFunction.GetPuzzleShipDataTemplate(shipID)
	assert(puzzle_ship_template[shipID] ~= nil, ">>puzzle_ship_template<< 找不到卡牌舰船配置：" .. shipID)

	return puzzle_ship_template[shipID]
end

--- 获取卡牌谜题关卡模板
--- @param dungeonID number
--- @return table
function BattleDataFunction.GetPuzzleDungeonTemplate(dungeonID)
	assert(puzzle_combat_template[dungeonID] ~= nil, ">>puzzle_combat_template<< 找不到卡牌关卡配置：" .. dungeonID)

	return puzzle_combat_template[dungeonID]
end

--- 获取卡牌谜题副属性模板
--- @param affixID number
--- @return table
function BattleDataFunction.GetPuzzleCardAffixDataTemplate(affixID)
	assert(puzzle_card_affix[affixID] ~= nil, ">>puzzle_card_affix<< 找不到卡牌关卡配置：" .. affixID)

	return puzzle_card_affix[affixID]
end
