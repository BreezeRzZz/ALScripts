ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable
local BattleFleetAntiAirUnit = class("BattleFleetAntiAirUnit")

ys.Battle.BattleFleetAntiAirUnit = BattleFleetAntiAirUnit
BattleFleetAntiAirUnit.__name = "BattleFleetAntiAirUnit"
BattleFleetAntiAirUnit.STATE_DISABLE = "DISABLE"
BattleFleetAntiAirUnit.STATE_READY = "READY"
BattleFleetAntiAirUnit.STATE_PRECAST = "PRECAST"
BattleFleetAntiAirUnit.STATE_PRECAST_FINISH = "STATE_PRECAST_FINISH"
BattleFleetAntiAirUnit.STATE_ATTACK = "ATTACK"
BattleFleetAntiAirUnit.STATE_OVER_HEAT = "OVER_HEAT"

-- 代表武器：舰船装备的近程防空炮
function BattleFleetAntiAirUnit.Ctor(self)
	self:init()
end

function BattleFleetAntiAirUnit.init(self)
	self._crewUnitList = {}
	self._hitFXResIDList = {}
	-- 初始是不可用状态
	self._currentState = BattleFleetAntiAirUnit.STATE_DISABLE
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._range = 0
end

-- 贝BattleFleetVO.appendScoutUnit和appendMainUnit调用
function BattleFleetAntiAirUnit.AppendCrewUnit(self, unit)
	local fleetAAList = unit:GetFleetAntiAirList()

	if #fleetAAList > 0 then
		self._currentState = BattleFleetAntiAirUnit.STATE_READY
		self._crewUnitList[unit] = fleetAAList

		self:flush()
	end
end

function BattleFleetAntiAirUnit.RemoveCrewUnit(self, unit)
	if self._crewUnitList[unit] then
		self._crewUnitList[unit] = nil

		self:flush()
	end
end

function BattleFleetAntiAirUnit.FlushCrewUnit(self, unit)
	local fleetAAList = unit:GetFleetAntiAirList()

	if #fleetAAList <= 0 then
		self:RemoveCrewUnit(unit)
	elseif self._crewUnitList[unit] == nil then
		self:AppendCrewUnit(unit)
	else
		self._crewUnitList[unit] = fleetAAList

		self:flush()
	end
end

function BattleFleetAntiAirUnit.SwitchHost(self, host)
	self._host = host
end

function BattleFleetAntiAirUnit.GetCrewUnitList(self)
	return self._crewUnitList
end

function BattleFleetAntiAirUnit.GetRange(self)
	return self._range
end

-- 每次更改编队成员后调用，重新计算防空炮属性
function BattleFleetAntiAirUnit.flush(self)
	self._range = 0
	self._interval = 0
	self._hitFXResIDList = {}
	self._SFXID = nil

	local weightRstList = {}
	local fleetAANum = 0
	-- 对每个舰船的每个防空炮进行遍历，计算整体属性
	for crewUnit, fleetAAList in pairs(self._crewUnitList) do
		for _, fleetAA in ipairs(fleetAAList) do
			fleetAANum = fleetAANum + 1
			self._interval = self._interval + fleetAA:GetReloadTime()

			local weaponTmpData = fleetAA:GetTemplateData()

			self._range = self._range + weaponTmpData.range
			self._hitFXResIDList[fleetAA] = ys.Battle.BattleDataFunction.GetBulletTmpDataFromID(weaponTmpData.bullet_ID[1]).hit_fx
			self._SFXID = weaponTmpData.fire_sfx
		end

		local crewAAPower = crewUnit:GetAttrByName("antiAirPower")
		local crewAAWeight = BattleFormulas.AntiAirPowerWeight(crewAAPower)
		local weightRstPair = {
			weight = crewAAWeight,
			rst = crewUnit
		}

		weightRstList[#weightRstList + 1] = weightRstPair
	end

	if fleetAANum == 0 then
		self._currentState = BattleFleetAntiAirUnit.STATE_DISABLE

		if self._precastTimer then
			self:RemovePrecastTimer()
		end
	else
		-- 防空炮的索敌范围为平均范围
		self._range = self._range / fleetAANum
		-- 防空炮的开火间隔为平均间隔+0.5秒
		self._interval = self._interval / fleetAANum + 0.5
		self._weightList, self._totalWeight = BattleFormulas.GenerateWeightList(weightRstList)
	end
end

function BattleFleetAntiAirUnit.Update(self)
	-- 只有在READY状态下才进行索敌
	if self._currentState == BattleFleetAntiAirUnit.STATE_READY then
		-- 第一次过滤
		local targetList = self:FilterTarget()
		-- 确定在索敌范围内有(过滤后的)敌机时，开始前摇
		if #self:FilterRange(targetList) > 0 then
			self:AddPreCastTimer()
		end
	end
end

function BattleFleetAntiAirUnit.AddPreCastTimer(self)
	local function afterPrecast()
		self:RemovePrecastTimer()
		self:Fire()
	end
	-- 首先进入前摇状态
	self._currentState = BattleFleetAntiAirUnit.STATE_PRECAST
	-- 防空炮的开火前摇：计时器0.25s
	self._precastTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 0, BattleConfig.AntiAirConfig.Precast_duration, afterPrecast, true)
