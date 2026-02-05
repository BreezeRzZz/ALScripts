ys = ys or {}

local ys = ys
local BattleBuffAddAttrRatioBloodrage = class("BattleBuffAddAttrRatioBloodrage", ys.Battle.BattleBuffAddAttr)

ys.Battle.BattleBuffAddAttrRatioBloodrage = BattleBuffAddAttrRatioBloodrage
BattleBuffAddAttrRatioBloodrage.__name = "BattleBuffAddAttrRatioBloodrage"

function BattleBuffAddAttrRatioBloodrage.Ctor(self, effectData)
	BattleBuffAddAttrRatioBloodrage.super.Ctor(self, effectData)
end

function BattleBuffAddAttrRatioBloodrage.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
end

function BattleBuffAddAttrRatioBloodrage.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._attr = self._tempData.arg_list.attr
	self._threshold = self._tempData.arg_list.threshold
	self._value = self._tempData.arg_list.value
	self._attrBound = self._tempData.arg_list.attrBound
	self._number = 0
end

-- function BattleBuffAddAttrRatioBloodrage.doOnHPRatioUpdate(self, owner, buff)
-- 	self:UpdateAttr(owner)
-- end

function BattleBuffAddAttrRatioBloodrage.calcBloodRageNumber(self, owner)
	local ownerHPRate = owner:GetHPRate()

	if ownerHPRate > self._threshold then
		self._number = 0
	else
		local baseAttrValue = ys.Battle.BattleAttr.GetBase(owner, self._attr)
		-- 按百分比转换加成
		self._number = (self._threshold - ownerHPRate) / self._value * baseAttrValue * 0.0001

		if self._attrBound then
			self._number = math.min(self._number, self._attrBound)
		end
	end
end

function BattleBuffAddAttrRatioBloodrage.doOnHPRatioUpdate(self, owner, buff)
	self:calcBloodRageNumber(owner)
	self:UpdateAttr(owner)
end

function BattleBuffAddAttrRatioBloodrage.onRemove(self, owner, buff)
	self._number = 0

	self:UpdateAttr(owner)
end
