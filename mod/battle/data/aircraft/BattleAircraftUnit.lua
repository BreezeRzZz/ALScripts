ys = ys or {}
-- TODO
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAircraftUnit = class("BattleAircraftUnit")

ys.Battle.BattleAircraftUnit = BattleAircraftUnit
BattleAircraftUnit.__name = "BattleAircraftUnit"
BattleAircraftUnit.STATE_CREATE = "Create"
BattleAircraftUnit.STATE_ATTACK = "Attack"
BattleAircraftUnit.STATE_DESTORY = "Destory"
-- BattleConfig.AircraftHeight = 10
BattleAircraftUnit.HEIGHT = BattleConfig.AircraftHeight + 5

function BattleAircraftUnit.Ctor(self, UID)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._uniqueID = UID
	self._speedExemptKey = "air_" .. UID
	self._dir = ys.Battle.BattleConst.UnitDir.RIGHT
	self._type = BattleConst.UnitType.AIRCRAFT_UNIT
	self._currentState = self.STATE_CREATE
	self._distanceBackup = {}
	self._battleProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._frame = 0
	self._weaponPotential = 1

	self:Init()
end

-- 被BattleDataProxy.doCreateAirUnit调用
function BattleAircraftUnit.SetBound(self, top, bottom)
	-- 从上层调用来看，一般top和bottom分别对应playerArea的上边界和下边界
	-- 绝大多数图都是：top = 88, bottom = 20
	self._top = top
	self._bottom = bottom

	-- 是否有布朗运动
	if self._tmpData.spawn_brownian == -1 then
		self._speedZ = 0
	else
		-- 范围是 -0.25 到 0.25
		self._speedZ = (math.random() - 0.5) * 0.5
	end
	-- 设置目标Z轴位置
	self:SetTargetZ()
end

-- 被BattleDataProxy.doCreateAirUnit调用
function BattleAircraftUnit.SetViewBoundData(self, cameraTop, cameraBottom, cameraLeft, cameraRight)
	self._cameraTop = cameraTop + 3
	self._cameraBottom = cameraBottom - 23
	self._cameraLeft = cameraLeft - 3
	self._cameraRight = cameraRight + 10
end

-- Aircraft的Update函数: 主要就是更新位置、更新速度和更新武器
function BattleAircraftUnit.Update(self, timeStamp)
	self._pos:Add(self._speed)
	self:UpdateSpeed()
	self:UpdateWeapon()
end

-- BattleAircraftCharacter.AddModel调用
function BattleAircraftUnit.ActiveCldBox(self)
	self._cldComponent:SetActive(true)
end

-- BattleCldSystem.DeleteAircraftCld调用
function BattleAircraftUnit.DeactiveCldBox(self)
	self._cldComponent:SetActive(false)
end

-- BattleBuffDeactiveCLDBox.onAttach/onRemove调用
function BattleAircraftUnit.SetCldBoxImmune(self, isImmune)
	self._cldComponent:SetImmuneCLD(isImmune)
end

-- 被BattleAircraftUnit.Ctor调用
function BattleAircraftUnit.Init(self)
	self._aliveState = true
	self._speed = Vector3.zero
	self._pos = Vector3.zero
	self._undefeated = false
	self._labelTagList = {}
end

function BattleAircraftUnit.Clear(self)
	if self._createTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._createTimer)

		self._createTimer = nil
	end

	self:ShutdownWeapon()

	self._distanceBackup = {}
end

function BattleAircraftUnit.SetWeaponPreCastBound(self)
	return
end

function BattleAircraftUnit.EnterGCD(self)
	return
end

-- 被BattleAircraftUnit.SetTemplate调用
function BattleAircraftUnit.CreateWeapon(self)
	local var_12_0 = {}

	for iter_12_0, iter_12_1 in ipairs(self._tmpData.weapon_ID) do
		var_12_0[iter_12_0] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(iter_12_1, self, iter_12_0, self._weaponPotential)
	end

	return var_12_0
end

function BattleAircraftUnit.ShutdownWeapon(self)
	for _, weapon in ipairs(self:GetWeapon()) do
		weapon:Clear()
	end
end

function BattleAircraftUnit.UpdateWeapon(self)
	if self._currentState == self.STATE_ATTACK then
		for _, weapon in ipairs(self:GetWeapon()) do
			weapon:Update()
		end
	end
end

