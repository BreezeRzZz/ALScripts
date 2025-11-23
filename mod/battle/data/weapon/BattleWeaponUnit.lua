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
-- arg_70_0 -> self
function BattleWeaponUnit.SetModifyInitialCD(self)
	self._modInitCD = true
end
-- arg_71_0 -> self
function BattleWeaponUnit.GetModifyInitialCD(self)
	return self._modInitCD
end
-- arg_72_0 -> self
function BattleWeaponUnit.InitialCD(self)
	if self._tmpData.initial_over_heat == 1 then
		self:AddCDTimer(self:GetReloadTime())
	end
end
-- arg_73_0 -> self
function BattleWeaponUnit.EnterCoolDown(self)
	self._fireFXFlag = self._tmpData.fire_fx_loop_type

	self:AddCDTimer(self:GetReloadTime())
end
-- arg_74_0 -> self
-- arg_74_1 -> deduction
	-- 这是个负数，armor逐渐减少，到0就进入打断状态
function BattleWeaponUnit.UpdatePrecastArmor(self, deduction)
	if self._currentState ~= BattleWeaponUnit.STATE_PRECAST or not self._precastArmor then
		return
	end

	self._precastArmor = self._precastArmor + deduction

	if self._precastArmor <= 0 then
		self:Interrupt()
	end
end
-- arg_75_0 -> self
function BattleWeaponUnit.Interrupt(self)
	-- var_75_0 -> preCastInfo
	-- var_75_1 -> preCastFinishEvent
	local preCastInfo = self._preCastInfo
	local preCastFinishEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, preCastInfo)

	self:DispatchEvent(preCastFinishEvent)
	-- var_75_2 -> interruptEvent
	local interruptEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_INTERRUPT, preCastInfo)

	self:DispatchEvent(interruptEvent)
	self:TriggerBuffWhenPrecastFinish(BattleConst.BuffEffectType.ON_WEAPON_INTERRUPT)
	self:RemovePrecastTimer()
	self:EnterCoolDown()
end
-- arg_76_0 -> self
function BattleWeaponUnit.Cease(self)
	if self._currentState == BattleWeaponUnit.STATE_ATTACK or self._currentState == BattleWeaponUnit.STATE_PRECAST or self._currentState == BattleWeaponUnit.STATE_PRECAST_FINISH then
		self:interruptAllEmitter()
		self:EnterCoolDown()
	end
end
-- arg_77_0 -> self
function BattleWeaponUnit.AppendReloadBoost(self)
	return
end
-- arg_78_0 -> self
function BattleWeaponUnit.DispatchGCD(self)
	if self._GCD > 0 then
		self._host:EnterGCD(self._GCD, self._tmpData.queue)
	end
end
-- arg_79_0 -> self
function BattleWeaponUnit.Clear(self)
	self:RemovePrecastTimer()

	if self._majorEmitterList then
		-- iter_79_0 -> _
		-- iter_79_1 -> emitter
		for _, emitter in ipairs(self._majorEmitterList) do
			emitter:Destroy()
		end
	end
	-- iter_79_2 -> _
	-- iter_79_3 -> emitterList
	for _, emitterList in ipairs(self._tempEmittersList) do
		-- iter_79_4 -> _
		-- iter_79_5 -> emitter
		for _, emitter in ipairs(emitterList) do
			emitter:Destroy()
		end
	end
	-- iter_79_6 -> _
	-- iter_79_7 -> emitterList
	for _, emitterList in ipairs(self._dumpedEmittersList) do
		-- iter_79_8 -> _
		-- iter_79_9 -> emitter
		for _, emitter in ipairs(emitterList) do
			emitter:Destroy()
		end
	end

	if self._currentState ~= self.STATE_OVER_HEAT then
		self._currentState = self.STATE_DISABLE
	end
end
-- arg_80_0 -> self
function BattleWeaponUnit.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
	self:RemovePrecastTimer()

	self._dataProxy = nil
end
-- arg_81_0 -> self
-- arg_81_1 -> time
function BattleWeaponUnit.AddCDTimer(self, time)
	self._currentState = self.STATE_OVER_HEAT
	self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._reloadRequire = time
end
-- arg_82_0 -> self
function BattleWeaponUnit.GetCDStartTimeStamp(self)
	return self._CDstartTime
