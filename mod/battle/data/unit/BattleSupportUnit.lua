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

			local function configWeapon(weaponID, equipLabels, equipSkin)
				local weaponType = BattleDataFunction.GetWeaponPropertyDataFromID(weaponID).type

				if weaponType == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or weaponType == BattleConst.EquipmentType.TORPEDO then
					local baseCount = base_list[equipIndex]

					for _ = 1, baseCount do
						local weapon = self:AddWeapon(weaponID, equipLabels, equipSkin, proficiency, equipIndex)
						local _ = weapon:GetTemplateData().type

						if equipmentInfo.equipment then
							weapon:SetSrcEquipmentID(equipmentInfo.equipment.id)
						end
					end
				end
			end

			if equipmentInfo.equipment and #equipmentInfo.equipment.weapon_id > 0 then
				if equipmentInfo.equipment.type == EquipType.FighterAircraft or equipmentInfo.equipment.type == EquipType.SubmarineTorpedo then
					local _ = equipmentInfo.equipment.weapon_id

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

				if equipment.type == EquipType.FighterAircraft or equipment.type == EquipType.SubmarineTorpedo then
					configWeapon(equipID, equipment.label)
				end
			end
		end
	end

	-- 此处用默认装备数量代指普通装备的数量，作为固定装备索引的偏移
	-- 也即固定装备的索引一般是4,5,6...，从而可以查找固定装备的效率
	local defaultEquipNum = #default_equip_list
	-- 固定装备(魔法装备)
	local fix_equip_list = self._tmpData.fix_equip_list

	for fixIndex, fixEquipID in ipairs(fix_equip_list) do
		if fixEquipID and fixEquipID ~= -1 then
			local fixEquipType = BattleDataFunction.GetWeaponPropertyDataFromID(fixEquipID).type

			if fixEquipType == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or fixEquipType == BattleConst.EquipmentType.TORPEDO then
				local fixProficiency = proficiencyList[fixIndex + defaultEquipNum] or 1

				self:AddWeapon(fixEquipID, nil, nil, fixProficiency, fixIndex + defaultEquipNum):SetFixedFlag()
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

	weapon:SetSupportWeapon()
	self:AddAutoWeapon(weapon)

	if equipSkin and equipSkin ~= 0 then
		weapon:SetSkinData(equipSkin)
		self:SetPriorityWeaponSkin(equipSkin)
	end

	return weapon
end
