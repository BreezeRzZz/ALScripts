ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleBullet = class("BattleBullet", ys.Battle.BattleSceneObject)
ys.Battle.BattleBullet.__name = "BattleBullet"

local BattleBullet = ys.Battle.BattleBullet

function BattleBullet.Ctor(arg_1_0)
	BattleBullet.super.Ctor(arg_1_0)
	ys.EventListener.AttachEventListener(arg_1_0)

	arg_1_0.resMgr = ys.Battle.BattleResourceManager.GetInstance()
	arg_1_0._cacheSpeed = Vector3.zero
	arg_1_0._calcSpeed = Vector3.zero
	arg_1_0._cacheTFPos = Vector3.zero
end

function BattleBullet.Update(arg_2_0, arg_2_1)
	local var_2_0 = arg_2_0._bulletData:GetSpeed()

	arg_2_0._calcSpeed:Set(var_2_0.x, var_2_0.y, var_2_0.z)

	local var_2_1 = arg_2_0._bulletData:GetVerticalSpeed()

	if var_2_1 ~= 0 then
		arg_2_0._calcSpeed.y = arg_2_0._calcSpeed.y + var_2_1
	end

	if arg_2_0._cacheSpeed ~= arg_2_0._calcSpeed then
		if arg_2_0._rotateScript then
			arg_2_0._rotateScript:SetSpeed(arg_2_0._calcSpeed)
		end

		arg_2_0._cacheSpeed:Set(arg_2_0._calcSpeed.x, arg_2_0._calcSpeed.y, arg_2_0._calcSpeed.z)
	end

	if math.abs(arg_2_0._calcSpeed.x) >= 0.01 or math.abs(arg_2_0._calcSpeed.z) >= 0.01 or math.abs(arg_2_0._calcSpeed.y) >= 0.01 then
		arg_2_0:UpdatePosition()
	else
		local var_2_2 = arg_2_0:GetPosition()

		if math.abs(arg_2_0._cacheTFPos.x - var_2_2.x) >= 0.1 or math.abs(arg_2_0._cacheTFPos.z - var_2_2.z) >= 0.1 or math.abs(arg_2_0._cacheTFPos.y - var_2_2.y) >= 0.1 then
			arg_2_0:UpdatePosition()
		end
	end
end

function BattleBullet.UpdatePosition(arg_3_0)
	local var_3_0 = arg_3_0:GetPosition()

	arg_3_0._tf.localPosition = var_3_0

	arg_3_0._cacheTFPos:Set(var_3_0.x, var_3_0.y, var_3_0.z)
end

function BattleBullet.DoOutRange(arg_4_0)
	arg_4_0._bulletMissFunc(arg_4_0)
end

function BattleBullet.SetBulletData(arg_5_0, arg_5_1)
	arg_5_0._bulletData = arg_5_1

	arg_5_0._bulletData:SetStartTimeStamp(pg.TimeMgr.GetInstance():GetCombatTime())

	arg_5_0._cfgTpl = arg_5_1:GetTemplate()
	arg_5_0._IFF = arg_5_1:GetIFF()

	arg_5_0:AddBulletEvent()
end

function BattleBullet.AddBulletEvent(arg_6_0)
	arg_6_0._bulletData:RegisterEventListener(arg_6_0, BattleBulletEvent.HIT, arg_6_0.onBulletHit)
	arg_6_0._bulletData:RegisterEventListener(arg_6_0, BattleBulletEvent.INTERCEPTED, arg_6_0.onIntercepted)
	arg_6_0._bulletData:RegisterEventListener(arg_6_0, BattleBulletEvent.OUT_RANGE, arg_6_0.onOutRange)
end

function BattleBullet.RemoveBulletEvent(arg_7_0)
	arg_7_0._bulletData:UnregisterEventListener(arg_7_0, BattleBulletEvent.HIT)
	arg_7_0._bulletData:UnregisterEventListener(arg_7_0, BattleBulletEvent.INTERCEPTED)
	arg_7_0._bulletData:UnregisterEventListener(arg_7_0, BattleBulletEvent.OUT_RANGE)
end

function BattleBullet.onBulletHit(arg_8_0, arg_8_1)
	local var_8_0 = arg_8_1.Data
	local var_8_1 = arg_8_1.Data.UID
	local var_8_2 = arg_8_1.Data.type

	arg_8_0._bulletHitFunc(arg_8_0, var_8_1, var_8_2)
