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

BattleBulletUnit.ACC_INTERVAL = BattleConfig.calcInterval
BattleBulletUnit.TRACKER_ANGLE = math.cos(math.deg2Rad * 10)
BattleBulletUnit.MIRROR_RES = "_mirror"

function BattleBulletUnit.doAccelerate(arg_1_0, arg_1_1)
	local var_1_0, var_1_1 = arg_1_0:GetAcceleration(arg_1_1)

	if var_1_0 == 0 and var_1_1 == 0 then
		return
	end

	if var_1_0 < 0 and arg_1_0._speedLength + var_1_0 < 0 then
		arg_1_0:reverseAcceleration()
	end

	arg_1_0._speed:Set(arg_1_0._speed.x + arg_1_0._speedNormal.x * var_1_0 + arg_1_0._speedCross.x * var_1_1, arg_1_0._speed.y + arg_1_0._speedNormal.y * var_1_0 + arg_1_0._speedCross.y * var_1_1, arg_1_0._speed.z + arg_1_0._speedNormal.z * var_1_0 + arg_1_0._speedCross.z * var_1_1)

	arg_1_0._speedLength = arg_1_0._speed:Magnitude()

	if arg_1_0._speedLength ~= 0 then
		arg_1_0._speedNormal:Copy(arg_1_0._speed):Div(arg_1_0._speedLength)
	end

	arg_1_0._speedCross:Copy(arg_1_0._speedNormal):Cross2(vector3Up)
end

function BattleBulletUnit.doTrack(arg_2_0)
	if arg_2_0:getTrackingTarget() == nil then
		local var_2_0 = BattleTargetChoise.TargetHarmNearest(arg_2_0)[1]

		if var_2_0 ~= nil and arg_2_0:GetDistance(var_2_0) <= arg_2_0._trackRange then
			arg_2_0:setTrackingTarget(var_2_0)
		end
	end

	local var_2_1 = arg_2_0:getTrackingTarget()

	if var_2_1 == nil or var_2_1 == -1 then
		return
	elseif not var_2_1:IsAlive() then
		arg_2_0:setTrackingTarget(-1)

		return
	elseif arg_2_0:GetDistance(var_2_1) > arg_2_0._trackRange then
		arg_2_0:setTrackingTarget(-1)

		return
	end

	local var_2_2 = var_2_1:GetBeenAimedPosition()

	if not var_2_2 then
		return
	end

	local var_2_3 = var_2_2 - arg_2_0:GetPosition()

	var_2_3:SetNormalize()

	local var_2_4 = Vector3.Normalize(arg_2_0._speed)
	local var_2_5 = Vector3.Dot(var_2_4, var_2_3)
	local var_2_6 = var_2_4.z * var_2_3.x - var_2_4.x * var_2_3.z

	if var_2_5 >= BattleBulletUnit.TRACKER_ANGLE then
		return
	end

	local var_2_7 = arg_2_0:GetSpeedRatio()
	local var_2_8 = math.cos(arg_2_0._cosAngularSpeed * var_2_7)
	local var_2_9 = math.sin(arg_2_0._sinAngularSpeed * var_2_7)
	local var_2_10 = var_2_5
	local var_2_11 = var_2_6

	if var_2_5 < var_2_8 then
		var_2_10 = var_2_8
		var_2_11 = var_2_9 * (var_2_11 >= 0 and 1 or -1)
	end

	local var_2_12 = arg_2_0._speed.x * var_2_10 + arg_2_0._speed.z * var_2_11
	local var_2_13 = arg_2_0._speed.z * var_2_10 - arg_2_0._speed.x * var_2_11

	arg_2_0._speed:Set(var_2_12, 0, var_2_13)
end

function BattleBulletUnit.doOrbit(arg_3_0)
	local var_3_0 = pg.Tool.FilterY(arg_3_0._weapon:GetPosition())
	local var_3_1 = pg.Tool.FilterY(arg_3_0:GetPosition())
	local var_3_2 = (var_3_1 - var_3_0).magnitude
	local var_3_3 = (var_3_0 - var_3_1).normalized
	local var_3_4

	if var_3_2 > 10 then
		var_3_4 = (var_3_3 + arg_3_0._speed.normalized).normalized
	else
		var_3_4 = (Vector3(-var_3_3.z, 0, var_3_3.x) + arg_3_0._speed.normalized).normalized
	end

	arg_3_0._speed = var_3_4
