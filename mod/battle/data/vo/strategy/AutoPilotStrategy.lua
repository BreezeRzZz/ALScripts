ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.AutoPilotStrategy = class("AutoPilotStrategy", ys.Battle.BattleJoyStickBotBaseStrategy)

local AutoPilotStrategy = ys.Battle.AutoPilotStrategy

AutoPilotStrategy.__name = "AutoPilotStrategy"
AutoPilotStrategy.FIX_FRONT = 0.5

function AutoPilotStrategy.Ctor(self, fleetVO)
	AutoPilotStrategy.super.Ctor(self, fleetVO)

	local referenceUnit = fleetVO:GetMotionReferenceUnit()
	local aiID = fleetVO:GetAutoBotAIID()
	local aiTmpData = ys.Battle.BattleDataFunction.GetAITmpDataFromID(aiID)

	self._autoPilot = ys.Battle.AutoPilot.New(referenceUnit, aiTmpData)
end

function AutoPilotStrategy.GetStrategyType(self)
	return ys.Battle.BattleJoyStickAutoBot.AUTO_PILOT
end

function AutoPilotStrategy.analysis(self)
	local direction = self._autoPilot:GetDirection()

	self._hrz = direction.x
	self._vtc = direction.z
end
