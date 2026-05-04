ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr2 = ys.Battle.BattleAttr
local BattleFleetVO = class("BattleFleetVO")

ys.Battle.BattleFleetVO = BattleFleetVO
BattleFleetVO.__name = "BattleFleetVO"

function BattleFleetVO.Ctor(self, IFF)
	ys.EventDispatcher.AttachEventDispatcher(self)
	ys.EventListener.AttachEventListener(self)

	self._IFF = IFF
	self._lastDist = 0

	self:init()
end

function BattleFleetVO.UpdateMotion(self)
	if self._motionReferenceUnit then
		self._motionVO:UpdatePos(self._motionReferenceUnit)
		self._motionVO:UpdateVelocityAndDirection(self:GetFleetVelocity(), self._motionSourceFunc())
	end

	local dist = math.max(self._motionVO:GetPos().x - self._rightBound, 0)

	if dist >= 0 and dist ~= self._lastDist then
		self._lastDist = dist

		self:DispatchEvent(ys.Event.New(BattleEvent.SHOW_BUFFER, {
			dist = dist
		}))
	end
end

function BattleFleetVO.UpdateAutoComponent(self, timeStamp)
	for iter_3_0, iter_3_1 in ipairs(self._scoutList) do
		iter_3_1:UpdateWeapon(timeStamp)
		iter_3_1:UpdateAirAssist()
	end

	for iter_3_2, iter_3_3 in ipairs(self._mainList) do
		iter_3_3:UpdateWeapon(timeStamp)
		iter_3_3:UpdateAirAssist()
	end

	for iter_3_4, iter_3_5 in ipairs(self._cloakList) do
		iter_3_5:UpdateCloak(timeStamp)
	end

	for iter_3_6, iter_3_7 in ipairs(self._subList) do
		iter_3_7:UpdateWeapon(timeStamp)
		iter_3_7:UpdateOxygen(timeStamp)
		iter_3_7:UpdatePhaseSwitcher()
	end

	for iter_3_8, iter_3_9 in ipairs(self._manualSubList) do
		iter_3_9:UpdateOxygen(timeStamp)
	end

	self._fleetAntiAir:Update(timeStamp)
	self._fleetRangeAntiAir:Update(timeStamp)
	self._fleetStaticSonar:Update(timeStamp)

	for iter_3_10, iter_3_11 in pairs(self._indieSonarList) do
		iter_3_10:Update(timeStamp)
	end

	self:UpdateBuff(timeStamp)
end

function BattleFleetVO.UpdateBuff(self, timeStamp)
	local buffList = self._buffList

	for iter_4_0, iter_4_1 in pairs(buffList) do
		iter_4_1:Update(self, timeStamp)
	end
end

function BattleFleetVO.UpdateManualWeaponVO(self, timeStamp)
	self._chargeWeaponVO:Update(timeStamp)
	self._torpedoWeaponVO:Update(timeStamp)
	self._airAssistVO:Update(timeStamp)
	self._submarineDiveVO:Update(timeStamp)
	self._submarineFloatVO:Update(timeStamp)
	self._submarineBoostVO:Update(timeStamp)
	self._submarineShiftVO:Update(timeStamp)
end

function BattleFleetVO.UpdateFleetDamage(self, damage)
	local fleetDamageRatio = BattleFormulas.CalculateFleetDamage(damage)

	self._currentDMGRatio = self._currentDMGRatio + fleetDamageRatio

	self:DispatchFleetDamageChange()
end

function BattleFleetVO.UpdateFleetOverDamage(self, overDamage)
	local fleetOverDamageRatio = BattleFormulas.CalculateFleetOverDamage(self, overDamage)

	self._currentDMGRatio = self._currentDMGRatio - fleetOverDamageRatio

	self:DispatchFleetDamageChange()
end

function BattleFleetVO.DispatchFleetDamageChange(self)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_DMG_CHANGE, {}))
end

function BattleFleetVO.DispatchSonarScan(self, indieSonar)
	self:DispatchEvent(ys.Event.New(BattleEvent.SONAR_SCAN, {
		indieSonar = indieSonar
	}))
end

function BattleFleetVO.FreeMainUnit(self, buffID)
	if self._mainUnitFree then
		return
	end

	self._mainUnitFree = true

	for iter_10_0, iter_10_1 in ipairs(self._mainList) do
		local buff = ys.Battle.BattleBuffUnit.New(buffID)

		iter_10_1:AddBuff(buff)
		iter_10_1:SetMainUnitStatic(false)
	end
end

