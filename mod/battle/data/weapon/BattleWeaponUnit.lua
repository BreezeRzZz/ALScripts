ys = ys or {}
-- var_0_0 -> ys
-- var_0_1 -> BattleConst
-- var_0_2 -> BattleConfig
-- var_0_3 -> BattleFormulas
-- var_0_4 -> WeaponSuppressType
-- var_0_5 -> WeaponSearchType
-- var_0_6 -> BattleDataFunction
-- var_0_7 -> BattleAttr
-- var_0_8 -> BattleTargetChoise
-- var_0_9 -> BattleWeaponUnit
local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleFormulas = ys.Battle.BattleFormulas
local WeaponSuppressType = BattleConst.WeaponSuppressType
local WeaponSearchType = BattleConst.WeaponSearchType
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleWeaponUnit = class("BattleWeaponUnit")

ys.Battle.BattleWeaponUnit = BattleWeaponUnit
BattleWeaponUnit.__name = "BattleWeaponUnit"
BattleWeaponUnit.INTERNAL = "internal"
BattleWeaponUnit.EXTERNAL = "external"
BattleWeaponUnit.EMITTER_NORMAL = "BattleBulletEmitter"
BattleWeaponUnit.EMITTER_SHOTGUN = "BattleShotgunEmitter"
BattleWeaponUnit.STATE_DISABLE = "DISABLE"
BattleWeaponUnit.STATE_READY = "READY"
BattleWeaponUnit.STATE_PRECAST = "PRECAST"
BattleWeaponUnit.STATE_PRECAST_FINISH = "STATE_PRECAST_FINISH"
BattleWeaponUnit.STATE_ATTACK = "ATTACK"
BattleWeaponUnit.STATE_OVER_HEAT = "OVER_HEAT"
-- arg_1_0 -> self
function BattleWeaponUnit.Ctor(self)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._currentState = self.STATE_READY
	self._equipmentIndex = -1
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._tempEmittersList = {}
	self._dumpedEmittersList = {}
	self._reloadFacotrList = {}
	self._diveEnabled = true
	self._comboIDList = {}
	self._jammingTime = 0
	self._reloadBoostList = {}
	self._CLDCount = 0
	self._damageSum = 0
	self._CTSum = 0
	self._ACCSum = 0
end
-- arg_2_0 -> self
function BattleWeaponUnit.HostOnEnemy(self)
	self._hostOnEnemy = true
end
-- arg_3_0 -> self
-- arg_3_1 -> potential
	-- potential指的是武器效率
function BattleWeaponUnit.SetPotentialFactor(self, potential)
	self._potential = potential

	if self._correctedDMG then
		self._correctedDMG = BattleFormulas.WeaponDamagePreCorrection(self)
	end
end
-- arg_4_0 -> self
function BattleWeaponUnit.GetEquipmentLabel(self)
	return self._equipmentLabelList or {}
end
-- arg_5_0 -> self
-- arg_5_1 -> labelList
function BattleWeaponUnit.SetEquipmentLabel(self, labelList)
	self._equipmentLabelList = labelList
end
-- arg_6_0 -> self
-- arg_6_1 -> template
	-- 相关参数说明
		-- 可到weapon_property.lua中查看更多对应字段
	-- potential: 武器效率
	-- maxRangeSqr(range): 最大射程
	-- minRangeSqr(min_range): 最小射程
	-- fireFXFlag(fire_fx_loop_type): 开火特效类型
	-- oxyList(oxy_type): 武器水上/水下适用类型
	-- bulletList(bullet_ID): 子弹ID列表
	-- barrage_ID: 弹幕ID列表
	-- GCD(recover_time): 公共CD时间
	-- preCastInfo(precast_param): 前摇(precast)参数
	-- correctedDMG: 经过修正的伤害，可以当成武器标伤 * 武器效率 * 修正比例
	-- convertedAtkAttr: 经过修正的攻击属性，实际是属性效率
function BattleWeaponUnit.SetTemplateData(self, template)
	self._potential = self._potential or 1
	self._tmpData = template
	self._maxRangeSqr = template.range
	self._minRangeSqr = template.min_range
	self._fireFXFlag = template.fire_fx_loop_type
	self._oxyList = template.oxy_type
	self._bulletList = template.bullet_ID
	self._majorEmitterList = {}

	self:ShiftBarrage(template.barrage_ID)

	self._GCD = template.recover_time
	self._preCastInfo = template.precast_param
	self._correctedDMG = BattleFormulas.WeaponDamagePreCorrection(self)
	self._convertedAtkAttr = BattleFormulas.WeaponAtkAttrPreRatio(self)

	self:FlushReloadMax(1)