-- BattleHiveUnit.SpawnAircraft或BattlePointAirStrikeUnit.DoAttack调用
function BattleAircraftUnit.SetStrikePoint(self, strikePoint)
	self._strikePoint = strikePoint

	self:SetPosition(Vector3(self._pos.x, self._pos.y, strikePoint.z))
end

function BattleAircraftUnit.GetStrikePoint(self)
	return self._strikePoint
end

function BattleAircraftUnit.GetWeapon(self)
	return self._weapon
end

function BattleAircraftUnit.GetCurrentHP(self)
	return self._currentHP
end

function BattleAircraftUnit.GetMaxHP(self)
	return ys.Battle.BattleAttr.GetCurrent(self, "maxHP")
end

function BattleAircraftUnit.IsUndefeated(self)
	return self._undefeated
end

function BattleAircraftUnit.IsAlive(self)
	return self._aliveState
end

function BattleAircraftUnit.IsCease(self)
	return false
end

function BattleAircraftUnit.GetOxyState(self)
	return nil
end

function BattleAircraftUnit.IsBoss(self)
	return nil
end

function BattleAircraftUnit.HandleDamageToDeath(self)
	self:UpdateHP(-self._currentHP, {
		isMiss = false,
		isCri = false,
		isHeal = false
	})
end

-- 舰载机的耐久更新主逻辑
-- 相比BattleUnit.UpdateHP，简单非常多
function BattleAircraftUnit.UpdateHP(self, dHP, extraInfo)
	local isMiss = extraInfo.isMiss
	local isCri = extraInfo.isCri
	local isHeal = extraInfo.isHeal

	self._currentHP = self._currentHP + dHP

	local maxHP = self:GetMaxHP()

	if maxHP < self._currentHP then
		self._currentHP = maxHP
	end

	if self._currentHP < 0 then
		self._currentHP = 0
	end

	local updateAircraftHPArgs = {
		dHP = dHP,
		isMiss = isMiss,
		isCri = isCri,
		isHeal = isHeal
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_AIR_CRAFT_HP, updateAircraftHPArgs))

	if self._currentHP <= 0 and self:IsAlive() then
		self:onDead()
	end

	return dHP
end

function BattleAircraftUnit.onDead(self)
	self._currentState = self.STATE_DESTORY
	self._aliveState = false
end

-- 舰载机速度计算
function BattleAircraftUnit.UpdateSpeed(self)
	-- 从AddCreateTimer来看，初始速度是只在X轴方向的
	local speedDir = self._speedDir
	local speed = self._velocity * self:GetSpeedRatio()

	self._speed:Copy(speedDir)
	self._speed:Mul(speed)

	local position = self:GetPosition()
	-- y < 10时，速度会受到影响，y越小，速度越慢
	-- (但y轴本来也没啥用，只是动画效果而已)
	if position.y < BattleAircraftUnit.HEIGHT then
		self._speed.y = math.max(0.4, 1 - position.y / BattleConfig.AircraftHeight)
	end
	-- 从上面可知，_speedZ 在 -0.25 到 0.25 之间变化
	-- 这实际就是下面触发SetTargetZ时的Z轴速度（没有被覆盖)
	self._speed.z = speed * self._speedZ
	-- 如果设定了随机运动, 则根据目标Z轴位置调整Z轴速度
	if self._tmpData.spawn_brownian == 1 then
		local dz = self._targetZ - position.z
		if speed < dz then
			self._speed.z = speed * 0.5
		elseif dz < -speed then
			self._speed.z = -speed * 0.5
		else
			-- 当dz在-speed到speed之间时，说明已经接近目标位置了
			-- 设定一次新的目标Z轴位置
			self:SetTargetZ()
		end
	end
end

function BattleAircraftUnit.OutBound(self)
	self._undefeated = true

	self:onDead()
end

function BattleAircraftUnit.GetSize(self)
	-- 创建状态下，随着Y轴位置的上升，大小逐渐变大
	-- 是与y轴位置成正比的，当y轴位置达到HEIGHT时，大小为_scale
	-- 最小为0.1倍
	-- (但不影响任何碰撞箱大小和相关判定，仅是视觉效果)
	if self._currentState == self.STATE_CREATE then
		return Mathf.Clamp(self:GetPosition().y / BattleAircraftUnit.HEIGHT, 0.1, self._scale)
	else
		return self._scale
	end
end

