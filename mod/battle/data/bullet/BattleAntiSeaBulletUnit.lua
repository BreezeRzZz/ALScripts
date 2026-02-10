ys = ys or {}

local ys = ys

ys.Battle.BattleAntiSeaBulletUnit = class("BattleAntiSeaBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleAntiSeaBulletUnit.__name = "BattleAntiSeaBulletUnit"

local BattleAntiSeaBulletUnit = ys.Battle.BattleAntiSeaBulletUnit

-- 对应ANTI_SEA类型子弹
-- 实际实现跟ANTI_AIR类型子弹完全一样, 只是换了个名字
function BattleAntiSeaBulletUnit.Ctor(self, UID, IFF)
	BattleAntiSeaBulletUnit.super.Ctor(self, UID, IFF)
end

function BattleAntiSeaBulletUnit.Update(self, timeStamp)
	return
end

function BattleAntiSeaBulletUnit.IsOutRange(self)
	return false
end

function BattleAntiSeaBulletUnit.SetDirectHitUnit(self, directHitUnit)
	self._directHitUnit = directHitUnit
end

function BattleAntiSeaBulletUnit.GetDirectHitUnit(self)
	return self._directHitUnit
end

function BattleAntiSeaBulletUnit.Dispose(self)
	self._directHitUnit = nil

	BattleAntiSeaBulletUnit.super.Dispose(self)
end
