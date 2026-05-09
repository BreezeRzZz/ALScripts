ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleFormulas = ys.Battle.BattleFormulas
-- 即(0,1,0)
local vector3Up = Vector3.up
local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local viewInterval = 1 / ys.Battle.BattleConfig.viewFPS
local BattleConst = ys.Battle.BattleConst
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType

ys.Battle.BattleBulletUnit = class("BattleBulletUnit")
ys.Battle.BattleBulletUnit.__name = "BattleBulletUnit"

local BattleBulletUnit = ys.Battle.BattleBulletUnit

-- 30帧, 每帧计算一次加速度
BattleBulletUnit.ACC_INTERVAL = BattleConfig.calcInterval
-- 追踪角度大于10度(对应的弧度余弦值)才进行追踪调整
BattleBulletUnit.TRACKER_ANGLE = math.cos(math.deg2Rad * 10)
BattleBulletUnit.MIRROR_RES = "_mirror"

-- 子弹的加速主逻辑
-- 作为BattleBulletUnit.updateSpeed之一(在BattleBulletUnit.InitSpeed中设定)
-- 被BattleBulletUnit.Update调用
function BattleBulletUnit.doAccelerate(self, timeStamp)
	local accU, accV = self:GetAcceleration(timeStamp)

	if accU == 0 and accV == 0 then
		return
	end
	-- 如果u方向加速度导致速度反向，则反转加速度的u方向(x方向)
	if accU < 0 and self._speedLength + accU < 0 then
		self:reverseAcceleration()
	end
	-- 速度差向量 = 加速度u方向分量 + 加速度v方向分量
	-- 加速度u方向分量 = 原速度方向单位向量 * accU
	-- 加速度v方向分量 = 速度法线向量(垂直于速度方向) * accV
	self._speed:Set(self._speed.x + self._speedNormal.x * accU + self._speedCross.x * accV, self._speed.y + self._speedNormal.y * accU + self._speedCross.y * accV, self._speed.z + self._speedNormal.z * accU + self._speedCross.z * accV)

	-- 以下重新计算速度大小、速度方向单位向量、速度法线向量
	self._speedLength = self._speed:Magnitude()

	if self._speedLength ~= 0 then
		self._speedNormal:Copy(self._speed):Div(self._speedLength)
	end

	self._speedCross:Copy(self._speedNormal):Cross2(vector3Up)
end

-- 子弹的追踪主逻辑(涉及一些比较复杂的数学向量运算)
-- 作为BattleBulletUnit.updateSpeed之一(在BattleBulletUnit.InitSpeed中设定)
-- 被BattleBulletUnit.Update调用
function BattleBulletUnit.doTrack(self)
	if self:getTrackingTarget() == nil then
		-- 如果原本没有追踪目标，尝试寻找一个最近的目标进行追踪(初始化的时候也是寻找目标这个逻辑)
		local nearestTarget = BattleTargetChoise.TargetHarmNearest(self)[1]
		-- 且应该在追踪范围内
		if nearestTarget ~= nil and self:GetDistance(nearestTarget) <= self._trackRange then
			self:setTrackingTarget(nearestTarget)
		end
	end

	local target = self:getTrackingTarget()

	if target == nil or target == -1 then
		return
	elseif not target:IsAlive() then
		self:setTrackingTarget(-1)

		return
	elseif self:GetDistance(target) > self._trackRange then
		self:setTrackingTarget(-1)

		return
	end

	local aimPosition = target:GetBeenAimedPosition()

	if not aimPosition then
		return
	end

	local direction = aimPosition - self:GetPosition()

	direction:SetNormalize()

	local speedDir = Vector3.Normalize(self._speed)
	-- 计算原速度方向和目标方向的夹角余弦值及大小(点乘)
	-- 数学基础知识：两个向量的点乘 = |A|*|B|*cosθ = cosθ (A,B均为单位向量时)
	local cosAngle = Vector3.Dot(speedDir, direction)
	-- 叉乘，得到正弦值(因为speedDir和direction均为单位向量，所以叉乘结果的模长即为sinθ)
	local sinAngle = speedDir.z * direction.x - speedDir.x * direction.z
	-- TRACKER_ANGLE = cos10度，即夹角小于10度才进行追踪调整(否则就按原速度前进)
	if cosAngle >= BattleBulletUnit.TRACKER_ANGLE then
		return
	end
	-- speedRatio是涉及子弹时间时的速度倍率，与逻辑计算本质无关
	local speedRatio = self:GetSpeedRatio()
	local cosAngular = math.cos(self._cosAngularSpeed * speedRatio)
	local sinAngular = math.sin(self._sinAngularSpeed * speedRatio)
	local cosAngularActual = cosAngle
	local sinAngularActual = sinAngle

	-- 如果夹角余弦值小于角加速度的余弦值->说明夹角比角加速度大
	-- 则实际调整角度为角加速度
	if cosAngle < cosAngular then
		cosAngularActual = cosAngular
		sinAngularActual = sinAngular * (sinAngularActual >= 0 and 1 or -1)
	end

	-- 否则，实际调整角度为夹角本身(调整到目标方向)
	-- 这里也是一个叉乘的变形运算
	local speedX = self._speed.x * cosAngularActual + self._speed.z * sinAngularActual
	local speedZ = self._speed.z * cosAngularActual - self._speed.x * sinAngularActual

	self._speed:Set(speedX, 0, speedZ)
