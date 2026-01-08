ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local ship_data_statistics = pg.ship_data_statistics
local ship_data_template = pg.ship_data_template
local ship_skin_template = pg.ship_skin_template
local enemy_data_statistics = pg.enemy_data_statistics
local weapon_property = pg.weapon_propertyp
local formation_template = pg.formation_template
local auto_pilot_template = pg.auto_pilot_template
local aircraft_template = pg.aircraft_template
local ship_skin_words = pg.ship_skin_words
local equip_data_statistics = pg.equip_data_statistics
local equip_data_template = pg.equip_data_template
local spweapon_data_statistics = pg.spweapon_data_statistics
local enemy_data_skill = pg.enemy_data_skill
local ship_data_personality = pg.ship_data_personality
local enemy_data_by_type = pg.enemy_data_by_type
local ship_data_by_type = pg.ship_data_by_type
local ship_level = pg.ship_level
local skill_data_template = pg.skill_data_template
local ship_data_trans = pg.ship_data_trans
local battle_environment_behaviour_template = pg.battle_environment_behaviour_template
local equip_skin_template = pg.equip_skin_template
local activity_template = pg.activity_template
local activity_event_worldboss = pg.activity_event_worldboss
local world_joint_boss_template = pg.world_joint_boss_template
local world_boss_level = pg.world_boss_level
local guild_boss_event = pg.guild_boss_event
local ship_strengthen_meta = pg.ship_strengthen_meta
local map_data = pg.map_data
local strategy_data_template = pg.strategy_data_template

ys.Battle.BattleDataFunction = ys.Battle.BattleDataFunction or {}

local BattleDataFunction = ys.Battle.BattleDataFunction

-- 被BattleDataProxy.generatePlayerUnit调用
function BattleDataFunction.CreateBattleUnitData(uid, unitType, IFF, monsterTemplateID, skinId, equipmentList, templateData, extraInfo, proficiencyList, baseInfo, preloadInfo, overrideLevel, owner)
	local unit
	local weaponCount

	if unitType == BattleConst.UnitType.PLAYER_UNIT then
		unit = ys.Battle.BattlePlayerUnit.New(uid, IFF)

		unit:SetSkinId(skinId)
		unit:SetWeaponInfo(baseInfo, preloadInfo)
		-- Ship.WEAPON_COUNT = 3
		weaponCount = Ship.WEAPON_COUNT
	elseif unitType == BattleConst.UnitType.SUB_UNIT then
		unit = ys.Battle.BattleSubUnit.New(uid, IFF)

		unit:SetSkinId(skinId)
		unit:SetWeaponInfo(baseInfo, preloadInfo)

		weaponCount = Ship.WEAPON_COUNT
	elseif unitType == BattleConst.UnitType.ENEMY_UNIT then
		unit = ys.Battle.BattleEnemyUnit.New(uid, IFF)

		unit:SetOverrideLevel(overrideLevel)
	elseif unitType == BattleConst.UnitType.MINION_UNIT then
		unit = ys.Battle.BattleMinionUnit.New(uid, IFF)
	elseif unitType == BattleConst.UnitType.BOSS_UNIT then
		unit = ys.Battle.BattleBossUnit.New(uid, IFF)

		unit:SetOverrideLevel(overrideLevel)
	elseif unitType == BattleConst.UnitType.CONST_UNIT then
		unit = ys.Battle.BattleConstPlayerUnit.New(uid, IFF)

		unit:SetSkinId(skinId)
		unit:SetWeaponInfo(baseInfo, preloadInfo)

		weaponCount = Ship.WEAPON_COUNT
	elseif unitType == BattleConst.UnitType.CARDPUZZLE_PLAYER_UNIT then
		unit = ys.Battle.BattleCardPuzzlePlayerUnit.New(uid, IFF)

		unit:SetSkinId(skinId)
		unit:SetWeaponInfo(baseInfo, preloadInfo)
	elseif unitType == BattleConst.UnitType.SUPPORT_UNIT then
		unit = ys.Battle.BattleSupportUnit.New(uid, IFF)

		unit:SetSkinId(skinId)
		unit:SetWeaponInfo(baseInfo, preloadInfo)
	end

	unit:SetTemplate(monsterTemplateID, templateData, extraInfo)

	if unitType == BattleConst.UnitType.MINION_UNIT then
		unit:SetMaster(owner)
		unit:InheritMasterAttr()
	end

	local unitEquipList = {}

	if unitType == BattleConst.UnitType.ENEMY_UNIT or unitType == BattleConst.UnitType.MINION_UNIT or unitType == BattleConst.UnitType.BOSS_UNIT then
		for _, equipmentInfo in ipairs(equipmentList) do
			unitEquipList[#unitEquipList + 1] = {
				equipment = {
					weapon_id = {
						equipmentInfo.id
					}
				}
			}
		end
	else
		for equipIndex, equipmentInfo in ipairs(equipmentList) do
			if not equipmentInfo.id then
				unitEquipList[#unitEquipList + 1] = {
					equipment = false,
					torpedoAmmo = 0,
					skin = equipmentInfo.skin
				}
			else
				local torpedoAmmo = equipmentInfo.equipmentInfo and equipmentInfo.equipmentInfo:getConfig("torpedo_ammo") or 0

				if not weaponCount or equipIndex <= weaponCount or #BattleDataFunction.GetWeaponDataFromID(equipmentInfo.id).weapon_id then
					local equipment = BattleDataFunction.GetWeaponDataFromID(equipmentInfo.id)

					unitEquipList[#unitEquipList + 1] = {
						equipment = equipment,
						skin = equipmentInfo.skin,
						torpedoAmmo = torpedoAmmo
					}
				else
					unitEquipList[#unitEquipList + 1] = {
						equipment = false,
						skin = equipmentInfo.skin,
						torpedoAmmo = torpedoAmmo
					}
				end
			end
		end
	end

	unit:SetProficiencyList(proficiencyList)
	unit:SetEquipment(unitEquipList)

	return unit
