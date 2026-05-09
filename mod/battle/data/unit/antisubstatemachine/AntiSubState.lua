ys = ys or {}

--- @class AntiSubState : 反潜警戒状态机
--- 管理反潜单位的警戒等级（平静→可疑→警觉→交战）
local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.AntiSubState = class("AntiSubState")
ys.Battle.AntiSubState.__name = "AntiSubState"

local AntiSubState = ys.Battle.AntiSubState

--- @param client BattleUnit: 所属单位
function AntiSubState.Ctor(self, client)
	self._client = client
	self._calmState = ys.Battle.CalmAntiSubState.New()
	self._suspiciousState = ys.Battle.SuspiciousAntiSubState.New()
	self._vigilantState = ys.Battle.VigilantAntiSubState.New()
	self._engageState = ys.Battle.EngageAntiSubState.New()
	self._currentState = self._calmState
	self._vigilantValue = 0
	self._vigilantDecayTimeStamp = nil
	self._decayFlag = false
	self._engageRage = false
	self._lastSonarDected = false
end

--- 每帧更新：计算警戒值的增减和状态切换
--- @param sonarDetectCount number: 声呐探测到的潜艇数量
--- @param floatDetectCount number: 上浮潜艇数量
function AntiSubState.Update(self, sonarDetectCount, floatDetectCount)
	if floatDetectCount > 0 and self:checkDecayRage() then
		self:OnEngageState()
	end

	if sonarDetectCount + floatDetectCount > 0 then
		self:resetVigilantDecay()
	end

	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	if self._vigilantDecayTimeStamp then
		self:updateVigilantDecay(currentTime)
	elseif self._currentState:CanDecay() and sonarDetectCount + floatDetectCount == 0 then
		self._vigilantDecayTimeStamp = currentTime
	end

	local meterSpeed = self._currentState:GetMeterSpeed()

	if self._decayFlag then
		meterSpeed = math.min(0, meterSpeed)
	end

	self._vigilantValue = math.clamp(self._vigilantValue + meterSpeed, 0, 100)

	if self._vigilantValue >= 100 and self._currentState ~= self._engageState then
		self:OnEngageState()
	end
end

--- 更新警戒值衰减
--- @param currentTime number: 当前时间
function AntiSubState.updateVigilantDecay(self, currentTime)
	if currentTime - self._vigilantDecayTimeStamp >= self._currentState:DecayDuration() then
		self._vigilantValue = self._vigilantValue - 0.01

		self._currentState:ToPreLevel(self)

		self._decayFlag = true
	end
end

--- 重置警戒衰减计时器
function AntiSubState.resetVigilantDecay(self)
	self._vigilantDecayTimeStamp = nil
	self._decayFlag = false
end

--- 检查是否处于衰减狂暴状态
--- @return boolean: 是否狂暴
function AntiSubState.checkDecayRage(self)
	return self._vigilantDecayTimeStamp and self._engageRage
end

--- 仇恨链传递
function AntiSubState.HateChain(self)
	self:resetVigilantDecay()
	self._currentState:OnHateChain(self)
end

--- 初始检查：有上浮潜艇则直接触发SubmarineFloat
--- @param floatCount number: 上浮潜艇数量
function AntiSubState.InitCheck(self, floatCount)
	if floatCount > 0 then
		self:SubmarineFloat()
	end
end

--- 水雷爆炸事件
function AntiSubState.MineExplode(self)
	if self:checkDecayRage() then
		self:OnEngageState()

		return
	end

	self:resetVigilantDecay()
	self._currentState:OnMineExplode(self)
end

--- 潜艇上浮事件
function AntiSubState.SubmarineFloat(self)
	if self:checkDecayRage() then
		self:OnEngageState()

		return
	end

	self:resetVigilantDecay()
	self._currentState:OnSubmarinFloat(self)
end

--- 警戒区域交战
function AntiSubState.VigilantAreaEngage(self)
	self:resetVigilantDecay()
	self._currentState:OnVigilantEngage(self)
end

--- 声呐探测事件：连续探测到潜艇时升级状态
--- @param detectCount number: 探测到的数量
function AntiSubState.SonarDetect(self, detectCount)
	self:DispatchSonarCheck()

	local hasDetect = detectCount > 0

	if self._lastSonarDected and hasDetect then
		self:OnEngageState()
	elseif hasDetect then
		self:OnVigilantState()
	end

	self._lastSonarDected = hasDetect
end

--- 进入平静状态
function AntiSubState.OnCalmState(self)
	self:resetVigilantDecay()

	self._currentState = self._calmState
	self._engageRage = false

	self:DispatchStateChange()
end

--- 进入可疑状态
function AntiSubState.OnSuspiciousState(self)
	self:resetVigilantDecay()

	self._currentState = self._suspiciousState

	self:DispatchStateChange()
end

--- 进入警觉状态
function AntiSubState.OnVigilantState(self)
	self:resetVigilantDecay()

	self._currentState = self._vigilantState

	self:DispatchStateChange()
end

--- 进入交战状态
--- @param skipHateChain boolean: 是否跳过仇恨链
function AntiSubState.OnEngageState(self, skipHateChain)
	self:resetVigilantDecay()

	self._currentState = self._engageState
	self._engageRage = true

	self:DispatchStateChange()

	if not skipHateChain then
		self:DispatchHateChain()
	end
end

--- 武器是否可用
--- @return boolean: 是否有可用武器
function AntiSubState.IsWeaponUseable(self)
	return #self._currentState:GetWeaponUseable() > 0
end

--- 获取警戒比例（0~1）
--- @return number: 警戒比例
function AntiSubState.GetVigilantRate(self)
	return self._vigilantValue * 0.01
end

--- 派发状态变化事件
function AntiSubState.DispatchStateChange(self)
	local event = ys.Event.New(ys.Battle.BattleUnitEvent.CHANGE_ANTI_SUB_VIGILANCE)

	self._client:DispatchEvent(event)
end

--- 派发声呐检查事件
function AntiSubState.DispatchSonarCheck(self)
	local event = ys.Event.New(ys.Battle.BattleUnitEvent.ANTI_SUB_VIGILANCE_SONAR_CHECK)

	self._client:DispatchEvent(event)
end

--- 派发仇恨链事件
function AntiSubState.DispatchHateChain(self)
	local event = ys.Event.New(ys.Battle.BattleUnitEvent.ANTI_SUB_VIGILANCE_HATE_CHAIN)

	self._client:DispatchEvent(event)
end

--- 获取警戒标记
--- @return any: 警戒标记
function AntiSubState.GetVigilantMark(self)
	return self._currentState:GetWarnMark()
end
