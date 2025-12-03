ys = ys or {}

local ys = ys
local BattleBuffAddAttrCommander = class("BattleBuffAddAttrCommander", ys.Battle.BattleBuffAddAttr)

ys.Battle.BattleBuffAddAttrCommander = BattleBuffAddAttrCommander
BattleBuffAddAttrCommander.__name = "BattleBuffAddAttrCommander"

function BattleBuffAddAttrCommander.Ctor(self, effectData)
	BattleBuffAddAttrCommander.super.Ctor(self, effectData)
end

function BattleBuffAddAttrCommander.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
end

function BattleBuffAddAttrCommander.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._attr = self._tempData.arg_list.convertAttr

	local ability = self._tempData.arg_list.ability
	local convertRate = self._tempData.arg_list.convertRate

	self._number = self._commander:getAbilitys()[ability].value * convertRate
	self._numberBase = self._number
end
