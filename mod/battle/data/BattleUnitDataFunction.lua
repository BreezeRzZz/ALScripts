ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local ship_data_statistics = pg.ship_data_statistics
local ship_data_template = pg.ship_data_template
local ship_skin_template = pg.ship_skin_template
local enemy_data_statistics = pg.enemy_data_statistics
local weapon_property = pg.weapon_property
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

--- 创建战斗单位的主要工厂函数
--- 根据unitType创建不同类型的战斗单位，并设置装备、皮肤等信息
--- 被BattleDataProxy.generatePlayerUnit调用
--- @param uid number 单位唯一ID
--- @param unitType number 单位类型 (UnitType)
--- @param IFF number 敌我识别 (FRIENDLY_CODE/FOE_CODE)
--- @param monsterTemplateID number 敌方/模板ID
--- @param skinId number 皮肤ID
--- @param equipmentList table 装备列表
--- @param templateData table 模板数据
--- @param extraInfo table 额外信息
--- @param proficiencyList table 熟练度列表
--- @param baseInfo table 基础信息
--- @param preloadInfo table 预载信息
--- @param overrideLevel number 覆盖等级
--- @param owner BattleUnit 拥有者(如Minion的Master)
--- @return BattleUnit
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

--- 初始化单位Buff
--- unitData.skills的来源是BattleMediator.GenBattleData里的skills字段
--- 被BattleDataProxy.generatePlayerUnit调用
--- @param unitData table 单位数据(含skills字段)
--- @param owner BattleUnit Buff的拥有者
--- @param battleType any 战斗类型(未在函数内使用，仅为接口一致保留)
function BattleDataFunction.InitUnitSkill(unitData, owner, battleType)
	local skills = unitData.skills or {}

	for _, skill in pairs(skills) do
		local buff = ys.Battle.BattleBuffUnit.New(skill.id, skill.level, owner)

		owner:AddBuff(buff)
	end
end

--- 初始化装备的Buff
--- 从equip_data_statistics的skill_id/hidden_skill_id字段提取Buff信息
--- 被BattleDataFunction.InitEquipSkill调用
--- @param equipmentInfoList table 装备信息列表
--- @param playerUnit BattleUnit|nil 玩家单位(用于SkillTranform)
--- @return table Buff信息列表 [{{buffID=..., buffLV=...}, ...}]
function BattleDataFunction.GetEquipSkill(equipmentInfoList, playerUnit)
	-- WEAPON_COUNT = 3
	local WEAPON_COUNT = Ship.WEAPON_COUNT
	local buffInfoList = {}

	for _, equipmentInfo in ipairs(equipmentInfoList) do
		local equipID = equipmentInfo.id

		if equipID then
			-- 实际是从equip_data_statistics里拿数据
			local equipTempData = BattleDataFunction.GetWeaponDataFromID(equipID)

			if equipTempData then
				for _, skillIDPair in ipairs(equipTempData.skill_id) do
					-- 进行battleType转换
					local actualBuffID = playerUnit and BattleDataFunction.SkillTranform(playerUnit, skillIDPair[1]) or skillIDPair[1]
					local buffLV = skillIDPair[2] or 1
					local buffInfo = {
						buffID = actualBuffID,
						buffLV = buffLV
					}

					table.insert(buffInfoList, buffInfo)
				end

				for _, skillIDPair in ipairs(equipTempData.hidden_skill_id) do
					local actualBuffID = playerUnit and BattleDataFunction.SkillTranform(playerUnit, skillIDPair[1]) or skillIDPair[1]
					local buffLV = skillIDPair[2] or 1
					local buffInfo = {
						buffID = actualBuffID,
						buffLV = buffLV
					}

					table.insert(buffInfoList, buffInfo)
				end
			end
		end
	end

	return buffInfoList
end

