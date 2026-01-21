ys = ys or {}
pg = pg or {}

local ys = ys
local pg = pg
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig
local BattleFleetMotionVO = class("BattleFleetMotionVO")

ys.Battle.BattleFleetMotionVO = BattleFleetMotionVO
BattleFleetMotionVO.__name = "BattleFleetMotionVO"

-- BattleFleetVO.init中初始化，作为舰队整体的运动VO
function BattleFleetMotionVO.Ctor(self)
	self._pos = Vector3.zero
	self._speed = Vector3.zero
	-- 默认为Vector3.right，即(1,0,0)
	self._lastDir = BattleConst.NORMALIZE_FLEET_SPEED
	self._rotateAngle = Quaternion.identity
	self._isCalibrateAcc = false
end

function BattleFleetMotionVO.GetPos(self)
	return self._pos
end

function BattleFleetMotionVO.GetSpeed(self)
	return self._speed:Clone()
end

function BattleFleetMotionVO.GetDirAngle(self)
	return self._rotateAngle
end

-- 被BattleFleetVO.UpdateMotion调用
function BattleFleetMotionVO.UpdatePos(self, referenceUnit)
	self._pos = referenceUnit:GetPosition()
end

-- 被BattleFleetVO.UpdateMotion调用
function BattleFleetMotionVO.UpdateVelocityAndDirection(self, velocity, dirX, dirZ)
	local _velocity = velocity
	local _dirX = dirX
	local _dirZ = dirZ
	local speedVec = Vector3(_dirX, 0, _dirZ):Mul(_velocity)

	self:UpdateSpeed(speedVec)
end

function BattleFleetMotionVO.UpdateSpeed(self, speedVec)
	if self._speed ~= speedVec then
		self._speed = speedVec

		if not speedVec:EqualZero() then
			self._lastDir = speedVec
		end
		-- Quaternion.SetFromToRotation1(fromVector3, toVector3)
		self._rotateAngle:SetFromToRotation1(BattleConst.NORMALIZE_FLEET_SPEED, self._lastDir)
	end
end

function BattleFleetMotionVO.CalibrateAcc(self, isCalibrate)
	self._isCalibrateAcc = isCalibrate
end

function BattleFleetMotionVO.SetPos(self, pos)
	self._pos = pos
end
