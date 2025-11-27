ys = ys or {}

local ys = ys
local BattleVariable = ys.Battle.BattleVariable
local BattleEvent = ys.Battle.BattleEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleCameraUtil = singletonClass("BattleCameraUtil")

ys.Battle.BattleCameraUtil = BattleCameraUtil
BattleCameraUtil.__name = "BattleCameraUtil"
BattleCameraUtil.FOCUS_PILOT = "FOCUS_PILOT"
BattleCameraUtil.TWEEN_TO_CHARACTER = "TWEEN_TO_CHARACTER"
BattleCameraUtil.FOLLOW_GESTURE = "FOLLOW_GESTURE"

--- @return nil
--- 构造函数
function BattleCameraUtil.Ctor(self)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._camera = pg.UIMgr.GetInstance():GetMainCamera():GetComponent(typeof(Camera))
	self._cameraTF = self._camera.transform
	self._uiCamera = GameObject.Find("UICamera"):GetComponent(typeof(Camera))
	self._cameraFixMgr = pg.CameraFixMgr.GetInstance()
end

--- @return nil
--- 激活主摄像机
function BattleCameraUtil.ActiveMainCamera(self)
	CameraMgr.instance:SetActiveMainCamera(self)
end

--- @return nil
--- 初始化函数
function BattleCameraUtil.Initialize(self)
	self._cameraTF.localPosition = BattleConfig.CAMERA_INIT_POS

	CameraMgr.instance:SetCameraOrthographicSize(self._camera, 20)
	BattleVariable.UpdateCameraPositionArgs()
	self:setArrowPoint()

	self._boundFix = ys.Battle.BattleCameraBoundFixDecorate.New()
	self._followPilot = ys.Battle.BattleCameraFollowPilot.New()
	self._focusCharacter = ys.Battle.BattleCameraFocusChar.New()
	self._fromTo = ys.Battle.BattleCameraTween.New()
	self._gesture = ys.Battle.BattleCameraFollowGesture.New()

	self:active()
	self:SwitchCameraPos()

	self._shakeEnabled = true
	self._uiMediator = ys.Battle.BattleState.GetInstance():GetMediatorByName(ys.Battle.BattleUIMediator.__name)
end

--- @return nil
--- 清理函数
function BattleCameraUtil.Clear(self)
	self.ActiveMainCamera(false)
	LeanTween.cancel(go(self._camera))
	self:Deactive()
	self:StopShake()
	self._boundFix:Dispose()
	self._followPilot:Dispose()
	self._focusCharacter:Dispose()
	self._fromTo:Dispose()
	self._gesture:Dispose()

	self._cameraTF.localPosition = Vector3(0, 62, -10)

	CameraMgr.instance:SetCameraOrthographicSize(self._camera, 20)

	self._uiMediator = nil
end

--- @param upperBound number
--- @param lowerBound number
--- @param leftBound number
--- @param rightBound number
--- @return number, number, number, number
--- 根据地图边界设置摄像机边界
function BattleCameraUtil.SetMapData(self, upperBound, lowerBound, leftBound, rightBound)
	local cameraTop, cameraBottom, cameraLeft, cameraRight = self._boundFix:SetMapData(upperBound, lowerBound, leftBound, rightBound)
	local actualWidth = pg.CameraFixMgr.GetInstance().actualWidth

	-- CAMERA_GOLDEN_RATE = 0.618
	self._followPilot:SetGoldenRation(self._camera:ScreenToWorldPoint(Vector3(actualWidth * BattleConfig.CAMERA_GOLDEN_RATE, 0, 0)).x - self._cameraTF.position.x)

	return cameraTop, cameraBottom, cameraLeft, cameraRight
end

--- @param fleetVO BattleFleetVO
--- @return nil
--- 设置焦点舰队
function BattleCameraUtil.SetFocusFleet(self, fleetVO)
	self._followPilot:SetFleetVO(fleetVO)

	self._cameraTF.position = self._boundFix:GetCameraPos(self._followPilot:GetCameraPos())

	BattleVariable.UpdateCameraPositionArgs()
