ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleBuffNewWeapon = class("BattleBuffNewWeapon", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffNewWeapon = BattleBuffNewWeapon
BattleBuffNewWeapon.__name = "BattleBuffNewWeapon"

-- 核心BuffEffect之一
-- 此类BuffEffect会给持有者添加一个新的自动武器(常规武器, 与技能武器/临时武器的概念区分)
-- 使用例很多，不列举
function BattleBuffNewWeapon.Ctor(self, effectData)
	BattleBuffNewWeapon.super.Ctor(self, effectData)
end

function BattleBuffNewWeapon.SetArgs(self, owner, buff)
	self._weaponID = self._tempData.arg_list.weapon_id
	self._reverse = self._tempData.arg_list.reverse
end

function BattleBuffNewWeapon.onAttach(self, owner, buff)
	if self._reverse then
		owner:RemoveAutoWeaponByWeaponID(self._weaponID)
	elseif BattleDataFunction.GetWeaponPropertyDataFromID(self._weaponID).type == BattleConst.EquipmentType.FLEET_ANTI_AIR then
		owner:AddWeapon(self._weaponID)
		owner:GetFleetVO():GetFleetAntiAirWeapon():FlushCrewUnit(owner)
	else
		self._weapon = owner:AddNewAutoWeapon(self._weaponID)
	end
end

function BattleBuffNewWeapon.onRemove(self, owner, buff)
	if self._reverse then
		owner:AddNewAutoWeapon(self._weaponID)
	elseif self._weapon then
		if BattleDataFunction.GetWeaponPropertyDataFromID(self._weaponID).type == BattleConst.EquipmentType.FLEET_ANTI_AIR then
			owner:RemoveWeapon(self._weaponID)
			owner:RemoveFleetAntiAirWeapon(self._weapon)
			owner:GetFleetVO():GetFleetAntiAirWeapon():FlushCrewUnit(owner)
		else
			self._weapon:Clear()
			owner:RemoveAutoWeapon(self._weapon)
		end
	end
end

function BattleBuffNewWeapon.Dispose(self)
	BattleBuffNewWeapon.super.Dispose(self)

	self._weapon = nil
end
