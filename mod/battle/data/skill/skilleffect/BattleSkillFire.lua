ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleSkillFire = class("BattleSkillFire", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillFire = BattleSkillFire
BattleSkillFire.__name = "BattleSkillFire"

-- 核心SkillEffect之一
-- 此类SkillEffect会提供给caster一个临时武器，并让这个武器开火(SingleFire)
-- 使用例: 几乎所有的弹幕都是这样实现的
function BattleSkillFire.Ctor(self, template, level)
	BattleSkillFire.super.Ctor(self, template, level)

	self._weaponID = self._tempData.arg_list.weapon_id
	self._emitter = self._tempData.arg_list.emitter
	self._useSkin = self._tempData.arg_list.useSkin
	self._equipIndex = self._tempData.arg_list.equip_index or -1
	self._atkAttrConvert = self._tempData.arg_list.attack_attribute_convert
end

function BattleSkillFire.SetWeaponSkin(self, skinID)
	self._modelID = skinID
end

function BattleSkillFire.IsFinaleEffect(self)
	return true
end

function BattleSkillFire.DoDataEffect(self, caster, target)
	if self._weapon == nil then
		-- 在caster的equipIndex位置上创建一个临时武器
		-- 临时武器一般不指定index，默认就是-1
		-- 所以很多针对index = -1的effect，指的是对临时武器的effect
		self._weapon = ys.Battle.BattleDataFunction.CreateWeaponUnit(self._weaponID, caster, nil, self._equipIndex)

		if BATTLE_DEBUG and (self._weapon:GetType() == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or self._weapon:GetType() == BattleConst.EquipmentType.STRIKE_AIRCRAFT) then
			self._weapon:GetATKAircraftList()
			self._weapon:GetDEFAircraftList()
		end

		if self._modelID then
			self._weapon:SetModelID(self._modelID)
		elseif self._useSkin then
			local priorityWeaponSkin = caster:GetPriorityWeaponSkin()

			if priorityWeaponSkin then
				self._weapon:SetModelID(BattleDataFunction.GetEquipSkin(priorityWeaponSkin))
			end
		end

		local args = {
			weapon = self._weapon
		}
		-- 对应在BattleCharacter.onNewWeapon
		-- 主要用于进一步触发临时武器上的事件
		local createWeaponEvent = ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_TEMPORARY_WEAPON, args)

		caster:DispatchEvent(createWeaponEvent)
	end

	local function extraStopFunc()
		self._weapon:Clear()

		if self._finaleCallback then
			self._finaleCallback()
		end
	end

	if self._atkAttrConvert then
		-- 转换为：min(attr / A, B)
		self._weapon:SetAtkAttrTrasnform(self._atkAttrConvert.attr_type, self._atkAttrConvert.A, self._atkAttrConvert.B)
	end

	self._weapon:updateMovementInfo()
	-- SingleFire即单次武器开火
	-- 所以对应的武器的reload_max没有意义
	self._weapon:SingleFire(target, self._emitter, extraStopFunc)
end

function BattleSkillFire.DoDataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster)
end

function BattleSkillFire.Clear(self)
	BattleSkillFire.super.Clear(self)

	if self._weapon and not self._weapon:GetHost():IsAlive() then
		self._weapon:Clear()
	end
end

function BattleSkillFire.Interrupt(self)
	BattleSkillFire.super.Interrupt(self)

	if self._weapon then
		self._weapon:Cease()
		self._weapon:Clear()
	end
end

function BattleSkillFire.GetDamageSum(self)
	local damageSum = 0

	if not self._weapon then
		damageSum = 0
	-- 对于舰载机/拦截机，计算的是携带的(攻击)武器的总伤害
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
