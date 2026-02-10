ys = ys or {}

local ys = ys

ys.Battle.BattleAntiAirBulletUnit = class("BattleAntiAirBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleAntiAirBulletUnit.__name = "BattleAntiAirBulletUnit"

local BattleAntiAirBulletUnit = ys.Battle.BattleAntiAirBulletUnit

-- 对应DIRECT/ANTI_AIR/BEAM/ELECTRIC_ARC类型子弹
-- 特点为directHitUnit(直接命中单位)属性, 以及不受飞行时间和射程限制
function BattleAntiAirBulletUnit.Ctor(self, UID, IFF)
	ys.Battle.BattleAntiAirBulletUnit.super.Ctor(self, UID, IFF)
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
