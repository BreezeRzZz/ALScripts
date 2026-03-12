ys = ys or {}

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

--- @class BattleBulletEmitter
--- @param spawnFunc function: 用于生成子弹
--- @param stopFunc function: 停止时的回调函数
--- @param barrageID number: 弹幕ID，到barrage_template中获取数据
--- @return nil
--- BattleBulletEmitter的构造函数
function BattleBulletEmitter.Ctor(self, spawnFunc, stopFunc, barrageID)
	self._spawnFunc = spawnFunc
	self._stopFunc = stopFunc
	self._barrageID = barrageID
	self._barrageTemp = BattleDataFunction.GetBarrageTmpDataFromID(barrageID)
	self._offsetPriority = self._barrageTemp.offset_prioritise
	self._isRandomAngle = self._barrageTemp.random_angle
	--- @type table<Timer, function>
	--- Timer结构见Timer.lua，对应的value是相应的iteration函数
	self._timerList = {}

	if self._barrageTemp.delta_delay ~= 0 then
		self.PrimalIteration = self._advancePrimalIteration
	elseif self._barrageTemp.delay ~= 0 then
		self.PrimalIteration = self._averagePrimalIteration
	else
		self.PrimalIteration = self._nonDelayPrimalIteration
	end

	self._primalMax = self._barrageTemp.primal_repeat + 1

	function self.timerCb(timer)
		self._timerList[timer](self, timer)
	end
end

--- @return nil
--- 初始化
--- - 设置状态为ACTIVE
--- - 重置计数器
--- - 清除所有Timer
function BattleBulletEmitter.Ready(self)
	self._state = self.STATE_ACTIVE
	self._seniorCounter = -1

	self:ClearAllTimer()
end

--- @param target BattleUnit
--- @param dir number
--- @return nil
--- Fire函数
function BattleBulletEmitter.Fire(self, target, dir)
	self._target = target
	self._dir = dir or BattleConst.UnitDir.RIGHT

	if not self._convertedDirBarrage then
		self._convertedDirBarrage = BattleDataFunction.GetConvertedBarrageTableFromID(self._barrageID, self._dir)[self._dir]
	end

	self:SeniorIteration()
end

--- @return nil
--- 停止发射子弹
function BattleBulletEmitter.Stop(self)
	self._state = self.STATE_STOP
	self._target = nil

	self:ClearAllTimer()
	self._stopFunc(self)
end

--- @return nil
--- 被打断时，中断发射子弹
--- 不会调用停止回调函数
function BattleBulletEmitter.Interrupt(self)
	self._state = self.STATE_STOP
	self._target = nil

	self:ClearAllTimer()
end

--- @return nil
--- 销毁
function BattleBulletEmitter.Destroy(self)
	self._spawnFunc = nil
	self._stopFunc = nil
	self._convertedDirBarrage = nil

	if self._timerList then
		self:ClearAllTimer()
	end
end

--- @return string
--- 获取当前状态
function BattleBulletEmitter.GetState(self)
	return self._state
end

--- @return nil
--- 清除所有Timer
function BattleBulletEmitter.ClearAllTimer(self)
	for timer, _ in pairs(self._timerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)
	end

	self._timerList = {}
end

--- @return nil
--- 生成子弹
--- 被各种PrimalIteration调用
function BattleBulletEmitter.GenerateBullet(self)
	local barrageData = self._convertedDirBarrage[self._primalCounter]
	local offsetX = barrageData.OffsetX

	self._delay = barrageData.Delay

	local angle

	if self._isRandomAngle then
		angle = (math.random() - 0.5) * barrageData.Angle
	else
		angle = barrageData.Angle
	end

	--- @type BattleBulletUnit
	local bullet = self._spawnFunc(offsetX, barrageData.OffsetZ, angle, self._offsetPriority, self._target, self._primalCounter)

	if bullet then
		local transBarrage = BattleDataFunction.GenerateTransBarrage(self._barrageID, self._dir, self._primalCounter)

		bullet:SetBarrageTransformTempate(transBarrage)
	end

	self:Interation()
