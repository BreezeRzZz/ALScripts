ys = ys or {}

local ys = ys

ys.Battle.BattleSkillDamage = class("BattleSkillDamage", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillDamage.__name = "BattleSkillDamage"

-- 此类SkillEffect对目标造成直接伤害
-- DirectDamage并不会受到任何伤害计算公式的影响(如增伤区/易伤区等)，伤害数值完全由SkillEffect的参数决定
function ys.Battle.BattleSkillDamage.Ctor(self, template, level)
	ys.Battle.BattleSkillDamage.super.Ctor(self, template, level)

	self._number = self._tempData.arg_list.number or 0
	self._currentHPRate = self._tempData.arg_list.current_hp_rate or 0
	self._maxHPRate = self._tempData.arg_list.rate or 0
	self._proxy = ys.Battle.BattleDataProxy.GetInstance()
end

function ys.Battle.BattleSkillDamage.DoDataEffect(self, caster, target)
	local currentHP, maxHP = target:GetHP()
	local damage = math.floor(maxHP * self._maxHPRate) + math.floor(currentHP * self._currentHPRate) + self._number

	self._proxy:HandleDirectDamage(target, damage, caster)
	-- 不太清楚, 待定
	if not target:IsAlive() then
		ys.Battle.BattleAttr.Spirit(target)
		ys.Battle.BattleAttr.AppendInvincible(target)
	end
end