end

function BattleBulletUnit.RotateY(arg_4_0, arg_4_1)
	local var_4_0 = math.cos(arg_4_1)
	local var_4_1 = math.sin(arg_4_1)

	return Vector3(arg_4_0.x * var_4_0 + arg_4_0.z * var_4_1, arg_4_0.y, arg_4_0.z * var_4_0 - arg_4_0.x * var_4_1)
end

function BattleBulletUnit.doCircle(arg_5_0)
	if not arg_5_0._originPos then
		return
	end

	local var_5_0 = arg_5_0:GetSpeedRatio() * (1 + ys.Battle.BattleAttr.GetCurrent(arg_5_0, "bulletSpeedRatio"))
	local var_5_1 = pg.Tool.FilterY(arg_5_0._position - arg_5_0._originPos)
	local var_5_2 = arg_5_0._convertedVelocity
	local var_5_3 = var_5_1:Magnitude()
	local var_5_4 = var_5_3 - arg_5_0._centripetalSpeed * var_5_0 * arg_5_0._inverseFlag

	arg_5_0._inverseFlag = var_5_4 < 0 and -arg_5_0._inverseFlag or arg_5_0._inverseFlag

	if var_5_3 <= 1e-05 then
		return
	end

	local var_5_5 = arg_5_0._circleAntiClockwise
	local var_5_6 = var_5_2 / var_5_3 * (var_5_5 and 1 or -1) * var_5_0

	arg_5_0._speed = arg_5_0.RotateY(var_5_1, var_5_6):Mul(var_5_4 / var_5_3):Sub(var_5_1)
end

function BattleBulletUnit.doNothing(arg_6_0)
	if arg_6_0._gravity ~= 0 then
		arg_6_0._verticalSpeed = arg_6_0._verticalSpeed + arg_6_0._gravity * arg_6_0:GetSpeedRatio()
	end
end

function BattleBulletUnit.Ctor(arg_7_0, arg_7_1, arg_7_2)
	ys.EventDispatcher.AttachEventDispatcher(arg_7_0)

	arg_7_0._battleProxy = ys.Battle.BattleDataProxy.GetInstance()
	arg_7_0._uniqueID = arg_7_1
	arg_7_0._speedExemptKey = "bullet_" .. arg_7_1
	arg_7_0._IFF = arg_7_2
	arg_7_0._collidedList = {}
	arg_7_0._speed = Vector3.zero
	arg_7_0._exist = true
	arg_7_0._timeStamp = 0
	arg_7_0._dmgEnhanceRate = 1
	arg_7_0._frame = 0
	arg_7_0._reachDestFlag = false
	arg_7_0._verticalSpeed = 0
	arg_7_0._damageList = {}
end

function BattleBulletUnit.Update(arg_8_0, arg_8_1)
	local var_8_0 = arg_8_0:GetSpeedRatio()

	arg_8_0:updateSpeed(arg_8_1)
	arg_8_0:updateBarrageTransform(arg_8_1)
	arg_8_0._position:Set(arg_8_0._position.x + arg_8_0._speed.x * var_8_0, arg_8_0._position.y + arg_8_0._speed.y * var_8_0, arg_8_0._position.z + arg_8_0._speed.z * var_8_0)

	arg_8_0._position.y = arg_8_0._position.y + arg_8_0._verticalSpeed * var_8_0

	if arg_8_0._gravity == 0 then
		arg_8_0._reachDestFlag = Vector3.SqrDistance(arg_8_0._spawnPos, arg_8_0._position) > arg_8_0._sqrRange
	else
		if arg_8_0._fieldSwitchHeight ~= 0 and arg_8_0._position.y <= arg_8_0._fieldSwitchHeight then
			arg_8_0._field = BattleConst.BulletField.SURFACE
		end

		arg_8_0._reachDestFlag = arg_8_0._position.y <= BattleConfig.BombDetonateHeight
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