end
-- arg_83_0 -> self
	-- CD完成时调用
function BattleWeaponUnit.handleCoolDown(self)
	self._currentState = self.STATE_READY
	self._CDstartTime = nil
	self._jammingTime = 0
end
-- arg_84_0 -> self
function BattleWeaponUnit.OverHeat(self)
	self._currentState = self.STATE_OVER_HEAT
end
-- arg_85_0 -> self
function BattleWeaponUnit.RemovePrecastTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._precastTimer)
	self._host:SetWeaponPreCastBound(false)

	self._precastArmor = nil
	self._precastTimer = nil
end
-- arg_86_0 -> self
function BattleWeaponUnit.AddPreCastTimer(self)
	-- var_86_0 -> onTimerFinish
	local function onTimerFinish()
		self._currentState = self.STATE_PRECAST_FINISH

		self:RemovePrecastTimer()
		-- var_87_0 -> preCastInfo
		-- var_87_1 -> preCastFinishEvent
		local preCastInfo = self._preCastInfo
		local preCastFinishEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, preCastInfo)

		self:DispatchEvent(preCastFinishEvent)
		self:TriggerBuffWhenPrecastFinish(BattleConst.BuffEffectType.ON_WEAPON_SUCCESS)
		self:Tracking()
	end

	self._precastTimer = pg.TimeMgr.GetInstance():AddBattleTimer("weaponPrecastTimer", 0, self._preCastInfo.time, onTimerFinish, true)
end
-- arg_88_0 -> self
-- arg_88_1 -> bulletID
-- arg_88_2 -> target
	-- 调用的时候用到了三个参数，不知道还有一个在哪，可能是可变参数...
function BattleWeaponUnit.Spawn(self, bulletID, target)
	-- var_88_0 -> targetPos
	local targetPos

	if self._tmpData.search_type == WeaponSearchType.STRIKE then
		targetPos = self._host:GetStrikePoint()
	elseif target == nil then
		targetPos = Vector3.zero
	else
		targetPos = target:GetBeenAimedPosition() or target:GetPosition()
	end
	-- var_88_1 -> bullet
	local bullet = self._dataProxy:CreateBulletUnit(bulletID, self._host, self, targetPos)

	self:setBulletSkin(bullet, bulletID)
	self:setBulletOrb(bullet)
	self:TriggerBuffWhenSpawn(bullet)

	return bullet
end
-- arg_89_0 -> self
-- arg_89_1 -> ammo
function BattleWeaponUnit.FixAmmo(self, ammo)
	self._fixedAmmo = ammo
end
-- arg_90_0 -> self
function BattleWeaponUnit.GetFixAmmo(self)
	return self._fixedAmmo
end
-- arg_91_0 -> self
-- arg_91_1 -> bulletID
function BattleWeaponUnit.ShiftBullet(self, bulletID)
	-- var_91_0 -> shiftedBulletList
	local shiftedBulletList = {}
	-- iter_91_0 -> i
	for i = 1, #self._bulletList do
		shiftedBulletList[i] = bulletID
	end

	self._bulletList = shiftedBulletList
end
-- arg_92_0 -> self
function BattleWeaponUnit.RevertBullet(self)
	self._bulletList = self._tmpData.bullet_ID
end
-- arg_93_0 -> self
function BattleWeaponUnit.cacheBulletID(self)
	self._emitBulletIDList = self._bulletList
end
-- arg_94_0 -> self
-- arg_94_1 -> bullet
function BattleWeaponUnit.setBulletOrb(self, bullet)
	if not self._orbID then
		return
	end
	-- var_94_0 -> buff
	local buff = {
		buff_id = self._orbID,
		rant = self._orbRant,
		level = self._orbLevel
	}

	bullet:AppendAttachBuff(buff)
end
-- arg_95_0 -> self
-- arg_95_1 -> buff
function BattleWeaponUnit.SetBulletOrbData(self, buff)
	self._orbID = buff.buffID
	self._orbRant = buff.rant
	self._orbLevel = buff.level
end
-- arg_96_0 -> self
-- arg_96_1 -> barrageID
	-- 可能是一个数字表示单个ID，也可能是一个表，表示多个ID
