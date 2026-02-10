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

function MoveComponent.Ctor(self)
	return
end

function MoveComponent.GetPos(self)
	return self._pos
end

function MoveComponent.SetPos(self, pos)
	self._pos = pos
end

function MoveComponent.Update(self)
	self._speed = self:GetFinalSpeed()
end

function MoveComponent.FixSpeed(self, cldComponent)
	assert(cldComponent.FixSpeed ~= nil and type(cldComponent.FixSpeed) == "function", " MoveComponent.FixSpeed 速度修正出错")
	cldComponent:FixSpeed(self._speed)
end

function MoveComponent.Move(self, speedRatio)
	speedRatio = speedRatio or 1
	self._pos.x = self._pos.x + self._speed.x * speedRatio
	self._pos.y = self._pos.y + self._speed.y * speedRatio
	self._pos.z = self._pos.z + self._speed.z * speedRatio
end

function MoveComponent.GetSpeed(self)
	return self._speed
end

function MoveComponent.SetCorpsArea(self, leftCorpsBound, rightCorpsBound)
	self._leftCorpsBound = leftCorpsBound
	self._rightCorpsBound = rightCorpsBound
end

function MoveComponent.SetBorder(self, leftBorder, rightBorder, upBorder, downBorder)
	self._leftBorder = leftBorder
	self._rightBorder = rightBorder
	self._upBorder = upBorder
	self._downBorder = downBorder
end

function MoveComponent.GetFinalSpeed(self)
	local initialSpeed = self:getInitialSpeed()

	if not self._unstoppable then
		initialSpeed = self:AdditiveForce(initialSpeed)
	end

	return (self:BorderLimit(initialSpeed))
end

-- 限制舰队在阵营区域内移动
-- MoveComponent.getInitialSpeed调用
function MoveComponent.CorpsAreaLimit(self, arg_11_1)
	if self._immuneAreaLimit then
		return arg_11_1
	end

	local var_11_0 = self._pos.x
	local var_11_1 = self._corpsLimitSpeed

	if var_11_0 < self._leftCorpsBound then
		var_11_1 = math.max(var_11_1, 0.1)

		if arg_11_1.x < 0 then
			var_11_1 = math.min(10, var_11_1 * 1.04)
		end
	elseif var_11_0 > self._rightCorpsBound then
		var_11_1 = math.min(var_11_1, -0.1)

		if arg_11_1.x > 0 then
			var_11_1 = math.max(-10, var_11_1 * 1.04)
		end
	else
		var_11_1 = var_11_1 < 0.1 and var_11_1 > -0.1 and 0 or var_11_1 * 0.8
	end

	self._corpsLimitSpeed = var_11_1
	arg_11_1.x = arg_11_1.x + self._corpsLimitSpeed

	return arg_11_1
end

function MoveComponent.BorderLimit(self, arg_12_1)
	if self._immuneMaxAreaLimit then
		return arg_12_1
	end

	local var_12_0 = self._pos

	if arg_12_1.x < 0 and var_12_0.x <= self._leftBorder or arg_12_1.x > 0 and var_12_0.x >= self._rightBorder then
		arg_12_1.x = 0
	end

	if arg_12_1.z < 0 and var_12_0.z <= self._downBorder or arg_12_1.z > 0 and var_12_0.z >= self._upBorder then
		arg_12_1.z = 0
	end

	return arg_12_1
end

function MoveComponent.ImmuneAreaLimit(self, arg_13_1)
	self._immuneAreaLimit = arg_13_1
end

function MoveComponent.ImmuneMaxAreaLimit(self, arg_14_1)
	self._immuneMaxAreaLimit = arg_14_1
end

function MoveComponent.getInitialSpeed(self)
	if self._isForceMove and not self._unstoppable then
		local forceSpeed = self._forceSpeed

		self:UpdateForceMove()

		return forceSpeed
	end

	if self._moveProcess then
		return self._moveProcess()
	end

	if self._staticState then
		return Vector3.zero
	end

	if self._manuallyMove then
		return self:CorpsAreaLimit(self._manuallyMove())
	end

	assert(self._autoMoveAi ~= nil, "角色缺少默认移动的ai")

	return self._autoMoveAi()
end

function MoveComponent.SetForceMove(self, arg_16_1, arg_16_2, arg_16_3, arg_16_4, arg_16_5)
	self._isForceMove = true
	arg_16_1 = arg_16_1.normalized
	self._forceSpeed = arg_16_1 * arg_16_2
	self._forceReduce = arg_16_1 * arg_16_3
	self._forceLastTime = arg_16_4
	self._decayValve = arg_16_5 or 0
end

function MoveComponent.UpdateForceMove(self)
	local var_17_0 = self._forceLastTime

	if var_17_0 <= 0 then
		self:ClearForceMove()

		return
	end

	self._forceLastTime = var_17_0 - 1

	if var_17_0 < self._decayValve then
		self._forceSpeed:Sub(self._forceReduce)
	end
end

function MoveComponent.ClearForceMove(self)
	self._isForceMove = false
	self._forceSpeed = nil
	self._forceReduce = nil
	self._forceLastTime = nil
end

function MoveComponent.SetMoveProcess(self, arg_19_1)
	self._moveProcess = arg_19_1
end

function MoveComponent.SetStaticState(self, arg_20_1)
	self._staticState = arg_20_1
end

-- 被AutoPilot.Ctor调用
function MoveComponent.SetAutoMoveAI(self, arg_21_1, arg_21_2)
	function self._autoMoveAi()
		return arg_21_1:GetDirection():Mul(arg_21_2:GetAttrByName("velocity"))
	end
end

function MoveComponent.SetFormationCtrlInfo(self, arg_23_1)
	function self._manuallyMove()
		return self:UpdateFleetInfo(arg_23_1)
	end
end

function MoveComponent.CancelFormationCtrl(self)
	self._manuallyMove = nil
end

function MoveComponent.SetMotionVO(self, arg_26_1)
	self._fleetMotionVO = arg_26_1
end

function MoveComponent.UpdateFleetInfo(self, arg_27_1)
	local var_27_0 = self._fleetMotionVO
	local var_27_1 = var_27_0:GetSpeed()

	if arg_27_1:EqualZero() then
		return var_27_1
	end

	local var_27_2 = var_27_0:GetPos()

	return (var_27_0:GetDirAngle() * arg_27_1):Add(var_27_2):Sub(self._pos):Div(25):Add(var_27_1)
end

function MoveComponent.AdditiveForce(self, arg_28_1)
	arg_28_1.x = arg_28_1.x + self._additiveSpeed.x
	arg_28_1.z = arg_28_1.z + self._additiveSpeed.z

	return arg_28_1
end

function MoveComponent.UpdateAdditiveSpeed(self, arg_29_1)
	self._additiveSpeed = arg_29_1
end

function MoveComponent.RemoveAdditiveSpeed(self)
	self._additiveSpeed = Vector3.zero
end

function MoveComponent.ActiveUnstoppable(self, arg_31_1)
	self._unstoppable = arg_31_1
end
