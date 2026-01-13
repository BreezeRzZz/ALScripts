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

function BattleBulletUnit.ActiveCldBox(arg_9_0)
	arg_9_0._cldComponent:SetActive(true)
end

function BattleBulletUnit.DeactiveCldBox(arg_10_0)
	arg_10_0._cldComponent:SetActive(false)
end

function BattleBulletUnit.SetStartTimeStamp(arg_11_0, arg_11_1)
	arg_11_0._timeStamp = arg_11_1
end

-- 被BattleDataProxy.HandleBulletHit调用
function BattleBulletUnit.Hit(self, shipUID, shipUnitType)
	self._collidedList[shipUID] = true

	local hitArgs = {
		UID = shipUID,
		type = shipUnitType
	}
	-- 对应的回调是BattleBullet.onBulletHit
	self:DispatchEvent(ys.Event.New(BattleBulletEvent.HIT, hitArgs))
end

function BattleBulletUnit.Intercepted(arg_13_0)
	arg_13_0:DispatchEvent(ys.Event.New(BattleBulletEvent.INTERCEPTED, {}))
end

function BattleBulletUnit.Reflected(arg_14_0)
	arg_14_0._speed.x = -arg_14_0._speed.x
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

function BattleBulletUnit.GetModleID(arg_18_0)
	local var_18_0 = arg_18_0:GetTemplate().extra_param
	local var_18_1

	if arg_18_0._IFF == BattleConfig.FOE_CODE then
		if arg_18_0._mirrorSkin == BattleBulletUnit.MIRROR_SKIN_RES then
			var_18_1 = arg_18_0._modleID .. BattleBulletUnit.MIRROR_RES
		elseif arg_18_0._mirrorSkin == BattleBulletUnit.ORIGNAL_RES and var_18_0.mirror == true then
			var_18_1 = arg_18_0._modleID .. BattleBulletUnit.MIRROR_RES
		else
			var_18_1 = arg_18_0._modleID
		end
	else
		var_18_1 = arg_18_0._modleID
	end

	return var_18_1
end

BattleBulletUnit.ORIGNAL_RES = -1
BattleBulletUnit.SKIN_RES = 0
BattleBulletUnit.MIRROR_SKIN_RES = 1

function BattleBulletUnit.SetModleID(arg_19_0, arg_19_1, arg_19_2, arg_19_3)
	arg_19_0._modleID = arg_19_1
	arg_19_0._mirrorSkin = arg_19_2

	if arg_19_3 and arg_19_3 ~= "" then
		arg_19_0._tempData.hit_fx = arg_19_3
	end
end

function BattleBulletUnit.SetSFXID(arg_20_0, arg_20_1, arg_20_2)
	if arg_20_1 then
		arg_20_0._hitSFX = arg_20_1
	end

	if arg_20_2 then
		arg_20_0._missSFX = arg_20_2
	end
end

function BattleBulletUnit.SetShiftInfo(arg_21_0, arg_21_1, arg_21_2)
	local var_21_0 = 0
	local var_21_1 = 0
	local var_21_2 = arg_21_0:GetTemplate().extra_param

	if var_21_2.randomLaunchOffsetX then
		var_21_0 = math.random() * var_21_2.randomLaunchOffsetX * 2 - var_21_2.randomLaunchOffsetX
	end

	if var_21_2.randomLaunchOffsetZ then
		var_21_1 = math.random() * var_21_2.randomLaunchOffsetZ * 2 - var_21_2.randomLaunchOffsetZ
	end

	arg_21_0._offsetX = arg_21_1 + var_21_0
	arg_21_0._offsetZ = arg_21_2 + var_21_1
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

function BattleBulletUnit.SetBarrageTransformTempate(arg_23_0, arg_23_1)
	if #arg_23_1 > 0 then
		arg_23_0._barrageTransData = arg_23_1
	end
end

function BattleBulletUnit.SetAttr(arg_24_0, arg_24_1)
	ys.Battle.BattleAttr.SetAttr(arg_24_0, arg_24_1)
end

function BattleBulletUnit.GetAttr(self)
	return ys.Battle.BattleAttr.GetAttr(self)
end

function BattleBulletUnit.SetStandHostAttr(arg_26_0, arg_26_1)
	arg_26_0._standUnit = {}

	ys.Battle.BattleAttr.SetAttr(arg_26_0._standUnit, arg_26_1)
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

function BattleBulletUnit.GetWeaponCardPuzzleEnhance(arg_29_0)
	return arg_29_0._weapon:GetCardPuzzleDamageEnhance()
