ys = ys or {}

local ys = ys

ys.Battle.BattleCannonBulletUnit = class("BattleCannonBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleCannonBulletUnit.__name = "BattleCannonBulletUnit"

local BattleCannonBulletUnit = ys.Battle.BattleCannonBulletUnit

-- 对应CANNON类型子弹
function BattleCannonBulletUnit.Ctor(self, UID, IFF)
	BattleCannonBulletUnit.super.Ctor(self, UID, IFF)
end

function BattleCannonBulletUnit.Hit(self, shipUID, shipUnitType)
	BattleCannonBulletUnit.super.Hit(self, shipUID, shipUnitType)

	self._pierceCount = self._pierceCount - 1
end
