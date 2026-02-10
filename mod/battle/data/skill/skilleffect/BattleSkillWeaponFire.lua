ys = ys or {}

local ys = ys
local BattleSkillWeaponFire = class("BattleSkillWeaponFire", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillWeaponFire = BattleSkillWeaponFire
BattleSkillWeaponFire.__name = "BattleSkillWeaponFire"

-- 核心SkillEffect之一
-- 此类SkillEffect的作用是让单位使用特定武器再次开火一次(SingleFire)
function BattleSkillWeaponFire.Ctor(self, template, level)
	BattleSkillWeaponFire.super.Ctor(self, template, level)

	self._weaponType = self._tempData.arg_list.weaponType
	self._useTempBullet = self._tempData.arg_list.preShiftBullet
end

function BattleSkillWeaponFire.DoDataEffect(self, caster, target)
	local weaponList = self:_GetWeapon(caster)

	for _, weapon in ipairs(weaponList) do
		weapon:SingleFire(target, nil, nil, self._useTempBullet)
	end
end

function BattleSkillWeaponFire.DoDataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster, nil)
end

function BattleSkillWeaponFire._GetWeapon(self, caster)
	local weaponList = {}
	-- 分为五种情况: 1. ChargeWeapon 2. TorpedoWeapon 3. AirAssist 4. Aircraft 5. OtherWeapon
	-- ChargeWeapon: 立刻再次跨射一次
	-- TorpedoWeapon: 立刻再次发射一次鱼雷
	-- AirAssist: 立刻再次进行空袭
	-- Aircraft: 立刻再次发射所有舰载机
	-- OtherWeapon: 立刻再次发射一次自动武器(一般是前排的主炮/后排的副炮)
	if self._weaponType == "ChargeWeapon" then
		table.insert(weaponList, caster:GetChargeList()[1])
	elseif self._weaponType == "TorpedoWeapon" then
		table.insert(weaponList, caster:GetTorpedoList()[1])
	elseif self._weaponType == "AirAssist" then
		table.insert(weaponList, caster:GetAirAssistList()[1])
	elseif self._weaponType == "Aircraft" then
		local hiveList = caster:GetHiveList()

		for _, hive in ipairs(hiveList) do
			table.insert(weaponList, hive)
		end
	else
		table.insert(weaponList, caster:GetAutoWeapons()[1])
	end

	return weaponList
end
