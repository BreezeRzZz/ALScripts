ys = ys or {}
-- TODO
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleDataFunction = ys.Battle.BattleDataFunction
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

-- 舰队的整体位置更新
-- 被BattleDataProxy.updateLoop调用
function BattleFleetVO.UpdateMotion(self)
	local distance = 0

	if self._motionReferenceUnit then
		self._motionVO:UpdatePos(self._motionReferenceUnit)
		self._motionVO:UpdateVelocityAndDirection(self:GetFleetVelocity(), self._motionSourceFunc())
		-- 此处的rightBound应为自律右边界/player右边界?
		distance = math.max(self._motionVO:GetPos().x - self._rightBound, 0)
	end

	if distance >= 0 and distance ~= self._lastDist then
		self._lastDist = distance
		-- 移动过界，触发缓冲事件
		self:DispatchEvent(ys.Event.New(BattleEvent.SHOW_BUFFER, {
			dist = distance
		}))
	end
end

-- 被BattleDataProxy.UpdateAutoComponent调用
-- 总的来说，每AI帧(0.1s)调用一次，更新舰队内各个单位的武器、潜艇、隐蔽等状态
function BattleFleetVO.UpdateAutoComponent(self, timeStamp)
	-- 前排武器、空袭更新
	for _, scout in ipairs(self._scoutList) do
		scout:UpdateWeapon(timeStamp)
		scout:UpdateAirAssist()
	end
	-- 后排武器、空袭更新
	for _, mainUnit in ipairs(self._mainList) do
		mainUnit:UpdateWeapon(timeStamp)
		mainUnit:UpdateAirAssist()
	end
	-- 支援舰队武器更新
	for _, supportUnit in ipairs(self._supportList) do
		supportUnit:UpdateWeapon(timeStamp)
	end
	-- 具有隐蔽状态的舰船，更新隐蔽状态
	for _, cloakUnit in ipairs(self._cloakList) do
		cloakUnit:UpdateCloak(timeStamp)
	end
	-- 潜艇武器、氧气、阶段切换更新
	for _, subUnit in ipairs(self._subList) do
		subUnit:UpdateWeapon(timeStamp)
		subUnit:UpdateOxygen(timeStamp)
		subUnit:UpdatePhaseSwitcher()
	end
	-- (仅破交用)手动潜艇的氧气更新
	for _, manualSubUnit in ipairs(self._manualSubList) do
		manualSubUnit:UpdateOxygen(timeStamp)
	end
	-- 更新全队的近程防空炮、远程防空炮、静态声呐
	self._fleetAntiAir:Update(timeStamp)
	self._fleetRangeAntiAir:Update(timeStamp)
	self._fleetStaticSonar:Update(timeStamp)
	-- 更新独立声呐
	for indieSonar, _ in pairs(self._indieSonarList) do
		indieSonar:Update(timeStamp)
	end
	-- 更新舰队Buff状态, 具体看 BattleFleetVO.UpdateBuff
	self:UpdateBuff(timeStamp)
	-- cardPuzzle为废案，不看
	if self._cardPuzzleComponent then
		self._cardPuzzleComponent:Update(timeStamp)
	end
end

function BattleFleetVO.UpdateBuff(self, timeStamp)
	local buffList = self._buffList

	for _, buff in pairs(buffList) do
		buff:Update(self, timeStamp)
	end
end

-- 被BattleControllerWeaponCommand.Update调用
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

function BattleFleetVO.UpdateFleetOverDamage(self, ship)
	local fleetDamageRatio = BattleFormulas.CalculateFleetOverDamage(self, ship)

	self._currentDMGRatio = self._currentDMGRatio - fleetDamageRatio

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

function BattleFleetVO.FleetBuffTrigger(self, effectType, arg_list)
	for _, unit in ipairs(self._unitList) do
		unit:TriggerBuff(effectType, arg_list)
	end
end

-- 模拟战使用(BattleSimulationCommand). 添加Buff 41(后排移动)
function BattleFleetVO.FreeMainUnit(self, buffID)
	if self._mainUnitFree then
		return
	end

	self._mainUnitFree = true

	for _, mainUnit in ipairs(self._mainList) do
		local buff = ys.Battle.BattleBuffUnit.New(buffID)

		mainUnit:AddBuff(buff)
		mainUnit:SetMainUnitStatic(false)
	end
end