end

function BattleBulletUnit.SetDamageEnhance(arg_30_0, arg_30_1)
	arg_30_0._dmgEnhanceRate = arg_30_1
end

function BattleBulletUnit.GetDamageEnhance(arg_31_0)
	return arg_31_0._dmgEnhanceRate
end

function BattleBulletUnit.GetAttrByName(arg_32_0, arg_32_1)
	return ys.Battle.BattleAttr.GetCurrent(arg_32_0, arg_32_1)
end

function BattleBulletUnit.GetVerticalSpeed(arg_33_0)
	return arg_33_0._verticalSpeed
end

function BattleBulletUnit.IsGravitate(arg_34_0)
	return arg_34_0._gravity ~= 0
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

function BattleBulletUnit.SetIsCld(arg_38_0, arg_38_1)
	arg_38_0._needCld = arg_38_1
end

function BattleBulletUnit.GetIsCld(arg_39_0)
	return arg_39_0._needCld
end

function BattleBulletUnit.IsIngoreCld(arg_40_0)
	return arg_40_0._tempData.extra_param.ingoreCld
end

function BattleBulletUnit.IsFragile(arg_41_0)
	return arg_41_0._tempData.extra_param.fragile
end

function BattleBulletUnit.IsIndiscriminate(arg_42_0)
	return arg_42_0._tempData.extra_param.indiscriminate
end

function BattleBulletUnit.GetExtraTag(arg_43_0)
	return arg_43_0._tempData.extra_param.tag
