ys = ys or {}

local ys = ys

ys.Battle.BattleBuffFixDamage = class("BattleBuffFixDamage", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffFixDamage.__name = "BattleBuffFixDamage"

local BattleBuffFixDamage = ys.Battle.BattleBuffFixDamage

-- 此类BuffEffect以一定几率，将受到的伤害固定为一个值(或原伤害的一个比例)
-- 使用例: 雪风2技能
function BattleBuffFixDamage.Ctor(self, effectData)
	BattleBuffFixDamage.super.Ctor(self, effectData)
end

function BattleBuffFixDamage.SetArgs(self, owner, buff)
	self._fixProb = self._tempData.arg_list.rant or 10000
	self._fixValue = self._tempData.arg_list.value
	self._fixRate = self._tempData.arg_list.rate
end

function BattleBuffFixDamage.onBeforeTakeDamage(self, owner, buff, args)
	-- 检查伤害属性(damageAttr)和伤害原因(damageReason)
	if not self:damageCheck(args) then
		return
	end

	local baseDamage = args.damage
	local finalDamage = args.damage

	if (self._fixProb >= 10000 or ys.Battle.BattleFormulas.IsHappen(self._fixProb)) and (self._fixValue or self._fixRate) then
		if self._fixRate then
			-- 按原伤害 * rate 修正
			finalDamage = math.max(1, baseDamage * self._fixRate)
			args.fixFlag = true
		elseif baseDamage > self._fixValue then
			-- 如果大于fixVaue, 将伤害固定为fixValue
			finalDamage = self._fixValue
			args.fixFlag = true
		end
	end

	local arg_list = self._tempData.arg_list
	local capValue
	local currentHP, maxHP = owner:GetHP()

	if arg_list.cap_value then
		capValue = arg_list.cap_value
	elseif arg_list.cap_hp_rate then
		capValue = math.floor(currentHP * arg_list.cap_hp_rate)
	elseif arg_list.cap_hp_rate_max then
		capValue = math.floor(maxHP * arg_list.cap_hp_rate_max)
	end

	if capValue then
		if arg_list.cap_ceiling then
			capValue = math.max(capValue, arg_list.cap_ceiling)
		elseif arg_list.cap_ceiling_rate then
			capValue = math.max(capValue, math.floor(arg_list.cap_ceiling_rate * maxHP))
		end

		if capValue < finalDamage then
			args.capFlag = true
			finalDamage = capValue
		end
	end

	args.damage = math.floor(finalDamage)
end
