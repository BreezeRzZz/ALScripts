ys = ys or {}

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

--- @class BattleWeaponUnit
--- @return nil
--- 构造函数
function BattleWeaponUnit.Ctor(self)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._currentState = self.STATE_READY
	-- 默认是-1. 因此各种针对非装备的弹幕武器的就是-1, 而装备的则是对应的装备索引
	self._equipmentIndex = -1
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	--- @type table<number, table<number, BattleBulletEmitter>>
	self._tempEmittersList = {}
	--- @type table<number, table<number, BattleBulletEmitter>>
	self._dumpedEmittersList = {}
	--- @type table<BattleBuffUnit, number>
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

--- @class BattleWeaponUnit
--- @return nil
--- 标记武器为敌方武器
function BattleWeaponUnit.HostOnEnemy(self)
	self._hostOnEnemy = true
end

--- @class BattleWeaponUnit
--- @param potential number
--- @return nil
--- 设置武器效率，并计算修正后的武器标伤
function BattleWeaponUnit.SetPotentialFactor(self, potential)
	self._potential = potential

	if self._correctedDMG then
		self._correctedDMG = BattleFormulas.WeaponDamagePreCorrection(self)
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 获取装备标签列表
function BattleWeaponUnit.GetEquipmentLabel(self)
	return self._equipmentLabelList or {}
end

--- @class BattleWeaponUnit
--- @param labelList table
--- @return nil
--- 设置装备标签列表
function BattleWeaponUnit.SetEquipmentLabel(self, labelList)
	self._equipmentLabelList = labelList
end

--- @class BattleWeaponUnit
--- @param tmpData table<string, any>
--- @return nil
--- 设置模板数据
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
function BattleWeaponUnit.SetTemplateData(self, tmpData)
	self._potential = self._potential or 1
	self._tmpData = tmpData
	self._maxRangeSqr = tmpData.range
	self._minRangeSqr = tmpData.min_range
	self._fireFXFlag = tmpData.fire_fx_loop_type
	self._oxyList = tmpData.oxy_type
	self._bulletList = tmpData.bullet_ID
	--- @type table<number, BattleBulletEmitter>
	self._majorEmitterList = {}

	self:ShiftBarrage(tmpData.barrage_ID)

	self._GCD = tmpData.recover_time
	self._preCastInfo = tmpData.precast_param
	self._correctedDMG = BattleFormulas.WeaponDamagePreCorrection(self)
	self._convertedAtkAttr = BattleFormulas.WeaponAtkAttrPreRatio(self)

	self:FlushReloadMax(1)
end

