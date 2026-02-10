ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleGravitationBulletUnit = class("BattleGravitationBulletUnit", ys.Battle.BattleBulletUnit)

ys.Battle.BattleGravitationBulletUnit = BattleGravitationBulletUnit
BattleGravitationBulletUnit.__name = "BattleGravitationBulletUnit"

-- 对应G_BULLET类型子弹
-- 似乎是类似引力子弹(如俾斯麦Zwei的技能子弹就用到了)
-- 更具体的牵引效果，需要看对应的BulletFactory的实现
function BattleGravitationBulletUnit.Ctor(self, UID, IFF)
	BattleGravitationBulletUnit.super.Ctor(self, UID, IFF)
end

function BattleGravitationBulletUnit.Update(self, timeStamp)
	if self._pierceCount > 0 then
		BattleGravitationBulletUnit.super.Update(self, timeStamp)
	end
end

function BattleGravitationBulletUnit.SetTemplateData(self, tempData)
	BattleGravitationBulletUnit.super.SetTemplateData(self, tempData)

	self._hitInterval = tempData.hit_type.interval or 0.2
end

function BattleGravitationBulletUnit.GetExplodePostion(self)
	return self._explodePos
end

function BattleGravitationBulletUnit.SetExplodePosition(self, explodePos)
	self._explodePos = explodePos
end

-- 这类子弹的伤害结算有点像激光
-- 初始前摇: alert_duration
-- 之后每隔interval秒对范围内单位造成一次伤害, 直到穿
function BattleGravitationBulletUnit.DealDamage(self)
	self._nextDamageTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._hitInterval
end

function BattleGravitationBulletUnit.CanDealDamage(self)
	if not self._nextDamageTime then
		self._nextDamageTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._tempData.extra_param.alert_duration

		return false
	else
		return self._nextDamageTime < pg.TimeMgr.GetInstance():GetCombatTime()
	end
end

function BattleGravitationBulletUnit.Hit(self, shipUID, shipUnitType)
	BattleGravitationBulletUnit.super.Hit(self, shipUID, shipUnitType)

	self._pierceCount = self._pierceCount - 1
	self._position.y = 100
end
