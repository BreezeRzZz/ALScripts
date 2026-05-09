ys = ys or {}

local ys = ys
local vector3Up = Vector3.up
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleTrackingAAMissileUnit = class("BattleTrackingAAMissileUnit", ys.Battle.BattleBulletUnit)

BattleTrackingAAMissileUnit.__name = "BattleTrackingAAMissileUnit"
ys.Battle.BattleTrackingAAMissileUnit = BattleTrackingAAMissileUnit

--- @class BattleTrackingAAMissileUnit : BattleBulletUnit
--- 追踪防空导弹子弹：继承自BattleBulletUnit，可同时进行追踪和加速，
--- 支持按距离和角度筛选目标，带有瞄准标记特效
--- 加速度逻辑：计算u/v方向加速度叠加到速度向量上
function BattleTrackingAAMissileUnit.doAccelerate(self, timeStamp)
	local accU, accV = self:GetAcceleration(timeStamp)

	if accU == 0 and accV == 0 then
		return
	end

	if accU < 0 and self._speedLength + accU < 0 then
		self:reverseAcceleration()
	end

	self._speed:Set(self._speed.x + self._speedNormal.x * accU + self._speedCross.x * accV, self._speed.y + self._speedNormal.y * accU + self._speedCross.y * accV, self._speed.z + self._speedNormal.z * accU + self._speedCross.z * accV)

	self._speedLength = self._speed:Magnitude()

	if self._speedLength ~= 0 then
		self._speedNormal:Copy(self._speed)
		self._speedNormal:Div(self._speedLength)
	end

	self._speedCross:Copy(self._speedNormal)
	self._speedCross:Cross2(vector3Up)
end

--- 追踪逻辑：用FilteredList+TargetWeightiest选择最佳目标，直接转向（无角度限制，全程追踪）
function BattleTrackingAAMissileUnit.doTrack(self)
	if self:getTrackingTarget() == nil then
		local filteredList = self:GetFilteredList()
		local bestTarget = BattleTargetChoise.TargetWeightiest(self, nil, filteredList)[1]

		if bestTarget ~= nil then
			self:setTrackingTarget(bestTarget)
		end
	end

	local target = self:getTrackingTarget()

	if target == nil or target == -1 then
		return
	elseif not target:IsAlive() then
		self:CleanAimMark()
		self:setTrackingTarget(-1)

		return
	end

	local aimPosition = target:GetBeenAimedPosition()

	if not aimPosition then
		return
	end

	local direction = aimPosition - self:GetPosition()

	direction:SetNormalize()

	local speedDir = Vector3.Normalize(self._speed)
	local cosAngle = Vector3.Dot(speedDir, direction)
	local sinAngle = speedDir.z * direction.x - speedDir.x * direction.z
	local speedRatio = self:GetSpeedRatio()
	local cosAngularActual = cosAngle
	local sinAngularActual = sinAngle
	-- 直接转向目标方向（无角度限制）
	local speedX = self._speed.x * cosAngularActual + self._speed.z * sinAngularActual
	local speedZ = self._speed.z * cosAngularActual - self._speed.x * sinAngularActual

	self._speed:Set(speedX, 0, speedZ)
end

--- 仅处理重力
function BattleTrackingAAMissileUnit.doNothing(self)
	if self._gravity ~= 0 then
		self._verticalSpeed = self._verticalSpeed + self._gravity * self:GetSpeedRatio()
	end
end

--- @return table<number, BattleUnit> 经过距离和角度筛选的目标列表
function BattleTrackingAAMissileUnit.GetFilteredList(self)
	local allHarm = BattleTargetChoise.TargetAllHarm(self)
	local filteredByRange = self:FilterRange(allHarm)

	return (self:FilterAngle(filteredByRange))
end

--- @param targets table<number, BattleUnit>
--- @return table<number, BattleUnit> 在追踪距离内的目标
function BattleTrackingAAMissileUnit.FilterRange(self, targets)
	if not self._trackDist then
		return targets
	end

	for i = #targets, 1, -1 do
		if self:IsOutOfRange(targets[i]) then
			table.remove(targets, i)
		end
	end

	return targets
end

