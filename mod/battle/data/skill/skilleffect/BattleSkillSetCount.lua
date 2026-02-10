ys = ys or {}

local ys = ys

ys.Battle.BattleSkillSetCount = class("BattleSkillSetCount", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillSetCount.__name = "BattleSkillSetCount"

local BattleSkillSetCount = ys.Battle.BattleSkillSetCount

-- 此类SkillEffect将目标的BattleBuffCount计数器设置为指定值，计数器类型由参数countType指定
-- 无使用例
function BattleSkillSetCount.Ctor(self, template, level)
	BattleSkillSetCount.super.Ctor(self, template, level)

	self._countType = self._tempData.arg_list.countType
	self._countTarget = self._tempData.arg_list.countTarget or 0
end

function BattleSkillSetCount.DoDataEffect(self, caster, target)
	self:doSetCounter(target)
end

function BattleSkillSetCount.DoDataEffectWithoutTarget(self, caster)
	self:doSetCounter(caster)
end

function BattleSkillSetCount.doSetCounter(self, target)
	local buffList = target:GetBuffList()

	for _, buff in pairs(buffList) do
		local effectList = buff:GetEffectList()

		for _, effect in ipairs(effectList) do
			-- 这对应的是BattleBuffCount
			if effect:GetEffectType() == ys.Battle.BattleBuffEffect.FX_TYPE_COUNTER and effect:GetCountType() == self._countType then
				effect:SetCount(self._countTarget)
			end
		end
	end
end