function BattleBulletUnit.Hit(arg_12_0, arg_12_1, arg_12_2)
	arg_12_0._collidedList[arg_12_1] = true

	local var_12_0 = {
		UID = arg_12_1,
		type = arg_12_2
	}

	arg_12_0:DispatchEvent(ys.Event.New(BattleBulletEvent.HIT, var_12_0))
end

function BattleBulletUnit.Intercepted(arg_13_0)
	arg_13_0:DispatchEvent(ys.Event.New(BattleBulletEvent.INTERCEPTED, {}))
end

function BattleBulletUnit.Reflected(arg_14_0)
	arg_14_0._speed.x = -arg_14_0._speed.x
end

function BattleBulletUnit.ResetVelocity(arg_15_0, arg_15_1)
	local var_15_0 = arg_15_0._tempData
	local var_15_1 = arg_15_0:GetTemplate().extra_param

	if not arg_15_1 then
		arg_15_1 = var_15_0.velocity

		if var_15_1.velocity_offset then
			arg_15_1 = math.random(arg_15_1 - var_15_1.velocity_offset, arg_15_1 + var_15_1.velocity_offset)
		elseif var_15_1.velocity_offsetF then
			arg_15_1 = arg_15_1 + math.random() * 2 * var_15_1.velocity_offsetF - var_15_1.velocity_offsetF
		end
	end

	arg_15_0._velocity = arg_15_1
	arg_15_0._convertedVelocity = BattleFormulas.ConvertBulletSpeed(arg_15_0._velocity)
end

function BattleBulletUnit.SetTemplateData(arg_16_0, arg_16_1)
	arg_16_0._tempData = setmetatable({}, {
		__index = arg_16_1
	})

	local var_16_0 = arg_16_0:GetTemplate().extra_param

	arg_16_0:SetModleID(arg_16_1.modle_ID, BattleBulletUnit.ORIGNAL_RES)
	arg_16_0:SetSFXID(arg_16_0._tempData.hit_sfx, arg_16_0._tempData.miss_sfx)
	arg_16_0:ResetVelocity()

	arg_16_0._pierceCount = arg_16_1.pierce_count

	arg_16_0:FixRange()
	arg_16_0:InitCldComponent()

	arg_16_0._accTable = Clone(arg_16_0._tempData.acceleration)

	table.sort(arg_16_0._accTable, function(arg_17_0, arg_17_1)
		return arg_17_0.t < arg_17_1.t
	end)

	arg_16_0._field = arg_16_1.effect_type
	arg_16_0._gravity = var_16_0.gravity or 0
	arg_16_0._fieldSwitchHeight = var_16_0.effectSwitchHeight or 0
	arg_16_0._ignoreShield = arg_16_0._tempData.extra_param.ignoreShield == true
	arg_16_0._autoRotate = arg_16_0._tempData.extra_param.dontRotate ~= true

	arg_16_0:SetDiverFilter()
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
	arg_21_0._offsetZ = arg_21_2 + var_21_1ac
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

function BattleBulletUnit.GetAttr(arg_25_0)
	return ys.Battle.BattleAttr.GetAttr(arg_25_0)
end

function BattleBulletUnit.SetStandHostAttr(arg_26_0, arg_26_1)
	arg_26_0._standUnit = {}

	ys.Battle.BattleAttr.SetAttr(arg_26_0._standUnit, arg_26_1)
end

function BattleBulletUnit.GetWeaponHostAttr(arg_27_0)
	if arg_27_0._standUnit then
		return ys.Battle.BattleAttr.GetAttr(arg_27_0._standUnit)
	else
		return arg_27_0:GetAttr()
	end
end