--- @class BattleWeaponUnit
--- @param barrageID number
--- @param index number
--- @param emitterType string
--- @param spawnFunc function
--- @param stopFunc function
--- @return BattleBulletEmitter
--- 创建主要发射器
--- 来自BattleWeaponUnit.ShiftBarrage
function BattleWeaponUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	--- @param offsetX number
	--- @param offsetZ number
	--- @param barrageAngle number
	--- @param isOffsetPriority boolean
	--- @param target BattleUnit
	--- @return BattleBulletUnit
	--- 创建默认的子弹生成函数
	local function defaultSpawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		local bulletID = self._emitBulletIDList[index]
		--- @type BattleBulletUnit
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

	--- @return nil
	--- 停止回调，停止所有主要发射器
	local function defaultStopFunc()
		for _, emitter in ipairs(self._majorEmitterList) do
			if emitter:GetState() ~= emitter.STATE_STOP then
				return
			end
		end

		self:EnterCoolDown()
	end

	emitterType = emitterType or BattleWeaponUnit.EMITTER_NORMAL
	--- @type BattleBulletEmitter
	local emitter = ys.Battle[emitterType].New(spawnFunc or defaultSpawnFunc, stopFunc or defaultStopFunc, barrageID)

	self._majorEmitterList[#self._majorEmitterList + 1] = emitter

	return emitter
end

--- @class BattleWeaponUnit
--- @return nil
--- 中断所有发射器
function BattleWeaponUnit.interruptAllEmitter(self)
	if self._majorEmitterList then
		for _, emitter in ipairs(self._majorEmitterList) do
			emitter:Interrupt()
		end
	end

	for _, emitterList in ipairs(self._tempEmittersList) do
		for _, emitter in ipairs(emitterList) do
			emitter:Interrupt()
		end
	end

	for _, emitterList in ipairs(self._dumpedEmittersList) do
		for _, emitter in ipairs(emitterList) do
			emitter:Interrupt()
		end
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 缓存扇形(索敌)数据
function BattleWeaponUnit.cacheSectorData(self)
	local halfAngle = self:GetAttackAngle() / 2

	self._upperEdge = math.deg2Rad * halfAngle
	self._lowerEdge = -1 * self._upperEdge

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

--- @class BattleWeaponUnit
--- @return nil
--- 缓存矩形(索敌)数据
function BattleWeaponUnit.cacheSquareData(self)
	self._frontRange = self._tmpData.angle
	self._backRange = self._tmpData.axis_angle
	self._upperRange = self._tmpData.min_range
	self._lowerRange = self._tmpData.range
end

--- @class BattleWeaponUnit
--- @param modelID number
--- @return nil
--- 设置模型ID
function BattleWeaponUnit.SetModelID(self, modelID)
	self._modelID = modelID
end

--- @class BattleWeaponUnit
--- @param skinID number
--- @return nil
--- 设置皮肤数据
function BattleWeaponUnit.SetSkinData(self, skinID)
	self._skinID = skinID
	-- 在BattleUnitDataFunction中
	local bulletName, derivateBullet, derivateTorpedo, derivateBoom, fireFXName, hitFXName = BattleDataFunction.GetEquipSkin(self._skinID)

	self:SetModelID(bulletName)

	if fireFXName ~= "" then
		self._skinFireFX = fireFXName
	end

	if hitFXName ~= "" then
		self._skinHitFX = hitFXName
	end

	-- 在BattleUnitDataFunction中
	local hitSFX, missSFX = BattleDataFunction.GetEquipSkinSFX(self._skinID)

	self._skinHixSFX = hitSFX
	self._skinMissSFX = missSFX
end

--- @class BattleWeaponUnit
--- @param derivateSkinID number
--- @return nil
--- 设置继承皮肤数据
function BattleWeaponUnit.SetDerivateSkin(self, derivateSkinID)
	self._derivateSkinID = derivateSkinID

	local bulletName, derivateBullet, derivateTorpedo, derivateBoom, fireFXName, hitFXName = BattleDataFunction.GetEquipSkin(self._derivateSkinID)

	self._derivateBullet = derivateBullet
	self._derivateTorpedo = derivateTorpedo
	self._derivateBoom = derivateBoom
	self._derviateHitFX = hitFXName

	local hitSFX, missSFX = BattleDataFunction.GetEquipSkinSFX(self._derivateSkinID)

	self._skinHixSFX = hitSFX
	self._skinMissSFX = missSFX
end

--- @class BattleWeaponUnit
--- @return number
--- 获取皮肤ID
function BattleWeaponUnit.GetSkinID(self)
	return self._skinID
end

--- @class BattleWeaponUnit
--- @param bullet BattleBulletUnit
--- @param bulletID number
--- @return nil
--- 设置子弹皮肤
function BattleWeaponUnit.setBulletSkin(self, bullet, bulletID)
	if self._derivateSkinID then
		-- 在BattleBulletDataFunction中
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
		-- mirrorSkin即装备外观
		local mirrorSkin = 0

		if self._skinID then
			mirrorSkin = BattleDataFunction.GetEquipSkinDataFromID(self._skinID).mirror
		end

		bullet:SetModleID(self._modelID, mirrorSkin, self._skinHitFX)
		bullet:SetSFXID(self._skinHixSFX, self._skinMissSFX)
	end
end

--- @class BattleWeaponUnit
--- @param srcEquipID number
--- @return nil
--- 设置原始装备ID
function BattleWeaponUnit.SetSrcEquipmentID(self, srcEquipID)
	self._srcEquipID = srcEquipID
end

--- @class BattleWeaponUnit
--- @param equipmentIndex number
--- @return nil
--- 设置装备索引
function BattleWeaponUnit.SetEquipmentIndex(self, equipmentIndex)
	self._equipmentIndex = equipmentIndex
end

--- @class BattleWeaponUnit
--- @return number
--- 获取装备索引
function BattleWeaponUnit.GetEquipmentIndex(self)
	return self._equipmentIndex
end

--- @class BattleWeaponUnit
--- @param host BattleUnit
--- @return nil
--- 设置武器的宿主数据
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

--- @class BattleWeaponUnit
--- @param standHost BattleUnit
--- @return nil
--- 设置StandHost, 用于跨队武器计算，standHost表示跨队武器的提供者
--- 跨队武器的属性会使用standHost的属性进行计算，其他使用host的部分
function BattleWeaponUnit.SetStandHost(self, standHost)
	self._standHost = standHost
end

--- @class BattleWeaponUnit
--- @param GCD number
--- @return nil
--- 设置GCD
function BattleWeaponUnit.OverrideGCD(self, GCD)
	self._GCD = GCD
end

--- @class BattleWeaponUnit
--- @return nil
--- 更新宿主位置信息
function BattleWeaponUnit.updateMovementInfo(self)
	self._hostPos = self._host:GetPosition()
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器ID
function BattleWeaponUnit.GetWeaponId(self)
	return self._tmpData.id
end

--- @class BattleWeaponUnit
--- @return table<string, any>
--- 获取模板数据
function BattleWeaponUnit.GetTemplateData(self)
	return self._tmpData
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器类型
function BattleWeaponUnit.GetType(self)
	return self._tmpData.type
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器效率
function BattleWeaponUnit.GetPotential(self)
	return self._potential or 1
end

--- @class BattleWeaponUnit
--- @return number
--- 获取原始装备ID
function BattleWeaponUnit.GetSrcEquipmentID(self)
	return self._srcEquipID
end

--- @class BattleWeaponUnit
--- @return nil
--- 设置固定武器标志
function BattleWeaponUnit.SetFixedFlag(self)
	self._isFixedWeapon = true
end

--- @class BattleWeaponUnit
--- @return boolean
--- 判断是否为固定武器
--- fix_equip_list实际都是weapon(虽然equip_data_statistics中有同ID的装备. 但要搞清楚实际逻辑只看武器)
function BattleWeaponUnit.IsFixedWeapon(self)
	return self._isFixedWeapon
end

--- @class BattleWeaponUnit
--- @return boolean
--- 判断武器是否正在攻击
function BattleWeaponUnit.IsAttacking(self)
	return self._currentState == BattleWeaponUnit.STATE_ATTACK or self._currentState == self.STATE_PRECAST
end

--- @class BattleWeaponUnit
--- @return nil
--- 武器的Update函数
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

--- @class BattleWeaponUnit
--- @return boolean
--- 检查武器是否完成了装填时间戳
function BattleWeaponUnit.CheckReloadTimeStamp(self)
	return self._CDstartTime and self:GetReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime()
end

--- @class BattleWeaponUnit
--- @return nil
--- 装填完毕时，更新装填状态
function BattleWeaponUnit.UpdateReload(self)
	if self._CDstartTime and not self._jammingStartTime then
		if self:GetReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime() then
			self:handleCoolDown()
		else
			return
		end
	end
end

--- @class BattleWeaponUnit
--- @return boolean
--- 检查能否准备开火?
function BattleWeaponUnit.CheckPreCast(self)
	if self._tmpData.search_type == WeaponSearchType.STRIKE then
		local strikePoint = self._host:GetStrikePoint()

		return not self:IsPointOutOfSquare(strikePoint)
	else
		for _, candidate in pairs(self:GetFilteredList()) do
			return true
		end
	end

	return false
end

--- @class BattleWeaponUnit
--- @return nil
--- 修改水上/水下状态
function BattleWeaponUnit.ChangeDiveState(self)
	if self._host:GetOxyState() then
		local weaponType = self._host:GetOxyState():GetWeaponType()

		for _, oxyType in ipairs(self._oxyList) do
			if table.contains(weaponType, oxyType) then
				self._diveEnabled = true

				return
			end
		end

		self._diveEnabled = false
	end
end

--- @class BattleWeaponUnit
--- @return BattleUnit
--- 获取武器Tracking宿主?
--- - 与getHost方法是一样的
function BattleWeaponUnit.getTrackingHost(self)
	return self._host
end

BattleWeaponUnit.TrackingFunc = {
	farthest = BattleWeaponUnit.TrackingFarthest,
	leastHP = BattleWeaponUnit.TrackingLeastHP
}

--- @class BattleWeaponUnit
--- @return nil
--- 索敌函数，确定要攻击的敌人
--- 这一步得到的目标一定是一个敌人
function BattleWeaponUnit.Tracking(self)
	-- SearchType为STRIKE的不需要索敌
	if self._tmpData.search_type == WeaponSearchType.STRIKE then
		return nil
	end
	local targetTag = BattleAttr.GetCurrentTargetSelect(self._host)
	local target
	-- 过滤掉不在索敌范围内的敌人
	local filteredList = self:GetFilteredList()

	if targetTag then
		-- 使用对应的索敌方法
		local trackingFunc = BattleWeaponUnit.TrackingFunc[targetTag]

		if trackingFunc then
			target = trackingFunc(self, filteredList)
		else
			target = self:TrackingTag(filteredList, targetTag)
		end
	else
		target = self:TrackingNearest(filteredList)
	end

	-- 如果目标存在守护者，转而攻击守护者
	if target and BattleAttr.GetCurrentGuardianID(target) then
		local guardianID = BattleAttr.GetCurrentGuardianID(target)

		for _, candidate in ipairs(filteredList) do
			if candidate:GetUniqueID() == guardianID then
				target = candidate

				break
			end
		end
	end

	return target
end

--- @class BattleWeaponUnit
--- @return table<number, BattleUnit>
--- 获取初步过滤后的敌人列表
function BattleWeaponUnit.GetFilteredList(self)
	-- 1. 过滤掉友军和水面状态不符合的单位
	local filteredList = self:FilterTarget()
	-- 2. 过滤掉不符合索敌范围/角度的单位
	if self._tmpData.search_type == WeaponSearchType.SECTOR then
		filteredList = self:FilterRange(filteredList)
		filteredList = self:FilterAngle(filteredList)
	elseif self._tmpData.search_type == WeaponSearchType.SQUARE then
		filteredList = self:FilterSquare(filteredList)
	end

	return filteredList
end

--- @class BattleWeaponUnit
--- @param maxRange number
--- @param fixBulletRange number
--- @param minRange number
--- @param bulletRangeOffset number
--- @return nil
--- 重载武器range相关参数
--- 被BattleBuffFixRange.updateBulletRange调用
function BattleWeaponUnit.FixWeaponRange(self, maxRange, fixBulletRange, minRange, bulletRangeOffset)
	self._maxRangeSqr = maxRange or self._tmpData.range
	self._minRangeSqr = minRange or self._tmpData.min_range
	self._fixBulletRange = fixBulletRange
	self._bulletRangeOffset = bulletRangeOffset
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器最大索敌范围
function BattleWeaponUnit.GetWeaponMaxRange(self)
	return self._maxRangeSqr
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器最小索敌范围
function BattleWeaponUnit.GetWeaponMinRange(self)
	return self._minRangeSqr
end

--- @class BattleWeaponUnit
--- @return number, number
--- 获取修正后的子弹射程和偏移
function BattleWeaponUnit.GetFixBulletRange(self)
	return self._fixBulletRange, self._bulletRangeOffset
end

--- @class BattleWeaponUnit
--- @param filteredList table<number, BattleUnit>
--- @return BattleUnit
--- 获取距离最近的目标
function BattleWeaponUnit.TrackingNearest(self, filteredList)
	local minDistance = self._maxRangeSqr
	local target

	for _, candidate in ipairs(filteredList) do
		local distance = self:getTrackingHost():GetDistance(candidate)

		if distance <= minDistance then
			minDistance = distance
			target = candidate
		end
	end

	return target
end

--- @class BattleWeaponUnit
--- @param filteredList table<number, BattleUnit>
--- @return BattleUnit
--- 获取距离最远的目标
function BattleWeaponUnit.TrackingFarthest(self, filteredList)
	local maxDistance = 0
	local target

	for _, candidate in ipairs(filteredList) do
		local distance = self:getTrackingHost():GetDistance(candidate)

		if maxDistance < distance then
			maxDistance = distance
			target = candidate
		end
	end

	return target
end

--- @class BattleWeaponUnit
--- @param filteredList table<number, BattleUnit>
--- @return BattleUnit
--- 获取血量最少的目标
function BattleWeaponUnit.TrackingLeastHP(self, filteredList)
	local minHP = math.huge
	local target

	for _, candidate in ipairs(filteredList) do
		local candidateHP = candidate:GetCurrentHP()

		if candidateHP < minHP then
			target = candidate
			minHP = candidateHP
		end
	end

	return target
end

--- @class BattleWeaponUnit
--- @param filteredList table<number, BattleUnit>
--- @return BattleUnit|nil
--- 获取随机目标
function BattleWeaponUnit.TrackingRandom(self, filteredList)
	local shuffledList = {}
	-- 这里是利用了pairs的无序性来打乱顺序
	-- 但严格来说，这并不是一个真正的随机打乱...
	for _, candidate in pairs(filteredList) do
		table.insert(shuffledList, candidate)
	end

	local candidateCount = #shuffledList

	if candidateCount == 0 then
		return nil
	else
		return shuffledList[math.random(candidateCount)]
	end
end

--- @class BattleWeaponUnit
--- @param filteredList table<number, BattleUnit>
--- @return BattleUnit
--- 获取符合标签的目标
function BattleWeaponUnit.TrackingTag(self, filteredList, targetTag)
	local tagedList = {}

	for _, candidate in ipairs(filteredList) do
		if candidate:ContainsLabelTag({
			targetTag
		}) then
			table.insert(tagedList, candidate)
		end
	end
	-- 如果没有符合tag的目标，选择最近的
	-- 否则，从符合tag的目标中随机选择一个
	if #tagedList == 0 then
		return self:TrackingNearest(filteredList)
	else
		return tagedList[math.random(#tagedList)]
	end
end

--- @class BattleWeaponUnit
--- @return table<number, BattleUnit>
--- 过滤掉友军和水面状态不符合的单位
function BattleWeaponUnit.FilterTarget(self)
	local enemyList = BattleTargetChoise.LegalWeaponTarget(self._host)
	local filteredList = {}
	local i = 1
	local search_condition = self._tmpData.search_condition

	for _, enemy in pairs(enemyList) do
		local oxyState = enemy:GetCurrentOxyState()

		if BattleAttr.IsCloak(enemy) then
			-- block empty
		elseif not table.contains(search_condition, oxyState) then
			-- block empty
		else
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

--- @class BattleWeaponUnit
--- @param list table<number, BattleUnit>
--- @return BattleUnit
--- 过滤掉角度范围外的单位
function BattleWeaponUnit.FilterAngle(self, list)
	if self:GetAttackAngle() >= 360 then
		return list
	end

	for i = #list, 1, -1 do
		if self:IsOutOfAngle(list[i]) then
			table.remove(list, i)
		end
	end

	return list
end

--- @class BattleWeaponUnit
--- @param list table<number, BattleUnit>
--- @return BattleUnit
--- 过滤掉距离范围外的单位
function BattleWeaponUnit.FilterRange(self, list)
	for i = #list, 1, -1 do
		if self:IsOutOfRange(list[i]) then
			table.remove(list, i)
		end
	end

	return list
end

--- @class BattleWeaponUnit
--- @param list table<number, BattleUnit>
--- @return BattleUnit
--- 过滤掉矩形外的单位
function BattleWeaponUnit.FilterSquare(self, list)
	-- lineX
		-- 这里是计算出正方形的边界线位置
		-- 对于己方，是左边界线；对于敌方，是右边界线
	local direction = self:GetDirection()
	-- backRange = axis_angle参数
	local lineX = self._host:GetPosition().x + self._backRange * direction * -1
	local areaArgs = {
		lineX = lineX,
		dir = direction
	}

	-- 1. 选出在指定区域内的单位
	local filteredList1 = BattleTargetChoise.TargetInsideArea(self._host, areaArgs, list)
	-- 2. 选出权重最高的单位(可能多个同权重的)
	local filteredList2 = BattleTargetChoise.TargetWeightiest(self._host, nil, filteredList1)

	for i = #list, 1, -1 do
		if self:IsOutOfSquare(list[i]) then
			table.remove(list, i)
		end
	end

	for i = #list, 1, -1 do
		if not table.contains(filteredList2, list[i]) then
			table.remove(list, i)
		end
	end

	return list
end

--- @class BattleWeaponUnit
--- @return number
--- 获取攻击角度
function BattleWeaponUnit.GetAttackAngle(self)
	return self._tmpData.angle
end

--- @class BattleWeaponUnit
--- @param candidate BattleUnit
--- @return boolean
--- 判定目标是否在角度之外
function BattleWeaponUnit.IsOutOfAngle(self, candidate)
	if self:GetAttackAngle() >= 360 then
		return false
	end

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

--- @class BattleWeaponUnit
--- @param candidate BattleWeaponUnit
--- @return boolean
--- 判定目标是否在范围之外
function BattleWeaponUnit.IsOutOfRange(self, candidate)
	local distance = self:getTrackingHost():GetDistance(candidate)

	return distance > self._maxRangeSqr or distance < self:GetMinimumRange()
end

--- @class BattleWeaponUnit
--- @param candidate BattleWeaponUnit
--- @return boolean
--- 判定目标是否在扇形之外
function BattleWeaponUnit.IsOutOfSector(self, candidate)
	return self:IsOutOfRange(candidate) or self:IsOutOfAngle(candidate)
end

--- @class BattleWeaponUnit
--- @param candidate BattleWeaponUnit
--- @return boolean
--- 判定目标是否在矩形之外
function BattleWeaponUnit.IsOutOfSquare(self, candidate)
	local position = candidate:GetPosition()

	return self:IsPointOutOfSquare(position)
end

--- @class BattleWeaponUnit
--- @param point Vector3
--- @return boolean
--- 判定给定点是否在矩形之外
function BattleWeaponUnit.IsPointOutOfSquare(self, point)
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

--- @class BattleWeaponUnit
--- @return nil
--- 准备开火状态相关处理
function BattleWeaponUnit.PreCast(self)
	self._currentState = self.STATE_PRECAST

	self:AddPreCastTimer()
	-- armor指的是蓄力期间的护盾值(护盾次数)
	if self._preCastInfo.armor then
		self._precastArmor = self._preCastInfo.armor
	end

	local preCastInfo = self._preCastInfo
	local preCastEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST, preCastInfo)

	self._host:SetWeaponPreCastBound(self._preCastInfo.isBound)
	self:DispatchEvent(preCastEvent)
end

--- @class BattleWeaponUnit
--- @param target BattleUnit
--- @return boolean
--- Fire函数主体
function BattleWeaponUnit.Fire(self, target)
	if self._host:IsCease() then
		return false
	else
		-- 1. 施加GCD
		self:DispatchGCD()
		-- 2. 切换攻击状态
		self._currentState = self.STATE_ATTACK
		-- 3. 使用对应的攻击方法/事件
		if self._tmpData.action_index == "" then
			self:DoAttack(target)
		else
			self:DispatchFireEvent(target, self._tmpData.action_index)
		end
	end

	return true
end

--- @class BattleWeaponUnit
--- @param target BattleUnit|nil
--- @return nil
--- 默认的攻击方法
function BattleWeaponUnit.DoAttack(self, target)
	if target == nil or not target:IsAlive() or self:outOfFireRange(target) then
		target = nil
	end

	local direction = self:GetDirection()
	local attackAngle = self:GetAttackAngle()

	self:cacheBulletID()
	self:TriggerBuffOnSteday()

	for _, emitter in ipairs(self._majorEmitterList) do
		emitter:Ready()
	end

	for _, emitter in ipairs(self._majorEmitterList) do
		emitter:Fire(target, direction, attackAngle)
	end

	self._host:CloakExpose(self._tmpData.expose)
	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)
	self:TriggerBuffOnFire()
	self:CheckAndShake()
end

--- @class BattleWeaponUnit
--- @return nil
--- 武器开火时的回调（实际位置在DoAttack的前面，在实际emitter发射前触发）
function BattleWeaponUnit.TriggerBuffOnSteday(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_WEAPON_STEDAY, {
		equipIndex = self._equipmentIndex
	})
end

--- @class BattleWeaponUnit
--- @return nil
--- 武器开火时的回调（实际位置在DoAttack的后面，在实际emitter发射后触发）
function BattleWeaponUnit.TriggerBuffOnFire(self)
	self._host:TriggerBuff(BattleConst.BuffEffectType.ON_FIRE, {
		equipIndex = self._equipmentIndex
	})
end

--- @class BattleWeaponUnit
--- @return nil
--- 这个函数没有被使用过
function BattleWeaponUnit.TriggerBuffOnReady(self)
	return
end

--- @class BattleWeaponUnit
--- @param damageList table<number, number>
--- @return nil
--- 更新对敌人的连击信息
function BattleWeaponUnit.UpdateCombo(self, damageList)
	if self._hostUnitType ~= BattleConst.UnitType.PLAYER_UNIT or not self._host:IsAlive() then
		return
	end

	if #damageList > 0 then
		local combo = 0

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

--- @class BattleWeaponUnit
--- @param target BattleUnit|nil
--- @param emitterType string
--- @param extraStopFunc function
--- @param useTmpDataBulletFlag boolean
--- @return nil
--- 单次开火函数，一般是技能武器使用
--- 与Fire的区别: 不会触发ON_FIRE
function BattleWeaponUnit.SingleFire(self, target, emitterType, extraStopFunc, useTmpDataBulletFlag)
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
	for index, barrageID in ipairs(self._barrageList) do
		--- @param offsetX number
		--- @param offsetZ number
		--- @param barrageAngle number
		--- @param isOffsetPriority boolean
		--- @return nil
		--- 子弹生成函数
		local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority)
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

		--- @return nil
		--- 结束时的回调
		local function stopFunc()
			-- 这里的emitterList利用的是闭包特性
			for _, emitter in ipairs(emitterList) do
				if emitter:GetState() ~= emitter.STATE_STOP then
					return
				end
			end

			for _, emitter in ipairs(emitterList) do
				emitter:Destroy()
			end

			-- 当全部emitter都停止后执行以下代码
			local emitterListPos

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

		local emitter = ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID)

		emitterList[#emitterList + 1] = emitter
	end

	for _, emitter in ipairs(emitterList) do
		emitter:Ready()
		emitter:Fire(target, self:GetDirection(), self:GetAttackAngle())
	end

	self._host:CloakExpose(self._tmpData.expose)
	self:CheckAndShake()
end

--- @class BattleWeaponUnit
--- @return nil
--- 设置初始CD被修改标志
function BattleWeaponUnit.SetModifyInitialCD(self)
	self._modInitCD = true
end

--- @class BattleWeaponUnit
--- @return boolean
--- 获取初始CD是否被修改
function BattleWeaponUnit.GetModifyInitialCD(self)
	return self._modInitCD
end

--- @class BattleWeaponUnit
--- @return nil
--- 进行初始冷却
function BattleWeaponUnit.InitialCD(self)
	if self._tmpData.initial_over_heat == 1 then
		self:AddCDTimer(self:GetReloadTime())
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 开始冷却
function BattleWeaponUnit.EnterCoolDown(self)
	self._fireFXFlag = self._tmpData.fire_fx_loop_type

	self:AddCDTimer(self:GetReloadTime())
end

--- @class BattleWeaponUnit
--- @param deduction number:这是个负数，armor逐渐减少，到0就进入打断状态
--- @return nil
--- 更新开火准备时的护盾计数
function BattleWeaponUnit.UpdatePrecastArmor(self, deduction)
	if self._currentState ~= BattleWeaponUnit.STATE_PRECAST or not self._precastArmor then
		return
	end

	self._precastArmor = self._precastArmor + deduction

	if self._precastArmor <= 0 then
		self:Interrupt()
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 中断开火准备
function BattleWeaponUnit.Interrupt(self)
	local preCastInfo = self._preCastInfo
	local preCastFinishEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, preCastInfo)

	self:DispatchEvent(preCastFinishEvent)

	local interruptEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_INTERRUPT, preCastInfo)

	self:DispatchEvent(interruptEvent)
	self:TriggerBuffWhenPrecastFinish(BattleConst.BuffEffectType.ON_WEAPON_INTERRUPT)
	self:RemovePrecastTimer()
	self:EnterCoolDown()
