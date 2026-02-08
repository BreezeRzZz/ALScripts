ys = ys or {}

local ys = ys

ys.Battle.BattleBuffShiftWeapon = class("BattleBuffShiftWeapon", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShiftWeapon.__name = "BattleBuffShiftWeapon"

local BattleBuffShiftWeapon = ys.Battle.BattleBuffShiftWeapon

-- 此类BuffEffect将根据配置表参数将目标的武器替换为指定武器
-- 新武器会继承原武器的许多属性（如装备标签、皮肤ID、武器效率等）
-- 使用例: 天雷的装备技能
function BattleBuffShiftWeapon.Ctor(self, effectData)
	BattleBuffShiftWeapon.super.Ctor(self, effectData)
end

function BattleBuffShiftWeapon.SetArgs(self, owner, buff)
	self._detachID = self._tempData.arg_list.detach_id
	self._attachID = self._tempData.arg_list.weapon_id
	self._detachLabel = self._tempData.arg_list.detach_labelList
	self._fixedEnabled = self._tempData.arg_list.fixed
	self._initCD = self._tempData.arg_list.initial_over_heat
end

function BattleBuffShiftWeapon.onAttach(self, owner, buff)
	self:shiftWeapon(owner)
end

function BattleBuffShiftWeapon.shiftWeapon(self, owner)
	local originalWeapon = self:removeWeapon(owner)

	if not originalWeapon or originalWeapon:IsFixedWeapon() and not self._fixedEnabled then
		return
	end

	local originalEquipLabel = originalWeapon:GetEquipmentLabel()
	local originalSkinID = originalWeapon:GetSkinID()
	local originalPotential = originalWeapon:GetPotential()
	local originalEquipIndex = originalWeapon:GetEquipmentIndex()
	local index = 0
	local weaponCDList = {}

	while originalWeapon ~= nil do
		table.insert(weaponCDList, originalWeapon:GetModifyInitialCD())

		index = index + 1
		originalWeapon = self:removeWeapon(owner)
	end

	for weaponIndex = 1, index do
		local newWeapon = owner:AddWeapon(self._attachID, originalEquipLabel, originalSkinID, originalPotential, originalEquipIndex)

		if weaponCDList[weaponIndex] then
			newWeapon:SetModifyInitialCD()
		end
	end
end

function BattleBuffShiftWeapon.removeWeapon(self, owner)
	local weapon

	if self._detachID then
		weapon = owner:RemoveWeapon(self._detachID)
	elseif self._detachLabel then
		weapon = owner:RemoveWeaponByLabel(self._detachLabel)
	end

	return weapon
end
