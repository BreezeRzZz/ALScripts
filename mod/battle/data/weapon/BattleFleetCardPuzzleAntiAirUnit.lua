ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable
local BattleFleetCardPuzzleAntiAirUnit = class("BattleFleetCardPuzzleAntiAirUnit")

ys.Battle.BattleFleetCardPuzzleAntiAirUnit = BattleFleetCardPuzzleAntiAirUnit
BattleFleetCardPuzzleAntiAirUnit.__name = "BattleFleetCardPuzzleAntiAirUnit"
BattleFleetCardPuzzleAntiAirUnit.STATE_DISABLE = "DISABLE"
BattleFleetCardPuzzleAntiAirUnit.STATE_READY = "READY"
BattleFleetCardPuzzleAntiAirUnit.STATE_PRECAST = "PRECAST"
BattleFleetCardPuzzleAntiAirUnit.STATE_PRECAST_FINISH = "STATE_PRECAST_FINISH"
BattleFleetCardPuzzleAntiAirUnit.STATE_ATTACK = "ATTACK"
BattleFleetCardPuzzleAntiAirUnit.STATE_OVER_HEAT = "OVER_HEAT"

--- @class BattleFleetCardPuzzleAntiAirUnit
--- @param client table 舰队客户端对象
--- 卡牌谜题防空单元：由多个船员单元(CrewUnit)组成，累计计算防空射程和间隔，选择最近目标进行防空射击
function BattleFleetCardPuzzleAntiAirUnit.Ctor(self, client)
	self._client = client

	self:init()
end

function BattleFleetCardPuzzleAntiAirUnit.init(self)
	self._crewUnitList = {}
	self._hitFXResIDList = {}
	self._currentState = BattleFleetCardPuzzleAntiAirUnit.STATE_DISABLE
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._range = 0
end

--- @param crewUnit CrewUnit 加入的船员单元
--- 添加船员单元并刷新防空属性
function BattleFleetCardPuzzleAntiAirUnit.AppendCrewUnit(self, crewUnit)
	self._crewUnitList[crewUnit] = true
	self._currentState = BattleFleetCardPuzzleAntiAirUnit.STATE_READY

	self:flush()
end

--- @param crewUnit CrewUnit 移除的船员单元
--- 移除船员单元并刷新防空属性
function BattleFleetCardPuzzleAntiAirUnit.RemoveCrewUnit(self, crewUnit)
	self._crewUnitList[crewUnit] = nil

	self:flush()
end

--- @param host BattleUnit 切换宿主
function BattleFleetCardPuzzleAntiAirUnit.SwitchHost(self, host)
	self._host = host
end

--- @return table<CrewUnit, boolean>
function BattleFleetCardPuzzleAntiAirUnit.GetCrewUnitList(self)
	return self._crewUnitList
end

--- @return number 防空射程
function BattleFleetCardPuzzleAntiAirUnit.GetRange(self)
	return self._range
end

--- 刷新防空属性：根据所有船员单元的平均值重新计算射程和间隔
function BattleFleetCardPuzzleAntiAirUnit.flush(self)
	self._range = 0
	self._interval = 0

	local count = 0

	for crewUnit, _ in pairs(self._crewUnitList) do
		self._range = self._range + crewUnit:GetTemplate().AA_range
		self._interval = self._interval + crewUnit:GetTemplate().AA_CD
		count = count + 1
	end

	self._range = self._range / count
	self._interval = self._interval / count
end

--- 每帧更新：检查防空是否激活，筛选目标并开火
function BattleFleetCardPuzzleAntiAirUnit.Update(self)
	if self._client:IsAAActive() and self._currentState == BattleFleetCardPuzzleAntiAirUnit.STATE_READY then
		local filteredTargets = self:FilterTarget()
		local filteredByRange = self:FilterRange(filteredTargets)
		local target = self:CompareDistance(filteredByRange)

		if target then
			self:Fire(target)
		end
	end
end

--- @return table<number, BattleUnit> 筛选后的敌对飞机列表
--- 筛选出敌方可见飞机
function BattleFleetCardPuzzleAntiAirUnit.FilterTarget(self)
	local aircraftList = self._dataProxy:GetAircraftList()
	local result = {}
	local hostIFF = self._host:GetIFF()
	local index = 1

	for _, aircraft in pairs(aircraftList) do
		if aircraft:GetIFF() ~= hostIFF and aircraft:IsVisitable() then
			result[index] = aircraft
			index = index + 1
		end
	end

	return result
end

--- @param targets table<number, BattleUnit> 候选目标列表
--- @return table<number, BattleUnit> 在射程内的目标列表
--- 反向遍历在射程外移除目标
function BattleFleetCardPuzzleAntiAirUnit.FilterRange(self, targets)
	for iter_11_0 = #targets, 1, -1 do
		if self:IsOutOfRange(targets[iter_11_0]) then
			table.remove(targets, iter_11_0)
		end
	end

	return targets
end

--- @param target BattleUnit
--- @return boolean 是否超出防空射程
function BattleFleetCardPuzzleAntiAirUnit.IsOutOfRange(self, target)
	return self:getTrackingHost():GetDistance(target) > self._range
end

--- @param targets table<number, BattleUnit>
--- @return BattleUnit|nil 最近的目标（按X坐标最小）
--- 选择X坐标最小的敌机作为最近目标
function BattleFleetCardPuzzleAntiAirUnit.CompareDistance(self, targets)
	local minX = 999999
	local nearestTarget

	for _, target in ipairs(targets) do
		if minX > target:GetPosition().x then
			nearestTarget = target
			minX = target:GetPosition().x
		end
	end

	return nearestTarget
end

--- @return BattleUnit 追踪宿主
function BattleFleetCardPuzzleAntiAirUnit.getTrackingHost(self)
	return self._host
end

--- @param target BattleUnit 被击中的目标飞机
--- 开火击落飞机，进入冷却并消耗AA计数
function BattleFleetCardPuzzleAntiAirUnit.Fire(self, target)
	if self._currentState == self.DISABLE then
		return
	end

	local targetUID = target:GetUniqueID()

	self._dataProxy:KillAircraft(targetUID)
	self:EnterCoolDown()
	self._client:ConsumeAACounter()
end

--- 进入冷却状态，添加CD定时器
function BattleFleetCardPuzzleAntiAirUnit.EnterCoolDown(self)
	self._currentState = self.STATE_OVER_HEAT

	self:AddCDTimer(self._interval)
end

--- @return string 当前状态
function BattleFleetCardPuzzleAntiAirUnit.GetCurrentState(self)
	return self._currentState
end

--- @param interval number CD间隔时间
--- 添加CD定时器，到期后恢复到READY状态
function BattleFleetCardPuzzleAntiAirUnit.AddCDTimer(self, interval)
	local function cdCallback()
		self._currentState = self.STATE_READY

		self:RemoveCDTimer()
	end

	self:RemoveCDTimer()

	self._cdTimer = pg.TimeMgr.GetInstance():AddBattleTimer("weaponTimer", -1, interval, cdCallback, true)
end

function BattleFleetCardPuzzleAntiAirUnit.RemoveCDTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._cdTimer)

	self._cdTimer = nil
end

--- 清理所有引用
function BattleFleetCardPuzzleAntiAirUnit.Dispose(self)
	self:RemoveCDTimer()

	self._crewUnitList = nil
	self._hitFXResIDList = nil
	self._dataProxy = nil
	self._SFXID = nil
end