--- 在BattleDataProxy的各个SpawnXXX和generatePlayerUnit里调用
--- 用于根据天气等环境因素给单位添加Buff（夜间隐蔽、瞄准偏移等）
--- @param unit BattleUnit
--- @param weather table 天气列表
function BattleDataFunction.AttachWeather(unit, weather)
	if table.contains(weather, BattleConst.WEATHER.NIGHT) then
		local unitShipType = unit:GetTemplate().type

		if unit:GetFleetVO() then
			local fleetVO = unit:GetFleetVO()
			-- 如果是前排，作为crew
			-- crew的整体挂载一个偏移组件
			if table.contains(ShipType.VanguardShipType, unitShipType) then
				local fleetBias = fleetVO:GetFleetBias()
				local crewCount = fleetBias:GetCrewCount() + 1

				fleetBias:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SCOUT[crewCount])
				fleetBias:AppendCrew(unit)
			elseif table.contains(ShipType.MainShipType, unitShipType) then
				fleetVO:AttachCloak(unit)
			elseif table.contains(ShipType.SubShipType, unitShipType) then
				-- 潜艇每个单位独立挂载一个偏移组件
				local aimBiasComponent = ys.Battle.BattleUnitAimBiasComponent.New()

				aimBiasComponent:ConfigRangeFormula(ys.Battle.BattleFormulas.CalculateMaxAimBiasRangeSub, ys.Battle.BattleFormulas.CalculateBiasDecay)
				aimBiasComponent:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SUB)
				aimBiasComponent:AppendCrew(unit)
				aimBiasComponent:Active(aimBiasComponent.STATE_ACTIVITING)
			end
		elseif unit:GetUnitType() == BattleConst.UnitType.ENEMY_UNIT or unit:GetUnitType() == BattleConst.UnitType.MINION_UNIT or unit:GetUnitType() == BattleConst.UnitType.BOSS_UNIT then
			-- 敌人也是每个单位独立挂载一个偏移组件
			local aimBiasComponent = ys.Battle.BattleUnitAimBiasComponent.New()

			aimBiasComponent:ConfigRangeFormula(ys.Battle.BattleFormulas.CalculateMaxAimBiasRangeMonster, ys.Battle.BattleFormulas.CalculateBiasDecayMonster)

			if table.contains(ShipType.SubShipType, unitShipType) then
				aimBiasComponent:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SUB)
			else
				aimBiasComponent:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_MONSTER)
			end

			aimBiasComponent:AppendCrew(unit)
			aimBiasComponent:SetHostile()
			aimBiasComponent:Active(aimBiasComponent.STATE_SUMMON_SICKNESS)
		end
	end
end

--- 被BattleBuffSmokeAimBias.onAttach调用
--- 给单位附加烟雾中的瞄准偏移组件
--- @param unit BattleUnit
function BattleDataFunction.AttachSmoke(unit)
	local unitType = unit:GetUnitType()
	-- 这里只对敌方单位生效
	if unitType == BattleConst.UnitType.ENEMY_UNIT or unitType == BattleConst.UnitType.BOSS_UNIT then
		if unit:GetAimBias() then
			local aimBias = unit:GetAimBias()
			local aimBiasState = aimBias:GetCurrentState()

			if aimBiasState == aimBias.STATE_SKILL_EXPOSE then
				aimBias:SomkeExitResume()
			elseif aimBiasState == aimBias.STATE_ACTIVITING or aimBiasState == aimBias.STATE_TOTAL_EXPOSE then
				aimBias:SmokeRecover()
			end
		else
			local aimBiasComponent = ys.Battle.BattleUnitAimBiasComponent.New()

			aimBiasComponent:ConfigRangeFormula(ys.Battle.BattleFormulas.CalculateMaxAimBiasRangeMonster, ys.Battle.BattleFormulas.CalculateBiasDecayMonsterInSmoke)
			-- 这个shipType变量是何意味...忘改了吗?
			if table.contains(ShipType.SubShipType, unitType) then
				aimBiasComponent:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_SUB)
			else
				aimBiasComponent:ConfigMinRange(BattleConfig.AIM_BIAS_MIN_RANGE_MONSTER)
			end

			aimBiasComponent:AppendCrew(unit)
			aimBiasComponent:SetHostile()
			aimBiasComponent:Active(aimBiasComponent.STATE_ACTIVITING)
		end
	end
