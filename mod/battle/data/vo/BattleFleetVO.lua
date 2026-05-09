ys = ys or {}

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

--- @class BattleFleetVO
--- 舰队值对象，管理舰队所有单位、武器VO、阵型、Buff等

--- 构造函数
--- @param IFF number 敌我识别码
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

--- 更新舰队Buff
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

--- 更新舰队受到的伤害
--- @param damage table 伤害数据
function BattleFleetVO.UpdateFleetDamage(self, damage)
	local fleetDamageRatio = BattleFormulas.CalculateFleetDamage(damage)

	self._currentDMGRatio = self._currentDMGRatio + fleetDamageRatio

	self:DispatchFleetDamageChange()
end

--- 更新舰队过量伤害（取消失效的伤害）
--- @param ship BattleUnit 造成的伤害所属的舰船
function BattleFleetVO.UpdateFleetOverDamage(self, ship)
	local fleetDamageRatio = BattleFormulas.CalculateFleetOverDamage(self, ship)

	self._currentDMGRatio = self._currentDMGRatio - fleetDamageRatio

	self:DispatchFleetDamageChange()
end

--- 分发舰队伤害变更事件
function BattleFleetVO.DispatchFleetDamageChange(self)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_DMG_CHANGE, {}))
end

--- 分发声呐扫描事件
--- @param indieSonar BattleIndieSonar 独立声呐对象
function BattleFleetVO.DispatchSonarScan(self, indieSonar)
	self:DispatchEvent(ys.Event.New(BattleEvent.SONAR_SCAN, {
		indieSonar = indieSonar
	}))
end

--- 触发舰队所有单位的Buff
--- @param effectType number BuffEffectType
--- @param arg_list table Buff参数
function BattleFleetVO.FleetBuffTrigger(self, effectType, arg_list)
	for _, unit in ipairs(self._unitList) do
		unit:TriggerBuff(effectType, arg_list)
	end
end

-- 模拟战使用(BattleSimulationCommand). 添加Buff 41(后排移动)
--- @param buffID number Buff ID
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
--- @param attrList table 需要过滤的属性名列表（如immuneDirectHit）
--- @return BattleUnit|nil 选中的受害单位
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
--- @param pos Vector3 参考位置
--- @param shipTypeList table 需要匹配的舰船类型列表
--- @return BattleUnit|nil 最近的单位
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

--- 设置舰队移动速度来源函数
--- @param motionSource function|nil 移动来源函数（nil则使用默认UI输入）
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

--- 设置潜艇支援数据
--- @param totalCount number 总可用次数
--- @param currentCount number 当前可用次数
function BattleFleetVO.SetSubAidData(self, totalCount, currentCount)
	self._submarineVO = ys.Battle.BattleSubmarineAidVO.New()

	if currentCount == BattleConst.SubAidFlag.AID_EMPTY or currentCount == BattleConst.SubAidFlag.OIL_EMPTY then
		self._submarineVO:SetUseable(false)
	else
		self._submarineVO:SetCount(currentCount)
		self._submarineVO:SetTotal(totalCount)
		self._submarineVO:SetUseable(true)
	end
end

--- 设置自律移动边界
--- @param upperBound number 上边界 Y
--- @param lowerBound number 下边界 Y
--- @param leftBound number 左边界 X
--- @param rightBound number 右边界 X
function BattleFleetVO.SetAutobotBound(self, upperBound, lowerBound, leftBound, rightBound)
	self._upperBound = upperBound
	self._lowerBound = lowerBound
	self._leftBound = leftBound
	self._rightBound = rightBound
end

--- 设置总边界（包括后排）
--- @param totalUpperBound number
--- @param totalLowerBound number
--- @param totalLeftBound number
--- @param totalRightBound number
function BattleFleetVO.SetTotalBound(self, totalUpperBound, totalLowerBound, totalLeftBound, totalRightBound)
	self._totalUpperBound = totalUpperBound
	self._totalLowerBound = totalLowerBound
	self._totalLeftBound = totalLeftBound
	self._totalRightBound = totalRightBound
end

--- 设置舰队单位边界组件
--- @param boundData1 any 边界配置数据1
--- @param boundData2 any 边界配置数据2
function BattleFleetVO.SetUnitBound(self, boundData1, boundData2)
	self._fleetUnitBound = ys.Battle.BattleFleetBound.New(self._IFF)

	self._fleetUnitBound:ConfigAreaData(boundData1, boundData2)
	self._fleetUnitBound:SwtichCommon()
end

--- 设置章节游戏类型
--- @param playType number 章节类型
function BattleFleetVO.SetChapterPlayType(self, playType)
	self._chapterType = playType
end

--- 获取左边界距离（仅chapterType == 5时有效）
--- @return number|nil
function BattleFleetVO.GetLeftBoundDistance(self)
	if self._chapterType and self._chapterType == 5 then
		return math.abs(self._motionVO:GetPos().x - self._leftBound)
	end
end

--- 更新前排单位边界
--- 将从fleetUnitBound获取的边界值设置到每个前排单位和冻结的非主力单位
function BattleFleetVO.UpdateScoutUnitBound(self)
	local upperBound, lowerBound, leftBound, rightBound, extraBound1, extraBound2 = self._fleetUnitBound:GetBound()

	for _, scout in ipairs(self._scoutList) do
		scout:SetBound(upperBound, lowerBound, leftBound, rightBound, extraBound1, extraBound2)
	end

	for unit, _ in pairs(self._freezeList) do
		if not unit:IsMainFleetUnit() then
			unit:SetBound(upperBound, lowerBound, leftBound, rightBound, extraBound1, extraBound2)
		end
	end
