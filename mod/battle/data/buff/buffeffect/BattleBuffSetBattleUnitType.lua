ys = ys or {}

local ys = ys

ys.Battle.BattleBuffSetBattleUnitType = class("BattleBuffSetBattleUnitType", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffSetBattleUnitType.__name = "BattleBuffSetBattleUnitType"

local BattleBuffSetBattleUnitType = ys.Battle.BattleBuffSetBattleUnitType
local BattleAttr = ys.Battle.BattleAttr

BattleBuffSetBattleUnitType.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TTPE_MOD_BATTLE_UNIT_TYPE
BattleBuffSetBattleUnitType.ATTR_KEY = "battle_unit_type"

-- 此类BuffEffect专用于修改battle_unit_type属性
-- 一般来讲，battle_unit_type决定的是索敌优先级
-- 此外还相关的则是是否属于Spectre(幽灵)单位
-- 幽灵单位的特点: 
-- 1. 会被大多数索敌方式规避
-- 2. 没有碰撞体
-- 3. 在特定值下, 不可见(-100, 这主要是给一些游戏机制设计的方便)
-- 使用例: 非常常用. 例如用来让敌人"无敌"(失去碰撞判定+不可见), 或是转阶段隐藏本体等.
function BattleBuffSetBattleUnitType.Ctor(self, effectData)
	BattleBuffSetBattleUnitType.super.Ctor(self, effectData)
end

function BattleBuffSetBattleUnitType.GetEffectType(self)
	return BattleBuffSetBattleUnitType.FX_TYPE
end

function BattleBuffSetBattleUnitType.SetArgs(self, owner, buff)
	self._value = self._tempData.arg_list.value
end

function BattleBuffSetBattleUnitType.onAttach(self, owner, buff)
	BattleAttr.SetCurrent(owner, BattleBuffSetBattleUnitType.ATTR_KEY, self._value)
	self.flash(owner)
end

function BattleBuffSetBattleUnitType.onRemove(self, owner, buff)
	BattleAttr.SetCurrent(owner, BattleBuffSetBattleUnitType.ATTR_KEY, nil)
	self.flash(owner)
end

function BattleBuffSetBattleUnitType.flash(target)
	target:UpdateBlindInvisibleBySpectre()
	ys.Battle.BattleDataProxy.GetInstance():SwitchSpectreUnit(target)
end