end

--- BattleDataProxy.generatePlayerUnit调用, 初始化装备Buff
--- @param equipment table 装备列表
--- @param playerUnit BattleUnit 玩家单位
--- @param battleType any 战斗类型
function BattleDataFunction.InitEquipSkill(equipment, playerUnit, battleType)
	local equipBuffInfoList = BattleDataFunction.GetEquipSkill(equipment, battleType)
	-- 将记载了buffID和buffLV的buffInfo转换为真正的BuffUnit并添加到单位身上
	for _, buffInfo in ipairs(equipBuffInfoList) do
		local buff = ys.Battle.BattleBuffUnit.New(buffInfo.buffID, buffInfo.buffLV, playerUnit)

		playerUnit:AddBuff(buff)
	end
end

--- BattleDataProxy.generatePlayerUnit调用
--- 添加指挥喵提供的Buff
--- @param commanderBuffInfoList table 指挥喵Buff信息列表
--- @param playerUnit BattleUnit 玩家单位
--- @param battleType any 战斗类型
function BattleDataFunction.InitCommanderSkill(commanderBuffInfoList, playerUnit, battleType)
	commanderBuffInfoList = commanderBuffInfoList or {}

	local currentBattleType = ys.Battle.BattleState.GetInstance():GetBattleType()

	for _, buffInfo in pairs(commanderBuffInfoList) do
		-- limit是battleType的限制. 即这个Buff不能在这些battleType里生效
		local limit = ys.Battle.BattleDataFunction.GetBuffTemplate(buffInfo.id, buffInfo.level).limit
		local isLimited = false

		if limit then
			for _, limitBattleType in ipairs(limit) do
				if currentBattleType == limitBattleType then
					isLimited = true

					break
				end
			end
		end

		if not isLimited then
			local buff = ys.Battle.BattleBuffUnit.New(buffInfo.id, buffInfo.level, playerUnit)
			-- 为了防止BUG，需要设定这个Buff是哪个指挥喵提供的
			buff:SetCommander(buffInfo.commander)
			playerUnit:AddBuff(buff)
		end
	end
end

--- 创建武器主要逻辑
--- 非常重要
--- 一般是在对应的BattleUnit(如PlayerUnit)中调用。此外, BattleSkillFire、BattlePointAirStrikeUnit等也会调用
--- @param weaponId number 武器ID
--- @param host BattleUnit 宿主单位
--- @param potential number 潜能系数
--- @param index number 装备索引(默认为-1)
--- @param weapon_type number 武器类型覆盖(可选)
--- @return BattleWeaponUnit
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
	-- 因为近程防空炮和远程防空炮本质是把多个防空炮综合成一个防空炮，这个处理在BattlePlayerUnit.AddWeapon
	-- 因此这里对于近程防空炮和远程防空炮只创建普通的BattleWeaponUnit
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

--- 创建舰载机主要逻辑
--- 被BattleDataProxy.CreateAircraft调用
--- @param aircraftUID number 飞机UID
--- @param aircraftId number 飞机模板ID
--- @param mother BattleUnit 母舰单位
--- @param potential number 潜能系数
--- @return BattleAircraftUnit
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

--- 被BattleFleetVO.appendScoutUnit/appendMainUnit调用
--- 根据ship_data_template的airassist_time字段创建AllInStrike列表
--- @param unit BattleUnit
--- @return table BattleAllInStrike列表
function BattleDataFunction.CreateAllInStrike(unit)
	local templateID = unit:GetTemplateID()
	-- ship_data_template
	local shipTemplate = BattleDataFunction.GetPlayerShipModelFromID(templateID)
	local airAssistList = {}
	-- 添加魔法空袭
	for index, skillID in ipairs(shipTemplate.airassist_time) do
		local allInStrike = ys.Battle.BattleAllInStrike.New(skillID)

		allInStrike:SetHost(unit)

		airAssistList[index] = allInStrike
	end

	return airAssistList
end

