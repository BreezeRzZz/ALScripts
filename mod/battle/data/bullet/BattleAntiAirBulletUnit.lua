ys = ys or {}

local ys = ys

ys.Battle.BattleAntiAirBulletUnit = class("BattleAntiAirBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleAntiAirBulletUnit.__name = "BattleAntiAirBulletUnit"

local BattleAntiAirBulletUnit = ys.Battle.BattleAntiAirBulletUnit

function BattleAntiAirBulletUnit.Ctor(self, UID, hostIFF)
	ys.Battle.BattleAntiAirBulletUnit.super.Ctor(self, UID, hostIFF)
end

function BattleAntiAirBulletUnit.Update(arg_2_0, arg_2_1)
	return
end

function BattleAntiAirBulletUnit.IsOutRange(arg_3_0)
	return false
end

function BattleAntiAirBulletUnit.SetDirectHitUnit(arg_4_0, arg_4_1)
	arg_4_0._directHitUnit = arg_4_1
end

function BattleAntiAirBulletUnit.GetDirectHitUnit(arg_5_0)
	return arg_5_0._directHitUnit
end

function BattleAntiAirBulletUnit.Dispose(arg_6_0)
	arg_6_0._directHitUnit = nil

	BattleAntiAirBulletUnit.super.Dispose(arg_6_0)
end
