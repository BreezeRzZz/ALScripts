ys = ys or {}

local ys = ys

ys.Battle.BattleSkillAddBuff = class("BattleSkillAddBuff", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillAddBuff.__name = "BattleSkillAddBuff"

function ys.Battle.BattleSkillAddBuff.Ctor(self, template, level)
	ys.Battle.BattleSkillAddBuff.super.Ctor(self, template, level)

	self._buffID = self._tempData.arg_list.buff_id
end

function ys.Battle.BattleSkillAddBuff.DoDataEffect(self, caster, target)
	if target:IsAlive() then
		local buff = ys.Battle.BattleBuffUnit.New(self._buffID, self._level, caster)

		buff:SetCommander(self._commander)
		target:AddBuff(buff)
	end
end
