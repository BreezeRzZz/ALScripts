ys = ys or {}

local ys = ys

ys.Battle.BattleBuffSetAttr = class("BattleBuffSetAttr", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffSetAttr.__name = "BattleBuffSetAttr"

local BattleBuffSetAttr = ys.Battle.BattleBuffSetAttr
local BattleAttr = ys.Battle.BattleAttr

-- 此类BuffEffect用于设置单位的某个属性到特定数值，或添加/移除一个TargetChoise
-- 使用例: VH装甲钢板的护甲类型修改; TargetChoise的例子: 厌战改1技能的集火目标优先级提高
function BattleBuffSetAttr.Ctor(self, effectData)
	BattleBuffSetAttr.super.Ctor(self, effectData)
end

function BattleBuffSetAttr.SetArgs(self, owner, buff)
	self._attr = self._tempData.arg_list.attr
	self._value = self._tempData.arg_list.value
end

function BattleBuffSetAttr.onAttach(self, owner, buff)
	if self._attr == "TargetChoise" then
		BattleAttr.AddTargetSelect(owner, self._value)
	else
		BattleAttr.SetCurrent(owner, self._attr, self._value)
	end
end

function BattleBuffSetAttr.onRemove(self, owner, buff)
	if self._attr == "TargetChoise" then
		BattleAttr.RemoveTargetSelect(owner, self._value)
	else
		BattleAttr.SetCurrent(owner, self._attr, 0)
	end
end
