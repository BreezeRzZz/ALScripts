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

function BattleDataFunction.GetDungeonTmpDataByID(arg_1_0)
	return require("GameCfg.dungeon." .. arg_1_0)
end

function BattleDataFunction.ClearDungeonCfg(arg_2_0)
	package.loaded["GameCfg.dungeon." .. arg_2_0] = nil
end

function BattleDataFunction.GetSkillTemplate(arg_3_0, arg_3_1)
	arg_3_1 = arg_3_1 or 1

	local var_3_0 = "skill_" .. arg_3_0
	local var_3_1 = pg.ConvertedSkill[var_3_0]
	local var_3_2 = var_3_1[arg_3_1] or var_3_1[0]

	var_3_2.name = getSkillName(arg_3_0)

	return var_3_2
end

function BattleDataFunction.ConvertSkillTemplate()
	pg.ConvertedSkill = {}

	setmetatable(pg.ConvertedSkill, {
		__index = function(arg_5_0, arg_5_1)
			local var_5_0 = arg_5_1
			local var_5_1 = pg.skillCfg[arg_5_1]

			if var_5_1 then
				local var_5_2 = {}
				local var_5_3 = {}

				for iter_5_0, iter_5_1 in pairs(var_5_1) do
					var_5_3[iter_5_0] = Clone(iter_5_1)
				end

				var_5_2[0] = var_5_3

				for iter_5_2, iter_5_3 in ipairs(var_5_1) do
					local var_5_4 = Clone(var_5_3)

					for iter_5_4, iter_5_5 in pairs(iter_5_3) do
						var_5_4[iter_5_4] = iter_5_5
					end

					var_5_2[iter_5_2] = var_5_4
				end

				pg.ConvertedSkill[var_5_0] = var_5_2

				return var_5_2
			end
		end
	})
end

function BattleDataFunction.GetBuffTemplate(buffID, buffLevel)
	buffLevel = buffLevel or 1

	local buffIDString = "buff_" .. buffID
	local levelDataTable = pg.ConvertedBuff[buffIDString]

	return levelDataTable[buffLevel] or levelDataTable[0]
end

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