end

--- @class BattleWeaponUnit
--- @return nil
--- 停止武器
function BattleWeaponUnit.Cease(self)
	if self._currentState == BattleWeaponUnit.STATE_ATTACK or self._currentState == BattleWeaponUnit.STATE_PRECAST or self._currentState == BattleWeaponUnit.STATE_PRECAST_FINISH then
		self:interruptAllEmitter()
		self:EnterCoolDown()
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 添加装填加速
--- - 这是个抽象方法，子类需要实现具体逻辑
function BattleWeaponUnit.AppendReloadBoost(self)
	return
end

--- @class BattleWeaponUnit
--- @return nil
--- 分发GCD事件
--- - 在对应的武器队列进入GCD
function BattleWeaponUnit.DispatchGCD(self)
	if self._GCD > 0 then
		self._host:EnterGCD(self._GCD, self._tmpData.queue)
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 清理武器状态
function BattleWeaponUnit.Clear(self)
	self:RemovePrecastTimer()

	if self._majorEmitterList then
		for _, emitter in ipairs(self._majorEmitterList) do
			emitter:Destroy()
		end
	end

	for _, emitterList in ipairs(self._tempEmittersList) do
		for _, emitter in ipairs(emitterList) do
			emitter:Destroy()
		end
	end

	for _, emitterList in ipairs(self._dumpedEmittersList) do
		for _, emitter in ipairs(emitterList) do
			emitter:Destroy()
		end
	end

	if self._currentState ~= self.STATE_OVER_HEAT then
		self._currentState = self.STATE_DISABLE
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 释放武器资源
function BattleWeaponUnit.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
	self:RemovePrecastTimer()

	self._dataProxy = nil