end
-- arg_7_0 -> self
-- arg_7_1 -> barrageID
-- arg_7_2 -> index
-- arg_7_3 -> emitterType(NORMAL/SHOTGUN)
-- arg_7_4 -> spawnFunc
-- arg_7_5 -> stopFunc
function BattleWeaponUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	-- var_7_0 -> defaultSpawnFunc
	-- arg_8_0 -> offsetX
	-- arg_8_1 -> offsetZ
	-- arg_8_2 -> barrageAngle
	-- arg_8_3 -> isOffsetPriority
	-- arg_8_4 -> target(BattleUnit)
	local function defaultSpawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		-- var_8_0 -> bulletID
		-- var_8_1 -> bullet(BattleBulletUnit)
		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, target, BattleWeaponUnit.INTERNAL)

		bullet:SetOffsetPriority(isOffsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)

		if self._tmpData.aim_type == BattleConst.WeaponAimType.AIM and target ~= nil then
			bullet:SetRotateInfo(target:GetBeenAimedPosition(), self:GetBaseAngle(), barrageAngle)
		else
			bullet:SetRotateInfo(nil, self:GetBaseAngle(), barrageAngle)
		end

		self:DispatchBulletEvent(bullet)

		return bullet
	end

	-- var_7_1 -> defaultStopFunc
	local function defaultStopFunc()
		-- iter_9_0 -> _
		-- iter_9_1 -> emitter(BattleBulletEmitter)
		for _, emitter in ipairs(self._majorEmitterList) do
			if emitter:GetState() ~= emitter.STATE_STOP then
				return
			end
		end

		self:EnterCoolDown()
	end

	emitterType = emitterType or BattleWeaponUnit.EMITTER_NORMAL

	-- var_7_2 -> emitter(BattleBulletEmitter/BattleShotgunEmitter)
	local emitter = ys.Battle[emitterType].New(spawnFunc or defaultSpawnFunc, stopFunc or defaultStopFunc, barrageID)

	self._majorEmitterList[#self._majorEmitterList + 1] = emitter

	return emitter
end
-- arg_10_0 -> self
function BattleWeaponUnit.interruptAllEmitter(self)
	if self._majorEmitterList then
		-- iter_10_0 -> _
		-- iter_10_1 -> emitter
		for _, emitter in ipairs(self._majorEmitterList) do
			emitter:Interrupt()
		end
	end
	-- iter_10_2 -> _
	-- iter_10_3 -> emitterList
	for _, emitterList in ipairs(self._tempEmittersList) do
		-- iter_10_4 -> _
		-- iter_10_5 -> emitter
		for _, emitter in ipairs(emitterList) do
			emitter:Interrupt()
		end
	end
	-- iter_10_6 -> _
	-- iter_10_7 -> emitterList
	for _, emitterList in ipairs(self._dumpedEmittersList) do
		-- iter_10_8 -> _
		-- iter_10_9 -> emitter
		for _, emitter in ipairs(emitterList) do
			emitter:Interrupt()
		end
	end
end
-- arg_11_0 -> self
function BattleWeaponUnit.cacheSectorData(self)
	-- var_11_0 -> halfAngle
	local halfAngle = self:GetAttackAngle() / 2

	self._upperEdge = math.deg2Rad * halfAngle
	self._lowerEdge = -1 * self._upperEdge
	-- var_11_1 -> axisAngle
	local axisAngle = math.deg2Rad * self._tmpData.axis_angle

	if self:GetDirection() == BattleConst.UnitDir.LEFT then
		self._normalizeOffset = math.pi - axisAngle
	elseif self:GetDirection() == BattleConst.UnitDir.RIGHT then
		self._normalizeOffset = axisAngle
	end

	self._wholeCircle = math.pi - self._normalizeOffset
	self._negativeCircle = -math.pi - self._normalizeOffset
	self._wholeCircleNormalizeOffset = self._normalizeOffset - math.pi * 2
	self._negativeCircleNormalizeOffset = self._normalizeOffset + math.pi * 2
end
-- arg_12_0 -> self
function BattleWeaponUnit.cacheSquareData(self)
	self._frontRange = self._tmpData.angle
	self._backRange = self._tmpData.axis_angle
	self._upperRange = self._tmpData.min_range
	self._lowerRange = self._tmpData.range
end
-- arg_13_0 -> self
-- arg_13_1 -> modelID
function BattleWeaponUnit.SetModelID(self, modelID)
	self._modelID = modelID
end
-- arg_14_0 -> self
-- arg_14_1 -> skinID
function BattleWeaponUnit.SetSkinData(self, skinID)
	self._skinID = skinID
	-- var_14_0 -> bulletName
	-- var_14_1 -> derivateBullet
	-- var_14_2 -> derivateTorpedo
	-- var_14_3 -> derivateBoom
	-- var_14_4 -> fireFXName
	-- var_14_5 -> hitFXName
		-- 此处应为BattleUnitDataFunction的GetEquipSkin函数
		-- 可能会自动获取需要的DataFunction？
	local bulletName, derivateBullet, derivateTorpedo, derivateBoom, fireFXName, hitFXName = BattleDataFunction.GetEquipSkin(self._skinID)

	self:SetModelID(bulletName)

	if fireFXName ~= "" then
		self._skinFireFX = fireFXName
	end

	if hitFXName ~= "" then
		self._skinHitFX = hitFXName
	end

	-- var_14_6 -> hitSFX
	-- var_14_7 -> missSFX
		-- 同理是BattleUnitDataFunction的GetEquipSkinSFX函数
	local hitSFX, missSFX = BattleDataFunction.GetEquipSkinSFX(self._skinID)

	self._skinHixSFX = hitSFX
	self._skinMissSFX = missSFX
end
-- arg_15_0 -> self
-- arg_15_1 -> derivateSkinID
function BattleWeaponUnit.SetDerivateSkin(self, derivateSkinID)
	self._derivateSkinID = derivateSkinID
	-- var_15_0 -> bulletName
	-- var_15_1 -> derivateBullet
	-- var_15_2 -> derivateTorpedo
	-- var_15_3 -> derivateBoom
	-- var_15_4 -> fireFXName
	-- var_15_5 -> hitFXName
	local bulletName, derivateBullet, derivateTorpedo, derivateBoom, fireFXName, hitFXName = BattleDataFunction.GetEquipSkin(self._derivateSkinID)

	self._derivateBullet = derivateBullet
	self._derivateTorpedo = derivateTorpedo
	self._derivateBoom = derivateBoom
	self._derviateHitFX = hitFXName
	-- var_15_6 -> hitSFX
	-- var_15_7 -> missSFX
	local hitSFX, missSFX = BattleDataFunction.GetEquipSkinSFX(self._derivateSkinID)

	self._skinHixSFX = hitSFX
	self._skinMissSFX = missSFX
end
-- arg_16_0 -> self
function BattleWeaponUnit.GetSkinID(self)
	return self._skinID
end
-- arg_17_0 -> self
-- arg_17_1 -> bullet
-- arg_17_2 -> bulletID
function BattleWeaponUnit.setBulletSkin(self, bullet, bulletID)
	if self._derivateSkinID then
		-- var_17_0 -> bulletType
			-- 这里是BattleBulletDataFunction的GetBulletTmpDataFromID函数 
		local bulletType = BattleDataFunction.GetBulletTmpDataFromID(bulletID).type

		if bulletType == BattleConst.BulletType.BOMB and self._derivateBoom ~= "" then
			bullet:SetModleID(self._derivateBoom, nil, self._derviateHitFX)
		elseif bulletType == BattleConst.BulletType.TORPEDO and self._derivateTorpedo ~= "" then
			bullet:SetModleID(self._derivateTorpedo, nil, self._derviateHitFX)
		elseif self._derivateBullet ~= "" then
			bullet:SetModleID(self._derivateBullet, nil, self._derviateHitFX)
		end

		bullet:SetSFXID(self._skinHixSFX, self._skinMissSFX)
	elseif self._modelID then
		-- var_17_1 -> mirrorSkin
			-- 装备皮肤
		local mirrorSkin = 0

		if self._skinID then
			mirrorSkin = BattleDataFunction.GetEquipSkinDataFromID(self._skinID).mirror
		end

		bullet:SetModleID(self._modelID, mirrorSkin, self._skinHitFX)
		bullet:SetSFXID(self._skinHixSFX, self._skinMissSFX)
	end
end
-- arg_18_0 -> self
-- arg_18_1 -> srcEquipID
function BattleWeaponUnit.SetSrcEquipmentID(self, srcEquipID)
	self._srcEquipID = srcEquipID
end
--arg_19_0 -> self
--arg_19_1 -> equipmentIndex
function BattleWeaponUnit.SetEquipmentIndex(self, equipmentIndex)
	self._equipmentIndex = equipmentIndex
end
-- arg_20_0 -> self
function BattleWeaponUnit.GetEquipmentIndex(self)
	return self._equipmentIndex
end
-- arg_21_0 -> self
-- arg_21_1 -> host
function BattleWeaponUnit.SetHostData(self, host)
	self._host = host
	self._hostUnitType = self._host:GetUnitType()
	self._hostIFF = host:GetIFF()

	if self._tmpData.search_type == WeaponSearchType.SECTOR then
		self:cacheSectorData()

		self.outOfFireRange = self.IsOutOfAngle
		self.IsOutOfFireArea = self.IsOutOfSector
	elseif self._tmpData.search_type == WeaponSearchType.SQUARE then
		self:cacheSquareData()

		self.outOfFireRange = self.IsOutOfSquare
		self.IsOutOfFireArea = self.IsOutOfSquare
	elseif self._tmpData.search_type == WeaponSearchType.STRIKE then
		self:cacheSquareData()

		self.outOfFireRange = self.IsOutOfSquare
	end

	if self:GetDirection() == BattleConst.UnitDir.RIGHT then
		self._baseAngle = 0
	else
		self._baseAngle = 180
	end
end
-- arg_22_0 -> self
-- arg_22_1 -> standHost
function BattleWeaponUnit.SetStandHost(self, standHost)
	self._standHost = standHost
end
-- arg_23_0 -> self
-- arg_23_1 -> GCD
function BattleWeaponUnit.OverrideGCD(self, GCD)
	self._GCD = GCD
end
-- arg_24_0 -> self
function BattleWeaponUnit.updateMovementInfo(self)
	self._hostPos = self._host:GetPosition()
end
--arg_25_0 -> self
function BattleWeaponUnit.GetWeaponId(self)
	return self._tmpData.id
end
-- arg_26_0 -> self
function BattleWeaponUnit.GetTemplateData(self)
	return self._tmpData
end
-- arg_27_0 -> self
function BattleWeaponUnit.GetType(self)
	return self._tmpData.type
end
-- arg_28_0 -> self
function BattleWeaponUnit.GetPotential(self)
	return self._potential or 1
end
-- arg_29_0 -> self
function BattleWeaponUnit.GetSrcEquipmentID(self)
	return self._srcEquipID
end
-- arg_30_0 -> self
function BattleWeaponUnit.SetFixedFlag(self)
	self._isFixedWeapon = true
end
-- arg_31_0 -> self
function BattleWeaponUnit.IsFixedWeapon(self)
	return self._isFixedWeapon
end
-- arg_32_0 -> self
function BattleWeaponUnit.IsAttacking(self)
	return self._currentState == BattleWeaponUnit.STATE_ATTACK or self._currentState == self.STATE_PRECAST
end
-- arg_33_0 -> self
function BattleWeaponUnit.Update(self)
	self:UpdateReload()

	if not self._diveEnabled then
		return
	end

	if self._currentState == self.STATE_READY then
		self:updateMovementInfo()

		if self._tmpData.suppress == WeaponSuppressType.SUPPRESSION or self:CheckPreCast() then
			if self._preCastInfo.time == nil or not self._hostOnEnemy then
				self._currentState = self.STATE_PRECAST_FINISH
			else
				self:PreCast()
			end
		end
	end

	if self._currentState == self.STATE_PRECAST_FINISH then
		self:updateMovementInfo()
		self:Fire(self:Tracking())
	end
end
-- arg_34_0 -> self
function BattleWeaponUnit.CheckReloadTimeStamp(self)
	return self._CDstartTime and self:GetReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime()
end
-- arg_35_0 -> self
function BattleWeaponUnit.UpdateReload(self)
	if self._CDstartTime and not self._jammingStartTime then
		if self:GetReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime() then
			self:handleCoolDown()
		else
			return
		end
	end
end
-- arg_36_0 -> self
function BattleWeaponUnit.CheckPreCast(self)
	if self._tmpData.search_type == WeaponSearchType.STRIKE then
		-- var_36_0 -> strikePoint
		local strikePoint = self._host:GetStrikePoint()

		return not self:IsPointOutOfSquare(strikePoint)
	else
		-- iter_36_0 -> _
		-- iter_36_1 -> candidate
		for _, candidate in pairs(self:GetFilteredList()) do
			return true
		end
	end

	return false
end
-- arg_37_0 -> self
function BattleWeaponUnit.ChangeDiveState(self)
	if self._host:GetOxyState() then
		-- var_37_0 -> weaponType
		local weaponType = self._host:GetOxyState():GetWeaponType()
		-- iter_37_0 -> _
		-- iter_37_1 -> oxyType
		for _, oxyType in ipairs(self._oxyList) do
			if table.contains(weaponType, oxyType) then
				self._diveEnabled = true

				return
			end
		end

		self._diveEnabled = false
	end
end
-- arg_38_0 -> self
function BattleWeaponUnit.getTrackingHost(self)
	return self._host
end

BattleWeaponUnit.TrackingFunc = {
	farthest = BattleWeaponUnit.TrackingFarthest,
	leastHP = BattleWeaponUnit.TrackingLeastHP
}
-- arg_39_0 -> self
function BattleWeaponUnit.Tracking(self)
	if self._tmpData.search_type == WeaponSearchType.STRIKE then
		return nil
	end
	-- var_39_0 -> targetTag
	local targetTag = BattleAttr.GetCurrentTargetSelect(self._host)
	-- var_39_1 -> target
	local target
	-- var_39_2 -> filteredList
	local filteredList = self:GetFilteredList()

	if targetTag then
		-- var_39_3 -> trackingFunc
		local trackingFunc = BattleWeaponUnit.TrackingFunc[targetTag]

		if trackingFunc then
			target = trackingFunc(self, filteredList)
		else
			target = self:TrackingTag(filteredList, targetTag)
		end
	else
		target = self:TrackingNearest(filteredList)
	end

	if target and BattleAttr.GetCurrentGuardianID(target) then
		-- var_39_4 -> guardianID
		local guardianID = BattleAttr.GetCurrentGuardianID(target)

		-- iter_39_0 -> _
		-- iter_39_1 -> candidate
		for _, candidate in ipairs(filteredList) do
			if candidate:GetUniqueID() == guardianID then
				target = candidate

				break
			end
		end
	end

	return target
end
-- arg_40_0 -> self
function BattleWeaponUnit.GetFilteredList(self)
	-- var_40_0 -> filteredList
	local filteredList = self:FilterTarget()

	if self._tmpData.search_type == WeaponSearchType.SECTOR then
		filteredList = self:FilterRange(filteredList)
		filteredList = self:FilterAngle(filteredList)
	elseif self._tmpData.search_type == WeaponSearchType.SQUARE then
		filteredList = self:FilterSquare(filteredList)
	end

	return filteredList
end
-- arg_41_0 -> self
-- arg_41_1 -> maxRange
-- arg_41_2 -> fixBulletRange
-- arg_41_3 -> minRange
-- arg_41_4 -> bulletRangeOffset
function BattleWeaponUnit.FixWeaponRange(self, maxRange, fixBulletRange, minRange, bulletRangeOffset)
	self._maxRangeSqr = maxRange or self._tmpData.range
	self._minRangeSqr = minRange or self._tmpData.min_range
	self._fixBulletRange = fixBulletRange
	self._bulletRangeOffset = bulletRangeOffset
end
-- arg_42_0 -> self
function BattleWeaponUnit.GetWeaponMaxRange(self)
	return self._maxRangeSqr
end
-- arg_43_0 -> self
function BattleWeaponUnit.GetWeaponMinRange(self)
	return self._minRangeSqr
end
-- arg_44_0 -> self
function BattleWeaponUnit.GetFixBulletRange(self)
	return self._fixBulletRange, self._bulletRangeOffset
end
-- arg_45_0 -> self
-- arg_45_1 -> filteredList
function BattleWeaponUnit.TrackingNearest(self, filteredList)
	-- var_45_0 -> minDistance
	-- var_45_1 -> target
	local minDistance = self._maxRangeSqr
	local target
	-- iter_45_0 -> _
	-- iter_45_1 -> candidate
	for _, candidate in ipairs(filteredList) do
		-- var_45_2 -> distance
		local distance = self:getTrackingHost():GetDistance(candidate)

		if distance <= minDistance then
			minDistance = distance
			target = candidate
		end
	end

	return target
end
-- arg_46_0 -> self
-- arg_46_1 -> filteredList
function BattleWeaponUnit.TrackingFarthest(self, filteredList)
	-- var_46_0 -> maxDistance
	-- var_46_1 -> target
	local maxDistance = 0
	local target
	-- iter_46_0 -> _
	-- iter_46_1 -> candidate
	for _, candidate in ipairs(filteredList) do
		-- var_46_2 -> distance
		local distance = self:getTrackingHost():GetDistance(candidate)

		if maxDistance < distance then
			maxDistance = distance
			target = candidate
		end
	end

	return target
end
-- arg_47_0 -> self
-- arg_47_1 -> filteredList
function BattleWeaponUnit.TrackingLeastHP(self, filteredList)
	-- var_47_0 -> minHP
	-- var_47_1 -> target
	local minHP = math.huge
	local target
	-- iter_47_0 -> _
	-- iter_47_1 -> candidate
	for _, candidate in ipairs(filteredList) do
		-- var_47_2 -> candidateHP
		local candidateHP = candidate:GetCurrentHP()

		if candidateHP < minHP then
			target = candidate
			minHP = candidateHP
		end
	end

	return target
end
-- arg_48_0 -> self
-- arg_48_1 -> filteredList
function BattleWeaponUnit.TrackingRandom(self, filteredList)
	-- var_48_0 -> shuffledList
	local shuffledList = {}
	-- iter_48_0 -> _
	-- iter_48_1 -> candidate
		-- 这里是利用了pairs的无序性来打乱顺序
		-- 但严格来说，这并不是一个真正的随机打乱...
	for _, candidate in pairs(filteredList) do
		table.insert(shuffledList, candidate)
	end
	-- var_48_1 -> candidateCount
	local candidateCount = #shuffledList

	if candidateCount == 0 then
		return nil
	else
		return shuffledList[math.random(candidateCount)]
	end
end
-- arg_49_0 -> self
-- arg_49_1 -> filteredList
-- arg_49_2 -> targetTag
function BattleWeaponUnit.TrackingTag(self, filteredList, targetTag)
	-- var_49_0 -> tagedList
	local tagedList = {}
	-- iter_49_0 -> _
	-- iter_49_1 -> candidate
	for _, candidate in ipairs(filteredList) do
		if candidate:ContainsLabelTag({
			targetTag
		}) then
			table.insert(tagedList, candidate)
		end
	end

	if #tagedList == 0 then
		return self:TrackingNearest(filteredList)
	else
		return tagedList[math.random(#tagedList)]
	end
end
-- arg_50_0 -> self
function BattleWeaponUnit.FilterTarget(self)
	-- var_50_0 -> enemyList
	-- var_50_1 -> filteredList
	-- var_50_2 -> i
	-- var_50_3 -> search_condition
	local enemyList = BattleTargetChoise.LegalWeaponTarget(self._host)
	local filteredList = {}
	local i = 1
	local search_condition = self._tmpData.search_condition

	-- iter_50_0 -> _
	-- iter_50_1 -> enemy
	for _, enemy in pairs(enemyList) do
		-- var_50_4 -> oxyState
		local oxyState = enemy:GetCurrentOxyState()

		if BattleAttr.IsCloak(enemy) then
			-- block empty
		elseif not table.contains(search_condition, oxyState) then
			-- block empty
		else
			-- var_50_5 -> enemyTrackable
			local enemyTrackable = true

			if oxyState == BattleConst.OXY_STATE.FLOAT then
				-- block empty
			elseif oxyState == BattleConst.OXY_STATE.DIVE and not enemy:IsRunMode() and not enemy:GetDiveDetected() and enemy:GetDiveInvisible() then
				enemyTrackable = false
			end

			if enemyTrackable then
				filteredList[i] = enemy
				i = i + 1
			end
		end
	end

	return filteredList
end
-- arg_51_0 -> self
-- arg_51_1 -> list
function BattleWeaponUnit.FilterAngle(self, list)
	if self:GetAttackAngle() >= 360 then
		return list
	end

	-- iter_51_0 -> i
	for i = #list, 1, -1 do
		if self:IsOutOfAngle(list[i]) then
			table.remove(list, i)
		end
	end

	return list
end
-- arg_52_0 -> self
-- arg_52_1 -> list
function BattleWeaponUnit.FilterRange(self, list)
	-- iter_52_0 -> i
	for i = #list, 1, -1 do
		if self:IsOutOfRange(list[i]) then
			table.remove(list, i)
		end
	end

	return list
end
-- arg_53_0 -> self
-- arg_53_1 -> list
function BattleWeaponUnit.FilterSquare(self, list)
	-- var_53_0 -> direction
	-- var_53_1 -> lineX
		-- 这里是计算出正方形的边界线位置
		-- 对于己方，是左边界线；对于敌方，是右边界线
	-- var_53_2 -> areaArgs
	local direction = self:GetDirection()
	local lineX = self._host:GetPosition().x + self._backRange * direction * -1
	local areaArgs = {
		lineX = lineX,
		dir = direction
	}
	-- var_53_3 -> filteredList1
	-- var_53_4 -> filteredList2
	local filteredList1 = BattleTargetChoise.TargetInsideArea(self._host, areaArgs, list)
	local filteredList2 = BattleTargetChoise.TargetWeightiest(self._host, nil, filteredList1)

	-- iter_53_0 -> i
	for i = #list, 1, -1 do
		if self:IsOutOfSquare(list[i]) then
			table.remove(list, i)
		end
	end
	-- iter_53_1 -> i
	for i = #list, 1, -1 do
		if not table.contains(filteredList2, list[i]) then
			table.remove(list, i)
		end
	end

	return list
end
-- arg_54_0 -> self
function BattleWeaponUnit.GetAttackAngle(self)
	return self._tmpData.angle
end
-- arg_55_0 -> self
-- arg_55_1 -> candidate
function BattleWeaponUnit.IsOutOfAngle(self, candidate)
	if self:GetAttackAngle() >= 360 then
		return false
	end
	-- var_55_0 -> position
	-- var_55_1 -> angleToCandidate
	local position = candidate:GetPosition()
	local angleToCandidate = math.atan2(position.z - self._hostPos.z, position.x - self._hostPos.x)

	if angleToCandidate > self._wholeCircle then
		angleToCandidate = angleToCandidate + self._wholeCircleNormalizeOffset
	elseif angleToCandidate < self._negativeCircle then
		angleToCandidate = angleToCandidate + self._negativeCircleNormalizeOffset
	else
		angleToCandidate = angleToCandidate + self._normalizeOffset
	end

	if angleToCandidate > self._lowerEdge and angleToCandidate < self._upperEdge then
		return false
	else
		return true
	end
end
-- arg_56_0 -> self
-- arg_56_1 -> candidate
function BattleWeaponUnit.IsOutOfRange(self, candidate)
	-- var_56_0 -> distance
	local distance = self:getTrackingHost():GetDistance(candidate)

	return distance > self._maxRangeSqr or distance < self:GetMinimumRange()
end
-- arg_57_0 -> self
-- arg_57_1 -> candidate
function BattleWeaponUnit.IsOutOfSector(self, candidate)
	return self:IsOutOfRange(candidate) or self:IsOutOfAngle(candidate)
end
-- arg_58_0 -> self
-- arg_58_1 -> candidate
function BattleWeaponUnit.IsOutOfSquare(self, candidate)
	-- var_58_0 -> position
	local position = candidate:GetPosition()

	return self:IsPointOutOfSquare(position)
end
-- arg_59_0 -> self
-- arg_59_1 -> point
function BattleWeaponUnit.IsPointOutOfSquare(self, point)
	-- var_59_0 -> isInRange
	-- var_59_1 -> distanceX
	local isInRange = false
	local distanceX = (point.x - self._hostPos.x) * self:GetDirection()

	if self._backRange < 0 then
		if distanceX > 0 and distanceX <= self._frontRange and distanceX >= math.abs(self._backRange) then
			isInRange = true
		end
	elseif distanceX > 0 and distanceX <= self._frontRange or distanceX < 0 and math.abs(distanceX) < self._backRange then
		isInRange = true
	end

	if not isInRange then
		return true
	else
		return false
	end
end
-- arg_60_0 -> self
function BattleWeaponUnit.PreCast(self)
	self._currentState = self.STATE_PRECAST

	self:AddPreCastTimer()
	-- armor指的是蓄力期间的护盾值(护盾次数)
	if self._preCastInfo.armor then
		self._precastArmor = self._preCastInfo.armor
	end
	-- var_60_0 -> preCastInfo
	-- var_60_1 -> preCastEvent
	local preCastInfo = self._preCastInfo
	local preCastEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST, preCastInfo)

	self._host:SetWeaponPreCastBound(self._preCastInfo.isBound)
	self:DispatchEvent(preCastEvent)
end
-- arg_61_0 -> self
-- arg_61_1 -> target
function BattleWeaponUnit.Fire(self, target)
	if self._host:IsCease() then
		return false
	else
		self:DispatchGCD()

		self._currentState = self.STATE_ATTACK

		if self._tmpData.action_index == "" then
			self:DoAttack(target)
		else
			self:DispatchFireEvent(target, self._tmpData.action_index)
		end
	end

	return true
end
-- arg_62_0 -> self
-- arg_62_1 -> target
function BattleWeaponUnit.DoAttack(self, target)
	if target == nil or not target:IsAlive() or self:outOfFireRange(target) then
		target = nil
	end
	-- var_62_0 -> direction
	-- var_62_1 -> attackAngle
	local direction = self:GetDirection()
	local attackAngle = self:GetAttackAngle()

	self:cacheBulletID()
	self:TriggerBuffOnSteday()
	-- iter_62_0 -> _
	-- iter_62_1 -> emitter
	for _, emitter in ipairs(self._majorEmitterList) do
		emitter:Ready()
	end
	-- iter_62_2 -> _
	-- iter_62_3 -> emitter
	for _, emitter in ipairs(self._majorEmitterList) do
		emitter:Fire(target, direction, attackAngle)
	end

	self._host:CloakExpose(self._tmpData.expose)
	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)
	self:TriggerBuffOnFire()
	self:CheckAndShake()
end
-- arg_63_0 -> self
function BattleWeaponUnit.TriggerBuffOnSteday(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_WEAPON_STEDAY, {
		equipIndex = self._equipmentIndex
	})
end
-- arg_64_0 -> self
function BattleWeaponUnit.TriggerBuffOnFire(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_FIRE, {
		equipIndex = self._equipmentIndex
	})
end
-- arg_65_0 -> self
function BattleWeaponUnit.TriggerBuffOnReady(self)
	return
end
-- arg_66_0 -> self
-- arg_66_1 -> damageList
	-- damageList本质是一个enemyID List
function BattleWeaponUnit.UpdateCombo(self, damageList)
	if self._hostUnitType ~= BattleConst.UnitType.PLAYER_UNIT or not self._host:IsAlive() then
		return
	end

	if #damageList > 0 then
		-- var_66_0 -> combo
		local combo = 0
		-- iter_66_0 -> _
		-- iter_66_1 -> enemyID
		for _, enemyID in ipairs(damageList) do
			if table.contains(self._comboIDList, enemyID) then
				combo = combo + 1
			end

			self._host:TriggerBuff(BattleConst.BuffEffectType.ON_COMBO, {
				equipIndex = self._equipmentIndex,
				matchUnitCount = combo
			})

			break
		end

		self._comboIDList = damageList
	end
end
-- arg_67_0 -> self
-- arg_67_1 -> target
-- arg_67_2 -> emitterType
-- arg_67_3 -> extraStopFunc
-- arg_67_4 -> useTmpDataBulletFlag
function BattleWeaponUnit.SingleFire(self, target, emitterType, extraStopFunc, useTmpDataBulletFlag)
	-- var_67_0 -> emitterList
	local emitterList = {}
	-- 注意这个是emittersList
		-- 每个元素是一个emitterList?
	self._tempEmittersList[#self._tempEmittersList + 1] = emitterList

	if target and target:IsAlive() then
		-- block empty
	else
		target = nil
	end

	emitterType = emitterType or BattleWeaponUnit.EMITTER_NORMAL
	-- iter_67_0 -> index
	-- iter_67_1 -> barrageID
	for index, barrageID in ipairs(self._barrageList) do
		-- var_67_1 -> spawnFunc
		-- arg_68_0 -> offsetX
		-- arg_68_1 -> offsetZ
		-- arg_68_2 -> barrageAngle
		-- arg_68_3 -> isOffsetPriority
		local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority)
			-- var_68_0 -> bulletID
			-- var_68_1 -> bullet
			local bulletID = (useTmpDataBulletFlag and self._tmpData.bullet_ID or self._bulletList)[index]
			local bullet = self:Spawn(bulletID, target, BattleWeaponUnit.EXTERNAL)

			bullet:SetOffsetPriority(isOffsetPriority)
			bullet:SetShiftInfo(offsetX, offsetZ)

			if target ~= nil then
				bullet:SetRotateInfo(target:GetBeenAimedPosition(), self:GetBaseAngle(), barrageAngle)
			else
				bullet:SetRotateInfo(nil, self:GetBaseAngle(), barrageAngle)
			end

			self:DispatchBulletEvent(bullet)
		end
		-- var_67_2 -> stopFunc
		local function stopFunc()
			-- iter_69_0 -> _
			-- iter_69_1 -> emitter
				-- 这里的emitterList利用的是闭包特性
			for _, emitter in ipairs(emitterList) do
				if emitter:GetState() ~= emitter.STATE_STOP then
					return
				end
			end
			-- iter_69_2 -> _
			-- iter_69_3 -> emitter
			for _, emitter in ipairs(emitterList) do
				emitter:Destroy()
			end
			-- 当全部emitter都停止后执行以下代码
			-- var_69_0 -> emitterListPos
			local emitterListPos
			-- iter_69_4 -> i
			-- iter_69_5 -> tempEmitterList
			for i, tempEmitterList in ipairs(self._tempEmittersList) do
				if tempEmitterList == emitterList then
					emitterListPos = i
				end
			end

			table.remove(self._tempEmittersList, emitterListPos)

			emitterList = nil
			self._fireFXFlag = self._tmpData.fire_fx_loop_type

			if extraStopFunc then
				extraStopFunc()
			end
		end
		-- var_67_3 -> emitter
		local emitter = ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID)

		emitterList[#emitterList + 1] = emitter
	end
	-- iter_67_2 -> _
	-- iter_67_3 -> emitter
	for _, emitter in ipairs(emitterList) do
		emitter:Ready()
		emitter:Fire(target, self:GetDirection(), self:GetAttackAngle())
	end

	self._host:CloakExpose(self._tmpData.expose)
	self:CheckAndShake()
end

function BattleWeaponUnit.SetModifyInitialCD(arg_70_0)
	arg_70_0._modInitCD = true
end

function BattleWeaponUnit.GetModifyInitialCD(arg_71_0)
	return arg_71_0._modInitCD
end

function BattleWeaponUnit.InitialCD(arg_72_0)
	if arg_72_0._tmpData.initial_over_heat == 1 then
		arg_72_0:AddCDTimer(arg_72_0:GetReloadTime())
	end
end

function BattleWeaponUnit.EnterCoolDown(arg_73_0)
	arg_73_0._fireFXFlag = arg_73_0._tmpData.fire_fx_loop_type

	arg_73_0:AddCDTimer(arg_73_0:GetReloadTime())
end

function BattleWeaponUnit.UpdatePrecastArmor(arg_74_0, arg_74_1)
	if arg_74_0._currentState ~= BattleWeaponUnit.STATE_PRECAST or not arg_74_0._precastArmor then
		return
	end

	arg_74_0._precastArmor = arg_74_0._precastArmor + arg_74_1

	if arg_74_0._precastArmor <= 0 then
		arg_74_0:Interrupt()
	end
end

function BattleWeaponUnit.Interrupt(arg_75_0)
	local var_75_0 = arg_75_0._preCastInfo
	local var_75_1 = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, var_75_0)

	arg_75_0:DispatchEvent(var_75_1)

	local var_75_2 = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_INTERRUPT, var_75_0)

	arg_75_0:DispatchEvent(var_75_2)
	arg_75_0:TriggerBuffWhenPrecastFinish(BattleConst.BuffEffectType.ON_WEAPON_INTERRUPT)
	arg_75_0:RemovePrecastTimer()
	arg_75_0:EnterCoolDown()