end

function BattleBullet.onIntercepted(arg_9_0)
	local var_9_0, var_9_1 = ys.Battle.BattleFXPool.GetInstance():GetFX(arg_9_0:GetBulletData():GetTemplate().hit_fx)

	pg.EffectMgr.GetInstance():PlayBattleEffect(var_9_0, var_9_1:Add(arg_9_0:GetPosition()), true)
end

function BattleBullet.onOutRange(arg_10_0, arg_10_1)
	arg_10_0:DoOutRange()
end

function BattleBullet.GetBulletData(arg_11_0)
	return arg_11_0._bulletData
end

function BattleBullet.GetPosition(arg_12_0)
	return arg_12_0._bulletData:GetPosition()
end

function BattleBullet.Dispose(arg_13_0)
	if arg_13_0._rotateScript then
		arg_13_0._rotateScript:SetSpeed(Vector3.zero)
	end

	arg_13_0:RemoveBulletEvent()

	if arg_13_0._isTempGO then
		arg_13_0._factory:RecyleTempModel(arg_13_0._go)
	else
		ys.Battle.BattleResourceManager.GetInstance():DestroyOb(arg_13_0._go)
	end

	if arg_13_0._trackFX then
		arg_13_0.resMgr.GetInstance():DestroyOb(arg_13_0._trackFX)
	end

	arg_13_0._skeleton = nil
	arg_13_0._go = nil
	arg_13_0._tf = nil
	arg_13_0._trackFX = nil

	ys.EventListener.DetachEventListener(arg_13_0)
end

function BattleBullet.GetModleID(arg_14_0)
	return arg_14_0._bulletData:GetModleID()
end

function BattleBullet.GetFXID(arg_15_0)
	return arg_15_0._cfgTpl.hit_fx
end

function BattleBullet.GetMissFXID(arg_16_0)
	return arg_16_0._cfgTpl.miss_fx
end

function BattleBullet.GetTrackFXID(arg_17_0)
	return arg_17_0._cfgTpl.track_fx
end

function BattleBullet.AddModel(arg_18_0, arg_18_1)
	if arg_18_0._isTempGO and arg_18_0._go == nil then
		ys.Battle.BattleResourceManager.GetInstance():DestroyOb(arg_18_1)

		return false
	else
		if arg_18_0._isTempGO then
			LuaHelper.CopyTransformInfoGO(arg_18_1, arg_18_0._go)
			arg_18_0._factory:RecyleTempModel(arg_18_0._go)

			arg_18_0._isTempGO = false
		end

		arg_18_0:SetGO(arg_18_1)
		arg_18_0._bulletData:ActiveCldBox()

		if arg_18_0._bulletData:IsAutoRotate() then
			arg_18_0:AddRotateScript()
		end

		local var_18_0 = arg_18_0._tf:Find("bullet")

		if var_18_0 and var_18_0:GetComponent(typeof(SpineAnim)) then
			arg_18_0._skeleton = var_18_0:GetComponent("SkeletonAnimation")
			arg_18_0._spineBullet = true

			var_18_0:GetComponent(typeof(SpineAnim)):SetAction("normal", 0, false)
		end

		local var_18_1 = arg_18_0._tf:Find("bullet_random")

		if var_18_1 and var_18_1:GetComponent(typeof(SpineAnim)) then
			arg_18_0._skeleton = var_18_1:GetComponent("SkeletonAnimation")
			arg_18_0._spineBullet = true

			local var_18_2 = var_18_1:GetComponent(typeof(SpineAnim))
			local var_18_3 = tostring(math.random(3))

			var_18_2:SetAction(var_18_3, 0, false)
		end

		return true
	end
end

function BattleBullet.SetAnimaSpeed(arg_19_0, arg_19_1)
	if arg_19_0._skeleton then
		arg_19_1 = arg_19_1 or 1
		arg_19_0._skeleton.timeScale = arg_19_1
	end
end

function BattleBullet.AddRotateScript(arg_20_0)
	arg_20_0._rotateScript = arg_20_0.resMgr:GetRotateScript(arg_20_0._go)
end

function BattleBullet.AddTempModel(arg_21_0, arg_21_1)
	arg_21_0._isTempGO = true

	arg_21_0:SetGO(arg_21_1)

	if arg_21_0._bulletData:IsAutoRotate() then
		arg_21_0:AddRotateScript()
	end
