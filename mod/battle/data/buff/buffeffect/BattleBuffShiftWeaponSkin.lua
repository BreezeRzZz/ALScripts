ys = ys or {}

local ys = ys

ys.Battle.BattleBuffShiftWeaponSkin = class("BattleBuffShiftWeaponSkin", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShiftWeaponSkin.__name = "BattleBuffShiftWeaponSkin"

local BattleBuffShiftWeaponSkin = ys.Battle.BattleBuffShiftWeaponSkin

-- 这类BuffEffect将(指定索引的)武器的皮肤替换为指定皮肤ID
-- 使用例: 随机单词生成器的装备技能
function BattleBuffShiftWeaponSkin.Ctor(self, effectData)
	BattleBuffShiftWeaponSkin.super.Ctor(self, effectData)
end

function BattleBuffShiftWeaponSkin.SetArgs(self, owner, buff)
	self._weaponIndex = self._tempData.arg_list.index
	self._skinID = self._tempData.arg_list.skin_id
end

function BattleBuffShiftWeaponSkin.onAttach(self, owner, buff)
	self:shiftWeaponSkin(owner)
end

function BattleBuffShiftWeaponSkin.onRemove(self, owner, buff)
	return
end

function BattleBuffShiftWeaponSkin.shiftWeaponSkin(self, owner)
	local weaponList = owner:GetAllWeapon()

	for _, equipIndex in ipairs(self._indexRequire) do
		for _, weapon in ipairs(weaponList) do
			if weapon:GetEquipmentIndex() == equipIndex then
				weapon:SetSkinData(self._skinID)
			end
		end
	end
end