end

function BattleWeaponUnit.Cease(arg_76_0)
	if arg_76_0._currentState == BattleWeaponUnit.STATE_ATTACK or arg_76_0._currentState == BattleWeaponUnit.STATE_PRECAST or arg_76_0._currentState == BattleWeaponUnit.STATE_PRECAST_FINISH then
		arg_76_0:interruptAllEmitter()
		arg_76_0:EnterCoolDown()
	end
end

function BattleWeaponUnit.AppendReloadBoost(arg_77_0)
	return
end

function BattleWeaponUnit.DispatchGCD(arg_78_0)
	if arg_78_0._GCD > 0 then
		arg_78_0._host:EnterGCD(arg_78_0._GCD, arg_78_0._tmpData.queue)
	end
end

function BattleWeaponUnit.Clear(arg_79_0)
	arg_79_0:RemovePrecastTimer()

	if arg_79_0._majorEmitterList then
		for iter_79_0, iter_79_1 in ipairs(arg_79_0._majorEmitterList) do
			iter_79_1:Destroy()
		end
	end

	for iter_79_2, iter_79_3 in ipairs(arg_79_0._tempEmittersList) do
		for iter_79_4, iter_79_5 in ipairs(iter_79_3) do
			iter_79_5:Destroy()
		end
	end

	for iter_79_6, iter_79_7 in ipairs(arg_79_0._dumpedEmittersList) do
		for iter_79_8, iter_79_9 in ipairs(iter_79_7) do
			iter_79_9:Destroy()
		end
	end

	if arg_79_0._currentState ~= arg_79_0.STATE_OVER_HEAT then
		arg_79_0._currentState = arg_79_0.STATE_DISABLE
	end