end

-- note: 计算潜艇攻击和撤退基准线
--- @param battleType number 战斗类型
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

--- 设置暴露线
--- @param visionLineX number 视野线X坐标
--- @param exposeLineX number 暴露线X坐标
function BattleFleetVO.SetExposeLine(self, visionLineX, exposeLineX)
	self._visionLineX = visionLineX
	self._exposeLineX = exposeLineX
end

--- @class BattleFleetVO
--- @param unit BattleUnit
--- @return nil
--- BattleDataProxy.SpawnVanguard/BattleDataProxy.SpawnMain调用
--- 将单位添加到舰队中
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
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_STATE, self.onUnitCloakUpdate)

	if self._cardPuzzleComponent then
		self._cardPuzzleComponent:AppendUnit(unit)
	end
end

--- 从舰队中移除单位
--- @param unit BattleUnit 要移除的单位
--- @param isFreeze boolean 是否为冻结移除（true则不清理武器缓存）
function BattleFleetVO.RemovePlayerUnit(self, unit, isFreeze)
	self._freezeList[unit] = nil

	local currentUnitList = {}

	for _, listUnit in ipairs(self._unitList) do
		if listUnit ~= unit then
			currentUnitList[#currentUnitList + 1] = listUnit
		else
			if not isFreeze then
				listUnit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)
				listUnit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_STATE)
				listUnit:DeactiveCldBox()
			end

			local chargeList = listUnit:GetChargeList()

			for _, chargeWeapon in ipairs(chargeList) do
				if chargeWeapon:IsAttacking() then
					self._chargeWeaponVO:CancelFocus()
					self._chargeWeaponVO:ResetFocus()
					self:CancelChargeWeapon()
				end

				self._chargeWeaponVO:RemoveWeapon(chargeWeapon)

				if not isFreeze then
					chargeWeapon:Clear()
				end
			end

			self._fleetAntiAir:RemoveCrewUnit(unit)
			self._fleetRangeAntiAir:RemoveCrewUnit(unit)
			self._fleetStaticSonar:RemoveCrewUnit(unit)

			local torpedoList = listUnit:GetTorpedoList()

			for _, torpedo in ipairs(torpedoList) do
				self:RemoveManunalTorpedo(torpedo, isFreeze)
			end

			local airAssistList = listUnit:GetAirAssistList()

			if airAssistList then
				for _, airAssist in ipairs(airAssistList) do
					self._airAssistVO:RemoveWeapon(airAssist)
				end
			end
		end
	end

	for scoutIndex, scout in ipairs(self._scoutList) do
		if scout == unit then
			if #self._scoutList == 1 then
				self:CancelChargeWeapon()
			end

			table.remove(self._scoutList, scoutIndex)

			break
		end
	end

	--- 从指定列表中移除目标单位
	local function removeUnitFromList(targetList)
		for listIndex, listUnit in ipairs(targetList) do
			if listUnit == unit then
				table.remove(targetList, listIndex)

				break
			end
		end
	end

	removeUnitFromList(self._mainList)
	removeUnitFromList(self._cloakList)
	removeUnitFromList(self._subList)
	removeUnitFromList(self._manualSubList)

	if not self._manualSubUnit then
		self:refreshFleetFormation(currentUnitList)
	end
end

-- BattleSkillOverrideAutoPilot.DoDataEffect调用
--- @param aiID number AutoPilot AI ID
function BattleFleetVO.OverrideJoyStickAutoBot(self, aiID)
	self._autoBotAIID = aiID

	local overrideAutoBotEvent = ys.Event.New(ys.Battle.BattleEvent.OVERRIDE_AUTO_BOT)
	-- 接收者: BattleControllerWeaponCommand.onOverrideAutoBot
	self:DispatchEvent(overrideAutoBotEvent)
end

--- 快照当前舰队总耐久和当前耐久
function BattleFleetVO.SnapShot(self)
	self._totalDMGRatio = BattleFormulas.GetFleetTotalHP(self)
	self._currentDMGRatio = self._totalDMGRatio
end

--- 获取敌我识别码
--- @return number
function BattleFleetVO.GetIFF(self)
	return self._IFF
end

--- 获取最大单位数
--- @return number
function BattleFleetVO.GetMaxCount(self)
	return self._maxCount
end

--- 获取旗舰
--- @return BattleUnit|nil
function BattleFleetVO.GetFlagShip(self)
	return self._flagShip
end

--- 获取前排领舰（前排第一位）
--- @return BattleUnit|nil
function BattleFleetVO.GetLeaderShip(self)
	return self._scoutList[1]
end

--- 获取所有单位列表
--- @return table
function BattleFleetVO.GetUnitList(self)
	return self._unitList
end

--- 获取冻结单位列表
--- @return table
function BattleFleetVO.GetFreezeUnitList(self)
	return self._freezeList
end

--- 获取主力舰队列表（后排）
--- @return table
function BattleFleetVO.GetMainList(self)
	return self._mainList
end

--- 获取前锋列表（前排）
--- @return table
function BattleFleetVO.GetScoutList(self)
	return self._scoutList
end

--- 通过ID获取冻结的舰船
--- @param shipID number
--- @return BattleUnit|nil
function BattleFleetVO.GetFreezeShipByID(self, shipID)
	for unit, _ in pairs(self._freezeList) do
		if shipID == unit:GetAttrByName("id") then
			return unit
		end
	end
end

--- 通过ID获取舰船
--- @param shipID number
--- @return BattleUnit|nil
function BattleFleetVO.GetShipByID(self, shipID)
	for _, unit in ipairs(self._unitList) do
		if shipID == unit:GetAttrByName("id") then
			return unit
		end
	end
