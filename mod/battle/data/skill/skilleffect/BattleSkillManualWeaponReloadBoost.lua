ys = ys or {}

local ys = ys
local BattleSkillManualWeaponReloadBoost = class("BattleSkillManualWeaponReloadBoost", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillManualWeaponReloadBoost = BattleSkillManualWeaponReloadBoost
BattleSkillManualWeaponReloadBoost.__name = "BattleSkillManualWeaponReloadBoost"

-- 此类SkillEffect的作用是为手动武器的冷却队列中的武器提供一个reload boost，减少它们的剩余冷却时间
-- 可以是固定的数值，也可以是一个比例
-- 注意与InstantCoolDown类似的, 实际只能作用于手动武器上
-- 使用例: 风云1技能
function BattleSkillManualWeaponReloadBoost.Ctor(self, template, level)
	BattleSkillManualWeaponReloadBoost.super.Ctor(self, template, level)

	self._weaponType = self._tempData.arg_list.weaponType
	self._boostValue = self._tempData.arg_list.value
	self._boostRate = self._tempData.arg_list.rate
end

function BattleSkillManualWeaponReloadBoost.DoDataEffect(self, caster, target)
	--- @type ManualWeaponQueue
	local weaponQueue = self.getWeaponQueueByType(caster, self._weaponType)

	if weaponQueue then
		local coolDownList = weaponQueue:GetCoolDownList()

		if self._boostValue then
			local boostValue = self._boostValue * -1

			for _, weapon in ipairs(coolDownList) do
				weapon:AppendReloadBoost(boostValue)
			end
		elseif self._boostRate then
			for _, weapon in ipairs(coolDownList) do
				local boostValue = weapon:GetReloadTimeByRate(self._boostRate) * -1

				weapon:AppendReloadBoost(boostValue)
			end
		end
	end
end

function BattleSkillManualWeaponReloadBoost.DoDataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster, nil)
end

function BattleSkillManualWeaponReloadBoost.getWeaponQueueByType(caster, weaponType)
	local weaponQueue

	if weaponType == "ChargeWeapon" then
		weaponQueue = caster:GetChargeQueue()
	elseif weaponType == "TorpedoWeapon" then
		weaponQueue = caster:GetTorpedoQueue()
	elseif weaponType == "AirAssist" then
		weaponQueue = caster:GetAirAssistQueue()
	end

	return weaponQueue
end