end

function BattleWeaponUnit.Dispose(arg_80_0)
	ys.EventDispatcher.DetachEventDispatcher(arg_80_0)
	arg_80_0:RemovePrecastTimer()

	arg_80_0._dataProxy = nil
end

function BattleWeaponUnit.AddCDTimer(arg_81_0, arg_81_1)
	arg_81_0._currentState = arg_81_0.STATE_OVER_HEAT
	arg_81_0._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	arg_81_0._reloadRequire = arg_81_1
end

function BattleWeaponUnit.GetCDStartTimeStamp(arg_82_0)
	return arg_82_0._CDstartTime
end

function BattleWeaponUnit.handleCoolDown(arg_83_0)
	arg_83_0._currentState = arg_83_0.STATE_READY
	arg_83_0._CDstartTime = nil
	arg_83_0._jammingTime = 0
end

function BattleWeaponUnit.OverHeat(arg_84_0)
	arg_84_0._currentState = arg_84_0.STATE_OVER_HEAT
end

function BattleWeaponUnit.RemovePrecastTimer(arg_85_0)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(arg_85_0._precastTimer)
	arg_85_0._host:SetWeaponPreCastBound(false)

	arg_85_0._precastArmor = nil
	arg_85_0._precastTimer = nil
end

function BattleWeaponUnit.AddPreCastTimer(arg_86_0)
	local function var_86_0()
		arg_86_0._currentState = arg_86_0.STATE_PRECAST_FINISH

		arg_86_0:RemovePrecastTimer()

		local var_87_0 = arg_86_0._preCastInfo
		local var_87_1 = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, var_87_0)

		arg_86_0:DispatchEvent(var_87_1)
		arg_86_0:TriggerBuffWhenPrecastFinish(BattleConst.BuffEffectType.ON_WEAPON_SUCCESS)
		arg_86_0:Tracking()
	end

	arg_86_0._precastTimer = pg.TimeMgr.GetInstance():AddBattleTimer("weaponPrecastTimer", 0, arg_86_0._preCastInfo.time, var_86_0, true)
