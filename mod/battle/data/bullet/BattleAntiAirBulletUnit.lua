ys = ys or {}

local ys = ys

ys.Battle.BattleAntiAirBulletUnit = class("BattleAntiAirBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleAntiAirBulletUnit.__name = "BattleAntiAirBulletUnit"

local BattleAntiAirBulletUnit = ys.Battle.BattleAntiAirBulletUnit

function BattleAntiAirBulletUnit.Ctor(self, UID, hostIFF)
	ys.Battle.BattleAntiAirBulletUnit.super.Ctor(self, UID, hostIFF)
end

function BattleAntiAirBulletUnit.Update(self, timeStamp)
	return
end

function BattleAntiAirBulletUnit.IsOutRange(self)
	return false
end

function BattleAntiAirBulletUnit.SetDirectHitUnit(self, directHitUnit)
	self._directHitUnit = directHitUnit
end

function BattleAntiAirBulletUnit.GetDirectHitUnit(self)
	return self._directHitUnit
end

function BattleAntiAirBulletUnit.Dispose(self)
	self._directHitUnit = nil

	BattleAntiAirBulletUnit.super.Dispose(self)
end