-- 被BattleDataFunction.CreateAircraftUnit调用
function BattleAircraftUnit.SetTemplate(self, tmpData)
	self._tmpData = tmpData

	self:InitCldComponent()
	-- 从模板设置属性，只涉及部分属性(如耐久、速度、crashDMG等)
	ys.Battle.BattleAttr.SetAircraftAttFromTemp(self)

	self._currentHP = self:GetMaxHP()
	self._weapon = self:CreateWeapon()
	self._modelID = tmpData.model_ID

	local speed = tmpData.speed + self:GetAttrByName("aircraftBooster")

	self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(speed)
	self._scale = tmpData.scale or 1
end

-- 被BattleDataFunction.CreateAircraftUnit调用
function BattleAircraftUnit.SetWeanponPotential(self, weaponPotential)
	self._weaponPotential = weaponPotential
end

-- BattleAircraftUnit.SetBound和BattleAircraftUnit.UpdateSpeed调用
function BattleAircraftUnit.SetTargetZ(self)
	-- 上面说到，top一般是88，bottom一般是20
	local bottom = self._bottom
	local top = self._top
	-- 以中线为基准，+-0.3范围内随机
	-- 那么中线是54, +-20.4的范围，也就是33.6到74.4之间
	-- 所以，舰载机的Z轴范围只会在33.6到74.4之间波动, 十分影响武器的投放
	self._targetZ = (bottom + top) * 0.5 + (top - bottom) * (math.random() - 0.5) * 0.6
end

-- 被BattleDataFunction.CreateAircraftUnit调用
-- 一般来讲，mother是创建该舰载机的BattleHiveUnit/BattleSupportHiveUnit
-- 而(Support)HiveUnit又是由BattleUnit创建的一种WeaponUnit
-- 这里的mother实际上是WeaponUnit的宿主单位(即BattleUnit),因为BattleHiveUnit.SpawnAircraft传入的是其host作为mother参数
function BattleAircraftUnit.SetMotherUnit(self, mother)
	self._motherUnit = mother

	local IFF = self._motherUnit:GetIFF()

	self:SetIFF(IFF)
	-- 舰载机的SetAttr有重载
	-- 一般情况下，SetAttr是设置了一个元表来"引用"母单位的属性(例如，子弹引用武器宿主的属性)
	-- 但舰载机的SetAttr则是直接从母单位复制属性(是真正创建了一份新的属性表，不是引用)
	-- 因此体现出"快照"的效果(两者从创建的时间点开始属性就不再联动)
	self:SetAttr(mother)
	-- 从motherUnit获取bound_bone
	local motherWeaponBoundBone = self._motherUnit:GetWeaponBoundBone()
	-- remote bound的用处：会让飞机生成位置相对于母舰位置有一个偏移
	if motherWeaponBoundBone.remote then
		local remote = motherWeaponBoundBone.remote
		local remoteVector = Vector3(remote[1], remote[2], remote[3])

		remoteVector.x = remoteVector.x * IFF

		local mainUnitPosition = self._battleProxy:GetStageInfo().mainUnitPosition
		local flagShipPos
		-- 用到remote，则总是基于旗舰位置来计算飞机位置
		if mainUnitPosition and mainUnitPosition[IFF] then
			flagShipPos = mainUnitPosition[IFF][1]
		else
			flagShipPos = BattleConfig.MAIN_UNIT_POS[IFF][1]
		end

		local spawnPos = flagShipPos + remoteVector

		self:SetPosition(spawnPos)
	else
		-- 否则，直接就是母单位位置
		self:SetPosition(self._motherUnit:GetPosition())
	end

	if mother:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self._dir = BattleConst.UnitDir.RIGHT
		self._isPlayerAircraft = true
	else
		self._dir = BattleConst.UnitDir.LEFT
	end
end

function BattleAircraftUnit.GetLabelTag(self)
	return self._labelTagList
end

function BattleAircraftUnit.AddLabelTag(self, labelTag)
	table.insert(self._labelTagList, labelTag)

	local labelTagList = self:GetAttrByName("labelTag")

	labelTagList[labelTag] = (labelTagList[labelTag] or 0) + 1
end

function BattleAircraftUnit.ContainsLabelTag(self, labelTags)
	if self._labelTagList == nil then
		return false
	end

	for _, labelTag in ipairs(labelTags) do
		if table.contains(self._labelTagList, labelTag) then
			return true
		end
	end

	return false
