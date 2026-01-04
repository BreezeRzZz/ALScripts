ys = ys or {}

local ys = ys
local BossPhaseSwitchType = ys.Battle.BattleConst.BossPhaseSwitchType
local var_0_2 = ys.Battle.BattleConst

ys.Battle.BattleUnitPhaseSwitcher = class("BattleUnitPhaseSwitcher")
ys.Battle.BattleUnitPhaseSwitcher.__name = "BattleUnitPhaseSwitcher"

-- 在BattleDataProxy.SpawnMonster和BattleFleetVO.AddSubMarine中用到了这个类
local BattleUnitPhaseSwitcher = ys.Battle.BattleUnitPhaseSwitcher

--- @class BattleUnitPhaseSwitcher
--- @param client BattleUnit
--- @return nil
function BattleUnitPhaseSwitcher.Ctor(self, client)
	self._client = client

	self._client:AddPhaseSwitcher(self)

	self._randomWeaponList = {}
end

function BattleUnitPhaseSwitcher.Update(self)
	local satisfied = true
	local switchTo

	for _, phaseSwitchParams in ipairs(self._currentPhaseSwitchParam) do
		local switchType = phaseSwitchParams.type
		local switchParam = phaseSwitchParams.param
		-- DURATION = 1
		if switchType == BossPhaseSwitchType.DURATION then
			if switchParam < pg.TimeMgr.GetInstance():GetCombatTime() - self._phaseStartTime then
				switchTo = phaseSwitchParams.to
				phaseSwitchParams.andFlag = false
			end
		-- POSITION_X_GREATER = 3
		elseif switchType == BossPhaseSwitchType.POSITION_X_GREATER then
			if switchParam < self._client:GetPosition().x then
				switchTo = phaseSwitchParams.to
				phaseSwitchParams.andFlag = false
			end
		-- POSITION_X_LESS = 4
		elseif switchType == BossPhaseSwitchType.POSITION_X_LESS then
			if switchParam > self._client:GetPosition().x then
				switchTo = phaseSwitchParams.to
				phaseSwitchParams.andFlag = false
			end
		-- OXYGEN = 5
		elseif switchType == BossPhaseSwitchType.OXYGEN and switchParam >= self._client:GetCuurentOxygen() then
			switchTo = phaseSwitchParams.to
			phaseSwitchParams.andFlag = false
		end

		satisfied = satisfied and not phaseSwitchParams.andFlag
	end

	if switchTo and satisfied then
		self:switch(switchTo)
	end
end

function BattleUnitPhaseSwitcher.UpdateHP(self, currentHP)
	local satisfied = true
	local switchTo

	for _, phaseSwitchParams in ipairs(self._currentPhaseSwitchParam) do
		local switchType = phaseSwitchParams.type
		local switchParam = phaseSwitchParams.param
		local switchTo = phaseSwitchParams.to

		if switchType == BossPhaseSwitchType.HP and currentHP < switchParam then
			switchTo = switchTo
			phaseSwitchParams.andFlag = false
		end

		satisfied = satisfied and not phaseSwitchParams.andFlag
	end

	if switchTo and satisfied then
		self:switch(switchTo)
	end
end

-- 在BattleDataProxy.SpawnMonster中设置了模板数据
function BattleUnitPhaseSwitcher.SetTemplateData(self, phaseData)
	self._phaseList = {}

	for _, phase in ipairs(phaseData) do
		self._phaseList[phase.index] = phase
	end

	self:switch(0)
end

function BattleUnitPhaseSwitcher.ForceSwitch(self, index)
	self:switch(index)
end

function BattleUnitPhaseSwitcher.switch(self, index)
	if index == -1 or self._phaseList[index] == nil then
		return
	end

	local phase = self._phaseList[index]
	local removeWeaponList = {}

	if phase.removeWeapon then
		removeWeaponList = Clone(phase.removeWeapon)
	end

	if phase.removeRandomWeapon then
		for _, weapon in ipairs(self._randomWeaponList) do
			table.insert(removeWeaponList, weapon)
		end

		self._randomWeaponList = {}
	end

	local addWeaponList = {}

	if phase.addWeapon then
		addWeaponList = Clone(phase.addWeapon)
	end

	if phase.addRandomWeapon then
		local randomWeaponGroup = phase.addRandomWeapon[math.random(#phase.addRandomWeapon)]

		for _, weapon in ipairs(randomWeaponGroup) do
			table.insert(addWeaponList, weapon)
			table.insert(self._randomWeaponList, weapon)
		end
	end

	self._currentPhase = phase

	self:packagePhaseSwitchParam(phase)
	self._client:ShiftWeapon(removeWeaponList, addWeaponList)

	if phase.removeBuff then
		for _, buffID in ipairs(phase.removeBuff) do
			self._client:RemoveBuff(buffID)
		end
	end

	if phase.addBuff then
		for _, buffID in ipairs(phase.addBuff) do
			local buff = ys.Battle.BattleBuffUnit.New(buffID, 1, self._client)

			self._client:AddBuff(buff)
		end
	end

	if phase.dive then
		self._client:ChangeOxygenState(phase.dive)
	end

	if phase.setAI then
		self._client:SetAI(phase.setAI)
	end

	if phase.story then
		pg.NewStoryMgr.GetInstance():Play(phase.story)
	end

	if not phase.guide or phase.guide.type == 1 and pg.SeriesGuideMgr.GetInstance():isEnd() then
		-- block empty
	elseif phase.guide.event == nil then
		pg.NewGuideMgr.GetInstance():Play(phase.guide.step)
	else
		pg.NewGuideMgr.GetInstance():Play(phase.guide.step, {
			phase.guide.event
		})
	end

	self._phaseStartTime = pg.TimeMgr.GetInstance():GetCombatTime()

	if phase.retreat == true then
		self._client:Retreat()
	end
end

-- 通过该函数，将当前阶段切换参数打包到_currentPhaseSwitchParam中
function BattleUnitPhaseSwitcher.packagePhaseSwitchParam(self, phase)
	self._currentPhaseSwitchParam = {}

	local switchDataType = type(phase.switchType)

	if switchDataType == "table" then
		local switchType = phase.switchType
		local switchParam = phase.switchParam
		local switchTo = phase.switchTo
		local isSwitchToNumber = type(switchTo) == "number"
		local index = 1
		local length = #phase.switchType

		while index <= length do
			local phaseSwitchParams = {
				type = switchType[index],
				param = switchParam[index]
			}

			if isSwitchToNumber then
				phaseSwitchParams.to = switchTo
				phaseSwitchParams.andFlag = true
			else
				phaseSwitchParams.to = switchTo[index]
			end

			table.insert(self._currentPhaseSwitchParam, phaseSwitchParams)

			index = index + 1
		end
	elseif switchDataType == "number" then
		local phaseSwitchParams = {
			type = phase.switchType
		}

		if phase.switchParamFunc then
			phaseSwitchParams.param = phase.switchParamFunc()
		else
			phaseSwitchParams.param = phase.switchParam
		end

		phaseSwitchParams.to = phase.switchTo

		table.insert(self._currentPhaseSwitchParam, phaseSwitchParams)
	end
end