--- 扩展AllInStrike列表（追加一个额外的空袭）
--- 被BattleBuffExpandAllInStrike.onAttach调用
--- @param unit BattleUnit
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

--- 用于将模板数据转换为飞机单位
--- 被BattleDataProxy.CreateAirFighter调用
--- @param aircraftUID number 飞机UID
--- @param tmpData table 模板数据({templateID=..., weaponID=..., backwardWeaponID=...})
--- @return BattleAirFighterUnit
function BattleDataFunction.CreateAirFighterUnit(aircraftUID, tmpData)
	-- aircraft_template
	local aircraftTemplate = BattleDataFunction.GetAircraftTmpDataFromID(tmpData.templateID)
	-- 敌方用的是BattleAirFighterUnit, 是BattleAircraftUnit的子类
	-- (我方用的一般就是BattleAircraftUnit, 不是子类)
	local airFighter = ys.Battle.BattleAirFighterUnit.New(aircraftUID)

	airFighter:SetWeaponTemplateID(tmpData.weaponID)
	airFighter:SetBackwardWeaponID(tmpData.backwardWeaponID)
	airFighter:SetTemplate(aircraftTemplate)

	return airFighter
end

--- 获取玩家舰船临时数据(ship_data_statistics)，会返回Clone副本
--- @param shipID number
--- @return table
function BattleDataFunction.GetPlayerShipTmpDataFromID(shipID)
	assert(ship_data_statistics[shipID] ~= nil, ">>ship_data_statistics<< 找不到玩家船只配置：id = " .. shipID)

	return Clone(ship_data_statistics[shipID])
end

--- 获取玩家舰船模板数据(ship_data_template)
--- @param shipID number
--- @return table
function BattleDataFunction.GetPlayerShipModelFromID(shipID)
	assert(ship_data_template[shipID] ~= nil, ">>ship_data_template<< 找不到玩家船只模组配置：id = " .. shipID)

	return ship_data_template[shipID]
end

--- 获取舰娘皮肤配置(ship_skin_template)
--- @param skinID number
--- @return table
function BattleDataFunction.GetPlayerShipSkinDataFromID(skinID)
	assert(ship_skin_template[skinID] ~= nil, ">>ship_skin_template<< 找不到舰娘皮肤配置：id = " .. skinID)

	return ship_skin_template[skinID]
end

--- 获取舰船类型配置(ship_data_by_type)
--- @param shipTypeID number
--- @return table
function BattleDataFunction.GetShipTypeTmp(shipTypeID)
	assert(ship_data_by_type[shipTypeID] ~= nil, ">>ship_data_by_type<< 找不到舰船类型配置：id = " .. shipTypeID)

	return ship_data_by_type[shipTypeID]
end

--- 获取敌方船只配置(enemy_data_statistics)
--- @param enemyID number
--- @return table
function BattleDataFunction.GetMonsterTmpDataFromID(enemyID)
	assert(enemy_data_statistics[enemyID] ~= nil, ">>enemy_data_statistics<< 找不到敌方船只配置：id = " .. enemyID)

	return enemy_data_statistics[enemyID]
end

--- 获取飞机配置(aircraft_template)
--- @param aircraftID number
--- @return table
function BattleDataFunction.GetAircraftTmpDataFromID(aircraftID)
	assert(aircraft_template[aircraftID] ~= nil, ">>aircraft_template<< 找不到飞机配置：id = " .. aircraftID)

	return aircraft_template[aircraftID]
end

--- 获取武器装备配置(equip_data_statistics)
--- @param equipmentID number
--- @return table
function BattleDataFunction.GetWeaponDataFromID(equipmentID)
	if equipmentID ~= Equipment.EQUIPMENT_STATE_EMPTY and equipmentID ~= Equipment.EQUIPMENT_STATE_LOCK then
		assert(equip_data_statistics[equipmentID] ~= nil, ">>equip_data_statistics<< 找不到武器类装备配置：id = " .. equipmentID)
	end

	return equip_data_statistics[equipmentID]
end