end

-- 子弹的环绕主逻辑(从逻辑来看，是子弹绕武器位置环绕. 武器位置一般就是发射者位置)
-- 这个函数是废弃的，没有被任何地方调用到(可能是doCircle的原型)
function BattleBulletUnit.doOrbit(self)
	local weaponPos = pg.Tool.FilterY(self._weapon:GetPosition())
	local bulletPos = pg.Tool.FilterY(self:GetPosition())
	local distance = (bulletPos - weaponPos).magnitude
	local direction = (weaponPos - bulletPos).normalized
	local newSpeed

	if distance > 10 then
		newSpeed = (direction + self._speed.normalized).normalized
	else
		-- 一个简单的垂直于direction和up向量的向量，用来产生环绕效果
		newSpeed = (Vector3(-direction.z, 0, direction.x) + self._speed.normalized).normalized
	end

	self._speed = newSpeed
end

-- 一个工具函数，用于绕Y轴旋转(等价于二维平面XZ上的旋转)
-- 被doCircle调用
function BattleBulletUnit.RotateY(vec1, vec2)
	local cosVec2 = math.cos(vec2)
	local sinVec2 = math.sin(vec2)
	-- 相当于vec1绕Y轴旋转vec2角度后的新向量
	return Vector3(vec1.x * cosVec2 + vec1.z * sinVec2, vec1.y, vec1.z * cosVec2 - vec1.x * sinVec2)
end

-- 子弹的环绕主逻辑
-- 作为BattleBulletUnit.updateSpeed之一(在BattleBulletUnit.InitSpeed中设定)
-- 被BattleBulletUnit.Update调用
function BattleBulletUnit.doCircle(self)
	if not self._originPos then
		return
	end

	local bulletSpeedRatio = self:GetSpeedRatio() * (1 + ys.Battle.BattleAttr.GetCurrent(self, "bulletSpeedRatio"))
	local vec = pg.Tool.FilterY(self._position - self._originPos)
	-- 在BattleBulletUnit.ResetVelocity中计算
	local convertedVelocity = self._convertedVelocity
	local distance = vec:Magnitude()
	-- 用向心加速度计算
	local ifInverse = distance - self._centripetalSpeed * bulletSpeedRatio * self._inverseFlag

	self._inverseFlag = ifInverse < 0 and -self._inverseFlag or self._inverseFlag

	if distance <= 1e-05 then
		return
	end

	-- 顺时针(0)/逆时针(1)
	local circleAntiClockWise = self._circleAntiClockwise
	local rotateAngle = convertedVelocity / distance * (circleAntiClockWise and 1 or -1) * bulletSpeedRatio

	self._speed = self.RotateY(vec, rotateAngle):Mul(ifInverse / distance):Sub(vec)
end

-- 一个空函数，用于替代updateSpeed
-- 实际会做的是处理重力对垂直速度的影响(但不影响水平速度)
function BattleBulletUnit.doNothing(self)
	if self._gravity ~= 0 then
		self._verticalSpeed = self._verticalSpeed + self._gravity * self:GetSpeedRatio()
	end
end

function BattleBulletUnit.Ctor(self, UID, IFF)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._battleProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._uniqueID = UID
	self._speedExemptKey = "bullet_" .. UID
	self._IFF = IFF
	self._collidedList = {}
	self._speed = Vector3.zero
	self._exist = true
	self._timeStamp = 0
	self._dmgEnhanceRate = 1
	self._frame = 0
	self._reachDestFlag = false
	self._verticalSpeed = 0
	self._damageList = {}
end

