ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleSkillSonar = class("BattleSkillSonar", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillSonar = BattleSkillSonar
BattleSkillSonar.__name = "BattleSkillSonar"

-- 此类SkillEffect启用声纳，参数range指定声纳范围，duration指定持续时间
-- 使用例: 莫加多尔3技能
function BattleSkillSonar.Ctor(self, template, level)
	BattleSkillSonar.super.Ctor(self, template, level)

	self._range = self._tempData.arg_list.range
	self._duration = self._tempData.arg_list.duration
end

function BattleSkillSonar.DoDataEffect(self, caster)
	caster:GetFleetVO():AppendIndieSonar(self._range, self._duration)
end

function BattleSkillSonar.DataEffectWithoutTarget(self, caster)
	caster:GetFleetVO():AppendIndieSonar(self._range, self._duration)
end
