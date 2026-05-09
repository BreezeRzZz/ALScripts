ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConst = ys.Battle.BattleConst
local EquipmentType = BattleConst.EquipmentType
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattlePlayerUnit = class("BattlePlayerUnit", ys.Battle.BattleUnit)
ys.Battle.BattlePlayerUnit.__name = "BattlePlayerUnit"

local BattlePlayerUnit = ys.Battle.BattlePlayerUnit

function BattlePlayerUnit.Ctor(self, uid, iff)
	BattlePlayerUnit.super.Ctor(self, uid, iff)

	self._type = BattleConst.battleUnitType.PLAYER_UNIT
end

function BattlePlayerUnit.Retreat(self)
	BattlePlayerUnit.super.Retreat(self)
	self:SetDeathReason(BattleConst.UnitDeathReason.LEAVE)
	self:DeacActionClear()
	self._battleProxy:ShutdownPlayerUnit(self:GetUniqueID())
	self._battleProxy:KillUnit(self:GetUniqueID())
end

function BattlePlayerUnit.DeadActionEvent(self)
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.WILL_DIE, {}))
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.SHUT_DOWN_PLAYER, {}))
	self._unitState:ChangeState(ys.Battle.UnitState.STATE_DEAD)
end

function BattlePlayerUnit.IsSpectre(self)
	local battleUnitType
	-- "battle_unit_type"
	local battleUnitTypeAttrKey = ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY

	if self:GetAttr()[battleUnitTypeAttrKey] ~= nil then
		-- 与舰种不是一个概念
		battleUnitType = self:GetAttrByName(battleUnitTypeAttrKey)
	else
		-- PLAYER_DEFAULT = 0
		battleUnitType = BattleConfig.PLAYER_DEFAULT
	end
	-- SPECTRE_UNIT_TYPE = -99
	return battleUnitType <= BattleConfig.SPECTRE_UNIT_TYPE, battleUnitType
end

function BattlePlayerUnit.InitCurrentHP(self, initHPRate)
	-- 此处会再做一次ceil?
	self:SetCurrentHP(math.ceil(self:GetMaxHP() * initHPRate))
	self:TriggerBuff(BattleConst.BuffEffectType.ON_HP_RATIO_UPDATE, {})
end

function BattlePlayerUnit.SetSkinId(self, skinId)
	self._skinId = skinId
end

function BattlePlayerUnit.GetSkinID(self)
	return self._skinId
end

function BattlePlayerUnit.GetDefaultSkinID(self)
	return self._tmpData.skin_id
end

-- note
function BattlePlayerUnit.ActionKeyOffsetUseable(self)
	return self._skinData.spine_action_offset
end

function BattlePlayerUnit.GetShipName(self)
	return self._shipName or self._tmpData.name
end

function BattlePlayerUnit.SetShipName(self, shipName)
	self._shipName = shipName
end

function BattlePlayerUnit.SetTemplate(self, templateID, attr, level)
	BattlePlayerUnit.super.SetTemplate(self, templateID)
	-- ship_data_statistics
	self._tmpData = BattleDataFunction.GetPlayerShipTmpDataFromID(self._tmpID)

	self:configWeaponQueueParallel()
	self:overrideWeaponInfo()
	self:overrideSkin(self._skinId, true)
	self:InitCldComponent()

	attr.armorType = self._tmpData.armor_type
	attr.scale = self._tmpData.scale

	self:setAttrFromOutBattle(attr, level)
	BattleAttr.InitDOTAttr(self._attr, self._tmpData)

	self._personality = BattleDataFunction.GetShipPersonality(2)

	for _, tag in ipairs(self._tmpData.tag_list) do
		self:AddLabelTag(tag)
	end

	self:setStandardLabelTag()
