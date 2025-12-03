ys = ys or {}

local ys = ys
local BattleBuffAddAttrRatioCommander = class("BattleBuffAddAttrRatioCommander", ys.Battle.BattleBuffAddAttrRatio)

ys.Battle.BattleBuffAddAttrRatioCommander = BattleBuffAddAttrRatioCommander
BattleBuffAddAttrRatioCommander.__name = "BattleBuffAddAttrRatioCommander"

function BattleBuffAddAttrRatioCommander.Ctor(self, effectData)
	BattleBuffAddAttrRatioCommander.super.Ctor(self, effectData)
end

function BattleBuffAddAttrRatioCommander.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
end

function BattleBuffAddAttrRatioCommander.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._attr = self._tempData.arg_list.convertAttr

	local ability = self._tempData.arg_list.ability
	local convertRate = self._tempData.arg_list.convertRate
	-- 等价于(abilityValue * convertRate / 100)% * base
	self._number = self._commander:getAbilitys()[ability].value * convertRate * ys.Battle.BattleAttr.GetBase(owner, self._attr) * 0.0001
	self._numberBase = self._number
end
