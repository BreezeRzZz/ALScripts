ys = ys or {}

local ys = ys
local BattleSkillEditFleetAttr = class("BattleSkillEditFleetAttr", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillEditFleetAttr = BattleSkillEditFleetAttr
BattleSkillEditFleetAttr.__name = "BattleSkillEditFleetAttr"

-- 此类SkillEffect用于设置舰队属性
-- 使用例: 优米雅阵营设置环境玛那
function BattleSkillEditFleetAttr.Ctor(self, template, level)
	BattleSkillEditFleetAttr.super.Ctor(self, template, level)

	self._fleetAttrName = self._tempData.arg_list.attr
	self._value = self._tempData.arg_list.value
end

function BattleSkillEditFleetAttr.DoDataEffect(self, caster, target)
	if caster:GetFleetVO() then
		local fleetAttr = caster:GetFleetVO():GetFleetAttr()
		local fleetAttrValue = fleetAttr:GetCurrent(self._fleetAttrName) + self._value

		fleetAttr:SetCurrent(self._fleetAttrName, fleetAttrValue)
	end
end