--- 获取装备模板配置(equip_data_template)
--- @param templateID number
--- @return table
function BattleDataFunction.GetEquipDataTemplate(templateID)
	assert(equip_data_template[templateID] ~= nil, ">>equip_data_template<< 找不到武器装备模板：id = " .. templateID)

	return equip_data_template[templateID]
end

--- 获取特殊兵装配置(spweapon_data_statistics)
--- @param spWeaponID number
--- @return table
function BattleDataFunction.GetSpWeaponDataFromID(spWeaponID)
	assert(spweapon_data_statistics[spWeaponID] ~= nil, ">>spweapon_data_statistics<< 找不到特殊兵装配置：id = " .. spWeaponID)

	return spweapon_data_statistics[spWeaponID]
end

--- 获取武器行为配置(weapon_property)
--- @param weaponId number
--- @return table
function BattleDataFunction.GetWeaponPropertyDataFromID(weaponId)
	assert(weapon_property[weaponId] ~= nil, ">>weapon_property<< 找不到武器行为配置：id = " .. weaponId)

	return weapon_property[weaponId]
end

--- 获取阵型配置(formation_template)
--- @param formationID number
--- @return table
function BattleDataFunction.GetFormationTmpDataFromID(formationID)
	assert(formation_template[formationID] ~= nil, ">>formation_template<<找不到阵型配置：id = " .. formationID)

	return formation_template[formationID]
end

--- 获取移动AI配置(auto_pilot_template)
--- @param aiID number
--- @return table
function BattleDataFunction.GetAITmpDataFromID(aiID)
	assert(auto_pilot_template[aiID] ~= nil, ">>auto_pilot_template<< 找不到移动ai配置：id = " .. aiID)

	return auto_pilot_template[aiID]
end

--- 获取舰船性格配置(ship_data_personality)
--- @param personalityID number
--- @return table
function BattleDataFunction.GetShipPersonality(personalityID)
	assert(ship_data_personality[personalityID] ~= nil, ">>shipPersonality<< 找不到性格配置：id = " .. personalityID)

	return ship_data_personality[personalityID]
end

--- 获取敌方类型数据(enemy_data_by_type)
--- @param enemyType number
--- @return table
function BattleDataFunction.GetEnemyTypeDataByType(enemyType)
	assert(enemy_data_by_type[enemyType] ~= nil, ">>enemy_data_by_type<< 找不到怪物类型：type = " .. enemyType)

	return enemy_data_by_type[enemyType]
end

--- 演习场，根据舰种不同获得不同的Buff
--- 从ship_data_by_type的arena_buff字段获得
--- @param shipType number 舰船类型
--- @return table arena_buff数据
function BattleDataFunction.GetArenaBuffByShipType(shipType)
	return BattleDataFunction.GetShipTypeTmp(shipType).arena_buff
end

--- 获取玩家单位演习耐久额外修正
--- 演习中根据舰船等级获得额外的耐久倍率和加成
--- @param battleType any 战斗类型
--- @param level number 舰船等级
--- @return number durability_ratio 耐久倍率
--- @return number durability_add 耐久加成
function BattleDataFunction.GetPlayerUnitDurabilityExtraAddition(battleType, level)
	if battleType == SYSTEM_DUEL then
		assert(ship_level[level] ~= nil, ">>ship_level<< 找不到等级配置：level = " .. level)

		return ship_level[level].arena_durability_ratio, ship_level[level].arena_durability_add
	else
		return 1, 0
	end
end

--- 获取技能数据模板(skill_data_template)
--- @param skillDataID number
--- @return table|nil
function BattleDataFunction.GetSkillDataTemplate(skillDataID)
	return skill_data_template[skillDataID]
end

--- 获取舰船变换数据模板(ship_data_trans)
--- 用于μ兵装/改造等系统
--- @param shipID number
--- @return table|nil
function BattleDataFunction.GetShipTransformDataTemplate(shipID)
	local shipModel = BattleDataFunction.GetPlayerShipModelFromID(shipID)

	return ship_data_trans[shipModel.group_type]
end