function BattleFleetVO.RandomMainVictim(self, excludeAttr)
	excludeAttr = excludeAttr or {}

	local candidates = {}
	local victim

	for iter_11_0, iter_11_1 in ipairs(self._mainList) do
		local isValid = true

		for iter_11_2, iter_11_3 in ipairs(excludeAttr) do
			if iter_11_1:GetAttrByName(iter_11_3) == 1 then
				isValid = false

				break
			end
		end

		if isValid then
			table.insert(candidates, iter_11_1)
		end
	end

	if #candidates > 0 then
		victim = candidates[math.random(#candidates)]
	end

	return victim
end

function BattleFleetVO.NearestUnitByType(self, pos, typeList)
	local minDist = 999
	local nearest

	for iter_12_0, iter_12_1 in ipairs(self._unitList) do
		local unitType = iter_12_1:GetTemplate().type

		if table.contains(typeList, unitType) then
			local unitPos = iter_12_1:GetPosition()
			local dist = Vector3.BattleDistance(unitPos, pos)

			if dist < minDist then
				minDist = dist
				nearest = iter_12_1
			end
		end
	end

	return nearest
end

function BattleFleetVO.SetMotionSource(self, source)
	if source == nil then
		function self._motionSourceFunc()
			local uiMgr = pg.UIMgr.GetInstance()

			return uiMgr.hrz, uiMgr.vtc
		end
	else
		self._motionSourceFunc = source
	end
end

function BattleFleetVO.SetSubAidData(self, total, flag)
	self._submarineVO = ys.Battle.BattleSubmarineAidVO.New()

	if flag == BattleConst.SubAidFlag.AID_EMPTY or flag == BattleConst.SubAidFlag.OIL_EMPTY then
		self._submarineVO:SetUseable(false)
	else
		self._submarineVO:SetCount(flag)
		self._submarineVO:SetTotal(total)
		self._submarineVO:SetUseable(true)
	end
end

function BattleFleetVO.SetBound(self, upper, lower, left, right)
	self._upperBound = upper
	self._lowerBound = lower
	self._leftBound = left
	self._rightBound = right
end

function BattleFleetVO.SetTotalBound(self, tUpper, tLower, tLeft, tRight)
	self._totalUpperBound = tUpper
	self._totalLowerBound = tLower
	self._totalLeftBound = tLeft
	self._totalRightBound = tRight
end

function BattleFleetVO.CalcSubmarineBaseLine(self, systemType)
	local centerLine = (self._totalRightBound + self._totalLeftBound) * 0.5

	if self._IFF == BattleConfig.FRIENDLY_CODE then
		if systemType == SYSTEM_DUEL then
			-- block empty
		else
			self._subAttackBaseLine = centerLine
			self._subRetreatBaseLine = self._leftBound - 10
		end
	elseif self._IFF == BattleConfig.FOE_CODE and systemType == SYSTEM_DUEL then
		-- block empty
	end
end

function BattleFleetVO.SetExposeLine(self, visionX, exposeX)
	self._visionLineX = visionX
	self._exposeLineX = exposeX
end

function BattleFleetVO.AppendPlayerUnit(self, unit)
	self._unitList[#self._unitList + 1] = unit
	self._maxCount = self._maxCount + 1

	if unit:IsMainFleetUnit() then
		self:appendMainUnit(unit)
	else
		self:appendScoutUnit(unit)
	end

	unit:SetFleetVO(self)
	unit:SetMotion(self._motionVO)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
end

function BattleFleetVO.RemovePlayerUnit(self, unit)
	local newUnitList = {}

	for iter_21_0, iter_21_1 in ipairs(self._unitList) do
		if iter_21_1 ~= unit then
			newUnitList[#newUnitList + 1] = iter_21_0
		else
			iter_21_1:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)
			iter_21_1:DeactiveCldBox()

			local chargeList = iter_21_1:GetChargeList()

			for iter_21_2, iter_21_3 in ipairs(chargeList) do
				if iter_21_3:IsAttacking() then
					self._chargeWeaponVO:CancelFocus()
					self._chargeWeaponVO:ResetFocus()
					self:CancelChargeWeapon()
				end

				self._chargeWeaponVO:RemoveWeapon(iter_21_3)
				iter_21_3:Clear()
			end

			self._fleetAntiAir:RemoveCrewUnit(unit)
			self._fleetRangeAntiAir:RemoveCrewUnit(unit)
			self._fleetStaticSonar:RemoveCrewUnit(unit)

			local torpedoList = iter_21_1:GetTorpedoList()

			for iter_21_4, iter_21_5 in ipairs(torpedoList) do
				self:RemoveManunalTorpedo(iter_21_5)
			end

			local airAssistList = iter_21_1:GetAirAssistList()

			if airAssistList then
				for iter_21_6, iter_21_7 in ipairs(airAssistList) do
					self._airAssistVO:RemoveWeapon(iter_21_7)
				end
			end
		end
	end

	for iter_21_8, iter_21_9 in ipairs(self._scoutList) do
		if iter_21_9 == unit then
			if #self._scoutList == 1 then
				self:CancelChargeWeapon()
			end

			table.remove(self._scoutList, iter_21_8)

			break
		end
	end

	for iter_21_10, iter_21_11 in ipairs(self._mainList) do
		if iter_21_11 == unit then
			table.remove(self._mainList, iter_21_10)

			break
		end
	end

	for iter_21_12, iter_21_13 in ipairs(self._cloakList) do
		if iter_21_13 == unit then
			table.remove(self._cloakList, iter_21_12)

			break
		end
	end

	for iter_21_14, iter_21_15 in ipairs(self._subList, i) do
		if iter_21_15 == unit then
			table.remove(self._subList, iter_21_14)

			break
		end
	end

	for iter_21_16, iter_21_17 in ipairs(self._manualSubList) do
		if iter_21_17 == unit then
			table.remove(self._manualSubList, iter_21_16)

			break
		end
	end

	if not self._manualSubUnit then
		self:refreshFleetFormation(newUnitList)
	end
end

function BattleFleetVO.OverrideJoyStickAutoBot(self, aiID)
	self._autoBotAIID = aiID

	local event = ys.Event.New(ys.Battle.BattleEvent.OVERRIDE_AUTO_BOT)

	self:DispatchEvent(event)
end

function BattleFleetVO.SnapShot(self)
	self._totalDMGRatio = BattleFormulas.GetFleetTotalHP(self)
	self._currentDMGRatio = self._totalDMGRatio
end

function BattleFleetVO.GetIFF(self)
	return self._IFF
end

function BattleFleetVO.GetMaxCount(self)
	return self._maxCount
end

function BattleFleetVO.GetFlagShip(self)
	return self._flagShip
end

function BattleFleetVO.GetLeaderShip(self)
	return self._scoutList[1]
end

function BattleFleetVO.GetUnitList(self)
	return self._unitList
end

function BattleFleetVO.GetMainList(self)
	return self._mainList
end

function BattleFleetVO.GetScoutList(self)
	return self._scoutList
end

function BattleFleetVO.GetCloakList(self)
	return self._cloakList
end

function BattleFleetVO.GetSubBench(self)
	return self._manualSubBench
end

function BattleFleetVO.GetMotion(self)
	return self._motionVO
end

function BattleFleetVO.GetMotionReferenceUnit(self)
	return self._motionReferenceUnit
end

function BattleFleetVO.GetAutoBotAIID(self)
	return self._autoBotAIID
end

function BattleFleetVO.GetChargeWeaponVO(self)
	return self._chargeWeaponVO
end

function BattleFleetVO.GetTorpedoWeaponVO(self)
	return self._torpedoWeaponVO
end

function BattleFleetVO.GetAirAssistVO(self)
	return self._airAssistVO
end

function BattleFleetVO.GetSubAidVO(self)
	return self._submarineVO
end

function BattleFleetVO.GetSubFreeDiveVO(self)
	return self._submarineDiveVO
end

function BattleFleetVO.GetSubFreeFloatVO(self)
	return self._submarineFloatVO
end

function BattleFleetVO.GetSubBoostVO(self)
	return self._submarineBoostVO
end

function BattleFleetVO.GetSubSpecialVO(self)
	return self._submarineSpecialVO
end

function BattleFleetVO.GetSubShiftVO(self)
	return self._submarineShiftVO
end

function BattleFleetVO.GetFleetAntiAirWeapon(self)
	return self._fleetAntiAir
end

function BattleFleetVO.GetFleetRangeAntiAirWeapon(self)
	return self._fleetRangeAntiAir
end

function BattleFleetVO.GetFleetVelocity(self)
	return BattleFormulas.GetFleetVelocity(self._scoutList)
end

function BattleFleetVO.GetFleetBound(self)
	return self._upperBound, self._lowerBound, self._leftBound, self._rightBound
end

function BattleFleetVO.GetFleetExposeLine(self)
	return self._exposeLineX
end

function BattleFleetVO.GetFleetVisionLine(self)
	return self._visionLineX
end

function BattleFleetVO.GetLeaderPersonality(self)
	return self._motionReferenceUnit:GetAutoPilotPreference()
end

function BattleFleetVO.GetDamageRatioResult(self)
	return string.format("%0.2f", self._currentDMGRatio / self._totalDMGRatio * 100), self._totalDMGRatio
end

function BattleFleetVO.GetDamageRatio(self)
	return self._currentDMGRatio / self._totalDMGRatio
end

function BattleFleetVO.GetSubmarineBaseLine(self)
	return self._subAttackBaseLine, self._subRetreatBaseLine
end

function BattleFleetVO.GetFleetSonar(self)
	return self._fleetStaticSonar
end

function BattleFleetVO.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
	ys.EventListener.DetachEventListener(self)

	self._leaderUnit = nil

	self._fleetAntiAir:Dispose()
	self._fleetRangeAntiAir:Dispose()
	self._fleetStaticSonar:Dispose()

	self._fleetStaticSonar = nil
	self._buffList = nil
	self._indieSonarList = nil
	self._scoutAimBias = nil
end

function BattleFleetVO.refreshFleetFormation(self, arg_57_1)
	local posOffset = BattleDataFunction.GetFormationTmpDataFromID(BattleConfig.FORMATION_ID).pos_offset

	self._unitList = BattleDataFunction.SortFleetList(arg_57_1, self._unitList)

	local bornOffset = BattleConfig.BornOffset

	if not self._mainUnitFree then
		for iter_57_0, iter_57_1 in ipairs(self._unitList) do
			if not table.contains(self._subList, iter_57_1) then
				local offset = posOffset[iter_57_0]

				iter_57_1:UpdateFormationOffset(Vector3(offset.x, offset.y, offset.z) + bornOffset * (iter_57_0 - 1))
			end
		end
	end

	if #self._scoutList > 0 then
		self._motionReferenceUnit = self._scoutList[1]
		self._leaderUnit = self._scoutList[1]

		self._leaderUnit:LeaderSetting()
		self._fleetAntiAir:SwitchHost(self._motionReferenceUnit)
		self._fleetStaticSonar:SwitchHost(self._motionReferenceUnit)

		for iter_57_2, iter_57_3 in pairs(self._indieSonarList) do
			iter_57_2:SwitchHost(self._motionReferenceUnit)
		end

		self._motionVO:UpdatePos(self._motionReferenceUnit)
	elseif self._fleetAntiAir:GetCurrentState() ~= self._fleetAntiAir.STATE_DISABLE then
		local crewList = self._fleetAntiAir:GetCrewUnitList()

		for iter_57_4, iter_57_5 in pairs(crewList) do
			self._motionReferenceUnit = iter_57_4

			self._fleetAntiAir:SwitchHost(iter_57_4)

			break
		end
	else
		self._motionReferenceUnit = self._mainList[1]
		self._leaderUnit = nil
	end

	if #self:GetUnitList() == 0 then
		return
	end

	local event = ys.Event.New(ys.Battle.BattleEvent.REFRESH_FLEET_FORMATION)

	self:DispatchEvent(event)
end

function BattleFleetVO.init(self)
	self._chargeWeaponVO = ys.Battle.BattleChargeWeaponVO.New()
	self._torpedoWeaponVO = ys.Battle.BattleTorpedoWeaponVO.New()
	self._airAssistVO = ys.Battle.BattleAllInStrikeVO.New()
	self._submarineDiveVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.DIVE_CD)
	self._submarineFloatVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.FLOAT_CD)
	self._submarineVOList = {
		self._submarineDiveVO,
		self._submarineFloatVO
	}
	self._submarineBoostVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.BOOST_CD)
	self._submarineShiftVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.SHIFT_CD)
	self._submarineSpecialVO = ys.Battle.BattleSubmarineAidVO.New()

	self._submarineSpecialVO:SetCount(1)
	self._submarineSpecialVO:SetTotal(1)

	self._fleetAntiAir = ys.Battle.BattleFleetAntiAirUnit.New()
	self._fleetRangeAntiAir = ys.Battle.BattleFleetRangeAntiAirUnit.New()
	self._motionVO = ys.Battle.BattleFleetMotionVO.New()
	self._fleetStaticSonar = ys.Battle.BattleFleetStaticSonar.New(self)
	self._indieSonarList = {}
	self._scoutList = {}
	self._mainList = {}
	self._subList = {}
	self._cloakList = {}
	self._manualSubList = {}
	self._manualSubBench = {}
	self._unitList = {}
	self._maxCount = 0
	self._blockCast = 0
	self._buffList = {}

	self:SetMotionSource()
