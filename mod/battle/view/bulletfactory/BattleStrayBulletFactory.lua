ys = ys or {}

local ys = ys
local UnitType = ys.Battle.BattleConst.UnitType

ys.Battle.BattleStrayBulletFactory = singletonClass("BattleStrayBulletFactory", ys.Battle.BattleCannonBulletFactory)
ys.Battle.BattleStrayBulletFactory.__name = "BattleStrayBulletFactory"

local BattleStrayBulletFactory = ys.Battle.BattleStrayBulletFactory

function BattleStrayBulletFactory.Ctor(self)
	BattleStrayBulletFactory.super.Ctor(self)
end

--- 创建流弹类型的BulletUnit View
--- 流弹继承自CannonBulletFactory的所有行为（命中/未命中/模型），仅创建不同的BulletUnit类型
--- @return BattleStrayBullet
function BattleStrayBulletFactory.MakeBullet(self)
	return ys.Battle.BattleStrayBullet.New()
end