end

function BattleAircraftUnit.SetIFF(self, IFF)
	self._IFF = IFF
end

function BattleAircraftUnit.SetPosition(self, pos)
	self._pos:Set(pos.x, pos.y, pos.z)
end

-- 视界范围限制
function BattleAircraftUnit.IsOutViewBound(self)
	local pos = self:GetPosition()
	local x = pos.x
	local z = pos.z

	if x > self._cameraRight or z > self._cameraTop or z < self._cameraBottom then
		return true
	end
end

function BattleAircraftUnit.GetDistance(self, otherUnit)
	local frameIndex = self._battleProxy.FrameIndex

	if self._frame ~= frameIndex then
		self._distanceBackup = {}
		self._frame = frameIndex
	end
	-- 先从缓存中取距离，没有的话就计算并缓存
	local distance = self._distanceBackup[otherUnit]

	if distance == nil then
		distance = Vector3.Distance(pg.Tool.FilterY(self:GetPosition()), pg.Tool.FilterY(otherUnit:GetPosition()))
		self._distanceBackup[otherUnit] = distance

		otherUnit:backupDistance(self, distance)
	end

	return distance
end

-- 到本单位的距离缓存
function BattleAircraftUnit.backupDistance(self, unit, distance)
	local frameIndex = self._battleProxy.FrameIndex

	if self._frame ~= frameIndex then
		self._distanceBackup = {}
		self._frame = frameIndex
	end

	self._distanceBackup[unit] = distance
end

function BattleAircraftUnit.GetSkinID(self)
	return self._modelID
end

function BattleAircraftUnit.SetSkinID(self, skinID)
	self._skinID = skinID
	self._modelID = BattleDataFunction.GetEquipSkin(self._skinID)

	for _, weapon in ipairs(self._weapon) do
		weapon:SetDerivateSkin(skinID)
	end
end

function BattleAircraftUnit.SetSkinData(self, skinData)
	return
end

-- 注意舰载机的属性重载
function BattleAircraftUnit.SetAttr(self, mother)
	ys.Battle.BattleAttr.SetAircraftAttFromMother(self, mother)
end

function BattleAircraftUnit.GetAttr(self)
	return ys.Battle.BattleAttr.GetAttr(self)
end

function BattleAircraftUnit.GetAttrByName(self, attrType)
	return ys.Battle.BattleAttr.GetCurrent(self, attrType)
end

function BattleAircraftUnit.GetMotherUnit(self)
	return self._motherUnit
end

function BattleAircraftUnit.GetUniqueID(self)
	return self._uniqueID
end

function BattleAircraftUnit.GetIFF(self)
	return self._IFF
end

function BattleAircraftUnit.GetCurrentState(self)
	return self._currentState
end

function BattleAircraftUnit.GetVelocity(self)
	return self._velocity
end

function BattleAircraftUnit.GetSpeed(self)
	return self._speed
end

function BattleAircraftUnit.GetPosition(self)
	return self._pos
end

function BattleAircraftUnit.GetBornPosition(self)
	return nil
end

function BattleAircraftUnit.GetCLDZCenterPosition(self)
	local boxSize = self:GetBoxSize()

	return Vector3(self._pos.x, self._pos.y, self._pos.z + boxSize.z)
end

-- 被瞄准点加上aim_offset
function BattleAircraftUnit.GetBeenAimedPosition(self)
	local aim_offset = self:GetTemplate().aim_offset
	local centerPosition = self:GetCLDZCenterPosition()

	if not aim_offset then
		return centerPosition
	end

	return Vector3(centerPosition.x + aim_offset[1], centerPosition.y + aim_offset[2], centerPosition.z + aim_offset[3])
end

function BattleAircraftUnit.GetDirection(self)
	return self._dir
end

function BattleAircraftUnit.GetTemplate(self)
	return self._tmpData
end

function BattleAircraftUnit.GetTemplateID(self)
	return self._tmpData.id
end

function BattleAircraftUnit.GetUnitType(self)
	return self._type
end

function BattleAircraftUnit.GetHPRate(self)
	return self._currentHP / self:GetMaxHP()
end

function BattleAircraftUnit.GetBoxSize(self)
	return self._cldComponent:GetCldBoxSize()
end

function BattleAircraftUnit.GetSpeedRatio(self)
	return BattleVariable.GetSpeedRatio(self:GetSpeedExemptKey(), self._IFF)