end
-- TODO
-- 被BattleDataProxy.generatePlayerUnit调用
function BattleDataFunction.InitUnitSkill(arg_2_0, owner, arg_2_2)
	local skills = arg_2_0.skills or {}

	for _, skill in pairs(skills) do
		local buff = ys.Battle.BattleBuffUnit.New(skill.id, skill.level, owner)

		owner:AddBuff(buff)
	end
end
-- TODO
function BattleDataFunction.GetEquipSkill(arg_3_0, arg_3_1)
	local var_3_0 = Ship.WEAPON_COUNT
	local var_3_1 = {}

	for iter_3_0, iter_3_1 in ipairs(arg_3_0) do
		local var_3_2 = iter_3_1.id

		if var_3_2 then
			local var_3_3
			local var_3_4 = BattleDataFunction.GetWeaponDataFromID(var_3_2)

			if var_3_4 then
				for iter_3_2, iter_3_3 in ipairs(var_3_4.skill_id) do
					local var_3_5 = arg_3_1 and BattleDataFunction.SkillTranform(arg_3_1, iter_3_3[1]) or iter_3_3[1]
					local var_3_6 = iter_3_3[2] or 1
					local var_3_7 = {
						buffID = var_3_5,
						buffLV = var_3_6
					}

					table.insert(var_3_1, var_3_7)
				end

				for iter_3_4, iter_3_5 in ipairs(var_3_4.hidden_skill_id) do
					local var_3_8 = arg_3_1 and BattleDataFunction.SkillTranform(arg_3_1, iter_3_5[1]) or iter_3_5[1]
					local var_3_9 = iter_3_5[2] or 1
					local var_3_10 = {
						buffID = var_3_8,
						buffLV = var_3_9
					}

					table.insert(var_3_1, var_3_10)
				end
			end
		end
	end

	return var_3_1
end

function BattleDataFunction.AttachWeather(arg_4_0, arg_4_1)
	if table.contains(arg_4_1, BattleConst.WEATHER.NIGHT) then
		local var_4_0 = arg_4_0:GetTemplate().type

		if arg_4_0:GetFleetVO() then
			local var_4_1 = arg_4_0:GetFleetVO()

			if table.contains(ShipType.VanguardShipType, var_4_0) then
				local var_4_2 = var_4_1:GetFleetBias()
				local var_4_3 = var_4_2:GetCrewCount() + 1

				var_4_2:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SCOUT[var_4_3])
				var_4_2:AppendCrew(arg_4_0)
			elseif table.contains(ShipType.MainShipType, var_4_0) then
				var_4_1:AttachCloak(arg_4_0)
			elseif table.contains(ShipType.SubShipType, var_4_0) then
				local var_4_4 = ys.Battle.BattleUnitAimBiasComponent.New()

				var_4_4:ConfigRangeFormula(ys.Battle.BattleFormulas.CalculateMaxAimBiasRangeSub, ys.Battle.BattleFormulas.CalculateBiasDecay)
				var_4_4:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SUB)
				var_4_4:AppendCrew(arg_4_0)
				var_4_4:Active(var_4_4.STATE_ACTIVITING)
			end
		elseif arg_4_0:GetUnitType() == BattleConst.UnitType.ENEMY_UNIT or arg_4_0:GetUnitType() == BattleConst.UnitType.MINION_UNIT or arg_4_0:GetUnitType() == BattleConst.UnitType.BOSS_UNIT then
			local var_4_5 = ys.Battle.BattleUnitAimBiasComponent.New()

			var_4_5:ConfigRangeFormula(ys.Battle.BattleFormulas.CalculateMaxAimBiasRangeMonster, ys.Battle.BattleFormulas.CalculateBiasDecayMonster)

			if table.contains(ShipType.SubShipType, var_4_0) then
				var_4_5:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SUB)
			else
				var_4_5:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_MONSTER)
			end

			var_4_5:AppendCrew(arg_4_0)
			var_4_5:SetHostile()
			var_4_5:Active(var_4_5.STATE_SUMMON_SICKNESS)
		end
	end
