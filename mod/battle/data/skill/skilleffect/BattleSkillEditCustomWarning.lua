ys = ys or {}

local ys = ys
local BattleSkillEditCustomWarning = class("BattleSkillEditCustomWarning", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillEditCustomWarning = BattleSkillEditCustomWarning
BattleSkillEditCustomWarning.__name = "BattleSkillEditCustomWarning"
BattleSkillEditCustomWarning.OP_ADD = 1
BattleSkillEditCustomWarning.OP_REMOVE = 0
BattleSkillEditCustomWarning.OP_REMOVE_PERMANENT = -1
BattleSkillEditCustomWarning.OP_REMOVE_TEMPLATE = -2

-- 此类SkillEffect用来编辑自定义预警标签
-- 用于在战斗中动态添加/移除预警标签，配合预警标签系统实现一些特殊的预警效果
-- 使用例: 各种EX里的预警标签
function BattleSkillEditCustomWarning.Ctor(self, template, level)
	BattleSkillEditCustomWarning.super.Ctor(self, template, level)

	self._labelData = {
		op = self._tempData.arg_list.op,
		key = self._tempData.arg_list.key,
		x = self._tempData.arg_list.x,
		y = self._tempData.arg_list.y,
		dialogue = self._tempData.arg_list.dialogue,
		duration = self._tempData.arg_list.duration
	}
end

function BattleSkillEditCustomWarning.DoDataEffect(self)
	self:doEditWarning()
end

function BattleSkillEditCustomWarning.DoDataEffectWithoutTarget(self)
	self:doEditWarning()
end

function BattleSkillEditCustomWarning.doEditWarning(self)
	ys.Battle.BattleDataProxy.GetInstance():DispatchCustomWarning(self._labelData)
end