end

--- @class BattleWeaponUnit
--- @param time number
--- @return nil
--- 给武器添加冷却时间
--- - 标记为过热状态，需要装填
function BattleWeaponUnit.AddCDTimer(self, time)
	self._currentState = self.STATE_OVER_HEAT
	self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._reloadRequire = time
end

--- @class BattleWeaponUnit
--- @return number
--- 获取冷却开始时间戳
function BattleWeaponUnit.GetCDStartTimeStamp(self)
	return self._CDstartTime
end

--- @class BattleWeaponUnit
--- @return nil
--- 处理冷却完成
function BattleWeaponUnit.handleCoolDown(self)
	self._currentState = self.STATE_READY
	self._CDstartTime = nil
	self._jammingTime = 0
end

--- @class BattleWeaponUnit
--- @return nil
--- 标记武器为过热状态
function BattleWeaponUnit.OverHeat(self)
	self._currentState = self.STATE_OVER_HEAT
end

--- @class BattleWeaponUnit
--- @return nil
--- 移除开火准备计时器
function BattleWeaponUnit.RemovePrecastTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._precastTimer)
	self._host:SetWeaponPreCastBound(false)

	self._precastArmor = nil
	self._precastTimer = nil
end

--- @class BattleWeaponUnit
--- @return nil
--- 添加开火准备计时器
function BattleWeaponUnit.AddPreCastTimer(self)
	local function onTimerFinish()
		self._currentState = self.STATE_PRECAST_FINISH

		self:RemovePrecastTimer()

		local preCastInfo = self._preCastInfo
		local preCastFinishEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, preCastInfo)

		self:DispatchEvent(preCastFinishEvent)
		self:TriggerBuffWhenPrecastFinish(BattleConst.BuffEffectType.ON_WEAPON_SUCCESS)
		self:Tracking()
	end

	self._precastTimer = pg.TimeMgr.GetInstance():AddBattleTimer("weaponPrecastTimer", 0, self._preCastInfo.time, onTimerFinish, true)