end

--- 获取隐蔽单位列表
--- @return table
function BattleFleetVO.GetCloakList(self)
	return self._cloakList
end

--- 获取手动潜艇待机区
--- @return table
function BattleFleetVO.GetSubBench(self)
	return self._manualSubBench
end

--- 获取舰队单位边界
--- @return BattleFleetBound
function BattleFleetVO.GetUnitBound(self)
	return self._fleetUnitBound
end

--- 获取舰队移动VO
--- @return BattleFleetMotionVO
function BattleFleetVO.GetMotion(self)
	return self._motionVO
end

--- 获取移动参考单位
--- @return BattleUnit|nil
function BattleFleetVO.GetMotionReferenceUnit(self)
	return self._motionReferenceUnit
end

--- 获取自律AI ID
--- @return number|nil
function BattleFleetVO.GetAutoBotAIID(self)
	return self._autoBotAIID
end

--- 获取跨射武器VO
--- @return BattleChargeWeaponVO
function BattleFleetVO.GetChargeWeaponVO(self)
	return self._chargeWeaponVO
end

--- 获取鱼雷武器VO
--- @return BattleTorpedoWeaponVO
function BattleFleetVO.GetTorpedoWeaponVO(self)
	return self._torpedoWeaponVO
end

--- 获取空袭支援VO
--- @return BattleAllInStrikeVO
function BattleFleetVO.GetAirAssistVO(self)
	return self._airAssistVO
end

--- 获取潜艇支援VO
--- @return BattleSubmarineAidVO
function BattleFleetVO.GetSubAidVO(self)
	return self._submarineVO
end

--- 获取潜艇自由下潜VO
--- @return BattleSubmarineFuncVO
function BattleFleetVO.GetSubFreeDiveVO(self)
	return self._submarineDiveVO
end

--- 获取潜艇自由上浮VO
--- @return BattleSubmarineFuncVO
function BattleFleetVO.GetSubFreeFloatVO(self)
	return self._submarineFloatVO
end

--- 获取潜艇加速VO
--- @return BattleSubmarineFuncVO
function BattleFleetVO.GetSubBoostVO(self)
	return self._submarineBoostVO
end

--- 获取潜艇特殊技能VO
--- @return BattleSubmarineAidVO
function BattleFleetVO.GetSubSpecialVO(self)
	return self._submarineSpecialVO
end

--- 获取潜艇切换VO
--- @return BattleSubmarineFuncVO
function BattleFleetVO.GetSubShiftVO(self)
	return self._submarineShiftVO
end

--- 获取近程防空炮
--- @return BattleFleetAntiAirUnit
function BattleFleetVO.GetFleetAntiAirWeapon(self)
	return self._fleetAntiAir
end

--- 获取远程防空炮
--- @return BattleFleetRangeAntiAirUnit
function BattleFleetVO.GetFleetRangeAntiAirWeapon(self)
	return self._fleetRangeAntiAir
end

--- 获取舰队速度
--- @return number
function BattleFleetVO.GetFleetVelocity(self)
	return BattleFormulas.GetFleetVelocity(self._scoutList)
end

--- 获取舰队四边界
--- @return number upperBound, number lowerBound, number leftBound, number rightBound
function BattleFleetVO.GetFleetBound(self)
	return self._upperBound, self._lowerBound, self._leftBound, self._rightBound
end

--- 获取舰队单位上下边界
--- @return number totalUpperBound, number totalLowerBound
function BattleFleetVO.GetFleetUnitBound(self)
	return self._totalUpperBound, self._totalLowerBound
end

--- 获取舰队暴露线X坐标
--- @return number
function BattleFleetVO.GetFleetExposeLine(self)
	return self._exposeLineX
end

--- 获取舰队视野线X坐标
--- @return number
function BattleFleetVO.GetFleetVisionLine(self)
	return self._visionLineX
end

-- 被RandomStrategy.generateTargetPoint调用
--- 获取领舰的AutoPilot偏好
--- @return any
function BattleFleetVO.GetLeaderPersonality(self)
	return self._motionReferenceUnit:GetAutoPilotPreference()
end

--- 获取伤害比例结果（用于UI显示）
--- @return string 格式化百分比, number 总耐久
function BattleFleetVO.GetDamageRatioResult(self)
	return string.format("%0.2f", self._currentDMGRatio / self._totalDMGRatio * 100), self._totalDMGRatio
end

--- 获取当前伤害比例
--- @return number
function BattleFleetVO.GetDamageRatio(self)
	return self._currentDMGRatio / self._totalDMGRatio
end

--- 获取潜艇基准线
--- @return number attackBaseLine, number retreatBaseLine
function BattleFleetVO.GetSubmarineBaseLine(self)
	return self._fixedSubRefLine or self._subAttackBaseLine, self._subRetreatBaseLine
end

--- 获取舰队静态声呐
--- @return BattleFleetStaticSonar
function BattleFleetVO.GetFleetSonar(self)
	return self._fleetStaticSonar
end

--- 销毁舰队VO
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

	self._fleetAttr:Dispose()

	self._fleetAttr = nil
	self._freezeList = nil
end

-- 刷新前排舰队阵型/位置的主逻辑, 重要
-- 在各种append/remove unit后调用
--- @param currentUnitList table 当前单位索引排序列表(用于重建_unitList顺序)
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

--- 初始化舰队所有VO和列表
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