end

--- @param timer Timer
--- @return nil
--- Senior Iteration与之后的Primal Iteration之间的衔接
--- - Senior Iteration内部有一个或多个Primal Iteration
--- - 时间轴示例：Senior 1 -> (first_delay) -> Primal 1 -> (delay) -> Primal 2 -> (delay + delta_delay * 1) -> Primal 3 -> ... -> Senior 2 -> (senior_delay) -> ...
function BattleBulletEmitter.DelaySeniorFunc(self, timer)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

	self._timerList[timer] = nil

	self:PrimalIteration()
end

--- @return nil
--- 执行Senior Iteration
function BattleBulletEmitter.SeniorIteration(self)
	if self._state ~= self.STATE_ACTIVE then
		return
	end

	self._seniorCounter = self._seniorCounter + 1

	if self._seniorCounter > self._barrageTemp.senior_repeat then
		self:Stop()
	else
		self:InitParam()

		local delay

		if self._seniorCounter == 0 then
			delay = self._barrageTemp.first_delay
		else
			delay = self._barrageTemp.senior_delay
		end

		if delay > 0 then
			--- 这里是经过delay后，执行DelaySeniorFunc
			local timer = pg.TimeMgr.GetInstance():AddBattleTimer("spawnBullet", -1, delay, self.timerCb, true)

			self._timerList[timer] = self.DelaySeniorFunc
		else
			self:PrimalIteration()
		end
	end
end

--- @return nil
--- 初始化delay和primalCounter
function BattleBulletEmitter.InitParam(self)
	self._delay = self._barrageTemp.delay
	self._primalCounter = 1
end

--- @return nil
--- primalCounter的计数方法
function BattleBulletEmitter.Interation(self)
	self._primalCounter = self._primalCounter + 1
end

--- @param timeScale number: Unity的时间缩放比例
--- @return nil
--- 设置Timer的时间缩放比例
function BattleBulletEmitter.SetTimeScale(self, timeScale)
	if self._timerList then
		for timer, _ in pairs(self._timerList) do
			-- 这里只修改了这个Timer的Scale
			timer:SetScale(timeScale)
		end
	end
end

--- @param timer Timer
--- @return nil
--- 每个Primal Iteration之间的延迟处理
--- - 每个primal对应到一次实际生成子弹
--- - 如果primalCounter满足计数，到下一个Senior Iteration
function BattleBulletEmitter.DelayPrimalConst(self, timer)
	self:GenerateBullet()

	if self._primalCounter > self._primalMax then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

		self._timerList[timer] = nil

		self:SeniorIteration()
	end
end

--- @return nil
--- 普通的Primal Iteration
--- - 对应delay非0，且没有delta_delay的情况
function BattleBulletEmitter._averagePrimalIteration(self)
	if self._state ~= self.STATE_ACTIVE then
		return
	end
	-- 每两次primal之间经过delay
	local timer = pg.TimeMgr.GetInstance():AddBattleTimer("spawnBullet", -1, self._delay, self.timerCb, true)

	self._timerList[timer] = self.DelayPrimalConst
end

--- @param timer Timer
--- @return nil
--- 每个Primal Iteration之间的延迟处理，用于delta_delay非0的情况
function BattleBulletEmitter.DelayPrimalAdvance(self, timer)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

	self._timerList[timer] = nil

	self:GenerateBullet()

	if self._primalCounter > self._primalMax then
		self:SeniorIteration()
	else
		self:PrimalIteration()
	end
end

--- @return nil
--- 变延迟的Primal Iteration
--- - 对应delta_delay非0的情况 
--- - delta_delay的使用似乎是在BattleBulletDataFunction中
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
		local timer = pg.TimeMgr.GetInstance():AddBattleTimer("spawnBullet", -1, self._delay, self.timerCb, true)

		self._timerList[timer] = self.DelayPrimalAdvance
	end
end

--- @return nil
--- 没有延迟的PrimalIteration
--- 对应delay=0且delta_delay=0的情况
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