end

--- @class BattleWeaponUnit
--- @param bulletID number
--- @param target BattleUnit
--- @return BattleBulletUnit
--- 生成武器的子弹
--- 调用的时候用到了三个参数，不知道还有一个在哪，可能是可变参数...
function BattleWeaponUnit.Spawn(self, bulletID, target)
	local targetPos

	if self._tmpData.search_type == WeaponSearchType.STRIKE then
		targetPos = self._host:GetStrikePoint()
	elseif target == nil then
		targetPos = Vector3.zero
	else
		targetPos = target:GetBeenAimedPosition() or target:GetPosition()
	end

	local bullet = self._dataProxy:CreateBulletUnit(bulletID, self._host, self, targetPos)

	self:setBulletSkin(bullet, bulletID)
	self:setBulletOrb(bullet)
	self:TriggerBuffWhenSpawn(bullet)

	return bullet
end

--- @class BattleWeaponUnit
--- @param damageRate number
--- @return nil
--- 设置固定弹药对甲比例
function BattleWeaponUnit.FixAmmo(self, damageRate)
	self._fixedAmmo = damageRate
end

--- @class BattleWeaponUnit
--- @return number
--- 获取固定弹药对甲比例
function BattleWeaponUnit.GetFixAmmo(self)
	return self._fixedAmmo
