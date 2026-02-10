ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleIndieSonar = class("BattleIndieSonar")

ys.Battle.BattleIndieSonar = BattleIndieSonar
BattleIndieSonar.__name = "BattleIndieSonar"

function BattleIndieSonar.Ctor(self, fleetVO, range, duration)
	self._fleetVO = fleetVO
	-- range实际是被固定死了，参数传了也没用
	self._range = 180
	self._duration = duration
end

function BattleIndieSonar.SwitchHost(self, host)
	self._host = host
end

function BattleIndieSonar.Detect(self)
	self._snoarStartTime = pg.TimeMgr.GetInstance():GetCombatTime()

	local targetList = self:FilterTarget()
	-- 暴露范围内的潜艇，持续duration秒
	for _, target in ipairs(targetList) do
		target:Detected(self._duration)
	end

	self._detectedList = targetList

	self._fleetVO:DispatchSonarScan(true)
end

function BattleIndieSonar.Update(self, timeStamp)
	if timeStamp > self._snoarStartTime + self._duration then
		self._detectedList = nil

		self._fleetVO:RemoveIndieSonar(self)
	end
end

function BattleIndieSonar.FilterTarget(self)
	local candidateList = BattleTargetChoise.LegalTarget(self._host)

	return (BattleTargetChoise.TargetDiveState(self._host, {
		diveState = BattleConst.OXY_STATE.DIVE
	}, candidateList))
end
