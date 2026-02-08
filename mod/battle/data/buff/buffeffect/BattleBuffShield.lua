ys = ys or {}

local ys = ys

ys.Battle.BattleBuffShield = class("BattleBuffShield", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShield.__name = "BattleBuffShield"

local BattleBuffShield = ys.Battle.BattleBuffShield

function BattleBuffShield.Ctor(self, effectData)
	BattleBuffShield.super.Ctor(self, effectData)
end

function BattleBuffShield.GetEffectAttachData(self)
	return self._shield
end

function BattleBuffShield.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._number = arg_list.number or 0
	self._maxHPRatio = arg_list.maxHPRatio or 0
	self._casterMaxHPRatio = arg_list.casterMaxHPRatio or 0
	self._shield = self:CalcNumber(owner)
end

function BattleBuffShield.onStack(self, owner, buff)
	self._shield = self:CalcNumber(owner)
end

-- 多个不同Buff的BattleBuffShield受到伤害时，由于没有明确规定如何处理
-- 因此实际是非常混沌的. 类似BattleBuffHPLink有多个的时候一样, 可能是依靠内部Buff ID的排序来决定先后顺序的(未确定)
function BattleBuffShield.onTakeDamage(self, owner, buff, args)
	if self:damageCheck(args) then
		local damage = args.damage

		self._shield = self._shield - damage

		if self._shield > 0 then
			args.damage = 0
		else
			-- 受到溢出伤害
			args.damage = -self._shield

			buff:SetToCancel()
		end
	end
end

function BattleBuffShield.CalcNumber(self, owner)
	local _, ownerMaxHP = owner:GetHP()
	local _, casterMaxHP = self._caster:GetHP()
	local shieldNumber = ownerMaxHP * self._maxHPRatio + self._number + self._casterMaxHPRatio * casterMaxHP

	return math.max(0, math.floor(shieldNumber))
end
