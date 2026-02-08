ys = ys or {}

local ys = ys

ys.Battle.BattleBuffFixAmmo = class("BattleBuffFixAmmo", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffFixAmmo.__name = "BattleBuffFixAmmo"

local BattleBuffFixAmmo = ys.Battle.BattleBuffFixAmmo

-- 此BuffEffect会将指定Index的武器的Ammo固定为指定damageRate(对甲比例).
-- 实际并不会修改ammoType，所以针对ammoType的增伤等仍生效
-- 使用例: 圣黑之心的1技能
function BattleBuffFixAmmo.Ctor(self, effectData)
	BattleBuffFixAmmo.super.Ctor(self, effectData)
end

function BattleBuffFixAmmo.SetArgs(self, owner, buff)
	self._damageRate = self._tempData.arg_list.damage_rate
end

function BattleBuffFixAmmo.onAttach(self, owner, buff)
	self:updateAmmo(owner, self._damageRate)
end

function BattleBuffFixAmmo.onRemove(self, owner, buff)
	self:updateAmmo(owner)
end

function BattleBuffFixAmmo.updateAmmo(self, owner, damageRate)
	local weaponList = owner:GetAllWeapon()

	for _, index in ipairs(self._indexRequire) do
		for _, weapon in ipairs(weaponList) do
			if weapon:GetEquipmentIndex() == index then
				weapon:FixAmmo(damageRate)
			end
		end
	end
end
