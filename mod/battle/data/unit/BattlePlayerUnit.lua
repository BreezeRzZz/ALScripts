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

function BattlePlayerUnit.Ctor(arg_1_0, arg_1_1, arg_1_2)
	BattlePlayerUnit.super.Ctor(arg_1_0, arg_1_1, arg_1_2)

	arg_1_0._type = BattleConst.battleUnitType.PLAYER_UNIT
end

function BattlePlayerUnit.Retreat(arg_2_0)
	BattlePlayerUnit.super.Retreat(arg_2_0)
	arg_2_0:SetDeathReason(BattleConst.UnitDeathReason.LEAVE)
	arg_2_0:DeacActionClear()
	arg_2_0._battleProxy:ShutdownPlayerUnit(arg_2_0:GetUniqueID())
	arg_2_0._battleProxy:KillUnit(arg_2_0:GetUniqueID())
end

function BattlePlayerUnit.DeadActionEvent(arg_3_0)
	arg_3_0:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.WILL_DIE, {}))
	arg_3_0:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.SHUT_DOWN_PLAYER, {}))
	arg_3_0._unitState:ChangeState(ys.Battle.UnitState.STATE_DEAD)
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
	-- 稍微查了一下，好像部分召唤物才被判定为SPECTRE(幽灵?)
	return battleUnitType <= BattleConfig.SPECTRE_UNIT_TYPE, battleUnitType
end

function BattlePlayerUnit.InitCurrentHP(arg_5_0, arg_5_1)
	arg_5_0:SetCurrentHP(math.ceil(arg_5_0:GetMaxHP() * arg_5_1))
	arg_5_0:TriggerBuff(BattleConst.BuffEffectType.ON_HP_RATIO_UPDATE, {})
end

function BattlePlayerUnit.SetSkinId(arg_6_0, arg_6_1)
	arg_6_0._skinId = arg_6_1
end

function BattlePlayerUnit.GetSkinID(arg_7_0)
	return arg_7_0._skinId
end

function BattlePlayerUnit.GetDefaultSkinID(arg_8_0)
	return arg_8_0._tmpData.skin_id
end

function BattlePlayerUnit.ActionKeyOffsetUseable(arg_9_0)
	return arg_9_0._skinData.spine_action_offset
end

function BattlePlayerUnit.GetShipName(arg_10_0)
	return arg_10_0._shipName or arg_10_0._tmpData.name
end

function BattlePlayerUnit.SetShipName(arg_11_0, arg_11_1)
	arg_11_0._shipName = arg_11_1
end

function BattlePlayerUnit.SetTemplate(arg_12_0, arg_12_1, arg_12_2, arg_12_3)
	BattlePlayerUnit.super.SetTemplate(arg_12_0, arg_12_1)

	arg_12_0._tmpData = BattleDataFunction.GetPlayerShipTmpDataFromID(arg_12_0._tmpID)

	arg_12_0:configWeaponQueueParallel()
	arg_12_0:overrideWeaponInfo()
	arg_12_0:overrideSkin(arg_12_0._skinId, true)
	arg_12_0:InitCldComponent()

	arg_12_2.armorType = arg_12_0._tmpData.armor_type

	arg_12_0:setAttrFromOutBattle(arg_12_2, arg_12_3)
	BattleAttr.InitDOTAttr(arg_12_0._attr, arg_12_0._tmpData)

	arg_12_0._personality = BattleDataFunction.GetShipPersonality(2)

	for iter_12_0, iter_12_1 in ipairs(arg_12_0._tmpData.tag_list) do
		arg_12_0:AddLabelTag(iter_12_1)
	end

	arg_12_0:setStandardLabelTag()
end