function BattleBulletUnit.GetWeaponAtkAttr(arg_28_0)
	local var_28_0 = arg_28_0:GetWeaponHostAttr()
	local var_28_1
	local var_28_2 = arg_28_0._weapon:GetAtkAttrTrasnform(var_28_0)

	if var_28_2 then
		var_28_1 = var_28_2
	else
		local var_28_3 = arg_28_0:GetWeaponTempData().attack_attribute

		var_28_1 = ys.Battle.BattleAttr.GetAtkAttrByType(var_28_0, var_28_3)
	end

	return var_28_1
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

function BattleBulletUnit.AppendDamageUnit(arg_44_0, arg_44_1)
	arg_44_0._damageList[#arg_44_0._damageList + 1] = arg_44_1
end

function BattleBulletUnit.DamageUnitListWriteback(arg_45_0)
	arg_45_0._weapon:UpdateCombo(arg_45_0._damageList)
end

function BattleBulletUnit.HasAcceleration(arg_46_0)
	return #arg_46_0._accTable ~= 0
end

function BattleBulletUnit.IsTracker(arg_47_0)
	return arg_47_0._accTable.tracker
end

function BattleBulletUnit.IsOrbit(arg_48_0)
	return arg_48_0._accTable.orbit
end

function BattleBulletUnit.IsCircle(arg_49_0)
	return arg_49_0._accTable.circle
end

function BattleBulletUnit.GetAcceleration(arg_50_0, arg_50_1)
	arg_50_0._lastAccTime = arg_50_0._lastAccTime or arg_50_0._timeStamp

	local var_50_0 = math.modf((arg_50_1 - arg_50_0._lastAccTime) / BattleBulletUnit.ACC_INTERVAL)

	arg_50_0._lastAccTime = arg_50_0._lastAccTime + BattleBulletUnit.ACC_INTERVAL * var_50_0

	local var_50_1 = arg_50_1 - arg_50_0._timeStamp
	local var_50_2 = #arg_50_0._accTable

	while var_50_2 > 0 do
		local var_50_3 = arg_50_0._accTable[var_50_2]

		if var_50_1 + BattleBulletUnit.ACC_INTERVAL < var_50_3.t then
			var_50_2 = var_50_2 - 1
		else
			return var_50_3.u * var_50_0, var_50_3.v * var_50_0
		end
	end

	return 0, 0
end

function BattleBulletUnit.reverseAcceleration(arg_51_0)
	for iter_51_0, iter_51_1 in ipairs(arg_51_0._accTable) do
		iter_51_1.u = iter_51_1.u * -1
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

function BattleBulletUnit.getTrackingTarget(arg_54_0)
	return arg_54_0._tarckingTarget
end

function BattleBulletUnit.setTrackingTarget(arg_55_0, arg_55_1)
	arg_55_0._tarckingTarget = arg_55_1
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

function BattleBulletUnit.AppendAttachBuff(arg_81_0, arg_81_1)
	arg_81_0._attachBuffList = arg_81_0._attachBuffList or arg_81_0:generateAttachBuffList()

	table.insert(arg_81_0._attachBuffList, arg_81_1)
end

function BattleBulletUnit.GetAttachBuff(arg_82_0)
	arg_82_0._attachBuffList = arg_82_0._attachBuffList or arg_82_0:generateAttachBuffList()

	return arg_82_0._attachBuffList
end

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

function BattleBulletUnit.InitCldComponent(arg_97_0)
	local var_97_0 = arg_97_0:GetTemplate().cld_box
	local var_97_1 = arg_97_0:GetTemplate().cld_offset
	local var_97_2 = var_97_1[1]

	if arg_97_0:GetIFF() == BattleConfig.FOE_CODE then
		var_97_2 = var_97_2 * -1
	end

	arg_97_0._cldComponent = ys.Battle.BattleCubeCldComponent.New(var_97_0[1], var_97_0[2], var_97_0[3], var_97_2, var_97_1[3])

	local var_97_3 = {
		type = BattleConst.CldType.BULLET,
		IFF = arg_97_0:GetIFF(),
		UID = arg_97_0:GetUniqueID()
	}

	arg_97_0._cldComponent:SetCldData(var_97_3)
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

function BattleBulletUnit.GetCldBox(arg_100_0)
	return arg_100_0._cldComponent:GetCldBox(arg_100_0:GetPosition())
end

function BattleBulletUnit.GetCldData(arg_101_0)
	return arg_101_0._cldComponent:GetCldData()
end

function BattleBulletUnit.GetSpeed(arg_102_0)
	return arg_102_0._speed
end

function BattleBulletUnit.GetSpeedRatio(arg_103_0)
	return BattleVariable.GetSpeedRatio(arg_103_0._speedExemptKey, arg_103_0._IFF)
end

function BattleBulletUnit.InitSpeed(arg_104_0, arg_104_1)
	if arg_104_0._yAngle == nil then
		arg_104_0._yAngle = (arg_104_1 or arg_104_0._baseAngle) + arg_104_0._barrageAngle
	end

	arg_104_0:calcSpeed()

	if arg_104_0:HasAcceleration() then
		arg_104_0._speedLength = arg_104_0._speed:Magnitude()

		local var_104_0 = math.deg2Rad * arg_104_0._yAngle

		arg_104_0._speedNormal = Vector3(math.cos(var_104_0), 0, math.sin(var_104_0))
		arg_104_0._speedCross = Vector3.Cross(arg_104_0._speedNormal, vector3Up)
		arg_104_0.updateSpeed = BattleBulletUnit.doAccelerate
	elseif arg_104_0:IsTracker() then
		local var_104_1 = arg_104_0._accTable.tracker

		arg_104_0._trackRange = var_104_1.range
		arg_104_0._cosAngularSpeed = math.deg2Rad * var_104_1.angular
		arg_104_0._sinAngularSpeed = math.deg2Rad * var_104_1.angular
		arg_104_0._negativeCosAngularSpeed = math.deg2Rad * var_104_1.angular * -1
		arg_104_0._negativeSinAngularSpeed = math.deg2Rad * var_104_1.angular * -1
		arg_104_0.updateSpeed = BattleBulletUnit.doTrack
	elseif arg_104_0:IsCircle() then
		local var_104_2 = arg_104_0._accTable.circle

		arg_104_0._originPos = var_104_2.center or arg_104_0._targetPos
		arg_104_0._circleAntiClockwise = tobool(var_104_2.antiClockWise)
		arg_104_0._centripetalSpeed = (var_104_2.centripetalSpeed or 0) * viewInterval
		arg_104_0._inverseFlag = 1
		arg_104_0.updateSpeed = BattleBulletUnit.doCircle
	else
		arg_104_0.updateSpeed = BattleBulletUnit.doNothing
	end
end

function BattleBulletUnit.InheritSpeed(arg_105_0, arg_105_1)
	arg_105_0._speed = Vector3(arg_105_1.x, arg_105_1.y, arg_105_1.z)
	arg_105_0._speedInited = true
end

function BattleBulletUnit.calcSpeed(arg_106_0)
	if arg_106_0._speedInited then
		return
	end

	local var_106_0 = 1 + ys.Battle.BattleAttr.GetCurrent(arg_106_0, "bulletSpeedRatio")
	local var_106_1 = arg_106_0._velocity * var_106_0
	local var_106_2 = BattleFormulas.ConvertBulletSpeed(var_106_1)
	local var_106_3 = math.deg2Rad * arg_106_0._yAngle

	arg_106_0._speed = Vector3(var_106_2 * math.cos(var_106_3), 0, var_106_2 * math.sin(var_106_3))
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

function BattleBulletUnit.FixRange(arg_111_0, arg_111_1, arg_111_2)
	arg_111_1 = arg_111_1 or arg_111_0._tempData.range
	arg_111_2 = arg_111_2 or 0

	local var_111_0 = arg_111_0._tempData.range_offset

	if var_111_0 == 0 then
		arg_111_0._range = arg_111_1
	else
		arg_111_0._range = arg_111_1 + var_111_0 * (math.random() - 0.5)
	end

	arg_111_0._range = math.max(0, arg_111_0._range + arg_111_2)
	arg_111_0._sqrRange = arg_111_0._range * arg_111_0._range
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
