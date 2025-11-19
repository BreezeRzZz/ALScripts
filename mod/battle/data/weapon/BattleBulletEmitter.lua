ys = ys or {}

-- this is the artificial recovery of variable names of decompiled code.
-- var_0_0 -> ys
-- var_0_1 -> pg
-- var_0_2 -> BattleConst
-- var_0_3 -> BattleDataFunction
-- var_0_4 -> math
-- var_0_5 -> BattleBulletEmitter
local ys = ys
local pg = pg
local BattleConst = ys.Battle.BattleConst
local BattleDataFunction = ys.Battle.BattleDataFunction
local math = math
local BattleBulletEmitter = class("BattleBulletEmitter")

ys.Battle.BattleBulletEmitter = BattleBulletEmitter
BattleBulletEmitter.__name = "BattleBulletEmitter"
BattleBulletEmitter.STATE_ACTIVE = "ACTIVE"
BattleBulletEmitter.STATE_STOP = "STOP"

-- for function args:
	-- the first arg usually represents 'self' (the instance obj of the class)
	-- other args can only be inferred from the logic of the function
-- arg_1_0 -> self
-- arg_1_1 -> spawnFunc
-- arg_1_2 -> stopFunc
-- arg_1_3 -> barrageID
function BattleBulletEmitter.Ctor(self, spawnFunc, stopFunc, barrageID)
	self._spawnFunc = spawnFunc
	self._stopFunc = stopFunc
	self._barrageID = barrageID
	self._barrageTemp = BattleDataFunction.GetBarrageTmpDataFromID(barrageID)
	self._offsetPriority = self._barrageTemp.offset_prioritise
	self._isRandomAngle = self._barrageTemp.random_angle
	self._timerList = {}

	if self._barrageTemp.delta_delay ~= 0 then
		self.PrimalIteration = self._advancePrimalIteration
	elseif self._barrageTemp.delay ~= 0 then
		self.PrimalIteration = self._averagePrimalIteration
	else
		self.PrimalIteration = self._nonDelayPrimalIteration
	end

	self._primalMax = self._barrageTemp.primal_repeat + 1

	-- arg_2_0 -> timerID
	function self.timerCb(timerID)
		self._timerList[timerID](self, timerID)
	end
end

-- arg_3_0 -> self
function BattleBulletEmitter.Ready(self)
	self._state = self.STATE_ACTIVE
	self._seniorCounter = -1

	self:ClearAllTimer()
end

-- arg_4_0 -> self
-- arg_4_1 -> target
-- arg_4_2 -> dir
function BattleBulletEmitter.Fire(self, target, dir)
	self._target = target
	self._dir = dir or BattleConst.UnitDir.RIGHT

	if not self._convertedDirBarrage then
		self._convertedDirBarrage = BattleDataFunction.GetConvertedBarrageTableFromID(self._barrageID, self._dir)[self._dir]
	end

	self:SeniorIteration()
end

-- arg_5_0 -> self
function BattleBulletEmitter.Stop(self)
	self._state = self.STATE_STOP
	self._target = nil

	self:ClearAllTimer()
	self._stopFunc(self)
end

-- arg_6_0 -> self
function BattleBulletEmitter.Interrupt(self)
	self._state = self.STATE_STOP
	self._target = nil

	self:ClearAllTimer()
end

-- arg_7_0 -> self
function BattleBulletEmitter.Destroy(self)
	self._spawnFunc = nil
	self._stopFunc = nil
	self._convertedDirBarrage = nil

	if self._timerList then
		self:ClearAllTimer()
	end
end

-- arg_8_0 -> self
function BattleBulletEmitter.GetState(self)
	return self._state
end

-- arg_9_0 -> self
function BattleBulletEmitter.ClearAllTimer(self)
	-- iter_9_0 -> timerID
	-- iter_9_1 -> callbackFunc(not used, here -> _)
	for timerID, _ in pairs(self._timerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)
	end

	self._timerList = {}
end