end

--- @param slider BattleCameraSlider
--- @return nil
--- 设置摄像机滑块
function BattleCameraUtil.SetCameraSilder(self, slider)
	self._gesture:SetGestureComponent(slider)
end

--- @param phase string
--- @return table|nil
--- 切换摄像机位置模式
function BattleCameraUtil.SwitchCameraPos(self, phase)
	if phase == "TWEEN_TO_CHARACTER" then
		function self._currentCameraPos()
			return self._fromTo:GetCameraPos()
		end
	elseif phase == "FOLLOW_GESTURE" then
		function self._currentCameraPos()
			return self._boundFix:GetCameraPos(self._gesture:GetCameraPos(self._cameraTF.position))
		end
	else
		function self._currentCameraPos()
			return self._boundFix:GetCameraPos(self._followPilot:GetCameraPos())
		end
	end
end

--- @param screenPoint Vector3
--- @return Vector3
--- 将屏幕坐标转换为世界坐标
function BattleCameraUtil.GetS2WPoint(self, screenPoint)
	return self._camera:ScreenToWorldPoint(screenPoint)
end

--- @return nil
--- 设置箭头指示点
function BattleCameraUtil.setArrowPoint(self)
	local offset = 1
	local leftBottomWorldPoint = self._uiCamera:ScreenToWorldPoint(self._cameraFixMgr.leftBottomVector) + Vector3(offset, offset, 0)
	local rightTopWorldPoint = self._uiCamera:ScreenToWorldPoint(self._cameraFixMgr.rightTopVector) - Vector3(offset, offset, 0)

	self._arrowCenterPos = (leftBottomWorldPoint + rightTopWorldPoint) * 0.5
	self._arrowRightHorizon = rightTopWorldPoint.x + 4
	self._arrowTopHorizon = rightTopWorldPoint.y + 4
	self._arrowBottomHorizon = leftBottomWorldPoint.y - 4
	self._arrowLeftHorizon = leftBottomWorldPoint.x - 3.75
	self._arrowLeftBottomPos_notch = self._uiCamera:ScreenToWorldPoint(self._cameraFixMgr.notchAdaptLBVector) + Vector3(offset, offset, 0)
	self._arrowRightTopPos_notch = self._uiCamera:ScreenToWorldPoint(self._cameraFixMgr.notchAdaptRTVector) - Vector3(offset, offset, 0)
	self._arrowFieldHalfWidth_notch = self._arrowRightTopPos_notch.x - self._arrowCenterPos.x
end

--- @return nil
--- 摄像机的Update函数
function BattleCameraUtil.Update(self)
	local newPosition = self:GetCameraPoint()
	local originalPosition = self._cameraTF.position

	-- ? 此处第二个比较疑似少写了 .z
	if originalPosition.x ~= newPosition.x or originalPosition.z ~= newPosition then
		self._cameraTF.position = newPosition

		BattleVariable.UpdateCameraPositionArgs()
	end

	if self._shakeInfo and self._shakeEnabled then
		self:DoShake()
	end
end