end

function BattleWeaponUnit.Spawn(arg_88_0, arg_88_1, arg_88_2)
	local var_88_0

	if arg_88_0._tmpData.search_type == WeaponSearchType.STRIKE then
		var_88_0 = arg_88_0._host:GetStrikePoint()
	elseif arg_88_2 == nil then
		var_88_0 = Vector3.zero
	else
		var_88_0 = arg_88_2:GetBeenAimedPosition() or arg_88_2:GetPosition()
	end

	local var_88_1 = arg_88_0._dataProxy:CreateBulletUnit(arg_88_1, arg_88_0._host, arg_88_0, var_88_0)

	arg_88_0:setBulletSkin(var_88_1, arg_88_1)
	arg_88_0:setBulletOrb(var_88_1)
	arg_88_0:TriggerBuffWhenSpawn(var_88_1)

	return var_88_1
end

function BattleWeaponUnit.FixAmmo(arg_89_0, arg_89_1)
	arg_89_0._fixedAmmo = arg_89_1
end

function BattleWeaponUnit.GetFixAmmo(arg_90_0)
	return arg_90_0._fixedAmmo
end

function BattleWeaponUnit.ShiftBullet(arg_91_0, arg_91_1)
	local var_91_0 = {}

	for iter_91_0 = 1, #arg_91_0._bulletList do
		var_91_0[iter_91_0] = arg_91_1
	end

	arg_91_0._bulletList = var_91_0
