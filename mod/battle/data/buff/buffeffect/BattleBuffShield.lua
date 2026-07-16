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

--- 设置护盾参数
--- 护盾量 = owner当前HP * currentHPRatio + owner最大HP * maxHPRatio
---         + caster当前HP * casterCurretnHPRatio + caster最大HP * casterMaxHPRatio
---         + number(固定值)
--- @param self BattleBuffShield
--- @param owner BattleUnit
--- @param buff BattleBuff
function BattleBuffShield.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._number = arg_list.number or 0
	self._maxHPRatio = arg_list.maxHPRatio or 0
	self._curretHPRatio = arg_list.currentHPRatio or 0
	self._casterMaxHPRatio = arg_list.casterMaxHPRatio or 0
	self._casterCurrentHPRatio = arg_list.casterCurretnHPRatio or 0
	self._shield = self:CalcNumber(owner)
end

function BattleBuffShield.onStack(self, owner, buff)
	self._shield = self:CalcNumber(owner)
end

--- 受到伤害时的护盾吸收逻辑
--- 多个不同Buff的BattleBuffShield受到伤害时，由于没有明确规定如何处理
--- 因此实际是非常混沌的. 类似BattleBuffHPLink有多个的时候一样, 可能是依靠内部Buff ID的排序来决定先后顺序的(未确定)
--- @param self BattleBuffShield
--- @param owner BattleUnit
--- @param buff BattleBuff
--- @param args table {damage, ignoreShield, ...}
function BattleBuffShield.onTakeDamage(self, owner, buff, args)
	if not args.ignoreShield and self:damageCheck(args) then
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

--- 计算护盾总量
--- @param self BattleBuffShield
--- @param owner BattleUnit
--- @return number shieldNumber
function BattleBuffShield.CalcNumber(self, owner)
	local ownerCurrentHP, ownerMaxHP = owner:GetHP()
	local casterCurrentHP, casterMaxHP = self._caster:GetHP()
	local shieldNumber = ownerMaxHP * self._maxHPRatio
		+ ownerCurrentHP * self._curretHPRatio
		+ casterMaxHP * self._casterMaxHPRatio
		+ casterCurrentHP * self._casterCurrentHPRatio
		+ self._number

	return math.max(0, math.floor(shieldNumber))
end