--- @param shakeTemplate table<number, table<string, any>>
--- @return nil
--- 根据shakeTemplate设置晃动信息
--- shakeTemplate的内容参考sharecfg/shake_template.lua
function BattleCameraUtil.StartShake(self, shakeTemplate)
	if self._shakeInfo and (self._shakeInfo._priority > shakeTemplate.priority or shakeTemplate.priority == 0) then
		return
	end

	self._shakeInfo = {}
	self._shakeInfo._elapsed = 0
	self._shakeInfo._duration = shakeTemplate.time or 0
	self._shakeInfo._count = 0
	self._shakeInfo._loop = shakeTemplate.loop or 1
	self._shakeInfo._direction = 1
	self._shakeInfo._vibrationH = shakeTemplate.vibration_H or 0
	self._shakeInfo._fricConstH = shakeTemplate.friction_const_H or 0
	self._shakeInfo._fricCoefH = shakeTemplate.friction_coefficient_H or 1
	self._shakeInfo._vibrationV = shakeTemplate.vibration_V or 0
	self._shakeInfo._fricConstV = shakeTemplate.friction_const_V or 0
	self._shakeInfo._fricCoefV = shakeTemplate.friction_coefficient_V or 1
	self._shakeInfo._diff = Vector3.zero
	self._shakeInfo._bounce = shakeTemplate.bounce

	if self._shakeInfo._bounce then
		self._shakeInfo._duration = self._shakeInfo._duration * 0.5
	end

	self._shakeInfo._priority = shakeTemplate.priority
end

--- @return nil
--- 停止晃动
function BattleCameraUtil.StopShake(self)
	self._shakeInfo = nil
end

--- @return nil
--- 执行晃动
function BattleCameraUtil.DoShake(self)
	self._shakeInfo._count = self._shakeInfo._count + 1
	self._shakeInfo._elapsed = self._shakeInfo._elapsed + Time.deltaTime

	local offsetX = self._shakeInfo._vibrationH * (math.random() * 0.5 + 0.5) * self._shakeInfo._count
	local offsetY = self._shakeInfo._vibrationV * (math.random() * 0.5 + 0.5) * self._shakeInfo._count
	local offsetVector = Vector3(offsetX, offsetY, 0):Mul(self._shakeInfo._direction)

	LuaHelper.UpdateTFLocalPos(self._cameraTF, offsetVector - self._shakeInfo._diff)

	if self._shakeInfo._count >= self._shakeInfo._loop then
		self._shakeInfo._vibrationH = self._shakeInfo._vibrationH * self._shakeInfo._fricCoefH + self._shakeInfo._fricConstH
		self._shakeInfo._vibrationV = self._shakeInfo._vibrationV * self._shakeInfo._fricCoefV + self._shakeInfo._fricConstV
		self._shakeInfo._direction = -self._shakeInfo._direction
		self._shakeInfo._count = 0
	end

	if self._shakeInfo._elapsed > self._shakeInfo._duration then
		if self._shakeInfo._bounce then
			BattleCameraUtil.bounceReverse(self._shakeInfo)

			self._shakeInfo._elapsed = 0
			self._shakeInfo._bounce = false
		else
			self:StopShake()
		end
	else
		self._shakeInfo._diff = offsetVector
	end
end

--- @param shakeInfo table<string, any>
--- @return nil
--- 反转弹跳效果的摩擦系数和常数
function BattleCameraUtil.bounceReverse(shakeInfo)
	if shakeInfo._fricCoefH ~= 0 then
		shakeInfo._fricCoefH = 1 / shakeInfo._fricCoefH
	end

	if shakeInfo._fricCoefV ~= 0 then
		shakeInfo._fricCoefV = 1 / shakeInfo._fricCoefV
	end

	shakeInfo._fricConstH = shakeInfo._fricConstH * -1
	shakeInfo._fricConstV = shakeInfo._fricConstV * -1
end

--- @return nil
--- 暂停晃动
function BattleCameraUtil.PauseShake(self)
	self._shakeEnabled = false
end

--- @return nil
--- 恢复晃动
function BattleCameraUtil.ResumeShake(self)
	self._shakeEnabled = true
end

--- @return nil
--- 激活摄像机工具（开始监听更新）
function BattleCameraUtil.active(self)
	UpdateBeat:Add(self.Update, self)
end

--- @return nil
--- 停用摄像机工具（停止监听更新）
function BattleCameraUtil.Deactive(self)
	UpdateBeat:Remove(self.Update, self)
end

--- @param caster BattleUnit
--- @param speed number
--- @return nil
--- 插入角色立绘
function BattleCameraUtil.CutInPainting(self, caster, speed)
	self:DispatchEvent(ys.Event.New(BattleEvent.SHOW_PAINTING, {
		caster = caster,
		speed = speed
	}))