function BattleWeaponUnit.ShiftBarrage(self, barrageID)
	-- iter_96_0 -> _
	-- iter_96_1 -> emitter
	for _, emitter in ipairs(self._majorEmitterList) do
		table.insert(self._dumpedEmittersList, emitter)
	end

	self._majorEmitterList = {}

	if type(barrageID) == "number" then
		-- var_96_0 -> barrageList
		local barrageList = {}
		-- iter_96_2 -> i
		for i = 1, #self._barrageList do
			barrageList[i] = barrageID
		end

		self._barrageList = barrageList
	elseif type(barrageID) == "table" then
		self._barrageList = barrageID
	end
	-- iter_96_3 -> i
	-- iter_96_4 -> barrageID
		-- 这里是单个ID了
	for i, barrageID in ipairs(self._barrageList) do
		self:createMajorEmitter(barrageID, i)
	end
end
-- arg_97_0 -> self
function BattleWeaponUnit.RevertBarrage(self)
	self:ShiftBarrage(self._tmpData.barrage_ID)
end
-- arg_98_0 -> self
function BattleWeaponUnit.GetPrimalAmmoType(self)
	-- 这里是BattleBulletDataFunction的GetBulletTmpDataFromID函数
	return BattleDataFunction.GetBulletTmpDataFromID(self._tmpData.bullet_ID[1]).ammo_type
end
-- arg_99_0 -> self
-- arg_99_1 -> bullet
-- arg_99_2 -> trigger
function BattleWeaponUnit.TriggerBuffWhenSpawn(self, bullet, trigger)
	-- var_99_0 -> trigger
	local trigger = trigger or BattleConst.BuffEffectType.ON_BULLET_CREATE
	-- var_99_1 -> extraArgs
	local extraArgs = {
		_bullet = bullet,
		equipIndex = self._equipmentIndex,
		bulletTag = bullet:GetExtraTag()
	}

	self._host:TriggerBuff(trigger, extraArgs)
end
-- arg_100_0 -> self
-- arg_100_1 -> trigger
function BattleWeaponUnit.TriggerBuffWhenPrecastFinish(self, trigger)
	if self._preCastInfo.armor then
		-- var_100_0 -> extraArgs
		local extraArgs = {
			weaponID = self._tmpData.id
		}

		self._host:TriggerBuff(trigger, extraArgs)
	end
end
-- arg_101_0 -> self
-- arg_101_1 -> bullet
-- arg_101_2 -> position
function BattleWeaponUnit.DispatchBulletEvent(self, bullet, position)
	-- var_101_0 -> position
	-- var_101_1 -> template
	-- var_101_2 -> fireFXID
	local position = position
	local template = self._tmpData
	local fireFXID

	if self._fireFXFlag ~= 0 then
		fireFXID = self._skinFireFX or template.fire_fx

		if self._fireFXFlag ~= -1 then
			self._fireFXFlag = self._fireFXFlag - 1
		end
	end
	-- spawn_bound是一个table的情况
	if type(template.spawn_bound) == "table" and not position then
		-- var_101_3 -> mainUnitPosition
		local mainUnitPosition = self._dataProxy:GetStageInfo().mainUnitPosition

		if mainUnitPosition and mainUnitPosition[self._hostIFF] then
			position = Clone(mainUnitPosition[self._hostIFF][template.spawn_bound[1]])
		else
			position = Clone(BattleConfig.MAIN_UNIT_POS[self._hostIFF][template.spawn_bound[1]])
		end
	end
	-- var_101_4 -> eventArgs
	local eventArgs = {
		spawnBound = template.spawn_bound,
		bullet = bullet,
		fireFxID = fireFXID,
		position = position
	}
	-- var_101_5 -> createBulletEvent
	local createBulletEvent = ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_BULLET, eventArgs)

	self:DispatchEvent(createBulletEvent)
end
-- arg_102_0 -> self
-- arg_102_1 -> target
-- arg_102_2 -> actionIndex
function BattleWeaponUnit.DispatchFireEvent(self, target, actionIndex)
	-- var_102_0 -> eventArgs
	local eventArgs = {
		target = target,
		actionIndex = actionIndex
	}
	-- var_102_1 -> fireEvent
	local fireEvent = ys.Event.New(ys.Battle.BattleUnitEvent.FIRE, eventArgs)

	self:DispatchEvent(fireEvent)