end

function BattleWeaponUnit.RevertBullet(arg_92_0)
	arg_92_0._bulletList = arg_92_0._tmpData.bullet_ID
end

function BattleWeaponUnit.cacheBulletID(arg_93_0)
	arg_93_0._emitBulletIDList = arg_93_0._bulletList
end

function BattleWeaponUnit.setBulletOrb(arg_94_0, arg_94_1)
	if not arg_94_0._orbID then
		return
	end

	local var_94_0 = {
		buff_id = arg_94_0._orbID,
		rant = arg_94_0._orbRant,
		level = arg_94_0._orbLevel
	}

	arg_94_1:AppendAttachBuff(var_94_0)
end

function BattleWeaponUnit.SetBulletOrbData(arg_95_0, arg_95_1)
	arg_95_0._orbID = arg_95_1.buffID
	arg_95_0._orbRant = arg_95_1.rant
	arg_95_0._orbLevel = arg_95_1.level
end

function BattleWeaponUnit.ShiftBarrage(arg_96_0, arg_96_1)
	for iter_96_0, iter_96_1 in ipairs(arg_96_0._majorEmitterList) do
		table.insert(arg_96_0._dumpedEmittersList, iter_96_1)
	end

	arg_96_0._majorEmitterList = {}

	if type(arg_96_1) == "number" then
		local var_96_0 = {}

		for iter_96_2 = 1, #arg_96_0._barrageList do
			var_96_0[iter_96_2] = arg_96_1
		end

		arg_96_0._barrageList = var_96_0
	elseif type(arg_96_1) == "table" then
		arg_96_0._barrageList = arg_96_1
	end

	for iter_96_3, iter_96_4 in ipairs(arg_96_0._barrageList) do
		arg_96_0:createMajorEmitter(iter_96_4, iter_96_3)
	end
