ys = ys or {}

-- 战斗舰队VO（Value Object），管理一个阵营下所有舰船Unit的队列、阵型、武器VO、Buff等
-- 负责统一调度前锋/主力/潜艇/隐身的更新循环和手动武器操作
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr2 = ys.Battle.BattleAttr
--- @class BattleFleetVO
local BattleFleetVO = class("BattleFleetVO")

ys.Battle.BattleFleetVO = BattleFleetVO
BattleFleetVO.__name = "BattleFleetVO"

--- 构造函数
--- @param IFF number 阵营编码（FRIENDLY_CODE/FOE_CODE）
function BattleFleetVO.Ctor(self, IFF)
	ys.EventDispatcher.AttachEventDispatcher(self)
	ys.EventListener.AttachEventListener(self)

	self._IFF = IFF
	self._lastDist = 0

	self:init()
end

--- 更新舰队运动状态：根据参考单位更新位置、速度、方向，并派发距离变化事件
function BattleFleetVO.UpdateMotion(self)
	if self._motionReferenceUnit then
		self._motionVO:UpdatePos(self._motionReferenceUnit)
		self._motionVO:UpdateVelocityAndDirection(self:GetFleetVelocity(), self._motionSourceFunc())
	end

	-- 计算舰队距离右边界的偏移，若变化则派发SHOW_BUFFER事件
	local dist = math.max(self._motionVO:GetPos().x - self._rightBound, 0)

	if dist >= 0 and dist ~= self._lastDist then
		self._lastDist = dist

		self:DispatchEvent(ys.Event.New(BattleEvent.SHOW_BUFFER, {
			dist = dist
		}))
	end
end

--- 更新舰队所有自动组件（前锋、主力、隐身、潜艇的武器/氧气/相位）
--- @param timeStamp number 时间戳
function BattleFleetVO.UpdateAutoComponent(self, timeStamp)
	for _, unit in ipairs(self._scoutList) do
		unit:UpdateWeapon(timeStamp)
		unit:UpdateAirAssist()
	end

	for _, unit in ipairs(self._mainList) do
		unit:UpdateWeapon(timeStamp)
		unit:UpdateAirAssist()
	end

	for _, unit in ipairs(self._cloakList) do
		unit:UpdateCloak(timeStamp)
	end

	for _, unit in ipairs(self._subList) do
		unit:UpdateWeapon(timeStamp)
		unit:UpdateOxygen(timeStamp)
		unit:UpdatePhaseSwitcher()
	end

	for _, unit in ipairs(self._manualSubList) do
		unit:UpdateOxygen(timeStamp)
	end

	self._fleetAntiAir:Update(timeStamp)
	self._fleetRangeAntiAir:Update(timeStamp)
	self._fleetStaticSonar:Update(timeStamp)

	-- 独立声呐更新
	for sonar, _ in pairs(self._indieSonarList) do
		sonar:Update(timeStamp)
	end

	self:UpdateBuff(timeStamp)
end

--- 更新舰队Buff列表
--- @param timeStamp number 时间戳
function BattleFleetVO.UpdateBuff(self, timeStamp)
	local buffList = self._buffList

	for buffID, buff in pairs(buffList) do
		buff:Update(self, timeStamp)
	end
end

--- 更新所有手动武器VO（蓄力/鱼雷/空袭/潜艇操作）
--- @param timeStamp number 时间戳
function BattleFleetVO.UpdateManualWeaponVO(self, timeStamp)
	self._chargeWeaponVO:Update(timeStamp)
	self._torpedoWeaponVO:Update(timeStamp)
	self._airAssistVO:Update(timeStamp)
	self._submarineDiveVO:Update(timeStamp)
	self._submarineFloatVO:Update(timeStamp)
	self._submarineBoostVO:Update(timeStamp)
	self._submarineShiftVO:Update(timeStamp)
end

--- 累加舰队受到的总伤害比例
--- @param damage number 伤害值
function BattleFleetVO.UpdateFleetDamage(self, damage)
	local fleetDamageRatio = BattleFormulas.CalculateFleetDamage(damage)

	self._currentDMGRatio = self._currentDMGRatio + fleetDamageRatio

	self:DispatchFleetDamageChange()
end

--- 扣除舰队过量伤害（给舰队回血）
--- @param overDamage number 过量伤害扣除量
function BattleFleetVO.UpdateFleetOverDamage(self, overDamage)
	local fleetOverDamageRatio = BattleFormulas.CalculateFleetOverDamage(self, overDamage)

	self._currentDMGRatio = self._currentDMGRatio - fleetOverDamageRatio

	self:DispatchFleetDamageChange()
end

--- 派发舰队伤害变化事件
function BattleFleetVO.DispatchFleetDamageChange(self)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_DMG_CHANGE, {}))
end

--- 派发声呐扫描事件
--- @param indieSonar BattleIndieSonar 独立声呐对象
function BattleFleetVO.DispatchSonarScan(self, indieSonar)
	self:DispatchEvent(ys.Event.New(BattleEvent.SONAR_SCAN, {
		indieSonar = indieSonar
	}))
end

--- 解放主力单位（允许其自由移动），给每个主力附加指定Buff
--- @param buffID number Buff ID
function BattleFleetVO.FreeMainUnit(self, buffID)
	if self._mainUnitFree then
		return
	end

	self._mainUnitFree = true

	for _, unit in ipairs(self._mainList) do
		local buff = ys.Battle.BattleBuffUnit.New(buffID)

		unit:AddBuff(buff)
		unit:SetMainUnitStatic(false)
	end
end