end

-- speedExemptKey的格式统一为类型+UID
-- 例如aircraft的就是"air_"..UID
function BattleAircraftUnit.GetSpeedExemptKey(self)
	return self._speedExemptKey
end

function BattleAircraftUnit.IsPlayerAircraft(self)
	return self._isPlayerAircraft
end

function BattleAircraftUnit.IsShowHPBar(self)
	return false
end

function BattleAircraftUnit.SetUnVisitable(self)
	ys.Battle.BattleAttr.UnVisitable(self)
end

function BattleAircraftUnit.SetVisitable(self)
	ys.Battle.BattleAttr.Visitable(self)
end

function BattleAircraftUnit.IsVisitable(self)
	return ys.Battle.BattleAttr.IsVisitable(self)
end

function BattleAircraftUnit.OverrideDeadFX(self, deadFX)
	self._deadFX = deadFX
end

function BattleAircraftUnit.GetDeadFX(self)
	return self._deadFX
end

BattleAircraftUnit.AIRCRAFT_TRIGGER = {
	ys.Battle.BattleConst.BuffEffectType.ON_BULLET_COLLIDE_BEFORE,
	ys.Battle.BattleConst.BuffEffectType.ON_BOMB_BULLET_BANG,
	ys.Battle.BattleConst.BuffEffectType.ON_TORPEDO_BULLET_BANG
}

-- 舰载机单位的Buff触发
-- 会传递到motherUnit触发
function BattleAircraftUnit.TriggerBuff(self, effectType, args)
	if table.contains(BattleAircraftUnit.AIRCRAFT_TRIGGER, effectType) and self._motherUnit and self._motherUnit:IsAlive() then
		self._motherUnit:TriggerBuff(effectType, args)
	end
end

-- BattleHiveUnit.createMajorEmitter/SingleFire调用
function BattleAircraftUnit.AddCreateTimer(self, direction, delay)
	self._currentState = self.STATE_CREATE
	self._speedDir = direction
	delay = delay or 1.5
	-- 创建后delay(默认1.5)秒内，不能攻击
	-- 从HiveUnit传过来的参数来看，createMajorEmitter传入的delay是1.5
	-- 而SingleFire传入的delay是1
	local function onTimerEnds()
		-- STATE_ATTACK关联到BattleAircraftUnit.UpdateWeapon
		self._currentState = self.STATE_ATTACK
		self._speedDir = Vector3(self._dir, 0, 0)

		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._createTimer)

		self._createTimer = nil
	end

	self._createTimer = pg.TimeMgr.GetInstance():AddBattleTimer("AddCreateTimer", 0, delay, onTimerEnds)
end

function BattleAircraftUnit.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
end

function BattleAircraftUnit.InitCldComponent(self)
	local cld_box = self:GetTemplate().cld_box
	local cld_offset = self:GetTemplate().cld_offset
	local cldOffsetX = cld_offset[1]

	if self:GetDirection() == ys.Battle.BattleConst.UnitDir.LEFT then
		cldOffsetX = cldOffsetX * -1
	end
	-- X和Z轴需要应用cld_offset偏移
	self._cldComponent = ys.Battle.BattleCubeCldComponent.New(cld_box[1], cld_box[2], cld_box[3], cldOffsetX, cld_offset[3])

	local cldData = {
		type = BattleConst.CldType.AIRCRAFT,
		IFF = self:GetIFF(),
		UID = self:GetUniqueID()
	}

	self._cldComponent:SetCldData(cldData)
end

function BattleAircraftUnit.GetCldBox(self)
	return self._cldComponent:GetCldBox(self:GetPosition())
end

function BattleAircraftUnit.GetCldData(self)
	return self._cldComponent:GetCldData()
end

function BattleAircraftUnit.AddBuff(self)
	return
end

function BattleAircraftUnit.SetBuffStack(self)
	return
end

function BattleAircraftUnit.RemoveBuff(self)
	return
end

function BattleAircraftUnit.CloakExpose(self)
	return
end

function BattleAircraftUnit.GetCurrentOxyState(self)
	return nil
end

function BattleAircraftUnit.RemoveRemoteBoundBone(self)
	return
end

function BattleAircraftUnit.SetRemoteBoundBone(self)
	return
end

function BattleAircraftUnit.GetRemoteBoundBone(self)
	return
end
