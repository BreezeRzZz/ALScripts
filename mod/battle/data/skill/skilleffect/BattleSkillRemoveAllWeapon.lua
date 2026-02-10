ys = ys or {}

local ys = ys
local BattleSkillRemoveAllWeapon = class("BattleSkillRemoveAllWeapon", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillRemoveAllWeapon = BattleSkillRemoveAllWeapon
BattleSkillRemoveAllWeapon.__name = "BattleSkillRemoveAllWeapon"

-- 此类SkillEffect移除施法者的所有自动武器
function BattleSkillRemoveAllWeapon.Ctor(self, template, level)
	BattleSkillRemoveAllWeapon.super.Ctor(self, template, level)
end

function BattleSkillRemoveAllWeapon.DoDataEffect(self, caster)
	self:doRemove(caster)
end

function BattleSkillRemoveAllWeapon.DoDataEffectWithoutTarget(self, caster)
	self:doRemove(caster)
end

function BattleSkillRemoveAllWeapon.doRemove(self, caster)
	caster:RemoveAllAutoWeapon()
end
