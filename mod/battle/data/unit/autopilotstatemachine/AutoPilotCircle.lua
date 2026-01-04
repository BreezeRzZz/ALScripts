ys = ys or {}

local ys = ys
local up = Vector3.up
local AutoPilotCircle = class("AutoPilotCircle", ys.Battle.IPilot)

ys.Battle.AutoPilotCircle = AutoPilotCircle
AutoPilotCircle.__name = "AutoPilotCircle"

function AutoPilotCircle.Ctor(self, ...)
	AutoPilotCircle.super.Ctor(self, ...)
end

-- 这类运动大致是以给定的(X, Z)坐标为圆心，radius为半径，围绕圆心做圆周运动
function AutoPilotCircle.SetParameter(self, paramList, toIndex)
	AutoPilotCircle.super.SetParameter(self, paramList, toIndex)

	self._referencePoint = Vector3(paramList.x, 0, paramList.z)
	self._radius = paramList.radius
	-- 逆时针or顺时针
	if paramList.antiClockWise == true then
		self.GetDirection = AutoPilotCircle._antiClockWise
	else
		self.GetDirection = AutoPilotCircle._clockWise
	end
end

function AutoPilotCircle._clockWise(self, position)
	if self:IsExpired() then
		self:Finish()

		return Vector3.zero
	end
	-- 超出圆圈半径则先回到圆圈上(朝向圆心)
	if (position - self._referencePoint).magnitude > self._radius then
		return (self._referencePoint - position).normalized
	else
		-- 否则沿切线方向前进，这可由简单的旋转矩阵计算得到(或者斜率相乘为-1)
		local direction = (self._referencePoint - position).normalized
		local dx = -direction.z
		local dz = direction.x

		return Vector3(dx, 0, dz)
	end
end

function AutoPilotCircle._antiClockWise(self, position)
	if self._duration > 0 and pg.TimeMgr.GetInstance():GetCombatTime() - self._startTime > self._duration then
		self:Finish()

		return Vector3.zero
	end

	if (position - self._referencePoint).magnitude > self._radius then
		return (self._referencePoint - position).normalized
	else
		-- 这里有区别，是一个反方向的切线
		local direction = (self._referencePoint - position).normalized
		local dx = direction.z
		local dz = -direction.x

		return Vector3(dx, 0, dz)
	end
end
