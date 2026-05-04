ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable
local WeaponSearchType = BattleConst.WeaponSearchType
local WeaponSuppressType = BattleConst.WeaponSuppressType
local BattleFleetRangeAntiAirUnit = class("BattleFleetRangeAntiAirUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleFleetRangeAntiAirUnit = BattleFleetRangeAntiAirUnit
BattleFleetRangeAntiAirUnit.__name = "BattleFleetRangeAntiAirUnit"

--- @class BattleFleetRangeAntiAirUnit : BattleWeaponUnit
--- 舰队范围防空单元：继承自BattleWeaponUnit，由多个船员单元的远程防空武器组成，对指定区域内的敌机造成AOE伤害
function BattleFleetRangeAntiAirUnit.Ctor(self)
	BattleFleetRangeAntiAirUnit.super.Ctor(self)

	self._currentState = BattleFleetRangeAntiAirUnit.STATE_DISABLE

	self:init()
end

--- 初始化各项属性，构造临时的武器模板数据
function BattleFleetRangeAntiAirUnit.init(self)
	self._crewUnitList = {}
	self._hitFXResIDList = {}
	self._range = 0
	self._majorEmitterList = {}
	self._GCD = 0.5
	self._tmpData = {}
	self._tmpData.bullet_ID = {
		BattleConfig.AntiAirConfig.RangeBulletID
	}
	self._tmpData.barrage_ID = {
		BattleConfig.AntiAirConfig.RangeBarrageID
	}
	self._tmpData.aim_type = BattleConst.WeaponAimType.AIM
	self._tmpData.axis_angle = 0
	self._tmpData.search_type = WeaponSearchType.SECTOR
	self._tmpData.suppress = WeaponSuppressType.NONE
	self._tmpData.queue = 0
	self._tmpData.action_index = ""
	self._tmpData.fire_sfx = "battle/cannon-air"
	self._tmpData.spawn_bound = BattleConfig.AntiAirConfig.RangeAntiAirBone
	self._tmpData.shakescreen = 0
	self._tmpData.fire_fx_loop_type = 0
	self._tmpData.attack_attribute = BattleConst.WeaponDamageAttr.AIR
	self._tmpData.attack_attribute_ratio = 100
	self._tmpData.expose = 0
	self._fireFXFlag = self._tmpData.fire_fx_loop_type
	self._preCastInfo = {}
	self._convertedBulletVelocity = BattleFormulas.ConvertBulletSpeed(BattleDataFunction.GetBulletTmpDataFromID(self._tmpData.bullet_ID[1]).velocity)
	self._bulletList = self._tmpData.bullet_ID

	self:ShiftBarrage(self._tmpData.barrage_ID)
end

--- @param crewUnit CrewUnit 加入的船员单元
--- 添加船员单元，读取其远程防空武器列表并刷新属性
function BattleFleetRangeAntiAirUnit.AppendCrewUnit(self, crewUnit)
	local fleetRangeAAList = crewUnit:GetFleetRangeAntiAirList()

	if #fleetRangeAAList > 0 then
		self._currentState = BattleFleetRangeAntiAirUnit.STATE_READY
		self._crewUnitList[crewUnit] = fleetRangeAAList

		self:flush()
	end
end

--- @param crewUnit CrewUnit 移除的船员单元
--- 如果移除的是当前宿主，先解除绑定
function BattleFleetRangeAntiAirUnit.RemoveCrewUnit(self, crewUnit)
	if self._crewUnitList[crewUnit] then
		if crewUnit == self._host then
			self._host:DetachFleetRangeAAWeapon()
		end

		self._crewUnitList[crewUnit] = nil

		self:flush()
	end
end

--- @param crewUnit CrewUnit 需要刷新的船员单元
--- 根据其远程防空武器列表，为空则移除，否则更新
function BattleFleetRangeAntiAirUnit.FlushCrewUnit(self, crewUnit)
	local fleetRangeAAList = crewUnit:GetFleetRangeAntiAirList()

	if #fleetRangeAAList <= 0 then
		self:RemoveCrewUnit(crewUnit)
	elseif self._crewUnitList[crewUnit] == nil then
		self:AppendCrewUnit(crewUnit)
	else
		self._crewUnitList[crewUnit] = fleetRangeAAList

		self:flush()
	end
end

--- @param bulletID number 子弹ID
--- @param target BattleUnit 目标
--- @return BattleBulletUnit 生成的子弹
function BattleFleetRangeAntiAirUnit.Spawn(self, bulletID, target)
	local spawnBullet
	local aimPoint = self:getAimPoint(target)
	local bullet = self._dataProxy:CreateBulletUnit(bulletID, self._host, self, aimPoint)

	self:setBulletSkin(bullet, bulletID)
	self:TriggerBuffWhenSpawn(bullet)

	return bullet
end

--- @param target BattleUnit|nil 目标
--- @return Vector3 瞄准点坐标
--- 有目标则瞄准目标位置，否则朝前方最远射程处发射
function BattleFleetRangeAntiAirUnit.getAimPoint(self, target)
	local aimPoint

	if target then
		local targetPos = target:GetPosition()

		aimPoint = Vector3(targetPos.x + self._aimOffset, 0, targetPos.z)
	else
		local hostPos = self:GetHost():GetPosition()
		local aimZ = hostPos.z
		local aimX = hostPos.x + self._maxRangeSqr * self._hostIFF + self._aimOffset

		aimPoint = Vector3(aimX, 0, aimZ)
	end

	return aimPoint
end

--- @return table<CrewUnit, table> 船员单元列表
function BattleFleetRangeAntiAirUnit.GetCrewUnitList(self)
	return self._crewUnitList
end

--- @return number 防空射程
function BattleFleetRangeAntiAirUnit.GetRange(self)
	return self._range
end

--- @return number 攻击角度
function BattleFleetRangeAntiAirUnit.GetAttackAngle(self)
	return self._aimAngle
end

--- @return number 装填时间
function BattleFleetRangeAntiAirUnit.GetReloadTime(self)
	return self._interval
end

--- 刷新防空属性：遍历所有船员单元的远程防空武器，按防空火力权重分配伤害
function BattleFleetRangeAntiAirUnit.flush(self)
	self._range = 0
	self._interval = 0
	self._aimAngle = 0
	self._aimOffset = 0
	self._maxRangeSqr = 0
	self._minRangeSqr = 0
	self._hitFXResIDList = {}
	self._SFXID = nil
	self._exploRange = 0

	local weightInput = {}
	local weaponCount = 0

	for crewUnit, weaponList in pairs(self._crewUnitList) do
		for _, weapon in ipairs(weaponList) do
			weaponCount = weaponCount + 1
			self._interval = self._interval + weapon:GetReloadTime()

			local weaponTempData = weapon:GetTemplateData()

			self._range = self._range + weaponTempData.range
			self._SFXID = weaponTempData.fire_sfx
			self._aimAngle = self._aimAngle + weapon:GetAttackAngle()
			self._maxRangeSqr = self._maxRangeSqr + weapon:GetWeaponMaxRange()
			self._minRangeSqr = self._minRangeSqr + weapon:GetWeaponMinRange()

			local bulletTemp = BattleDataFunction.GetBulletTmpDataFromID(weapon:GetTemplateData().bullet_ID[1])

			self._hitFXResIDList[weapon] = bulletTemp.hit_fx
			self._exploRange = self._exploRange + bulletTemp.hit_type.range
			self._aimOffset = self._aimOffset + (bulletTemp.extra_param.aim_offset or 0)
		end

		local antiAirPower = crewUnit:GetAttrByName("antiAirPower")
		local weight = BattleFormulas.AntiAirPowerWeight(antiAirPower)
		local weightEntry = {
			weight = weight,
			rst = crewUnit
		}

		weightInput[#weightInput + 1] = weightEntry
	end

	if weaponCount == 0 then
		self._currentState = BattleFleetRangeAntiAirUnit.STATE_DISABLE
	else
		self:SwitchHost()

		self._maxRangeSqr = self._maxRangeSqr / weaponCount
		self._minRangeSqr = self._minRangeSqr / weaponCount
		self._exploRange = self._exploRange / weaponCount
		self._aimAngle = self._aimAngle / weaponCount
		self._aimOffset = self._aimOffset / weaponCount * self._host:GetIFF()
		self._interval = self._interval / weaponCount + 0.5
		self._weightList, self._totalWeight = BattleFormulas.GenerateWeightList(weightInput)
	end
end

--- @param bullet BattleBulletUnit 子弹
--- 区域AOE伤害：在爆炸范围内对敌方飞机造成防空伤害
function BattleFleetRangeAntiAirUnit.DoAreaSplit(self, bullet)
	local function areaDamage(areaTargets)
		local aliveTargets = {}
		local aircraftList = self._dataProxy:GetAircraftList()

		for _, areaEntry in ipairs(areaTargets) do
			if areaEntry.Active then
				local aircraft = aircraftList[areaEntry.UID]

				if aircraft and aircraft:IsVisitable() then
					aliveTargets[#aliveTargets + 1] = aircraft
				end
			end
		end

		local totalDamage = BattleFormulas.CalculateFleetAntiAirTotalDamage(self)
		local meteoRatio = BattleFormulas.GetMeteoDamageRatio(#aliveTargets)

		for index, target in ipairs(aliveTargets) do
			local dmg = math.max(1, math.floor(totalDamage * meteoRatio[index]))
			local rst = BattleFormulas.WeightListRandom(self._weightList, self._totalWeight)

			self._dataProxy:HandleDirectDamage(target, dmg, rst)
		end
	end

	for crewUnit, _ in pairs(self._crewUnitList) do
		crewUnit:TriggerBuff(BattleConst.BuffEffectType.ON_ANTIAIR_FIRE_FAR, {})
		crewUnit:PlayFX(self._crewUnitList[crewUnit][1]:GetTemplateData().fire_fx, true)
	end

	for weapon, hitFXResID in pairs(self._hitFXResIDList) do
		local randomOffsetX = (math.random() * 2 - 1) * self._exploRange
		local randomOffsetZ = (math.random() * 2 - 1) * self._exploRange
		local fxPos = bullet:GetPosition() + Vector3(randomOffsetX, 10, randomOffsetZ)
		local fx = ys.Battle.BattleFXPool.GetInstance():GetFX(hitFXResID)

		pg.EffectMgr.GetInstance():PlayBattleEffect(fx, fxPos, true)
	end

	self._dataProxy:SpawnColumnArea(BattleConst.BulletField.AIR, bullet:GetIFF(), bullet:GetPosition(), self._exploRange, -1, areaDamage)

	if RANGE_ANTI_AREA then
		local alertArea = ys.Battle.BattleFXPool.GetInstance():GetFX("AlertArea")

		alertArea.transform.localScale = Vector3(self._exploRange, 1, self._exploRange)

		pg.EffectMgr.GetInstance():PlayBattleEffect(alertArea, bullet:GetPosition())
	end

	self._dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
end

--- 切换宿主：选择主单位索引最小的船员作为新宿主
function BattleFleetRangeAntiAirUnit.SwitchHost(self)
	local crewList = {}

	for crewUnit, _ in pairs(self._crewUnitList) do
		table.insert(crewList, crewUnit)
	end

	table.sort(crewList, function(a, b)
		return a:GetMainUnitIndex() < b:GetMainUnitIndex()
	end)

	local newHost = crewList[1]

	if self._host == newHost then
		return
	end

	self:SetHostData(newHost)
	self._host:AttachFleetRangeAAWeapon(self)
end

--- @return table<number, BattleUnit> 筛选后的敌机列表
function BattleFleetRangeAntiAirUnit.GetFilteredList(self)
	local filteredTargets = self:FilterTarget()
	local filteredByRange = self:FilterRange(filteredTargets)

	return (self:FilterAngle(filteredByRange))
end

--- @return table<number, BattleUnit> IFF不同的可见飞机
function BattleFleetRangeAntiAirUnit.FilterTarget(self)
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

--- 非DISABLE状态才调用父类Update
function BattleFleetRangeAntiAirUnit.Update(self)
	if self._currentState ~= BattleFleetRangeAntiAirUnit.STATE_DISABLE then
		BattleFleetRangeAntiAirUnit.super.Update(self)
	end
end

function BattleFleetRangeAntiAirUnit.RemovePrecastTimer(self)
	return
end

function BattleFleetRangeAntiAirUnit.Dispose(self)
	BattleFleetRangeAntiAirUnit.super.Dispose(self)

	self._crewUnitList = nil
	self._weightList = nil
	self._hitFXResIDList = nil
	self._SFXID = nil
end
