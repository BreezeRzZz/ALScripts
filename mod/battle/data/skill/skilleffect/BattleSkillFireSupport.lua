ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleSkillFireSupport = class("BattleSkillFireSupport", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillFireSupport = BattleSkillFireSupport
BattleSkillFireSupport.__name = "BattleSkillFireSupport"

function BattleSkillFireSupport.Ctor(self, template)
	BattleSkillFireSupport.super.Ctor(self, template, lv)

	self._weaponID = self._tempData.arg_list.weapon_id
	self._supportTargetFilter = self._tempData.arg_list.supportTarget.targetChoice
	self._supportTargetArgList = self._tempData.arg_list.supportTarget.arg_list
end

function BattleSkillFireSupport.DoDataEffect(self, caster, target)
	if self._weapon == nil then
		local candidateList
		-- 常用的一般是TargetPlayerAidUnit+TargetShipTag的组合
		for _, supportTargetType in ipairs(self._supportTargetFilter) do
			candidateList = ys.Battle.BattleTargetChoise[supportTargetType](caster, self._supportTargetArgList, candidateList)
		end
		-- 原来standHost是用来提供跨队武器的属性用于计算的？
		local standHost = candidateList[1]

		self._weapon = ys.Battle.BattleDataFunction.CreateWeaponUnit(self._weaponID, caster)

		if BATTLE_DEBUG and (self._weapon:GetType() == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or self._weapon:GetType() == BattleConst.EquipmentType.STRIKE_AIRCRAFT) then
			self._weapon:GetATKAircraftList()
		end

		if standHost then
			self._weapon:SetStandHost(standHost)
		end

		local args = {
			weapon = self._weapon
		}
		local createWeaponEvent = ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_TEMPORARY_WEAPON, args)

		caster:DispatchEvent(createWeaponEvent)
	end

	local function extraStopFunc()
		self._weapon:Clear()
	end

	self._weapon:updateMovementInfo()
	self._weapon:SingleFire(target, self._emitter, extraStopFunc)
end

function BattleSkillFireSupport.DoDataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster)
end

function BattleSkillFireSupport.Clear(self)
	BattleSkillFireSupport.super.Clear(self)

	if self._weapon and not self._weapon:GetHost():IsAlive() then
		self._weapon:Clear()
	end
end

function BattleSkillFireSupport.Interrupt(self)
	BattleSkillFireSupport.super.Interrupt(self)

	if self._weapon then
		self._weapon:Cease()
		self._weapon:Clear()
	end
end

function BattleSkillFireSupport.GetDamageSum(self)
	local damageSum = 0

	if not self._weapon then
		damageSum = 0
	elseif self._weapon:GetType() == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or self._weapon:GetType() == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
		for _, aircraft in ipairs(self._weapon:GetATKAircraftList()) do
			local weaponList = aircraft:GetWeapon()

			for _, weapon in ipairs(weaponList) do
				damageSum = damageSum + weapon:GetDamageSUM()
			end
		end
	else
		damageSum = self._weapon:GetDamageSUM()
	end

	return damageSum
end