function BattleBulletUnit.Update(self, timeStamp)
	local bulletSpeedRatio = self:GetSpeedRatio()

	self:updateSpeed(timeStamp)
	self:updateBarrageTransform(timeStamp)
	-- 更新本帧位置
	self._position:Set(self._position.x + self._speed.x * bulletSpeedRatio, self._position.y + self._speed.y * bulletSpeedRatio, self._position.z + self._speed.z * bulletSpeedRatio)
	-- 这算是更新两次Y轴位置吗？可能speed本身就不包含Y轴分量吧
	self._position.y = self._position.y + self._verticalSpeed * bulletSpeedRatio
	-- 如果没有重力，那么判定“到达”是基于超出射程
	if self._gravity == 0 then
		self._reachDestFlag = Vector3.SqrDistance(self._spawnPos, self._position) > self._sqrRange
	else
		-- 如果有重力
		-- 用于改变fieldType: y <= 5时
		if self._fieldSwitchHeight ~= 0 and self._position.y <= self._fieldSwitchHeight then
			self._field = BattleConst.BulletField.SURFACE
		end
		-- y <= 1.2时认为到达(引爆)
		self._reachDestFlag = self._position.y <= BattleConfig.BombDetonateHeight
	end
end

function BattleBulletUnit.ActiveCldBox(self)
	self._cldComponent:SetActive(true)
end

function BattleBulletUnit.DeactiveCldBox(self)
	self._cldComponent:SetActive(false)
end

function BattleBulletUnit.SetStartTimeStamp(self, timeStamp)
	self._timeStamp = timeStamp
end

-- 核心: 处理子弹击中目标的逻辑
-- 被BattleDataProxy.HandleBulletHit调用
--- @param shipUID number 被击中目标的UID
--- @param shipUnitType number 被击中目标的UnitType(如Player/Enemy/Boss等)
function BattleBulletUnit.Hit(self, shipUID, shipUnitType)
	self._collidedList[shipUID] = true

	local hitArgs = {
		UID = shipUID,
		type = shipUnitType
	}
	-- 对应的回调是BattleBullet.onBulletHit
	self:DispatchEvent(ys.Event.New(BattleBulletEvent.HIT, hitArgs))
end

-- 被BattleBuffShieldWall.onWallCld调用
function BattleBulletUnit.Intercepted(self)
	self:DispatchEvent(ys.Event.New(BattleBulletEvent.INTERCEPTED, {}))
end

-- 被BattleBuffShieldWall.onWallCld调用
function BattleBulletUnit.Reflected(self)
	self._speed.x = -self._speed.x
end

-- 被BattleBulletUnit.SetTemplateData调用(用于初始化速度)
-- 此外还被一些子弹(BattleMissileUnit)等，用于重置速度
function BattleBulletUnit.ResetVelocity(self, velocity)
	local tempData = self._tempData
	local extra_param = self:GetTemplate().extra_param

	-- 如果没有给定要
	if not velocity then
		velocity = tempData.velocity

		if extra_param.velocity_offset then
			-- 速度偏移在(-offset, +offset)范围内随机(lua的random要求里面的velocity和offset都是整数)
			velocity = math.random(velocity - extra_param.velocity_offset, velocity + extra_param.velocity_offset)
		elseif extra_param.velocity_offsetF then
			-- offsetF则是在(-offsetF, +offsetF)范围内随机浮点数
			velocity = velocity + math.random() * 2 * extra_param.velocity_offsetF - extra_param.velocity_offsetF
		end
	end

	self._velocity = velocity
	self._convertedVelocity = BattleFormulas.ConvertBulletSpeed(self._velocity)
end

-- 被BattleDataFunction.CreateBattleBulletData(和一些creatBulletFunc)调用
-- 初始化的一部分，设置子弹数据实体的各种数据
function BattleBulletUnit.SetTemplateData(self, tempData)
	self._tempData = setmetatable({}, {
		__index = tempData
	})

	local extra_param = self:GetTemplate().extra_param

	self:SetModleID(tempData.modle_ID, BattleBulletUnit.ORIGNAL_RES)
	self:SetSFXID(self._tempData.hit_sfx, self._tempData.miss_sfx)
	-- 初始化速度
	self:ResetVelocity()

	self._pierceCount = tempData.pierce_count
	-- 初始化射程
	self:FixRange()
	self:InitCldComponent()
	-- 设置加速度表
	self._accTable = Clone(self._tempData.acceleration)
	-- 按照时间排序加速度表
	table.sort(self._accTable, function(phase1, phase2)
		return phase1.t < phase2.t
	end)

	self._field = tempData.effect_type
	self._gravity = extra_param.gravity or 0
	self._fieldSwitchHeight = extra_param.effectSwitchHeight or 0
	self._ignoreShield = self._tempData.extra_param.ignoreShield == true
	self._autoRotate = self._tempData.extra_param.dontRotate ~= true
	-- 初始化DiveFilter
	self:SetDiverFilter()
