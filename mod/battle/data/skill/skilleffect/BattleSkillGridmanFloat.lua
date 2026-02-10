ys = ys or {}

local ys = ys

ys.Battle.BattleSkillGridmanFloat = class("BattleSkillGridmanFloat", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillGridmanFloat.__name = "BattleSkillGridmanFloat"

local BattleSkillGridmanFloat = ys.Battle.BattleSkillGridmanFloat

function BattleSkillGridmanFloat.Ctor(self, template, level)
	BattleSkillGridmanFloat.super.Ctor(self, template, level)

	self._iconType = self._tempData.arg_list.icon_type
end

-- 此类SkillEffect似乎和CustomWarning是差不多的, 用来在古力特变身时显示漂浮的图标
-- 使用例: 古力特变身的那几个技能(如宝多六花的专属装备技能)
function BattleSkillGridmanFloat.DoDataEffect(self, caster)
	self:doGridmanSkillFloat(caster)
end

function BattleSkillGridmanFloat.DoDataEffectWithoutTarget(self, caster)
	self:doGridmanSkillFloat(caster)
end

function BattleSkillGridmanFloat.doGridmanSkillFloat(self, caster)
	ys.Battle.BattleDataProxy.GetInstance():DispatchGridmanSkill(self._iconType, caster:GetIFF())
end