end

function BattleDataFunction.AttachSmoke(arg_5_0)
	local var_5_0 = arg_5_0:GetUnitType()

	if var_5_0 == BattleConst.UnitType.ENEMY_UNIT or var_5_0 == BattleConst.UnitType.BOSS_UNIT then
		if arg_5_0:GetAimBias() then
			local var_5_1 = arg_5_0:GetAimBias()
			local var_5_2 = var_5_1:GetCurrentState()

			if var_5_2 == var_5_1.STATE_SKILL_EXPOSE then
				var_5_1:SomkeExitResume()
			elseif var_5_2 == var_5_1.STATE_ACTIVITING or var_5_2 == var_5_1.STATE_TOTAL_EXPOSE then
				var_5_1:SmokeRecover()
			end
		else
			local var_5_3 = ys.Battle.BattleUnitAimBiasComponent.New()

			var_5_3:ConfigRangeFormula(ys.Battle.BattleFormulas.CalculateMaxAimBiasRangeMonster, ys.Battle.BattleFormulas.CalculateBiasDecayMonsterInSmoke)

			if table.contains(ShipType.SubShipType, shipType) then
				var_5_3:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SUB)
			else
				var_5_3:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_MONSTER)
			end

			var_5_3:AppendCrew(arg_5_0)
			var_5_3:SetHostile()
			var_5_3:Active(var_5_3.STATE_ACTIVITING)
		end
	end
end

function BattleDataFunction.InitEquipSkill(arg_6_0, arg_6_1, arg_6_2)
	local var_6_0 = BattleDataFunction.GetEquipSkill(arg_6_0, arg_6_2)

	for iter_6_0, iter_6_1 in ipairs(var_6_0) do
		local var_6_1 = ys.Battle.BattleBuffUnit.New(iter_6_1.buffID, iter_6_1.buffLV, arg_6_1)

		arg_6_1:AddBuff(var_6_1)
	end
end

function BattleDataFunction.InitCommanderSkill(arg_7_0, arg_7_1, arg_7_2)
	arg_7_0 = arg_7_0 or {}

	local var_7_0 = ys.Battle.BattleState.GetInstance():GetBattleType()

	for iter_7_0, iter_7_1 in pairs(arg_7_0) do
		local var_7_1 = ys.Battle.BattleDataFunction.GetBuffTemplate(iter_7_1.id, iter_7_1.level).limit
		local var_7_2 = false

		if var_7_1 then
			for iter_7_2, iter_7_3 in ipairs(var_7_1) do
				if var_7_0 == iter_7_3 then
					var_7_2 = true

					break
				end
			end
		end

		if not var_7_2 then
			local var_7_3 = ys.Battle.BattleBuffUnit.New(iter_7_1.id, iter_7_1.level, arg_7_1)

			var_7_3:SetCommander(iter_7_1.commander)
			arg_7_1:AddBuff(var_7_3)
		end
	end
end

