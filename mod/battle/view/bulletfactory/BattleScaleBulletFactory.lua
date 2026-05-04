ys = ys or {}

local ys = ys
local UnitType = ys.Battle.BattleConst.UnitType

ys.Battle.BattleScaleBulletFactory = singletonClass("BattleScaleBulletFactory", ys.Battle.BattleCannonBulletFactory)
ys.Battle.BattleScaleBulletFactory.__name = "BattleScaleBulletFactory"

local BattleScaleBulletFactory = ys.Battle.BattleScaleBulletFactory

function BattleScaleBulletFactory.Ctor(self)
	BattleScaleBulletFactory.super.Ctor(self)
end

--- 创建伸缩弹的BulletUnit View
--- 伸缩弹继承自CannonBulletFactory的所有行为（命中/未命中/模型创建），
--- 仅创建不同的BulletUnit类型，其特殊逻辑（缩放动画等）在BattleScaleBulletUnit内部处理
--- @return BattleScaleBullet
function BattleScaleBulletFactory.MakeBullet(self)
	return ys.Battle.BattleScaleBullet.New()
end
