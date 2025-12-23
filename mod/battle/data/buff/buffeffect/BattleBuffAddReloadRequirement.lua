ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAttr = ys.Battle.BattleAttr
local BattleBuffAddReloadRequirement = class("BattleBuffAddReloadRequirement", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddReloadRequirement = BattleBuffAddReloadRequirement
BattleBuffAddReloadRequirement.__name = "BattleBuffAddReloadRequirement"

function BattleBuffAddReloadRequirement.Ctor(self, effectData)
	BattleBuffAddReloadRequirement.super.Ctor(self, effectData)
end

function BattleBuffAddReloadRequirement.SetArgs(self, owner, buff)
	self._weaponIndex = self._tempData.arg_list.index
	self._weaponType = self._tempData.arg_list.type
	self._value = self._tempData.arg_list.number or 0
	self._convertAttr = self._tempData.arg_list.convert_attr
	self._convertValue = self._tempData.arg_list.convert_value
end

function BattleBuffAddReloadRequirement.onAttach(self, owner, buff)
	local targetWeaponList = {}

	if self._weaponType then
		local weaponList

		if self._weaponType == BattleConst.EquipmentType.POINT_HIT_AND_LOCK then
			weaponList = owner:GetChargeList()
		elseif self._weaponType == BattleConst.EquipmentType.MANUAL_TORPEDO then
			weaponList = owner:GetTorpedoList()
		elseif self._weaponType == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or self._weaponType == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
			weaponList = owner:GetHiveList()
		elseif self._weaponType == BattleConst.EquipmentType.AIR_ASSIST then
			weaponList = owner:GetAirAssistList()
		else
			weaponList = owner:GetAutoWeapons()
		end

		if weaponList then
			for _, weapon in ipairs(weaponList) do
				targetWeaponList[#targetWeaponList + 1] = weapon
			end
		end
	elseif self._weaponIndex then
		local totalWeaponList = owner:GetTotalWeapon()

		for _, weapon in ipairs(totalWeaponList) do
			if weapon:GetEquipmentIndex() == self._weaponIndex then
				targetWeaponList[#targetWeaponList + 1] = weapon
			end
		end
	else
		assert(false, "BattleBuffAddReloadRequirement：缺少指定类型或索引")
	end

	for _, weapon in ipairs(targetWeaponList) do
		weapon:AppendReloadFactor(buff, self:calcFactor(buff:GetCaster()))
		-- 计算全部Buff的装填因子的总效果
		local reloadFactorList = weapon:GetReloadFactorList()
		local baseReloadFactor = 1
		-- 均为加算
		for _, reloadFactor in pairs(reloadFactorList) do
			baseReloadFactor = baseReloadFactor + reloadFactor
		end

		weapon:FlushReloadMax(baseReloadFactor)
	end

	self._targetWeaponList = targetWeaponList
end

function BattleBuffAddReloadRequirement.onRemove(self, owner, buff)
	for _, weapon in ipairs(self._targetWeaponList) do
		weapon:RemoveReloadFactor(buff)

		local reloadFactorList = weapon:GetReloadFactorList()
		local baseReloadFactor = 1

		for _, reloadFactor in pairs(reloadFactorList) do
			baseReloadFactor = baseReloadFactor + reloadFactor
		end

		weapon:FlushReloadMax(baseReloadFactor)
	end
end

function BattleBuffAddReloadRequirement.calcFactor(self, owner)
	local value = self._value
	local convertedValue = 0

	if self._convertAttr == nil then
		-- block empty
	elseif self._convertAttr == "HPRate" or self._convertAttr == "DMGRate" then
		convertedValue = BattleAttr.GetCurrent(owner, self._convertAttr) * self._convertValue
	else
		convertedValue = BattleAttr.GetBase(owner, self._convertAttr) * self._convertValue
	end

	return value + convertedValue
end
