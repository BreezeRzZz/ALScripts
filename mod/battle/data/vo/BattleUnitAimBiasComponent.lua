ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleFormulas = ys.Battle.BattleFormulas

ys.Battle.BattleUnitAimBiasComponent = class("BattleUnitAimBiasComponent")
ys.Battle.BattleUnitAimBiasComponent.__name = "BattleUnitAimBiasComponent"

local BattleUnitAimBiasComponent = ys.Battle.BattleUnitAimBiasComponent

BattleUnitAimBiasComponent.NORMAL = 1
BattleUnitAimBiasComponent.DIVING = 2
BattleUnitAimBiasComponent.STATE_SUMMON_SICKNESS = "STATE_SUMMON_SICKNESS"
BattleUnitAimBiasComponent.STATE_ACTIVITING = "STATE_ACTIVITING"
BattleUnitAimBiasComponent.STATE_SKILL_EXPOSE = "STATE_SKILL_EXPOSE"
BattleUnitAimBiasComponent.STATE_TOTAL_EXPOSE = "STATE_TOTAL_EXPOSE"
BattleUnitAimBiasComponent.STATE_EXPIRE = "STATE_EXPIRE"

-- BattleDataFunction.AttachWeather调用, 该组件用于管理夜战隐匿相关的瞄准偏移机制(与隐匿组件区分)
function BattleUnitAimBiasComponent.Ctor(self)
	return
end

function BattleUnitAimBiasComponent.Dispose(self)
	self:clear()
end

function BattleUnitAimBiasComponent.init(self)
	self._crewList = {}
	self._maxBiasRange = 0
	self._minBiasRange = 0
	self._currentBiasRange = 0
	self._biasAttr = 0
	self._decaySpeed = 0
	self._ratioSpeed = 0
	self._combinedSpeed = 0
	self._pos = Vector3.zero
end

function BattleUnitAimBiasComponent.ConfigRangeFormula(self, rangeFormulaFunc, decayFormulaFunc)
	self._rangeFormulaFunc = rangeFormulaFunc
	self._decayFormulaFunc = decayFormulaFunc

	self:init()
end

function BattleUnitAimBiasComponent.ConfigMinRange(self, minBiasRange)
	self._minBiasRange = minBiasRange
end

function BattleUnitAimBiasComponent.Active(self, state)
	self._state = state
	self._currentBiasRange = self._maxBiasRange
	self._activeTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime()
	self._lastUpdateTimeStamp = self._activeTimeStamp
end

function BattleUnitAimBiasComponent.GetHost(self)
	return self._host
end

function BattleUnitAimBiasComponent.Update(self, timeStamp)
	self._pos = self._host:GetPosition()

	-- 数值衰减速度
	local aimBiasDecaySpeed = BattleAttr.GetCurrent(self._host, "aimBiasDecaySpeed")
	-- ratioSpeed: 根据maxBiasRange计算的百分比衰减速度
	local ratioSpeed = BattleAttr.GetCurrent(self._host, "aimBiasDecaySpeedRatio") * self._maxBiasRange

	self._ratioSpeed = ratioSpeed
	self._combinedSpeed = self._decaySpeed + aimBiasDecaySpeed + ratioSpeed

	if self._state == BattleUnitAimBiasComponent.STATE_SUMMON_SICKNESS then
		-- AIM_BIAS_ENEMY_INIT_TIME = 1.5
		if timeStamp - self._activeTimeStamp > BattleConfig.AIM_BIAS_ENEMY_INIT_TIME then
			-- 也即瞄准偏移需要1.5s才能激活
			self:ChangeState(BattleUnitAimBiasComponent.STATE_ACTIVITING)
		end
	elseif self._state == BattleUnitAimBiasComponent.STATE_SKILL_EXPOSE then
		self._biasAttr = 0
	else
		-- 缩圈的量
		local decayedValue = self._combinedSpeed * (timeStamp - self._lastUpdateTimeStamp)

		self._currentBiasRange = Mathf.Clamp(self._currentBiasRange - decayedValue, self._minBiasRange, self._maxBiasRange)
		self._biasAttr = self._currentBiasRange

		if self._currentBiasRange <= self._minBiasRange then
			self:ChangeState(BattleUnitAimBiasComponent.STATE_TOTAL_EXPOSE)
		else
			self:ChangeState(BattleUnitAimBiasComponent.STATE_ACTIVITING)
		end
	end

	self._lastUpdateTimeStamp = timeStamp

	self:biasEffect()
end

function BattleUnitAimBiasComponent.GetCurrentRate(self)
	return (self._currentBiasRange - self._minBiasRange) / self._progressLength
end

function BattleUnitAimBiasComponent.GetDecayRatioSpeed(self)
	return self._ratioSpeed
end

function BattleUnitAimBiasComponent.GetCurrentState(self)
	return self._state
end

function BattleUnitAimBiasComponent.IsFaint(self)
	return self._state == BattleUnitAimBiasComponent.STATE_TOTAL_EXPOSE or self._state == BattleUnitAimBiasComponent.STATE_SKILL_EXPOSE
end

function BattleUnitAimBiasComponent.GetPosition(self)
	return self._pos
end

function BattleUnitAimBiasComponent.GetCrewCount(self)
	return #self._crewList