end

function BattleFleetVO.appendScoutUnit(self, arg_59_1)
	self._scoutList[#self._scoutList + 1] = arg_59_1

	local torpedoList = arg_59_1:GetTorpedoList()

	for iter_59_0, iter_59_1 in ipairs(torpedoList) do
		self._torpedoWeaponVO:AppendWeapon(iter_59_1)
	end

	if #arg_59_1:GetHiveList() > 0 then
		local allInStrikeList = BattleDataFunction.CreateAllInStrike(arg_59_1)

		for iter_59_2, iter_59_3 in ipairs(allInStrikeList) do
			self._airAssistVO:AppendWeapon(iter_59_3)
		end

		arg_59_1:SetAirAssistList(allInStrikeList)
	end

	self._fleetAntiAir:AppendCrewUnit(arg_59_1)
	self._fleetStaticSonar:AppendCrewUnit(arg_59_1)

	local i = 1
	local n = #self._unitList
	local newOrder = {}

	while i < n do
		table.insert(newOrder, i)

		i = i + 1
	end

	table.insert(newOrder, #self._scoutList, i)
	self:refreshFleetFormation(newOrder)
end

function BattleFleetVO.appendMainUnit(self, arg_60_1)
	if #self._mainList == 0 then
		self._flagShip = arg_60_1
	end

	self._mainList[#self._mainList + 1] = arg_60_1

	arg_60_1:SetMainUnitIndex(#self._mainList)

	if ShipType.CloakShipType(arg_60_1:GetTemplate().type) then
		self:AttachCloak(arg_60_1)
	end

	local var_60_0 = arg_60_1:GetChargeList()

	for iter_60_0, iter_60_1 in ipairs(var_60_0) do
		self._chargeWeaponVO:AppendWeapon(iter_60_1)
	end

	local var_60_1 = arg_60_1:GetTorpedoList()

	for iter_60_2, iter_60_3 in ipairs(var_60_1) do
		self._torpedoWeaponVO:AppendWeapon(iter_60_3)
	end

	if #arg_60_1:GetHiveList() > 0 then
		local var_60_2 = BattleDataFunction.CreateAllInStrike(arg_60_1)

		for iter_60_4, iter_60_5 in ipairs(var_60_2) do
			self._airAssistVO:AppendWeapon(iter_60_5)
		end

		arg_60_1:SetAirAssistList(var_60_2)
	end

	self._fleetAntiAir:AppendCrewUnit(arg_60_1)
	self._fleetRangeAntiAir:AppendCrewUnit(arg_60_1)
	self._fleetStaticSonar:AppendCrewUnit(arg_60_1)

	local var_60_3 = {}

	for iter_60_6, iter_60_7 in ipairs(self._unitList) do
		table.insert(var_60_3, iter_60_6)
	end

	self:refreshFleetFormation(var_60_3)
end

function BattleFleetVO.appendSubUnit(self, arg_61_1)
	self._subList[#self._subList + 1] = arg_61_1

	arg_61_1:SetMainUnitIndex(#self._subList)
end

function BattleFleetVO.FleetWarcry(self)
	local var_62_0
	local var_62_1 = math.random(0, 1)
	local var_62_2 = self:GetScoutList()[1]
	local var_62_3 = self:GetMainList()[1]

	if var_62_3 == nil or var_62_1 == 0 then
		var_62_0 = var_62_2
	elseif var_62_1 == 1 then
		var_62_0 = var_62_3
	end

	local var_62_4 = "battle"
	local var_62_5 = var_62_0:GetIntimacy()
	local var_62_6 = ys.Battle.BattleDataFunction.GetWords(var_62_0:GetSkinID(), var_62_4, var_62_5)

	var_62_0:DispatchVoice(var_62_4)
	var_62_0:DispatchChat(var_62_6, 2.5, var_62_4)
end

function BattleFleetVO.FleetUnitSpwanFinish(self)
	local var_63_0 = 0

	for iter_63_0, iter_63_1 in ipairs(self._unitList) do
		var_63_0 = var_63_0 + iter_63_1:GetGearScore()
	end

	for iter_63_2, iter_63_3 in ipairs(self._unitList) do
		BattleAttr2.SetCurrent(iter_63_3, "fleetGS", var_63_0)
	end
end

function BattleFleetVO.SubWarcry(self)
	local var_64_0 = self:GetSubList()[1]
	local var_64_1 = "battle"
	local var_64_2 = var_64_0:GetIntimacy()
	local var_64_3 = ys.Battle.BattleDataFunction.GetWords(var_64_0:GetSkinID(), var_64_1, var_64_2)

	var_64_0:DispatchVoice(var_64_1)
	var_64_0:DispatchChat(var_64_3, 2.5, var_64_1)
end

function BattleFleetVO.SetWeaponBlock(self, arg_65_1)
	self._blockCast = self._blockCast + arg_65_1
end

function BattleFleetVO.GetWeaponBlock(self)
	return self._blockCast > 0
end

function BattleFleetVO.CastChargeWeapon(self)
	if self:GetWeaponBlock() then
		return
	end

	local var_67_0 = self._chargeWeaponVO:GetCurrentWeapon()

	if var_67_0 ~= nil and var_67_0:GetCurrentState() == var_67_0.STATE_READY then
		var_67_0:Charge()

		local var_67_1 = {}
		local var_67_2 = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CHARGE, var_67_1)

		self:DispatchEvent(var_67_2)
	end
end

function BattleFleetVO.CancelChargeWeapon(self)
	local var_68_0 = self._chargeWeaponVO:GetCurrentWeapon()

	if var_68_0 ~= nil and var_68_0:GetCurrentState() == var_68_0.STATE_PRECAST then
		local var_68_1 = {}
		local var_68_2 = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CANCEL, var_68_1)

		self:DispatchEvent(var_68_2)
		var_68_0:CancelCharge()
	end
end

function BattleFleetVO.UnleashChrageWeapon(self)
	if self:GetWeaponBlock() then
		self:CancelChargeWeapon()

		return
	end

	local var_69_0 = self._chargeWeaponVO:GetCurrentWeapon()

	if var_69_0 ~= nil and var_69_0:GetCurrentState() == var_69_0.STATE_PRECAST then
		if var_69_0:IsStrikeMode() then
			local var_69_1 = self._motionVO:GetPos().x + BattleConfig.ChargeWeaponConfig.SIGHT_C
			local var_69_2 = math.min(var_69_1, self._totalRightBound)

			self:fireChargeWeapon(var_69_0, true, Vector3.New(var_69_2, 0, self._motionVO:GetPos().z))
		else
			var_69_0:CancelCharge()
		end

		local var_69_3 = {}
		local var_69_4 = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CANCEL, var_69_3)

		self:DispatchEvent(var_69_4)
	end
end

function BattleFleetVO.QuickTagChrageWeapon(self, arg_70_1)
	if self:GetWeaponBlock() then
		return
	end

	local var_70_0 = self._chargeWeaponVO:GetCurrentWeapon()

	if var_70_0 ~= nil and var_70_0:GetCurrentState() == var_70_0.STATE_READY then
		var_70_0:QuickTag()

		if #var_70_0:GetLockList() <= 0 then
			var_70_0:CancelQuickTag()
		else
			self:fireChargeWeapon(var_70_0, arg_70_1)
		end
	end
end

function BattleFleetVO.fireChargeWeapon(self, arg_71_1, arg_71_2, arg_71_3)
	local var_71_0 = arg_71_1:GetHost()

	local function var_71_1()
		local function var_72_0()
			arg_71_1:Fire(arg_71_3)
		end

		arg_71_1:DispatchBlink(var_72_0)
	end

	if arg_71_2 then
		if self._IFF == BattleConfig.FRIENDLY_CODE then
			self._chargeWeaponVO:PlayCutIn(var_71_0, 1 / BattleConfig.FOCUS_MAP_RATE)
		end

		self._chargeWeaponVO:PlayFocus(var_71_0, var_71_1)
	else
		if self._IFF == BattleConfig.FRIENDLY_CODE then
			self._chargeWeaponVO:PlayCutIn(var_71_0, 1)
		end

		var_71_1()
	end
end

function BattleFleetVO.UnleashAllInStrike(self)
	if self:GetWeaponBlock() then
		return
	end

	local var_74_0 = self._airAssistVO:GetCurrentWeapon()

	if var_74_0 and var_74_0:GetCurrentState() == var_74_0.STATE_READY then
		local var_74_1 = var_74_0:GetHost()

		if self._IFF == BattleConfig.FRIENDLY_CODE and var_74_1:IsMainFleetUnit() then
			self._airAssistVO:PlayCutIn(var_74_1, 1)
		end

		var_74_0:CLSBullet()
		var_74_0:DispatchBlink()
		var_74_0:Fire()
	end
end

function BattleFleetVO.CastTorpedo(self)
	if self:GetWeaponBlock() then
		return
	end

	local var_75_0 = self._torpedoWeaponVO:GetCurrentWeapon()

	if var_75_0 ~= nil and var_75_0:GetCurrentState() == var_75_0.STATE_READY then
		var_75_0:Prepar()
	end
end

function BattleFleetVO.CancelTorpedo(self)
	local var_76_0 = self._torpedoWeaponVO:GetCurrentWeapon()

	if var_76_0 ~= nil and var_76_0:GetCurrentState() == var_76_0.STATE_PRECAST then
		var_76_0:Cancel()
	end
end

function BattleFleetVO.UnleashTorpedo(self)
	if self:GetWeaponBlock() then
		self:CancelTorpedo()

		return
	end

	local var_77_0 = self._torpedoWeaponVO:GetCurrentWeapon()

	if var_77_0 ~= nil and var_77_0:GetCurrentState() == var_77_0.STATE_PRECAST then
		var_77_0:Fire()
	end
end

function BattleFleetVO.QuickCastTorpedo(self)
	if self:GetWeaponBlock() then
		return
	end

	local var_78_0 = self._torpedoWeaponVO:GetCurrentWeapon()

	if var_78_0 ~= nil and var_78_0:GetCurrentState() == var_78_0.STATE_READY then
		var_78_0:Fire(true)
	end
end

function BattleFleetVO.RemoveManunalTorpedo(self, arg_79_1)
	if arg_79_1:IsAttacking() then
		self:CancelTorpedo()
	end

	self._torpedoWeaponVO:RemoveWeapon(arg_79_1)
	arg_79_1:Clear()
end

function BattleFleetVO.CoupleEncourage(self)
	local var_80_0 = {}
	local var_80_1 = {}

	for iter_80_0, iter_80_1 in ipairs(self._unitList) do
		local var_80_2 = iter_80_1:GetIntimacy()
		local var_80_3 = BattleDataFunction.GetWords(iter_80_1:GetSkinID(), "couple_encourage", var_80_2)

		if #var_80_3 > 0 then
			var_80_0[iter_80_1] = var_80_3
		end
	end

	local var_80_4 = BattleConst.CPChatType
	local var_80_5 = BattleConst.CPChatTargetFunc

	local function var_80_6(self, arg_81_1)
		local var_81_0 = {}

		if self == var_80_4.GROUP_ID then
			var_81_0.groupIDList = arg_81_1
		elseif self == var_80_4.SHIP_TYPE then
			var_81_0.ship_type_list = arg_81_1
		elseif self == var_80_4.RARE then
			var_81_0.rarity = arg_81_1[1]
		elseif self == var_80_4.NATIONALITY then
			var_81_0.nationality = arg_81_1[1]
		elseif self == var_80_4.ILLUSTRATOR then
			var_81_0.illustrator = arg_81_1[1]
		elseif self == var_80_4.TEAM then
			var_81_0.teamIndex = arg_81_1[1]
		end

		return var_81_0
	end

	for iter_80_2, iter_80_3 in pairs(var_80_0) do
		for iter_80_4, iter_80_5 in ipairs(iter_80_3) do
			local var_80_7 = iter_80_5[1]
			local var_80_8 = iter_80_5[2]
			local var_80_9 = iter_80_5[4] or var_80_4.GROUP_ID
			local var_80_10 = ys.Battle.BattleTargetChoise.TargetAllHelp(iter_80_2)

			if type(var_80_9) == "table" then
				for iter_80_6, iter_80_7 in ipairs(var_80_9) do
					local var_80_11 = var_80_6(iter_80_7, var_80_7[iter_80_6])

					var_80_10 = ys.Battle.BattleTargetChoise[var_80_5[iter_80_7]](iter_80_2, var_80_11, var_80_10)
				end
			elseif type(var_80_9) == "number" then
				local var_80_12 = var_80_6(var_80_9, var_80_7)

				var_80_10 = ys.Battle.BattleTargetChoise[var_80_5[var_80_9]](iter_80_2, var_80_12, var_80_10)
			end

			if var_80_8 <= #var_80_10 then
				local var_80_13 = {
					cp = iter_80_2,
					content = iter_80_5[3],
					linkIndex = iter_80_4
				}

				var_80_1[#var_80_1 + 1] = var_80_13
			end
		end
	end

	if #var_80_1 > 0 then
		local var_80_14 = var_80_1[math.random(#var_80_1)]
		local var_80_15 = "link" .. var_80_14.linkIndex

		var_80_14.cp:DispatchVoice(var_80_15)
		var_80_14.cp:DispatchChat(var_80_14.content, 3, var_80_15)
	end
end

function BattleFleetVO.onUnitUpdateHP(self, arg_82_1)
	local var_82_0 = arg_82_1.Dispatcher
	local var_82_1 = arg_82_1.Data.dHP

	for iter_82_0, iter_82_1 in ipairs(self._unitList) do
		iter_82_1:TriggerBuff(BattleConst.BuffEffectType.ON_FRIENDLY_HP_RATIO_UPDATE, {
			unit = var_82_0,
			dHP = var_82_1
		})

		if iter_82_1 ~= var_82_0 then
			iter_82_1:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_HP_RATIO_UPDATE, {
				unit = var_82_0,
				dHP = var_82_1
			})
		end
	end
end

function BattleFleetVO.SetSubUnitData(self, arg_83_1)
	self._subUntiDataList = arg_83_1
end

function BattleFleetVO.GetSubUnitData(self)
	return self._subUntiDataList
end

function BattleFleetVO.AddSubMarine(self, arg_85_1)
	arg_85_1:InitOxygen()

	local var_85_0 = arg_85_1:GetTemplate()
	local var_85_1 = ys.Battle.BattleUnitPhaseSwitcher.New(arg_85_1)

	local function var_85_2()
		return arg_85_1:GetRaidDuration()
	end

	var_85_1:SetTemplateData(BattleDataFunction.GeneratePlayerSubmarinPhase(self._subAttackBaseLine, self._subRetreatBaseLine, arg_85_1:GetAttrByName("raidDist"), var_85_2, arg_85_1:GetAttrByName("oxyAtkDuration")))

	self._unitList[#self._unitList + 1] = arg_85_1
	self._subList[#self._subList + 1] = arg_85_1

	arg_85_1:SetFleetVO(self)
	arg_85_1:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
end

function BattleFleetVO.AddManualSubmarine(self, arg_87_1)
	self._unitList[#self._unitList + 1] = arg_87_1
	self._manualSubList[#self._manualSubList + 1] = arg_87_1
	self._manualSubBench[#self._manualSubBench + 1] = arg_87_1
	self._maxCount = self._maxCount + 1

	arg_87_1:InitOxygen()
	arg_87_1:SetFleetVO(self)
	arg_87_1:SetMotion(self._motionVO)
	arg_87_1:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
end

function BattleFleetVO.GetSubList(self)
	return self._subList
end

function BattleFleetVO.ShiftManualSub(self)
	local var_89_0

	if self._manualSubUnit then
		local var_89_1 = self._manualSubUnit:GetTorpedoList()

		for iter_89_0, iter_89_1 in ipairs(var_89_1) do
			if iter_89_1:IsAttacking() then
				self:CancelTorpedo()
			end

			self._torpedoWeaponVO:RemoveWeapon(iter_89_1)
		end

		if self._manualSubUnit:IsAlive() then
			table.insert(self._manualSubBench, self._manualSubUnit)
		end

		var_89_0 = self._motionVO:GetPos():Clone()
	else
		var_89_0 = self._manualSubList[1]:GetPosition():Clone()
	end

	self._manualSubUnit = table.remove(self._manualSubBench, 1)
	self._scoutList[1] = self._manualSubUnit

	local var_89_2 = {}

	for iter_89_2, iter_89_3 in ipairs(self._manualSubBench) do
		for iter_89_4, iter_89_5 in ipairs(self._unitList) do
			if iter_89_5 == iter_89_3 then
				table.insert(var_89_2, iter_89_4)

				break
			end
		end
	end

	for iter_89_6, iter_89_7 in ipairs(self._unitList) do
		if iter_89_7 == self._manualSubUnit then
			table.insert(var_89_2, 1, iter_89_6)

			break
		end
	end

	self:refreshFleetFormation(var_89_2)
	self._manualSubUnit:SetMainUnitStatic(false)
	self._manualSubUnit:SetPosition(var_89_0)
	self:UpdateMotion()
	self._submarineSpecialVO:SetUseable(false)

	local var_89_3 = self._manualSubUnit:GetBuffList()

	for iter_89_8, iter_89_9 in pairs(var_89_3) do
		if iter_89_9:IsSubmarineSpecial() then
			self._submarineSpecialVO:SetCount(1)
			self._submarineSpecialVO:SetUseable(true)

			break
		end
	end

	self:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE)
	self._torpedoWeaponVO:Reset()

	local var_89_4 = self._manualSubUnit:GetTorpedoList()

	for iter_89_10, iter_89_11 in ipairs(var_89_4) do
		if iter_89_11:GetCurrentState() ~= iter_89_11.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(iter_89_11)
		end
	end

	for iter_89_12, iter_89_13 in ipairs(var_89_4) do
		if iter_89_13:GetCurrentState() == iter_89_13.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(iter_89_13)
		end
	end

	for iter_89_14, iter_89_15 in ipairs(self._manualSubBench) do
		iter_89_15:SetPosition(BattleConfig.SUB_BENCH_POS[iter_89_14])
		iter_89_15:SetMainUnitStatic(true)
		iter_89_15:ChangeOxygenState(ys.Battle.OxyState.STATE_FREE_BENCH)
	end

	self._submarineShiftVO:ResetCurrent()

	if #self._manualSubBench == 0 then
		self._submarineShiftVO:SetActive(false)
	end
end

function BattleFleetVO.ChangeSubmarineState(self, arg_90_1, arg_90_2)
	if not self._manualSubUnit then
		return
	end

	self._manualSubUnit:ChangeOxygenState(arg_90_1)

	if arg_90_2 then
		for iter_90_0, iter_90_1 in ipairs(self._submarineVOList) do
			iter_90_1:ResetCurrent()
		end

		local var_90_0 = self._submarineShiftVO:GetMax() - self._submarineShiftVO:GetCurrent()

		if self._submarineShiftVO:IsOverLoad() and var_90_0 > BattleConfig.SR_CONFIG.DIVE_CD then
			-- block empty
		else
			self._submarineShiftVO:SetMax(BattleConfig.SR_CONFIG.DIVE_CD)
			self._submarineShiftVO:ResetCurrent()
		end
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.MANUAL_SUBMARINE_SHIFT, {
		state = arg_90_1
	}))
end

function BattleFleetVO.SubmarinBoost(self)
	self._manualSubUnit:Boost(Vector3.right, BattleConfig.SR_CONFIG.BOOST_SPEED, BattleConfig.SR_CONFIG.BOOST_DECAY, BattleConfig.SR_CONFIG.BOOST_DURATION, BattleConfig.SR_CONFIG.BOOST_DECAY_STAMP)
	self._submarineBoostVO:ResetCurrent()
end

function BattleFleetVO.UnleashSubmarineSpecial(self)
	if self:GetWeaponBlock() then
		return
	end

	self._submarineSpecialVO:Cast()
	self._manualSubUnit:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FREE_SPECIAL)
end

function BattleFleetVO.AppendIndieSonar(self, arg_93_1, arg_93_2)
	local var_93_0 = ys.Battle.BattleIndieSonar.New(self, arg_93_1, arg_93_2)

	var_93_0:SwitchHost(self._motionReferenceUnit)

	self._indieSonarList[var_93_0] = true

	var_93_0:Detect()
end

function BattleFleetVO.RemoveIndieSonar(self, arg_94_1)
	for iter_94_0, iter_94_1 in pairs(self._indieSonarList) do
		if arg_94_1 == iter_94_0 then
			self._indieSonarList[iter_94_0] = nil

			break
		end
	end
end

function BattleFleetVO.AttachFleetBuff(self, arg_95_1)
	local var_95_0 = arg_95_1:GetID()
	local var_95_1 = self:GetFleetBuff(var_95_0)

	if var_95_1 then
		var_95_1:Stack(self)
	else
		self._buffList[var_95_0] = arg_95_1

		arg_95_1:Attach(self)
	end
end

function BattleFleetVO.RemoveFleetBuff(self, arg_96_1)
	local var_96_0 = self:GetFleetBuff(arg_96_1)

	if var_96_0 then
		var_96_0:Remove()
	end
end

function BattleFleetVO.GetFleetBuff(self, arg_97_1)
	return self._buffList[arg_97_1]
end

function BattleFleetVO.GetFleetBuffList(self)
	return self._buffList
end

function BattleFleetVO.Jamming(self, arg_99_1)
	if arg_99_1 then
		self._chargeWeaponVO:StartJamming()
		self._torpedoWeaponVO:StartJamming()
		self._airAssistVO:StartJamming()
	else
		self._chargeWeaponVO:JammingEliminate()
		self._torpedoWeaponVO:JammingEliminate()
		self._airAssistVO:JammingEliminate()
	end
end

function BattleFleetVO.Blinding(self, arg_100_1)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_BLIND, {
		isBlind = arg_100_1
	}))
end

function BattleFleetVO.UpdateHorizon(self)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_HORIZON_UPDATE, {}))
end

function BattleFleetVO.AutoBotUpdated(self, arg_102_1)
	local var_102_0 = arg_102_1 and BattleConst.BuffEffectType.ON_AUTOBOT or BattleConst.BuffEffectType.ON_MANUAL

	for iter_102_0, iter_102_1 in ipairs(self._unitList) do
		iter_102_1:TriggerBuff(var_102_0)
	end
end

function BattleFleetVO.CloakFatalExpose(self)
	for iter_103_0, iter_103_1 in ipairs(self._cloakList) do
		iter_103_1:GetCloak():ForceToMax()
	end
end

function BattleFleetVO.CloakInVision(self, arg_104_1)
	for iter_104_0, iter_104_1 in ipairs(self._cloakList) do
		iter_104_1:GetCloak():AppendExposeSpeed(arg_104_1)
	end
end

function BattleFleetVO.CloakOutVision(self)
	for iter_105_0, iter_105_1 in ipairs(self._cloakList) do
		iter_105_1:GetCloak():AppendExposeSpeed(0)
	end
end

function BattleFleetVO.AttachCloak(self, arg_106_1)
	if not arg_106_1:GetCloak() then
		arg_106_1:InitCloak()

		self._cloakList[#self._cloakList + 1] = arg_106_1
	end
end

function BattleFleetVO.AttachNightCloak(self)
	self._scoutAimBias = ys.Battle.BattleUnitAimBiasComponent.New()

	self._scoutAimBias:ConfigRangeFormula(BattleFormulas.CalculateMaxAimBiasRange, BattleFormulas.CalculateBiasDecay)
	self._scoutAimBias:Active(self._scoutAimBias.STATE_ACTIVITING)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIM_BIAS, {
		aimBias = self._scoutAimBias
	}))
end

function BattleFleetVO.GetFleetBias(self)
	return self._scoutAimBias
end