function BattlePlayerUnit.overrideSkin(arg_13_0, arg_13_1, arg_13_2)
	arg_13_0._skinData = BattleDataFunction.GetPlayerShipSkinDataFromID(arg_13_1)

	local var_13_0 = {
		"prefab",
		"fx_container",
		"bound_bone",
		"smoke"
	}

	if arg_13_2 then
		var_13_0[#var_13_0 + 1] = "painting"
	end

	_.each(var_13_0, function(arg_14_0)
		arg_13_0._tmpData[arg_14_0] = arg_13_0._skinData[arg_14_0]
	end)
end

function BattlePlayerUnit.overrideWeaponInfo(arg_15_0, arg_15_1, arg_15_2)
	if arg_15_0._overrideBaseInfo then
		arg_15_0._tmpData.base_list = arg_15_0._overrideBaseInfo
	end

	if arg_15_0._overridePreloadInfo then
		arg_15_0._tmpData.preload_count = arg_15_0._overridePreloadInfo
	end
end

function BattlePlayerUnit.SetWeaponInfo(arg_16_0, arg_16_1, arg_16_2)
	arg_16_0._overrideBaseInfo = arg_16_1
	arg_16_0._overridePreloadInfo = arg_16_2
end

function BattlePlayerUnit.SetRarity(arg_17_0, arg_17_1)
	arg_17_0._rarity = arg_17_1
end

function BattlePlayerUnit.SetIntimacy(arg_18_0, arg_18_1)
	arg_18_0._intimacy = arg_18_1
end

function BattlePlayerUnit.setWeapon(arg_19_0, arg_19_1)
	local var_19_0 = arg_19_0._tmpData.default_equip_list
	local var_19_1 = arg_19_0._tmpData.base_list
	local var_19_2 = arg_19_0._proficiencyList
	local var_19_3 = arg_19_0._tmpData.preload_count

	for iter_19_0, iter_19_1 in ipairs(arg_19_1) do
		if iter_19_1 and iter_19_1.skin and iter_19_1.skin ~= 0 and Equipment.IsOrbitSkin(iter_19_1.skin) then
			arg_19_0._orbitSkinIDList = arg_19_0._orbitSkinIDList or {}

			table.insert(arg_19_0._orbitSkinIDList, iter_19_1.skin)
		end

		if iter_19_0 <= Ship.WEAPON_COUNT then
			local var_19_4 = var_19_2[iter_19_0]
			local var_19_5 = var_19_3[iter_19_0]

			local function var_19_6(arg_20_0, arg_20_1, arg_20_2)
				local var_20_0 = var_19_1[iter_19_0]

				for iter_20_0 = 1, var_20_0 do
					local var_20_1 = arg_19_0:AddWeapon(arg_20_0, arg_20_1, arg_20_2, var_19_4, iter_19_0)
					local var_20_2 = var_20_1:GetTemplateData().type

					if iter_20_0 <= var_19_5 and (var_20_2 == EquipmentType.POINT_HIT_AND_LOCK or var_20_2 == EquipmentType.MANUAL_MISSILE or var_20_2 == EquipmentType.MANUAL_METEOR or var_20_2 == EquipmentType.MANUAL_TORPEDO or var_20_2 == EquipmentType.DISPOSABLE_TORPEDO) then
						var_20_1:SetModifyInitialCD()
					end

					if iter_19_1.equipment then
						var_20_1:SetSrcEquipmentID(iter_19_1.equipment.id)
					end
				end
			end

			if iter_19_1.equipment and #iter_19_1.equipment.weapon_id > 0 then
				local var_19_7 = iter_19_1.equipment.weapon_id

				for iter_19_2, iter_19_3 in ipairs(var_19_7) do
					local var_19_8 = BattleDataFunction.GetWeaponPropertyDataFromID(iter_19_3).type
					local var_19_9 = BattleConfig.EQUIPMENT_ACTIVE_LIMITED_BY_TYPE[var_19_8]

					if (not var_19_9 or table.contains(var_19_9, arg_19_0._tmpData.type)) and iter_19_3 and iter_19_3 ~= -1 then
						var_19_6(iter_19_3, iter_19_1.equipment.label, iter_19_1.skin)
					end
				end
			else
				local var_19_10 = var_19_0[iter_19_0]
				local var_19_11 = BattleDataFunction.GetWeaponDataFromID(var_19_10)

				var_19_6(var_19_10, var_19_11.label)
			end
		end
	end

	local var_19_12 = #var_19_0
	local var_19_13 = arg_19_0._tmpData.fix_equip_list

	for iter_19_4, iter_19_5 in ipairs(var_19_13) do
		if iter_19_5 and iter_19_5 ~= -1 then
			local var_19_14 = var_19_2[iter_19_4 + var_19_12] or 1

			arg_19_0:AddWeapon(iter_19_5, nil, nil, var_19_14, iter_19_4 + var_19_12):SetFixedFlag()
		end
	end

	if arg_19_0:CanDoAntiSub() then
		local var_19_15 = {}

		for iter_19_6 = Ship.WEAPON_COUNT + 1, #arg_19_1 do
			local var_19_16 = arg_19_1[iter_19_6]

			if var_19_16 and var_19_16.equipment and #var_19_16.equipment.weapon_id > 0 then
				var_19_15[#var_19_15 + 1] = var_19_16.equipment.weapon_id[1]
			end
		end

		for iter_19_7, iter_19_8 in ipairs(arg_19_0._tmpData.depth_charge_list) do
			var_19_15[#var_19_15 + 1] = iter_19_8
		end

		local var_19_17 = 20
		local var_19_18 = 1

		for iter_19_9, iter_19_10 in ipairs(var_19_15) do
			local var_19_19 = BattleDataFunction.CreateWeaponUnit(iter_19_10, arg_19_0, var_19_18, var_19_17)

			arg_19_0:AddAutoWeapon(var_19_19)
		end
	end
end

function BattlePlayerUnit.SetPriorityWeaponSkin(arg_21_0, arg_21_1)
	if not arg_21_0._priorityWeaponSkinID then
		arg_21_0._priorityWeaponSkinID = arg_21_1
	end
end

function BattlePlayerUnit.GetPriorityWeaponSkin(arg_22_0)
	return arg_22_0._priorityWeaponSkinID
end

function BattlePlayerUnit.AddWeapon(arg_23_0, arg_23_1, arg_23_2, arg_23_3, arg_23_4, arg_23_5, arg_23_6)
	local var_23_0 = BattleDataFunction.CreateWeaponUnit(arg_23_1, arg_23_0, arg_23_4, arg_23_5)

	arg_23_0._totalWeapon[#arg_23_0._totalWeapon + 1] = var_23_0

	if arg_23_2 then
		var_23_0:SetEquipmentLabel(arg_23_2)
	end

	local var_23_1 = var_23_0:GetTemplateData().type

	if var_23_1 == EquipmentType.POINT_HIT_AND_LOCK or var_23_1 == EquipmentType.MANUAL_METEOR or var_23_1 == EquipmentType.MANUAL_MISSILE or var_23_1 == EquipmentType.POINT_AIR_STRIKE then
		arg_23_0._chargeList[#arg_23_0._chargeList + 1] = var_23_0

		arg_23_0._weaponQueue:AppendChargeWeapon(var_23_0)
	elseif var_23_1 == EquipmentType.MANUAL_TORPEDO or var_23_1 == EquipmentType.DISPOSABLE_TORPEDO or var_23_1 == EquipmentType.MANUAL_AAMISSILE then
		arg_23_0._manualTorpedoList[#arg_23_0._manualTorpedoList + 1] = var_23_0

		arg_23_0._weaponQueue:AppendManualTorpedo(var_23_0)
	elseif var_23_1 == EquipmentType.STRIKE_AIRCRAFT then
		-- block empty
	elseif var_23_1 == EquipmentType.FLEET_ANTI_AIR then
		arg_23_0:AddFleetAntiAirWeapon(var_23_0)
	elseif var_23_1 == EquipmentType.FLEET_RANGE_ANTI_AIR then
		arg_23_0:AddFleetRangeAntiAirWeapon(var_23_0)
	else
		arg_23_0:AddAutoWeapon(var_23_0)
	end

	if var_23_1 == EquipmentType.STRIKE_AIRCRAFT then
		arg_23_0._hiveList[#arg_23_0._hiveList + 1] = var_23_0
	end

	if var_23_1 == EquipmentType.ANTI_AIR then
		arg_23_0._AAList[#arg_23_0._AAList + 1] = var_23_0
	end

	if arg_23_3 and arg_23_3 ~= 0 then
		var_23_0:SetSkinData(arg_23_3)
		arg_23_0:SetPriorityWeaponSkin(arg_23_3)
	end

	return var_23_0
end

function BattlePlayerUnit.RemoveWeapon(arg_24_0, arg_24_1)
	local var_24_0 = BattleDataFunction.GetWeaponPropertyDataFromID(arg_24_1).type
	local var_24_1

	if var_24_0 == EquipmentType.STRIKE_AIRCRAFT then
		for iter_24_0, iter_24_1 in ipairs(arg_24_0._hiveList) do
			if iter_24_1:GetWeaponId() == arg_24_1 then
				var_24_1 = iter_24_1

				table.remove(arg_24_0._hiveList, iter_24_0)

				break
			end
		end
	elseif var_24_0 == EquipmentType.POINT_HIT_AND_LOCK or var_24_0 == EquipmentType.MANUAL_METEOR or var_24_0 == EquipmentType.MANUAL_MISSILE then
		-- block empty
	elseif var_24_0 == EquipmentType.MANUAL_TORPEDO then
		for iter_24_2, iter_24_3 in ipairs(arg_24_0._manualTorpedoList) do
			if iter_24_3:GetWeaponId() == arg_24_1 then
				var_24_1 = iter_24_3

				table.remove(arg_24_0._manualTorpedoList, iter_24_2)
				arg_24_0._weaponQueue:RemoveManualTorpedo(iter_24_3)

				break
			end
		end
	elseif var_24_0 == EquipmentType.FLEET_ANTI_AIR then
		for iter_24_4, iter_24_5 in ipairs(arg_24_0._fleetAAList) do
			if iter_24_5:GetWeaponId() == arg_24_1 then
				arg_24_0:RemoveFleetAntiAirWeapon(iter_24_5)

				break
			end
		end
	else
		for iter_24_6, iter_24_7 in ipairs(arg_24_0._autoWeaponList) do
			if iter_24_7:GetWeaponId() == arg_24_1 then
				var_24_1 = iter_24_7

				var_24_1:Clear()
				arg_24_0:RemoveAutoWeapon(var_24_1)

				break
			end
		end
	end

	if var_24_1 then
		for iter_24_8, iter_24_9 in ipairs(arg_24_0._totalWeapon) do
			if iter_24_9 == var_24_1 then
				table.remove(arg_24_0._totalWeapon, iter_24_8)

				break
			end
		end
	end

	return var_24_1
end

function BattlePlayerUnit.RemoveWeaponByLabel(arg_25_0, arg_25_1)
	local var_25_0

	for iter_25_0, iter_25_1 in ipairs(arg_25_0._totalWeapon) do
		local var_25_1 = true

		for iter_25_2, iter_25_3 in ipairs(arg_25_1) do
			local var_25_2 = iter_25_1:GetEquipmentLabel()

			var_25_1 = var_25_1 and table.contains(var_25_2, iter_25_3)
		end

		if var_25_1 then
			var_25_0 = iter_25_1

			table.remove(arg_25_0._totalWeapon, iter_25_0)
		end
	end

	if not var_25_0 then
		return
	end

	local var_25_3 = var_25_0:GetType()

	if var_25_3 == EquipmentType.STRIKE_AIRCRAFT then
		for iter_25_4, iter_25_5 in ipairs(arg_25_0._hiveList) do
			if var_25_0 == iter_25_5 then
				table.remove(arg_25_0._hiveList, iter_25_4)

				break
			end
		end
	elseif var_25_3 == EquipmentType.POINT_HIT_AND_LOCK or var_25_3 == EquipmentType.MANUAL_METEOR or var_25_3 == EquipmentType.MANUAL_MISSILE then
		-- block empty
	elseif var_25_3 == EquipmentType.MANUAL_TORPEDO then
		for iter_25_6, iter_25_7 in ipairs(arg_25_0._manualTorpedoList) do
			if var_25_0 == iter_25_7 then
				table.remove(arg_25_0._manualTorpedoList, iter_25_6)
				arg_25_0._weaponQueue:RemoveManualTorpedo(iter_25_7)

				break
			end
		end
	elseif var_25_3 == EquipmentType.FLEET_ANTI_AIR then
		for iter_25_8, iter_25_9 in ipairs(arg_25_0._fleetAAList) do
			if var_25_0 == iter_25_9 then
				arg_25_0:RemoveFleetAntiAirWeapon(iter_25_9)

				break
			end
		end
	elseif var_25_3 == EquipmentType.INTERCEPT_AIRCRAFT then
		for iter_25_10, iter_25_11 in ipairs(arg_25_0._autoWeaponList) do
			if var_25_0 == iter_25_11 then
				arg_25_0:RemoveAutoWeapon(var_25_0)

				break
			end
		end
	else
		for iter_25_12, iter_25_13 in ipairs(arg_25_0._autoWeaponList) do
			if var_25_0 == iter_25_13 then
				arg_25_0:RemoveAutoWeapon(var_25_0)

				break
			end
		end
	end

	return var_25_0
end

function BattlePlayerUnit.AddFleetAntiAirWeapon(arg_26_0, arg_26_1)
	arg_26_0._fleetAAList[#arg_26_0._fleetAAList + 1] = arg_26_1

	if arg_26_0._fleet and arg_26_0._fleet:GetFleetAntiAirWeapon() then
		arg_26_0._fleet:GetFleetAntiAirWeapon():FlushCrewUnit(arg_26_0)
	end
end

function BattlePlayerUnit.RemoveFleetAntiAirWeapon(arg_27_0, arg_27_1)
	for iter_27_0, iter_27_1 in ipairs(arg_27_0._fleetAAList) do
		if iter_27_1 == arg_27_1 then
			table.remove(arg_27_0._fleetAAList, iter_27_0)

			return
		end
	end

	arg_27_0._fleet:GetFleetAntiAirWeapon():FlushCrewUnit(arg_27_0)
end

function BattlePlayerUnit.AddFleetRangeAntiAirWeapon(arg_28_0, arg_28_1)
	arg_28_0._fleetRangeAAList[#arg_28_0._fleetRangeAAList + 1] = arg_28_1
end

function BattlePlayerUnit.RemoveFleetRangeAntiAirWeapon(arg_29_0, arg_29_1)
	for iter_29_0, iter_29_1 in ipairs(arg_29_0._fleetRangeAAList) do
		if iter_29_1 == arg_29_1 then
			table.remove(arg_29_0._fleetRangeAAList, iter_29_0)

			return
		end
	end
end

function BattlePlayerUnit.ShiftWeapon(arg_30_0, arg_30_1)
	return
end

function BattlePlayerUnit.GetManualWeaponParallel(arg_31_0)
	return arg_31_0._tmpData.parallel_max
end

function BattlePlayerUnit.CeaseAllWeapon(arg_32_0, arg_32_1)
	if arg_32_1 then
		for iter_32_0, iter_32_1 in ipairs(arg_32_0._totalWeapon) do
			iter_32_1:Cease()
		end

		local var_32_0 = arg_32_0._buffList

		for iter_32_2, iter_32_3 in pairs(var_32_0) do
			iter_32_3:Interrupt()
		end
	end

	BattlePlayerUnit.super.CeaseAllWeapon(arg_32_0, arg_32_1)
end

function BattlePlayerUnit.LeaderSetting(arg_33_0)
	local var_33_0 = arg_33_0:GetIntimacy()
	local var_33_1 = BattleDataFunction.GetWords(arg_33_0:GetSkinID(), "hp_warning", var_33_0)

	if var_33_1 and var_33_1 ~= "" then
		arg_33_0._warningValue = BattleConfig.WARNING_HP_RATE * arg_33_0:GetMaxHP()
	end
end

function BattlePlayerUnit.UpdateHP(arg_34_0, arg_34_1, arg_34_2, arg_34_3, arg_34_4)
	local var_34_0 = BattlePlayerUnit.super.UpdateHP(arg_34_0, arg_34_1, arg_34_2, arg_34_3, arg_34_4)

	if arg_34_0._warningValue and arg_34_0._currentHP < arg_34_0._warningValue and not isHeal then
		arg_34_0._warningValue = nil

		local var_34_1 = arg_34_0:GetIntimacy()
		local var_34_2 = "hp_warning"
		local var_34_3 = BattleDataFunction.GetWords(arg_34_0:GetSkinID(), var_34_2, var_34_1)

		arg_34_0:DispatchVoice(var_34_2)
		arg_34_0:DispatchChat(var_34_3, 2.5, var_34_2)
	end

	if arg_34_0._mainUnitWarningValue and arg_34_0._currentHP < arg_34_0._mainUnitWarningValue and arg_34_0._currentHP > 0 and not isHeal then
		arg_34_0._mainUnitWarningValue = nil

		pg.TipsMgr.GetInstance():ShowTips(i18n("battle_main_emergent", arg_34_0:GetShipName()))
	end

	return var_34_0
end

function BattlePlayerUnit.SetMainFleetUnit(arg_35_0)
	BattlePlayerUnit.super.SetMainFleetUnit(arg_35_0)

	if arg_35_0._IFF == BattleConfig.FRIENDLY_CODE then
		arg_35_0._mainUnitWarningValue = BattleConfig.WARNING_HP_RATE_MAIN * arg_35_0:GetMaxHP()
	end
end

function BattlePlayerUnit.UpdatePrecastMoveLimit(arg_36_0)
	return
end

function BattlePlayerUnit.setStandardLabelTag(arg_37_0)
	BattlePlayerUnit.super.setStandardLabelTag(arg_37_0)

	local var_37_0 = arg_37_0:GetManualWeaponParallel()
	local var_37_1 = #var_37_0

	while var_37_1 > 0 do
		if var_37_0[var_37_1] > 1 then
			print(BattleConst.PARALLEL_LABEL_TAG[var_37_1])
			arg_37_0:AddLabelTag(BattleConst.PARALLEL_LABEL_TAG[var_37_1])
		end

		var_37_1 = var_37_1 - 1
	end
end

function BattlePlayerUnit.ConfigBubbleFX(arg_38_0)
	arg_38_0._bubbleFX = BattleConfig.PLAYER_SUB_BUBBLE_FX

	arg_38_0._oxyState:SetBubbleTemplate(BattleConfig.PLAYER_SUB_BUBBLE_INIT, BattleConfig.PLAYER_SUB_BUBBLE_INTERVAL)
end

function BattlePlayerUnit.OxyConsume(arg_39_0)
	BattlePlayerUnit.super.OxyConsume(arg_39_0)

	if arg_39_0._currentOxy <= 0 then
		arg_39_0._fleet:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_FLOAT, true)
	end
end

function BattlePlayerUnit.SetFormationIndex(arg_40_0, arg_40_1)
	arg_40_0._formationIndex = arg_40_1
end

function BattlePlayerUnit.setAttrFromOutBattle(arg_41_0, arg_41_1, arg_41_2)
	BattleAttr.SetPlayerAttrFromOutBattle(arg_41_0, arg_41_1, arg_41_2)
end

function BattlePlayerUnit.SetFleetVO(arg_42_0, arg_42_1)
	arg_42_0._fleet = arg_42_1
	arg_42_0._subRaidLine, arg_42_0._subRetreatLine = arg_42_0._fleet:GetSubmarineBaseLine()
end

function BattlePlayerUnit.GetTemplate(arg_43_0)
	return arg_43_0._tmpData
end

function BattlePlayerUnit.GetGroupID(arg_44_0)
	local var_44_0 = arg_44_0:GetTemplateID()

	return BattleDataFunction.GetPlayerShipModelFromID(var_44_0).group_type
end

function BattlePlayerUnit.GetRarity(arg_45_0)
	return arg_45_0._rarity or arg_45_0._tmpData.rarity
end

function BattlePlayerUnit.GetIntimacy(arg_46_0)
	return arg_46_0._intimacy or 0
end

function BattlePlayerUnit.GetAutoPilotPreference(arg_47_0)
	return arg_47_0._personality
end

function BattlePlayerUnit.GetFleetVO(arg_48_0)
	return arg_48_0._fleet
end

function BattlePlayerUnit.InitCldComponent(arg_49_0)
	BattlePlayerUnit.super.InitCldComponent(arg_49_0)

	local var_49_0 = {
		type = BattleConst.CldType.SHIP,
		IFF = arg_49_0:GetIFF(),
		UID = arg_49_0:GetUniqueID(),
		Mass = BattleConst.CldMass.L2
	}

	arg_49_0._cldComponent:SetCldData(var_49_0)
end

function BattlePlayerUnit.AddPointAirStrike(arg_50_0, arg_50_1, arg_50_2, arg_50_3)
	local var_50_0 = arg_50_0:AddWeapon(arg_50_1, {}, nil, 1, -1)

	arg_50_0:GetFleetVO():GetChargeWeaponVO():AppendWeapon(var_50_0)

	if arg_50_3 then
		var_50_0:OverHeat()
		var_50_0:EnterCoolDown()
	end

	arg_50_0:GetFleetVO():GetChargeWeaponVO():DispatchCountChange()
	arg_50_0:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_POINT_AIR_STRIKE, {
		weapon = var_50_0
	}))

	return var_50_0
end
