ys = ys or {}

local ys = ys

ys.Battle.BattleSkillConsumeBuff = class("BattleSkillConsumeBuff", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillConsumeBuff.__name = "BattleSkillConsumeBuff"

local BattleSkillConsumeBuff = ys.Battle.BattleSkillConsumeBuff

-- 此类SkillEffect消耗目标身上指定Buff的指定层数
-- 使用例: 约克城META BOSS的逻辑
function BattleSkillConsumeBuff.Ctor(self, template, level)
	BattleSkillConsumeBuff.super.Ctor(self, template, level)

	self._buffID = self._tempData.arg_list.buff_id
	self._count = self._tempData.arg_list.consume_count
end

function BattleSkillConsumeBuff.DoDataEffect(self, caster, target)
	if target:IsAlive() then
		target:ConsumeBuffStack(self._buffID, self._count)
	end
end
