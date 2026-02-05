ys = ys or {}

local ys = ys
local BattleBuffAddAttrBloodrage = class("BattleBuffAddAttrBloodrage", ys.Battle.BattleBuffAddAttr)

ys.Battle.BattleBuffAddAttrBloodrage = BattleBuffAddAttrBloodrage
BattleBuffAddAttrBloodrage.__name = "BattleBuffAddAttrBloodrage"

function BattleBuffAddAttrBloodrage.Ctor(self, effectData)
	BattleBuffAddAttrBloodrage.super.Ctor(self, effectData)
end

function BattleBuffAddAttrBloodrage.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
end

function BattleBuffAddAttrBloodrage.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._attr = self._tempData.arg_list.attr
	self._threshold = self._tempData.arg_list.threshold
	self._value = self._tempData.arg_list.value
	self._attrBound = self._tempData.arg_list.attrBound
	self._number = 0
end

function BattleBuffAddAttrBloodrage.calcBloodRageNumber(self, owner)
	local ownerHPRate = owner:GetHPRate()

	if ownerHPRate > self._threshold then
		self._number = 0
	else
		-- 提供的属性增益计算方式是线性的
		-- value(的倒数)为系数
		self._number = (self._threshold - ownerHPRate) / self._value

		if self._attrBound then
			self._number = math.min(self._number, self._attrBound)
		end
	end
end

function BattleBuffAddAttrBloodrage.doOnHPRatioUpdate(self, owner, buff)
	self:calcBloodRageNumber(owner)
	self:UpdateAttr(owner)
end

function BattleBuffAddAttrBloodrage.onRemove(self, owner, buff)
	self._number = 0

	self:UpdateAttr(owner)
end