-- 舰船/舰载机触底时，选择一个随机主力舰作为受伤害目标
-- 被BattleDataProxy.HandleAircraftMissDamage/BattleDataProxy.HandleShipMissDamage调用
function BattleFleetVO.RandomMainVictim(self, attrList)
	attrList = attrList or {}

	local resList = {}
	local victim

	for _, mainUnit in ipairs(self._mainList) do
		local canBeHit = true

		for _, attr in ipairs(attrList) do
			-- 只用过immuneDirectHit来过滤
			if mainUnit:GetAttrByName(attr) >= 1 then
				canBeHit = false

				break
			end
		end

		if canBeHit then
			table.insert(resList, mainUnit)
		end
	end

	if #resList > 0 then
		victim = resList[math.random(#resList)]
	end

	return victim
end

-- 用于找出距离pos最近的指定类型舰船
-- 被BattleDataProxy.HandleAircraftMissDamage/BattleDataProxy.HandleShipMissDamage调用
-- 主要是用于对这个最近的单位添加额外暴露值
function BattleFleetVO.NearestUnitByType(self, pos, shipTypeList)
	local minDistance = 999
	local target

	for _, unit in ipairs(self._unitList) do
		local shipType = unit:GetTemplate().type

		if table.contains(shipTypeList, shipType) then
			local unitPos = unit:GetPosition()
			-- 只计算XZ平面距离
			local distance = Vector3.BattleDistance(unitPos, pos)

			if distance < minDistance then
				minDistance = distance
				target = unit
			end
		end
	end

	return target
end

function BattleFleetVO.SetMotionSource(self, motionSource)
	if motionSource == nil then
		-- 默认返回的是UI的X、Z轴输入
		function self._motionSourceFunc()
			local uiMgr = pg.UIMgr.GetInstance()

			return uiMgr.hrz, uiMgr.vtc
		end
	else
		self._motionSourceFunc = motionSource
	end
end

function BattleFleetVO.SetSubAidData(arg_16_0, arg_16_1, arg_16_2)
	arg_16_0._submarineVO = ys.Battle.BattleSubmarineAidVO.New()

	if arg_16_2 == BattleConst.SubAidFlag.AID_EMPTY or arg_16_2 == BattleConst.SubAidFlag.OIL_EMPTY then
		arg_16_0._submarineVO:SetUseable(false)
	else
		arg_16_0._submarineVO:SetCount(arg_16_2)
		arg_16_0._submarineVO:SetTotal(arg_16_1)
		arg_16_0._submarineVO:SetUseable(true)
	end
end

function BattleFleetVO.SetAutobotBound(arg_17_0, arg_17_1, arg_17_2, arg_17_3, arg_17_4)
	arg_17_0._upperBound = arg_17_1
	arg_17_0._lowerBound = arg_17_2
	arg_17_0._leftBound = arg_17_3
	arg_17_0._rightBound = arg_17_4
end

function BattleFleetVO.SetTotalBound(arg_18_0, arg_18_1, arg_18_2, arg_18_3, arg_18_4)
	arg_18_0._totalUpperBound = arg_18_1
	arg_18_0._totalLowerBound = arg_18_2
	arg_18_0._totalLeftBound = arg_18_3
	arg_18_0._totalRightBound = arg_18_4
end

function BattleFleetVO.SetUnitBound(arg_19_0, arg_19_1, arg_19_2)
	arg_19_0._fleetUnitBound = ys.Battle.BattleFleetBound.New(arg_19_0._IFF)

	arg_19_0._fleetUnitBound:ConfigAreaData(arg_19_1, arg_19_2)
	arg_19_0._fleetUnitBound:SwtichCommon()
end

function BattleFleetVO.SetChapterPlayType(arg_20_0, arg_20_1)
	arg_20_0._chapterType = arg_20_1
end

function BattleFleetVO.GetLeftBoundDistance(arg_21_0)
	if arg_21_0._chapterType and arg_21_0._chapterType == 5 then
		return math.abs(arg_21_0._motionVO:GetPos().x - arg_21_0._leftBound)
	end
end

function BattleFleetVO.UpdateScoutUnitBound(arg_22_0)
	local var_22_0, var_22_1, var_22_2, var_22_3, var_22_4, var_22_5 = arg_22_0._fleetUnitBound:GetBound()

	for iter_22_0, iter_22_1 in ipairs(arg_22_0._scoutList) do
		iter_22_1:SetBound(var_22_0, var_22_1, var_22_2, var_22_3, var_22_4, var_22_5)
	end

	for iter_22_2, iter_22_3 in pairs(arg_22_0._freezeList) do
		if not iter_22_2:IsMainFleetUnit() then
			iter_22_2:SetBound(var_22_0, var_22_1, var_22_2, var_22_3, var_22_4, var_22_5)
		end
	end
end

-- note: 计算潜艇攻击和撤退基准线
function BattleFleetVO.CalcSubmarineBaseLine(self, battleType)
	local subAttackBaseLine = (self._totalRightBound + self._totalLeftBound) * 0.5

	if self._IFF == BattleConfig.FRIENDLY_CODE then
		if battleType == SYSTEM_DUEL then
			-- block empty
		else
			self._subAttackBaseLine = subAttackBaseLine
			self._subRetreatBaseLine = self._leftBound - 10
		end
	elseif self._IFF == BattleConfig.FOE_CODE and battleType == SYSTEM_DUEL then
		-- block empty
	end
end

function BattleFleetVO.SetExposeLine(arg_24_0, arg_24_1, arg_24_2)
	arg_24_0._visionLineX = arg_24_1
	arg_24_0._exposeLineX = arg_24_2
end

function BattleFleetVO.AppendPlayerUnit(arg_25_0, arg_25_1)
	arg_25_0._unitList[#arg_25_0._unitList + 1] = arg_25_1
	arg_25_0._maxCount = arg_25_0._maxCount + 1

	if arg_25_1:IsMainFleetUnit() then
		arg_25_0:appendMainUnit(arg_25_1)
	else
		arg_25_0:appendScoutUnit(arg_25_1)
	end

	arg_25_1:SetFleetVO(arg_25_0)
	arg_25_1:SetMotion(arg_25_0._motionVO)
	arg_25_1:RegisterEventListener(arg_25_0, BattleUnitEvent.UPDATE_HP, arg_25_0.onUnitUpdateHP)
	arg_25_1:RegisterEventListener(arg_25_0, BattleUnitEvent.UPDATE_CLOAK_STATE, arg_25_0.onUnitCloakUpdate)

	if arg_25_0._cardPuzzleComponent then
		arg_25_0._cardPuzzleComponent:AppendUnit(arg_25_1)
	end
end

function BattleFleetVO.RemovePlayerUnit(arg_26_0, arg_26_1, arg_26_2)
	arg_26_0._freezeList[arg_26_1] = nil

	local var_26_0 = {}

	for iter_26_0, iter_26_1 in ipairs(arg_26_0._unitList) do
		if iter_26_1 ~= arg_26_1 then
			var_26_0[#var_26_0 + 1] = iter_26_0
		else
			if not arg_26_2 then
				iter_26_1:UnregisterEventListener(arg_26_0, BattleUnitEvent.UPDATE_HP)
				iter_26_1:UnregisterEventListener(arg_26_0, BattleUnitEvent.UPDATE_CLOAK_STATE)
				iter_26_1:DeactiveCldBox()
			end

			local var_26_1 = iter_26_1:GetChargeList()

			for iter_26_2, iter_26_3 in ipairs(var_26_1) do
				if iter_26_3:IsAttacking() then
					arg_26_0._chargeWeaponVO:CancelFocus()
					arg_26_0._chargeWeaponVO:ResetFocus()
					arg_26_0:CancelChargeWeapon()
				end

				arg_26_0._chargeWeaponVO:RemoveWeapon(iter_26_3)

				if not arg_26_2 then
					iter_26_3:Clear()
				end
			end

			arg_26_0._fleetAntiAir:RemoveCrewUnit(arg_26_1)
			arg_26_0._fleetRangeAntiAir:RemoveCrewUnit(arg_26_1)
			arg_26_0._fleetStaticSonar:RemoveCrewUnit(arg_26_1)

			local var_26_2 = iter_26_1:GetTorpedoList()

			for iter_26_4, iter_26_5 in ipairs(var_26_2) do
				arg_26_0:RemoveManunalTorpedo(iter_26_5, arg_26_2)
			end

			local var_26_3 = iter_26_1:GetAirAssistList()

			if var_26_3 then
				for iter_26_6, iter_26_7 in ipairs(var_26_3) do
					arg_26_0._airAssistVO:RemoveWeapon(iter_26_7)
				end
			end
		end
	end

	for iter_26_8, iter_26_9 in ipairs(arg_26_0._scoutList) do
		if iter_26_9 == arg_26_1 then
			if #arg_26_0._scoutList == 1 then
				arg_26_0:CancelChargeWeapon()
			end

			table.remove(arg_26_0._scoutList, iter_26_8)

			break
		end
	end

	local function var_26_4(arg_27_0)
		for iter_27_0, iter_27_1 in ipairs(arg_27_0) do
			if iter_27_1 == arg_26_1 then
				table.remove(arg_27_0, iter_27_0)

				break
			end
		end
	end

	var_26_4(arg_26_0._mainList)
	var_26_4(arg_26_0._cloakList)
	var_26_4(arg_26_0._subList)
	var_26_4(arg_26_0._manualSubList)

	if not arg_26_0._manualSubUnit then
		arg_26_0:refreshFleetFormation(var_26_0)
	end
end

function BattleFleetVO.OverrideJoyStickAutoBot(arg_28_0, arg_28_1)
	arg_28_0._autoBotAIID = arg_28_1

	local var_28_0 = ys.Event.New(ys.Battle.BattleEvent.OVERRIDE_AUTO_BOT)

	arg_28_0:DispatchEvent(var_28_0)
end

function BattleFleetVO.SnapShot(arg_29_0)
	arg_29_0._totalDMGRatio = BattleFormulas.GetFleetTotalHP(arg_29_0)
	arg_29_0._currentDMGRatio = arg_29_0._totalDMGRatio
end

function BattleFleetVO.GetIFF(arg_30_0)
	return arg_30_0._IFF
end

function BattleFleetVO.GetMaxCount(arg_31_0)
	return arg_31_0._maxCount
end

function BattleFleetVO.GetFlagShip(arg_32_0)
	return arg_32_0._flagShip
end

function BattleFleetVO.GetLeaderShip(arg_33_0)
	return arg_33_0._scoutList[1]
end

function BattleFleetVO.GetUnitList(arg_34_0)
	return arg_34_0._unitList
end

function BattleFleetVO.GetFreezeUnitList(arg_35_0)
	return arg_35_0._freezeList
end

function BattleFleetVO.GetMainList(arg_36_0)
	return arg_36_0._mainList
end

function BattleFleetVO.GetScoutList(arg_37_0)
	return arg_37_0._scoutList
end

function BattleFleetVO.GetFreezeShipByID(arg_38_0, arg_38_1)
	for iter_38_0, iter_38_1 in pairs(arg_38_0._freezeList) do
		if arg_38_1 == iter_38_0:GetAttrByName("id") then
			return iter_38_0
		end
	end
end

function BattleFleetVO.GetShipByID(arg_39_0, arg_39_1)
	for iter_39_0, iter_39_1 in ipairs(arg_39_0._unitList) do
		if arg_39_1 == iter_39_1:GetAttrByName("id") then
			return iter_39_1
		end
	end
end

function BattleFleetVO.GetCloakList(arg_40_0)
	return arg_40_0._cloakList
end

function BattleFleetVO.GetSubBench(arg_41_0)
	return arg_41_0._manualSubBench
end

function BattleFleetVO.GetUnitBound(arg_42_0)
	return arg_42_0._fleetUnitBound
end

function BattleFleetVO.GetMotion(arg_43_0)
	return arg_43_0._motionVO
end

function BattleFleetVO.GetMotionReferenceUnit(self)
	return self._motionReferenceUnit
end

function BattleFleetVO.GetAutoBotAIID(arg_45_0)
	return arg_45_0._autoBotAIID
end

function BattleFleetVO.GetChargeWeaponVO(arg_46_0)
	return arg_46_0._chargeWeaponVO
end

function BattleFleetVO.GetTorpedoWeaponVO(arg_47_0)
	return arg_47_0._torpedoWeaponVO
end

function BattleFleetVO.GetAirAssistVO(arg_48_0)
	return arg_48_0._airAssistVO
end

function BattleFleetVO.GetSubAidVO(arg_49_0)
	return arg_49_0._submarineVO
end

function BattleFleetVO.GetSubFreeDiveVO(arg_50_0)
	return arg_50_0._submarineDiveVO
end

function BattleFleetVO.GetSubFreeFloatVO(arg_51_0)
	return arg_51_0._submarineFloatVO
end

function BattleFleetVO.GetSubBoostVO(arg_52_0)
	return arg_52_0._submarineBoostVO
end

function BattleFleetVO.GetSubSpecialVO(arg_53_0)
	return arg_53_0._submarineSpecialVO
end

function BattleFleetVO.GetSubShiftVO(arg_54_0)
	return arg_54_0._submarineShiftVO
end

function BattleFleetVO.GetFleetAntiAirWeapon(arg_55_0)
	return arg_55_0._fleetAntiAir
end

function BattleFleetVO.GetFleetRangeAntiAirWeapon(arg_56_0)
	return arg_56_0._fleetRangeAntiAir
end

function BattleFleetVO.GetFleetVelocity(self)
	return BattleFormulas.GetFleetVelocity(self._scoutList)
end

function BattleFleetVO.GetFleetBound(arg_58_0)
	return arg_58_0._upperBound, arg_58_0._lowerBound, arg_58_0._leftBound, arg_58_0._rightBound
end

function BattleFleetVO.GetFleetUnitBound(arg_59_0)
	return arg_59_0._totalUpperBound, arg_59_0._totalLowerBound
end

function BattleFleetVO.GetFleetExposeLine(self)
	return self._exposeLineX
end

function BattleFleetVO.GetFleetVisionLine(self)
	return self._visionLineX
end

-- 被RandomStrategy.generateTargetPoint调用
function BattleFleetVO.GetLeaderPersonality(self)
	return self._motionReferenceUnit:GetAutoPilotPreference()
end

function BattleFleetVO.GetDamageRatioResult(arg_63_0)
	return string.format("%0.2f", arg_63_0._currentDMGRatio / arg_63_0._totalDMGRatio * 100), arg_63_0._totalDMGRatio
end

function BattleFleetVO.GetDamageRatio(arg_64_0)
	return arg_64_0._currentDMGRatio / arg_64_0._totalDMGRatio
end

function BattleFleetVO.GetSubmarineBaseLine(arg_65_0)
	return arg_65_0._fixedSubRefLine or arg_65_0._subAttackBaseLine, arg_65_0._subRetreatBaseLine
end

function BattleFleetVO.GetFleetSonar(arg_66_0)
	return arg_66_0._fleetStaticSonar
end

function BattleFleetVO.Dispose(arg_67_0)
	ys.EventDispatcher.DetachEventDispatcher(arg_67_0)
	ys.EventListener.DetachEventListener(arg_67_0)

	arg_67_0._leaderUnit = nil

	arg_67_0._fleetAntiAir:Dispose()
	arg_67_0._fleetRangeAntiAir:Dispose()
	arg_67_0._fleetStaticSonar:Dispose()

	arg_67_0._fleetStaticSonar = nil
	arg_67_0._buffList = nil
	arg_67_0._indieSonarList = nil
	arg_67_0._scoutAimBias = nil

	arg_67_0._fleetAttr:Dispose()

	arg_67_0._fleetAttr = nil
	arg_67_0._freezeList = nil
end

-- 刷新前排舰队阵型/位置的主逻辑, 重要
-- 在各种append/remove unit后调用
function BattleFleetVO.refreshFleetFormation(self, currentUnitList)
	-- FORMATION_ID = 10001
	-- 吐槽: formation_template可能是早期用于实现阵型的遗留产物, 类似已有的Clike游戏中的阵型系统
	-- 但后来转变为做了一个弹幕射击游戏，阵型就粗糙的设计为了几个Buff
	-- 现在的"阵型"实际是拿来给敌方AirFighter使用的
	-- 此外, 还用于了我方前排的阵型(写死)
	-- 因为我方前排最多3人，可以看到实际是每个单位之间有offsetX = -4
	local pos_offset = BattleDataFunction.GetFormationTmpDataFromID(BattleConfig.FORMATION_ID).pos_offset
	-- 重新计算index
	self._unitList = BattleDataFunction.SortFleetList(currentUnitList, self._unitList)
	-- BornOffset = Vector3(0, 0, 0.1)
	local bornOffset = BattleConfig.BornOffset

	if not self._mainUnitFree then
		for index, unit in ipairs(self._unitList) do
			if not table.contains(self._subList, unit) then
				local offset = pos_offset[index] or pos_offset[#pos_offset]
				-- 计算每个unit的实际位置(根据offset)
				-- bornOffset稍微分开了0.1的z轴距离
				unit:UpdateFormationOffset(Vector3(offset.x, offset.y, offset.z) + bornOffset * (index - 1))
			end
		end
	end

	if #self._scoutList > 0 then
		-- 前排的移动，是以第一个前排单位(前排领舰)为参考的
		self._motionReferenceUnit = self._scoutList[1]
		self._leaderUnit = self._scoutList[1]

		self._leaderUnit:LeaderSetting()
		-- 近程防空炮和静态声呐的host为前排领舰
		self._fleetAntiAir:SwitchHost(self._motionReferenceUnit)
		self._fleetStaticSonar:SwitchHost(self._motionReferenceUnit)
		-- 同样为前排领舰
		for indieSonar, _ in pairs(self._indieSonarList) do
			indieSonar:SwitchHost(self._motionReferenceUnit)
		end
		-- motionVO的位置为前排领舰的位置
		self._motionVO:UpdatePos(self._motionReferenceUnit)
	elseif self._fleetAntiAir:GetCurrentState() ~= self._fleetAntiAir.STATE_DISABLE then
		local fleetAntiAirCrewUnitList = self._fleetAntiAir:GetCrewUnitList()

		for fleetAntiAirCrewUnit, _ in pairs(fleetAntiAirCrewUnitList) do
			self._motionReferenceUnit = fleetAntiAirCrewUnit

			self._fleetAntiAir:SwitchHost(fleetAntiAirCrewUnit)

			break
		end
	else
		-- 没有前排就用旗舰(但实战应该不会没有前排)
		self._motionReferenceUnit = self._mainList[1]
		self._leaderUnit = nil
	end

	if #self:GetUnitList() == 0 then
		return
	end

	local refreshFleetFormationEvent = ys.Event.New(ys.Battle.BattleEvent.REFRESH_FLEET_FORMATION)

	self:DispatchEvent(refreshFleetFormationEvent)
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
	self._supportList = {}
	self._cloakList = {}
	self._manualSubList = {}
	self._manualSubBench = {}
	self._unitList = {}
	self._maxCount = 0
	self._freezeList = {}
	self._blockCast = 0
	self._buffList = {}

	self:AttachFleetAttr()
	self:SetMotionSource()
end

function BattleFleetVO.appendScoutUnit(arg_70_0, arg_70_1)
	arg_70_0._scoutList[#arg_70_0._scoutList + 1] = arg_70_1

	local var_70_0 = arg_70_1:GetTorpedoList()

	for iter_70_0, iter_70_1 in ipairs(var_70_0) do
		arg_70_0._torpedoWeaponVO:AppendWeapon(iter_70_1)
	end

	if #arg_70_1:GetHiveList() > 0 then
		local var_70_1 = BattleDataFunction.CreateAllInStrike(arg_70_1)

		for iter_70_2, iter_70_3 in ipairs(var_70_1) do
			arg_70_0._airAssistVO:AppendWeapon(iter_70_3)
		end

		arg_70_1:SetAirAssistList(var_70_1)
	end

	arg_70_0._fleetAntiAir:AppendCrewUnit(arg_70_1)
	arg_70_0._fleetStaticSonar:AppendCrewUnit(arg_70_1)

	local var_70_2 = 1
	local var_70_3 = #arg_70_0._unitList
	local var_70_4 = {}

	while var_70_2 < var_70_3 do
		table.insert(var_70_4, var_70_2)

		var_70_2 = var_70_2 + 1
	end

	table.insert(var_70_4, #arg_70_0._scoutList, var_70_2)
	arg_70_0:refreshFleetFormation(var_70_4)
end
-- TODO
function BattleFleetVO.appendMainUnit(arg_71_0, arg_71_1)
	if #arg_71_0._mainList == 0 then
		arg_71_0._flagShip = arg_71_1
	end

	arg_71_0._mainList[#arg_71_0._mainList + 1] = arg_71_1

	arg_71_1:SetMainUnitIndex(#arg_71_0._mainList)

	if ShipType.CloakShipType(arg_71_1:GetTemplate().type) then
		arg_71_0:AttachCloak(arg_71_1)
	end

	local var_71_0 = arg_71_1:GetChargeList()

	for iter_71_0, iter_71_1 in ipairs(var_71_0) do
		arg_71_0._chargeWeaponVO:AppendWeapon(iter_71_1)
	end

	local var_71_1 = arg_71_1:GetTorpedoList()

	for iter_71_2, iter_71_3 in ipairs(var_71_1) do
		arg_71_0._torpedoWeaponVO:AppendWeapon(iter_71_3)
	end

	if #arg_71_1:GetHiveList() > 0 then
		-- 此处将Hive->Airassist
		local var_71_2 = BattleDataFunction.CreateAllInStrike(arg_71_1)

		for iter_71_4, iter_71_5 in ipairs(var_71_2) do
			arg_71_0._airAssistVO:AppendWeapon(iter_71_5)
		end

		arg_71_1:SetAirAssistList(var_71_2)
	end

	arg_71_0._fleetAntiAir:AppendCrewUnit(arg_71_1)
	arg_71_0._fleetRangeAntiAir:AppendCrewUnit(arg_71_1)
	arg_71_0._fleetStaticSonar:AppendCrewUnit(arg_71_1)

	local var_71_3 = {}

	for iter_71_6, iter_71_7 in ipairs(arg_71_0._unitList) do
		table.insert(var_71_3, iter_71_6)
	end

	arg_71_0:refreshFleetFormation(var_71_3)
end

function BattleFleetVO.appendSubUnit(arg_72_0, arg_72_1)
	arg_72_0._subList[#arg_72_0._subList + 1] = arg_72_1

	arg_72_1:SetMainUnitIndex(#arg_72_0._subList)
end

function BattleFleetVO.FleetWarcry(arg_73_0)
	local var_73_0
	local var_73_1 = math.random(0, 1)
	local var_73_2 = arg_73_0:GetScoutList()[1]
	local var_73_3 = arg_73_0:GetMainList()[1]

	if var_73_3 == nil or var_73_1 == 0 then
		var_73_0 = var_73_2
	elseif var_73_1 == 1 then
		var_73_0 = var_73_3
	end

	local var_73_4 = "battle"
	local var_73_5 = var_73_0:GetIntimacy()
	local var_73_6 = ys.Battle.BattleDataFunction.GetWords(var_73_0:GetSkinID(), var_73_4, var_73_5)

	var_73_0:DispatchVoice(var_73_4)
	var_73_0:DispatchChat(var_73_6, 2.5, var_73_4)
end

-- TODO: 计算舰队总战力，并设置到每个unit的fleetGS属性中（用于一些武器的伤害计算）
function BattleFleetVO.FleetUnitSpwanFinish(self)
	local gearScore = 0

	for _, unit in ipairs(self._unitList) do
		gearScore = gearScore + unit:GetGearScore()
	end
	-- 设置舰队总战力，在一些计算中会用到
	for _, unit in ipairs(self._unitList) do
		BattleAttr.SetCurrent(unit, "fleetGS", gearScore)
	end
end

function BattleFleetVO.SubWarcry(arg_75_0)
	local var_75_0 = arg_75_0:GetSubList()[1]
	local var_75_1 = "battle"
	local var_75_2 = var_75_0:GetIntimacy()
	local var_75_3 = ys.Battle.BattleDataFunction.GetWords(var_75_0:GetSkinID(), var_75_1, var_75_2)

	var_75_0:DispatchVoice(var_75_1)
	var_75_0:DispatchChat(var_75_3, 2.5, var_75_1)
end

function BattleFleetVO.SetWeaponBlock(arg_76_0, arg_76_1)
	arg_76_0._blockCast = arg_76_0._blockCast + arg_76_1
end

function BattleFleetVO.GetWeaponBlock(arg_77_0)
	return arg_77_0._blockCast > 0
end

-- 作为按下跨射按钮时的回调(不放开)
function BattleFleetVO.CastChargeWeapon(self)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()
	-- 需要是READY状态才可以进入处理逻辑
	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		-- BattlePointHitWeaponUnit/BattlePointAirStrikeUnit
		-- 主要是让武器进入PRECAST状态
		currentWeapon:Charge()

		local chargeArgs = {}
		local chargeEvent = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CHARGE, chargeArgs)

		self:DispatchEvent(chargeEvent)
	end
end

-- 作为松开跨射按钮时的回调
function BattleFleetVO.CancelChargeWeapon(self)
	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()
	-- 得是PRECAST状态才可以取消(这个判断逻辑有点太狭隘，有可能产生BUG)
	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		local cancelArgs = {}
		local cancelEvent = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CANCEL, cancelArgs)

		self:DispatchEvent(cancelEvent)
		-- 清空lockList，并将状态重置为READY
		currentWeapon:CancelCharge()
	end
end

-- 释放跨射武器逻辑
-- 作为按下并松开跨射按钮时的回调
function BattleFleetVO.UnleashChrageWeapon(self)
	if self:GetWeaponBlock() then
		self:CancelChargeWeapon()

		return
	end

	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		if currentWeapon:IsStrikeMode() then
			-- SIGHT_C = 38
			-- 也就是瞄准点在舰队前方38个单位处
			local targetPointX = self._motionVO:GetPos().x + BattleConfig.ChargeWeaponConfig.SIGHT_C
			local actualTargetPointX = math.min(targetPointX, self._totalRightBound)

			self:fireChargeWeapon(currentWeapon, true, Vector3.New(actualTargetPointX, 0, self._motionVO:GetPos().z))
		else
			currentWeapon:CancelCharge()
		end

		local hitCancelArgs = {}
		local hitCancelEvent = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CANCEL, hitCancelArgs)

		self:DispatchEvent(hitCancelEvent)
	end
end

-- 被BattleManualWeaponAutoBot.Update调用
-- 即每帧都尝试自动释放
function BattleFleetVO.QuickTagChrageWeapon(self, isPlayFocus)
	if self:GetWeaponBlock() then
		return
	end

	local success
	local weapon = self._chargeWeaponVO:GetCurrentWeapon()

	if weapon ~= nil and weapon:GetCurrentState() == weapon.STATE_READY then
		weapon:QuickTag()
		-- 若场上无可选目标，则取消瞄准状态
		if #weapon:GetLockList() <= 0 then
			weapon:CancelQuickTag()
		else
			-- 这个函数没有返回值，不知道要干嘛...
			success = self:fireChargeWeapon(weapon, isPlayFocus)
		end
	end

	return success
end

function BattleFleetVO.fireChargeWeapon(self, weapon, isPlayFocus, targetPos)
	local host = weapon:GetHost()

	local function afterFocusFunc()
		local function chargeWeaponFinishCallback()
			weapon:Fire(targetPos)
		end

		weapon:DispatchBlink(chargeWeaponFinishCallback)
	end

	if weapon:GetType() == BattleConst.EquipmentType.POINT_AIR_STRIKE then
		weapon:Fire(targetPos)
	-- isPlayFocus指的是是否需要播放聚焦动画，只有后排的战列跨射才需要
	elseif isPlayFocus then
		if self._IFF == BattleConfig.FRIENDLY_CODE then
			self._chargeWeaponVO:PlayCutIn(host, 1 / BattleConfig.FOCUS_MAP_RATE)
		end

		self._chargeWeaponVO:PlayFocus(host, afterFocusFunc)
	else
		-- 否则是直接切入立绘，没有切换镜头的聚焦动画
		if self._IFF == BattleConfig.FRIENDLY_CODE then
			self._chargeWeaponVO:PlayCutIn(host, 1)
		end

		afterFocusFunc()
	end
end

-- 作为按下并松开空袭按钮时的回调
function BattleFleetVO.UnleashAllInStrike(self)
	if self:GetWeaponBlock() then
		return
	end

	local success
	local currentWeapon = self._airAssistVO:GetCurrentWeapon()

	if currentWeapon and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		local host = currentWeapon:GetHost()

		if self._IFF == BattleConfig.FRIENDLY_CODE and host:IsMainFleetUnit() then
			self._airAssistVO:PlayCutIn(host, 1)
		end
		-- 消弹逻辑
		currentWeapon:CLSBullet()
		currentWeapon:DispatchBlink()
		-- 对应BattleAllInStrike.Fire
		success = currentWeapon:Fire()
	end

	return success
end

-- 按住鱼雷发射按钮
-- 作为BattleSkillView中, torpedoButton的按下回调(不包括松开)
function BattleFleetVO.CastTorpedo(self)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY and currentWeapon:Prepar() then
		self:FleetBuffTrigger(BattleConst.BuffEffectType.ON_TORPEDO_BUTTON_PUSH)
	end
end

-- 取消鱼雷发射
-- 作为松开鱼雷发射按钮的回调
function BattleFleetVO.CancelTorpedo(self)
	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		currentWeapon:Cancel()
	end
end

-- 释放鱼雷
-- 作为按下并松开鱼雷发射按钮时的回调
function BattleFleetVO.UnleashTorpedo(self)
	if self:GetWeaponBlock() then
		self:CancelTorpedo()

		return
	end

	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		currentWeapon:Fire()
	end
end

-- 自律发射鱼雷
function BattleFleetVO.QuickCastTorpedo(self)
	if self:GetWeaponBlock() then
		return
	end

	local success
	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		success = currentWeapon:Fire(true)
	end

	return success
end

function BattleFleetVO.RemoveManunalTorpedo(arg_90_0, arg_90_1, arg_90_2)
	if arg_90_1:IsAttacking() then
		arg_90_0:CancelTorpedo()
	end

	arg_90_0._torpedoWeaponVO:RemoveWeapon(arg_90_1)

	if not arg_90_2 then
		arg_90_1:Clear()
	end
end

function BattleFleetVO.CoupleEncourage(arg_91_0)
	local var_91_0 = {}
	local var_91_1 = {}

	for iter_91_0, iter_91_1 in ipairs(arg_91_0._unitList) do
		local var_91_2 = iter_91_1:GetIntimacy()
		local var_91_3 = BattleDataFunction.GetWords(iter_91_1:GetSkinID(), "couple_encourage", var_91_2)

		if #var_91_3 > 0 then
			var_91_0[iter_91_1] = var_91_3
		end
	end

	local var_91_4 = BattleConst.CPChatType
	local var_91_5 = BattleConst.CPChatTargetFunc

	local function var_91_6(arg_92_0, arg_92_1)
		local var_92_0 = {}

		if arg_92_0 == var_91_4.GROUP_ID then
			var_92_0.groupIDList = arg_92_1
		elseif arg_92_0 == var_91_4.SHIP_TYPE then
			var_92_0.ship_type_list = arg_92_1
		elseif arg_92_0 == var_91_4.RARE then
			var_92_0.rarity = arg_92_1[1]
		elseif arg_92_0 == var_91_4.NATIONALITY then
			var_92_0.nationality = arg_92_1[1]
		elseif arg_92_0 == var_91_4.ILLUSTRATOR then
			var_92_0.illustrator = arg_92_1[1]
		elseif arg_92_0 == var_91_4.TEAM then
			var_92_0.teamIndex = arg_92_1[1]
		end

		return var_92_0
	end

	for iter_91_2, iter_91_3 in pairs(var_91_0) do
		for iter_91_4, iter_91_5 in ipairs(iter_91_3) do
			local var_91_7 = iter_91_5[1]
			local var_91_8 = iter_91_5[2]
			local var_91_9 = iter_91_5[4] or var_91_4.GROUP_ID
			local var_91_10 = ys.Battle.BattleTargetChoise.TargetAllHelp(iter_91_2)

			if type(var_91_9) == "table" then
				for iter_91_6, iter_91_7 in ipairs(var_91_9) do
					local var_91_11 = var_91_6(iter_91_7, var_91_7[iter_91_6])

					var_91_10 = ys.Battle.BattleTargetChoise[var_91_5[iter_91_7]](iter_91_2, var_91_11, var_91_10)
				end
			elseif type(var_91_9) == "number" then
				local var_91_12 = var_91_6(var_91_9, var_91_7)

				var_91_10 = ys.Battle.BattleTargetChoise[var_91_5[var_91_9]](iter_91_2, var_91_12, var_91_10)
			end

			if var_91_8 <= #var_91_10 then
				local var_91_13 = {
					cp = iter_91_2,
					content = iter_91_5[3],
					linkIndex = iter_91_4
				}

				var_91_1[#var_91_1 + 1] = var_91_13
			end
		end
	end

	if #var_91_1 > 0 then
		local var_91_14 = var_91_1[math.random(#var_91_1)]
		local var_91_15 = "link" .. var_91_14.linkIndex

		var_91_14.cp:DispatchVoice(var_91_15)
		var_91_14.cp:DispatchChat(var_91_14.content, 3, var_91_15)
	end
end

function BattleFleetVO.onUnitUpdateHP(arg_93_0, arg_93_1)
	local var_93_0 = arg_93_1.Dispatcher
	local var_93_1 = arg_93_1.Data.dHP

	for iter_93_0, iter_93_1 in ipairs(arg_93_0._unitList) do
		iter_93_1:TriggerBuff(BattleConst.BuffEffectType.ON_FRIENDLY_HP_RATIO_UPDATE, {
			unit = var_93_0,
			dHP = var_93_1
		})

		if iter_93_1 ~= var_93_0 then
			iter_93_1:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_HP_RATIO_UPDATE, {
				unit = var_93_0,
				dHP = var_93_1
			})
		end
	end
end

function BattleFleetVO.onUnitCloakUpdate(arg_94_0, arg_94_1)
	local var_94_0 = arg_94_1.Dispatcher
	local var_94_1 = BattleAttr.GetCurrent(var_94_0, "isCloak")

	for iter_94_0, iter_94_1 in ipairs(arg_94_0._unitList) do
		iter_94_1:TriggerBuff(BattleConst.BuffEffectType.ON_CLOAK_UPDATE, {
			cloakState = var_94_1
		})

		if iter_94_1 ~= var_94_0 then
			iter_94_1:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_CLOAK_UPDATE, {
				cloakState = var_94_1
			})
		end
	end
end

function BattleFleetVO.SetSubUnitData(arg_95_0, arg_95_1)
	arg_95_0._subUntiDataList = arg_95_1
end

function BattleFleetVO.GetSubUnitData(arg_96_0)
	return arg_96_0._subUntiDataList
end

-- TODO
-- 添加潜艇单位函数
-- 被BattleDataProxy.SpawnSub调用
-- template数据来自BattleDataFunction.GeneratePlayerSubmarinPhase
function BattleFleetVO.AddSubMarine(self, subUnit)
	subUnit:InitOxygen()

	local subTemplate = subUnit:GetTemplate()
	local subPhaseSwitcher = ys.Battle.BattleUnitPhaseSwitcher.New(subUnit)

	local function raidDuration()
		return subUnit:GetRaidDuration()
	end
	-- 攻击和撤退基准线的计算：BattleFleetVO.CalcSubmarineBaseLine
	local subAttackBaseLine = self._fixedSubRefLine or self._subAttackBaseLine
	-- raidDist来自舰船属性，又来自模板数据的raid_distance
	-- 因为在GeneratePlayerSubmarinPhase中的处理方式，实际上如果是负数raidDist则为基准线更向前，正数则更向后
	subPhaseSwitcher:SetTemplateData(BattleDataFunction.GeneratePlayerSubmarinPhase(subAttackBaseLine, self._subRetreatBaseLine, subUnit:GetAttrByName("raidDist"), raidDuration, subUnit:GetAttrByName("oxyAtkDuration")))

	self._unitList[#self._unitList + 1] = subUnit
	self._subList[#self._subList + 1] = subUnit

	subUnit:SetFleetVO(self)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_STATE, self.onUnitCloakUpdate)
end

function BattleFleetVO.AddManualSubmarine(arg_99_0, arg_99_1)
	arg_99_0._unitList[#arg_99_0._unitList + 1] = arg_99_1
	arg_99_0._manualSubList[#arg_99_0._manualSubList + 1] = arg_99_1
	arg_99_0._manualSubBench[#arg_99_0._manualSubBench + 1] = arg_99_1
	arg_99_0._maxCount = arg_99_0._maxCount + 1

	arg_99_1:InitOxygen()
	arg_99_1:SetFleetVO(arg_99_0)
	arg_99_1:SetMotion(arg_99_0._motionVO)
	arg_99_1:RegisterEventListener(arg_99_0, BattleUnitEvent.UPDATE_HP, arg_99_0.onUnitUpdateHP)
	arg_99_1:RegisterEventListener(arg_99_0, BattleUnitEvent.UPDATE_CLOAK_STATE, arg_99_0.onUnitCloakUpdate)
end

function BattleFleetVO.GetSubList(arg_100_0)
	return arg_100_0._subList
end

function BattleFleetVO.ShiftManualSub(arg_101_0)
	local var_101_0

	if arg_101_0._manualSubUnit then
		local var_101_1 = arg_101_0._manualSubUnit:GetTorpedoList()

		for iter_101_0, iter_101_1 in ipairs(var_101_1) do
			if iter_101_1:IsAttacking() then
				arg_101_0:CancelTorpedo()
			end

			arg_101_0._torpedoWeaponVO:RemoveWeapon(iter_101_1)
		end

		if arg_101_0._manualSubUnit:IsAlive() then
			table.insert(arg_101_0._manualSubBench, arg_101_0._manualSubUnit)
		end

		var_101_0 = arg_101_0._motionVO:GetPos():Clone()
	else
		var_101_0 = arg_101_0._manualSubList[1]:GetPosition():Clone()
	end

	arg_101_0._manualSubUnit = table.remove(arg_101_0._manualSubBench, 1)
	arg_101_0._scoutList[1] = arg_101_0._manualSubUnit

	local var_101_2 = {}

	for iter_101_2, iter_101_3 in ipairs(arg_101_0._manualSubBench) do
		for iter_101_4, iter_101_5 in ipairs(arg_101_0._unitList) do
			if iter_101_5 == iter_101_3 then
				table.insert(var_101_2, iter_101_4)

				break
			end
		end
	end

	for iter_101_6, iter_101_7 in ipairs(arg_101_0._unitList) do
		if iter_101_7 == arg_101_0._manualSubUnit then
			table.insert(var_101_2, 1, iter_101_6)

			break
		end
	end

	arg_101_0:refreshFleetFormation(var_101_2)
	arg_101_0._manualSubUnit:SetMainUnitStatic(false)
	arg_101_0._manualSubUnit:SetPosition(var_101_0)
	arg_101_0:UpdateMotion()
	arg_101_0._submarineSpecialVO:SetUseable(false)

	local var_101_3 = arg_101_0._manualSubUnit:GetBuffList()

	for iter_101_8, iter_101_9 in pairs(var_101_3) do
		if iter_101_9:IsSubmarineSpecial() then
			arg_101_0._submarineSpecialVO:SetCount(1)
			arg_101_0._submarineSpecialVO:SetUseable(true)

			break
		end
	end

	arg_101_0:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE)
	arg_101_0._torpedoWeaponVO:Reset()

	local var_101_4 = arg_101_0._manualSubUnit:GetTorpedoList()

	for iter_101_10, iter_101_11 in ipairs(var_101_4) do
		if iter_101_11:GetCurrentState() ~= iter_101_11.STATE_OVER_HEAT then
			arg_101_0._torpedoWeaponVO:AppendWeapon(iter_101_11)
		end
	end

	for iter_101_12, iter_101_13 in ipairs(var_101_4) do
		if iter_101_13:GetCurrentState() == iter_101_13.STATE_OVER_HEAT then
			arg_101_0._torpedoWeaponVO:AppendWeapon(iter_101_13)
		end
	end

	if BattleAttr.GetCurrent(arg_101_0._manualSubUnit, "oxyMax") <= 0 then
		arg_101_0._submarineDiveVO:SetActive(false)
		arg_101_0._submarineFloatVO:SetActive(false)
	else
		arg_101_0._submarineDiveVO:SetActive(true)
		arg_101_0._submarineFloatVO:SetActive(true)
	end

	for iter_101_14, iter_101_15 in ipairs(arg_101_0._manualSubBench) do
		iter_101_15:SetPosition(BattleConfig.SUB_BENCH_POS[iter_101_14])
		iter_101_15:SetMainUnitStatic(true)
		iter_101_15:ChangeOxygenState(ys.Battle.OxyState.STATE_FREE_BENCH)
	end

	arg_101_0._submarineShiftVO:ResetCurrent()

	if #arg_101_0._manualSubBench == 0 then
		arg_101_0._submarineShiftVO:SetActive(false)
	end
end

function BattleFleetVO.ChangeSubmarineState(arg_102_0, arg_102_1, arg_102_2)
	if not arg_102_0._manualSubUnit then
		return
	end

	arg_102_0._manualSubUnit:ChangeOxygenState(arg_102_1)

	if arg_102_2 then
		for iter_102_0, iter_102_1 in ipairs(arg_102_0._submarineVOList) do
			iter_102_1:ResetCurrent()
		end

		local var_102_0 = arg_102_0._submarineShiftVO:GetMax() - arg_102_0._submarineShiftVO:GetCurrent()

		if arg_102_0._submarineShiftVO:IsOverLoad() and var_102_0 > BattleConfig.SR_CONFIG.DIVE_CD then
			-- block empty
		else
			arg_102_0._submarineShiftVO:SetMax(BattleConfig.SR_CONFIG.DIVE_CD)
			arg_102_0._submarineShiftVO:ResetCurrent()
		end
	end

	arg_102_0:DispatchEvent(ys.Event.New(BattleEvent.MANUAL_SUBMARINE_SHIFT, {
		state = arg_102_1
	}))
end

function BattleFleetVO.SubmarinBoost(arg_103_0)
	arg_103_0._manualSubUnit:Boost(Vector3.right, BattleConfig.SR_CONFIG.BOOST_SPEED, BattleConfig.SR_CONFIG.BOOST_DECAY, BattleConfig.SR_CONFIG.BOOST_DURATION, BattleConfig.SR_CONFIG.BOOST_DECAY_STAMP)
	arg_103_0._submarineBoostVO:ResetCurrent()
end

function BattleFleetVO.UnleashSubmarineSpecial(arg_104_0)
	if arg_104_0:GetWeaponBlock() then
		return
	end

	arg_104_0._submarineSpecialVO:Cast()
	arg_104_0._manualSubUnit:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FREE_SPECIAL)
end

function BattleFleetVO.FixSubRefLine(arg_105_0, arg_105_1)
	arg_105_0._fixedSubRefLine = arg_105_1
end

function var_0_8.AppendIndieSonar(arg_106_0, arg_106_1, arg_106_2)
	if not arg_106_0._motionReferenceUnit then
		return
	end

	local var_106_0 = ys.Battle.BattleIndieSonar.New(arg_106_0, arg_106_1, arg_106_2)

	var_106_0:SwitchHost(arg_106_0._motionReferenceUnit)

	arg_106_0._indieSonarList[var_106_0] = true

	var_106_0:Detect()
end

function BattleFleetVO.RemoveIndieSonar(arg_107_0, arg_107_1)
	for iter_107_0, iter_107_1 in pairs(arg_107_0._indieSonarList) do
		if arg_107_1 == iter_107_0 then
			arg_107_0._indieSonarList[iter_107_0] = nil

			break
		end
	end
end

function BattleFleetVO.AttachFleetBuff(arg_108_0, arg_108_1)
	local var_108_0 = arg_108_1:GetID()
	local var_108_1 = arg_108_0:GetFleetBuff(var_108_0)

	if var_108_1 then
		var_108_1:Stack(arg_108_0)
	else
		arg_108_0._buffList[var_108_0] = arg_108_1

		arg_108_1:Attach(arg_108_0)
	end
end

function BattleFleetVO.RemoveFleetBuff(arg_109_0, arg_109_1)
	local var_109_0 = arg_109_0:GetFleetBuff(arg_109_1)

	if var_109_0 then
		var_109_0:Remove()
	end
end

function BattleFleetVO.GetFleetBuff(arg_110_0, arg_110_1)
	return arg_110_0._buffList[arg_110_1]
end

function BattleFleetVO.GetFleetBuffList(arg_111_0)
	return arg_111_0._buffList
end

function BattleFleetVO.AttachFleetAttr(arg_112_0)
	arg_112_0._fleetAttr = ys.Battle.BattleFleetAttrComponent.New(arg_112_0)
end

function BattleFleetVO.GetFleetAttr(arg_113_0)
	return arg_113_0._fleetAttr
end

function BattleFleetVO.Jamming(arg_114_0, arg_114_1)
	if arg_114_1 then
		arg_114_0._chargeWeaponVO:StartJamming()
		arg_114_0._torpedoWeaponVO:StartJamming()
		arg_114_0._airAssistVO:StartJamming()
	else
		arg_114_0._chargeWeaponVO:JammingEliminate()
		arg_114_0._torpedoWeaponVO:JammingEliminate()
		arg_114_0._airAssistVO:JammingEliminate()
	end
end

function BattleFleetVO.Blinding(arg_115_0, arg_115_1)
	arg_115_0:DispatchEvent(ys.Event.New(BattleEvent.FLEET_BLIND, {
		isBlind = arg_115_1
	}))
end

function BattleFleetVO.UpdateHorizon(arg_116_0)
	arg_116_0:DispatchEvent(ys.Event.New(BattleEvent.FLEET_HORIZON_UPDATE, {}))
end

-- 对应触发ON_AUTOBOT和ON_MANUAL的buffEffect
function BattleFleetVO.AutoBotUpdated(self, isAutoBotActive)
	local effectType = isAutoBotActive and BattleConst.BuffEffectType.ON_AUTOBOT or BattleConst.BuffEffectType.ON_MANUAL

	self:FleetBuffTrigger(effectType)
end

function BattleFleetVO.CloakFatalExpose(arg_118_0)
	for iter_118_0, iter_118_1 in ipairs(arg_118_0._cloakList) do
		iter_118_1:GetCloak():ForceToMax()
	end
end

function BattleFleetVO.CloakInVision(arg_119_0, arg_119_1)
	for iter_119_0, iter_119_1 in ipairs(arg_119_0._cloakList) do
		iter_119_1:GetCloak():AppendExposeSpeed(arg_119_1)
	end
end

function BattleFleetVO.CloakOutVision(arg_120_0)
	for iter_120_0, iter_120_1 in ipairs(arg_120_0._cloakList) do
		iter_120_1:GetCloak():AppendExposeSpeed(0)
	end
end

function BattleFleetVO.AttachCloak(arg_121_0, arg_121_1)
	if not arg_121_1:GetCloak() then
		arg_121_1:InitCloak()

		arg_121_0._cloakList[#arg_121_0._cloakList + 1] = arg_121_1
	end
end

function BattleFleetVO.AttachNightCloak(arg_122_0)
	arg_122_0._scoutAimBias = ys.Battle.BattleUnitAimBiasComponent.New()

	arg_122_0._scoutAimBias:ConfigRangeFormula(BattleFormulas.CalculateMaxAimBiasRange, BattleFormulas.CalculateBiasDecay)
	arg_122_0._scoutAimBias:Active(arg_122_0._scoutAimBias.STATE_ACTIVITING)
	arg_122_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIM_BIAS, {
		aimBias = arg_122_0._scoutAimBias
	}))
end

function BattleFleetVO.GetFleetBias(arg_123_0)
	return arg_123_0._scoutAimBias
end

function BattleFleetVO.FreezeUnit(arg_124_0, arg_124_1)
	arg_124_0:RemovePlayerUnit(arg_124_1, true)

	arg_124_0._freezeList[arg_124_1] = true
end

function BattleFleetVO.ActiveFreezeUnit(arg_125_0, arg_125_1)
	arg_125_0._freezeList[arg_125_1] = nil
	arg_125_0._unitList[#arg_125_0._unitList + 1] = arg_125_1
	arg_125_0._maxCount = arg_125_0._maxCount + 1

	if arg_125_1:IsMainFleetUnit() then
		arg_125_0:appendFreezeMainUnit(arg_125_1)
	else
		arg_125_0:activeFreezeScoutUnit(arg_125_1)
	end

	arg_125_1:SetFleetVO(arg_125_0)
	arg_125_1:SetMotion(arg_125_0._motionVO)
	arg_125_1:RegisterEventListener(arg_125_0, BattleUnitEvent.UPDATE_HP, arg_125_0.onUnitUpdateHP)
	arg_125_1:RegisterEventListener(arg_125_0, BattleUnitEvent.UPDATE_CLOAK_STATE, arg_125_0.onUnitCloakUpdate)
end

function BattleFleetVO.UndoFusion(arg_126_0)
	for iter_126_0, iter_126_1 in pairs(arg_126_0._freezeList) do
		arg_126_0._unitList[#arg_126_0._unitList + 1] = iter_126_0
		arg_126_0._maxCount = arg_126_0._maxCount + 1

		if iter_126_0:IsMainFleetUnit() then
			arg_126_0:appendFreezeMainUnit(iter_126_0)
		else
			arg_126_0:activeFreezeScoutUnit(iter_126_0)
		end
	end

	local var_126_0 = {}

	for iter_126_2, iter_126_3 in ipairs(arg_126_0._unitList) do
		local var_126_1 = iter_126_3:GetAttrByName("hpProvideRate")

		if var_126_1 ~= 0 then
			table.insert(var_126_0, iter_126_3)

			local var_126_2, var_126_3 = iter_126_3:GetHP()
			local var_126_4 = var_126_3 - var_126_2
			local var_126_5 = 0

			for iter_126_4, iter_126_5 in pairs(var_126_1) do
				local var_126_6 = arg_126_0:GetFreezeShipByID(iter_126_4)

				if not var_126_6 then
					arg_126_0:GetShipByID(iter_126_4)
				end

				local var_126_7 = math.floor(iter_126_5 * var_126_4)

				var_126_6:UpdateHP(var_126_7 * -1, {})
			end
		end
	end

	for iter_126_6, iter_126_7 in ipairs(var_126_0) do
		arg_126_0:RemovePlayerUnit(iter_126_7)
	end
end

function BattleFleetVO.appendFreezeMainUnit(arg_127_0, arg_127_1)
	arg_127_0._mainList[#arg_127_0._mainList + 1] = arg_127_1

	arg_127_1:SetMainUnitIndex(#arg_127_0._mainList)

	if ShipType.CloakShipType(arg_127_1:GetTemplate().type) then
		table.insert(arg_127_0._cloakList, arg_127_1)
	end

	local var_127_0 = arg_127_1:GetChargeList()

	for iter_127_0, iter_127_1 in ipairs(var_127_0) do
		arg_127_0._chargeWeaponVO:AppendFreezeWeapon(iter_127_1)
	end

	local var_127_1 = arg_127_1:GetTorpedoList()

	for iter_127_2, iter_127_3 in ipairs(var_127_1) do
		arg_127_0._torpedoWeaponVO:AppendFreezeWeapon(iter_127_3)
	end

	if arg_127_1:GetAirAssistList() then
		local var_127_2 = arg_127_1:GetAirAssistList()

		for iter_127_4, iter_127_5 in ipairs(var_127_2) do
			arg_127_0._airAssistVO:AppendFreezeWeapon(iter_127_5)
		end
	end

	arg_127_0._fleetAntiAir:AppendCrewUnit(arg_127_1)
	arg_127_0._fleetRangeAntiAir:AppendCrewUnit(arg_127_1)
	arg_127_0._fleetStaticSonar:AppendCrewUnit(arg_127_1)

	local var_127_3 = {}

	for iter_127_6, iter_127_7 in ipairs(arg_127_0._unitList) do
		table.insert(var_127_3, iter_127_6)
	end

	arg_127_0:refreshFleetFormation(var_127_3)
end

function BattleFleetVO.activeFreezeScoutUnit(arg_128_0, arg_128_1)
	arg_128_0._scoutList[#arg_128_0._scoutList + 1] = arg_128_1

	local var_128_0 = arg_128_1:GetTorpedoList()

	for iter_128_0, iter_128_1 in ipairs(var_128_0) do
		arg_128_0._torpedoWeaponVO:AppendFreezeWeapon(iter_128_1)
	end

	if arg_128_1:GetAirAssistList() then
		local var_128_1 = arg_128_1:GetAirAssistList()

		for iter_128_2, iter_128_3 in ipairs(var_128_1) do
			arg_128_0._airAssistVO:AppendFreezeWeapon(iter_128_3)
		end
	end

	arg_128_0._fleetAntiAir:AppendCrewUnit(arg_128_1)
	arg_128_0._fleetStaticSonar:AppendCrewUnit(arg_128_1)

	local var_128_2 = 1
	local var_128_3 = #arg_128_0._unitList
	local var_128_4 = {}

	while var_128_2 < var_128_3 do
		table.insert(var_128_4, var_128_2)

		var_128_2 = var_128_2 + 1
	end

	table.insert(var_128_4, #arg_128_0._scoutList, var_128_2)
	arg_128_0:refreshFleetFormation(var_128_4)
end

function BattleFleetVO.AttachCardPuzzleComponent(arg_129_0)
	arg_129_0._cardPuzzleComponent = ys.Battle.BattleFleetCardPuzzleComponent.New(arg_129_0)

	return arg_129_0._cardPuzzleComponent
end

function BattleFleetVO.GetCardPuzzleComponent(arg_130_0)
	return arg_130_0._cardPuzzleComponent
end

function BattleFleetVO.AppendSupportUnit(arg_131_0, arg_131_1)
	arg_131_0._supportList[#arg_131_0._supportList + 1] = arg_131_1
end

function BattleFleetVO.GetSupportUnitList(arg_132_0)
	return arg_132_0._supportList
end