end

--- @param key string
--- @param speed number
--- @param exemptUnit BattleUnit: 不被影响的单位(动画速度匹配时间流速)
function BattleCameraUtil.BulletTime(self, key, speed, exemptUnit)
	local bulletTimeArgs = {
		key = key,
		speed = speed,
		exemptUnit = exemptUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.BULLET_TIME, bulletTimeArgs))
	ys.Battle.BattleState.GetInstance():ScaleTimer(speed)

	if self._uiMediator then
		-- 调整UI速度，匹配时间流速
		local uiSpeed = 1 / (speed or 1)

		self._uiMediator:ScaleUISpeed(uiSpeed)

		if self._uiMediator:GetAppearFX() ~= nil then
			self._uiMediator:GetAppearFX():GetComponent(typeof(Animator)).speed = uiSpeed
		end
	end
end

--- @param currentSize number
--- @param targetSize number
--- @param duration number
--- @param ease boolean
--- @return nil
--- 缩放摄像机视野大小
function BattleCameraUtil.ZoomCamara(self, currentSize, targetSize, duration, ease)
	duration = duration or 1.6
	-- CAMERA_SIZE = 20
	targetSize = targetSize or BattleConfig.CAMERA_SIZE
	currentSize = currentSize or CameraMgr.instance:GetCameraOrthographicSize(self._camera)

	-- LeenTween是一个Unity插件，用于实现各种缓动动画
	-- 这里创建了一个从currentSize到targetSize的缓动动画，持续时间为duration
	local tween = LeanTween.value(go(self._camera), currentSize, targetSize, duration):setOnUpdate(System.Action_float(function(arg_26_0)
		CameraMgr.instance:SetCameraOrthographicSize(self._camera, arg_26_0)
	end))

	-- ease参数用于指定缓动动画的缓动函数类型
	if ease then
		tween:setEase(LeanTweenType.easeOutExpo)
	end
end

--- @param unit BattleUnit
--- @param duration number
--- @param extraBulletTime number
--- @param skill boolean
--- @param ease boolean
--- @return nil
--- 聚焦角色
function BattleCameraUtil.FocusCharacter(self, unit, duration, extraBulletTime, skill, ease)
	self:StopShake()

	-- 此处的delay不知道从何而来，猜测是想要一个默认值为0的参数
	delay = delay or 0

	local focusCharacterArgs = {
		unit = unit,
		duration = duration,
		extraBulletTime = extraBulletTime,
		skill = skill or false
	}

	LeanTween.cancel(go(self._camera))

	local originalCameraPosition = self._cameraTF.position

	if unit ~= nil then
		self._focusCharacter:SetUnit(unit)

		local characterCameraPosition = self._focusCharacter:GetCameraPos()

		if ease == nil then
			ease = true
		end

		-- 此处的作用是将镜头从默认位置转向角色(对应的摄像头)位置，在delay秒后开始，这个过程使用duration秒
			-- 因此一般可以认为使用的时间为 duration + delay，以用于计算
			-- 这里的_fromTo 是 BattleCameraTween 的一个实例
		self._fromTo:SetFromTo(self._camera, originalCameraPosition, characterCameraPosition, duration, delay, ease)
		self:SwitchCameraPos(BattleCameraUtil.TWEEN_TO_CHARACTER)
	else
		-- pilot大致指的是默认的摄像头位置
		local pilotCameraPosition = self._boundFix:GetCameraPos(self._followPilot:GetCameraPos())

		local function onCompleteFunc()
			self:SwitchCameraPos()
		end

		if ease == nil then
			ease = false
		end

		-- 如果没有指定unit，则将镜头转回一个默认位置
		self._fromTo:SetFromTo(self._camera, originalCameraPosition, pilotCameraPosition, duration, delay, ease, onCompleteFunc)
		self:SwitchCameraPos(BattleCameraUtil.TWEEN_TO_CHARACTER)
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.CAMERA_FOCUS, focusCharacterArgs))
end

