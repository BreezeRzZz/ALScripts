ys = ys or {}

local ys = ys
local AIStepType = ys.Battle.BattleConst.AIStepType
local AutoPilot = class("AutoPilot")

ys.Battle.AutoPilot = AutoPilot
AutoPilot.__name = "AutoPilot"
AutoPilot.PILOT_VALVE = 0.5

function AutoPilot.Ctor(self, target, aiCfg)
	self._aiCfg = aiCfg
	self._target = target

	target._move:SetAutoMoveAI(self, target)
	self:generateList()

	self._currentStep = self._stepList[self._aiCfg.default]

	self._currentStep:Active(self._target)
end

function AutoPilot.GetDirection(self)
	local position = self._target:GetPosition()

	return (self._currentStep:GetDirection(position))
end

function AutoPilot.GetTarget(self)
	return self._target
end

function AutoPilot.InputWeaponStateChange(self)
	return
end

function AutoPilot.SetHiveUnit(self, hiveunit)
	self._hiveUnit = hiveunit
end

function AutoPilot.GetHiveUnit(self)
	return self._hiveUnit
end

function AutoPilot.OnHiveUnitDead(self)
	self._target:OnMotherDead()
end

function AutoPilot.NextStep(self)
	local toIndex = self._currentStep:GetToIndex()
	-- 没有就到Default Step
	if self._stepList[toIndex] == nil then
		toIndex = self._aiCfg.default
	end

	self._currentStep = self._stepList[toIndex]

	self._currentStep:Active(self._target)
end

-- note: AutoPilot主要逻辑部分，对auto_pilot_template的每个配置列表的step进行解析，生成对应的AutoPilotStep对象
function AutoPilot.generateList(self)
	self._stepList = {}

	for _, step in ipairs(self._aiCfg.list) do
		local aiStep
		local index = step.index
		local to = step.to
		local type = step.type
		local param = step.param

		if type == AIStepType.STAY then
			aiStep = ys.Battle.AutoPilotStay.New(index, self)
		elseif type == AIStepType.MOVE_TO then
			aiStep = ys.Battle.AutoPilotMoveTo.New(index, self)
		elseif type == AIStepType.MOVE then
			aiStep = ys.Battle.AutoPilotMove.New(index, self)
		elseif type == AIStepType.MOVE_RELATIVE then
			aiStep = ys.Battle.AutoPilotMoveRelative.New(index, self)
		elseif type == AIStepType.BROWNIAN then
			aiStep = ys.Battle.AutoPilotBrownian.New(index, self)
		elseif type == AIStepType.CIRCLE then
			aiStep = ys.Battle.AutoPilotCircle.New(index, self)
		elseif type == AIStepType.RELATIVE_BROWNIAN then
			aiStep = ys.Battle.AutoPilotRelativeBrownian.New(index, self)
		elseif type == AIStepType.RELATIVE_FLEET_MOVE_TO then
			aiStep = ys.Battle.AutoPilotRelativeFleetMoveTo.New(index, self)
		elseif type == AIStepType.HIVE_STAY then
			aiStep = ys.Battle.AutoPilotHiveRelativeStay.New(index, self)
		elseif type == AIStepType.HIVE_CIRCLE then
			aiStep = ys.Battle.AutoPilotHiveRelativeCircle.New(index, self)
		elseif type == AIStepType.MINION_STAY then
			aiStep = ys.Battle.AutoPilotMinionRelativeStay.New(index, self)
		elseif type == AIStepType.MINION_CIRCLE then
			aiStep = ys.Battle.AutoPilotMinionRelativeCircle.New(index, self)
		end

		aiStep:SetParameter(param, to)

		self._stepList[aiStep:GetIndex()] = aiStep
	end
end