function BattleDataFunction.CreateWeaponUnit(weaponId, host, potential, index, weapon_type)
	index = index or -1

	local hostUnitType = host:GetUnitType()
	local weapon
	local weaponTemplate = BattleDataFunction.GetWeaponPropertyDataFromID(weaponId)

	assert(weaponTemplate ~= nil, "找不到武器配置：id = " .. weaponId)

	local weaponType = weapon_type or weaponTemplate.type

	if weaponType == BattleConst.EquipmentType.MAIN_CANNON then
		weapon = ys.Battle.BattleWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.SUB_CANNON then
		weapon = ys.Battle.BattleWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.TORPEDO then
		weapon = ys.Battle.BattleTorpedoUnit.New()
	elseif weaponType == BattleConst.EquipmentType.MANUAL_TORPEDO then
		weapon = ys.Battle.BattleManualTorpedoUnit.New()
	elseif weaponType == BattleConst.EquipmentType.ANTI_AIR then
		weapon = ys.Battle.BattleAntiAirUnit.New()
	elseif weaponType == BattleConst.EquipmentType.FLEET_ANTI_AIR or weaponType == BattleConst.EquipmentType.FLEET_RANGE_ANTI_AIR then
		weapon = ys.Battle.BattleWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or weaponType == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
		if hostUnitType == BattleConst.UnitType.SUPPORT_UNIT then
			weapon = ys.Battle.BattleSupportHiveUnit.New()
		else
			weapon = ys.Battle.BattleHiveUnit.New()
		end
	elseif weaponType == BattleConst.EquipmentType.SPECIAL then
		weapon = ys.Battle.BattleSpecialWeapon.New()
	elseif weaponType == BattleConst.EquipmentType.ANTI_SEA then
		weapon = ys.Battle.BattleDirectHitWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.HAMMER_HEAD then
		weapon = ys.Battle.BattleHammerHeadWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.BOMBER_PRE_CAST_ALERT then
		weapon = ys.Battle.BattleBombWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.POINT_HIT_AND_LOCK or weaponType == BattleConst.EquipmentType.MANUAL_MISSILE or weaponType == BattleConst.EquipmentType.MANUAL_METEOR then
		weapon = ys.Battle.BattlePointHitWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.POINT_AIR_STRIKE then
		weapon = ys.Battle.BattlePointAirStrikeUnit.New()
	elseif weaponType == BattleConst.EquipmentType.BEAM then
		weapon = ys.Battle.BattleLaserUnit.New()
	elseif weaponType == BattleConst.EquipmentType.DEPTH_CHARGE then
		weapon = ys.Battle.BattleDepthChargeUnit.New()
	elseif weaponType == BattleConst.EquipmentType.REPEATER_ANTI_AIR then
		weapon = ys.Battle.BattleRepeaterAntiAirUnit.New()
	elseif weaponType == BattleConst.EquipmentType.DISPOSABLE_TORPEDO then
		weapon = ys.Battle.BattleDisposableTorpedoUnit.New()
	elseif weaponType == BattleConst.EquipmentType.SPACE_LASER then
		weapon = ys.Battle.BattleSpaceLaserWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.MISSILE then
		weapon = ys.Battle.BattleMissileWeaponUnit.New()
	elseif weaponType == BattleConst.EquipmentType.MANUAL_AAMISSILE then
		weapon = ys.Battle.BattleManualAAMissileUnit.New()
	elseif weaponType == BattleConst.EquipmentType.AUTO_MISSILE then
		weapon = ys.Battle.BattleAutoMissileUnit.New()
	end

	assert(weapon ~= nil, "创建武器失败，不存在该类型的武器：id = " .. weaponId)
	weapon:SetPotentialFactor(potential)
	weapon:SetEquipmentIndex(index)
	weapon:SetTemplateData(weaponTemplate)
	weapon:SetHostData(host)

	if hostUnitType == BattleConst.UnitType.PLAYER_UNIT then
		if weaponTemplate.auto_aftercast > 0 then
			weapon:OverrideGCD(weaponTemplate.auto_aftercast)
		end
	elseif hostUnitType == BattleConst.UnitType.ENEMY_UNIT or BattleConst.UnitType.BOSS_UNIT then
		weapon:HostOnEnemy()
	end
	-- 创建时即进入CD
	if weaponTemplate.type == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or weaponTemplate.type == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
		weapon:EnterCoolDown()
	end

	return weapon
end

-- TODO
function BattleDataFunction.CreateAircraftUnit(aircraftUID, aircraftId, mother, potential)
	local aircraft
	local aircraftTemplate = BattleDataFunction.GetAircraftTmpDataFromID(aircraftId)

	assert(aircraftTemplate ~= nil, "找不到飞机配置：id = " .. aircraftId)
	-- 根据类型不同创建不同的飞机单位
	-- 如果有funnel_behavior字段，则创建FunnelUnit
		-- 如果存在hover_range字段，则创建UAVUnit
		-- 如果存在AI字段，则创建PatternFunnelUnit
		-- 否则创建普通FunnelUnit
	-- 否则创建普通AircraftUnit
	if type(aircraftTemplate.funnel_behavior) == "table" then
		if aircraftTemplate.funnel_behavior.hover_range then
			aircraft = ys.Battle.BattleUAVUnit.New(aircraftUID)
		elseif aircraftTemplate.funnel_behavior.AI then
			aircraft = ys.Battle.BattlePatternFunnelUnit.New(aircraftUID)
		else
			aircraft = ys.Battle.BattleFunnelUnit.New(aircraftUID)
		end
	else
		aircraft = ys.Battle.BattleAircraftUnit.New(aircraftUID)
	end

	aircraft:SetMotherUnit(mother)
	aircraft:SetWeanponPotential(potential)
	aircraft:SetTemplate(aircraftTemplate)

	return aircraft
