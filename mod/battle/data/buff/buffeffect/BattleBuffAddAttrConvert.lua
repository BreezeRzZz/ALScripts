ys = ys or {}

local ys = ys
local BattleBuffAddAttrConvert = class("BattleBuffAddAttrConvert", ys.Battle.BattleBuffAddAttr)

ys.Battle.BattleBuffAddAttrConvert = BattleBuffAddAttrConvert
BattleBuffAddAttrConvert.__name = "BattleBuffAddAttrConvert"

function BattleBuffAddAttrConvert.Ctor(self, effectData)
	BattleBuffAddAttrConvert.super.Ctor(self, effectData)
end

function BattleBuffAddAttrConvert.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
end

-- 相比BattleBuffAddAttr，增加了根据转换属性计算数值的逻辑(number = baseNumber + convertAttrValue * convertRate)
-- convertAttrValue使用的是base值，因此战斗内Buff提高的被转换属性不会影响转换后的数值
function BattleBuffAddAttrConvert.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._attr = self._tempData.arg_list.attr
	self._convertAttr = self._tempData.arg_list.convertAttr
	self._convertAttrValue = ys.Battle.BattleAttr.GetBase(owner, self._convertAttr)
	self._convertRate = self._tempData.arg_list.convertRate
	self._number = (self._tempData.arg_list.number or 0) + self._convertAttrValue * self._convertRate
	self._numberBase = self._number
end
