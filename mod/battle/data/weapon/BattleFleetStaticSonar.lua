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
local VAN_SONAR_PROPERTY = BattleConfig.VAN_SONAR_PROPERTY
local BattleFleetStaticSonar = class("BattleFleetStaticSonar")

ys.Battle.BattleFleetStaticSonar = BattleFleetStaticSonar
BattleFleetStaticSonar.__name = "BattleFleetStaticSonar"
BattleFleetStaticSonar.STATE_DISABLE = "DISABLE"
BattleFleetStaticSonar.STATE_READY = "READY"

--- @class BattleFleetStaticSonar
--- @param fleetVO table 舰队VO对象
--- 舰队静态声呐：管理多个船员单元的反潜探测，计算综合声呐范围，检测潜航状态的敌方单位
function BattleFleetStaticSonar.Ctor(self, fleetVO)
	self:init()

	self._fleetVO = fleetVO
	self._currentState = BattleFleetStaticSonar.STATE_DISABLE
end

--- @return string 当前状态
function BattleFleetStaticSonar.GetCurrentState(self)
	return self._currentState
end

function BattleFleetStaticSonar.Dispose(self)
	self._detectedList = nil
	self._crewUnitList = nil
	self._host = nil
end

function BattleFleetStaticSonar.init(self)
	self._crewUnitList = {}
	self._detectedList = {}
	self._skillDiameter = 0
	self._radius = 0
	self._diameter = 0
end

--- @param extraRange number 技能额外声呐范围
function BattleFleetStaticSonar.AppendExtraSkillRange(self, extraRange)
	self._skillDiameter = self._skillDiameter + extraRange

	if self._radius ~= 0 then
		self._radius = self._radius + extraRange * 0.5
	end
end

--- @param crewUnit CrewUnit 加入的船员单元
function BattleFleetStaticSonar.AppendCrewUnit(self, crewUnit)
	self._crewUnitList[crewUnit:GetUniqueID()] = crewUnit

	self:flush()
end

--- @param crewUnit CrewUnit 移除的船员单元
function BattleFleetStaticSonar.RemoveCrewUnit(self, crewUnit)
	local uid = crewUnit:GetUniqueID()

	if self._crewUnitList[uid] then
		self._crewUnitList[uid] = nil

		self:updateSonarState()

		if self._currentState == BattleFleetStaticSonar.STATE_DISABLE then
			self:Undetect()
		end
	end
end

--- @param host BattleUnit 切换宿主
function BattleFleetStaticSonar.SwitchHost(self, host)
	self._host = host
end

--- @return number 声呐覆盖直径
function BattleFleetStaticSonar.GetRange(self)
	return self._diameter
end

--- 刷新声呐属性
function BattleFleetStaticSonar.flush(self)
	self._diameter = 0

	local baseRange, extraRange, mainRange = self:calcSonarRange()

	if baseRange ~= 0 then
		self._diameter = baseRange + mainRange + extraRange
		self._radius = self._diameter * 0.5
	end

	self:updateSonarState()
end

--- @return number baseRange 基础声呐范围（取各船员最大值）
--- @return number mainRange 主力舰反潜范围
--- @return number extraRange 额外声呐范围
function BattleFleetStaticSonar.calcSonarRange(self)
	local baseRange = 0
	local extraRange = 0
	local mainRange = 0

	for _, crewUnit in pairs(self._crewUnitList) do
		local baseR, extraR, mainR = self.getSonarProperty(crewUnit)

		if baseR > 0 then
			baseRange = math.max(baseR, baseRange)
		end

		extraRange = extraRange + extraR
		mainRange = mainRange + mainR
	end

	local mainProperty = BattleConfig.MAIN_SONAR_PROPERTY
	local mainRatio = mainRange / mainProperty.a
	local mainClamped = Mathf.Clamp(mainRatio, mainProperty.minRange, mainProperty.maxRange)

	return baseRange, mainClamped, extraRange
end