end

--- @class BattleWeaponUnit
--- @param bulletID number
--- @return nil
--- 替换武器的子弹ID列表为指定的子弹ID
function BattleWeaponUnit.ShiftBullet(self, bulletID)
	local shiftedBulletList = {}
	
	for i = 1, #self._bulletList do
		shiftedBulletList[i] = bulletID
	end

	self._bulletList = shiftedBulletList
end

--- @class BattleWeaponUnit
--- @return nil
--- 恢复武器的子弹ID列表为原始的子弹ID列表
function BattleWeaponUnit.RevertBullet(self)
	self._bulletList = self._tmpData.bullet_ID
end

--- @class BattleWeaponUnit
--- @return nil
--- 缓存当前的子弹ID列表
function BattleWeaponUnit.cacheBulletID(self)
	self._emitBulletIDList = self._bulletList
end

--- @class BattleWeaponUnit
--- @param bullet BattleBulletUnit
--- @return nil
--- ? 设置子弹的orb?(可能是对应caster)
function BattleWeaponUnit.setBulletOrb(self, bullet)
	if not self._orbID then
		return
	end

	local buff = {
		buff_id = self._orbID,
		rant = self._orbRant,
		level = self._orbLevel
	}

	bullet:AppendAttachBuff(buff)
end

--- @class BattleWeaponUnit
--- @param buff table<string, number>
--- @return nil
--- 设置子弹的orb数据
function BattleWeaponUnit.SetBulletOrbData(self, buff)
	self._orbID = buff.buffID
	self._orbRant = buff.rant
	self._orbLevel = buff.level
end
--- @class BattleWeaponUnit
--- @param barrageID number|table<number, number>
--- @return nil
--- 替换武器的弹幕ID列表为指定的弹幕ID
--- 这也是初始化的一个重要部分, 调用了核心: createMajorEmitter函数
function BattleWeaponUnit.ShiftBarrage(self, barrageID)
	for _, emitter in ipairs(self._majorEmitterList) do
		table.insert(self._dumpedEmittersList, emitter)
	end

	self._majorEmitterList = {}

	if type(barrageID) == "number" then
		local barrageList = {}

		for i = 1, #self._barrageList do
			barrageList[i] = barrageID
		end

		self._barrageList = barrageList
	elseif type(barrageID) == "table" then
		self._barrageList = barrageID
	end

	-- 这里的barrageID是number了
	for i, barrageID in ipairs(self._barrageList) do
		self:createMajorEmitter(barrageID, i)
	end
end
--- @class BattleWeaponUnit
--- @return nil
--- 恢复武器的弹幕ID列表为原始的弹幕ID列表
function BattleWeaponUnit.RevertBarrage(self)
	self:ShiftBarrage(self._tmpData.barrage_ID)
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的主要弹药类型
--- - 获取第一位bullet的ammo_type
function BattleWeaponUnit.GetPrimalAmmoType(self)
	-- 在BattleBulletDataFunction中
	return BattleDataFunction.GetBulletTmpDataFromID(self._tmpData.bullet_ID[1]).ammo_type