end
-- TODO
function BattlePlayerUnit.overrideSkin(self, skinID, needPainting)
	self._skinData = BattleDataFunction.GetPlayerShipSkinDataFromID(skinID)

	local keys = {
		"prefab",
		"fx_container",
		"bound_bone",
		"smoke"
	}

	if needPainting then
		keys[#keys + 1] = "painting"
	end
	-- 全部记到tmpData里
	_.each(keys, function(key)
		self._tmpData[key] = self._skinData[key]
	end)
end

function BattlePlayerUnit.overrideWeaponInfo(self, baseInfo, preloadInfo)
	if self._overrideBaseInfo then
		self._tmpData.base_list = self._overrideBaseInfo
	end

	if self._overridePreloadInfo then
		self._tmpData.preload_count = self._overridePreloadInfo
	end
end

function BattlePlayerUnit.SetWeaponInfo(self, baseInfo, preloadInfo)
	self._overrideBaseInfo = baseInfo
	self._overridePreloadInfo = preloadInfo
end

function BattlePlayerUnit.SetRarity(self, rarity)
	self._rarity = rarity
end

function BattlePlayerUnit.SetIntimacy(self, intimacy)
	self._intimacy = intimacy
end

function BattlePlayerUnit.setWeapon(self, equipmentList)
	local defaultEquipList = self._tmpData.default_equip_list
	local baseList = self._tmpData.base_list
	local proficiencyList = self._proficiencyList
	local preloadCount = self._tmpData.preload_count

	for equipIndex, equipData in ipairs(equipmentList) do
		if equipData and equipData.skin and equipData.skin ~= 0 and Equipment.IsOrbitSkin(equipData.skin) then
			self._orbitSkinIDList = self._orbitSkinIDList or {}

			table.insert(self._orbitSkinIDList, equipData.skin)
		end

		if equipIndex <= Ship.WEAPON_COUNT then
			local proficiency = proficiencyList[equipIndex]
			local preloadCountSlot = preloadCount[equipIndex]

			local function createWeaponFn(weaponID, label, skinID)
				local baseCount = baseList[equipIndex]

				for mountIndex = 1, baseCount do
					local weapon = self:AddWeapon(weaponID, label, skinID, proficiency, equipIndex)
					local weaponType = weapon:GetTemplateData().type

					if mountIndex <= preloadCountSlot and (weaponType == EquipmentType.POINT_HIT_AND_LOCK or weaponType == EquipmentType.MANUAL_MISSILE or weaponType == EquipmentType.MANUAL_METEOR or weaponType == EquipmentType.MANUAL_TORPEDO or weaponType == EquipmentType.DISPOSABLE_TORPEDO) then
						weapon:SetModifyInitialCD()
					end

					if equipData.equipment then
						weapon:SetSrcEquipmentID(equipData.equipment.id)
					end
				end
			end

			if equipData.equipment and #equipData.equipment.weapon_id > 0 then
				local weaponIDs = equipData.equipment.weapon_id

				for _, weaponIDItem in ipairs(weaponIDs) do
					local weaponType = BattleDataFunction.GetWeaponPropertyDataFromID(weaponIDItem).type
					local shipTypeLimit = BattleConfig.EQUIPMENT_ACTIVE_LIMITED_BY_TYPE[weaponType]

					if (not shipTypeLimit or table.contains(shipTypeLimit, self._tmpData.type)) and weaponIDItem and weaponIDItem ~= -1 then
						createWeaponFn(weaponIDItem, equipData.equipment.label, equipData.skin)
					end
				end
			else
				local defaultWeaponID = defaultEquipList[equipIndex]
				local weaponData = BattleDataFunction.GetWeaponDataFromID(defaultWeaponID)

				createWeaponFn(defaultWeaponID, weaponData.label)
			end
		end
	end

	local defaultEquipCount = #defaultEquipList
	local fixEquipList = self._tmpData.fix_equip_list

	for fixEquipIndex, fixEquipID in ipairs(fixEquipList) do
		if fixEquipID and fixEquipID ~= -1 then
			local fixProficiency = proficiencyList[fixEquipIndex + defaultEquipCount] or 1

			self:AddWeapon(fixEquipID, nil, nil, fixProficiency, fixEquipIndex + defaultEquipCount):SetFixedFlag()
		end
	end

	if self:CanDoAntiSub() then
		local antiSubWeapons = {}

		for slotIndex = Ship.WEAPON_COUNT + 1, #equipmentList do
			local antiSubEquip = equipmentList[slotIndex]

			if antiSubEquip and antiSubEquip.equipment and #antiSubEquip.equipment.weapon_id > 0 then
				antiSubWeapons[#antiSubWeapons + 1] = antiSubEquip.equipment.weapon_id[1]
			end
		end

		for _, depthChargeID in ipairs(self._tmpData.depth_charge_list) do
			antiSubWeapons[#antiSubWeapons + 1] = depthChargeID
		end

		local antiSubWeaponCount = 20
		local antiSubIndex = 1

		for _, weaponIDItem in ipairs(antiSubWeapons) do
			local weapon = BattleDataFunction.CreateWeaponUnit(weaponIDItem, self, antiSubIndex, antiSubWeaponCount)

			self:AddAutoWeapon(weapon)
		end
	end
end

function BattlePlayerUnit.SetPriorityWeaponSkin(self, skinID)
	if not self._priorityWeaponSkinID then
		self._priorityWeaponSkinID = skinID
	end
end

function BattlePlayerUnit.GetPriorityWeaponSkin(self)
	return self._priorityWeaponSkinID
end
-- TODO
function BattlePlayerUnit.AddWeapon(self, weaponID, label, skinID, proficiency, equipmentIndex, param6)
	local weapon = BattleDataFunction.CreateWeaponUnit(weaponID, self, proficiency, equipmentIndex)

	self._totalWeapon[#self._totalWeapon + 1] = weapon

	if label then
		weapon:SetEquipmentLabel(label)
	end

	local weaponType = weapon:GetTemplateData().type

	if weaponType == EquipmentType.POINT_HIT_AND_LOCK or weaponType == EquipmentType.MANUAL_METEOR or weaponType == EquipmentType.MANUAL_MISSILE or weaponType == EquipmentType.POINT_AIR_STRIKE then
		self._chargeList[#self._chargeList + 1] = weapon

		self._weaponQueue:AppendChargeWeapon(weapon)
	elseif weaponType == EquipmentType.MANUAL_TORPEDO or weaponType == EquipmentType.DISPOSABLE_TORPEDO or weaponType == EquipmentType.MANUAL_AAMISSILE then
		self._manualTorpedoList[#self._manualTorpedoList + 1] = weapon

		self._weaponQueue:AppendManualTorpedo(weapon)
	elseif weaponType == EquipmentType.STRIKE_AIRCRAFT then
		-- block empty
	elseif weaponType == EquipmentType.FLEET_ANTI_AIR then
		self:AddFleetAntiAirWeapon(weapon)
	elseif weaponType == EquipmentType.FLEET_RANGE_ANTI_AIR then
		self:AddFleetRangeAntiAirWeapon(weapon)
	else
		self:AddAutoWeapon(weapon)
	end

	if weaponType == EquipmentType.STRIKE_AIRCRAFT then
		self._hiveList[#self._hiveList + 1] = weapon
	end

	if weaponType == EquipmentType.ANTI_AIR then
		self._AAList[#self._AAList + 1] = weapon
	end

	if skinID and skinID ~= 0 then
		weapon:SetSkinData(skinID)
		self:SetPriorityWeaponSkin(skinID)
	end

	return weapon
end

-- BattleBuffShiftWeapon.removeWeapon调用
function BattlePlayerUnit.RemoveWeapon(self, weaponID)
	local weaponType = BattleDataFunction.GetWeaponPropertyDataFromID(weaponID).type
	local removedWeapon

	if weaponType == EquipmentType.STRIKE_AIRCRAFT then
		for _, hiveWeapon in ipairs(self._hiveList) do
			if hiveWeapon:GetWeaponId() == weaponID then
				removedWeapon = hiveWeapon

				table.remove(self._hiveList, _)

				break
			end
		end
	elseif weaponType == EquipmentType.POINT_HIT_AND_LOCK or weaponType == EquipmentType.MANUAL_METEOR or weaponType == EquipmentType.MANUAL_MISSILE then
		-- block empty
	elseif weaponType == EquipmentType.MANUAL_TORPEDO then
		for _, torpedoWeapon in ipairs(self._manualTorpedoList) do
			if torpedoWeapon:GetWeaponId() == weaponID then
				removedWeapon = torpedoWeapon

				table.remove(self._manualTorpedoList, _)
				self._weaponQueue:RemoveManualTorpedo(torpedoWeapon)

				break
			end
		end
	elseif weaponType == EquipmentType.FLEET_ANTI_AIR then
		for _, faaWeapon in ipairs(self._fleetAAList) do
			if faaWeapon:GetWeaponId() == weaponID then
				self:RemoveFleetAntiAirWeapon(faaWeapon)

				break
			end
		end
	else
		for _, autoWeapon in ipairs(self._autoWeaponList) do
			if autoWeapon:GetWeaponId() == weaponID then
				removedWeapon = autoWeapon

				removedWeapon:Clear()
				self:RemoveAutoWeapon(removedWeapon)

				break
			end
		end
	end

	if removedWeapon then
		for _, totalWeapon in ipairs(self._totalWeapon) do
			if totalWeapon == removedWeapon then
				table.remove(self._totalWeapon, _)

				break
			end
		end
	end

	return removedWeapon
end

function BattlePlayerUnit.RemoveWeaponByLabel(self, labels)
	local removedWeapon

	for _, weapon in ipairs(self._totalWeapon) do
		local allMatch = true

		for _, labelItem in ipairs(labels) do
			local equipmentLabel = weapon:GetEquipmentLabel()

			allMatch = allMatch and table.contains(equipmentLabel, labelItem)
		end

		if allMatch then
			removedWeapon = weapon

			table.remove(self._totalWeapon, _)
		end
	end

	if not removedWeapon then
		return
	end

	local weaponType = removedWeapon:GetType()

	if weaponType == EquipmentType.STRIKE_AIRCRAFT then
		for _, hiveWeapon in ipairs(self._hiveList) do
			if removedWeapon == hiveWeapon then
				table.remove(self._hiveList, _)

				break
			end
		end
	elseif weaponType == EquipmentType.POINT_HIT_AND_LOCK or weaponType == EquipmentType.MANUAL_METEOR or weaponType == EquipmentType.MANUAL_MISSILE then
		-- block empty
	elseif weaponType == EquipmentType.MANUAL_TORPEDO then
		for _, torpedoWeapon in ipairs(self._manualTorpedoList) do
			if removedWeapon == torpedoWeapon then
				table.remove(self._manualTorpedoList, _)
				self._weaponQueue:RemoveManualTorpedo(torpedoWeapon)

				break
			end
		end
	elseif weaponType == EquipmentType.FLEET_ANTI_AIR then
		for _, faaWeapon in ipairs(self._fleetAAList) do
			if removedWeapon == faaWeapon then
				self:RemoveFleetAntiAirWeapon(faaWeapon)

				break
			end
		end
	elseif weaponType == EquipmentType.INTERCEPT_AIRCRAFT then
		for _, autoWeapon in ipairs(self._autoWeaponList) do
			if removedWeapon == autoWeapon then
				self:RemoveAutoWeapon(removedWeapon)

				break
			end
		end
	else
		for _, autoWeapon in ipairs(self._autoWeaponList) do
			if removedWeapon == autoWeapon then
				self:RemoveAutoWeapon(removedWeapon)

				break
			end
		end
	end

	return removedWeapon
end

function BattlePlayerUnit.AddFleetAntiAirWeapon(self, weapon)
	self._fleetAAList[#self._fleetAAList + 1] = weapon

	if self._fleet and self._fleet:GetFleetAntiAirWeapon() then
		self._fleet:GetFleetAntiAirWeapon():FlushCrewUnit(self)
	end
end

function BattlePlayerUnit.RemoveFleetAntiAirWeapon(self, weapon)
	for index, faaWeapon in ipairs(self._fleetAAList) do
		if faaWeapon == weapon then
			table.remove(self._fleetAAList, index)

			return
		end
	end

	self._fleet:GetFleetAntiAirWeapon():FlushCrewUnit(self)
end

function BattlePlayerUnit.AddFleetRangeAntiAirWeapon(self, weapon)
	self._fleetRangeAAList[#self._fleetRangeAAList + 1] = weapon
end

function BattlePlayerUnit.RemoveFleetRangeAntiAirWeapon(self, weapon)
	for index, fraaWeapon in ipairs(self._fleetRangeAAList) do
		if fraaWeapon == weapon then
			table.remove(self._fleetRangeAAList, index)

			return
		end
	end
end

function BattlePlayerUnit.ShiftWeapon(self, weaponIDs)
	return
end

function BattlePlayerUnit.GetManualWeaponParallel(self)
	return self._tmpData.parallel_max
end

function BattlePlayerUnit.CeaseAllWeapon(self, ceaseFire)
	if ceaseFire then
		for _, weapon in ipairs(self._totalWeapon) do
			weapon:Cease()
		end

		local buffList = self._buffList

		for _, buff in pairs(buffList) do
			buff:Interrupt()
		end
	end

	BattlePlayerUnit.super.CeaseAllWeapon(self, ceaseFire)
end

-- 被BattleFleetVO.refreshFleetFormation调用
function BattlePlayerUnit.LeaderSetting(self)
	local intimacy = self:GetIntimacy()
	local shipWords = BattleDataFunction.GetWords(self:GetSkinID(), "hp_warning", intimacy)

	if shipWords and shipWords ~= "" then
		self._warningValue = BattleConfig.WARNING_HP_RATE * self:GetMaxHP()
	end
end

function BattlePlayerUnit.UpdateHP(self, dHP, extraInfo, arg3, arg4)
	local superDHP = BattlePlayerUnit.super.UpdateHP(self, dHP, extraInfo, arg3, arg4)

	if self._warningValue and self._currentHP < self._warningValue and not isHeal then
		self._warningValue = nil

		local intimacy = self:GetIntimacy()
		local voiceKey = "hp_warning"
		local shipWord = BattleDataFunction.GetWords(self:GetSkinID(), voiceKey, intimacy)

		self:DispatchVoice(voiceKey)
		self:DispatchChat(shipWord, 2.5, voiceKey)
	end

	if self._mainUnitWarningValue and self._currentHP < self._mainUnitWarningValue and self._currentHP > 0 and not isHeal then
		self._mainUnitWarningValue = nil

		pg.TipsMgr.GetInstance():ShowTips(i18n("battle_main_emergent", self:GetShipName()))
	end

	return superDHP
end

function BattlePlayerUnit.SetMainFleetUnit(self)
	BattlePlayerUnit.super.SetMainFleetUnit(self)

	if self._IFF == BattleConfig.FRIENDLY_CODE then
		self._mainUnitWarningValue = BattleConfig.WARNING_HP_RATE_MAIN * self:GetMaxHP()
	end
end

function BattlePlayerUnit.UpdatePrecastMoveLimit(self)
	return
end
-- TODO
function BattlePlayerUnit.setStandardLabelTag(self)
	BattlePlayerUnit.super.setStandardLabelTag(self)
	-- ship_data_statistics.parallel_max
	local parallel_max = self:GetManualWeaponParallel()
	local index = #parallel_max

	while index > 0 do
		-- 需要对应位置 > 1
		if parallel_max[index] > 1 then
			print(BattleConst.PARALLEL_LABEL_TAG[index])
			self:AddLabelTag(BattleConst.PARALLEL_LABEL_TAG[index])
		end

		index = index - 1
	end
end

function BattlePlayerUnit.ConfigBubbleFX(self)
	self._bubbleFX = BattleConfig.PLAYER_SUB_BUBBLE_FX

	self._oxyState:SetBubbleTemplate(BattleConfig.PLAYER_SUB_BUBBLE_INIT, BattleConfig.PLAYER_SUB_BUBBLE_INTERVAL)
end

function BattlePlayerUnit.OxyConsume(self)
	BattlePlayerUnit.super.OxyConsume(self)

	if self._currentOxy <= 0 then
		self._fleet:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_FLOAT, true)
	end
end

function BattlePlayerUnit.SetFormationIndex(self, formationIndex)
	self._formationIndex = formationIndex
end

function BattlePlayerUnit.setAttrFromOutBattle(self, attr, level)
	BattleAttr.SetPlayerAttrFromOutBattle(self, attr, level)
end

function BattlePlayerUnit.SetFleetVO(self, fleet)
	self._fleet = fleet
	self._subRaidLine, self._subRetreatLine = self._fleet:GetSubmarineBaseLine()
end

function BattlePlayerUnit.GetTemplate(self)
	return self._tmpData
end

function BattlePlayerUnit.GetGroupID(self)
	local templateID = self:GetTemplateID()

	return BattleDataFunction.GetPlayerShipModelFromID(templateID).group_type
end

function BattlePlayerUnit.GetRarity(self)
	return self._rarity or self._tmpData.rarity
end

function BattlePlayerUnit.GetIntimacy(self)
	return self._intimacy or 0
end

-- 被BattleFleetVO.GetLeaderPersonality调用
-- _personality在SetTemplate中初始化，来自BattleDataFunction.GetShipPersonality(2)
-- 对应的是ship_data_personality表的第二项("元气")
function BattlePlayerUnit.GetAutoPilotPreference(self)
	return self._personality
end

function BattlePlayerUnit.GetFleetVO(self)
	return self._fleet
end

function BattlePlayerUnit.InitCldComponent(self)
	BattlePlayerUnit.super.InitCldComponent(self)

	local cldData = {
		type = BattleConst.CldType.SHIP,
		IFF = self:GetIFF(),
		UID = self:GetUniqueID(),
		Mass = BattleConst.CldMass.L2
	}

	self._cldComponent:SetCldData(cldData)
end

function BattlePlayerUnit.AddPointAirStrike(self, strikeWeaponID, coolDownDuration, initOverheat)
	local strikeWeapon = self:AddWeapon(strikeWeaponID, {}, nil, 1, -1)

	self:GetFleetVO():GetChargeWeaponVO():AppendWeapon(strikeWeapon)

	if initOverheat then
		strikeWeapon:OverHeat()
		strikeWeapon:EnterCoolDown()
	end

	self:GetFleetVO():GetChargeWeaponVO():DispatchCountChange()
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_POINT_AIR_STRIKE, {
		weapon = strikeWeapon
	}))

	return strikeWeapon
end
