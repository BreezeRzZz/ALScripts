ys = ys or {}

local ys = ys
local BattleBuffHP = class("BattleBuffHP", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffHP = BattleBuffHP
BattleBuffHP.__name = "BattleBuffHP"

-- 核心BuffEffect之一
-- 此类BuffEffect为单位恢复HP. 各种治疗技能基本都是这个BuffEffect
-- 使用非常广泛, 不列举
function BattleBuffHP.Ctor(self, effectData)
	BattleBuffHP.super.Ctor(self, effectData)
end

function BattleBuffHP.SetArgs(self, owner, buff)
	self._number = self._tempData.arg_list.number or 0
	self._numberBase = self._number
	self._currentHPRatio = 0

	if self._tempData.arg_list.currentHPRatio then
		self._currentHPRatio = self._tempData.arg_list.currentHPRatio * 0.0001
	end

	local _, ownerMaxHP = owner:GetHP()
	local _, casterMaxHP = self._caster:GetHP()

	self._maxHPRatio = self._tempData.arg_list.maxHPRatio or 0
	self._maxHPNumber = ownerMaxHP * self._maxHPRatio
	self._castMaxHPRatio = self._tempData.arg_list.casterMaxHPRatio or 0
	self._castMaxHPNumber = self._castMaxHPRatio * casterMaxHP
	self._castHPRatio = self._tempData.arg_list.casterHPRatio or 0
	self._weaponType = self._tempData.arg_list.weaponType
	self._damageConvert = 0

	if self._tempData.arg_list.damageConvertRatio then
		self._damageConvert = self._tempData.arg_list.damageConvertRatio * 0.0001
	end

	self._incorruptible = self._tempData.arg_list.incorrupt
end

function BattleBuffHP.onBulletHit(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	if not self:bulletTagRequire(args.bulletTag) then
		return
	end

	if not self:victimRequire(args.target, owner) then
		return
	end

	local healingRate = owner:GetAttrByName("healingRate")
	local target = args.target

	if not self._weaponType then
		local number = self._number
		local isHeal = number > 0

		if isHeal then
			number = math.floor(number * healingRate)
		end

		local extraInfo = {
			isMiss = false,
			isCri = false,
			isHeal = isHeal
		}

		target:UpdateHP(number, extraInfo)
	elseif args.weaponType == self._weaponType then
		-- 由伤害转化的治疗
		-- 使用例: 吸血鬼1技能
		local damageConvertNumber = math.floor(args.damage * self._damageConvert * healingRate)
		local extraInfo = {
			isMiss = false,
			isCri = false,
			isHeal = true,
			incorrupt = self._incorruptible
		}

		owner:UpdateHP(damageConvertNumber, extraInfo)
	end
end

function BattleBuffHP.onAttach(self, owner, buff)
	onDelayTick(function()
		BattleBuffHP.super.onAttach(self, owner, buff)
	end, 0.03)
end

function BattleBuffHP.onTrigger(self, owner, buff)
	local number = self:CalcNumber(owner)
	local isHeal = number > 0

	if isHeal then
		local healingRate = owner:GetAttrByName("healingRate")

		number = math.floor(number * healingRate)
	end

	local extraInfo = {
		isMiss = false,
		isCri = false,
		isHeal = isHeal,
		incorrupt = self._incorruptible
	}

	owner:UpdateHP(number, extraInfo)
end

function BattleBuffHP.CalcNumber(self, owner)
	local currentHP = owner:GetHP()
	local casterCurrentHP = self._caster:GetHP()
	local casterHealingEnhancement = self._caster:GetAttrByName("healingEnhancement") + 1

	return math.floor((currentHP * self._currentHPRatio + self._maxHPNumber + self._number + self._castMaxHPNumber + casterCurrentHP * self._castHPRatio) * casterHealingEnhancement)
end