end

--- @class BattleWeaponUnit
--- @param bullet BattleBulletUnit
--- @param trigger number
--- @return nil
--- 触发子弹生成时的Buff
function BattleWeaponUnit.TriggerBuffWhenSpawn(self, bullet, trigger)
	local trigger = trigger or BattleConst.BuffEffectType.ON_BULLET_CREATE

	local extraArgs = {
		_bullet = bullet,
		equipIndex = self._equipmentIndex,
		bulletTag = bullet:GetExtraTag()
	}

	self._host:TriggerBuff(trigger, extraArgs)
end

--- @class BattleWeaponUnit
--- @param trigger number
--- @return nil
--- 触发开火准备完成时的Buff
function BattleWeaponUnit.TriggerBuffWhenPrecastFinish(self, trigger)
	if self._preCastInfo.armor then

		local extraArgs = {
			weaponID = self._tmpData.id
		}

		self._host:TriggerBuff(trigger, extraArgs)
	end
end

--- @class BattleWeaponUnit
--- @param bullet BattleBulletUnit
--- @param position Vector3
--- @return nil
--- 发送子弹生成事件
--- 在createMajorEmitter和SingleFire中均有使用
function BattleWeaponUnit.DispatchBulletEvent(self, bullet, position)
	local position = position
	local tmpData = self._tmpData
	local fireFXID

	if self._fireFXFlag ~= 0 then
		fireFXID = self._skinFireFX or tmpData.fire_fx

		if self._fireFXFlag ~= -1 then
			self._fireFXFlag = self._fireFXFlag - 1
		end
	end
	-- spawn_bound是一个table的情况
	-- 一般都是一个字符串，table比较少见
	-- 字符串的情况下，position一般是nil，因为大多数时候调用这个函数的时候并没有传position参数

	-- 是table的例子：例如，狮的15s弹幕有spawn_bound={1}
	-- 这种情况下，spawn_bound指定了这个武器/弹幕从后排哪个位置生成子弹
	-- 也就实现了：与自己所在位置无关的子弹生成位置(这就是居中弹幕的实现原理)
	if type(tmpData.spawn_bound) == "table" and not position then
		local mainUnitPosition = self._dataProxy:GetStageInfo().mainUnitPosition

		if mainUnitPosition and mainUnitPosition[self._hostIFF] then
			position = Clone(mainUnitPosition[self._hostIFF][tmpData.spawn_bound[1]])
		else
			position = Clone(BattleConfig.MAIN_UNIT_POS[self._hostIFF][tmpData.spawn_bound[1]])
		end
	end

	local eventArgs = {
		spawnBound = tmpData.spawn_bound,
		bullet = bullet,
		fireFxID = fireFXID,
		position = position
	}
	-- 对应到创建子弹事件的参数
	local createBulletEvent = ys.Event.New(ys.Battle.BattleUnitEvent.CREATE_BULLET, eventArgs)

	self:DispatchEvent(createBulletEvent)
end

--- @class BattleWeaponUnit
--- @param target BattleUnit
--- @param actionIndex string
--- @return nil
--- 发送开火事件
function BattleWeaponUnit.DispatchFireEvent(self, target, actionIndex)
	local eventArgs = {
		target = target,
		actionIndex = actionIndex
	}

	local fireEvent = ys.Event.New(ys.Battle.BattleUnitEvent.FIRE, eventArgs)

	self:DispatchEvent(fireEvent)
end

--- @class BattleWeaponUnit
--- @return nil
--- 发送屏幕震动事件
function BattleWeaponUnit.CheckAndShake(self)
	if self._tmpData.shakescreen ~= 0 then
		ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[self._tmpData.shakescreen])
	end
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的基础角度
function BattleWeaponUnit.GetBaseAngle(self)
	return self._baseAngle
end

--- @class BattleWeaponUnit
--- @return BattleUnit
--- 获取武器的宿主单位
function BattleWeaponUnit.GetHost(self)
	return self._host
end

--- @class BattleWeaponUnit
--- @return BattleUnit
--- ? 获取武器的StandHost?
function BattleWeaponUnit.GetStandHost(self)
	return self._standHost
end

--- @class BattleWeaponUnit
--- @return Vector3
--- 获取武器的位置
function BattleWeaponUnit.GetPosition(self)
	return self._hostPos
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的方向
function BattleWeaponUnit.GetDirection(self)
	return self._host:GetDirection()
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的当前状态
function BattleWeaponUnit.GetCurrentState(self)
	return self._currentState
end


--- @class BattleWeaponUnit
--- @return number
--- 获取武器的装填时间
function BattleWeaponUnit.GetReloadTime(self)
	-- loadSpeed指的是装填属性值
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	if self._reloadMax ~= self._cacheReloadMax or loadSpeed ~= self._cacheHostReload then
		self._cacheReloadMax = self._reloadMax
		self._cacheHostReload = loadSpeed
		self._cacheReloadTime = BattleFormulas.CalculateReloadTime(self._reloadMax, loadSpeed)
	end

	return self._cacheReloadTime
end

--- @class BattleWeaponUnit
--- @param rate number
--- @return number
--- 根据比例获取武器的装填时间
--- BattleSkillManualWeaponReloadBoost.DoDataEffect中有调用
function BattleWeaponUnit.GetReloadTimeByRate(self, rate)
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")
	local newReloadMax = self._cacheReloadMax * rate

	return (BattleFormulas.CalculateReloadTime(newReloadMax, loadSpeed))
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的装填完成时间戳
function BattleWeaponUnit.GetReloadFinishTimeStamp(self)
	local totalReloadBoost = 0
	-- reloadBoost有可能是负数, 表示装填加快...
	for _, reloadBoost in ipairs(self._reloadBoostList) do
		totalReloadBoost = totalReloadBoost + reloadBoost
	end

	return self._reloadRequire + self._CDstartTime + self._jammingTime + totalReloadBoost
end

--- @class BattleWeaponUnit
--- @param factor number
--- @return nil
--- 这个函数没有被使用过，也没有被重载
function BattleWeaponUnit.AppendFactor(self, factor)
	return
