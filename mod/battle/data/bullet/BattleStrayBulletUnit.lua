ys = ys or {}

local ys = ys

ys.Battle.BattleStrayBulletUnit = class("BattleStrayBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleStrayBulletUnit.__name = "BattleStrayBulletUnit"

local BattleStrayBulletUnit = ys.Battle.BattleStrayBulletUnit

-- 对应STRAY类型子弹
-- 不知道有啥意义, 只设定了个explodePos(父类没有), 其他部分跟父类完全一样
-- 此外实际也没有任何这个类型的子弹的实例(可能废弃了)
function BattleStrayBulletUnit.Ctor(self, UID, IFF)
	BattleStrayBulletUnit.super.Ctor(self, UID, IFF)
end

function BattleStrayBulletUnit.SetExplodePosition(self, explodePos)
	self._explodePos = explodePos
end

function BattleStrayBulletUnit.GetExplodePostion(self)
	return self._explodePos
end