end

function BattleBulletUnit.GetModleID(self)
	local extra_param = self:GetTemplate().extra_param
	local modelID

	if self._IFF == BattleConfig.FOE_CODE then
		if self._mirrorSkin == BattleBulletUnit.MIRROR_SKIN_RES then
			modelID = self._modleID .. BattleBulletUnit.MIRROR_RES
		elseif self._mirrorSkin == BattleBulletUnit.ORIGNAL_RES and extra_param.mirror == true then
			modelID = self._modleID .. BattleBulletUnit.MIRROR_RES
		else
			modelID = self._modleID
		end
	else
		modelID = self._modleID
	end

	return modelID
end

BattleBulletUnit.ORIGNAL_RES = -1
BattleBulletUnit.SKIN_RES = 0
BattleBulletUnit.MIRROR_SKIN_RES = 1

function BattleBulletUnit.SetModleID(self, modelID, mirrorSkin, hit_fx)
	self._modleID = modelID
	self._mirrorSkin = mirrorSkin

	if hit_fx and hit_fx ~= "" then
		self._tempData.hit_fx = hit_fx
	end
end

function BattleBulletUnit.SetSFXID(self, hitSFX, missSFX)
	if hitSFX then
		self._hitSFX = hitSFX
	end

	if missSFX then
		self._missSFX = missSFX
	end
end

function BattleBulletUnit.SetShiftInfo(self, offsetX, offsetZ)
	local randomLaunchOffsetX = 0
	local randomLaunchOffsetZ = 0
	local extra_param = self:GetTemplate().extra_param

	if extra_param.randomLaunchOffsetX then
		randomLaunchOffsetX = math.random() * extra_param.randomLaunchOffsetX * 2 - extra_param.randomLaunchOffsetX
	end

	if extra_param.randomLaunchOffsetZ then
		randomLaunchOffsetZ = math.random() * extra_param.randomLaunchOffsetZ * 2 - extra_param.randomLaunchOffsetZ
	end

	self._offsetX = offsetX + randomLaunchOffsetX
	self._offsetZ = offsetZ + randomLaunchOffsetZ
end

function BattleBulletUnit.SetRotateInfo(self, targetPos, baseAngle, barrageAngle)
	self._targetPos = targetPos
	self._baseAngle = baseAngle
	self._barrageAngle = barrageAngle

	local angle = self._barrageAngle % 360

	if angle > 0 and angle < 180 then
		for _, accStage in ipairs(self._accTable) do
			if accStage.flip then
				accStage.v = accStage.v * -1
			end
		end
	end
end

function BattleBulletUnit.SetBarrageTransformTempate(self, transBarrage)
	if #transBarrage > 0 then
		self._barrageTransData = transBarrage
	end
end

function BattleBulletUnit.SetAttr(self, attr)
	ys.Battle.BattleAttr.SetAttr(self, attr)
end

function BattleBulletUnit.GetAttr(self)
	return ys.Battle.BattleAttr.GetAttr(self)
end

function BattleBulletUnit.SetStandHostAttr(self, attr)
	self._standUnit = {}

	ys.Battle.BattleAttr.SetAttr(self._standUnit, attr)
end

function BattleBulletUnit.GetWeaponHostAttr(self)
	if self._standUnit then
		return ys.Battle.BattleAttr.GetAttr(self._standUnit)
	else
		return self:GetAttr()
	end
end

function BattleBulletUnit.GetWeaponAtkAttr(self)
	-- GetWeaponHostAttr
	-- 如果有StandHost取StandHost的属性，否则取的是自己的属性
	-- 自己的属性是继承的发射者的属性
	local weaponHostAttr = self:GetWeaponHostAttr()
	local atkAttr
	local atkAttrTransform = self._weapon:GetAtkAttrTrasnform(weaponHostAttr)

	if atkAttrTransform then
		atkAttr = atkAttrTransform
	else
		local attack_attribute = self:GetWeaponTempData().attack_attribute

		atkAttr = ys.Battle.BattleAttr.GetAtkAttrByType(weaponHostAttr, attack_attribute)
	end

	return atkAttr
end

function BattleBulletUnit.GetWeaponCardPuzzleEnhance(self)
	return self._weapon:GetCardPuzzleDamageEnhance()
end

function BattleBulletUnit.SetDamageEnhance(self, dmgEnhanceRate)
	self._dmgEnhanceRate = dmgEnhanceRate
end

