ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleTorpedoBulletUnit = class("BattleTorpedoBulletUnit", ys.Battle.BattleBulletUnit)

ys.Battle.BattleTorpedoBulletUnit = BattleTorpedoBulletUnit
BattleTorpedoBulletUnit.__name = "BattleTorpedoBulletUnit"

-- 对应TORPEDO类型子弹
function BattleTorpedoBulletUnit.Ctor(self, UID, IFF)
	BattleTorpedoBulletUnit.super.Ctor(self, UID, IFF)
end

function BattleTorpedoBulletUnit.calcSpeed(self)
	local bulletSpeedRatio = 1 + ys.Battle.BattleAttr.GetCurrent(self, "bulletSpeedRatio")
	-- 鱼雷有torpedoSpeedExtra属性, 需要加上这个属性的影响
	-- (也即，这个属性是作用在BulletType为TORPEDO的子弹上的)
	-- (使用例: 伊19的缓速鱼雷) (这个属性的值是负数, 会降低鱼雷速度)
	-- 其余部分跟父类BulletUnit一样
	local bulletSpeed = math.max(0, self._velocity + ys.Battle.BattleAttr.GetCurrent(self, "torpedoSpeedExtra")) * bulletSpeedRatio
	local bulletVelocity = BattleFormulas.ConvertBulletSpeed(bulletSpeed)
	local yAngle = math.deg2Rad * self._yAngle

	self._speed = Vector3(bulletVelocity * math.cos(yAngle), 0, bulletVelocity * math.sin(yAngle))
end

function BattleTorpedoBulletUnit.GetExplodePostion(self)
	return self._explodePos
end

function BattleTorpedoBulletUnit.SetExplodePosition(self, explodePos)
	self._explodePos = explodePos
end

function BattleTorpedoBulletUnit.InitCldComponent(self)
	BattleTorpedoBulletUnit.super.InitCldComponent(self)
	self:ResetCldSurface()
end

function BattleTorpedoBulletUnit.Hit(self, shipUID, shipUnitType)
	BattleTorpedoBulletUnit.super.Hit(self, shipUID, shipUnitType)

	self._pierceCount = self._pierceCount - 1
end
