ys = ys or {}

local ys = ys
local BattleSkillEditTag = class("BattleSkillEditTag", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillEditTag = BattleSkillEditTag
BattleSkillEditTag.__name = "BattleSkillEditTag"
BattleSkillEditTag.TAG_OPERATION_APPEND = 1
BattleSkillEditTag.TAG_OPERATION_REMOVE = -1

-- 此类SkillEffect用于添加/移除标签
-- 和BattleBuffAddTag差不多(用的都是Unit的Add/RemoveLabelTag接口), 只是AddTag没有直接的Remove(只能等OnRemove)
-- 使用例: 很多, 略
function BattleSkillEditTag.Ctor(self, template, level)
	BattleSkillEditTag.super.Ctor(self, template, level)

	self._tag = self._tempData.arg_list.tag
	self._op = self._tempData.arg_list.operation
end

function BattleSkillEditTag.DoDataEffect(self, caster, target)
	if self._op == BattleSkillEditTag.TAG_OPERATION_APPEND then
		target:AddLabelTag(self._tag)
	elseif self._op == BattleSkillEditTag.TAG_OPERATION_REMOVE then
		target:RemoveLabelTag(self._tag)
	end
end