--- 从主力列表中随机选择一个未排除属性的受害单位
--- @param excludeAttr table 排除的属性列表（如 { "isSubmarine" }）
--- @return BattleUnitVO|nil victim 选中的受害单位
function BattleFleetVO.RandomMainVictim(self, excludeAttr)
	excludeAttr = excludeAttr or {}

	local candidates = {}
	local victim

	-- 根据排除属性过滤候选单位
	for _, unit in ipairs(self._mainList) do
		local isValid = true

		for _, attrName in ipairs(excludeAttr) do
			if unit:GetAttrByName(attrName) == 1 then
				isValid = false

				break
			end
		end

		if isValid then
			table.insert(candidates, unit)
		end
	end

	if #candidates > 0 then
		victim = candidates[math.random(#candidates)]
	end

	return victim
end

--- 从单位列表中找离指定位置最近的特定类型的单位
--- @param pos Vector3 参考位置
--- @param typeList table 允许的类型列表
--- @return BattleUnitVO|nil nearest 最近的单位
function BattleFleetVO.NearestUnitByType(self, pos, typeList)
	local minDist = 999
	local nearest

	for _, unit in ipairs(self._unitList) do
		local unitType = unit:GetTemplate().type

		if table.contains(typeList, unitType) then
			local unitPos = unit:GetPosition()
			local dist = Vector3.BattleDistance(unitPos, pos)

			if dist < minDist then
				minDist = dist
				nearest = unit
			end
		end
	end

	return nearest
end

--- 设置舰队运动来源（默认读取UIMgr的水平/垂直输入，或传入自定义函数）
--- @param source function|nil 自定义运动来源函数
function BattleFleetVO.SetMotionSource(self, source)
	if source == nil then
		-- 默认：读取UI输入
		function self._motionSourceFunc()
			local uiMgr = pg.UIMgr.GetInstance()

			return uiMgr.hrz, uiMgr.vtc
		end
	else
		self._motionSourceFunc = source
	end
end

--- 设置潜艇支援数据（可用次数/标志）
--- @param total number 总次数
--- @param flag number 支援状态标志
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

--- 设置舰队活动边界
--- @param upper number 上边界
--- @param lower number 下边界
--- @param left number 左边界
--- @param right number 右边界
function BattleFleetVO.SetBound(self, upper, lower, left, right)
	self._upperBound = upper
	self._lowerBound = lower
	self._leftBound = left
	self._rightBound = right
end

--- 设置舰队总边界（含屏幕外区域）
--- @param tUpper number 总上边界
--- @param tLower number 总下边界
--- @param tLeft number 总左边界
--- @param tRight number 总右边界
function BattleFleetVO.SetTotalBound(self, tUpper, tLower, tLeft, tRight)
	self._totalUpperBound = tUpper
	self._totalLowerBound = tLower
	self._totalLeftBound = tLeft
	self._totalRightBound = tRight
end

--- 计算潜艇攻击/撤退基线位置
--- @param systemType number 系统类型
function BattleFleetVO.CalcSubmarineBaseLine(self, systemType)
	-- 计算地图中心X坐标
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

--- 设置舰队暴露线和视野线X坐标
--- @param visionX number 视野线X
--- @param exposeX number 暴露线X
function BattleFleetVO.SetExposeLine(self, visionX, exposeX)
	self._visionLineX = visionX
	self._exposeLineX = exposeX
end

--- 向舰队添加玩家单位，根据主力/前锋类型分到不同列表
--- @param unit BattleUnitVO 要添加的单位
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

--- 从舰队移除玩家单位并清理其武器/Buff/声呐关联
--- @param unit BattleUnitVO 要移除的单位
function BattleFleetVO.RemovePlayerUnit(self, unit)
	local newUnitList = {}

	-- 遍历单位列表，分离保留和移除的单位
	for index, curUnit in ipairs(self._unitList) do
		if curUnit ~= unit then
			newUnitList[#newUnitList + 1] = index
		else
			-- 清理事件监听和碰撞
			curUnit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)
			curUnit:DeactiveCldBox()

			-- 清理该单位的所有蓄力武器
			local chargeList = curUnit:GetChargeList()

			for _, chargeWeapon in ipairs(chargeList) do
				if chargeWeapon:IsAttacking() then
					self._chargeWeaponVO:CancelFocus()
					self._chargeWeaponVO:ResetFocus()
					self:CancelChargeWeapon()
				end

				self._chargeWeaponVO:RemoveWeapon(chargeWeapon)
				chargeWeapon:Clear()
			end

			self._fleetAntiAir:RemoveCrewUnit(unit)
			self._fleetRangeAntiAir:RemoveCrewUnit(unit)
			self._fleetStaticSonar:RemoveCrewUnit(unit)

			-- 清理该单位的所有鱼雷武器
			local torpedoList = curUnit:GetTorpedoList()

			for _, torpedoWeapon in ipairs(torpedoList) do
				self:RemoveManunalTorpedo(torpedoWeapon)
			end

			-- 清理该单位的所有空袭武器
			local airAssistList = curUnit:GetAirAssistList()

			if airAssistList then
				for _, airWeapon in ipairs(airAssistList) do
					self._airAssistVO:RemoveWeapon(airWeapon)
				end
			end
		end
	end

	-- 从各子列表中移除该单位
	for scoutIndex, scoutUnit in ipairs(self._scoutList) do
		if scoutUnit == unit then
			if #self._scoutList == 1 then
				self:CancelChargeWeapon()
			end

			table.remove(self._scoutList, scoutIndex)

			break
		end
	end

	for mainIndex, mainUnit in ipairs(self._mainList) do
		if mainUnit == unit then
			table.remove(self._mainList, mainIndex)

			break
		end
	end

	for cloakIndex, cloakUnit in ipairs(self._cloakList) do
		if cloakUnit == unit then
			table.remove(self._cloakList, cloakIndex)

			break
		end
	end

	for subIndex, subUnit in ipairs(self._subList) do
		if subUnit == unit then
			table.remove(self._subList, subIndex)

			break
		end
	end

	for manSubIndex, manSubUnit in ipairs(self._manualSubList) do
		if manSubUnit == unit then
			table.remove(self._manualSubList, manSubIndex)

			break
		end
	end

	-- 非手动潜艇状态则刷新阵型
	if not self._manualSubUnit then
		self:refreshFleetFormation(newUnitList)
	end
end

--- 覆盖摇杆自动Bot AI ID
--- @param aiID number 新的AI ID
function BattleFleetVO.OverrideJoyStickAutoBot(self, aiID)
	self._autoBotAIID = aiID

	local event = ys.Event.New(ys.Battle.BattleEvent.OVERRIDE_AUTO_BOT)

	self:DispatchEvent(event)
end

--- 快照：记录当前舰队总血量比例作为基准
function BattleFleetVO.SnapShot(self)
	self._totalDMGRatio = BattleFormulas.GetFleetTotalHP(self)
	self._currentDMGRatio = self._totalDMGRatio
end

--- 获取阵营编码
--- @return number IFF
function BattleFleetVO.GetIFF(self)
	return self._IFF
end

--- 获取最大单位数
--- @return number maxCount
function BattleFleetVO.GetMaxCount(self)
	return self._maxCount
end

--- 获取旗舰
--- @return BattleUnitVO|nil flagShip
function BattleFleetVO.GetFlagShip(self)
	return self._flagShip
end

--- 获取领舰（前锋列表第一位）
--- @return BattleUnitVO|nil leaderShip
function BattleFleetVO.GetLeaderShip(self)
	return self._scoutList[1]
end

--- 获取所有单位列表
--- @return table unitList
function BattleFleetVO.GetUnitList(self)
	return self._unitList
end

--- 获取主力单位列表
--- @return table mainList
function BattleFleetVO.GetMainList(self)
	return self._mainList
end

--- 获取前锋单位列表
--- @return table scoutList
function BattleFleetVO.GetScoutList(self)
	return self._scoutList
end

--- 获取隐身单位列表
--- @return table cloakList
function BattleFleetVO.GetCloakList(self)
	return self._cloakList
end

--- 获取手动潜艇预备席
--- @return table manualSubBench
function BattleFleetVO.GetSubBench(self)
	return self._manualSubBench
end

--- 获取舰队运动VO
--- @return BattleFleetMotionVO motionVO
function BattleFleetVO.GetMotion(self)
	return self._motionVO
end

--- 获取当前运动参考单位
--- @return BattleUnitVO|nil motionReferenceUnit
function BattleFleetVO.GetMotionReferenceUnit(self)
	return self._motionReferenceUnit
end

--- 获取自动Bot AI ID
--- @return number|nil autoBotAIID
function BattleFleetVO.GetAutoBotAIID(self)
	return self._autoBotAIID
end

--- 获取蓄力武器VO
--- @return BattleChargeWeaponVO chargeWeaponVO
function BattleFleetVO.GetChargeWeaponVO(self)
	return self._chargeWeaponVO
end

--- 获取鱼雷武器VO
--- @return BattleTorpedoWeaponVO torpedoWeaponVO
function BattleFleetVO.GetTorpedoWeaponVO(self)
	return self._torpedoWeaponVO
end

--- 获取空袭武器VO
--- @return BattleAllInStrikeVO airAssistVO
function BattleFleetVO.GetAirAssistVO(self)
	return self._airAssistVO
end

--- 获取潜艇支援VO
--- @return BattleSubmarineAidVO submarineVO
function BattleFleetVO.GetSubAidVO(self)
	return self._submarineVO
end

--- 获取潜艇自由下潜VO
--- @return BattleSubmarineFuncVO submarineDiveVO
function BattleFleetVO.GetSubFreeDiveVO(self)
	return self._submarineDiveVO
end

--- 获取潜艇自主上浮VO
--- @return BattleSubmarineFuncVO submarineFloatVO
function BattleFleetVO.GetSubFreeFloatVO(self)
	return self._submarineFloatVO
end

--- 获取潜艇加速VO
--- @return BattleSubmarineFuncVO submarineBoostVO
function BattleFleetVO.GetSubBoostVO(self)
	return self._submarineBoostVO
end

--- 获取潜艇特殊技能VO
--- @return BattleSubmarineAidVO submarineSpecialVO
function BattleFleetVO.GetSubSpecialVO(self)
	return self._submarineSpecialVO
end

--- 获取潜艇切换VO
--- @return BattleSubmarineFuncVO submarineShiftVO
function BattleFleetVO.GetSubShiftVO(self)
	return self._submarineShiftVO
end

--- 获取舰队防空武器
--- @return BattleFleetAntiAirUnit fleetAntiAir
function BattleFleetVO.GetFleetAntiAirWeapon(self)
	return self._fleetAntiAir
end

--- 获取舰队范围防空武器
--- @return BattleFleetRangeAntiAirUnit fleetRangeAntiAir
function BattleFleetVO.GetFleetRangeAntiAirWeapon(self)
	return self._fleetRangeAntiAir
end

--- 获取舰队移动速度
--- @return number velocity
function BattleFleetVO.GetFleetVelocity(self)
	return BattleFormulas.GetFleetVelocity(self._scoutList)
end

--- 获取舰队活动边界（上/下/左/右）
--- @return number upperBound, number lowerBound, number leftBound, number rightBound
function BattleFleetVO.GetFleetBound(self)
	return self._upperBound, self._lowerBound, self._leftBound, self._rightBound
end

--- 获取舰队暴露线X坐标
--- @return number exposeLineX
function BattleFleetVO.GetFleetExposeLine(self)
	return self._exposeLineX
end

--- 获取舰队视野线X坐标
--- @return number visionLineX
function BattleFleetVO.GetFleetVisionLine(self)
	return self._visionLineX
end

--- 获取领舰的自动驾驶偏好
--- @return number personality
function BattleFleetVO.GetLeaderPersonality(self)
	return self._motionReferenceUnit:GetAutoPilotPreference()
end

--- 获取伤害比例结果（格式化为百分比字符串）和总血量
--- @return string damagePercent, number totalHP
function BattleFleetVO.GetDamageRatioResult(self)
	return string.format("%0.2f", self._currentDMGRatio / self._totalDMGRatio * 100), self._totalDMGRatio
end

--- 获取当前伤害比例
--- @return number damageRatio
function BattleFleetVO.GetDamageRatio(self)
	return self._currentDMGRatio / self._totalDMGRatio
end

--- 获取潜艇攻击/撤退基线
--- @return number subAttackBaseLine, number subRetreatBaseLine
function BattleFleetVO.GetSubmarineBaseLine(self)
	return self._subAttackBaseLine, self._subRetreatBaseLine
end

--- 获取舰队静态声呐
--- @return BattleFleetStaticSonar fleetStaticSonar
function BattleFleetVO.GetFleetSonar(self)
	return self._fleetStaticSonar
end

--- 销毁舰队：清除事件监听、防空武器、声呐、Buff等资源
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

--- 刷新舰队阵型：重新排序unitList并更新各单位在阵型中的偏移位置
--- @param unitOrder table 单位索引排序列表（由外部子列表变化计算得出）
function BattleFleetVO.refreshFleetFormation(self, unitOrder)
	-- 读取阵型模板的pos_offset数据
	local posOffset = BattleDataFunction.GetFormationTmpDataFromID(BattleConfig.FORMATION_ID).pos_offset

	self._unitList = BattleDataFunction.SortFleetList(unitOrder, self._unitList)

	local bornOffset = BattleConfig.BornOffset

	-- 主力未解放时，按阵型模板设置各单位偏移
	if not self._mainUnitFree then
		for index, unit in ipairs(self._unitList) do
			if not table.contains(self._subList, unit) then
				local offset = posOffset[index]

				unit:UpdateFormationOffset(Vector3(offset.x, offset.y, offset.z) + bornOffset * (index - 1))
			end
		end
	end

	-- 有前锋时以第一位为运动参考单位
	if #self._scoutList > 0 then
		self._motionReferenceUnit = self._scoutList[1]
		self._leaderUnit = self._scoutList[1]

		self._leaderUnit:LeaderSetting()
		self._fleetAntiAir:SwitchHost(self._motionReferenceUnit)
		self._fleetStaticSonar:SwitchHost(self._motionReferenceUnit)

		for sonar, _ in pairs(self._indieSonarList) do
			sonar:SwitchHost(self._motionReferenceUnit)
		end

		self._motionVO:UpdatePos(self._motionReferenceUnit)
	elseif self._fleetAntiAir:GetCurrentState() ~= self._fleetAntiAir.STATE_DISABLE then
		-- 无前锋但有防空机组成员时，从机组成员中选一个作为参考单位
		local crewList = self._fleetAntiAir:GetCrewUnitList()

		for unit, _ in pairs(crewList) do
			self._motionReferenceUnit = unit

			self._fleetAntiAir:SwitchHost(unit)

			break
		end
	else
		-- 无前锋也无防空机组，以主力列表第一位为参考
		self._motionReferenceUnit = self._mainList[1]
		self._leaderUnit = nil
	end

	if #self:GetUnitList() == 0 then
		return
	end

	local event = ys.Event.New(ys.Battle.BattleEvent.REFRESH_FLEET_FORMATION)

	self:DispatchEvent(event)
end

--- 初始化舰队VO：创建各武器VO、防空单元、运动VO、声呐、子列表等
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

--- 向前锋列表添加单位，并关联其鱼雷/空袭武器到舰队VO
--- @param unit BattleUnitVO 要添加的前锋单位
function BattleFleetVO.appendScoutUnit(self, unit)
	self._scoutList[#self._scoutList + 1] = unit

	-- 注册鱼雷武器
	local torpedoList = unit:GetTorpedoList()

	for _, torpedoWeapon in ipairs(torpedoList) do
		self._torpedoWeaponVO:AppendWeapon(torpedoWeapon)
	end

	-- 有空袭槽位时创建空袭武器
	if #unit:GetHiveList() > 0 then
		local allInStrikeList = BattleDataFunction.CreateAllInStrike(unit)

		for _, strikeWeapon in ipairs(allInStrikeList) do
			self._airAssistVO:AppendWeapon(strikeWeapon)
		end

		unit:SetAirAssistList(allInStrikeList)
	end

	self._fleetAntiAir:AppendCrewUnit(unit)
	self._fleetStaticSonar:AppendCrewUnit(unit)

	-- 构建新的单位排序列表：前段保序 + 新单位插入前锋位置
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

--- 向主力列表添加单位，并关联其蓄力/鱼雷/空袭武器到舰队VO
--- @param unit BattleUnitVO 要添加的主力单位
function BattleFleetVO.appendMainUnit(self, unit)
	if #self._mainList == 0 then
		self._flagShip = unit
	end

	self._mainList[#self._mainList + 1] = unit

	unit:SetMainUnitIndex(#self._mainList)

	-- 隐身舰船类型自动附加隐身
	if ShipType.CloakShipType(unit:GetTemplate().type) then
		self:AttachCloak(unit)
	end

	-- 蓄力武器
	local chargeList = unit:GetChargeList()

	for _, chargeWeapon in ipairs(chargeList) do
		self._chargeWeaponVO:AppendWeapon(chargeWeapon)
	end

	-- 鱼雷武器
	local torpedoList = unit:GetTorpedoList()

	for _, torpedoWeapon in ipairs(torpedoList) do
		self._torpedoWeaponVO:AppendWeapon(torpedoWeapon)
	end

	-- 空袭武器
	if #unit:GetHiveList() > 0 then
		local allInStrikeList = BattleDataFunction.CreateAllInStrike(unit)

		for _, strikeWeapon in ipairs(allInStrikeList) do
			self._airAssistVO:AppendWeapon(strikeWeapon)
		end

		unit:SetAirAssistList(allInStrikeList)
	end

	self._fleetAntiAir:AppendCrewUnit(unit)
	self._fleetRangeAntiAir:AppendCrewUnit(unit)
	self._fleetStaticSonar:AppendCrewUnit(unit)

	-- 构建单位排序列表：保持现有顺序
	local unitOrder = {}

	for index, _ in ipairs(self._unitList) do
		table.insert(unitOrder, index)
	end

	self:refreshFleetFormation(unitOrder)
end

--- 向潜艇列表添加单位
--- @param unit BattleUnitVO 要添加的潜艇单位
function BattleFleetVO.appendSubUnit(self, unit)
	self._subList[#self._subList + 1] = unit

	unit:SetMainUnitIndex(#self._subList)
end

--- 舰队出战呐喊：从前锋/主力中随机选取一位播报"battle"语音和对话
function BattleFleetVO.FleetWarcry(self)
	local speaker
	local coinFlip = math.random(0, 1)
	local scoutLeader = self:GetScoutList()[1]
	local mainLeader = self:GetMainList()[1]

	-- 主力不存在或随机到0时由前锋领舰喊话，否则主力旗舰喊话
	if mainLeader == nil or coinFlip == 0 then
		speaker = scoutLeader
	elseif coinFlip == 1 then
		speaker = mainLeader
	end

	local context = "battle"
	local intimacy = speaker:GetIntimacy()
	local words = ys.Battle.BattleDataFunction.GetWords(speaker:GetSkinID(), context, intimacy)

	speaker:DispatchVoice(context)
	speaker:DispatchChat(words, 2.5, context)
end

--- 舰队单位全部生成完毕：计算总装备评分并设置到每个单位
function BattleFleetVO.FleetUnitSpwanFinish(self)
	local totalGS = 0

	-- 汇总所有单位的装备评分
	for _, unit in ipairs(self._unitList) do
		totalGS = totalGS + unit:GetGearScore()
	end

	-- 将总评分写入每个单位的"fleetGS"属性
	for _, unit in ipairs(self._unitList) do
		BattleAttr2.SetCurrent(unit, "fleetGS", totalGS)
	end
end

--- 潜艇出战呐喊：由潜艇列表第一位播报语音和对话
function BattleFleetVO.SubWarcry(self)
	local subUnit = self:GetSubList()[1]
	local context = "battle"
	local intimacy = subUnit:GetIntimacy()
	local words = ys.Battle.BattleDataFunction.GetWords(subUnit:GetSkinID(), context, intimacy)

	subUnit:DispatchVoice(context)
	subUnit:DispatchChat(words, 2.5, context)
end

--- 设置武器阻塞计数（用于禁用/恢复手动武器操作）
--- @param count number 阻塞增量（正数=阻塞，负数=解除）
function BattleFleetVO.SetWeaponBlock(self, count)
	self._blockCast = self._blockCast + count
end

--- 检查武器是否被阻塞
--- @return boolean isBlocked
function BattleFleetVO.GetWeaponBlock(self)
	return self._blockCast > 0
end

--- 释放蓄力武器（手动蓄力炮击）
function BattleFleetVO.CastChargeWeapon(self)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		currentWeapon:Charge()

		local eventData = {}
		local event = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CHARGE, eventData)

		self:DispatchEvent(event)
	end
end

--- 取消蓄力武器
function BattleFleetVO.CancelChargeWeapon(self)
	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		local eventData = {}
		local event = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CANCEL, eventData)

		self:DispatchEvent(event)
		currentWeapon:CancelCharge()
	end
end

--- 释放蓄力武器（蓄力完成 → 发射）
function BattleFleetVO.UnleashChrageWeapon(self)
	if self:GetWeaponBlock() then
		self:CancelChargeWeapon()

		return
	end

	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		-- 强袭模式：计算目标位置并发射
		if currentWeapon:IsStrikeMode() then
			local targetX = self._motionVO:GetPos().x + BattleConfig.ChargeWeaponConfig.SIGHT_C
			local clampedX = math.min(targetX, self._totalRightBound)

			self:fireChargeWeapon(currentWeapon, true, Vector3.New(clampedX, 0, self._motionVO:GetPos().z))
		else
			currentWeapon:CancelCharge()
		end

		local eventData = {}
		local event = ys.Event.New(ys.Battle.BattleUnitEvent.POINT_HIT_CANCEL, eventData)

		self:DispatchEvent(event)
	end
end

--- 快速标记蓄力武器（自动锁定目标后发射）
--- @param isManual boolean 是否手动模式（用于区分是否播放CutIn）
function BattleFleetVO.QuickTagChrageWeapon(self, isManual)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._chargeWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		currentWeapon:QuickTag()

		-- 无锁定目标则取消，否则发射
		if #currentWeapon:GetLockList() <= 0 then
			currentWeapon:CancelQuickTag()
		else
			self:fireChargeWeapon(currentWeapon, isManual)
		end
	end
end

--- 执行蓄力武器发射（内部方法）：处理CutIn动画/聚焦后Fire
--- @param weapon BattleChargeWeapon 蓄力武器
--- @param isStrike boolean 是否为强袭模式（有聚焦CutIn）
--- @param targetPos Vector3 发射目标位置（强袭模式下使用）
function BattleFleetVO.fireChargeWeapon(self, weapon, isStrike, targetPos)
	local host = weapon:GetHost()

	-- 发射回调：先闪烁再发射
	local function fireCallback()
		-- 内部函数：实际调用武器Fire
		local function fireFunc()
			weapon:Fire(targetPos)
		end

		weapon:DispatchBlink(fireFunc)
	end

	if isStrike then
		if self._IFF == BattleConfig.FRIENDLY_CODE then
			self._chargeWeaponVO:PlayCutIn(host, 1 / BattleConfig.FOCUS_MAP_RATE)
		end

		self._chargeWeaponVO:PlayFocus(host, fireCallback)
	else
		if self._IFF == BattleConfig.FRIENDLY_CODE then
			self._chargeWeaponVO:PlayCutIn(host, 1)
		end

		fireCallback()
	end
end

--- 释放全部空袭（All-in Strike）
function BattleFleetVO.UnleashAllInStrike(self)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._airAssistVO:GetCurrentWeapon()

	if currentWeapon and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		local host = currentWeapon:GetHost()

		-- 友方主力单位播放CutIn
		if self._IFF == BattleConfig.FRIENDLY_CODE and host:IsMainFleetUnit() then
			self._airAssistVO:PlayCutIn(host, 1)
		end

		currentWeapon:CLSBullet()
		currentWeapon:DispatchBlink()
		currentWeapon:Fire()
	end
end

--- 准备鱼雷（手动鱼雷）
function BattleFleetVO.CastTorpedo(self)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		currentWeapon:Prepar()
	end
end

--- 取消鱼雷准备
function BattleFleetVO.CancelTorpedo(self)
	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_PRECAST then
		currentWeapon:Cancel()
	end
end

--- 释放鱼雷
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

--- 快速释放鱼雷（跳过准备阶段直接发射）
function BattleFleetVO.QuickCastTorpedo(self)
	if self:GetWeaponBlock() then
		return
	end

	local currentWeapon = self._torpedoWeaponVO:GetCurrentWeapon()

	if currentWeapon ~= nil and currentWeapon:GetCurrentState() == currentWeapon.STATE_READY then
		currentWeapon:Fire(true)
	end
end

--- 移除手动鱼雷武器
--- @param torpedoWeapon BattleTorpedoWeapon 要移除的鱼雷武器
function BattleFleetVO.RemoveManunalTorpedo(self, torpedoWeapon)
	if torpedoWeapon:IsAttacking() then
		self:CancelTorpedo()
	end

	self._torpedoWeaponVO:RemoveWeapon(torpedoWeapon)
	torpedoWeapon:Clear()
end

--- 触发伴侣鼓励系统：随机选取一对符合条件的单位播报CP对话和语音
function BattleFleetVO.CoupleEncourage(self)
	-- unitChatMap: 单位 → 其拥有的CP对话行列表
	local unitChatMap = {}
	-- validChats: 筛选后符合条件的对话条目
	local validChats = {}

	-- 收集所有有CP对话的单位
	for _, unit in ipairs(self._unitList) do
		local intimacy = unit:GetIntimacy()
		local chatLines = BattleDataFunction.GetWords(unit:GetSkinID(), "couple_encourage", intimacy)

		if #chatLines > 0 then
			unitChatMap[unit] = chatLines
		end
	end

	local cpChatType = BattleConst.CPChatType
	local cpChatTargetFunc = BattleConst.CPChatTargetFunc

	--- 根据类型构建过滤条件表
	--- @param categoryType number CPChatType枚举值
	--- @param filterParam any 过滤参数
	--- @return table filter 过滤条件表
	local function buildFilter(categoryType, filterParam)
		local filter = {}

		if categoryType == cpChatType.GROUP_ID then
			filter.groupIDList = filterParam
		elseif categoryType == cpChatType.SHIP_TYPE then
			filter.ship_type_list = filterParam
		elseif categoryType == cpChatType.RARE then
			filter.rarity = filterParam[1]
		elseif categoryType == cpChatType.NATIONALITY then
			filter.nationality = filterParam[1]
		elseif categoryType == cpChatType.ILLUSTRATOR then
			filter.illustrator = filterParam[1]
		elseif categoryType == cpChatType.TEAM then
			filter.teamIndex = filterParam[1]
		end

		return filter
	end

	-- 遍历每个有CP对话的单位及其对话行
	for unit, chatLines in pairs(unitChatMap) do
		for linkIndex, chatEntry in ipairs(chatLines) do
			local targetType = chatEntry[1]
			local targetCount = chatEntry[2]
			local filterType = chatEntry[4] or cpChatType.GROUP_ID
			-- 获取该单位的所有潜在CP目标
			local targetList = ys.Battle.BattleTargetChoise.TargetAllHelp(unit)

			-- 根据filterType类型进行不同过滤
			if type(filterType) == "table" then
				-- 复合过滤：多个条件依次叠加
				for ftIndex, filterTypeEntry in ipairs(filterType) do
					local filter = buildFilter(filterTypeEntry, targetType[ftIndex])

					targetList = ys.Battle.BattleTargetChoise[cpChatTargetFunc[filterTypeEntry]](unit, filter, targetList)
				end
			elseif type(filterType) == "number" then
				-- 单条件过滤
				local filter = buildFilter(filterType, targetType)

				targetList = ys.Battle.BattleTargetChoise[cpChatTargetFunc[filterType]](unit, filter, targetList)
			end

			-- 符合条件的目标数量达到要求时，加入有效对话列表
			if targetCount <= #targetList then
				local chatEntryData = {
					cp = unit,
					content = chatEntry[3],
					linkIndex = linkIndex
				}

				validChats[#validChats + 1] = chatEntryData
			end
		end
	end

	-- 从有效对话中随机选一条播报
	if #validChats > 0 then
		local selectedChat = validChats[math.random(#validChats)]
		local voiceKey = "link" .. selectedChat.linkIndex

		selectedChat.cp:DispatchVoice(voiceKey)
		selectedChat.cp:DispatchChat(selectedChat.content, 3, voiceKey)
	end
end

--- 单位HP更新事件处理：向舰队内所有单位触发HP变化相关的Buff
--- @param event table 事件数据（包含Dispatcher和Data.dHP）
function BattleFleetVO.onUnitUpdateHP(self, event)
	local dispatcher = event.Dispatcher
	local dHP = event.Data.dHP

	-- 遍历全部单位，触发友方HP更新Buff；非事件源的单位额外触发队友HP更新Buff
	for _, unit in ipairs(self._unitList) do
		unit:TriggerBuff(BattleConst.BuffEffectType.ON_FRIENDLY_HP_RATIO_UPDATE, {
			unit = dispatcher,
			dHP = dHP
		})

		if unit ~= dispatcher then
			unit:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_HP_RATIO_UPDATE, {
				unit = dispatcher,
				dHP = dHP
			})
		end
	end
end

--- 设置潜艇单位数据列表
--- @param subData table 潜艇数据
function BattleFleetVO.SetSubUnitData(self, subData)
	self._subUntiDataList = subData
end

--- 获取潜艇单位数据列表
--- @return table subUnitDataList
function BattleFleetVO.GetSubUnitData(self)
	return self._subUntiDataList
end

--- 添加潜艇单位到舰队（自动潜艇模式）：初始化氧气、设置相位切换器
--- @param subUnit BattleUnitVO 潜艇单位
function BattleFleetVO.AddSubMarine(self, subUnit)
	subUnit:InitOxygen()

	local template = subUnit:GetTemplate()
	local phaseSwitcher = ys.Battle.BattleUnitPhaseSwitcher.New(subUnit)

	-- 获取突击持续时间的内联函数
	local function getRaidDuration()
		return subUnit:GetRaidDuration()
	end

	-- 根据潜艇属性生成相位模板数据
	phaseSwitcher:SetTemplateData(BattleDataFunction.GeneratePlayerSubmarinPhase(
		self._subAttackBaseLine,
		self._subRetreatBaseLine,
		subUnit:GetAttrByName("raidDist"),
		getRaidDuration,
		subUnit:GetAttrByName("oxyAtkDuration")
	))

	self._unitList[#self._unitList + 1] = subUnit
	self._subList[#self._subList + 1] = subUnit

	subUnit:SetFleetVO(self)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
end

--- 添加手动潜艇单位
--- @param subUnit BattleUnitVO 手动潜艇单位
function BattleFleetVO.AddManualSubmarine(self, subUnit)
	self._unitList[#self._unitList + 1] = subUnit
	self._manualSubList[#self._manualSubList + 1] = subUnit
	self._manualSubBench[#self._manualSubBench + 1] = subUnit
	self._maxCount = self._maxCount + 1

	subUnit:InitOxygen()
	subUnit:SetFleetVO(self)
	subUnit:SetMotion(self._motionVO)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
end

--- 获取潜艇列表
--- @return table subList
function BattleFleetVO.GetSubList(self)
	return self._subList
end

--- 切换手动潜艇：将当前手动潜艇换下，从预备席弹出一个新的上场
function BattleFleetVO.ShiftManualSub(self)
	local newPos

	-- 有当前手动潜艇时：保存位置并清理其鱼雷武器
	if self._manualSubUnit then
		local torpedoList = self._manualSubUnit:GetTorpedoList()

		for _, torpedoWeapon in ipairs(torpedoList) do
			if torpedoWeapon:IsAttacking() then
				self:CancelTorpedo()
			end

			self._torpedoWeaponVO:RemoveWeapon(torpedoWeapon)
		end

		if self._manualSubUnit:IsAlive() then
			table.insert(self._manualSubBench, self._manualSubUnit)
		end

		newPos = self._motionVO:GetPos():Clone()
	else
		-- 首次切换：以预备席第一艘潜艇位置为准
		newPos = self._manualSubList[1]:GetPosition():Clone()
	end

	-- 从预备席弹出下一艘潜艇
	self._manualSubUnit = table.remove(self._manualSubBench, 1)
	self._scoutList[1] = self._manualSubUnit

	-- 构建新的单位排序列表
	local newUnitOrder = {}

	-- 先加入预备席中其他单位在unitList中的索引
	for _, benchUnit in ipairs(self._manualSubBench) do
		for unitIndex, unitInList in ipairs(self._unitList) do
			if unitInList == benchUnit then
				table.insert(newUnitOrder, unitIndex)

				break
			end
		end
	end

	-- 再将当前手动潜艇的索引插入列表首位
	for unitIndex, unitInList in ipairs(self._unitList) do
		if unitInList == self._manualSubUnit then
			table.insert(newUnitOrder, 1, unitIndex)

			break
		end
	end

	-- 刷新阵型并设置新潜艇位置
	self:refreshFleetFormation(newUnitOrder)
	self._manualSubUnit:SetMainUnitStatic(false)
	self._manualSubUnit:SetPosition(newPos)
	self:UpdateMotion()
	self._submarineSpecialVO:SetUseable(false)

	-- 检查新潜艇是否有特殊技能Buff，若有则启用特殊技能VO
	local buffList = self._manualSubUnit:GetBuffList()

	for _, buff in pairs(buffList) do
		if buff:IsSubmarineSpecial() then
			self._submarineSpecialVO:SetCount(1)
			self._submarineSpecialVO:SetUseable(true)

			break
		end
	end

	-- 切换到自由下潜状态
	self:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE)
	self._torpedoWeaponVO:Reset()

	-- 将新潜艇的鱼雷武器注册到舰队鱼雷VO
	-- 优先加入非过热状态的鱼雷，再追加过热状态的
	local torpedoList = self._manualSubUnit:GetTorpedoList()

	for _, torpedoWeapon in ipairs(torpedoList) do
		if torpedoWeapon:GetCurrentState() ~= torpedoWeapon.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(torpedoWeapon)
		end
	end

	for _, torpedoWeapon in ipairs(torpedoList) do
		if torpedoWeapon:GetCurrentState() == torpedoWeapon.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(torpedoWeapon)
		end
	end

	-- 预备席中剩余潜艇设为静止/待命状态
	for benchIndex, benchUnit in ipairs(self._manualSubBench) do
		benchUnit:SetPosition(BattleConfig.SUB_BENCH_POS[benchIndex])
		benchUnit:SetMainUnitStatic(true)
		benchUnit:ChangeOxygenState(ys.Battle.OxyState.STATE_FREE_BENCH)
	end

	self._submarineShiftVO:ResetCurrent()

	-- 预备席无剩余则禁用切换按钮
	if #self._manualSubBench == 0 then
		self._submarineShiftVO:SetActive(false)
	end
end

--- 切换手动潜艇状态（下潜/上浮等）
--- @param state number 目标氧气状态
--- @param resetCD boolean 是否重置所有子VO的冷却
function BattleFleetVO.ChangeSubmarineState(self, state, resetCD)
	if not self._manualSubUnit then
		return
	end

	self._manualSubUnit:ChangeOxygenState(state)

	if resetCD then
		-- 重置所有子VO的CD
		for _, subVO in ipairs(self._submarineVOList) do
			subVO:ResetCurrent()
		end

		-- 若切换VO未过载 或 剩余时间 > 下潜CD，则重置切换CD
		local remainingTime = self._submarineShiftVO:GetMax() - self._submarineShiftVO:GetCurrent()

		if self._submarineShiftVO:IsOverLoad() and remainingTime > BattleConfig.SR_CONFIG.DIVE_CD then
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

--- 手动潜艇加速（向右方向加速）
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

--- 向舰队添加独立声呐
--- @param id number 声呐ID
--- @param level number 声呐等级
function BattleFleetVO.AppendIndieSonar(self, id, level)
	local sonar = ys.Battle.BattleIndieSonar.New(self, id, level)

	sonar:SwitchHost(self._motionReferenceUnit)

	self._indieSonarList[sonar] = true

	sonar:Detect()
end

--- 从舰队移除独立声呐
--- @param sonar BattleIndieSonar 要移除的声呐对象
function BattleFleetVO.RemoveIndieSonar(self, sonar)
	for existingSonar, _ in pairs(self._indieSonarList) do
		if sonar == existingSonar then
			self._indieSonarList[existingSonar] = nil

			break
		end
	end
end

--- 附加舰队Buff（若已存在则叠加层数，否则新建）
--- @param buff BattleBuff 要附加的Buff
function BattleFleetVO.AttachFleetBuff(self, buff)
	local buffID = buff:GetID()
	local existingBuff = self:GetFleetBuff(buffID)

	if existingBuff then
		existingBuff:Stack(self)
	else
		self._buffList[buffID] = buff

		buff:Attach(self)
	end
end

--- 移除舰队Buff
--- @param id number Buff ID
function BattleFleetVO.RemoveFleetBuff(self, id)
	local buff = self:GetFleetBuff(id)

	if buff then
		buff:Remove()
	end
end

--- 根据ID获取舰队Buff
--- @param id number Buff ID
--- @return BattleBuff|nil buff
function BattleFleetVO.GetFleetBuff(self, id)
	return self._buffList[id]
end

--- 获取舰队所有Buff列表
--- @return table buffList
function BattleFleetVO.GetFleetBuffList(self)
	return self._buffList
end

--- 干扰状态切换：启用/禁用蓄力武器、鱼雷、空袭武器VO的干扰效果
--- @param isJamming boolean 是否启用干扰
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

--- 致盲/解除致盲舰队
--- @param isBlind boolean 是否致盲
function BattleFleetVO.Blinding(self, isBlind)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_BLIND, {
		isBlind = isBlind
	}))
end

--- 刷新舰队视野线
function BattleFleetVO.UpdateHorizon(self)
	self:DispatchEvent(ys.Event.New(BattleEvent.FLEET_HORIZON_UPDATE, {}))
end

--- 自动/手动模式切换：触发所有单位的ON_AUTOBOT或ON_MANUAL Buff
--- @param isAutoBot boolean 是否为自动模式
function BattleFleetVO.AutoBotUpdated(self, isAutoBot)
	local triggerType = isAutoBot and BattleConst.BuffEffectType.ON_AUTOBOT or BattleConst.BuffEffectType.ON_MANUAL

	for _, unit in ipairs(self._unitList) do
		unit:TriggerBuff(triggerType)
	end
end

--- 强制所有隐身单位暴露（暴露条拉满）
function BattleFleetVO.CloakFatalExpose(self)
	for _, unit in ipairs(self._cloakList) do
		unit:GetCloak():ForceToMax()
	end
end

--- 隐身单位进入视野：增加暴露速度
--- @param exposeSpeed number 暴露速度增量
function BattleFleetVO.CloakInVision(self, exposeSpeed)
	for _, unit in ipairs(self._cloakList) do
		unit:GetCloak():AppendExposeSpeed(exposeSpeed)
	end
end

--- 隐身单位离开视野：暴露速度归零
function BattleFleetVO.CloakOutVision(self)
	for _, unit in ipairs(self._cloakList) do
		unit:GetCloak():AppendExposeSpeed(0)
	end
end

--- 为单位附加隐身组件（若尚未有）
--- @param unit BattleUnitVO 要附加隐身的单位
function BattleFleetVO.AttachCloak(self, unit)
	if not unit:GetCloak() then
		unit:InitCloak()

		self._cloakList[#self._cloakList + 1] = unit
	end
end

--- 启用夜间隐身瞄准偏差组件
function BattleFleetVO.AttachNightCloak(self)
	self._scoutAimBias = ys.Battle.BattleUnitAimBiasComponent.New()

	self._scoutAimBias:ConfigRangeFormula(BattleFormulas.CalculateMaxAimBiasRange, BattleFormulas.CalculateBiasDecay)
	self._scoutAimBias:Active(self._scoutAimBias.STATE_ACTIVITING)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIM_BIAS, {
		aimBias = self._scoutAimBias
	}))
end

--- 获取舰队瞄准偏差组件
--- @return BattleUnitAimBiasComponent|nil scoutAimBias
function BattleFleetVO.GetFleetBias(self)
	return self._scoutAimBias
end
