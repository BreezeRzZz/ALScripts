ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleDepthChargeUnit = class("BattleDepthChargeUnit", ys.Battle.BattleWeaponUnit)
ys.Battle.BattleDepthChargeUnit.__name = "BattleDepthChargeUnit"

local BattleDepthChargeUnit = ys.Battle.BattleDepthChargeUnit
local BattleTargetChoise = ys.Battle.BattleTargetChoise

function BattleDepthChargeUnit.Ctor(self)
	BattleDepthChargeUnit.super.Ctor(self)
end

function BattleDepthChargeUnit.TriggerBuffOnFire(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_DEPTH_CHARGE_DROP, {
		equipIndex = self._equipmentIndex
	})
end