-- 被BattleFleetVO.AppendPlayerUnit调用
--- 将单位添加到前排列表，并关联其鱼雷/空袭武器
--- @param unit BattleUnit
function BattleFleetVO.appendScoutUnit(self, unit)
	self._scoutList[#self._scoutList + 1] = unit

	local manualTorpedoList = unit:GetTorpedoList()

	for _, manualTorpedo in ipairs(manualTorpedoList) do
		self._torpedoWeaponVO:AppendWeapon(manualTorpedo)
	end

	if #unit:GetHiveList() > 0 then
		local airAssistList = BattleDataFunction.CreateAllInStrike(unit)

		for _, airAssist in ipairs(airAssistList) do
			self._airAssistVO:AppendWeapon(airAssist)
		end

		unit:SetAirAssistList(airAssistList)
	end

	self._fleetAntiAir:AppendCrewUnit(unit)
	self._fleetStaticSonar:AppendCrewUnit(unit)

	local posIndex = 1
	local unitListLength = #self._unitList
	local currentUnitList = {}

	while posIndex < unitListLength do
		table.insert(currentUnitList, posIndex)

		posIndex = posIndex + 1
	end
	-- 有点没看懂，相关逻辑待重看
	table.insert(currentUnitList, #self._scoutList, posIndex)
	self:refreshFleetFormation(currentUnitList)
end

-- 被BattleFleetVO.AppendPlayerUnit调用
--- 将单位添加到主力舰队（后排）列表
--- @param unit BattleUnit
function BattleFleetVO.appendMainUnit(self, unit)
	if #self._mainList == 0 then
		self._flagShip = unit
	end

	self._mainList[#self._mainList + 1] = unit

	unit:SetMainUnitIndex(#self._mainList)

	if ShipType.CloakShipType(unit:GetTemplate().type) then
		self:AttachCloak(unit)
	end

	local chargeList = unit:GetChargeList()

	for _, chargeWeapon in ipairs(chargeList) do
		self._chargeWeaponVO:AppendWeapon(chargeWeapon)
	end

	local manualTorpedoList = unit:GetTorpedoList()

	for _, manualTorpedo in ipairs(manualTorpedoList) do
		self._torpedoWeaponVO:AppendWeapon(manualTorpedo)
	end

	if #unit:GetHiveList() > 0 then
		-- 此处将Hive->Airassist
		local airAssistList = BattleDataFunction.CreateAllInStrike(unit)

		for _, airAssist in ipairs(airAssistList) do
			self._airAssistVO:AppendWeapon(airAssist)
		end

		unit:SetAirAssistList(airAssistList)
	end

	self._fleetAntiAir:AppendCrewUnit(unit)
	self._fleetRangeAntiAir:AppendCrewUnit(unit)
	self._fleetStaticSonar:AppendCrewUnit(unit)

	local currentUnitList = {}

	for _, _ in ipairs(self._unitList) do
		table.insert(currentUnitList, _)
	end

	self:refreshFleetFormation(currentUnitList)
end

--- 将单位添加到潜艇列表
--- @param unit BattleUnit
function BattleFleetVO.appendSubUnit(self, unit)
	self._subList[#self._subList + 1] = unit

	unit:SetMainUnitIndex(#self._subList)
end

-- 开场台词
-- 典型如被BattleSingleDungeonCommand.DoPrologue调用
function BattleFleetVO.FleetWarcry(self)
	local warCrier
	local randomChoice = math.random(0, 1)
	local leader = self:GetScoutList()[1]
	local flagShip = self:GetMainList()[1]

	if flagShip == nil or randomChoice == 0 then
		warCrier = leader
	elseif randomChoice == 1 then
		warCrier = flagShip
	end

	local voiceName = "battle"
	local intimacy = warCrier:GetIntimacy()
	local words = ys.Battle.BattleDataFunction.GetWords(warCrier:GetSkinID(), voiceName, intimacy)

	warCrier:DispatchVoice(voiceName)
	warCrier:DispatchChat(words, 2.5, voiceName)
end

-- 计算舰队总战力，并设置到每个unit的fleetGS属性中（用于一些武器的伤害计算）
-- 被BattleDataProxy.InitUserShipsData调用
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

-- 潜艇出场台词
function BattleFleetVO.SubWarcry(self)
	local subFlagShip = self:GetSubList()[1]
	local voiceName = "battle"
	local intimacy = subFlagShip:GetIntimacy()
	local words = ys.Battle.BattleDataFunction.GetWords(subFlagShip:GetSkinID(), voiceName, intimacy)

	subFlagShip:DispatchVoice(voiceName)
	subFlagShip:DispatchChat(words, 2.5, voiceName)
end

--- 设置武器禁用计数
--- @param value number 变化量（正数增加禁用层数，负数为减少）
function BattleFleetVO.SetWeaponBlock(self, value)
	self._blockCast = self._blockCast + value
end

--- 获取武器是否被禁用
--- @return boolean
function BattleFleetVO.GetWeaponBlock(self)
	return self._blockCast > 0
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
--- @param isPlayFocus boolean 是否播放聚焦动画
--- @return any|nil 发射结果
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

--- 发射跨射武器的核心逻辑
--- @param weapon BattlePointHitWeaponUnit 跨射武器
--- @param isPlayFocus boolean 是否播放聚焦动画
--- @param targetPos Vector3 目标位置（仅空袭模式需要）
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
--- @return boolean 是否成功释放
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
--- @return any 鱼雷发射结果
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

--- 移除手动鱼雷
--- @param weapon BattleManualTorpedoUnit
--- @param isFreeze boolean 是否为冻结移除
function BattleFleetVO.RemoveManunalTorpedo(self, weapon, isFreeze)
	if weapon:IsAttacking() then
		self:CancelTorpedo()
	end

	self._torpedoWeaponVO:RemoveWeapon(weapon)

	if not isFreeze then
		weapon:Clear()
	end
end

--- CP台词系统（大讲堂/特殊触摸等）
function BattleFleetVO.CoupleEncourage(self)
	local shipWordMap = {}
	local chatList = {}

	for _, unit in ipairs(self._unitList) do
		local intimacy = unit:GetIntimacy()
		local words = BattleDataFunction.GetWords(unit:GetSkinID(), "couple_encourage", intimacy)

		if #words > 0 then
			shipWordMap[unit] = words
		end
	end

	local CPChatType = BattleConst.CPChatType
	local CPChatTargetFunc = BattleConst.CPChatTargetFunc

	--- 根据类型和数据构建过滤条件
	local function buildConditionFilter(filterType, filterData)
		local conditionFilter = {}

		if filterType == CPChatType.GROUP_ID then
			conditionFilter.groupIDList = filterData
		elseif filterType == CPChatType.SHIP_TYPE then
			conditionFilter.ship_type_list = filterData
		elseif filterType == CPChatType.RARE then
			conditionFilter.rarity = filterData[1]
		elseif filterType == CPChatType.NATIONALITY then
			conditionFilter.nationality = filterData[1]
		elseif filterType == CPChatType.ILLUSTRATOR then
			conditionFilter.illustrator = filterData[1]
		elseif filterType == CPChatType.TEAM then
			conditionFilter.teamIndex = filterData[1]
		end

		return conditionFilter
	end

	for cpUnit, wordList in pairs(shipWordMap) do
		for linkIndex, wordEntry in ipairs(wordList) do
			local targetType = wordEntry[1]
			local targetCount = wordEntry[2]
			local conditionData = wordEntry[4] or CPChatType.GROUP_ID
			local totalTargets = ys.Battle.BattleTargetChoise.TargetAllHelp(cpUnit)

			if type(conditionData) == "table" then
				for filterTypeIndex, filterTypeValue in ipairs(conditionData) do
					local filterData = buildConditionFilter(filterTypeValue, wordEntry[filterTypeIndex])

					totalTargets = ys.Battle.BattleTargetChoise[CPChatTargetFunc[filterTypeValue]](cpUnit, filterData, totalTargets)
				end
			elseif type(conditionData) == "number" then
				local filterData = buildConditionFilter(conditionData, targetType)

				totalTargets = ys.Battle.BattleTargetChoise[CPChatTargetFunc[conditionData]](cpUnit, filterData, totalTargets)
			end

			if targetCount <= #totalTargets then
				local chatEntry = {
					cp = cpUnit,
					content = wordEntry[3],
					linkIndex = linkIndex
				}

				chatList[#chatList + 1] = chatEntry
			end
		end
	end

	if #chatList > 0 then
		local selectedChat = chatList[math.random(#chatList)]
		local voiceKey = "link" .. selectedChat.linkIndex

		selectedChat.cp:DispatchVoice(voiceKey)
		selectedChat.cp:DispatchChat(selectedChat.content, 3, voiceKey)
	end
end

--- 单位HP更新事件的回调
--- @param event table 事件对象 {Dispatcher=..., Data={dHP=...}}
function BattleFleetVO.onUnitUpdateHP(self, event)
	local sourceUnit = event.Dispatcher
	local dHP = event.Data.dHP

	for _, unit in ipairs(self._unitList) do
		unit:TriggerBuff(BattleConst.BuffEffectType.ON_FRIENDLY_HP_RATIO_UPDATE, {
			unit = sourceUnit,
			dHP = dHP
		})

		if unit ~= sourceUnit then
			unit:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_HP_RATIO_UPDATE, {
				unit = sourceUnit,
				dHP = dHP
			})
		end
	end
end

--- 单位隐蔽状态更新事件的回调
--- @param event table 事件对象 {Dispatcher=...}
function BattleFleetVO.onUnitCloakUpdate(self, event)
	local sourceUnit = event.Dispatcher
	local isCloak = BattleAttr.GetCurrent(sourceUnit, "isCloak")

	for _, unit in ipairs(self._unitList) do
		unit:TriggerBuff(BattleConst.BuffEffectType.ON_CLOAK_UPDATE, {
			cloakState = isCloak
		})

		if unit ~= sourceUnit then
			unit:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_CLOAK_UPDATE, {
				cloakState = isCloak
			})
		end
	end
end

--- 设置潜艇单位数据列表
--- @param subUnitDataList table
function BattleFleetVO.SetSubUnitData(self, subUnitDataList)
	self._subUntiDataList = subUnitDataList
end

--- 获取潜艇单位数据列表
--- @return table
function BattleFleetVO.GetSubUnitData(self)
	return self._subUntiDataList
end

-- TODO
-- 添加潜艇单位函数
-- 被BattleDataProxy.SpawnSub调用
-- template数据来自BattleDataFunction.GeneratePlayerSubmarinPhase
--- @param subUnit BattleSubUnit
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

--- 添加手动操作的潜艇（破交作战等）
--- @param subUnit BattleSubUnit
function BattleFleetVO.AddManualSubmarine(self, subUnit)
	self._unitList[#self._unitList + 1] = subUnit
	self._manualSubList[#self._manualSubList + 1] = subUnit
	self._manualSubBench[#self._manualSubBench + 1] = subUnit
	self._maxCount = self._maxCount + 1

	subUnit:InitOxygen()
	subUnit:SetFleetVO(self)
	subUnit:SetMotion(self._motionVO)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_STATE, self.onUnitCloakUpdate)
end

--- 获取潜艇列表
--- @return table
function BattleFleetVO.GetSubList(self)
	return self._subList
end

--- 切换手动潜艇（将当前操作潜艇换到待机区，从待机区取出下一个）
function BattleFleetVO.ShiftManualSub(self)
	local previousPos

	if self._manualSubUnit then
		local manualTorpedoList = self._manualSubUnit:GetTorpedoList()

		for _, torpedo in ipairs(manualTorpedoList) do
			if torpedo:IsAttacking() then
				self:CancelTorpedo()
			end

			self._torpedoWeaponVO:RemoveWeapon(torpedo)
		end

		if self._manualSubUnit:IsAlive() then
			table.insert(self._manualSubBench, self._manualSubUnit)
		end

		previousPos = self._motionVO:GetPos():Clone()
	else
		previousPos = self._manualSubList[1]:GetPosition():Clone()
	end

	self._manualSubUnit = table.remove(self._manualSubBench, 1)
	self._scoutList[1] = self._manualSubUnit

	local currentUnitList = {}

	for _, benchUnit in ipairs(self._manualSubBench) do
		for unitIndex, listUnit in ipairs(self._unitList) do
			if listUnit == benchUnit then
				table.insert(currentUnitList, unitIndex)

				break
			end
		end
	end

	for unitIndex, listUnit in ipairs(self._unitList) do
		if listUnit == self._manualSubUnit then
			table.insert(currentUnitList, 1, unitIndex)

			break
		end
	end

	self:refreshFleetFormation(currentUnitList)
	self._manualSubUnit:SetMainUnitStatic(false)
	self._manualSubUnit:SetPosition(previousPos)
	self:UpdateMotion()
	self._submarineSpecialVO:SetUseable(false)

	local buffList = self._manualSubUnit:GetBuffList()

	for _, buff in pairs(buffList) do
		if buff:IsSubmarineSpecial() then
			self._submarineSpecialVO:SetCount(1)
			self._submarineSpecialVO:SetUseable(true)

			break
		end
	end

	self:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE)
	self._torpedoWeaponVO:Reset()

	local torpedoList = self._manualSubUnit:GetTorpedoList()

	for _, torpedo in ipairs(torpedoList) do
		if torpedo:GetCurrentState() ~= torpedo.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(torpedo)
		end
	end

	for _, torpedo in ipairs(torpedoList) do
		if torpedo:GetCurrentState() == torpedo.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(torpedo)
		end
	end

	if BattleAttr.GetCurrent(self._manualSubUnit, "oxyMax") <= 0 then
		self._submarineDiveVO:SetActive(false)
		self._submarineFloatVO:SetActive(false)
	else
		self._submarineDiveVO:SetActive(true)
		self._submarineFloatVO:SetActive(true)
	end

	for benchIndex, benchUnit in ipairs(self._manualSubBench) do
		benchUnit:SetPosition(BattleConfig.SUB_BENCH_POS[benchIndex])
		benchUnit:SetMainUnitStatic(true)
		benchUnit:ChangeOxygenState(ys.Battle.OxyState.STATE_FREE_BENCH)
	end

	self._submarineShiftVO:ResetCurrent()

	if #self._manualSubBench == 0 then
		self._submarineShiftVO:SetActive(false)
	end
end

--- 改变潜艇状态
--- @param state number 目标氧气状态
--- @param resetCD boolean 是否重置CD
function BattleFleetVO.ChangeSubmarineState(self, state, resetCD)
	if not self._manualSubUnit then
		return
	end

	self._manualSubUnit:ChangeOxygenState(state)

	if resetCD then
		for _, subVO in ipairs(self._submarineVOList) do
			subVO:ResetCurrent()
		end

		local remainingCD = self._submarineShiftVO:GetMax() - self._submarineShiftVO:GetCurrent()

		if self._submarineShiftVO:IsOverLoad() and remainingCD > BattleConfig.SR_CONFIG.DIVE_CD then
			-- block empty
		else
			self._submarineShiftVO:SetMax(BattleConfig.SR_CONFIG.DIVE_CD)
			self._submarineShiftVO:ResetCurrent()
		end
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.MANUAL_SUBMARINE_SHIFT, {
		state = state
	}))
end

--- 潜艇爆发加速
function BattleFleetVO.SubmarinBoost(self)
	self._manualSubUnit:Boost(Vector3.right, BattleConfig.SR_CONFIG.BOOST_SPEED, BattleConfig.SR_CONFIG.BOOST_DECAY, BattleConfig.SR_CONFIG.BOOST_DURATION, BattleConfig.SR_CONFIG.BOOST_DECAY_STAMP)
	self._submarineBoostVO:ResetCurrent()
end

--- 释放潜艇特殊技能
function BattleFleetVO.UnleashSubmarineSpecial(self)
	if self:GetWeaponBlock() then
		return
	end

	self._submarineSpecialVO:Cast()
	self._manualSubUnit:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FREE_SPECIAL)
end

-- BattleFleetBuffFixSubRefLine
--- 固定潜艇参考线（用于特殊活动的潜艇出击起点修正）
--- @param refLine number 参考线X坐标
function BattleFleetVO.FixSubRefLine(self, refLine)
	self._fixedSubRefLine = refLine
end

-- BattleSkillSonar
--- 添加独立声呐
--- @param range number 声呐范围
--- @param duration number 持续时间
function BattleFleetVO.AppendIndieSonar(self, range, duration)
	if not self._motionReferenceUnit then
		return
	end

	local indieSonar = ys.Battle.BattleIndieSonar.New(self, range, duration)

	indieSonar:SwitchHost(self._motionReferenceUnit)

	self._indieSonarList[indieSonar] = true

	indieSonar:Detect()
end

--- 移除独立声呐
--- @param indieSonar BattleIndieSonar
function BattleFleetVO.RemoveIndieSonar(self, indieSonar)
	for sonar, _ in pairs(self._indieSonarList) do
		if indieSonar == sonar then
			self._indieSonarList[sonar] = nil

			break
		end
	end
end

-- 添加FleetBuff
-- FleetBuff是属于舰队的Buff，而不是属于某个Unit的Buff
-- 被BattleSkillAddFleetBuff.DoDataEffect调用
--- @param fleetBuff BattleFleetBuffUnit
function BattleFleetVO.AttachFleetBuff(self, fleetBuff)
	local fleetBuffID = fleetBuff:GetID()
	local _fleetBuff = self:GetFleetBuff(fleetBuffID)

	if _fleetBuff then
		_fleetBuff:Stack(self)
	else
		self._buffList[fleetBuffID] = fleetBuff
		--- fleetBuff: BattleFleetBuffUnit
		fleetBuff:Attach(self)
	end
end

--- 移除舰队Buff
--- @param fleetBuffID number Buff ID
function BattleFleetVO.RemoveFleetBuff(self, fleetBuffID)
	local fleetBuff = self:GetFleetBuff(fleetBuffID)

	if fleetBuff then
		fleetBuff:Remove()
	end
end

--- 获取舰队Buff
--- @param fleetBuffID number
--- @return BattleFleetBuffUnit|nil
function BattleFleetVO.GetFleetBuff(self, fleetBuffID)
	return self._buffList[fleetBuffID]
end

--- 获取所有舰队Buff列表
--- @return table
function BattleFleetVO.GetFleetBuffList(self)
	return self._buffList
end

--- FleetAttr相关 ---
-- 与Unit的Attr是一个简单的表相比(只依靠BattleAttr做相关操作),FleetAttr则是一个组件(单独类)
-- 一般来说, FleetAttr主要是为了实现这类一般需求: 队友做了XXX操作能够积累XXX(其实常规Buff靠tag应该也能做，但会很麻烦)...而这艘船可以根据积累的XXX/消耗XXX来触发一些效果
-- 具体请看对应类代码. 可以对FleetAttr有更详细的了解(其实比BattleAttr是简化非常多的)
--- 创建舰队属性组件
function BattleFleetVO.AttachFleetAttr(self)
	self._fleetAttr = ys.Battle.BattleFleetAttrComponent.New(self)
end

--- 获取舰队属性组件
--- @return BattleFleetAttrComponent
function BattleFleetVO.GetFleetAttr(self)
	return self._fleetAttr
end

--- 干扰控制（禁用全武器/恢复）
--- @param isJamming boolean true为开始干扰，false为消除干扰
function BattleFleetVO.Jamming(self, isJamming)
	if isJamming then
		self._chargeWeaponVO:StartJamming()
		self._torpedoWeaponVO:StartJamming()
		self._airAssistVO:StartJamming()
	else
		self._chargeWeaponVO:JammingEliminate()
		self._torpedoWeaponVO:JammingEliminate()
		self._airAssistVO:JammingEliminate()
	end
end

--- 致盲
--- @param isBlind boolean
function BattleFleetVO.Blinding(self, isBlind)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_BLIND, {
		isBlind = isBlind
	}))
end

-- 被BattleBuffBlindedHorizon.onAttach调用
--- 更新视野范围
function BattleFleetVO.UpdateHorizon(self)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_HORIZON_UPDATE, {}))
end

-- 对应触发ON_AUTOBOT和ON_MANUAL的buffEffect
--- @param isAutoBotActive boolean 自律是否激活
function BattleFleetVO.AutoBotUpdated(self, isAutoBotActive)
	local effectType = isAutoBotActive and BattleConst.BuffEffectType.ON_AUTOBOT or BattleConst.BuffEffectType.ON_MANUAL

	self:FleetBuffTrigger(effectType)
end

--- 致命暴露（强制将隐蔽值设为最大）
function BattleFleetVO.CloakFatalExpose(self)
	for _, cloakUnit in ipairs(self._cloakList) do
		cloakUnit:GetCloak():ForceToMax()
	end
end

--- 在视野内时的暴露速度
--- @param exposeSpeed number 暴露速度值
function BattleFleetVO.CloakInVision(self, exposeSpeed)
	for _, cloakUnit in ipairs(self._cloakList) do
		cloakUnit:GetCloak():AppendExposeSpeed(exposeSpeed)
	end
end

--- 在视野外（暴露速度为0）
function BattleFleetVO.CloakOutVision(self)
	for _, cloakUnit in ipairs(self._cloakList) do
		cloakUnit:GetCloak():AppendExposeSpeed(0)
	end
end

-- BattleFleetVO.appendMainUnit调用. 给每个后排主力单位调用
--- 初始化并附加隐蔽组件
--- @param unit BattleUnit
function BattleFleetVO.AttachCloak(self, unit)
	if not unit:GetCloak() then
		unit:InitCloak()

		self._cloakList[#self._cloakList + 1] = unit
	end
end

--- 附加夜间隐蔽的瞄准偏移组件
function BattleFleetVO.AttachNightCloak(self)
	self._scoutAimBias = ys.Battle.BattleUnitAimBiasComponent.New()

	self._scoutAimBias:ConfigRangeFormula(BattleFormulas.CalculateMaxAimBiasRange, BattleFormulas.CalculateBiasDecay)
	self._scoutAimBias:Active(self._scoutAimBias.STATE_ACTIVITING)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIM_BIAS, {
		aimBias = self._scoutAimBias
	}))
