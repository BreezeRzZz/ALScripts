ys = ys or {}

local ys = ys
local AutoPilotRelativeBrownian = class("AutoPilotRelativeBrownian", ys.Battle.IPilot)

ys.Battle.AutoPilotRelativeBrownian = AutoPilotRelativeBrownian
AutoPilotRelativeBrownian.__name = "AutoPilotRelativeBrownian"

function AutoPilotRelativeBrownian.Ctor(self, ...)
	AutoPilotRelativeBrownian.super.Ctor(self, ...)
end

function AutoPilotRelativeBrownian.SetParameter(self, paramList, toIndex)
	AutoPilotRelativeBrownian.super.SetParameter(self, paramList, toIndex)

	self._randomPoint = {
		X1 = paramList.X1,
		X2 = paramList.X2,
		Z1 = paramList.Z1,
		Z2 = paramList.Z2
	}
	self._stop = paramList.stopCount
	self._move = paramList.moveCount
	self._random = paramList.randomCount or 30
end

function AutoPilotRelativeBrownian.Active(self, target)
	self._stopCount = self._stop
	self._moveCount = 0
	self._randomCount = 0

	local position = Clone(target:GetPosition())
	-- 和Brownian的区别就是随机点的选取是基于当前位置的偏移量，其余逻辑相同
	self._relativePoint = {
		X1 = self._randomPoint.X1 + position.x,
		X2 = self._randomPoint.X2 + position.x,
		Z1 = self._randomPoint.Z1 + position.z,
		Z2 = self._randomPoint.Z2 + position.z
	}
	self._referencePoint = ys.Battle.BattleFormulas.RandomPos(self._relativePoint)

	AutoPilotRelativeBrownian.super.Active(self, target)
end

function AutoPilotRelativeBrownian.GetDirection(self, position)
	if self:IsExpired() then
		self:Finish()

		return Vector3.zero
	end

	self._moveCount = self._moveCount or 0

	if self._stop > self._stopCount then
		self._stopCount = self._stopCount + 1

		return Vector3.zero
	end

	local direction = self._referencePoint - position

	if direction.magnitude < 0.4 or self._randomCount > self._random then
		if self._move < self._moveCount then
			self._stopCount = 0
			self._moveCount = 0
		else
			self._randomCount = 0

			local newReferencePoint = ys.Battle.BattleFormulas.RandomPos(self._relativePoint)
			local attempts = 0

			while Vector3.SqrDistance(newReferencePoint, position) < 5 do
				newReferencePoint = ys.Battle.BattleFormulas.RandomPos(self._relativePoint)
				attempts = attempts + 1
			end

			self._referencePoint = newReferencePoint
		end

		return Vector3.zero
	else
		self._randomCount = self._randomCount + 1
		self._moveCount = self._moveCount + 1

		return direction.normalized
	end
end
