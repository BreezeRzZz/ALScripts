ys = ys or {}

local ys = ys
local AutoPilotBrownian = class("AutoPilotBrownian", ys.Battle.IPilot)

ys.Battle.AutoPilotBrownian = AutoPilotBrownian
AutoPilotBrownian.__name = "AutoPilotBrownian"

function AutoPilotBrownian.Ctor(self, ...)
	AutoPilotBrownian.super.Ctor(self, ...)
end

function AutoPilotBrownian.SetParameter(self, paramList, toIndex)
	AutoPilotBrownian.super.SetParameter(self, paramList, toIndex)

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

function AutoPilotBrownian.Active(self, target)
	self._stopCount = self._stop
	self._moveCount = 0
	self._randomCount = 0
	-- 这里取的referencePoint为[X1,X2],[Z1,Z2]范围内的一个随机点，注意是整数随机（均匀分布整数），不会生成浮点数坐标
	self._referencePoint = ys.Battle.BattleFormulas.RandomPos(self._randomPoint)

	AutoPilotBrownian.super.Active(self, target)
end

function AutoPilotBrownian.GetDirection(self, position)
	if self:IsExpired() then
		self:Finish()

		return Vector3.zero
	end

	self._moveCount = self._moveCount or 0
	-- 如果处于停止状态，则增加停止计数器并返回零向量
	-- 这个计数器的逻辑稍有区别，退出的要求是stopCount >= stop，而不是其他的 >
	if self._stop > self._stopCount then
		self._stopCount = self._stopCount + 1

		return Vector3.zero
	end

	local direction = self._referencePoint - position
	-- 当距离目标点小于0.4或者随机帧数达到设定值时，进行下列判断
	if direction.magnitude < 0.4 or self._randomCount > self._random then
		-- 如果运动帧数达到了设定的最大值，则进入停止状态，计数器归零
		if self._move < self._moveCount then
			self._stopCount = 0
			self._moveCount = 0
		-- 否则，说明
		else
			self._randomCount = 0
			-- 再次用完全一样的方式生成一个新的随机目标点
			local newReferencePoint = ys.Battle.BattleFormulas.RandomPos(self._randomPoint)
			-- 这个attempts没啥用啊
			local attempts = 0
			-- 新随机点与当前位置距离不能小于5，否则重新生成，直到满足条件为止
			while Vector3.SqrDistance(newReferencePoint, position) < 5 do
				newReferencePoint = ys.Battle.BattleFormulas.RandomPos(self._randomPoint)
				attempts = attempts + 1
			end

			self._referencePoint = newReferencePoint
		end

		return Vector3.zero
	else
		self._randomCount = self._randomCount + 1
		self._moveCount = self._moveCount + 1

		return direction:SetNormalize()
	end
end
