ys = ys or {}

local ys = ys
local BattleSkillPhaseJump = class("BattleSkillPhaseJump", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillPhaseJump = BattleSkillPhaseJump
BattleSkillPhaseJump.__name = "BattleSkillPhaseJump"

-- 此类SkillEffect用于将Unit的Phase切换到指定阶段
-- 使用例: 某些条件下触发的技能, 强制跳转阶段(如BOSS转阶段)
function BattleSkillPhaseJump.Ctor(self, template, level)
	BattleSkillPhaseJump.super.Ctor(self, template, level)

	self._phaseIndex = self._tempData.arg_list.index or 0
end

function BattleSkillPhaseJump.DoDataEffect(self, caster)
	self:doJump(caster)
end

function BattleSkillPhaseJump.DoDataEffectWithoutTarget(self, caster)
	self:doJump(caster)
end

function BattleSkillPhaseJump.doJump(self, caster)
	--- @type BattleUnitPhaseSwitcher
	local phaseSwitcher = caster:GetPhaseSwitcher()

	if phaseSwitcher then
		phaseSwitcher:ForceSwitch(self._phaseIndex)
	end
end
