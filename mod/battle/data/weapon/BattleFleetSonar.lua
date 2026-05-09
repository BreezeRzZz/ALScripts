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
local BattleFleetSonar = class("BattleFleetSonar")

ys.Battle.BattleFleetSonar = BattleFleetSonar
BattleFleetSonar.__name = "BattleFleetSonar"
BattleFleetSonar.STATE_DISABLE = "DISABLE"
BattleFleetSonar.STATE_OVER_HEAT = "OVER_HEAT"
BattleFleetSonar.STATE_READY = "READY"
BattleFleetSonar.STATE_DETECTING = "DETECTING"

--- 构造函数：初始化并关联舰队VO
--- @param fleetVO BattleFleetVO: 所属舰队
function BattleFleetSonar.Ctor(self, fleetVO)
	self:init()

	self._fleetVO = fleetVO
end

--- 清理
function BattleFleetSonar.Dispose(self)
	self._detectedList = nil
	self._crewUnitList = nil
	self._host = nil
end

--- 初始化内部数据
function BattleFleetSonar.init(self)
	self._crewUnitList = {}
	self._detectedList = {}
end

--- 添加声呐操作员单位
--- @param crewUnit BattleUnit: 操作员单位
function BattleFleetSonar.AppendCrewUnit(self, crewUnit)
	self._crewUnitList[crewUnit:GetUniqueID()] = crewUnit

	self:flush()

	self._currentState = BattleFleetSonar.STATE_READY
end

--- 移除声呐操作员单位
--- @param crewUnit BattleUnit: 操作员单位
function BattleFleetSonar.RemoveCrewUnit(self, crewUnit)
	local unitID = crewUnit:GetUniqueID()

	if self._crewUnitList[unitID] then
		self._crewUnitList[unitID] = nil

		self:flush()
	end
end

--- 切换声呐宿主
--- @param host BattleUnit: 新宿主
function BattleFleetSonar.SwitchHost(self, host)
	self._host = host
end

--- 获取声呐范围
--- @return number: 声呐范围
function BattleFleetSonar.GetRange(self)
	return self._range
end

--- 刷新声呐参数：根据操作员属性计算范围、间隔、持续时间
function BattleFleetSonar.flush(self)
	self._range, self._interval, self._duration = 0, 0, 0

	local operatorCount = 0
	local maxRange = 0
	local totalInterval = 0
	local maxDuration = 0

	for _, operatorUnit in pairs(self._crewUnitList) do
		local sonarRange = operatorUnit:GetAttrByName("sonarRange")

		if sonarRange > 0 then
			operatorCount = operatorCount + 1

			local sonarInterval = operatorUnit:GetAttrByName("sonarInterval")
			local sonarDuration = operatorUnit:GetAttrByName("sonarDuration")

			maxRange = math.max(maxRange, sonarRange)
			totalInterval = sonarInterval + totalInterval
			maxDuration = math.max(maxDuration, sonarDuration)
		end
	end

	if operatorCount > 0 then
		self._range = maxRange
		self._interval = totalInterval / operatorCount * (1 - (operatorCount - 1) * BattleConfig.SONAR_INTERVAL_K)
		self._duration = maxDuration * (1 + (operatorCount - 1) * BattleConfig.SONAR_DURATION_K)
	else
		self:Undetect()

		self._currentState = BattleFleetSonar.STATE_DISABLE
	end
end

--- 每帧更新：根据状态驱动声呐扫描周期
--- @param timeStamp number: 当前时间戳
function BattleFleetSonar.Update(self, timeStamp)
	if self._currentState == BattleFleetSonar.STATE_DISABLE then
		-- block empty
	elseif self._currentState == BattleFleetSonar.STATE_READY then
		self:Detect()
	elseif self._currentState == BattleFleetSonar.STATE_OVER_HEAT then
		if timeStamp > self._interval + self._overheatStartTime then
			self:Ready()
		end
	elseif self._currentState == BattleFleetSonar.STATE_DETECTING then
		if timeStamp > self._snoarStartTime + self._duration then
			self:Overheat()
		else
			self:updateDetectedList()
		end
	end
end

--- 开始声呐探测：筛选目标并标记为已探测
function BattleFleetSonar.Detect(self)
	self._snoarStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._currentState = BattleFleetSonar.STATE_DETECTING

	local detectedTargets = self:FilterTarget()

	for _, target in ipairs(detectedTargets) do
		target:Detected(10)
	end

	self._detectedList = detectedTargets

	self._fleetVO:DispatchSonarScan()
end

--- 取消探测：进入过热状态并取消所有已探测标记
function BattleFleetSonar.Undetect(self)
	self._snoarStartTime = nil
	self._currentState = BattleFleetSonar.STATE_OVER_HEAT

	local detectedList = self._detectedList

	for _, target in ipairs(detectedList) do
		if target:IsAlive() then
			target:Undetected()
		end
	end

	self._detectedList = {}
end

--- 更新已探测列表：移除死亡或离开范围的单位
function BattleFleetSonar.updateDetectedList(self)
	local currentTargets = self:FilterTarget()
	local idx = #self._detectedList

	while idx > 0 do
		local detectedUnit = self._detectedList[idx]

		if not detectedUnit:IsAlive() then
			table.remove(self._detectedList, idx)
		elseif not table.contains(currentTargets, detectedUnit) then
			detectedUnit:Undetected()
			table.remove(self._detectedList, idx)
		end

		idx = idx - 1
	end
end

--- 进入过热状态
function BattleFleetSonar.Overheat(self)
	self:Undetect()

	self._overheatStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
end

--- 恢复到就绪状态
function BattleFleetSonar.Ready(self)
	self._overheatStartTime = nil
	self._currentState = BattleFleetSonar.STATE_READY
end

--- 筛选目标：合法目标 + 潜水状态 + 范围过滤
--- @return table: 符合条件的目标列表
function BattleFleetSonar.FilterTarget(self)
	local legalTargets = BattleTargetChoise.LegalTarget(self._host)
	local diveTargets = BattleTargetChoise.TargetDiveState(self._host, {
		diveState = BattleConst.OXY_STATE.DIVE
	}, legalTargets)

	return (self:FilterRange(diveTargets))
end

--- 按范围过滤目标
--- @param targetList table: 候选目标列表
--- @return table: 在范围内的目标列表
function BattleFleetSonar.FilterRange(self, targetList)
	for i = #targetList, 1, -1 do
		if self:isOutOfRange(targetList[i]) then
			table.remove(targetList, i)
		end
	end

	return targetList
end

--- 判断目标是否超出范围
--- @param target BattleUnit: 目标
--- @return boolean: 是否超出范围
function BattleFleetSonar.isOutOfRange(self, target)
	return self._host:GetDistance(target) > self._range
end
