ys = ys or {}
-- TODO
local ys = ys
local ActionName = ys.Battle.BattleConst.ActionName

ys.Battle.AntiSubState = class("AntiSubState")
ys.Battle.AntiSubState.__name = "AntiSubState"

local AntiSubState = ys.Battle.AntiSubState

--- @param client BattleUnit
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

function AntiSubState.Update(self, arg_2_1, arg_2_2)
	if arg_2_2 > 0 and self:checkDecayRage() then
		self:OnEngageState()
	end

	if arg_2_1 + arg_2_2 > 0 then
		self:resetVigilantDecay()
	end

	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	if self._vigilantDecayTimeStamp then
		self:updateVigilantDecay(currentTime)
	elseif self._currentState:CanDecay() and arg_2_1 + arg_2_2 == 0 then
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

function AntiSubState.updateVigilantDecay(self, arg_3_1)
	if arg_3_1 - self._vigilantDecayTimeStamp >= self._currentState:DecayDuration() then
		self._vigilantValue = self._vigilantValue - 0.01

		self._currentState:ToPreLevel(self)

		self._decayFlag = true
	end
end

function AntiSubState.resetVigilantDecay(self)
	self._vigilantDecayTimeStamp = nil
	self._decayFlag = false
end

function AntiSubState.checkDecayRage(self)
	return self._vigilantDecayTimeStamp and self._engageRage
end

function AntiSubState.HateChain(self)
	self:resetVigilantDecay()
	self._currentState:OnHateChain(self)
end

function AntiSubState.InitCheck(self, arg_7_1)
	if arg_7_1 > 0 then
		self:SubmarineFloat()
	end
end

function AntiSubState.MineExplode(self)
	if self:checkDecayRage() then
		self:OnEngageState()

		return
	end

	self:resetVigilantDecay()
	self._currentState:OnMineExplode(self)
end

function AntiSubState.SubmarineFloat(self)
	if self:checkDecayRage() then
		self:OnEngageState()

		return
	end

	self:resetVigilantDecay()
	self._currentState:OnSubmarinFloat(self)
end

function AntiSubState.VigilantAreaEngage(self)
	self:resetVigilantDecay()
	self._currentState:OnVigilantEngage(self)
end

function AntiSubState.SonarDetect(self, arg_11_1)
	self:DispatchSonarCheck()

	local var_11_0 = arg_11_1 > 0

	if self._lastSonarDected and var_11_0 then
		self:OnEngageState()
	elseif var_11_0 then
		self:OnVigilantState()
	end

	self._lastSonarDected = var_11_0
end

function AntiSubState.OnCalmState(self)
	self:resetVigilantDecay()

	self._currentState = self._calmState
	self._engageRage = false

	self:DispatchStateChange()
end

function AntiSubState.OnSuspiciousState(self)
	self:resetVigilantDecay()

	self._currentState = self._suspiciousState

	self:DispatchStateChange()
end

function AntiSubState.OnVigilantState(self)
	self:resetVigilantDecay()

	self._currentState = self._vigilantState

	self:DispatchStateChange()
end

function AntiSubState.OnEngageState(self, arg_15_1)
	self:resetVigilantDecay()

	self._currentState = self._engageState
	self._engageRage = true

	self:DispatchStateChange()

	if not arg_15_1 then
		self:DispatchHateChain()
	end
end

function AntiSubState.IsWeaponUseable(self)
	return #self._currentState:GetWeaponUseable() > 0
end

function AntiSubState.GetVigilantRate(self)
	return self._vigilantValue * 0.01
end

function AntiSubState.DispatchStateChange(self)
	local var_18_0 = ys.Event.New(ys.Battle.BattleUnitEvent.CHANGE_ANTI_SUB_VIGILANCE)

	self._client:DispatchEvent(var_18_0)
end

function AntiSubState.DispatchSonarCheck(self)
	local var_19_0 = ys.Event.New(ys.Battle.BattleUnitEvent.ANTI_SUB_VIGILANCE_SONAR_CHECK)

	self._client:DispatchEvent(var_19_0)
end

function AntiSubState.DispatchHateChain(self)
	local var_20_0 = ys.Event.New(ys.Battle.BattleUnitEvent.ANTI_SUB_VIGILANCE_HATE_CHAIN)

	self._client:DispatchEvent(var_20_0)
end

function AntiSubState.GetVigilantMark(self)
	return self._currentState:GetWarnMark()
end