end

function BattleWeaponUnit.RevertBarrage(arg_97_0)
	arg_97_0:ShiftBarrage(arg_97_0._tmpData.barrage_ID)
end

function BattleWeaponUnit.GetPrimalAmmoType(arg_98_0)
	return BattleDataFunction.GetBulletTmpDataFromID(arg_98_0._tmpData.bullet_ID[1]).ammo_type
end

function BattleWeaponUnit.TriggerBuffWhenSpawn(arg_99_0, arg_99_1, arg_99_2)
	local var_99_0 = arg_99_2 or BattleConst.BuffEffectType.ON_BULLET_CREATE
	local var_99_1 = {
		_bullet = arg_99_1,
		equipIndex = arg_99_0._equipmentIndex,
		bulletTag = arg_99_1:GetExtraTag()
	}

	arg_99_0._host:TriggerBuff(var_99_0, var_99_1)
end

function BattleWeaponUnit.TriggerBuffWhenPrecastFinish(arg_100_0, arg_100_1)
	if arg_100_0._preCastInfo.armor then
		local var_100_0 = {
			weaponID = arg_100_0._tmpData.id
		}

		arg_100_0._host:TriggerBuff(arg_100_1, var_100_0)
	end
end

function BattleWeaponUnit.DispatchBulletEvent(arg_101_0, arg_101_1, arg_101_2)
	local var_101_0 = arg_101_2
	local var_101_1 = arg_101_0._tmpData
	local var_101_2

	if arg_101_0._fireFXFlag ~= 0 then
		var_101_2 = arg_101_0._skinFireFX or var_101_1.fire_fx

		if arg_101_0._fireFXFlag ~= -1 then
			arg_101_0._fireFXFlag = arg_101_0._fireFXFlag - 1
		end
	end

	if type(var_101_1.spawn_bound) == "table" and not var_101_0 then
		local var_101_3 = arg_101_0._dataProxy:GetStageInfo().mainUnitPosition

		if var_101_3 and var_101_3[arg_101_0._hostIFF] then
			var_101_0 = Clone(var_101_3[arg_101_0._hostIFF][var_101_1.spawn_bound[1]])
		else
			var_101_0 = Clone(BattleConfig.MAIN_UNIT_POS[arg_101_0._hostIFF][var_101_1.spawn_bound[1]])
		end
	end

	local var_101_4 = {
		spawnBound = var_101_1.spawn_bound,
		bullet = arg_101_1,
		fireFxID = var_101_2,
		position = var_101_0
	}
	local var_101_5 = ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_BULLET, var_101_4)

	arg_101_0:DispatchEvent(var_101_5)
end

function BattleWeaponUnit.DispatchFireEvent(arg_102_0, arg_102_1, arg_102_2)
	local var_102_0 = {
		target = arg_102_1,
		actionIndex = arg_102_2
	}
	local var_102_1 = ys.Event.New(ys.Battle.BattleUnitEvent.FIRE, var_102_0)

	arg_102_0:DispatchEvent(var_102_1)
end

function BattleWeaponUnit.CheckAndShake(arg_103_0)
	if arg_103_0._tmpData.shakescreen ~= 0 then
		ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[arg_103_0._tmpData.shakescreen])
	end
end

function BattleWeaponUnit.GetBaseAngle(arg_104_0)
	return arg_104_0._baseAngle
end

function BattleWeaponUnit.GetHost(arg_105_0)
	return arg_105_0._host
end

function BattleWeaponUnit.GetStandHost(arg_106_0)
	return arg_106_0._standHost
end

function BattleWeaponUnit.GetPosition(arg_107_0)
	return arg_107_0._hostPos
end

function BattleWeaponUnit.GetDirection(arg_108_0)
	return arg_108_0._host:GetDirection()
end

function BattleWeaponUnit.GetCurrentState(arg_109_0)
	return arg_109_0._currentState
end

