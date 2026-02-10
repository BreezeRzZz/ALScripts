ys = ys or {}

local ys = ys

ys.Battle.BattleSkillSetCloak = class("BattleSkillSetCloak", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillSetCloak.__name = "BattleSkillSetCloak"

local BattleSkillSetCloak = ys.Battle.BattleSkillSetCloak

-- 此类SkillEffect设置隐匿的暴露值
-- 使用例: 各种隐匿清空的技能
function BattleSkillSetCloak.Ctor(self, template, level)
	BattleSkillSetCloak.super.Ctor(self, template, level)

	self._rate = self._tempData.arg_list.cloak_rate or 0
end

function BattleSkillSetCloak.DoDataEffect(self, caster, target)
	self:doSetCloakValue(target)
end

function BattleSkillSetCloak.DoDataEffectWithoutTarget(self, caster)
	self:doSetCloakValue(caster)
end

function BattleSkillSetCloak.doSetCloakValue(self, target)
	--- @type BattleUnitCloakComponent
	local cloak = target:GetCloak()

	if cloak then
		cloak:ForceToRate(self._rate)
	end
end
