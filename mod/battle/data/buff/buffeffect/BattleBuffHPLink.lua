ys = ys or {}

local ys = ys

ys.Battle.BattleBuffHPLink = class("BattleBuffHPLink", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffHPLink.__name = "BattleBuffHPLink"

local BattleBuffHPLink = ys.Battle.BattleBuffHPLink

BattleBuffHPLink.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_LINK

function BattleBuffHPLink.Ctor(self, effectData)
	BattleBuffHPLink.super.Ctor(self, effectData)
end

function BattleBuffHPLink.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._number = arg_list.number or 0
	self._absorbRate = arg_list.absorb or 0
	self._restoreRate = 0
	self._sumDMG = 0

	if arg_list.restoreRatio then
		self._restoreRate = arg_list.restoreRatio * 0.0001
	end
end

function BattleBuffHPLink.onTakeDamage(self, owner, buff, attach)
	-- 来源只能是BattleUnit.UpdateHP中的ON_TAKE_DAMAGE的trigger
	if attach.isShare then
		return
	end

	local damage = attach.damage
	local caster = buff:GetCaster()

	if caster and caster:IsAlive() and caster ~= owner then
		-- 注：是通过修改attach.damage，来处理有多个HPLink的分摊情况
		attach.damage = math.ceil(damage * self._number)

		local realDamage = math.ceil((damage - attach.damage) * (1 - self._absorbRate))

		if realDamage > 0 then
			self._sumDMG = self._sumDMG + realDamage
			-- 此处设置isShare = true，表示该伤害是由HPLink分摊的伤害，避免循环触发onTakeDamage
			-- 也即这种分摊只有一次
			local extraInfo = {
				isMiss = false,
				isCri = false,
				isHeal = false,
				isShare = true
			}
			-- 这里只会对caster造成伤害
			caster:UpdateHP(-realDamage, extraInfo)

			if attach.damageSrc then
				local damageSrc = attach.damageSrc

				ys.Battle.BattleDataProxy.GetInstance():DamageStatistics(damageSrc, owner:GetAttrByName("id"), -realDamage)
				ys.Battle.BattleDataProxy.GetInstance():DamageStatistics(damageSrc, caster:GetAttrByName("id"), realDamage)
			end
		end
	end
end

function BattleBuffHPLink.onRemove(self, owner, buff)
	local caster = buff:GetCaster()

	if caster and caster:IsAlive() and self._restoreRate > 0 and caster ~= owner then
		local casterHealingRate = caster:GetAttrByName("healingRate")
		local hpDiff = math.floor(self._sumDMG * self._restoreRate * casterHealingRate)

		if hpDiff ~= 0 then
			local extraInfo = {
				isMiss = false,
				isCri = false,
				isHeal = true
			}

			caster:UpdateHP(hpDiff, extraInfo)
		end
	end
end