end

--- 获取舰队瞄准偏移组件
--- @return BattleUnitAimBiasComponent|nil
function BattleFleetVO.GetFleetBias(self)
	return self._scoutAimBias
end

--- 冻结单位（从舰队中移除但保留在freezeList中）
--- @param unit BattleUnit
function BattleFleetVO.FreezeUnit(self, unit)
	self:RemovePlayerUnit(unit, true)

	self._freezeList[unit] = true
end

--- 激活冻结的单位（从freezeList中移出，重新加入舰队）
--- @param unit BattleUnit
function BattleFleetVO.ActiveFreezeUnit(self, unit)
	self._freezeList[unit] = nil
	self._unitList[#self._unitList + 1] = unit
	self._maxCount = self._maxCount + 1

	if unit:IsMainFleetUnit() then
		self:appendFreezeMainUnit(unit)
	else
		self:activeFreezeScoutUnit(unit)
	end

	unit:SetFleetVO(self)
	unit:SetMotion(self._motionVO)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_STATE, self.onUnitCloakUpdate)
end

--- 解除融合（将融合单位拆回原单位，并恢复其HP转移）
function BattleFleetVO.UndoFusion(self)
	for unit, _ in pairs(self._freezeList) do
		self._unitList[#self._unitList + 1] = unit
		self._maxCount = self._maxCount + 1

		if unit:IsMainFleetUnit() then
			self:appendFreezeMainUnit(unit)
		else
			self:activeFreezeScoutUnit(unit)
		end
	end

	local fusionSourceList = {}

	for _, unit in ipairs(self._unitList) do
		local hpProvideRate = unit:GetAttrByName("hpProvideRate")

		if hpProvideRate ~= 0 then
			table.insert(fusionSourceList, unit)

			local currentHP, maxHP = unit:GetHP()
			local missingHP = maxHP - currentHP

			for targetShipID, provideRate in pairs(hpProvideRate) do
				local targetUnit = self:GetFreezeShipByID(targetShipID)

				if not targetUnit then
					self:GetShipByID(targetShipID)
				end

				local hpToTransfer = math.floor(provideRate * missingHP)

				targetUnit:UpdateHP(hpToTransfer * -1, {})
			end
		end
	end

	for _, unit in ipairs(fusionSourceList) do
		self:RemovePlayerUnit(unit)
	end
end

--- 添加冻结的主力单位（后排）
--- @param unit BattleUnit
function BattleFleetVO.appendFreezeMainUnit(self, unit)
	self._mainList[#self._mainList + 1] = unit

	unit:SetMainUnitIndex(#self._mainList)

	if ShipType.CloakShipType(unit:GetTemplate().type) then
		table.insert(self._cloakList, unit)
	end

	local chargeList = unit:GetChargeList()

	for _, chargeWeapon in ipairs(chargeList) do
		self._chargeWeaponVO:AppendFreezeWeapon(chargeWeapon)
	end

	local manualTorpedoList = unit:GetTorpedoList()

	for _, torpedo in ipairs(manualTorpedoList) do
		self._torpedoWeaponVO:AppendFreezeWeapon(torpedo)
	end

	if unit:GetAirAssistList() then
		local airAssistList = unit:GetAirAssistList()

		for _, airAssist in ipairs(airAssistList) do
			self._airAssistVO:AppendFreezeWeapon(airAssist)
		end
	end

	self._fleetAntiAir:AppendCrewUnit(unit)
	self._fleetRangeAntiAir:AppendCrewUnit(unit)
	self._fleetStaticSonar:AppendCrewUnit(unit)

	local currentUnitList = {}

	for _, _ in ipairs(self._unitList) do
		table.insert(currentUnitList, _)
	end

	self:refreshFleetFormation(currentUnitList)
end

--- 激活冻结的前排单位
--- @param unit BattleUnit
function BattleFleetVO.activeFreezeScoutUnit(self, unit)
	self._scoutList[#self._scoutList + 1] = unit

	local manualTorpedoList = unit:GetTorpedoList()

	for _, torpedo in ipairs(manualTorpedoList) do
		self._torpedoWeaponVO:AppendFreezeWeapon(torpedo)
	end

	if unit:GetAirAssistList() then
		local airAssistList = unit:GetAirAssistList()

		for _, airAssist in ipairs(airAssistList) do
			self._airAssistVO:AppendFreezeWeapon(airAssist)
		end
	end

	self._fleetAntiAir:AppendCrewUnit(unit)
	self._fleetStaticSonar:AppendCrewUnit(unit)

	local posIndex = 1
	local unitListLength = #self._unitList
	local currentUnitList = {}

	while posIndex < unitListLength do
		table.insert(currentUnitList, posIndex)

		posIndex = posIndex + 1
	end

	table.insert(currentUnitList, #self._scoutList, posIndex)
	self:refreshFleetFormation(currentUnitList)
end

--- 附加卡牌谜题组件
--- @return BattleFleetCardPuzzleComponent
function BattleFleetVO.AttachCardPuzzleComponent(self)
	self._cardPuzzleComponent = ys.Battle.BattleFleetCardPuzzleComponent.New(self)

	return self._cardPuzzleComponent
end

--- 获取卡牌谜题组件
--- @return BattleFleetCardPuzzleComponent|nil
function BattleFleetVO.GetCardPuzzleComponent(self)
	return self._cardPuzzleComponent
end

--- 添加支援单位
--- @param unit BattleSupportUnit
function BattleFleetVO.AppendSupportUnit(self, unit)
	self._supportList[#self._supportList + 1] = unit
end

--- 获取支援单位列表
--- @return table
function BattleFleetVO.GetSupportUnitList(self)
	return self._supportList
end
