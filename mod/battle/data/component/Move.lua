ys = ys or {}
-- 舰队的移动组件, 负责处理舰队整体的移动逻辑
local BattleVariable = ys.Battle.BattleVariable
local MoveComponent = class("MoveComponent")

ys.Battle.MoveComponent = MoveComponent

local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas

MoveComponent._pos = Vector3.zero
MoveComponent._isForceMove = false
MoveComponent._staticState = false
MoveComponent._speed = Vector3.zero
MoveComponent._additiveSpeedList = {}
MoveComponent._additiveSpeed = Vector3.zero
MoveComponent._corpsLimitSpeed = 0
MoveComponent._leftCorpsBound = 0
MoveComponent._rightCorpsBound = 0
MoveComponent._immuneAreaLimit = false
MoveComponent._immuneMaxAreaLimit = false
MoveComponent._leftBorder = 0
MoveComponent._rightBorder = 0
MoveComponent._upBorder = 0
MoveComponent._downBorder = 0
MoveComponent._IFF = 0

--- 构造函数
function MoveComponent.Ctor(self)
	return
end

--- 获取当前位置
--- @return Vector3: 位置
function MoveComponent.GetPos(self)
	return self._pos
end

--- 设置位置
--- @param pos Vector3: 新位置
function MoveComponent.SetPos(self, pos)
	self._pos = pos
end

--- 每帧更新：计算最终速度
function MoveComponent.Update(self)
	self._speed = self:GetFinalSpeed()
end

--- 通过碰撞组件修正速度
--- @param cldComponent BattleCldComponent: 碰撞组件
function MoveComponent.FixSpeed(self, cldComponent)
	assert(cldComponent.FixSpeed ~= nil and type(cldComponent.FixSpeed) == "function", " MoveComponent.FixSpeed 速度修正出错")
	cldComponent:FixSpeed(self._speed)
end

--- 按速度倍率移动
--- @param speedRatio number: 速度倍率（默认1）
function MoveComponent.Move(self, speedRatio)
	speedRatio = speedRatio or 1
	self._pos.x = self._pos.x + self._speed.x * speedRatio
	self._pos.y = self._pos.y + self._speed.y * speedRatio
	self._pos.z = self._pos.z + self._speed.z * speedRatio
end

--- 获取当前速度
--- @return Vector3: 速度
function MoveComponent.GetSpeed(self)
	return self._speed
end

--- 设置阵营区域范围
--- @param leftCorpsBound number: 左边界
--- @param rightCorpsBound number: 右边界
function MoveComponent.SetCorpsArea(self, leftCorpsBound, rightCorpsBound)
	self._leftCorpsBound = leftCorpsBound
	self._rightCorpsBound = rightCorpsBound
end

--- 设置地图边界
--- @param leftBorder number: 左边界
--- @param rightBorder number: 右边界
--- @param upBorder number: 上边界
--- @param downBorder number: 下边界
function MoveComponent.SetBorder(self, leftBorder, rightBorder, upBorder, downBorder)
	self._leftBorder = leftBorder
	self._rightBorder = rightBorder
	self._upBorder = upBorder
	self._downBorder = downBorder
end

--- 获取最终速度（综合初始速度、附加力、边界限制）
--- @return Vector3: 最终速度
function MoveComponent.GetFinalSpeed(self)
	local initialSpeed = self:getInitialSpeed()

	if not self._unstoppable then
		initialSpeed = self:AdditiveForce(initialSpeed)
	end

	return (self:BorderLimit(initialSpeed))
end

-- 限制舰队在阵营区域内移动
-- MoveComponent.getInitialSpeed调用
--- @param initialSpeed Vector3: 初始速度
--- @return Vector3: 限制后的速度
function MoveComponent.CorpsAreaLimit(self, initialSpeed)
	if self._immuneAreaLimit then
		return initialSpeed
	end

	local currentX = self._pos.x
	local limitSpeed = self._corpsLimitSpeed

	if currentX < self._leftCorpsBound then
		limitSpeed = math.max(limitSpeed, 0.1)

		if initialSpeed.x < 0 then
			limitSpeed = math.min(10, limitSpeed * 1.04)
		end
	elseif currentX > self._rightCorpsBound then
		limitSpeed = math.min(limitSpeed, -0.1)

		if initialSpeed.x > 0 then
			limitSpeed = math.max(-10, limitSpeed * 1.04)
		end
	else
		limitSpeed = limitSpeed < 0.1 and limitSpeed > -0.1 and 0 or limitSpeed * 0.8
	end

	self._corpsLimitSpeed = limitSpeed
	initialSpeed.x = initialSpeed.x + self._corpsLimitSpeed

	return initialSpeed
end

--- 地图边界限制
--- @param speed Vector3: 当前速度
--- @return Vector3: 限制后的速度
function MoveComponent.BorderLimit(self, speed)
	if self._immuneMaxAreaLimit then
		return speed
	end

	local currentPos = self._pos

	if speed.x < 0 and currentPos.x <= self._leftBorder or speed.x > 0 and currentPos.x >= self._rightBorder then
		speed.x = 0
	end

	if speed.z < 0 and currentPos.z <= self._downBorder or speed.z > 0 and currentPos.z >= self._upBorder then
		speed.z = 0
	end

	return speed