--- 更新声呐状态：有任意船员具有声呐属性则为READY
function BattleFleetStaticSonar.updateSonarState(self)
	local activeCount = 0

	for _, crewUnit in pairs(self._crewUnitList) do
		if self.getSonarProperty(crewUnit) > 0 then
			activeCount = activeCount + 1
		end
	end

	if activeCount > 0 then
		self._currentState = BattleFleetStaticSonar.STATE_READY
	else
		self._currentState = BattleFleetStaticSonar.STATE_DISABLE
	end

	local sonarEvent = ys.Event.New(ys.Battle.BattleEvent.SONAR_UPDATE)

	self._fleetVO:DispatchEvent(sonarEvent)
end

--- @param crewUnit CrewUnit
--- @return number baseRange 基础声呐范围
--- @return number sonarRange 声呐范围属性
--- @return number mainRange 主力舰反潜值
function BattleFleetStaticSonar.getSonarProperty(self, crewUnit)
	local shipType = crewUnit:GetTemplate().type
	local shipProperty = VAN_SONAR_PROPERTY[shipType]
	local baseRange = 0

	if shipProperty then
		local rawValue = crewUnit:GetAttrByName("baseAntiSubPower") / shipProperty.a - shipProperty.b

		baseRange = Mathf.Clamp(rawValue, shipProperty.minRange, shipProperty.maxRange)
	end

	local sonarRange = crewUnit:GetAttrByName("sonarRange")
	local mainRange = 0

	if table.contains(ShipType.MainShipType, shipType) then
		mainRange = crewUnit:GetAttrByName("baseAntiSubPower")
	end

	return baseRange, sonarRange, mainRange
end

--- @param timeStamp number 时间戳
function BattleFleetStaticSonar.Update(self, timeStamp)
	if self._currentState ~= BattleFleetStaticSonar.STATE_DISABLE then
		self._fleetVO:DispatchSonarScan()
		self:updateDetectedList()
	end
end

--- 取消所有探测
function BattleFleetStaticSonar.Undetect(self)
	local detectedList = self._detectedList

	for _, enemy in ipairs(detectedList) do
		if enemy:IsAlive() then
			enemy:Undetected()
		end
	end

	self._detectedList = {}
end

--- 更新探测列表：对比新筛选结果与当前列表，处理进出探测范围的单位
function BattleFleetStaticSonar.updateDetectedList(self)
	local legalTargets = BattleTargetChoise.LegalTarget(self._host)
	local diveTargets = BattleTargetChoise.TargetDiveState(self._host, {
		diveState = BattleConst.OXY_STATE.DIVE
	}, legalTargets)
	local inRange = self:FilterRange(diveTargets)

	for _, target in ipairs(diveTargets) do
		local isInRange = table.contains(inRange, target)
		local wasDetected = table.contains(self._detectedList, target)

		if wasDetected then
			if not isInRange then
				target:Undetected()
			end
		elseif not wasDetected and isInRange then
			target:Detected()
		end
	end

	self._detectedList = inRange
end

--- @return table<number, BattleUnit> 在声呐范围内的潜航敌方单位
function BattleFleetStaticSonar.FilterTarget(self)
	local legalTargets = BattleTargetChoise.LegalTarget(self._host)
	local diveTargets = BattleTargetChoise.TargetDiveState(self._host, {
		diveState = BattleConst.OXY_STATE.DIVE
	}, legalTargets)

	return (self:FilterRange(diveTargets))
end

--- @param targets table<number, BattleUnit>
--- @return table<number, BattleUnit> 在声呐半径内的目标
function BattleFleetStaticSonar.FilterRange(self, targets)
	local inRange = {}

	for _, target in ipairs(targets) do
		if not self:isOutOfRange(target) then
			table.insert(inRange, target)
		end
	end

	return inRange
end

--- @param target BattleUnit
--- @return boolean 是否超出探测半径
function BattleFleetStaticSonar.isOutOfRange(self, target)
	return self._host:GetDistance(target) > self._radius
end

--- @return number baseRange
--- @return number mainRange
--- @return number extraRange
--- @return number skillDiameter
function BattleFleetStaticSonar.GetTotalRangeDetail(self)
	local baseRange, mainRange, extraRange = self:calcSonarRange()

	return baseRange, mainRange, extraRange, self._skillDiameter
end
