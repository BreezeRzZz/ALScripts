ys = ys or {}

local ys = ys
local BattleBuffAddTag = class("BattleBuffAddTag", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddTag = BattleBuffAddTag
BattleBuffAddTag.__name = "BattleBuffAddTag"

function BattleBuffAddTag.Ctor(self, effectData)
	BattleBuffAddTag.super.Ctor(self, effectData)
end

function BattleBuffAddTag.SetArgs(self, owner, buff)
	self._labelTag = self._tempData.arg_list.tag
end

function BattleBuffAddTag.onAttach(self, owner, buff)
	-- BattleUnit.AddLabelTag: 插入labelTagList，labelTag属性对应的tag数值+1
	owner:AddLabelTag(self._labelTag)
end

function BattleBuffAddTag.onRemove(self, owner, buff)
	-- BattleUnit.RemoveLabelTag: 从labelTagList移除，labelTag属性对应的tag数值-1
	owner:RemoveLabelTag(self._labelTag)
end
