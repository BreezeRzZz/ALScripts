ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleConst = ys.Battle.BattleConst
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local bfConsts = pg.bfConsts
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig
local BattleMissileUnit = class("BattleMissileUnit", ys.Battle.BattleBulletUnit)

BattleMissileUnit.__name = "BattleMissileUnit"
ys.Battle.BattleMissileUnit = BattleMissileUnit
BattleMissileUnit.STATE_LAUNCH = "Launch"
BattleMissileUnit.STATE_ATTACK = "Attack"
BattleMissileUnit.TYPE_COORD = 1
BattleMissileUnit.TYPE_RANGE = 2
BattleMissileUnit.TYPE_TARGET = 3

-- 对应MISSILE类型子弹
-- 这个不是常见的导弹武器, 暂时不用管
function BattleMissileUnit.Ctor(self, ...)
	BattleMissileUnit.super.Ctor(self, ...)

	self._state = self.STATE_LAUNCH
end

function BattleMissileUnit.SetTemplateData(self, tempData)
	BattleMissileUnit.super.SetTemplateData(self, tempData)
	self:ResetVelocity(0)

	local extraParam = self:GetTemplate().extra_param

	self._gravity = extraParam.gravity or ys.Battle.BattleConfig.GRAVITY
	self._targetType = extraParam.aimType or BattleMissileUnit.TYPE_TARGET
end

function BattleMissileUnit.GetPierceCount(self)
	return 1
end

function BattleMissileUnit.RegisterOnTheAir(self, onTheHighest)
	self._onTheHighest = onTheHighest
end

function BattleMissileUnit.SetExplodePosition(self, explodePos)
	self._explodePos = explodePos:Clone()
	self._explodePos.y = BattleConfig.BombDetonateHeight
end

function BattleMissileUnit.GetExplodePostion(self)
	return self._explodePos
end

local viewInterval = 1 / BattleConfig.viewFPS

function BattleMissileUnit.SetSpawnPosition(self, spawnPos)
	BattleMissileUnit.super.SetSpawnPosition(self, spawnPos)

	self._verticalSpeed = self:GetTemplate().extra_param.launchVrtSpeed
end

function BattleMissileUnit.Update(self, timeStamp)
	BattleMissileUnit.super.Update(self, timeStamp)

	if self._state == self.STATE_LAUNCH and timeStamp > self:GetTemplate().extra_param.launchRiseTime + self._timeStamp then
		self:CompleteRise()
	end
end

function BattleMissileUnit.CompleteRise(self)
	self._state = self.STATE_ATTACK
	self._gravity = 0

	if self._onTheHighest then
		self._onTheHighest()
	end

	local fallTime = self:GetTemplate().extra_param.fallTime

	self._targetPos = self._explodePos
	self._yAngle = math.rad2Deg * math.atan2(self._explodePos.z - self._spawnPos.z, self._explodePos.x - self._spawnPos.x)
	self._verticalSpeed = -(self._position.y / fallTime) * viewInterval

	local distance = pg.Tool.FilterY(self._explodePos - self._position):Magnitude()

	self:ResetVelocity(BattleFormulas.ConvertBulletDataSpeed(distance / fallTime * viewInterval))
	self:calcSpeed()
end

function BattleMissileUnit.IsOutRange(self)
	return self._state == self.STATE_ATTACK and self._position.y <= BattleConfig.BombDetonateHeight
end

function BattleMissileUnit.OutRange(self, UID)
	local explodeArgs = {
		UID = UID
	}

	self:DispatchEvent(ys.Event.New(BattleBulletEvent.EXPLODE, explodeArgs))
	BattleMissileUnit.super.OutRange(self)
end

function BattleMissileUnit.GetMissileTargetPosition(self)
	if self._targetType == BattleMissileUnit.TYPE_RANGE then
		return self:aimRange()
	elseif self._targetType == BattleMissileUnit.TYPE_COORD then
		return self:aimCoord()
	elseif self._targetType == BattleMissileUnit.TYPE_TARGET then
		return self:aimTarget()
	end
end

function BattleMissileUnit.aimRange(self)
	local range = self._range
	local relativeRange = self._range * self:GetIFF()

	return (Vector3(self._spawnPos.x + relativeRange, 0, 0))
end

function BattleMissileUnit.aimCoord(self)
	local extraParam = self:GetTemplate().extra_param
	local missileX = extraParam.missileX
	local missileZ = extraParam.missileZ

	if not missileX or not missileZ then
		return self:aimRange()
	end

	return (Vector3(missileX, 0, missileZ))
end

function BattleMissileUnit.aimTarget(self, target)
	local weapon = target:GetWeapon()
	local host = weapon:GetHost()

	if not host or not host:IsAlive() then
		return self:aimCoord()
	end

	local target = weapon:Tracking()

	return weapon:GetTemplateData().aim_type == BattleConst.WeaponAimType.AIM and target and weapon:CalculateRandTargetPosition(self, target) or weapon:CalculateFixedExplodePosition(self)
end