end

function BattleDataFunction.CreateAllInStrike(unit)
	local templateID = unit:GetTemplateID()
	-- ship_data_template
	local shipTemplate = BattleDataFunction.GetPlayerShipModelFromID(templateID)
	local airAssistList = {}

	for index, skillID in ipairs(shipTemplate.airassist_time) do
		local allInStrike = ys.Battle.BattleAllInStrike.New(skillID)

		allInStrike:SetHost(unit)

		airAssistList[index] = allInStrike
	end

	return airAssistList
end

function BattleDataFunction.ExpandAllinStrike(unit)
	local templateID = unit:GetTemplateID()
	local airassist_time = BattleDataFunction.GetPlayerShipModelFromID(templateID).airassist_time

	if #airassist_time > 0 then
		local lastAirAssist = airassist_time[#airassist_time]
		local allInStrike = ys.Battle.BattleAllInStrike.New(lastAirAssist)

		allInStrike:SetHost(unit)
		unit:GetFleetVO():GetAirAssistVO():AppendWeapon(allInStrike)
		allInStrike:OverHeat()
		unit:GetAirAssistQueue():AppendWeapon(allInStrike)

		local airAssistList = unit:GetAirAssistList()

		airAssistList[#airAssistList + 1] = allInStrike
	end
end

function BattleDataFunction.CreateAirFighterUnit(aircraftUID, args)
	local var_12_0
	-- aircraft_template
	local aircraftTemplate = BattleDataFunction.GetAircraftTmpDataFromID(args.templateID)
	local aircraft = ys.Battle.BattleAirFighterUnit.New(aircraftUID)

	aircraft:SetWeaponTemplateID(args.weaponID)
	aircraft:SetBackwardWeaponID(args.backwardWeaponID)
	aircraft:SetTemplate(aircraftTemplate)

	return aircraft
end

function BattleDataFunction.GetPlayerShipTmpDataFromID(arg_13_0)
	assert(ship_data_statistics[arg_13_0] ~= nil, ">>ship_data_statistics<< 找不到玩家船只配置：id = " .. arg_13_0)

	return Clone(ship_data_statistics[arg_13_0])
end

function BattleDataFunction.GetPlayerShipModelFromID(arg_14_0)
	assert(ship_data_template[arg_14_0] ~= nil, ">>ship_data_template<< 找不到玩家船只模组配置：id = " .. arg_14_0)

	return ship_data_template[arg_14_0]
end

function BattleDataFunction.GetPlayerShipSkinDataFromID(arg_15_0)
	assert(ship_skin_template[arg_15_0] ~= nil, ">>ship_skin_template<< 找不到舰娘皮肤配置：id = " .. arg_15_0)

	return ship_skin_template[arg_15_0]
end

function BattleDataFunction.GetShipTypeTmp(arg_16_0)
	assert(ship_data_by_type[arg_16_0] ~= nil, ">>ship_data_by_type<< 找不到舰船类型配置：id = " .. arg_16_0)

	return ship_data_by_type[arg_16_0]
end

function BattleDataFunction.GetMonsterTmpDataFromID(arg_17_0)
	assert(enemy_data_statistics[arg_17_0] ~= nil, ">>enemy_data_statistics<< 找不到敌方船只配置：id = " .. arg_17_0)

	return enemy_data_statistics[arg_17_0]
end

function BattleDataFunction.GetAircraftTmpDataFromID(arg_18_0)
	assert(aircraft_template[arg_18_0] ~= nil, ">>aircraft_template<< 找不到飞机配置：id = " .. arg_18_0)

	return aircraft_template[arg_18_0]
end

function BattleDataFunction.GetWeaponDataFromID(arg_19_0)
	if arg_19_0 ~= Equipment.EQUIPMENT_STATE_EMPTY and arg_19_0 ~= Equipment.EQUIPMENT_STATE_LOCK then
		assert(equip_data_statistics[arg_19_0] ~= nil, ">>equip_data_statistics<< 找不到武器类装备配置：id = " .. arg_19_0)
	end

	return equip_data_statistics[arg_19_0]
end

function BattleDataFunction.GetEquipDataTemplate(arg_20_0)
	assert(equip_data_template[arg_20_0] ~= nil, ">>equip_data_template<< 找不到武器装备模板：id = " .. arg_20_0)

	return equip_data_template[arg_20_0]
end

function BattleDataFunction.GetSpWeaponDataFromID(arg_21_0)
	assert(spweapon_data_statistics[arg_21_0] ~= nil, ">>spweapon_data_statistics<< 找不到特殊兵装配置：id = " .. arg_21_0)

	return spweapon_data_statistics[arg_21_0]
end

function BattleDataFunction.GetWeaponPropertyDataFromID(weaponId)
	assert(weapon_property[weaponId] ~= nil, ">>weapon_property<< 找不到武器行为配置：id = " .. weaponId)

	return weapon_property[weaponId]
end

function BattleDataFunction.GetFormationTmpDataFromID(arg_23_0)
	assert(formation_template[arg_23_0] ~= nil, ">>formation_template<<找不到阵型配置：id = " .. arg_23_0)

	return formation_template[arg_23_0]
end

function BattleDataFunction.GetAITmpDataFromID(arg_24_0)
	assert(auto_pilot_template[arg_24_0] ~= nil, ">>auto_pilot_template<< 找不到移动ai配置：id = " .. arg_24_0)

	return auto_pilot_template[arg_24_0]
end

function BattleDataFunction.GetShipPersonality(arg_25_0)
	assert(ship_data_personality[arg_25_0] ~= nil, ">>shipPersonality<< 找不到性格配置：id = " .. arg_25_0)

	return ship_data_personality[arg_25_0]
end

function BattleDataFunction.GetEnemyTypeDataByType(arg_26_0)
	assert(enemy_data_by_type[arg_26_0] ~= nil, ">>enemy_data_by_type<< 找不到怪物类型：type = " .. arg_26_0)

	return enemy_data_by_type[arg_26_0]
end

function BattleDataFunction.GetArenaBuffByShipType(arg_27_0)
	return BattleDataFunction.GetShipTypeTmp(arg_27_0).arena_buff
end

function BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(arg_28_0, arg_28_1)
	if arg_28_0 == SYSTEM_DUEL then
		assert(ship_level[arg_28_1] ~= nil, ">>ship_level<< 找不到等级配置：level = " .. arg_28_1)

		return ship_level[arg_28_1].arena_durability_ratio, ship_level[arg_28_1].arena_durability_add
	else
		return 1, 0
	end
end

function BattleDataFunction.GetSkillDataTemplate(arg_29_0)
	return skill_data_template[arg_29_0]
end

function BattleDataFunction.GetShipTransformDataTemplate(arg_30_0)
	local var_30_0 = BattleDataFunction.GetPlayerShipModelFromID(arg_30_0)

	return ship_data_trans[var_30_0.group_type]
end

function BattleDataFunction.GetShipMetaFromDataTemplate(arg_31_0)
	local var_31_0 = BattleDataFunction.GetPlayerShipModelFromID(arg_31_0)

	return ship_strengthen_meta[var_31_0.group_type]
end

function BattleDataFunction.GetEquipSkinDataFromID(arg_32_0)
	assert(equip_skin_template[arg_32_0] ~= nil, ">>equip_skin_template<< 找不到装备皮肤配置：id = " .. arg_32_0)

	return equip_skin_template[arg_32_0]
end

function BattleDataFunction.GetEquipSkin(arg_33_0)
	assert(equip_skin_template[arg_33_0] ~= nil, ">>equip_skin_template<< 找不到装备皮肤配置：id = " .. arg_33_0)

	local var_33_0 = equip_skin_template[arg_33_0]

	return var_33_0.bullet_name, var_33_0.derivate_bullet, var_33_0.derivate_torpedo, var_33_0.derivate_boom, var_33_0.fire_fx_name, var_33_0.hit_fx_name
end

function BattleDataFunction.GetEquipSkinSFX(arg_34_0)
	assert(equip_skin_template[arg_34_0] ~= nil, ">>equip_skin_template<< 找不到装备皮肤配置：id = " .. arg_34_0)

	local var_34_0 = equip_skin_template[arg_34_0]

	return var_34_0.hit_sfx, var_34_0.miss_sfx
end

function BattleDataFunction.GetSpecificGuildBossEnemyList(arg_35_0, arg_35_1)
	local var_35_0 = guild_boss_event[arg_35_0].expedition_id
	local var_35_1 = {}

	if var_35_0[1] == arg_35_1 then
		var_35_1 = var_35_0[2]
	end

	return var_35_1
end

function BattleDataFunction.GetSpecificEnemyList(arg_36_0, arg_36_1)
	local var_36_0 = activity_template[arg_36_0]
	local var_36_1 = activity_event_worldboss[var_36_0.config_id].ex_expedition_enemy
	local var_36_2

	for iter_36_0, iter_36_1 in ipairs(var_36_1) do
		if iter_36_1[1] == arg_36_1 then
			var_36_2 = iter_36_1[2]

			break
		end
	end

	return var_36_2
end

function BattleDataFunction.GetMetaBossTemplate(arg_37_0)
	return world_joint_boss_template[arg_37_0]
end

function BattleDataFunction.GetMetaBossLevelTemplate(arg_38_0, arg_38_1)
	local var_38_0 = BattleDataFunction.GetMetaBossTemplate(arg_38_0).boss_level_id + (arg_38_1 - 1)

	return world_boss_level[var_38_0]
end

function BattleDataFunction.GetSpecificWorldJointEnemyList(arg_39_0, arg_39_1, arg_39_2)
	local var_39_0 = BattleDataFunction.GetMetaBossLevelTemplate(arg_39_1, arg_39_2)

	return {
		var_39_0.enemy_id
	}
end

function BattleDataFunction.IncreaseAttributes(arg_40_0, arg_40_1, arg_40_2)
	for iter_40_0, iter_40_1 in ipairs(arg_40_2) do
		if iter_40_1[arg_40_1] ~= nil and type(iter_40_1[arg_40_1]) == "number" then
			arg_40_0 = arg_40_0 + iter_40_1[arg_40_1]
		end
	end
end

-- 舰载机创建的武器
function BattleDataFunction.CreateAirFighterWeaponUnit(weaponId, aircraft, index, potential)
	local weapon
	local weaponTemplate = BattleDataFunction.GetWeaponPropertyDataFromID(weaponId)

	assert(weaponTemplate ~= nil, "找不到武器配置：id = " .. weaponId)

	if weaponTemplate.type == BattleConst.EquipmentType.MAIN_CANNON then
		weapon = ys.Battle.BattleWeaponUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.SUB_CANNON then
		weapon = ys.Battle.BattleWeaponUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.TORPEDO then
		weapon = ys.Battle.BattleTorpedoUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.ANTI_AIR then
		weapon = ys.Battle.BattleAntiAirUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.ANTI_SEA then
		weapon = ys.Battle.BattleDirectHitWeaponUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.HAMMER_HEAD then
		weapon = ys.Battle.BattleHammerHeadWeaponUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.BOMBER_PRE_CAST_ALERT then
		weapon = ys.Battle.BattleBombWeaponUnit.New()
	elseif weaponTemplate.type == BattleConst.EquipmentType.DEPTH_CHARGE then
		weapon = ys.Battle.BattleDepthChargeUnit.New()
	end

	assert(weapon ~= nil, "创建武器失败，不存在该类型的武器：id = " .. weaponId)
	weapon:SetPotentialFactor(potential)

	local template = Clone(weaponTemplate)

	template.spawn_bound = "weapon"

	weapon:SetTemplateData(template)
	weapon:SetHostData(aircraft, index)

	return weapon
end

function BattleDataFunction.GetWords(arg_42_0, arg_42_1, arg_42_2)
	local var_42_0, var_42_1, var_42_2 = ShipWordHelper.GetWordAndCV(arg_42_0, arg_42_1, 1, true, arg_42_2)

	return var_42_2
end
-- TODO
-- 演习/大世界技能转换
function BattleDataFunction.SkillTranform(arg_43_0, arg_43_1)
	local var_43_0 = BattleDataFunction.GetSkillDataTemplate(arg_43_1)

	if not var_43_0 then
		return arg_43_1
	end

	local var_43_1 = var_43_0.system_transform

	if var_43_1[arg_43_0] == nil then
		return arg_43_1
	else
		return var_43_1[arg_43_0]
	end
end

-- TODO
function BattleDataFunction.GenerateHiddenBuff(configId)
	local hide_buff_list = BattleDataFunction.GetPlayerShipModelFromID(configId).hide_buff_list
	local hideBuffList = {}

	for _, hideBuffID in ipairs(hide_buff_list) do
		local hideBuffData = {}

		hideBuffData.level = 1
		hideBuffData.id = hideBuffID
		hideBuffList[hideBuffID] = hideBuffData
	end

	return hideBuffList
end

function BattleDataFunction.GetDivingFilter(arg_45_0)
	return map_data[arg_45_0].diving_filter
end

-- Important: 潜艇PhaseList生成
function BattleDataFunction.GeneratePlayerSubmarinPhase(subAttackBaseLine, subRetreatBaseLine, raidDist, raidDuration, oxyAtkDuration)
	local subAttackLine = subAttackBaseLine - raidDist

	-- Phase 0: SwitchType = POSITION_X_GREATER: 若X > switchParam, to Phase 1
	-- Phase 1: SwitchType = OXYGEN: 若氧气值 < switchParam, to Phase 2
	-- Phase 2: SwitchType = DURATION: 潜艇浮出水面, to Phase 3 after switchParam时间(对应oxyAtkDuration，又对应到模板的attack_duration字段)
	-- Phase 3: SwitchType = POSITION_X_LESSER: 若X < switchParam, to Phase 4
	-- Phase 4: 视为撤退
	return {
		{
			index = 0,
			switchType = 3,
			switchTo = 1,
			switchParam = subAttackLine
		},
		{
			switchParam = 0,
			dive = "STATE_RAID",
			switchTo = 2,
			index = 1,
			switchType = 5
		},
		{
			index = 2,
			switchType = 1,
			switchTo = 3,
			dive = "STATE_FLOAT",
			switchParam = oxyAtkDuration
		},
		{
			index = 3,
			switchType = 4,
			switchTo = 4,
			dive = "STATE_RETREAT",
			switchParam = subRetreatBaseLine
		},
		{
			index = 4,
			retreat = true
		}
	}
end

function BattleDataFunction.GetEnvironmentBehaviour(arg_47_0)
	assert(battle_environment_behaviour_template[arg_47_0] ~= nil, ">>battle_environment_behaviour_template<< 找不到环境行为配置：id = " .. arg_47_0)

	return battle_environment_behaviour_template[arg_47_0]
end

-- 添加驱逐舰的满破加成
function BattleDataFunction.AttachUltimateBonus(playerUnit)
	local shipID = playerUnit:GetTemplateID()

	if not Ship.IsMaxStarByTmpID(shipID) then
		return
	end
	-- ship_data_template
	--- @type table<string>
	local specific_type = BattleDataFunction.GetPlayerShipModelFromID(shipID).specific_type

	for _, specificTypeItem in ipairs(specific_type) do
		if specificTypeItem == ShipType.SpecificTypeTable.gunner then
			BattleAttr.SetCurrent(playerUnit, "barrageCounterMod", BattleConst.UltimateBonus.GunnerCountMod)
		elseif specificTypeItem == ShipType.SpecificTypeTable.torpedo then
			local torpedoBuff = ys.Battle.BattleBuffUnit.New(BattleConst.UltimateBonus.TorpedoBarrageBuff)

			playerUnit:AddBuff(torpedoBuff)
		elseif specificTypeItem == ShipType.SpecificTypeTable.auxiliary then
			BattleDataFunction.AuxBoost(playerUnit)
		end
	end
end

function BattleDataFunction.AuxBoost(playerUnit)
	local equipmentList = playerUnit:GetEquipment()

	for _, equipInfo in ipairs(equipmentList) do
		-- DeviceEquipTypes = {Equipment, AntiSubAircraft, Sonar, Helicopter, Goods}
		if equipInfo and equipInfo.equipment and table.contains(EquipType.DeviceEquipTypes, equipInfo.equipment.type) then
			local equipment = equipInfo.equipment

			for index = 1, 3 do
				local attrName = "attribute_" .. index

				if equipment[attrName] then
					local attrValue = equipment["value_" .. index]
					local battleAttrName = AttributeType.ConvertBattleAttrName(equipment[attrName])
					-- GetBase获得的是不计算战斗内Buff的属性值
					-- 即包含：floor(floor(面板) * (1 + 指挥喵能力加成)) + 装备加成 + 科技加成 + 指挥喵天赋加成
					-- 加成方式是，直接将设备的属性值乘以AuxBoostValue后，直接加到基础属性上
					-- 实际上等价于直接将设备的属性改为原来的(1 + AuxBoostValue)倍
						-- 一个要注意的点是不向下取整
						-- 这和平常稍有不同，因为平常的装备加成这部分都是整数，所以一般Base属性也是整数
						-- 但这里乘以AuxBoostValue后，可能会变成小数
					local newBattleAttrValue = BattleAttr.GetBase(playerUnit, battleAttrName) + attrValue * BattleConst.UltimateBonus.AuxBoostValue

					BattleAttr.SetCurrent(playerUnit, battleAttrName, newBattleAttrValue)
					BattleAttr.SetBaseAttr(playerUnit)
				end
			end
		end
	end
end

function BattleDataFunction.GetSLGStrategyBuffByCombatBuffID(arg_50_0)
	for iter_50_0, iter_50_1 in pairs(strategy_data_template) do
		if iter_50_1.buff_id == arg_50_0 then
			return iter_50_1
		end
	end
end