end

function BattleBullet.AddTrack(arg_22_0, arg_22_1)
	arg_22_0._trackFX = arg_22_1

	LuaHelper.SetGOParentTF(arg_22_1, arg_22_0._tf, false)
end

-- 被各子弹的BulletFactory.MakeModel调用
-- 处理子弹生成时的视觉相关逻辑(位置、朝向、速度初始化等)
function BattleBullet.SetSpawn(self, position)
	local offset, zExtraOffset = self:getHeightAdjust(position)
	local _offset = offset:Clone()

	_offset.z = _offset.z + zExtraOffset
	self._tf.localPosition = _offset
	-- note: 这里对应到实际的数据实体(BattleBulletUnit)的SetSpawnPosition
	self._bulletData:SetSpawnPosition(_offset)

	local targetPos, _, _ = self._bulletData:GetRotateInfo()

	-- 如果有目标点，会设定一个初始角度(根据getHeightAdjust计算出来的offset和zExtraOffset)
	if targetPos then
		local angle
		-- IMPORTANT: 是否计入zExtraOffset
		if self._bulletData:GetOffsetPriority() then
			angle = math.rad2Deg * math.atan2(targetPos.z - offset.z, targetPos.x - _offset.x)
		else
			angle = math.rad2Deg * math.atan2(targetPos.z - offset.z - zExtraOffset, targetPos.x - _offset.x)
		end

		self._bulletData:InitSpeed(angle)
	else
		self._bulletData:InitSpeed(nil)
	end
end
-- TODO
function BattleBullet.getHeightAdjust(self, position)
	local extra_param = self._bulletData:GetTemplate().extra_param

	if extra_param.airdrop then
		local explodePosition = self._bulletData:GetExplodePostion()
		local xExtraOffset = 0

		if extra_param.dropOffset then
			-- t = sqrt(2h/g)
			-- xExtraOffset = v * t
			-- 表示的是，y轴上落下来的时间，刚好能走这么多距离
			-- 因此提前这个距离投放，使得落点正好是目标点，即从XZ平面上用的时间和y轴上落下的时间一致
			xExtraOffset = math.sqrt(math.abs(extra_param.offsetY * 2 / self._bulletData._gravity)) * self._bulletData:GetConvertedVelocity()

			if self._bulletData:GetHost():GetDirection() < 0 then
				xExtraOffset = xExtraOffset * -1
			end
		end

		return Vector3(explodePosition.x - xExtraOffset, extra_param.offsetY or position.y, explodePosition.z), 0
	else
		-- 根源来自于barrage_template中的offset_x, offset_z
		local offsetX, offsetZ = self._bulletData:GetOffset()
		local positionX = position.x + offsetX
		local positionZ = position.z + offsetZ
		-- gravity不为0时满足
		if self._bulletData:IsGravitate() then
			return Vector3(positionX, position.y, positionZ), 0
		else
			local zExtraOffset = 0
			local positionY
			-- BulletHeight = 1
			local BulletHeight = BattleConfig.BulletHeight
			-- 即position.y <= 1时不做高度调整
			-- 高度调整的目的可能是透视处理?
			if BulletHeight >= position.y then
				positionY = position.y
			else
				positionY = BulletHeight
				zExtraOffset = self.GetZExtraOffset(position.y)
			end

			return Vector3(positionX, positionY, positionZ), zExtraOffset
		end
	end
end
-- TODO
function BattleBullet.GetZExtraOffset(positionY)
	-- HeightOffsetRate = 1.5
	-- 即1.5 * (positionY - 1）
	return BattleConfig.HeightOffsetRate * (positionY - BattleConfig.BulletHeight)
end

function BattleBullet.GetFactory(arg_26_0)
	return arg_26_0._factory
end

function BattleBullet.SetFactory(arg_27_0, arg_27_1)
	arg_27_0._factory = arg_27_1
end

function BattleBullet.SetFXFunc(arg_28_0, arg_28_1, arg_28_2)
	arg_28_0._bulletHitFunc = arg_28_1
	arg_28_0._bulletMissFunc = arg_28_2
end

function BattleBullet.Neutrailze(arg_29_0)
	if arg_29_0._bulletMissFunc then
		arg_29_0._bulletMissFunc(arg_29_0)
	end

	SetActive(arg_29_0._go, false)
end