--- @return nil
--- 重置摄像机焦点
function BattleCameraUtil.ResetFocus(self)
	self:StopShake()
	LeanTween.cancel(go(self._camera))
	LeanTween.cancel(go(self._uiCamera))

	local pilotCameraPosition = self._boundFix:GetCameraPos(self._followPilot:GetCameraPos())

	LeanTween.move(go(self._camera), pilotCameraPosition, BattleConfig.CAM_RESET_DURATION):setOnUpdate(System.Action_float(function(arg)
		BattleVariable.UpdateCameraPositionArgs()
	end))
	self:DispatchEvent(ys.Event.New(BattleEvent.CAMERA_FOCUS_RESET, {}))
end

--- @param referenceVector Vector3
--- @param arrowVector Vector3
--- @return Vector3|nil
--- 获取箭头的位置?
function BattleCameraUtil.GetCharacterArrowBarPosition(self, referenceVector, arrowVector)
	local arrowLeftBottomPos_notch = self._arrowLeftBottomPos_notch
	local arrowRightTopPos_notch = self._arrowRightTopPos_notch
	local arrowCenterPos = self._arrowCenterPos

	if referenceVector.x >= self._arrowLeftHorizon and referenceVector.x < self._arrowRightHorizon and referenceVector.y >= self._arrowBottomHorizon and referenceVector.y <= self._arrowTopHorizon then
		return nil
	else
		local deltaY = referenceVector.y - arrowCenterPos.y
		local arrowX
		local deltaX

		if referenceVector.x > arrowCenterPos.x then
			arrowX = arrowRightTopPos_notch.x
			deltaX = referenceVector.x - arrowCenterPos.x
		else
			arrowX = arrowLeftBottomPos_notch.x
			deltaX = arrowCenterPos.x - referenceVector.x
		end

		local arrowY = deltaY / deltaX * self._arrowFieldHalfWidth_notch

		if arrowY > arrowRightTopPos_notch.y then
			arrowY = arrowRightTopPos_notch.y
			arrowX = deltaX / deltaY * (arrowY - arrowCenterPos.y)
		elseif arrowY < arrowLeftBottomPos_notch.y then
			arrowY = arrowLeftBottomPos_notch.y
			arrowX = deltaX / deltaY * (arrowY - arrowCenterPos.y)
		end

		if arrowVector then
			arrowVector:Set(arrowX, arrowY, 10)

			return arrowVector
		else
			return Vector3(arrowX, arrowY, 10)
		end
	end
end

--- @return Vector3
--- 获取摄像机当前的位置
function BattleCameraUtil.GetCameraPoint(self)
	return self._currentCameraPos()
end

--- @return Vector3
--- 获取箭头中心的位置
function BattleCameraUtil.GetArrowCenterPos(self)
	return self._arrowCenterPos
end

--- @return Camera
--- 获取摄像机
function BattleCameraUtil.GetCamera(self)
	return self._camera
end

--- @param fx Object
--- @param orderDiff number
function BattleCameraUtil.Add2Camera(self, fx, orderDiff)
	orderDiff = orderDiff or 0
	fx = tf(fx)

	fx:SetParent(self._cameraTF)
	pg.ViewUtils.SetSortingOrder(fx, orderDiff)

	return self._cameraTF.localScale
end

--- @return nil
--- 暂停摄像机的缓动动画
function BattleCameraUtil.PauseCameraTween(self)
	LeanTween.pause(go(self._camera))
	LeanTween.pause(go(self._uiCamera))
end

--- @return nil
--- 恢复摄像机的缓动动画
function BattleCameraUtil.ResumeCameraTween(self)
	LeanTween.resume(go(self._camera))
	LeanTween.resume(go(self._uiCamera))
end
