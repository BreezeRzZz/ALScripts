ys = ys or {}

local ys = ys
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleFormulas = ys.Battle.BattleFormulas
local BattleSpaceLaserUnit = class("BattleSpaceLaserUnit", ys.Battle.BattleColumnAreaBulletUnit)

BattleSpaceLaserUnit.__name = "BattleSpaceLaserUnit"
ys.Battle.BattleSpaceLaserUnit = BattleSpaceLaserUnit
BattleSpaceLaserUnit.STATE_READY = "Ready"
BattleSpaceLaserUnit.STATE_PRECAST = "Precast"
BattleSpaceLaserUnit.STATE_ATTACK = "Attack"
BattleSpaceLaserUnit.STATE_DESTROY = "Destroy"

-- 对应SPACE_LASER类型子弹. 其主要对应的武器是BattleSpaceLaserWeaponUnit
-- 大致形态是从天上落下的激光, 伤害结算有点像激光(Laser), 有个持续时间, 在持续时间内每隔一段时间对范围内单位造成一次伤害
-- 从Weapon的实现来看, 这个子弹有一个前摇时间(aim_time), 前摇结束后才真正开始攻击(attack_time). 在attack_time内每隔interval秒对范围内单位造成伤害
-- 使用例: 威奇塔META的激光炮
function BattleSpaceLaserUnit.Ctor(self, ...)
	BattleSpaceLaserUnit.super.Ctor(self, ...)

	self._collidedTimes = {}
end

function BattleSpaceLaserUnit.Dispose(self)
	self._lifeEndCb = nil
	self._collidedTimes = nil

	BattleSpaceLaserUnit.super.Dispose(self)
end

function BattleSpaceLaserUnit.ExecuteLifeEndCallback(self)
	if self._lifeEndCb then
		self._lifeEndCb()
	end
end

function BattleSpaceLaserUnit.AssertFields(self, field)
	assert(self[field], "Lack Field " .. field)
end

function BattleSpaceLaserUnit.SetTemplateData(self, tempData)
	self.AssertFields(tempData.extra_param, "attack_time")
	self.AssertFields(tempData.hit_type, "interval")
	BattleSpaceLaserUnit.super.SetTemplateData(self, tempData)

	self._hitInterval = tempData.hit_type.interval
end

function BattleSpaceLaserUnit.GetHitInterval(self)
	return self._hitInterval
end

function BattleSpaceLaserUnit.DoTrack(bullet)
	local _bullet = bullet
	local trackingTarget = _bullet:getTrackingTarget()

	if not trackingTarget or trackingTarget == -1 then
		return
	elseif not trackingTarget:IsAlive() then
		_bullet:setTrackingTarget(-1)
		_bullet._speed:SetNormalize():Mul(bullet._convertedVelocity)

		return
	elseif _bullet:GetDistance(trackingTarget) > _bullet._trackRange then
		_bullet:setTrackingTarget(-1)
		_bullet._speed:SetNormalize():Mul(bullet._convertedVelocity)

		return
	end

	local disVector = trackingTarget:GetPosition() - _bullet:GetPosition()
	local distance = disVector:Magnitude()

	if distance <= 1e-05 then
		bullet._speed:Set(0, 0, 0)

		return
	end

	local speedNormal = bullet._speedNormal

	disVector:SetNormalize()

	local dotProduct = disVector.x * speedNormal.x + disVector.z * speedNormal.z
	local crossProduct = disVector.z * speedNormal.x - disVector.x * speedNormal.z
	local speedRatio = _bullet:GetSpeedRatio()
	local cosAngle = math.cos(_bullet._cosAngularSpeed * speedRatio)
	local sinAngle = math.sin(_bullet._sinAngularSpeed * speedRatio)
	local dotClamped = dotProduct
	local crossClamped = crossProduct

	if dotProduct < cosAngle then
		dotClamped = cosAngle
		crossClamped = sinAngle * (crossClamped > 0 and 1 or -1)
	end

	local newSpeedX = speedNormal.x * dotClamped - speedNormal.z * crossClamped
	local newSpeedZ = speedNormal.z * dotClamped + speedNormal.x * crossClamped
	local maxSpeed = math.min(bullet._convertedVelocity, distance)

	_bullet._speed:Set(newSpeedX, 0, newSpeedZ)
	_bullet._speed:Mul(maxSpeed)
	bullet._speedNormal:Set(newSpeedX, 0, newSpeedZ)
	bullet._speedNormal:SetNormalize()

	bullet._yAngle = math.rad2Deg * math.atan2(newSpeedX, newSpeedZ)
end

function BattleSpaceLaserUnit.InitSpeed(self, ...)
	BattleSpaceLaserUnit.super.InitSpeed(self, ...)

	if self:IsTracker() then
		local radAngle = math.deg2Rad * self._yAngle

		self._speedNormal = Vector3(math.cos(radAngle), 0, math.sin(radAngle))
		self.updateSpeed = self.DoTrack
	elseif self:IsCircle() and self:IsAlert() then
		self._centripetalSpeed = self._centripetalSpeed * self.alertSpeedRatio
	end
end

function BattleSpaceLaserUnit.SetLifeTime(self, lifetime)
	self._lifeTime = lifetime
end

function BattleSpaceLaserUnit.SetAlert(self, alertFlag)
	self._alertFlag = alertFlag

	local extra_param = self:GetTemplate().extra_param

	if not extra_param.alertSpeed then
		return
	end

	self:ResetVelocity(self._velocity * extra_param.alertSpeed)

	self.alertSpeedRatio = extra_param.alertSpeed
end

function BattleSpaceLaserUnit.IsAlert(self)
	return self._alertFlag
end

function BattleSpaceLaserUnit.Update(self, timeStamp)
	BattleSpaceLaserUnit.super.Update(self, timeStamp)

	self._reachDestFlag = timeStamp > self._timeStamp + self._lifeTime

	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	for clbObjID, collidedTime in pairs(self._collidedTimes) do
		if currentTime > collidedTime + self._hitInterval then
			self._collidedTimes[clbObjID] = nil
			self._collidedList[clbObjID] = nil
		end
	end
end

function BattleSpaceLaserUnit.GetCollidedList(self)
	return self._collidedList, self._collidedTimes
end

function BattleSpaceLaserUnit.RegisterLifeEndCB(self, liftEndCb)
	self._lifeEndCb = liftEndCb
end

function BattleSpaceLaserUnit.UnRegisterLifeEndCB(self)
	self._lifeEndCb = nil
end