-- arg_10_0 -> self
function BattleBulletEmitter.GenerateBullet(self)
	-- var_10_0 -> barrageData
	-- var_10_1 -> offsetX
	local barrageData = self._convertedDirBarrage[self._primalCounter]
	local offsetX = barrageData.OffsetX

	self._delay = barrageData.Delay

	-- var_10_2 -> angle
	local angle

	if self._isRandomAngle then
		angle = (math.random() - 0.5) * barrageData.Angle
	else
		angle = barrageData.Angle
	end

	-- var_10_3 -> bullet
	local bullet = self._spawnFunc(offsetX, barrageData.OffsetZ, angle, self._offsetPriority, self._target, self._primalCounter)

	if bullet then
		-- var_10_4 -> transBarrage
		local transBarrage = BattleDataFunction.GenerateTransBarrage(self._barrageID, self._dir, self._primalCounter)

		bullet:SetBarrageTransformTempate(transBarrage)
	end

	self:Interation()
end

-- arg_11_0 -> self
-- arg_11_1 -> timerID
function BattleBulletEmitter.DelaySeniorFunc(self, timerID)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)

	self._timerList[timerID] = nil

	self:PrimalIteration()
end

-- arg_12_0 -> self
function BattleBulletEmitter.SeniorIteration(self)
	if self._state ~= self.STATE_ACTIVE then
		return
	end

	self._seniorCounter = self._seniorCounter + 1

	if self._seniorCounter > self._barrageTemp.senior_repeat then
		self:Stop()
	else
		self:InitParam()

		-- var_12_0 -> delay
		local delay

		if self._seniorCounter == 0 then
			delay = self._barrageTemp.first_delay
		else
			delay = self._barrageTemp.senior_delay
		end

		if delay > 0 then
			-- var_12_1 -> timerID
			local timerID = pg.TimeMgr.GetInstance():AddBattleTimer("spawnBullet", -1, delay, self.timerCb, true)

			self._timerList[timerID] = self.DelaySeniorFunc
		else
			self:PrimalIteration()
		end
	end
end

-- arg_13_0 -> self
function BattleBulletEmitter.InitParam(self)
	self._delay = self._barrageTemp.delay
	self._primalCounter = 1
end

-- arg_14_0 -> self
function BattleBulletEmitter.Interation(self)
	self._primalCounter = self._primalCounter + 1
end

-- arg_15_0 -> self
-- arg_15_1 -> timeScale
function BattleBulletEmitter.SetTimeScale(self, timeScale)
	if self._timerList then
		-- iter_15_0 -> timerID
		-- iter_15_1 -> callbackFunc(not used, here -> _)
		for timerID, _ in pairs(self._timerList) do
			timerID:SetScale(timeScale)
		end
	end
end

-- arg_16_0 -> self
-- arg_16_1 -> timerID
function BattleBulletEmitter.DelayPrimalConst(self, timerID)
	self:GenerateBullet()

	if self._primalCounter > self._primalMax then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)

		self._timerList[timerID] = nil

		self:SeniorIteration()
	end
end

-- arg_17_0 -> self
function BattleBulletEmitter._averagePrimalIteration(self)
	if self._state ~= self.STATE_ACTIVE then
		return
	end

	-- var_17_0 -> timerID
	local timerID = pg.TimeMgr.GetInstance():AddBattleTimer("spawnBullet", -1, self._delay, self.timerCb, true)

	self._timerList[timerID] = self.DelayPrimalConst
end

-- arg_18_0 -> self
-- arg_18_1 -> timerID
function BattleBulletEmitter.DelayPrimalAdvance(self, timerID)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)

	self._timerList[timerID] = nil

	self:GenerateBullet()

	if self._primalCounter > self._primalMax then
		self:SeniorIteration()
	else
		self:PrimalIteration()
	end
end

-- arg_19_0 -> self
function BattleBulletEmitter._advancePrimalIteration(self)
	if self._state ~= self.STATE_ACTIVE then
		return
	end

	if self._delay == 0 then
		self:GenerateBullet()

		if self._primalCounter > self._primalMax then
			self:SeniorIteration()
		else
			self:PrimalIteration()
		end
	else
		-- var_19_0 -> timerID
		local timerID = pg.TimeMgr.GetInstance():AddBattleTimer("spawnBullet", -1, self._delay, self.timerCb, true)

		self._timerList[timerID] = self.DelayPrimalAdvance
	end
end

-- arg_20_0 -> self
function BattleBulletEmitter._nonDelayPrimalIteration(self)
	if self._state ~= self.STATE_ACTIVE then
		return
	end

	self:GenerateBullet()

	if self._primalCounter > self._primalMax then
		self:SeniorIteration()
	else
		self:PrimalIteration()
	end
end
