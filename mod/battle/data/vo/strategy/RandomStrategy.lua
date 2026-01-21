ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.RandomStrategy = class("RandomStrategy", ys.Battle.BattleJoyStickBotBaseStrategy)

local RandomStrategy = ys.Battle.RandomStrategy

RandomStrategy.__name = "RandomStrategy"
RandomStrategy.STOP_DURATION_MAX = 20
RandomStrategy.STOP_DURATION_MIN = 10
RandomStrategy.MOVE_DURATION_MAX = 60
RandomStrategy.MOVE_DURATION_MIN = 20

function RandomStrategy.Ctor(self, fleetVO)
	RandomStrategy.super.Ctor(self, fleetVO)

	self._stopCount = 0
	self._moveCount = 0
	self._speed = Vector3.zero
	self._speedCross = Vector3.zero
end

function RandomStrategy.GetStrategyType(self)
	return ys.Battle.BattleJoyStickAutoBot.RANDOM
end

function RandomStrategy.Input(self, foeShipList, foeAircraftList)
	RandomStrategy.super.Input(self, foeShipList, foeAircraftList)
	-- 初始：移动权重10，停止权重0
	self:shiftTick(0, 10)
end

local up = Vector3.up

function RandomStrategy._moveTick(self)
	-- 当移动帧用完，令stopWeight = -1
	if self._moveCount <= 0 then
		self:shiftTick(-1)
	else
		-- 移动帧-1
		self._moveCount = self._moveCount - 1

		local speedMagnitude = self._speed:Magnitude()

		self._speedCross = self._speedCross:Copy(up):Cross2(self._speed):Mul(self._crossAcc / speedMagnitude)
		self._speed = self._speed:Add(self._speedCross)
		self._hrz = self._speed.x
		self._vtc = self._speed.z
	end
end

function RandomStrategy._stopTick(self)
	if self._stopCount <= 0 then
		self:shiftTick(0, 10)
	else
		self._stopCount = self._stopCount - 1
	end
end

function RandomStrategy.shiftTick(self, stopWeight, moveWeight)
	self._stopWeight = stopWeight or self._stopWeight
	self._moveWeight = moveWeight or self._moveWeight
	-- 如果随机值大于等于0，则进入移动状态
	if math.random(self._stopWeight, self._moveWeight) >= 0 then
		-- 移动权重-1
		-- 因为每次移动结束后，都是置stopWeight=-1, 而如果连续随机到移动，moveWeight会越来越小
		-- 也即：确实会出现连续移动，但这个概率会越来越小，最多不超过10次
		self._moveWeight = self._moveWeight - 1
		-- 在[20,60]间随机
		self._moveCount = math.random(RandomStrategy.MOVE_DURATION_MIN, RandomStrategy.MOVE_DURATION_MAX)
		-- 目标点生成
		-- 注意，这个目标点只是用来确定方向，实际移动式按移动帧来，不一定会到达目标点
		self._targetPoint = self:generateTargetPoint()

		local currentPos = self._motionVO:GetPos()
		local dirX, dirZ = self.getDirection(currentPos, self._targetPoint)

		self._speed.x = dirX
		self._speed.z = dirZ
		-- 这个是一个很小的垂直加速度(向心加速度?)，因为是用来叉乘的
		self._crossAcc = math.random(-100, 100) / 10000
		self.analysis = self._moveTick
	else
		-- 对停止计数随机: random(10, 20)
		self._stopCount = math.random(RandomStrategy.STOP_DURATION_MIN, RandomStrategy.STOP_DURATION_MAX)
		self.analysis = RandomStrategy._stopTick
		self._hrz = 0
		self._vtc = 0
	end
end

function RandomStrategy.generateTargetPoint(self)
	-- 这个personality的逻辑跟神人没区别
	-- personality属于废案，现在取的定值用
	local personalityData = self._fleetVO:GetLeaderPersonality()
	-- front_rate = 0.15
	local front_rate = personalityData.front_rate
	-- rear_rate = 0.3
	local rear_rate = personalityData.rear_rate
	-- 对于友方，实际front_rate = 0.85, rear_rate = 0.7
	if self._fleetVO:GetIFF() == BattleConfig.FRIENDLY_CODE then
		front_rate = 1 - front_rate
		rear_rate = 1 - rear_rate
	end
	-- 	_totalWidth = rightBound - leftBound, _totalHeight = upperBound - lowerBound
	local randomRightBound = self._totalWidth * front_rate + self._leftBound
	local randomLeftBound = self._totalWidth * rear_rate + self._leftBound
	-- upper_rate = 0.7
	local randomUpperBound = self._totalHeight * personalityData.upper_rate + self._lowerBound
	-- lower_rate = 0.3
	local randomLowerBound = self._totalHeight * personalityData.lower_rate + self._lowerBound
	-- 通俗的讲，就是在X的0.7~0.85区间，Z的0.3~0.7区间内随机取点
	local targetX = math.random(randomLeftBound, randomRightBound)
	local targetZ = math.random(randomLowerBound, randomUpperBound)

	return (Vector3(targetX, 0, targetZ))
end
