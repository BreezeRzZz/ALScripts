ys = ys or {}

local ys = ys

ys.Battle.BattleSkillHeal = class("BattleSkillHeal", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillHeal.__name = "BattleSkillHeal"

-- 核心SkillEffect之一
-- 此类SkillEffect用于治疗目标单位
-- 使用例: 部分回血技能
-- 与BattleBuffHP区别在于, BattleSkillHeal一定是自己给自己的治疗, 而BattleBuffHP则不一定. 例如, 也可以是给队友治疗的BuffEffect
function ys.Battle.BattleSkillHeal.Ctor(self, template, level)
	ys.Battle.BattleSkillHeal.super.Ctor(self, template, level)

	self._number = self._tempData.arg_list.number or 0
	self._maxHPRatio = self._tempData.arg_list.maxHPRatio or 0
	self._incorruptible = self._tempData.arg_list.incorrupt
end

function ys.Battle.BattleSkillHeal.DoDataEffect(self, caster, target)
	local healingRatio = caster:GetAttrByName("healingEnhancement") + 1
	-- 例如, 演习模式有治疗倍率加成
	local healFixRatio = ys.Battle.BattleFormulas.HealFixer(ys.Battle.BattleDataProxy.GetInstance():GetInitData().battleType, target:GetAttr())
	local fixedHealNumber = math.floor(self._number * healFixRatio)
	-- healingRate是大型作战的治疗倍率
	local healingRate = caster:GetAttrByName("healingRate")
	-- 基于最大耐久的不用修正(因为耐久的倍率跟治疗倍率一样)
	local healNumber = math.max(0, math.floor((target:GetMaxHP() * self._maxHPRatio + fixedHealNumber) * healingRatio * healingRate))
	local extraInfo = {
		isMiss = false,
		isCri = false,
		isHeal = true,
		incorrupt = self._incorruptible
	}

	target:UpdateHP(healNumber, extraInfo)
end
