ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConst = ys.Battle.BattleConst
local EquipmentType = BattleConst.EquipmentType
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleSupportUnit = class("BattleSupportUnit", ys.Battle.BattlePlayerUnit)
ys.Battle.BattleSupportUnit.__name = "BattleSupportUnit"

local BattleSupportUnit = ys.Battle.BattleSupportUnit

function BattleSupportUnit.Ctor(self, uid, iff)
	BattleSupportUnit.super.Ctor(self, uid, iff)

	self._type = BattleConst.UnitType.SUPPORT_UNIT
end

-- 在祖宗BattleUnit.SetEquipment中被调用
function BattleSupportUnit.setWeapon(self, equipmentList)
	local default_equip_list = self._tmpData.default_equip_list
	local base_list = self._tmpData.base_list
	local proficiencyList = self._proficiencyList
	local preload_count = self._tmpData.preload_count
	--- equipmentList: table<number, table<string, any>>
	for equipIndex, equipmentInfo in ipairs(equipmentList) do
		if equipmentInfo and equipmentInfo.skin and equipmentInfo.skin ~= 0 and Equipment.IsOrbitSkin(equipmentInfo.skin) then
			self._orbitSkinIDList = self._orbitSkinIDList or {}

			table.insert(self._orbitSkinIDList, equipmentInfo.skin)
		end
		-- WEAPON_COUNT = 3
		-- 不管什么船，至少得保留2个设备槽
		if equipIndex <= Ship.WEAPON_COUNT then
			local proficiency = proficiencyList[equipIndex]
			local preloadCount = preload_count[equipIndex]

			local function var_2_6(arg_3_0, arg_3_1, arg_3_2)
				local var_3_0 = var_0_1.GetWeaponPropertyDataFromID(arg_3_0).type

				if var_3_0 == var_0_4.EquipmentType.INTERCEPT_AIRCRAFT or var_3_0 == var_0_4.EquipmentType.TORPEDO then
					local var_3_1 = var_2_1[iter_2_0]

					for iter_3_0 = 1, var_3_1 do
						local var_3_2 = arg_2_0:AddWeapon(arg_3_0, arg_3_1, arg_3_2, var_2_4, iter_2_0)
						local var_3_3 = var_3_2:GetTemplateData().type

						if iter_2_1.equipment then
							var_3_2:SetSrcEquipmentID(iter_2_1.equipment.id)
						end
					end
				end
			end

			if iter_2_1.equipment and #iter_2_1.equipment.weapon_id > 0 then
				if iter_2_1.equipment.type == EquipType.FighterAircraft or iter_2_1.equipment.type == EquipType.SubmarineTorpedo then
					local var_2_7 = iter_2_1.equipment.weapon_id

					for _, weaponID in ipairs(weaponIDList) do
						-- 从weapon_property里拿
						local weaponType = BattleDataFunction.GetWeaponPropertyDataFromID(weaponID).type
						-- EQUIPMENT_ACTIVE_LIMITED_BY_TYPE = {[31] = {21},[32] = {20}}
						-- 这个东西是通用的限制，表示31类武器(MANUAL_MISSLE)只能装在舰种21(导驱M)上，32类武器(AUTO_MISSILE)只能装在舰种20(导驱V)上
						-- 这应该是因为，导弹装备会同时携带两种武器，一种是手动导弹，一种是自动导弹，所以要让不同的导驱舰只能装对应的导弹武器
						-- 在这里没影响，不用管
						local limitedShipType = BattleConfig.EQUIPMENT_ACTIVE_LIMITED_BY_TYPE[weaponType]

						if (not limitedShipType or table.contains(limitedShipType, self._tmpData.type)) and weaponID and weaponID ~= -1 then
							configWeapon(weaponID, equipmentInfo.equipment.label, equipmentInfo.skin)
						end
					end
				end
			else
				-- 如果没装备，用默认的
				local equipID = default_equip_list[equipIndex]
				-- equip_data_statistics
				local equipment = BattleDataFunction.GetWeaponDataFromID(equipID)

				if var_2_11.type == EquipType.FighterAircraft or var_2_11.type == EquipType.SubmarineTorpedo then
					var_2_6(var_2_10, var_2_11.label)
				end
			end
		end
	end

	-- 此处用默认装备数量代指普通装备的数量，作为固定装备索引的偏移
	-- 也即固定装备的索引一般是4,5,6...，从而可以查找固定装备的效率
	local defaultEquipNum = #default_equip_list
	-- 固定装备(魔法装备)
	local fix_equip_list = self._tmpData.fix_equip_list

	for iter_2_4, iter_2_5 in ipairs(var_2_13) do
		if iter_2_5 and iter_2_5 ~= -1 then
			local var_2_14 = var_0_1.GetWeaponPropertyDataFromID(iter_2_5).type

			if var_2_14 == var_0_4.EquipmentType.INTERCEPT_AIRCRAFT or var_2_14 == var_0_4.EquipmentType.TORPEDO then
				local var_2_15 = var_2_2[iter_2_4 + var_2_12] or 1

				arg_2_0:AddWeapon(iter_2_5, nil, nil, var_2_15, iter_2_4 + var_2_12):SetFixedFlag()
			end
		end
	end
end

function BattleSupportUnit.AddWeapon(self, weaponID, equipLabels, equipSkin, potential, index, arg_4_6)
	--- @type BattleSupportHiveUnit
	local weapon = BattleDataFunction.CreateWeaponUnit(weaponID, self, potential, index)

	self._totalWeapon[#self._totalWeapon + 1] = weapon

	if equipLabels then
		weapon:SetEquipmentLabel(equipLabels)
	end

	var_4_0:SetSupportWeapon()
	arg_4_0:AddAutoWeapon(var_4_0)

	if equipSkin and equipSkin ~= 0 then
		weapon:SetSkinData(equipSkin)
		self:SetPriorityWeaponSkin(equipSkin)
	end

	return weapon
end