--- 获取舰船meta强化数据模板(ship_strengthen_meta)
--- @param shipID number
--- @return table|nil
function BattleDataFunction.GetShipMetaFromDataTemplate(shipID)
	local shipModel = BattleDataFunction.GetPlayerShipModelFromID(shipID)

	return ship_strengthen_meta[shipModel.group_type]
end

--- 获取装备皮肤数据(equip_skin_template)
--- @param skinID number
--- @return table
function BattleDataFunction.GetEquipSkinDataFromID(skinID)
	assert(equip_skin_template[skinID] ~= nil, ">>equip_skin_template<< 找不到装备皮肤配置：id = " .. skinID)

	return equip_skin_template[skinID]
end

--- 获取装备皮肤相关的子弹/特效名
--- @param skinID number
--- @return string bullet_name
--- @return string derivate_bullet
--- @return string derivate_torpedo
--- @return string derivate_boom
--- @return string fire_fx_name
--- @return string hit_fx_name
function BattleDataFunction.GetEquipSkin(skinID)
	assert(equip_skin_template[skinID] ~= nil, ">>equip_skin_template<< 找不到装备皮肤配置：id = " .. skinID)

	local equipSkinData = equip_skin_template[skinID]

	return equipSkinData.bullet_name, equipSkinData.derivate_bullet, equipSkinData.derivate_torpedo, equipSkinData.derivate_boom, equipSkinData.fire_fx_name, equipSkinData.hit_fx_name
end

--- 获取装备皮肤的命中/未命中音效
--- @param skinID number
--- @return string hit_sfx
--- @return string miss_sfx
function BattleDataFunction.GetEquipSkinSFX(skinID)
	assert(equip_skin_template[skinID] ~= nil, ">>equip_skin_template<< 找不到装备皮肤配置：id = " .. skinID)

	local equipSkinData = equip_skin_template[skinID]

	return equipSkinData.hit_sfx, equipSkinData.miss_sfx
end

--- 获取大舰队boss的特定敌人列表
--- @param guildEventID number 大舰队事件ID
--- @param formationID number 阵型ID
--- @return table 敌人列表
function BattleDataFunction.GetSpecificGuildBossEnemyList(guildEventID, formationID)
	local expeditionID = guild_boss_event[guildEventID].expedition_id
	local enemyList = {}

	if expeditionID[1] == formationID then
		enemyList = expeditionID[2]
	end

	return enemyList
end

--- 获取特定活动的敌人列表
--- @param activityID number 活动ID
--- @param formationID number 阵型ID
--- @return table|nil 敌人子列表
function BattleDataFunction.GetSpecificEnemyList(activityID, formationID)
	local activityData = activity_template[activityID]
	local expeditionEnemyList = activity_event_worldboss[activityData.config_id].ex_expedition_enemy
	local enemySubList

	for _, enemyEntry in ipairs(expeditionEnemyList) do
		if enemyEntry[1] == formationID then
			enemySubList = enemyEntry[2]

			break
		end
	end

	return enemySubList
end

--- 获取Meta Boss模板(world_joint_boss_template)
--- @param bossID number
--- @return table
function BattleDataFunction.GetMetaBossTemplate(bossID)
	return world_joint_boss_template[bossID]
end

--- 获取Meta Boss等级模板
--- boss_level_id + (level - 1) = 实际world_boss_level的id
--- @param bossID number Boss ID
--- @param level number Boss等级
--- @return table
function BattleDataFunction.GetMetaBossLevelTemplate(bossID, level)
	local bossLevelID = BattleDataFunction.GetMetaBossTemplate(bossID).boss_level_id + (level - 1)

	return world_boss_level[bossLevelID]
end

--- 获取特定世界联合boss的敌人列表
--- @param _ any (未使用)
--- @param bossID number
--- @param level number
--- @return table 敌人ID列表
function BattleDataFunction.GetSpecificWorldJointEnemyList(_, bossID, level)
	local bossLevelTemplate = BattleDataFunction.GetMetaBossLevelTemplate(bossID, level)

	return {
		bossLevelTemplate.enemy_id
	}
end