end
-- TODO
function BattleBulletUnit.AppendDamageUnit(arg_44_0, arg_44_1)
	arg_44_0._damageList[#arg_44_0._damageList + 1] = arg_44_1
end

function BattleBulletUnit.DamageUnitListWriteback(arg_45_0)
	arg_45_0._weapon:UpdateCombo(arg_45_0._damageList)
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

function BattleBulletUnit.GetDistance(arg_52_0, arg_52_1)
	local var_52_0 = arg_52_0._battleProxy.FrameIndex

	if arg_52_0._frame ~= var_52_0 then
		arg_52_0._distanceBackup = {}
		arg_52_0._frame = var_52_0
	end

	local var_52_1 = arg_52_0._distanceBackup[arg_52_1]

	if var_52_1 == nil then
		var_52_1 = Vector3.Distance(arg_52_0:GetPosition(), arg_52_1:GetPosition())
		arg_52_0._distanceBackup[arg_52_1] = var_52_1

		arg_52_1:backupDistance(arg_52_0, var_52_1)
	end

	return var_52_1
end

function BattleBulletUnit.backupDistance(arg_53_0, arg_53_1, arg_53_2)
	local var_53_0 = arg_53_0._battleProxy.FrameIndex

	if arg_53_0._frame ~= var_53_0 then
		arg_53_0._distanceBackup = {}
		arg_53_0._frame = var_53_0
	end

	arg_53_0._distanceBackup[arg_53_1] = arg_53_2
end

function BattleBulletUnit.getTrackingTarget(self)
	return self._tarckingTarget
end

function BattleBulletUnit.setTrackingTarget(self, target)
	self._tarckingTarget = target
end

function BattleBulletUnit.SetWeapon(arg_56_0, arg_56_1)
	arg_56_0._weapon = arg_56_1

	if arg_56_1 then
		arg_56_0._correctedDMG = arg_56_0._weapon:GetCorrectedDMG()
	end
end

function BattleBulletUnit.GetWeapon(arg_57_0)
	return arg_57_0._weapon
end

function BattleBulletUnit.GetCorrectedDMG(arg_58_0)
	return arg_58_0._correctedDMG
end

function BattleBulletUnit.OverrideCorrectedDMG(arg_59_0, arg_59_1)
	arg_59_0._correctedDMG = BattleFormulas.WeaponDamagePreCorrection(arg_59_0._weapon, arg_59_1)
end

function BattleBulletUnit.GetWeaponTempData(arg_60_0)
	return arg_60_0._weapon:GetTemplateData()
end

function BattleBulletUnit.GetPosition(arg_61_0)
	return arg_61_0._position or Vector3.zero
end
-- TODO
function BattleBulletUnit.SetSpawnPosition(arg_62_0, arg_62_1)
	arg_62_0._spawnPos = arg_62_1
	arg_62_0._position = arg_62_1:Clone()

	if arg_62_0._gravity ~= 0 then
		local var_62_0 = math.atan2(arg_62_0._speed.x, arg_62_0._speed.z)

		if var_62_0 == 0 then
			arg_62_0._verticalSpeed = 0
		else
			local var_62_1 = Vector3(math.cos(var_62_0) * 60, math.sin(var_62_0) * 60)
			local var_62_2 = 60 / arg_62_0._convertedVelocity

			arg_62_0._verticalSpeed = -0.5 * arg_62_0._gravity * var_62_2
		end
	end
end

function BattleBulletUnit.GetSpawnPosition(arg_63_0)
	return arg_63_0._spawnPos
end

function BattleBulletUnit.GetTemplate(arg_64_0)
	return arg_64_0._tempData
end

function BattleBulletUnit.GetType(arg_65_0)
	return arg_65_0._tempData.type
end

function BattleBulletUnit.GetHitSFX(arg_66_0)
	return arg_66_0._hitSFX
end

function BattleBulletUnit.GetMissSFX(arg_67_0)
	return arg_67_0._missSFX
end

function BattleBulletUnit.GetOutBound(arg_68_0)
	return arg_68_0._tempData.out_bound
end

function BattleBulletUnit.GetUniqueID(arg_69_0)
	return arg_69_0._uniqueID
end

function BattleBulletUnit.GetOffset(arg_70_0)
	return arg_70_0._offsetX, arg_70_0._offsetZ, arg_70_0._isOffsetPriority
end

function BattleBulletUnit.GetRotateInfo(arg_71_0)
	return arg_71_0._targetPos, arg_71_0._baseAngle, arg_71_0._barrageAngle
end

function BattleBulletUnit.IsOutRange(arg_72_0)
	return arg_72_0._reachDestFlag
end

function BattleBulletUnit.SetYAngle(arg_73_0, arg_73_1)
	arg_73_0._yAngle = arg_73_1
end

function BattleBulletUnit.SetOffsetPriority(arg_74_0, arg_74_1)
	arg_74_0._isOffsetPriority = arg_74_1 or false
end

function BattleBulletUnit.GetOffsetPriority(arg_75_0)
	return arg_75_0._isOffsetPriority
end

function BattleBulletUnit.GetYAngle(arg_76_0)
	return arg_76_0._yAngle
end

function BattleBulletUnit.GetCurrentYAngle(arg_77_0)
	local var_77_0 = Vector3.Normalize(arg_77_0._speed)
	local var_77_1 = math.acos(var_77_0.x) / math.deg2Rad

	if var_77_0.z < 0 then
		var_77_1 = 360 - var_77_1
	end

	return var_77_1
end

function BattleBulletUnit.GetIFF(arg_78_0)
	return arg_78_0._IFF
end

function BattleBulletUnit.GetHost(arg_79_0)
	return arg_79_0._host
end

function BattleBulletUnit.GetPierceCount(arg_80_0)
	return arg_80_0._pierceCount
end
-- TODO
function BattleBulletUnit.AppendAttachBuff(arg_81_0, arg_81_1)
	arg_81_0._attachBuffList = arg_81_0._attachBuffList or arg_81_0:generateAttachBuffList()

	table.insert(arg_81_0._attachBuffList, arg_81_1)
end

function BattleBulletUnit.GetAttachBuff(arg_82_0)
	arg_82_0._attachBuffList = arg_82_0._attachBuffList or arg_82_0:generateAttachBuffList()

	return arg_82_0._attachBuffList
end
-- TODO
function BattleBulletUnit.generateAttachBuffList(arg_83_0)
	local var_83_0 = {}

	if not arg_83_0:GetTemplate().attach_buff then
		local var_83_1 = {}
	end

	for iter_83_0, iter_83_1 in ipairs(arg_83_0:GetTemplate().attach_buff) do
		local var_83_2 = {
			buff_id = iter_83_1.buff_id,
			level = iter_83_1.buff_level,
			rant = iter_83_1.rant,
			hit_ignore = iter_83_1.hit_ignore,
			group_level = iter_83_1.group_level
		}

		table.insert(var_83_0, var_83_2)
	end

	return var_83_0
end

function BattleBulletUnit.GetEffectField(arg_84_0)
	return arg_84_0._field
end

function BattleBulletUnit.SetDiverFilter(arg_85_0, arg_85_1)
	if arg_85_1 == nil then
		arg_85_0._diveFilter = arg_85_0._tempData.extra_param.diveFilter or {
			2
		}
	else
		arg_85_0._diveFilter = arg_85_1
	end
end

function BattleBulletUnit.GetDiveFilter(arg_86_0)
	return arg_86_0._diveFilter
end

function BattleBulletUnit.GetVelocity(arg_87_0)
	return arg_87_0._velocity
end

function BattleBulletUnit.GetConvertedVelocity(arg_88_0)
	return arg_88_0._convertedVelocity
end

function BattleBulletUnit.GetSpeedExemptKey(arg_89_0)
	return arg_89_0._speedExemptKey
end

function BattleBulletUnit.IsCollided(arg_90_0, arg_90_1)
	return arg_90_0._collidedList[arg_90_1]
end

function BattleBulletUnit.GetExist(arg_91_0)
	return arg_91_0._exist
end

function BattleBulletUnit.SetExist(arg_92_0, arg_92_1)
	arg_92_0._exist = arg_92_1
end

function BattleBulletUnit.GetIgnoreShield(arg_93_0)
	return arg_93_0._ignoreShield
end

function BattleBulletUnit.SetIgnoreShield(arg_94_0, arg_94_1)
	arg_94_0._ignoreShield = arg_94_1
end

function BattleBulletUnit.IsAutoRotate(arg_95_0)
	return arg_95_0._autoRotate
end

function BattleBulletUnit.Dispose(arg_96_0)
	arg_96_0._dataProxy = nil

	ys.EventDispatcher.DetachEventDispatcher(arg_96_0)
end
-- TODO
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

function BattleBulletUnit.ResetCldSurface(arg_98_0)
	local var_98_0 = arg_98_0:GetDiveFilter()

	if var_98_0 and #var_98_0 == 0 then
		arg_98_0:GetCldData().Surface = BattleConst.OXY_STATE.DIVE
	else
		arg_98_0:GetCldData().Surface = BattleConst.OXY_STATE.FLOAT
	end
end

function BattleBulletUnit.GetBoxSize(arg_99_0)
	return arg_99_0._cldComponent:GetCldBoxSize()
end

function BattleBulletUnit.GetCldBox(self)
	return self._cldComponent:GetCldBox(self:GetPosition())
end

function BattleBulletUnit.GetCldData(arg_101_0)
	return arg_101_0._cldComponent:GetCldData()
end

function BattleBulletUnit.GetSpeed(arg_102_0)
	return arg_102_0._speed
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

function BattleBulletUnit.InheritSpeed(arg_105_0, arg_105_1)
	arg_105_0._speed = Vector3(arg_105_1.x, arg_105_1.y, arg_105_1.z)
	arg_105_0._speedInited = true
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

function BattleBulletUnit.updateBarrageTransform(arg_107_0, arg_107_1)
	if not arg_107_0._barrageTransData or #arg_107_0._barrageTransData == 0 then
		return
	end

	local var_107_0 = arg_107_1 - arg_107_0._timeStamp
	local var_107_1 = arg_107_0._barrageTransData[1]

	if var_107_0 >= var_107_1.transStartDelay then
		if var_107_1.transAimAngle then
			arg_107_0._yAngle = var_107_1.transAimAngle
		else
			arg_107_0._yAngle = math.rad2Deg * math.atan2(var_107_1.transAimPosZ - arg_107_0._position.z, var_107_1.transAimPosX - arg_107_0._position.x)
		end

		arg_107_0:calcSpeed()
		table.remove(arg_107_0._barrageTransData, 1)

		local var_107_2 = arg_107_0._barrageTransData[1]

		if var_107_2 then
			var_107_2.transStartDelay = var_107_2.transStartDelay + var_107_1.transStartDelay
		end
	end
end

function BattleBulletUnit.GetCurrentDistance(arg_108_0)
	return Vector3.Distance(arg_108_0._spawnPos, arg_108_0._position)
end

function BattleBulletUnit.SetOutRangeCallback(arg_109_0, arg_109_1)
	arg_109_0._outRangeFunc = arg_109_1
end

function BattleBulletUnit.OutRange(arg_110_0)
	arg_110_0:DispatchEvent(ys.Event.New(BattleBulletEvent.OUT_RANGE, {}))
	arg_110_0._outRangeFunc(arg_110_0)
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

function BattleBulletUnit.ImmuneBombCLS(arg_112_0)
	return arg_112_0:GetTemplate().extra_param.ignoreB
end

function BattleBulletUnit.ImmuneCLS(arg_113_0)
	return arg_113_0._immuneCLS
end

function BattleBulletUnit.SetImmuneCLS(arg_114_0, arg_114_1)
	arg_114_0._immuneCLS = arg_114_1
end
