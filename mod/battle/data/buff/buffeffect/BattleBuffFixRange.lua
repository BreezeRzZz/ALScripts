ys = ys or {}

local ys = ys

ys.Battle.BattleBuffFixRange = class("BattleBuffFixRange", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffFixRange.__name = "BattleBuffFixRange"

local BattleBuffFixRange = ys.Battle.BattleBuffFixRange

-- 此类BuffEffect调整武器的索敌范围及其所有子弹的射程
-- 使用例: 近江1技能调整副炮的索敌范围和射程
function BattleBuffFixRange.Ctor(self, effectData)
	BattleBuffFixRange.super.Ctor(self, effectData)
end

function BattleBuffFixRange.SetArgs(self, owner, buff)
	self._weaponRange = self._tempData.arg_list.weaponRange
	self._bulletRange = self._tempData.arg_list.bulletRange
	self._minRange = self._tempData.arg_list.minRange
	self._bulletRangeOffset = self._tempData.arg_list.bulletRangeOffset
end

function BattleBuffFixRange.onAttach(self, owner)
	if self._weaponRange or self._bulletRange or self._bulletRangeOffset then
		self:updateBulletRange(owner, self._weaponRange, self._bulletRange, self._minRange, self._bulletRangeOffset)
	end
end

function BattleBuffFixRange.onRemove(self, owner)
	self:updateBulletRange(owner)
end

function BattleBuffFixRange.updateBulletRange(self, target, weaponRange, bulletRange, minRange, bulletRangeOffset)
	local weaponList = target:GetAllWeapon()

	for _, weapon in ipairs(weaponList) do
		local equipIndex = weapon:GetEquipmentIndex()

		if self._indexRequire == nil or table.contains(self._indexRequire, equipIndex) then
			weapon:FixWeaponRange(weaponRange, bulletRange, minRange, bulletRangeOffset)
		end
	end
end