--- 根据属性列表增加属性值
--- 遍历attrList中每个元素，若存在attrName字段且为数值，则累加到baseValue
--- @param baseValue number 基础值(会被修改)
--- @param attrName string 属性名
--- @param attrList table 属性列表
function BattleDataFunction.IncreaseAttributes(baseValue, attrName, attrList)
	for _, attrEntry in ipairs(attrList) do
		if attrEntry[attrName] ~= nil and type(attrEntry[attrName]) == "number" then
			baseValue = baseValue + attrEntry[attrName]
		end
	end
end

--- 舰载机创建的武器
--- @param weaponId number 武器ID
--- @param aircraft BattleAircraftUnit 飞机单位
--- @param index number 装备索引
--- @param potential number 潜能系数
--- @return BattleWeaponUnit
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

--- 获取舰船台词文本
--- @param skinID number 皮肤ID
--- @param wordKey string 台词类型名
--- @param intimacy number 好感度
--- @return table 台词数据
function BattleDataFunction.GetWords(skinID, wordKey, intimacy)
	local _, _, words = ShipWordHelper.GetWordAndCV(skinID, wordKey, 1, true, intimacy)

	return words
end

--- 对Buff ID，根据实际的system进行转换
--- 被BattleMediator.GenBattleData调用
--- @param system any 战斗系统/类型
--- @param buffID number 原始Buff ID
--- @return number 转换后的Buff ID
function BattleDataFunction.SkillTranform(system, buffID)
	-- 从skill_data_template的system_transform字段获得转换后的Buff ID
	local skillDataTmp = BattleDataFunction.GetSkillDataTemplate(buffID)

	if not skillDataTmp then
		return buffID
	end

	local system_transform = skillDataTmp.system_transform

	if system_transform[system] == nil then
		return buffID
	else
		return system_transform[system]
	end
end

--- 从ship_data_template的hide_buff_list字段生成隐藏Buff列表
--- 被BattleMediator.GenBattleData调用
--- @param configId number 舰船配置ID
--- @return table {[buffID] = {level = 1, id = buffID}, ...}
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

--- 获取地图潜水过滤器配置
--- @param mapID number
--- @return table
function BattleDataFunction.GetDivingFilter(mapID)
	return map_data[mapID].diving_filter
end

--- Important: 潜艇PhaseList生成
--- @param subAttackBaseLine number 攻击基准线X
--- @param subRetreatBaseLine number 撤退基准线X
--- @param raidDist number 突袭距离
--- @param raidDuration function 突袭持续时间(函数)
--- @param oxyAtkDuration number 氧气攻击持续时间
--- @return table Phase列表
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

--- 获取环境行为配置(battle_environment_behaviour_template)
--- @param envID number
--- @return table
function BattleDataFunction.GetEnvironmentBehaviour(envID)
	assert(battle_environment_behaviour_template[envID] ~= nil, ">>battle_environment_behaviour_template<< 找不到环境行为配置：id = " .. envID)

	return battle_environment_behaviour_template[envID]
end

--- 添加驱逐舰的满破加成
--- 被BattleDataProxy.generatePlayerUnit调用
--- @param playerUnit BattleUnit
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

--- 设备加成提升（辅助舰种满破加成）
--- 将设备属性值乘以AuxBoostValue后直接加到基础属性上
--- @param playerUnit BattleUnit
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
					-- 这部分额外的属性值，不计入综合性能计算
					local newBattleAttrValue = BattleAttr.GetBase(playerUnit, battleAttrName) + attrValue * BattleConst.UltimateBonus.AuxBoostValue

					BattleAttr.SetCurrent(playerUnit, battleAttrName, newBattleAttrValue)
					BattleAttr.SetBaseAttr(playerUnit)
				end
			end
		end
	end
end

--- 通过战斗Buff ID获取SLG策略Buff
--- @param buffID number
--- @return table|nil
function BattleDataFunction.GetSLGStrategyBuffByCombatBuffID(buffID)
	for _, strategyData in pairs(strategy_data_template) do
		if strategyData.buff_id == buffID then
			return strategyData
		end
	end
end