function BattleDataFunction.GetBuffBulletRes(arg_9_0, arg_9_1, arg_9_2, arg_9_3, arg_9_4)
	local var_9_0 = {}
	local var_9_1 = {}

	arg_9_1 = arg_9_1 or {}

	local var_9_2 = BattleDataFunction.GetPlayerShipModelFromID(arg_9_0)

	local function var_9_3(arg_10_0)
		for iter_10_0, iter_10_1 in ipairs(arg_10_0) do
			local var_10_0

			if arg_9_1[iter_10_1] then
				var_10_0 = arg_9_1[iter_10_1].level
			else
				var_10_0 = 1
			end

			iter_10_1 = arg_9_4 and arg_9_4:RemapSkillId(iter_10_1, true) or iter_10_1

			local var_10_1 = BattleDataFunction.SkillTranform(arg_9_2, iter_10_1)
			local var_10_2 = BattleDataFunction.GetResFromBuff(var_10_1, var_10_0, var_9_1, arg_9_3)

			for iter_10_2, iter_10_3 in ipairs(var_10_2) do
				var_9_0[#var_9_0 + 1] = iter_10_3
			end
		end
	end

	var_9_3(var_9_2.buff_list)
	var_9_3(var_9_2.hide_buff_list)

	local var_9_4 = {}

	for iter_9_0, iter_9_1 in pairs(arg_9_1) do
		table.insert(var_9_4, iter_9_0)
	end

	var_9_3(var_9_4)

	local var_9_5 = var_9_2.airassist_time

	for iter_9_2, iter_9_3 in ipairs(var_9_5) do
		local var_9_6 = BattleDataFunction.GetResFromSkill(iter_9_3, 1, nil, arg_9_3)

		for iter_9_4, iter_9_5 in ipairs(var_9_6) do
			var_9_0[#var_9_0 + 1] = iter_9_5
		end
	end

	local var_9_7 = BattleDataFunction.GetShipTransformDataTemplate(arg_9_0)

	if var_9_7 and var_9_7.skill_id ~= 0 and pg.transform_data_template[var_9_7.skill_id].skill_id ~= 0 then
		local var_9_8 = pg.transform_data_template[var_9_7.skill_id].skill_id
		local var_9_9

		if arg_9_1[var_9_8] then
			var_9_9 = arg_9_1[var_9_8].level
		else
			var_9_9 = 1
		end

		local var_9_10 = BattleDataFunction.GetResFromBuff(var_9_8, var_9_9, var_9_1, arg_9_3)

		for iter_9_6, iter_9_7 in ipairs(var_9_10) do
			var_9_0[#var_9_0 + 1] = iter_9_7
		end
	end

	if BattleDataFunction.GetShipMetaFromDataTemplate(arg_9_0) then
		var_9_3(var_9_2.buff_list_display)
	end

	return var_9_0
end

function BattleDataFunction.getWeaponResource(arg_11_0, arg_11_1)
	local var_11_0 = ys.Battle.BattleResourceManager.GetWeaponResource(arg_11_0)

	for iter_11_0, iter_11_1 in ipairs(var_11_0) do
		arg_11_1[#arg_11_1 + 1] = iter_11_1
	end
end

function BattleDataFunction.GetResFromBuff(arg_12_0, arg_12_1, arg_12_2, arg_12_3)
	local var_12_0 = {}
	local var_12_1 = arg_12_0 .. "_" .. arg_12_1

	if arg_12_2[var_12_1] then
		return var_12_0
	else
		arg_12_2[var_12_1] = true
	end

	local var_12_2 = BattleDataFunction.GetBuffTemplate(arg_12_0, arg_12_1)

	if var_12_2.init_effect and var_12_2.init_effect ~= "" then
		local var_12_3 = var_12_2.init_effect

		if var_12_2.skin_adapt then
			var_12_3 = BattleDataFunction.SkinAdaptFXID(var_12_3, arg_12_3)
		end

		var_12_0[#var_12_0 + 1] = ys.Battle.BattleResourceManager.GetFXPath(var_12_3)
	end

	if var_12_2.last_effect and var_12_2.last_effect ~= "" then
		local var_12_4 = type(var_12_2.last_effect) == "table" and var_12_2.last_effect or {
			var_12_2.last_effect
		}

		for iter_12_0, iter_12_1 in ipairs(var_12_4) do
			var_12_0[#var_12_0 + 1] = ys.Battle.BattleResourceManager.GetFXPath(iter_12_1)
		end
	end

	if var_12_2.last_effect_stack_list then
		for iter_12_2, iter_12_3 in pairs(var_12_2.last_effect_stack_list) do
			var_12_0[#var_12_0 + 1] = ys.Battle.BattleResourceManager.GetFXPath(iter_12_3)
		end
	end

	for iter_12_4, iter_12_5 in ipairs(var_12_2.effect_list) do
		local var_12_5 = iter_12_5.arg_list.skill_id

		if var_12_5 ~= nil then
			local var_12_6 = BattleDataFunction.GetResFromSkill(var_12_5, arg_12_1, arg_12_2, arg_12_3)

			for iter_12_6, iter_12_7 in ipairs(var_12_6) do
				var_12_0[#var_12_0 + 1] = iter_12_7
			end
		end

		local var_12_7 = iter_12_5.arg_list.skill_id_list

		if var_12_7 ~= nil then
			for iter_12_8, iter_12_9 in ipairs(var_12_7) do
				local var_12_8 = BattleDataFunction.GetResFromSkill(iter_12_9, arg_12_1, arg_12_2, arg_12_3)

				for iter_12_10, iter_12_11 in ipairs(var_12_8) do
					var_12_0[#var_12_0 + 1] = iter_12_11
				end
			end
		end

		local var_12_9 = iter_12_5.arg_list.damage_attr_list

		if var_12_9 ~= nil then
			for iter_12_12, iter_12_13 in pairs(var_12_9) do
				local var_12_10 = BattleDataFunction.GetResFromSkill(iter_12_13, arg_12_1, arg_12_2, arg_12_3)

				for iter_12_14, iter_12_15 in ipairs(var_12_10) do
					var_12_0[#var_12_0 + 1] = iter_12_15
				end
			end
		end

		local var_12_11 = iter_12_5.arg_list.bullet_id

		if var_12_11 then
			local var_12_12 = ys.Battle.BattleResourceManager.GetBulletResource(var_12_11)

			for iter_12_16, iter_12_17 in ipairs(var_12_12) do
				var_12_0[#var_12_0 + 1] = iter_12_17
			end
		end

		local var_12_13 = iter_12_5.arg_list.weapon_id

		if var_12_13 then
			BattleDataFunction.getWeaponResource(var_12_13, var_12_0)
		end

		local var_12_14 = iter_12_5.arg_list.aircraft_id_list

		if var_12_14 then
			for iter_12_18, iter_12_19 in ipairs(var_12_14) do
				BattleDataFunction.getWeaponResource(iter_12_19, var_12_0)
			end
		end

		local var_12_15 = iter_12_5.arg_list.skin_id

		if var_12_15 then
			local var_12_16 = ys.Battle.BattleResourceManager.GetEquipSkinBulletRes(var_12_15)

			for iter_12_20, iter_12_21 in ipairs(var_12_16) do
				var_12_0[#var_12_0 + 1] = iter_12_21
			end
		end

		local var_12_17 = iter_12_5.arg_list.ship_skin_id

		if var_12_17 then
			local var_12_18 = BattleDataFunction.GetPlayerShipSkinDataFromID(var_12_17)

			var_12_0[#var_12_0 + 1] = ys.Battle.BattleResourceManager.GetCharacterPath(var_12_18.prefab)
		end

		local var_12_19 = iter_12_5.arg_list.buff_id

		if var_12_19 then
			local var_12_20 = BattleDataFunction.GetResFromBuff(var_12_19, arg_12_1, arg_12_2, arg_12_3)

			for iter_12_22, iter_12_23 in ipairs(var_12_20) do
				if type(iter_12_23) == "string" then
					var_12_0[#var_12_0 + 1] = iter_12_23
				elseif type(iter_12_23) == "table" then
					for iter_12_24, iter_12_25 in ipairs(iter_12_23) do
						var_12_0[#var_12_0 + 1] = iter_12_25
					end
				end
			end
		end

		local var_12_21 = iter_12_5.arg_list.buff_skin_id

		if var_12_21 then
			local var_12_22 = BattleDataFunction.GetResFromBuff(var_12_21, arg_12_1, arg_12_2, arg_12_3)

			for iter_12_26, iter_12_27 in ipairs(var_12_22) do
				if type(iter_12_27) == "string" then
					var_12_0[#var_12_0 + 1] = iter_12_27
				elseif type(iter_12_27) == "table" then
					for iter_12_28, iter_12_29 in ipairs(iter_12_27) do
						var_12_0[#var_12_0 + 1] = iter_12_29
					end
				end
			end
		end

		local var_12_23 = iter_12_5.arg_list.effect

		if var_12_23 then
			var_12_0[#var_12_0 + 1] = ys.Battle.BattleResourceManager.GetFXPath(var_12_23)
		end
	end

	return var_12_0
end

function BattleDataFunction.GetBuffListRes(arg_13_0, arg_13_1, arg_13_2)
	local var_13_0 = {}
	local var_13_1 = {}

	for iter_13_0, iter_13_1 in ipairs(arg_13_0) do
		local var_13_2 = iter_13_1.id
		local var_13_3 = iter_13_1.level

		for iter_13_2, iter_13_3 in ipairs(BattleDataFunction.GetResFromBuff(var_13_2, var_13_3, var_13_1, arg_13_2)) do
			var_13_0[#var_13_0 + 1] = iter_13_3
		end
	end

	return var_13_0
end

function BattleDataFunction.GetResFromSkill(arg_14_0, arg_14_1, arg_14_2, arg_14_3)
	arg_14_1 = arg_14_1 or 1

	local var_14_0 = {}
	local var_14_1 = BattleDataFunction.GetSkillTemplate(arg_14_0, arg_14_1)

	local function var_14_2(arg_15_0)
		for iter_15_0, iter_15_1 in ipairs(arg_15_0) do
			if iter_15_1.type == "BattleBuffShieldWall" then
				print(iter_15_1.arg_list.effect)
			end

			if iter_15_1.type == ys.Battle.BattleSkillGridmanFloat.__name then
				table.insert(var_14_0, "UI/combatgridmanskillfloat")
			end

			if iter_15_1.type == ys.Battle.BattleSkillFusion.__name then
				local var_15_0 = iter_15_1.arg_list
				local var_15_1 = ys.Battle.BattleResourceManager.GetShipResource(var_15_0.fusion_id, var_15_0.ship_skin_id)

				for iter_15_2, iter_15_3 in ipairs(var_15_1) do
					table.insert(var_14_0, iter_15_3)
				end

				local var_15_2 = var_15_0.weapon_id_list

				for iter_15_4, iter_15_5 in ipairs(var_15_2) do
					BattleDataFunction.getWeaponResource(iter_15_5, var_14_0)
				end

				local var_15_3 = var_15_0.buff_list

				for iter_15_6, iter_15_7 in ipairs(var_15_3) do
					local var_15_4 = BattleDataFunction.GetResFromBuff(iter_15_7, arg_14_1, arg_14_2)

					for iter_15_8, iter_15_9 in ipairs(var_15_4) do
						var_14_0[#var_14_0 + 1] = iter_15_9
					end
				end
			end

			local var_15_5 = iter_15_1.arg_list.weapon_id

			if var_15_5 ~= nil then
				BattleDataFunction.getWeaponResource(var_15_5, var_14_0)
			end

			local var_15_6 = iter_15_1.arg_list.buff_id

			if var_15_6 then
				local var_15_7 = BattleDataFunction.GetResFromBuff(var_15_6, arg_14_1, arg_14_2)

				for iter_15_10, iter_15_11 in ipairs(var_15_7) do
					var_14_0[#var_14_0 + 1] = iter_15_11
				end
			end

			local var_15_8 = iter_15_1.arg_list.damage_buff_id

			if var_15_8 then
				local var_15_9 = iter_15_1.arg_list.damage_buff_lv or 1
				local var_15_10 = BattleDataFunction.GetResFromBuff(var_15_8, var_15_9, arg_14_2)

				for iter_15_12, iter_15_13 in ipairs(var_15_10) do
					var_14_0[#var_14_0 + 1] = iter_15_13
				end
			end

			local var_15_11 = iter_15_1.arg_list.effect

			if var_15_11 then
				var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetFXPath(var_15_11)
			end

			local var_15_12 = iter_15_1.arg_list.finale_effect

			if var_15_12 then
				var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetFXPath(var_15_12)
			end

			local var_15_13 = iter_15_1.arg_list.spawnData

			if var_15_13 then
				local var_15_14 = ys.Battle.BattleResourceManager.GetMonsterRes(var_15_13)

				for iter_15_14, iter_15_15 in ipairs(var_15_14) do
					var_14_0[#var_14_0 + 1] = iter_15_15
				end
			end
		end
	end

	if type(var_14_1.painting) == "string" then
		var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetHrzIcon(var_14_1.painting)
		var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetSquareIcon(var_14_1.painting)
	end

	if type(var_14_1.castCV) == "table" then
		ys.Battle.BattleResourceManager.GetInstance():AddPreloadCV(var_14_1.castCV.skinID)
	end

	if var_14_1.focus_duration then
		if var_14_1.cutin_cover then
			var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetInstance().GetPaintingPath(var_14_1.cutin_cover)
		elseif var_14_1.cutin_cover_DAL then
			var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetInstance().GetPaintingPath(var_14_1.cutin_cover_DAL)
			var_14_0[#var_14_0 + 1] = "UI/SkillPaintingDAL"
		elseif arg_14_3 then
			local var_14_3 = BattleDataFunction.GetPlayerShipSkinDataFromID(arg_14_3).painting

			var_14_0[#var_14_0 + 1] = ys.Battle.BattleResourceManager.GetInstance().GetPaintingPath(var_14_3)
		end
	end

	var_14_2(var_14_1.effect_list)

	for iter_14_0, iter_14_1 in ipairs(var_14_1) do
		var_14_2(iter_14_1.effect_list)
	end

	return var_14_0
end

function BattleDataFunction.GetShipSkillTriggerCount(arg_16_0, arg_16_1)
	local function var_16_0(arg_17_0)
		local var_17_0 = 0

		for iter_17_0, iter_17_1 in pairs(arg_17_0) do
			local var_17_1 = BattleDataFunction.GetBuffTemplate(iter_17_1.id).effect_list

			for iter_17_2, iter_17_3 in ipairs(var_17_1) do
				local var_17_2 = iter_17_3.trigger

				for iter_17_4, iter_17_5 in ipairs(var_17_2) do
					if table.contains(arg_16_1, iter_17_5) then
						var_17_0 = var_17_0 + 1
					end
				end
			end
		end

		return var_17_0
	end

	local var_16_1 = 0
	local var_16_2 = arg_16_0.skills or {}
	local var_16_3 = var_16_1 + var_16_0(var_16_2)
	local var_16_4 = BattleDataFunction.GetEquipSkill(arg_16_0.equipment)
	local var_16_5 = {}

	for iter_16_0, iter_16_1 in ipairs(var_16_4) do
		table.insert(var_16_5, {
			id = iter_16_1.buffID
		})
	end

	return var_16_3 + var_16_0(var_16_5)
end

-- BattleDataProxy.initBGM调用
-- 对给定的BuffList，选出与BGM相关的
function BattleDataFunction.GetSongList(buffIDList)
	local songList = {
		initList = {},
		otherList = {}
	}

	for buffID, _ in pairs(buffIDList) do
		local buffTmpData = BattleDataFunction.GetBuffTemplate(buffID, 1)

		for _, effect in ipairs(buffTmpData.effect_list) do
			-- 判定是否为BattleBuffDiva
			if effect.type == ys.Battle.BattleBuffDiva.__name then
				if table.contains(effect.trigger, "onInitGame") then
					for _, bgm in ipairs(effect.arg_list.bgm_list) do
						songList.initList[bgm] = true
					end
				end
				-- 非onInitGame在otherList中
				if not table.contains(effect.trigger, "onInitGame") or #effect.trigger > 1 then
					for _, bgm in ipairs(effect.arg_list.bgm_list) do
						songList.otherList[bgm] = true
					end
				end
			end
		end
	end

	return songList
end

function BattleDataFunction.GetCardRes(arg_19_0)
	local var_19_0 = {}
	local var_19_1 = ys.Battle.BattleCardPuzzleCard.GetCardEffectConfig(arg_19_0)

	for iter_19_0, iter_19_1 in ipairs(var_19_1.effect_list) do
		local var_19_2 = BattleDataFunction.GetCardFXRes(iter_19_1)

		for iter_19_2, iter_19_3 in ipairs(var_19_2) do
			table.insert(var_19_0, iter_19_3)
		end
	end

	for iter_19_4, iter_19_5 in pairs(var_19_1.effect_list) do
		local var_19_3 = BattleDataFunction.GetCardFXRes(iter_19_5)

		for iter_19_6, iter_19_7 in ipairs(var_19_3) do
			table.insert(var_19_0, iter_19_7)
		end
	end

	return var_19_0
end

function BattleDataFunction.GetCardFXRes(arg_20_0)
	local var_20_0 = {}

	for iter_20_0, iter_20_1 in ipairs(arg_20_0) do
		if iter_20_1.type == "BattleCardPuzzleSkillCreateCard" then
			local var_20_1 = BattleDataFunction.GetCardRes(iter_20_1.arg_list.card_id)

			for iter_20_2, iter_20_3 in ipairs(var_20_1) do
				table.insert(var_20_0, iter_20_3)
			end
		elseif iter_20_1.type == "BattleCardPuzzleSkillFire" then
			local var_20_2 = ys.Battle.BattleResourceManager.GetWeaponResource(iter_20_1.arg_list.weapon_id)

			for iter_20_4, iter_20_5 in ipairs(var_20_2) do
				table.insert(var_20_0, iter_20_5)
			end
		elseif iter_20_1.type == "BattleCardPuzzleSkillAddBuff" then
			local var_20_3 = BattleDataFunction.GetResFromBuff(iter_20_1.arg_list.buff_id, 1, {})

			for iter_20_6, iter_20_7 in ipairs(var_20_3) do
				table.insert(var_20_0, iter_20_7)
			end
		end
	end

	return var_20_0
end

function BattleDataFunction.NeedSkillPainting(arg_21_0)
	local var_21_0 = false

	if BattleDataFunction.GetSkillTemplate(arg_21_0).focus_duration then
		var_21_0 = true
	end

	return var_21_0
end

function BattleDataFunction.SkinAdaptFXID(arg_22_0, arg_22_1)
	return arg_22_0 .. "_" .. arg_22_1
end

function BattleDataFunction.GetFleetReload(arg_23_0)
	return BattleFormulas.GetFleetReload(arg_23_0)
end

function BattleDataFunction.GetFleetTorpedoPower(arg_24_0)
	return BattleFormulas.GetFleetTorpedoPower(arg_24_0)
end

-- 被BattleFleetVO.refreshFleetFormation调用
function BattleDataFunction.SortFleetList(currentUnitList, previousUnitList)
	local unitList = {}

	for currentIndex, unit in ipairs(currentUnitList) do
		unitList[#unitList + 1] = previousUnitList[unit]

		unitList[currentIndex]:SetFormationIndex(currentIndex)
	end

	return unitList
end

function BattleDataFunction.GetLimitAttributeRange(arg_26_0, arg_26_1)
	if pg.battle_attribute_range[arg_26_0] then
		return math.clamp(arg_26_1, pg.battle_attribute_range[arg_26_0].min / 10000, pg.battle_attribute_range[arg_26_0].max / 10000)
	end

	return arg_26_1
end

function BattleDataFunction.GetPuzzleCardDataTemplate(arg_27_0)
	assert(puzzle_card_template[arg_27_0] ~= nil, ">>puzzle_card_template<< 找不到卡牌配置：" .. arg_27_0)

	return puzzle_card_template[arg_27_0]
end

function BattleDataFunction.GetPuzzleShipDataTemplate(arg_28_0)
	assert(puzzle_ship_template[arg_28_0] ~= nil, ">>puzzle_ship_template<< 找不到卡牌舰船配置：" .. arg_28_0)

	return puzzle_ship_template[arg_28_0]
end

function BattleDataFunction.GetPuzzleDungeonTemplate(arg_29_0)
	assert(puzzle_combat_template[arg_29_0] ~= nil, ">>puzzle_combat_template<< 找不到卡牌关卡配置：" .. arg_29_0)

	return puzzle_combat_template[arg_29_0]
end

function BattleDataFunction.GetPuzzleCardAffixDataTemplate(arg_30_0)
	assert(puzzle_card_affix[arg_30_0] ~= nil, ">>puzzle_card_affix<< 找不到卡牌关卡配置：" .. arg_30_0)

	return puzzle_card_affix[arg_30_0]
end