end
-- arg_103_0 -> self
function BattleWeaponUnit.CheckAndShake(self)
	if self._tmpData.shakescreen ~= 0 then
		ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[self._tmpData.shakescreen])
	end
end
-- arg_104_0 -> self
function BattleWeaponUnit.GetBaseAngle(self)
	return self._baseAngle
end
-- arg_105_0 -> self
function BattleWeaponUnit.GetHost(self)
	return self._host
end
-- arg_106_0 -> self
function BattleWeaponUnit.GetStandHost(self)
	return self._standHost
end
-- arg_107_0 -> self
function BattleWeaponUnit.GetPosition(self)
	return self._hostPos
end
-- arg_108_0 -> self
function BattleWeaponUnit.GetDirection(self)
	return self._host:GetDirection()
end
-- arg_109_0 -> self
function BattleWeaponUnit.GetCurrentState(self)
	return self._currentState
end
-- arg_110_0 -> self
function BattleWeaponUnit.GetReloadTime(self)
	-- var_110_0 -> loadSpeed
		-- 指的是装填属性值
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	if self._reloadMax ~= self._cacheReloadMax or loadSpeed ~= self._cacheHostReload then
		self._cacheReloadMax = self._reloadMax
		self._cacheHostReload = loadSpeed
		self._cacheReloadTime = BattleFormulas.CalculateReloadTime(self._reloadMax, loadSpeed)
	end

	return self._cacheReloadTime
end
-- arg_111_0 -> self
-- arg_111_1 -> rate
function BattleWeaponUnit.GetReloadTimeByRate(self, rate)
	-- var_111_0 -> loadSpeed
	-- var_111_1 -> newReloadMax
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")
	local newReloadMax = self._cacheReloadMax * rate

	return (BattleFormulas.CalculateReloadTime(newReloadMax, loadSpeed))
end
-- arg_112_0 -> self
function BattleWeaponUnit.GetReloadFinishTimeStamp(self)
	-- var_112_0 -> totalReloadBoost
	local totalReloadBoost = 0
	-- iter_112_0 -> _
	-- iter_112_1 -> reloadBoost
		-- reloadBoost有可能是负数, 表示装填加快...
	for _, reloadBoost in ipairs(self._reloadBoostList) do
		totalReloadBoost = totalReloadBoost + reloadBoost
	end

	return self._reloadRequire + self._CDstartTime + self._jammingTime + totalReloadBoost
end
-- arg_113_0 -> self
-- arg_113_1 -> factor
	-- 这个函数没有被使用过，也没有被重载
function BattleWeaponUnit.AppendFactor(self, factor)
	return
end
-- arg_114_0 -> self
function BattleWeaponUnit.StartJamming(self)
	if self._currentState ~= BattleWeaponUnit.STATE_READY then
		self._jammingStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end
end
-- arg_115_0 -> self
function BattleWeaponUnit.JammingEliminate(self)
	if not self._jammingStartTime then
		return
	end

	self._jammingTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._jammingStartTime
	self._jammingStartTime = nil
end
-- arg_116_0 -> self
-- arg_116_1 -> reloadFactor
function BattleWeaponUnit.FlushReloadMax(self, reloadFactor)
	-- var_116_0 -> reloadMax
	local reloadMax = self._tmpData.reload_max

	reloadFactor = reloadFactor or 1
	self._reloadMax = reloadMax * reloadFactor

	if not self._CDstartTime or self._reloadRequire == 0 then
		return true
	end
	-- var_116_1 -> loadSpeed
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	self._reloadRequire = BattleWeaponUnit.FlushRequireByInverse(self, loadSpeed)
end
-- arg_117_0 -> self
-- arg_117_1 -> buff
-- arg_117_2 -> reloadFactor
function BattleWeaponUnit.AppendReloadFactor(self, buff, reloadFactor)
	-- 这变量名难绷
	self._reloadFacotrList[buff] = reloadFactor
end
-- arg_118_0 -> self
-- arg_118_1 -> buff
function BattleWeaponUnit.RemoveReloadFactor(self, buff)
	if self._reloadFacotrList[buff] then
		self._reloadFacotrList[buff] = nil
	end
end
-- arg_119_0 -> self
function BattleWeaponUnit.GetReloadFactorList(self)
	return self._reloadFacotrList