end

function BattleUnitAimBiasComponent.GetRange(self)
	local range
	-- 技能破隐期间, 瞄准偏移范围是最小的, 也即暴露程度最高
	if self._state == BattleUnitAimBiasComponent.STATE_SKILL_EXPOSE then
		range = self._minBiasRange
	else
		range = self._currentBiasRange
	end

	return range
end

function BattleUnitAimBiasComponent.GetDecayFactorType(self)
	if self._host:GetCurrentOxyState() == BattleConst.OXY_STATE.DIVE then
		return BattleUnitAimBiasComponent.DIVING
	else
		return BattleUnitAimBiasComponent.NORMAL
	end
end

function BattleUnitAimBiasComponent.IsHostile(self)
	return self._hostile
end

function BattleUnitAimBiasComponent.SetDecayFactor(self, decayFactor, extraDecaySpeed)
	if decayFactor == 0 then
		self._decaySpeed = 0

		return
	end

	if self._cacheFactor == decayFactor and self._cacheType == self:GetDecayFactorType() then
		return
	end

	if self:GetDecayFactorType() == BattleUnitAimBiasComponent.DIVING then
		self._decaySpeed = BattleFormulas.CalculateBiasDecayDiving(decayFactor)
	else
		self._decaySpeed = self._decayFormulaFunc(decayFactor)
	end

	self._decaySpeed = self._decaySpeed + extraDecaySpeed
end

function BattleUnitAimBiasComponent.AppendCrew(self, crew)
	if table.contains(self._crewList, crew) then
		return
	end

	table.insert(self._crewList, crew)
	self:switchHost()
	self:flush()
	crew:AttachAimBias(self)

	self._currentBiasRange = self._maxBiasRange
end

function BattleUnitAimBiasComponent.RemoveCrew(self, crew)
	local removedIndex

	for index, _crew in ipairs(self._crewList) do
		if _crew == crew then
			table.remove(self._crewList, index)

			break
		end
	end

	if #self._crewList == 0 then
		self:clear()
	else
		self:switchHost()
		self:flush()
	end
end

function BattleUnitAimBiasComponent.UpdateSkillLock(self)
	if BattleAttr.IsLockAimBias(self._host) then
		self:ChangeState(BattleUnitAimBiasComponent.STATE_SKILL_EXPOSE)
	elseif self._currentBiasRange <= self._minBiasRange then
		self:ChangeState(BattleUnitAimBiasComponent.STATE_TOTAL_EXPOSE)
	else
		self:ChangeState(BattleUnitAimBiasComponent.STATE_ACTIVITING)
	end

	self._host:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_AIMBIAS_LOCK))
end

function BattleUnitAimBiasComponent.SmokeExitPause(self)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	self._pauseStartTimeStamp = currentTime

	BattleAttr.SetCurrent(self._host, "lockAimBias", 1)
	self:UpdateSkillLock()
	self:Update(currentTime)

	local function onRestoreTimerEnds()
		self:removeRestoreTimer()
		self._host:DetachAimBias()
	end

	self._smokeRestoreTimer = pg.TimeMgr.GetInstance():AddBattleTimer("smokeRestoreTimer", 0, BattleConfig.AIM_BIAS_SMOKE_RESTORE_DURATION, onRestoreTimerEnds, true)
end

function BattleUnitAimBiasComponent.SomkeExitResume(self)
	self:removeRestoreTimer()

	local elapsedTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._pauseStartTimeStamp

	self._lastUpdateTimeStamp = self._lastUpdateTimeStamp + elapsedTime

	self:UpdateSkillLock()
end

function BattleUnitAimBiasComponent.SmokeRecover(self)
	-- AIM_BIAS_SMOKE_RECOVERY_RATE = 0.6
	self._currentBiasRange = math.min(self._maxBiasRange, self._currentBiasRange + self._maxBiasRange * BattleConfig.AIM_BIAS_SMOKE_RECOVERY_RATE)
end

function BattleUnitAimBiasComponent.ChangeState(self, state)
	self._state = state
end

function BattleUnitAimBiasComponent.SetHostile(self)
	self._hostile = true
end

function BattleUnitAimBiasComponent.switchHost(self)
	self._host = self._crewList[1]

	self._host:HostAimBias()
end

function BattleUnitAimBiasComponent.flush(self)
	self._maxBiasRange = math.max(self._rangeFormulaFunc(self._crewList), self._minBiasRange)

	local cld_box = self._host:GetTemplate().cld_box

	self._progressLength = self._maxBiasRange - self._minBiasRange
end

function BattleUnitAimBiasComponent.biasEffect(self)
	for _, crew in ipairs(self._crewList) do
		BattleAttr.SetCurrent(crew, "aimBias", self._biasAttr)
	end
end

function BattleUnitAimBiasComponent.removeRestoreTimer(self)
	BattleAttr.SetCurrent(self._host, "lockAimBias", 0)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._smokeRestoreTimer)

	self._smokeRestoreTimer = nil
end

function BattleUnitAimBiasComponent.clear(self)
	if self._smokeRestoreTimer then
		self:removeRestoreTimer()
	end

	self._crewList = {}
	self._pos = nil
	self._state = BattleUnitAimBiasComponent.STATE_EXPIRE
end