--- @param target BattleUnit
--- @return boolean 是否超出追踪距离
function BattleTrackingAAMissileUnit.IsOutOfRange(self, target)
	if not self._trackDist then
		return true
	end

	return self:GetDistance(target) > self._trackDist
end

--- @param targets table<number, BattleUnit>
--- @return table<number, BattleUnit> 在追踪角度内的目标
function BattleTrackingAAMissileUnit.FilterAngle(self, targets)
	if not self._trackAngle or self._trackAngle >= 360 then
		return targets
	end

	for i = #targets, 1, -1 do
		if self:IsOutOfAngle(targets[i]) then
			table.remove(targets, i)
		end
	end

	return targets
end

--- @param target BattleUnit
--- @return boolean 是否超出追踪角度
function BattleTrackingAAMissileUnit.IsOutOfAngle(self, target)
	if not self._trackAngle or self._trackAngle >= 360 then
		return false
	end

	local bulletPos = self:GetPosition()
	local toTarget = target:GetPosition() - bulletPos
	local speedNormal = self._speedNormal
	local cosValue = Vector3.Dot(toTarget, speedNormal) / toTarget:Magnitude()
	local angle = math.acos(cosValue)

	return angle > self._trackRadian or angle < -self._trackRadian
end

--- @param fxData table 追踪特效数据
function BattleTrackingAAMissileUnit.SetTrackingFXData(self, fxData)
	self._trackingFXData = fxData
end

--- @param angle number 发射角度
--- 组合updateSpeed函数链：追踪 + 加速 + doNothing（顺序调用）
function BattleTrackingAAMissileUnit.InitSpeed(self, angle)
	if self._yAngle == nil then
		if self._targetPos ~= nil then
			self._yAngle = angle + self._barrageAngle
		else
			self._yAngle = self._baseAngle + self._barrageAngle
		end
	end

	self:calcSpeed()

	local speedFuncs = {}

	local function updateSpeedWrapper(self, timeStamp)
		for _, func in ipairs(speedFuncs) do
			func(self, timeStamp)
		end

		local trackingTarget = self:getTrackingTarget()

		if trackingTarget and trackingTarget ~= -1 and not self._trackingFXData.aimingFX and self._trackingFXData.fxName and self._trackingFXData.fxName ~= "" then
			local character = ys.Battle.BattleState.GetInstance():GetSceneMediator():GetCharacter(trackingTarget:GetUniqueID())

			self._trackingFXData.aimingFX = character:AddFX(self._trackingFXData.fxName)
		end
	end

	if self:IsTracker() then
		local tracker = self._accTable.tracker

		self._trackAngle = 360
		self._trackDist = tracker.range

		if tracker.angular then
			self._trackRadian = math.deg2Rad * self._trackAngle * 0.5
		end

		table.insert(speedFuncs, self.doTrack)
	end

	if self:HasAcceleration() then
		self._speedLength = self._speed:Magnitude()
		self._speedNormal = self._speed / self._speedLength
		self._speedCross = Vector3.Cross(self._speedNormal, vector3Up)

		table.insert(speedFuncs, function(self, ...)
			self._speedLength = self._speed:Magnitude()
			self._speedNormal = self._speed / self._speedLength
			self._speedCross = Vector3.Cross(self._speedNormal, vector3Up)

			self.doAccelerate(self, ...)
		end)
	end

	if #speedFuncs == 0 then
		table.insert(speedFuncs, self.doNothing)
	end

	self.updateSpeed = updateSpeedWrapper
end

--- 清除追踪目标上的瞄准特效
function BattleTrackingAAMissileUnit.CleanAimMark(self)
	local target = self:getTrackingTarget()

	if target and target ~= -1 and self._trackingFXData.aimingFX then
		local character = ys.Battle.BattleState.GetInstance():GetSceneMediator():GetCharacter(target:GetUniqueID())

		if character then
			character:RemoveFX(self._trackingFXData.aimingFX)
		end

		self._trackingFXData.aimingFX = nil
	end
end

--- 超出射程时先清除瞄准标记
function BattleTrackingAAMissileUnit.OutRange(self, ...)
	self:CleanAimMark()
	BattleTrackingAAMissileUnit.super.OutRange(self, ...)
end
