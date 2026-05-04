ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConst = ys.Battle.BattleConst
local EquipmentType = BattleConst.EquipmentType
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleSubUnit = class("BattleSubUnit", ys.Battle.BattlePlayerUnit)
ys.Battle.BattleSubUnit.__name = "BattleSubUnit"

local BattleSubUnit = ys.Battle.BattleSubUnit

--- @class BattleSubUnit
--- @param uid number: 单位唯一ID
--- @param iff number: 阵营
--- @return nil
--- 构造函数
function BattleSubUnit.Ctor(self, uid, iff)
	BattleSubUnit.super.Ctor(self, uid, iff)

	self._type = BattleConst.UnitType.PLAYER_UNIT
end

--- @class BattleSubUnit
--- @param equipmentList table: 装备列表
--- @return nil
--- 设置武器：潜艇的特殊武器逻辑，处理鱼雷弹药分配
--- 1. 统计所有装备的鱼雷弹药总量
--- 2. 创建非鱼雷武器(通过BattlePlayerUnit.AddWeapon)
--- 3. 将鱼雷武器收集到列表，按弹药分配逐个创建一次性鱼雷(AddDisposableTorpedo)
function BattleSubUnit.setWeapon(self, equipmentList)
	local defaultEquipList = self._tmpData.default_equip_list
	local baseList = self._tmpData.base_list
	local proficiencyList = self._proficiencyList
	local preloadCount = self._tmpData.preload_count
	local torpedoAmmoTotal = 0

	-- 统计所有装备提供的鱼雷弹药总量
	for iter_2_0, iter_2_1 in ipairs(equipmentList) do
		if iter_2_0 > Ship.WEAPON_COUNT and iter_2_1 then
			torpedoAmmoTotal = torpedoAmmoTotal + iter_2_1.torpedoAmmo
		end
	end

	-- 收集需要一次性创建的鱼雷武器
	local torpedoWeaponList = {}

	for iter_2_2, iter_2_3 in ipairs(equipmentList) do
		if iter_2_3 and iter_2_3.skin and iter_2_3.skin ~= 0 and Equipment.IsOrbitSkin(iter_2_3.skin) then
			self._orbitSkinIDList = self._orbitSkinIDList or {}

			table.insert(self._orbitSkinIDList, iter_2_3.skin)
		end

		if iter_2_2 <= Ship.WEAPON_COUNT then
			local proficiency = proficiencyList[iter_2_2]

			-- 内嵌函数：处理武器创建，返回鱼雷弹药数(如果是鱼雷)或false
			local function processWeapon(weaponID, label, skin)
				local weaponProperty = BattleDataFunction.GetWeaponPropertyDataFromID(weaponID)

				-- 如果是鱼雷武器，返回弹药数而非创建武器
				if weaponProperty.type == BattleConst.EquipmentType.TORPEDO then
					return weaponProperty.torpedo_ammo
				else
					local baseCount = baseList[iter_2_2]

					for iter_3_0 = 1, baseCount do
						self:AddWeapon(weaponID, label, skin, proficiency, iter_2_2)
					end

					return false
				end
			end

			if iter_2_3.equipment then
				local weaponIDs = iter_2_3.equipment.weapon_id

				for iter_2_4, iter_2_5 in ipairs(weaponIDs) do
					if iter_2_5 and iter_2_5 ~= -1 then
						local ammo = processWeapon(iter_2_5, iter_2_3.equipment.label, iter_2_3.skin)

						if ammo then
							table.insert(torpedoWeaponList, {
								id = iter_2_5,
								ammo = ammo,
								index = iter_2_2
							})
						end
					end
				end
			else
				local defaultWeaponID = defaultEquipList[iter_2_2]
				local ammo = processWeapon(defaultWeaponID)

				if ammo then
					table.insert(torpedoWeaponList, {
						id = defaultWeaponID,
						ammo = ammo,
						index = iter_2_2
					})
				end
			end
		end
	end

	-- 内嵌函数：添加一次性鱼雷武器
	local function addTorpedo(weaponID, equipIndex)
		local equipment = equipmentList[equipIndex]
		local label
		local skin

		if equipment.equipment then
			label = equipment.equipment.label
			skin = equipment.skin
		end

		local proficiency = proficiencyList[equipIndex]

		self:AddDisposableTorpedo(weaponID, label, skin, proficiency, equipIndex):SetModifyInitialCD()
	end

	-- 循环分配鱼雷弹药：直到所有弹药用完
	repeat
		local remainingAmmo = 0

		for iter_2_6, iter_2_7 in ipairs(torpedoWeaponList) do
			-- 当前武器弹药不足时，从总额外弹药中补充
			if iter_2_7.ammo <= 0 and torpedoAmmoTotal > 0 then
				iter_2_7.ammo = iter_2_7.ammo + 1
				torpedoAmmoTotal = torpedoAmmoTotal - 1
			end

			if iter_2_7.ammo > 0 then
				addTorpedo(iter_2_7.id, iter_2_7.index)

				iter_2_7.ammo = iter_2_7.ammo - 1
			end

			remainingAmmo = remainingAmmo + iter_2_7.ammo
		end
	until remainingAmmo == 0 and torpedoAmmoTotal == 0
end

--- @class BattleSubUnit
--- @param weaponID number: 武器ID
--- @param label string: 装备标签
--- @param skin number: 皮肤ID
--- @param proficiency number: 武器熟练度
--- @param equipIndex number: 装备槽位索引
--- @return BattleWeaponUnit: 创建的武器单位
--- 添加一次性鱼雷武器：创建DISPOSABLE_TORPEDO类型的WeaponUnit并加入手动鱼雷队列
function BattleSubUnit.AddDisposableTorpedo(self, weaponID, label, skin, proficiency, equipIndex)
	local weapon = ys.Battle.BattleDataFunction.CreateWeaponUnit(weaponID, self, proficiency, equipIndex, BattleConst.EquipmentType.DISPOSABLE_TORPEDO)

	self._totalWeapon[#self._totalWeapon + 1] = weapon

	if label then
		weapon:SetEquipmentLabel(label)
	end

	self._manualTorpedoList[#self._manualTorpedoList + 1] = weapon

	self._weaponQueue:AppendManualTorpedo(weapon)

	if skin and skin ~= 0 then
		weapon:SetSkinData(skin)
		self:SetPriorityWeaponSkin(skin)
	end

	return weapon
end