end

function BattleFleetAntiAirUnit.RemovePrecastTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._precastTimer)

	self._precastTimer = nil
end

-- 被BattleFleetAntiAirUnit.Update调用
function BattleFleetAntiAirUnit.FilterTarget(self)
	local aircraftList = self._dataProxy:GetAircraftList()
	local filteredList = {}
	local hostIFF = self._host:GetIFF()
	local index = 1

	for _, aircraft in pairs(aircraftList) do
		if aircraft:GetIFF() ~= hostIFF and aircraft:IsVisitable() then
			filteredList[index] = aircraft
			index = index + 1
		end
	end

	return filteredList
end

function BattleFleetAntiAirUnit.FilterRange(self, filteredList)
	for index = #filteredList, 1, -1 do
		if self:IsOutOfRange(filteredList[index]) then
			table.remove(filteredList, index)
		end
	end

	return filteredList
end

function BattleFleetAntiAirUnit.IsOutOfRange(self, target)
	return self:getTrackingHost():GetDistance(target) > self._range
end

function BattleFleetAntiAirUnit.getTrackingHost(self)
	return self._host
end

-- 防空炮实际开火(在Precast完成后调用)
function BattleFleetAntiAirUnit.Fire(self)
	if self._currentState == self.DISABLE then
		return
	end

	local function areaCldFunc(cldObjList)
		local cldAircraftList = {}
		local aircraftList = self._dataProxy:GetAircraftList()

		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local aircraft = aircraftList[cldObj.UID]

				if aircraft and aircraft:IsVisitable() then
					cldAircraftList[#cldAircraftList + 1] = aircraft
				end
			end
		end

		local fleetAATotalDamage = BattleFormulas.CalculateFleetAntiAirTotalDamage(self)
		local meteoDamageRatio = BattleFormulas.GetMeteoDamageRatio(#cldAircraftList)

		for index, aircraft in ipairs(cldAircraftList) do
			local aircraftHPLost = math.max(1, math.floor(fleetAATotalDamage * meteoDamageRatio[index]))
			local caster = BattleFormulas.WeightListRandom(self._weightList, self._totalWeight)
			-- 防空伤害结算是DirectDamage的方式
			-- caster按防空值的平方加权，随机选取
			self._dataProxy:HandleDirectDamage(aircraft, aircraftHPLost, caster)
		end
	end
	-- 防空炮的range实际作为半径使用(与一般武器的range语义实际是相同的)
	self._dataProxy:SpawnColumnArea(BattleConst.AOEField.AIR, self._host:GetIFF(), self._host:GetPosition(), self._range * 2, -1, areaCldFunc)
	self:EnterCoolDown()

	for crewUnit, fleetAAList in pairs(self._crewUnitList) do
		crewUnit:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ANTIAIR_FIRE_NEAR, {})
		crewUnit:PlayFX(fleetAAList[1]:GetTemplateData().fire_fx, true)
	end
	-- 特效播放
	for _, hitFXResID in pairs(self._hitFXResIDList) do
		local randomOffsetX = (math.random() * 2 - 1) * self._range
		local randomOffsetZ = (math.random() * 2 - 1) * self._range
		local fxPos = self._host:GetPosition() + Vector3(randomOffsetX, 10, randomOffsetZ)
		local fx = ys.Battle.BattleFXPool.GetInstance():GetFX(hitFXResID)

		pg.EffectMgr.GetInstance():PlayBattleEffect(fx, fxPos, true)
	end

	ys.Battle.PlayBattleSFX(self._SFXID)
end

-- 被BattleFleetAntiAirUnit.Fire调用
function BattleFleetAntiAirUnit.EnterCoolDown(self)
	self._currentState = self.STATE_OVER_HEAT

	self:AddCDTimer(self._interval)
end

function BattleFleetAntiAirUnit.GetCurrentState(self)
	return self._currentState
end

-- 被BattleFleetAntiAirUnit.EnterCoolDown调用
function BattleFleetAntiAirUnit.AddCDTimer(self, interval)
	local function onCDTimerEnds()
		self._currentState = self.STATE_READY

		self:RemoveCDTimer()
	end

	self:RemoveCDTimer()

	self._cdTimer = pg.TimeMgr.GetInstance():AddBattleTimer("weaponTimer", -1, interval, onCDTimerEnds, true)
end

function BattleFleetAntiAirUnit.RemoveCDTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._cdTimer)

	self._cdTimer = nil
end

function BattleFleetAntiAirUnit.Dispose(self)
	self:RemoveCDTimer()
	self:RemovePrecastTimer()

	self._crewUnitList = nil
	self._weightList = nil
	self._hitFXResIDList = nil
	self._dataProxy = nil
	self._SFXID = nil
end