function BattleBulletUnit.GetDamageEnhance(self)
	return self._dmgEnhanceRate
end

function BattleBulletUnit.GetAttrByName(self, attrName)
	return ys.Battle.BattleAttr.GetCurrent(self, attrName)
end

function BattleBulletUnit.GetVerticalSpeed(self)
	return self._verticalSpeed
end

function BattleBulletUnit.IsGravitate(self)
	return self._gravity ~= 0
end

function BattleBulletUnit.SetBuffTrigger(self, host)
	self._host = host
	self._buffTriggerFun = {}
end

function BattleBulletUnit.SetBuffFun(self, effectType, func)
	--- @type table<number, function>
	local triggerFunctions = self._buffTriggerFun[effectType] or {}

	triggerFunctions[#triggerFunctions + 1] = func
	self._buffTriggerFun[effectType] = triggerFunctions
end

function BattleBulletUnit.BuffTrigger(self, effectType, args)
	local host = self._host

	if host then
		if table.contains(AircraftUnitType, host:GetUnitType()) then
			self._host:TriggerBuff(effectType, args)
		elseif host:IsAlive() then
			self._host:TriggerBuff(effectType, args)

			--- @type table<number, function>
			local triggerFunctions = self._buffTriggerFun[effectType]

			if triggerFunctions then
				for _, func in ipairs(triggerFunctions) do
					func(self._host, args)
				end
			end
		end
	end
end

function BattleBulletUnit.SetIsCld(self, needCld)
	self._needCld = needCld
end

function BattleBulletUnit.GetIsCld(self)
	return self._needCld
end

function BattleBulletUnit.IsIngoreCld(self)
	return self._tempData.extra_param.ingoreCld
end

function BattleBulletUnit.IsFragile(self)
	return self._tempData.extra_param.fragile
end

function BattleBulletUnit.IsIndiscriminate(self)
	return self._tempData.extra_param.indiscriminate
end

function BattleBulletUnit.GetExtraTag(self)
	return self._tempData.extra_param.tag
end

function BattleBulletUnit.AppendDamageUnit(self, damageUnit)
	self._damageList[#self._damageList + 1] = damageUnit
end

function BattleBulletUnit.DamageUnitListWriteback(self)
	self._weapon:UpdateCombo(self._damageList)
end

function BattleBulletUnit.HasAcceleration(self)
	return #self._accTable ~= 0
end

function BattleBulletUnit.IsTracker(self)
	return self._accTable.tracker
end

function BattleBulletUnit.IsOrbit(self)
	return self._accTable.orbit
end

function BattleBulletUnit.IsCircle(self)
	return self._accTable.circle
end

-- 被BattleBulletUnit.doAccelerate调用
function BattleBulletUnit.GetAcceleration(self, timeStamp)
	self._lastAccTime = self._lastAccTime or self._timeStamp
	-- 计算自上次计算加速度以来经过了多少个加速度计算间隔(帧)
	local accCounts = math.modf((timeStamp - self._lastAccTime) / BattleBulletUnit.ACC_INTERVAL)

	self._lastAccTime = self._lastAccTime + BattleBulletUnit.ACC_INTERVAL * accCounts
	-- 开始加速后，经过的总时间
	local elapsedAccTime = timeStamp - self._timeStamp
	local accPhaseIndex = #self._accTable

	while accPhaseIndex > 0 do
		local accPhase = self._accTable[accPhaseIndex]
		-- 找到对应符合当前时间戳的加速度阶段
		if elapsedAccTime + BattleBulletUnit.ACC_INTERVAL < accPhase.t then
			accPhaseIndex = accPhaseIndex - 1
		else
			-- 返回的对应加速度值是每帧的加速度乘以经过的帧数，分别是u方向和v方向(x轴和z轴方向)
			return accPhase.u * accCounts, accPhase.v * accCounts
		end
	end

	return 0, 0
end

-- 被BattleBulletUnit.doAccelerate调用
-- 该函数在加速度导致速度反向时调用
-- 将所有加速度阶段的u方向(x方向)加速度取反
function BattleBulletUnit.reverseAcceleration(self)
	for _, accPhase in ipairs(self._accTable) do
		accPhase.u = accPhase.u * -1
	end
end

function BattleBulletUnit.GetDistance(self, target)
	local frameIndex = self._battleProxy.FrameIndex

	if self._frame ~= frameIndex then
		self._distanceBackup = {}
		self._frame = frameIndex
	end

	local distance = self._distanceBackup[target]

	if distance == nil then
		distance = Vector3.Distance(self:GetPosition(), target:GetPosition())
		self._distanceBackup[target] = distance

		target:backupDistance(self, distance)
	end

	return distance
end

function BattleBulletUnit.backupDistance(self, target, distance)
	local frameIndex = self._battleProxy.FrameIndex

	if self._frame ~= frameIndex then
		self._distanceBackup = {}
		self._frame = frameIndex
	end

	self._distanceBackup[target] = distance
end

function BattleBulletUnit.getTrackingTarget(self)
	return self._tarckingTarget
end

function BattleBulletUnit.setTrackingTarget(self, target)
	self._tarckingTarget = target
end

function BattleBulletUnit.SetWeapon(self, weapon)
	self._weapon = weapon

	if weapon then
		self._correctedDMG = self._weapon:GetCorrectedDMG()
	end
end

function BattleBulletUnit.GetWeapon(self)
	return self._weapon
end

function BattleBulletUnit.GetCorrectedDMG(self)
	return self._correctedDMG
end

function BattleBulletUnit.OverrideCorrectedDMG(self, overrideDamage)
	self._correctedDMG = BattleFormulas.WeaponDamagePreCorrection(self._weapon, overrideDamage)
end

function BattleBulletUnit.GetWeaponTempData(self)
	return self._weapon:GetTemplateData()
end

function BattleBulletUnit.GetPosition(self)
	return self._position or Vector3.zero
end

-- 设置子弹的出生点
function BattleBulletUnit.SetSpawnPosition(self, spawnPos)
	self._spawnPos = spawnPos
	self._position = spawnPos:Clone()

	if self._gravity ~= 0 then
		local speedDirAngle = math.atan2(self._speed.x, self._speed.z)

		if speedDirAngle == 0 then
			self._verticalSpeed = 0
		else
			-- 60是什么意思？
			local dir = Vector3(math.cos(speedDirAngle) * 60, math.sin(speedDirAngle) * 60)
			local time = 60 / self._convertedVelocity

			self._verticalSpeed = -0.5 * self._gravity * time
		end
	end
end

function BattleBulletUnit.GetSpawnPosition(self)
	return self._spawnPos
end

function BattleBulletUnit.GetTemplate(self)
	return self._tempData
end

function BattleBulletUnit.GetType(self)
	return self._tempData.type
end

function BattleBulletUnit.GetHitSFX(self)
	return self._hitSFX
end

function BattleBulletUnit.GetMissSFX(self)
	return self._missSFX
end

function BattleBulletUnit.GetOutBound(self)
	return self._tempData.out_bound
end

function BattleBulletUnit.GetUniqueID(self)
	return self._uniqueID
end

function BattleBulletUnit.GetOffset(self)
	return self._offsetX, self._offsetZ, self._isOffsetPriority
end

function BattleBulletUnit.GetRotateInfo(self)
	return self._targetPos, self._baseAngle, self._barrageAngle
end

function BattleBulletUnit.IsOutRange(self)
	return self._reachDestFlag
end

function BattleBulletUnit.SetYAngle(self, yAngle)
	self._yAngle = yAngle
end

function BattleBulletUnit.SetOffsetPriority(self, isOffsetPriority)
	self._isOffsetPriority = isOffsetPriority or false
end

function BattleBulletUnit.GetOffsetPriority(self)
	return self._isOffsetPriority
end

function BattleBulletUnit.GetYAngle(self)
	return self._yAngle
end

function BattleBulletUnit.GetCurrentYAngle(self)
	local speedDir = Vector3.Normalize(self._speed)
	local speedDirAngle = math.acos(speedDir.x) / math.deg2Rad

	if speedDir.z < 0 then
		speedDirAngle = 360 - speedDirAngle
	end

	return speedDirAngle
end

function BattleBulletUnit.GetIFF(self)
	return self._IFF
end

function BattleBulletUnit.GetHost(self)
	return self._host
end

function BattleBulletUnit.GetPierceCount(self)
	return self._pierceCount
end

function BattleBulletUnit.AppendAttachBuff(self, buffConfig)
	self._attachBuffList = self._attachBuffList or self:generateAttachBuffList()

	table.insert(self._attachBuffList, buffConfig)
end

function BattleBulletUnit.GetAttachBuff(self)
	self._attachBuffList = self._attachBuffList or self:generateAttachBuffList()

	return self._attachBuffList
end

function BattleBulletUnit.generateAttachBuffList(self)
	local attachBuffList = {}

	if not self:GetTemplate().attach_buff then
		local buffEntries = {}
	end

	for _, attachBuff in ipairs(self:GetTemplate().attach_buff) do
		local buffConfig = {
			buff_id = attachBuff.buff_id,
			level = attachBuff.buff_level,
			rant = attachBuff.rant,
			hit_ignore = attachBuff.hit_ignore,
			group_level = attachBuff.group_level
		}

		table.insert(attachBuffList, buffConfig)
	end

	return attachBuffList
end

function BattleBulletUnit.GetEffectField(self)
	return self._field
end

function BattleBulletUnit.SetDiverFilter(self, diveFilter)
	if diveFilter == nil then
		self._diveFilter = self._tempData.extra_param.diveFilter or {
			2
		}
	else
		self._diveFilter = diveFilter
	end
end

function BattleBulletUnit.GetDiveFilter(self)
	return self._diveFilter
end

function BattleBulletUnit.GetVelocity(self)
	return self._velocity
end

function BattleBulletUnit.GetConvertedVelocity(self)
	return self._convertedVelocity
end

function BattleBulletUnit.GetSpeedExemptKey(self)
	return self._speedExemptKey
end

function BattleBulletUnit.IsCollided(self, target)
	return self._collidedList[target]
end

function BattleBulletUnit.GetExist(self)
	return self._exist
end

function BattleBulletUnit.SetExist(self, exist)
	self._exist = exist
end

function BattleBulletUnit.GetIgnoreShield(self)
	return self._ignoreShield
end

function BattleBulletUnit.SetIgnoreShield(self, ignoreShield)
	self._ignoreShield = ignoreShield
end

function BattleBulletUnit.IsAutoRotate(self)
	return self._autoRotate
end

function BattleBulletUnit.Dispose(self)
	self._dataProxy = nil

	ys.EventDispatcher.DetachEventDispatcher(self)
end

-- note: 子弹碰撞体初始化
function BattleBulletUnit.InitCldComponent(self)
	local cld_box = self:GetTemplate().cld_box
	local cld_offset = self:GetTemplate().cld_offset
	local offsetX = cld_offset[1]

	if self:GetIFF() == BattleConfig.FOE_CODE then
		offsetX = offsetX * -1
	end
	-- 子弹在碰撞系统中，本质是一个立方体
	self._cldComponent = ys.Battle.BattleCubeCldComponent.New(cld_box[1], cld_box[2], cld_box[3], offsetX, cld_offset[3])
	-- 关于CldType: 在BattleCldSystem的各个HandleCldWithXXX函数中会根据type来区分不同的碰撞体进行不同的处理
	local cldData = {
		type = BattleConst.CldType.BULLET,
		IFF = self:GetIFF(),
		UID = self:GetUniqueID()
	}

	self._cldComponent:SetCldData(cldData)
end

function BattleBulletUnit.ResetCldSurface(self)
	local diveFilter = self:GetDiveFilter()

	if diveFilter and #diveFilter == 0 then
		self:GetCldData().Surface = BattleConst.OXY_STATE.DIVE
	else
		self:GetCldData().Surface = BattleConst.OXY_STATE.FLOAT
	end
end

function BattleBulletUnit.GetBoxSize(self)
	return self._cldComponent:GetCldBoxSize()
end

function BattleBulletUnit.GetCldBox(self)
	return self._cldComponent:GetCldBox(self:GetPosition())
end

function BattleBulletUnit.GetCldData(self)
	return self._cldComponent:GetCldData()
end

function BattleBulletUnit.GetSpeed(self)
	return self._speed
end

function BattleBulletUnit.GetSpeedRatio(self)
	return BattleVariable.GetSpeedRatio(self._speedExemptKey, self._IFF)
end

-- 速度参数初始化
-- 根据加速度参数，设置updateSpeed函数
-- 被BattleBullet.SetSpawn调用
function BattleBulletUnit.InitSpeed(self, angle)
	if self._yAngle == nil then
		self._yAngle = (angle or self._baseAngle) + self._barrageAngle
	end
	-- 此处计算速度向量到self._speed
	self:calcSpeed()

	-- 情况1: 有加速度(数组形式)
	if self:HasAcceleration() then
		self._speedLength = self._speed:Magnitude()

		local yAngle = math.deg2Rad * self._yAngle

		self._speedNormal = Vector3(math.cos(yAngle), 0, math.sin(yAngle))
		-- 将速度方向与Y轴正方向做叉乘，得到垂直于速度方向的向量
		-- speedNormal和speedCross都与Y轴正方向垂直(也即都在XZ平面上，且互相垂直)
		self._speedCross = Vector3.Cross(self._speedNormal, vector3Up)
		self.updateSpeed = BattleBulletUnit.doAccelerate
	-- 情况2: 追踪型子弹
	elseif self:IsTracker() then
		local tracker = self._accTable.tracker
		-- 追踪范围(半径)
		self._trackRange = tracker.range
		-- angular是角加速度
		-- 实际上这两个值是一样的(只是分别用在cos和sin计算上)，只是为了代码可读性才分开写的
		self._cosAngularSpeed = math.deg2Rad * tracker.angular
		self._sinAngularSpeed = math.deg2Rad * tracker.angular
		-- 这两个实际没用到
		self._negativeCosAngularSpeed = math.deg2Rad * tracker.angular * -1
		self._negativeSinAngularSpeed = math.deg2Rad * tracker.angular * -1
		self.updateSpeed = BattleBulletUnit.doTrack
	-- 情况3: 环绕型子弹(少见)
	elseif self:IsCircle() then
		local circle = self._accTable.circle

		self._originPos = circle.center or self._targetPos
		self._circleAntiClockwise = tobool(circle.antiClockWise)
		-- 每帧的向心加速度
		self._centripetalSpeed = (circle.centripetalSpeed or 0) * viewInterval
		self._inverseFlag = 1
		self.updateSpeed = BattleBulletUnit.doCircle
	else
		-- 如都没有，则不更新速度(最常见的情况)
		self.updateSpeed = BattleBulletUnit.doNothing
	end
end

function BattleBulletUnit.InheritSpeed(self, speed)
	self._speed = Vector3(speed.x, speed.y, speed.z)
	self._speedInited = true
end

-- 计算速度的大小和方向，得到速度向量
-- 被BattleBulletUnit.InitSpeed调用
function BattleBulletUnit.calcSpeed(self)
	if self._speedInited then
		return
	end

	local bulletSpeedRatio = 1 + ys.Battle.BattleAttr.GetCurrent(self, "bulletSpeedRatio")
	local bulletSpeed = self._velocity * bulletSpeedRatio
	local bulletVelocity = BattleFormulas.ConvertBulletSpeed(bulletSpeed)
	local yAngle = math.deg2Rad * self._yAngle

	self._speed = Vector3(bulletVelocity * math.cos(yAngle), 0, bulletVelocity * math.sin(yAngle))
end

function BattleBulletUnit.updateBarrageTransform(self, timeStamp)
	if not self._barrageTransData or #self._barrageTransData == 0 then
		return
	end

	local elapsedTime = timeStamp - self._timeStamp
	local transData1 = self._barrageTransData[1]

	if elapsedTime >= transData1.transStartDelay then
		if transData1.transAimAngle then
			self._yAngle = transData1.transAimAngle
		else
			self._yAngle = math.rad2Deg * math.atan2(transData1.transAimPosZ - self._position.z, transData1.transAimPosX - self._position.x)
		end

		self:calcSpeed()
		table.remove(self._barrageTransData, 1)

		local transData1 = self._barrageTransData[1]

		if transData1 then
			transData1.transStartDelay = transData1.transStartDelay + transData1.transStartDelay
		end
	end
end

function BattleBulletUnit.GetCurrentDistance(self)
	return Vector3.Distance(self._spawnPos, self._position)
end

function BattleBulletUnit.SetOutRangeCallback(self, outRangeFunc)
	self._outRangeFunc = outRangeFunc
end

function BattleBulletUnit.OutRange(self)
	self:DispatchEvent(ys.Event.New(BattleBulletEvent.OUT_RANGE, {}))
	self._outRangeFunc(self)
end

-- 被BattleBulletUnit.SetTemplateData和BattleDataProxy.CreateBulletUnit调用
function BattleBulletUnit.FixRange(self, range, fixRange)
	range = range or self._tempData.range
	fixRange = fixRange or 0

	local range_offset = self._tempData.range_offset

	if range_offset == 0 then
		self._range = range
	else
		-- 最终的射程 = [range - 0.5 * range_offset, range + 0.5 * range_offset] 之间的随机值
		self._range = range + range_offset * (math.random() - 0.5)
	end
	-- 随机完，再加上固定的修正值，作为最终判定的射程
	self._range = math.max(0, self._range + fixRange)
	self._sqrRange = self._range * self._range
end

function BattleBulletUnit.ImmuneBombCLS(self)
	return self:GetTemplate().extra_param.ignoreB
end

function BattleBulletUnit.ImmuneCLS(self)
	return self._immuneCLS
end

function BattleBulletUnit.SetImmuneCLS(self, immuneCLS)
	self._immuneCLS = immuneCLS
end

function BattleBulletUnit.IsSpectreBullet(self)
	return self:GetTemplate().extra_param.spectre
end
