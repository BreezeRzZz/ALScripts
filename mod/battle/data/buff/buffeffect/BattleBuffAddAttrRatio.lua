ys = ys or {}

local ys = ys
local BattleBuffAddAttrRatio = class("BattleBuffAddAttrRatio", ys.Battle.BattleBuffAddAttr)

ys.Battle.BattleBuffAddAttrRatio = BattleBuffAddAttrRatio
BattleBuffAddAttrRatio.__name = "BattleBuffAddAttrRatio"

function BattleBuffAddAttrRatio.Ctor(self, effectData)
	BattleBuffAddAttrRatio.super.Ctor(self, effectData)
end

function BattleBuffAddAttrRatio.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
end

function BattleBuffAddAttrRatio.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._attr = self._tempData.arg_list.attr
	self._attrBound = self._tempData.arg_list.attrBound
	-- convertAttr存在时，按convertAttr的属性值计算加成
	-- 比如，可以用防空值，按一定比例加成炮击值
	local attr = self._tempData.arg_list.convertAttr or self._attr
	local attrValue = ys.Battle.BattleAttr.GetBase(owner, attr)
	-- 等价于(number/100)% * attrValue
	self._number = self._tempData.arg_list.number * attrValue * 0.0001
	self._numberBase = self._number

	-- 每层的效果最多提高到attrBound
	if self._attrBound then
		self._numberBase = math.min(self._numberBase, self._attrBound)
	end

	self._attrID = self._tempData.arg_list.attr_group_ID
end