function BattleWeaponUnit.GetReloadTime(arg_110_0)
	local var_110_0 = BattleAttr.GetCurrent(arg_110_0._host, "loadSpeed")

	if arg_110_0._reloadMax ~= arg_110_0._cacheReloadMax or var_110_0 ~= arg_110_0._cacheHostReload then
		arg_110_0._cacheReloadMax = arg_110_0._reloadMax
		arg_110_0._cacheHostReload = var_110_0
		arg_110_0._cacheReloadTime = BattleFormulas.CalculateReloadTime(arg_110_0._reloadMax, BattleAttr.GetCurrent(arg_110_0._host, "loadSpeed"))
	end

	return arg_110_0._cacheReloadTime
end

function BattleWeaponUnit.GetReloadTimeByRate(arg_111_0, arg_111_1)
	local var_111_0 = BattleAttr.GetCurrent(arg_111_0._host, "loadSpeed")
	local var_111_1 = arg_111_0._cacheReloadMax * arg_111_1

	return (BattleFormulas.CalculateReloadTime(var_111_1, var_111_0))
end

function BattleWeaponUnit.GetReloadFinishTimeStamp(arg_112_0)
	local var_112_0 = 0

	for iter_112_0, iter_112_1 in ipairs(arg_112_0._reloadBoostList) do
		var_112_0 = var_112_0 + iter_112_1
	end

	return arg_112_0._reloadRequire + arg_112_0._CDstartTime + arg_112_0._jammingTime + var_112_0
end

function BattleWeaponUnit.AppendFactor(arg_113_0, arg_113_1)
	return
end

function BattleWeaponUnit.StartJamming(arg_114_0)
	if arg_114_0._currentState ~= BattleWeaponUnit.STATE_READY then
		arg_114_0._jammingStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end
end

function BattleWeaponUnit.JammingEliminate(arg_115_0)
	if not arg_115_0._jammingStartTime then
		return
	end

	arg_115_0._jammingTime = pg.TimeMgr.GetInstance():GetCombatTime() - arg_115_0._jammingStartTime
	arg_115_0._jammingStartTime = nil
end

function BattleWeaponUnit.FlushReloadMax(arg_116_0, arg_116_1)
	local var_116_0 = arg_116_0._tmpData.reload_max

	arg_116_1 = arg_116_1 or 1
	arg_116_0._reloadMax = var_116_0 * arg_116_1

	if not arg_116_0._CDstartTime or arg_116_0._reloadRequire == 0 then
		return true
	end

	local var_116_1 = BattleAttr.GetCurrent(arg_116_0._host, "loadSpeed")

	arg_116_0._reloadRequire = BattleWeaponUnit.FlushRequireByInverse(arg_116_0, var_116_1)
end

function BattleWeaponUnit.AppendReloadFactor(arg_117_0, arg_117_1, arg_117_2)
	arg_117_0._reloadFacotrList[arg_117_1] = arg_117_2
end

function BattleWeaponUnit.RemoveReloadFactor(arg_118_0, arg_118_1)
	if arg_118_0._reloadFacotrList[arg_118_1] then
		arg_118_0._reloadFacotrList[arg_118_1] = nil
	end
end

function BattleWeaponUnit.GetReloadFactorList(arg_119_0)
	return arg_119_0._reloadFacotrList
end

function BattleWeaponUnit.FlushReloadRequire(arg_120_0)
	if not arg_120_0._CDstartTime or arg_120_0._reloadRequire == 0 then
		return true
	end

	local var_120_0 = BattleFormulas.CaclulateReloadAttr(arg_120_0._reloadMax, arg_120_0._reloadRequire)

	arg_120_0._reloadRequire = BattleWeaponUnit.FlushRequireByInverse(arg_120_0, var_120_0)
end

function BattleWeaponUnit.GetMinimumRange(arg_121_0)
	return arg_121_0._minRangeSqr
end

function BattleWeaponUnit.GetCorrectedDMG(arg_122_0)
	return arg_122_0._correctedDMG
end

function BattleWeaponUnit.GetConvertedAtkAttr(arg_123_0)
	return arg_123_0._convertedAtkAttr
end

function BattleWeaponUnit.SetAtkAttrTrasnform(arg_124_0, arg_124_1, arg_124_2, arg_124_3)
	arg_124_0._atkAttrTrans = arg_124_1
	arg_124_0._atkAttrTransA = arg_124_2
	arg_124_0._atkAttrTransB = arg_124_3
end

function BattleWeaponUnit.GetAtkAttrTrasnform(arg_125_0, arg_125_1)
	local var_125_0

	if arg_125_0._atkAttrTrans then
		local var_125_1 = arg_125_1[arg_125_0._atkAttrTrans] or 0

		var_125_0 = math.min(var_125_1 / arg_125_0._atkAttrTransA, arg_125_0._atkAttrTransB)
	end

	return var_125_0
end

function BattleWeaponUnit.IsReady(arg_126_0)
	return arg_126_0._currentState == arg_126_0.STATE_READY
end

function BattleWeaponUnit.FlushRequireByInverse(arg_127_0, arg_127_1)
	local var_127_0 = pg.TimeMgr.GetInstance():GetCombatTime() - arg_127_0._CDstartTime
	local var_127_1 = BattleFormulas.CaclulateReloaded(var_127_0, arg_127_1)
	local var_127_2 = arg_127_0._reloadMax - var_127_1

	return var_127_0 + BattleFormulas.CalculateReloadTime(var_127_2, BattleAttr.GetCurrent(arg_127_0._host, "loadSpeed"))
end

function BattleWeaponUnit.SetCardPuzzleDamageEnhance(arg_128_0, arg_128_1)
	arg_128_0._cardPuzzleEnhance = arg_128_1
end

function BattleWeaponUnit.GetCardPuzzleDamageEnhance(arg_129_0)
	return arg_129_0._cardPuzzleEnhance or 1
end

function BattleWeaponUnit.GetReloadRate(arg_130_0)
	if arg_130_0._currentState == arg_130_0.STATE_READY then
		return 0
	elseif arg_130_0._CDstartTime then
		return (arg_130_0:GetReloadFinishTimeStamp() - pg.TimeMgr.GetInstance():GetCombatTime()) / arg_130_0._reloadRequire
	else
		return 1
	end
end

function BattleWeaponUnit.WeaponStatistics(arg_131_0, arg_131_1, arg_131_2, arg_131_3)
	arg_131_0._CLDCount = arg_131_0._CLDCount + 1
	arg_131_0._damageSum = arg_131_1 + arg_131_0._damageSum

	if arg_131_2 then
		arg_131_0._CTSum = arg_131_0._CTSum + 1
	end

	if not arg_131_3 then
		arg_131_0._ACCSum = arg_131_0._ACCSum + 1
	end
end

function BattleWeaponUnit.GetDamageSUM(arg_132_0)
	return arg_132_0._damageSum
end

function BattleWeaponUnit.GetCTRate(arg_133_0)
	return arg_133_0._CTSum / arg_133_0._CLDCount
end

function BattleWeaponUnit.GetACCRate(arg_134_0)
	return arg_134_0._ACCSum / arg_134_0._CLDCount
end