end


--- @class BattleWeaponUnit
--- @return nil
--- 开始堵塞开火
function BattleWeaponUnit.StartJamming(self)
	if self._currentState ~= BattleWeaponUnit.STATE_READY then
		self._jammingStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end
end

--- @class BattleWeaponUnit
--- @return nil
--- 结束堵塞开火
function BattleWeaponUnit.JammingEliminate(self)
	if not self._jammingStartTime then
		return
	end

	self._jammingTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._jammingStartTime
	self._jammingStartTime = nil
end

--- @class BattleWeaponUnit
--- @param reloadFactor number
--- @return nil
--- 刷新武器的装填上限值
function BattleWeaponUnit.FlushReloadMax(self, reloadFactor)
	local reloadMax = self._tmpData.reload_max

	reloadFactor = reloadFactor or 1
	self._reloadMax = reloadMax * reloadFactor

	if not self._CDstartTime or self._reloadRequire == 0 then
		return true
	end

	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	self._reloadRequire = BattleWeaponUnit.FlushRequireByInverse(self, loadSpeed)
end

--- @class BattleWeaponUnit
--- @param buff BattleBuffUnit
--- @param reloadFactor number
--- @return nil
--- 添加装填系数到列表
function BattleWeaponUnit.AppendReloadFactor(self, buff, reloadFactor)
	-- 这变量名难绷
	self._reloadFacotrList[buff] = reloadFactor
end

--- @class BattleWeaponUnit
--- @param buff BattleBuffUnit
--- @return nil
--- 从列表中移除装填系数
function BattleWeaponUnit.RemoveReloadFactor(self, buff)
	if self._reloadFacotrList[buff] then
		self._reloadFacotrList[buff] = nil
	end
end


--- @class BattleWeaponUnit
--- @return table<BattleBuffUnit, number>
--- 获取装填系数列表
function BattleWeaponUnit.GetReloadFactorList(self)
	return self._reloadFacotrList
end


--- @class BattleWeaponUnit
--- @return nil
--- 刷新武器的装填需求
function BattleWeaponUnit.FlushReloadRequire(self)
	if not self._CDstartTime or self._reloadRequire == 0 then
		return true
	end
	local requireLoadSpeed = BattleFormulas.CaclulateReloadAttr(self._reloadMax, self._reloadRequire)

	self._reloadRequire = BattleWeaponUnit.FlushRequireByInverse(self, requireLoadSpeed)
end


--- @class BattleWeaponUnit
--- @return number
--- 获取武器的最小索敌范围
function BattleWeaponUnit.GetMinimumRange(self)
	return self._minRangeSqr
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的修正伤害
--- - 标伤 * 武器效率 * 修正系数
function BattleWeaponUnit.GetCorrectedDMG(self)
	return self._correctedDMG
end

--- @class BattleWeaponUnit
--- @return number
--- 获取武器的属性效率
function BattleWeaponUnit.GetConvertedAtkAttr(self)
	return self._convertedAtkAttr
end

--- @class BattleWeaponUnit
--- @param atkAttrTrans string: 要转换的攻击属性
--- @param atkAttrTransA number
--- @param atkAttrTransB number
--- @return nil
--- 设置攻击属性转换参数
function BattleWeaponUnit.SetAtkAttrTrasnform(self, atkAttrTrans, atkAttrTransA, atkAttrTransB)
	self._atkAttrTrans = atkAttrTrans
	self._atkAttrTransA = atkAttrTransA
	self._atkAttrTransB = atkAttrTransB
end

--- @class BattleWeaponUnit
--- @param attrs table<string, number>
--- @return number
--- 获取攻击属性转换值
function BattleWeaponUnit.GetAtkAttrTrasnform(self, attrs)
	local atkAttrTransform

	if self._atkAttrTrans then
		local atkAttrValue = attrs[self._atkAttrTrans] or 0

		atkAttrTransform = math.min(atkAttrValue / self._atkAttrTransA, self._atkAttrTransB)
	end

	return atkAttrTransform
end

--- @class BattleWeaponUnit
--- @return boolean
--- 判断武器是否准备好
function BattleWeaponUnit.IsReady(self)
	return self._currentState == self.STATE_READY
end

--- @class BattleWeaponUnit
--- @param loadSpeed number
--- @return number
--- 通过反向计算刷新装填需求时间
function BattleWeaponUnit.FlushRequireByInverse(self, loadSpeed)
	local elapsedTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._CDstartTime
	local reloadedAmount = BattleFormulas.CaclulateReloaded(elapsedTime, loadSpeed)
	local remainingReload = self._reloadMax - reloadedAmount

	return elapsedTime + BattleFormulas.CalculateReloadTime(remainingReload, BattleAttr.GetCurrent(self._host, "loadSpeed"))
end

function BattleWeaponUnit.SetSupportWeapon(self)
	self._isSupportWeapon = true
end

function BattleWeaponUnit.SetCardPuzzleDamageEnhance(self, cardPuzzleEnhance)
	self._cardPuzzleEnhance = cardPuzzleEnhance
end

function BattleWeaponUnit.GetCardPuzzleDamageEnhance(self)
	return self._cardPuzzleEnhance or 1
end

function BattleWeaponUnit.GetReloadRate(self)
	if self._currentState == self.STATE_READY then
		return 0
	elseif self._CDstartTime then
		return (self:GetReloadFinishTimeStamp() - pg.TimeMgr.GetInstance():GetCombatTime()) / self._reloadRequire
	else
		return 1
	end
end

function BattleWeaponUnit.WeaponStatistics(self, damage, isCrit, isMiss)
	self._CLDCount = self._CLDCount + 1
	self._damageSum = damage + self._damageSum

	if isCrit then
		self._CTSum = self._CTSum + 1
	end

	if not isMiss then
		self._ACCSum = self._ACCSum + 1
	end
end

function BattleWeaponUnit.GetDamageSUM(self)
	return self._damageSum
end

function BattleWeaponUnit.GetCTRate(self)
	return self._CTSum / self._CLDCount
end

function BattleWeaponUnit.GetACCRate(self)
	return self._ACCSum / self._CLDCount
end