end

--- 设置是否免疫区域限制
--- @param isImmune boolean: 是否免疫
function MoveComponent.ImmuneAreaLimit(self, isImmune)
	self._immuneAreaLimit = isImmune
end

--- 设置是否免疫最大区域限制
--- @param isImmune boolean: 是否免疫
function MoveComponent.ImmuneMaxAreaLimit(self, isImmune)
	self._immuneMaxAreaLimit = isImmune
end

--- 获取初始速度（根据移动模式选择不同速度来源）
--- @return Vector3: 初始速度
function MoveComponent.getInitialSpeed(self)
	if self._isForceMove and not self._unstoppable then
		local forceSpeed = self._forceSpeed

		self:UpdateForceMove()

		return forceSpeed
	end

	if self._staticState and not self._unstoppable then
		return Vector3.zero
	end

	if self._manuallyMove then
		return self:CorpsAreaLimit(self._manuallyMove())
	end

	assert(self._autoMoveAi ~= nil, "角色缺少默认移动的ai")

	return self._autoMoveAi()
end

--- 设置强制移动
--- @param direction Vector3: 移动方向
--- @param speed number: 移动速度
--- @param reduceSpeed number: 减速值
--- @param lastTime number: 持续时间
--- @param decayValve number: 衰减阈值
function MoveComponent.SetForceMove(self, direction, speed, reduceSpeed, lastTime, decayValve)
	self._isForceMove = true
	direction = direction.normalized
	self._forceSpeed = direction * speed
	self._forceReduce = direction * reduceSpeed
	self._forceLastTime = lastTime
	self._decayValve = decayValve or 0
end

--- 更新强制移动（每帧衰减）
function MoveComponent.UpdateForceMove(self)
	local remainingTime = self._forceLastTime

	if remainingTime <= 0 then
		self:ClearForceMove()

		return
	end

	self._forceLastTime = remainingTime - 1

	if remainingTime < self._decayValve then
		self._forceSpeed:Sub(self._forceReduce)
	end
end

--- 清除强制移动
function MoveComponent.ClearForceMove(self)
	self._isForceMove = false
	self._forceSpeed = nil
	self._forceReduce = nil
	self._forceLastTime = nil
end

--- 设置静止状态
--- @param isStatic boolean: 是否静止
function MoveComponent.SetStaticState(self, isStatic)
	self._staticState = isStatic
end

-- 被AutoPilot.Ctor调用
--- @param autoPilot AutoPilot: 自动驾驶组件
--- @param unit BattleUnit: 单位
function MoveComponent.SetAutoMoveAI(self, autoPilot, unit)
	function self._autoMoveAi()
		return autoPilot:GetDirection():Mul(unit:GetAttrByName("velocity"))
	end
end

--- 设置编队控制信息
--- @param formationCtrl table: 编队控制数据
function MoveComponent.SetFormationCtrlInfo(self, formationCtrl)
	function self._manuallyMove()
		return self:UpdateFleetInfo(formationCtrl)
	end
end

--- 取消编队控制
function MoveComponent.CancelFormationCtrl(self)
	self._manuallyMove = nil
end

--- 设置舰队运动VO
--- @param motionVO table: 运动视图对象
function MoveComponent.SetMotionVO(self, motionVO)
	self._fleetMotionVO = motionVO
end

--- 更新舰队位置信息（编队控制模式下）
--- @param formationDir Vector3: 编队方向向量
--- @return Vector3: 更新后的速度
function MoveComponent.UpdateFleetInfo(self, formationDir)
	local motionVO = self._fleetMotionVO
	local motionSpeed = motionVO:GetSpeed()

	if formationDir:EqualZero() then
		return motionSpeed
	end

	local motionPos = motionVO:GetPos()

	return (motionVO:GetDirAngle() * formationDir):Add(motionPos):Sub(self._pos):Div(25):Add(motionSpeed)
end

--- 施加附加力到速度上
--- @param speed Vector3: 基础速度
--- @return Vector3: 施加附加力后的速度
function MoveComponent.AdditiveForce(self, speed)
	speed.x = speed.x + self._additiveSpeed.x
	speed.z = speed.z + self._additiveSpeed.z

	return speed
end

--- 更新附加速度
--- @param additiveSpeed Vector3: 新的附加速度
function MoveComponent.UpdateAdditiveSpeed(self, additiveSpeed)
	self._additiveSpeed = additiveSpeed
end

--- 移除附加速度
function MoveComponent.RemoveAdditiveSpeed(self)
	self._additiveSpeed = Vector3.zero
end

--- 设置是否不可阻挡
--- @param unstoppable boolean: 是否不可阻挡
function MoveComponent.ActiveUnstoppable(self, unstoppable)
	self._unstoppable = unstoppable
end