end
-- arg_120_0 -> self
function BattleWeaponUnit.FlushReloadRequire(self)
	if not self._CDstartTime or self._reloadRequire == 0 then
		return true
	end
	-- var_120_0 -> requireLoadSpeed
	local requireLoadSpeed = BattleFormulas.CaclulateReloadAttr(self._reloadMax, self._reloadRequire)

	self._reloadRequire = BattleWeaponUnit.FlushRequireByInverse(self, requireLoadSpeed)
end
-- arg_121_0 -> self
function BattleWeaponUnit.GetMinimumRange(self)
	return self._minRangeSqr
end
-- arg_122_0 -> self
function BattleWeaponUnit.GetCorrectedDMG(self)
	return self._correctedDMG
end
-- arg_123_0 -> self
function BattleWeaponUnit.GetConvertedAtkAttr(self)
	return self._convertedAtkAttr
end
-- arg_124_0 -> self
-- arg_124_1 -> atkAttrTrans
-- arg_124_2 -> atkAttrTransA
-- arg_124_3 -> atkAttrTransB
function BattleWeaponUnit.SetAtkAttrTrasnform(self, atkAttrTrans, atkAttrTransA, atkAttrTransB)
	self._atkAttrTrans = atkAttrTrans
	self._atkAttrTransA = atkAttrTransA
	self._atkAttrTransB = atkAttrTransB
end
-- arg_125_0 -> self
-- arg_125_1 -> attrs
function BattleWeaponUnit.GetAtkAttrTrasnform(self, attrs)
	-- var_125_0 -> atkAttrTransform
	local atkAttrTransform

	if self._atkAttrTrans then
		-- var_125_1 -> atkAttrValue
		local atkAttrValue = attrs[self._atkAttrTrans] or 0

		atkAttrTransform = math.min(atkAttrValue / self._atkAttrTransA, self._atkAttrTransB)
	end

	return atkAttrTransform
end
-- arg_126_0 -> self
function BattleWeaponUnit.IsReady(self)
	return self._currentState == self.STATE_READY
end
-- arg_127_0 -> self
-- arg_127_1 -> loadSpeed
function BattleWeaponUnit.FlushRequireByInverse(self, loadSpeed)
	-- var_127_0 -> elapsedTime
	-- var_127_1 -> reloadedAmount
	-- var_127_2 -> remainingReload
	local elapsedTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._CDstartTime
	local reloadedAmount = BattleFormulas.CaclulateReloaded(elapsedTime, loadSpeed)
	local remainingReload = self._reloadMax - reloadedAmount

	return elapsedTime + BattleFormulas.CalculateReloadTime(remainingReload, BattleAttr.GetCurrent(self._host, "loadSpeed"))
end
-- arg_128_0 -> self
-- arg_128_1 -> enhance
	-- CardPuzzle相关都是废案，不用管
function BattleWeaponUnit.SetCardPuzzleDamageEnhance(self, enhance)
	self._cardPuzzleEnhance = enhance
end
-- arg_129_0 -> self
function BattleWeaponUnit.GetCardPuzzleDamageEnhance(self)
	return self._cardPuzzleEnhance or 1
end
-- arg_130_0 -> self
function BattleWeaponUnit.GetReloadRate(self)
	if self._currentState == self.STATE_READY then
		return 0
	elseif self._CDstartTime then
		return (self:GetReloadFinishTimeStamp() - pg.TimeMgr.GetInstance():GetCombatTime()) / self._reloadRequire
	else
		return 1
	end
end
-- arg_131_0 -> self
-- arg_131_1 -> damage
-- arg_131_2 -> isCri
-- arg_131_3 -> isMiss
function BattleWeaponUnit.WeaponStatistics(self, damage, isCri, isMiss)
	self._CLDCount = self._CLDCount + 1
	self._damageSum = damage + self._damageSum

	if isCri then
		self._CTSum = self._CTSum + 1
	end

	if not isMiss then
		self._ACCSum = self._ACCSum + 1
	end
end
-- arg_132_0 -> self
function BattleWeaponUnit.GetDamageSUM(self)
	return self._damageSum
end
-- arg_133_0 -> self
function BattleWeaponUnit.GetCTRate(self)
	return self._CTSum / self._CLDCount
end
-- arg_134_0 -> self
function BattleWeaponUnit.GetACCRate(self)
	return self._ACCSum / self._CLDCount
end
