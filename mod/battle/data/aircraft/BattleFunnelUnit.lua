ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleFunnelUnit = class("BattleFunnelUnit", ys.Battle.BattleAircraftUnit)
ys.Battle.BattleFunnelUnit.__name = "BattleFunnelUnit"

local BattleFunnelUnit = ys.Battle.BattleFunnelUnit

BattleFunnelUnit.STOP_STATE = "STOP_STATE"
BattleFunnelUnit.MOVE_STATE = "MOVE_STATE"
BattleFunnelUnit.CRASH_STATE = "CRASH_STATE"

--- @class BattleFunnelUnit
--- @param UID number: 单位唯一ID
--- @return nil
--- 构造函数：设置单位方向为左、类型为FUNNEL_UNIT
function BattleFunnelUnit.Ctor(self, UID)
	BattleFunnelUnit.super.Ctor(self, UID)

	self._dir = ys.Battle.BattleConst.UnitDir.LEFT
	self._type = ys.Battle.BattleConst.UnitType.FUNNEL_UNIT
end

--- @class BattleFunnelUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 浮游炮的Update函数：检查存在时间和巡逻状态
function BattleFunnelUnit.Update(self, timeStamp)
	self:updateExist()
	self:updatePatrol(timeStamp)
end

--- @class BattleFunnelUnit
--- @return nil
--- 检查浮游炮是否超过存在时间，超过则进入CRASH(坠毁)状态
function BattleFunnelUnit.updateExist(self)
	if not self._existStartTime then
		return
	end

	if self._existStartTime + self._existDuration < pg.TimeMgr.GetInstance():GetCombatTime() then
		self:changePartolState(BattleFunnelUnit.CRASH_STATE)
	end
end

--- @class BattleFunnelUnit
--- @return nil
--- 更新所有武器
function BattleFunnelUnit.UpdateWeapon(self)
	for _, weapon in ipairs(self:GetWeapon()) do
		weapon:Update()
	end
end

--- @class BattleFunnelUnit
--- @param mother BattleUnit: 母单位
--- @return nil
--- 设置母单位后，根据敌对IFF获取活动边界
function BattleFunnelUnit.SetMotherUnit(self, mother)
	BattleFunnelUnit.super.SetMotherUnit(self, mother)

	local hostileIFF = self:GetIFF() * -1

	self._upperBound, self._lowerBound, self._leftBound, self._rightBound = ys.Battle.BattleDataProxy.GetInstance():GetFleetBoundByIFF(hostileIFF)
end

--- @class BattleFunnelUnit
--- @param tmpData table: 模板数据(aircraft_template)
--- @return nil
--- 设置模板数据：读取浮游炮行为参数(exist/stay/front/rear)，调整活动边界
function BattleFunnelUnit.SetTemplate(self, tmpData)
	BattleFunnelUnit.super.SetTemplate(self, tmpData)

	self._existDuration = tmpData.funnel_behavior.exist
	self._stayDuration = tmpData.funnel_behavior.stay
	self._frontOffset = tmpData.funnel_behavior.front or 0
	self._rearOffset = tmpData.funnel_behavior.rear or 0

	-- 根据是否有武器选择stopState的处理函数
	if self:GetWeapon()[1] then
		self.changeToStopState = BattleFunnelUnit.stopState
	else
		self.changeToStopState = BattleFunnelUnit.nonWeaponStopState
	end

	-- 根据IFF调整活动区域的左右边界(front/rear偏移)
	if self:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self._leftBound = self._leftBound + self._rearOffset
		self._rightBound = self._rightBound + self._frontOffset
	else
		self._leftBound = self._leftBound - self._frontOffset
		self._rightBound = self._rightBound - self._rearOffset
	end
end

--- @class BattleFunnelUnit
--- @param state string: 目标巡逻状态(MOVE_STATE/STOP_STATE/CRASH_STATE)
--- @return nil
--- 切换巡逻状态
function BattleFunnelUnit.changePartolState(self, state)
	if state == BattleFunnelUnit.MOVE_STATE then
		self:changeToMoveState()
	elseif state == BattleFunnelUnit.STOP_STATE then
		self:changeToStopState()
	elseif state == BattleFunnelUnit.CRASH_STATE then
		self:changeToCrashState()
	end

	self._portalState = state
end

--- @class BattleFunnelUnit
--- @param direction Vector3: 创建时的飞行方向
--- @param delay number: 创建后延迟进入巡逻的时间(默认1.5)
--- @return nil
--- 添加创建计时器：初始以20速度飞出，delay秒后进入MOVE巡逻状态
function BattleFunnelUnit.AddCreateTimer(self, direction, delay)
	self._currentState = self.STATE_CREATE
	self._speedDir = direction
	self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(20)
	delay = delay or 1.5

	local function onTimerEnds()
		self._existStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
		self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(self._tmpData.speed)

		self:changePartolState(BattleFunnelUnit.MOVE_STATE)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._createTimer)

		self._createTimer = nil
	end

	self.updatePatrol = self._updateCreate
	self._createTimer = pg.TimeMgr.GetInstance():AddBattleTimer("AddCreateTimer", 0, delay, onTimerEnds)
end

--- @class BattleFunnelUnit
--- @return nil
--- 位置更新：当前位置 += 当前速度
function BattleFunnelUnit.updatePosition(self)
	self._pos = self._pos + self._speed
end

--- @class BattleFunnelUnit
--- @return nil
--- 创建阶段的更新：更新速度和位置
function BattleFunnelUnit._updateCreate(self)
	self:UpdateSpeed()
	self:updatePosition()
end

--- @class BattleFunnelUnit
--- @return nil
--- 无武器时的停止状态：记录停止开始时间，切换到停止更新
function BattleFunnelUnit.nonWeaponStopState(self)
	self._stopStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self.updatePatrol = self._updateStop
end

--- @class BattleFunnelUnit
--- @return nil
--- 有武器时的停止状态：寻找最近敌对目标，若目标在射程外则切换为移动状态
function BattleFunnelUnit.stopState(self)
	self._stopStartTime = pg.TimeMgr.GetInstance():GetCombatTime()

	local target = BattleTargetChoise.TargetHarmNearest(self)[1]
	local weapon = self:GetWeapon()[1]

	weapon:updateMovementInfo()

	if target == nil then
		self:changePartolState(BattleFunnelUnit.CRASH_STATE)
	elseif weapon:IsOutOfFireArea(target) then
		self:changePartolState(BattleFunnelUnit.MOVE_STATE)
	else
		self.updatePatrol = self._updateStop
	end
end

--- @class BattleFunnelUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 停止状态的每帧更新：若停止时间已到则切换为移动状态，否则更新武器
function BattleFunnelUnit._updateStop(self, timeStamp)
	if self:getStopDuration() < pg.TimeMgr.GetInstance():GetCombatTime() then
		self:changePartolState(BattleFunnelUnit.MOVE_STATE)
	else
		self:UpdateWeapon()
	end
end

--- @class BattleFunnelUnit
--- @return number: 停止状态的结束时间戳
--- 获取停止状态的结束时间点
function BattleFunnelUnit.getStopDuration(self)
	return self._stopStartTime + self._stayDuration
end

--- @class BattleFunnelUnit
--- @return nil
--- 切换到移动状态：生成随机移动目标点
function BattleFunnelUnit.changeToMoveState(self)
	self:generateMoveTargetPoint()

	self.updatePatrol = self._updateMove
end

--- @class BattleFunnelUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 移动状态的每帧更新：按方向乘以速度比移动，到达目标点(距离<1)则切换为停止状态
function BattleFunnelUnit._updateMove(self, timeStamp)
	self._speed = self._direction * self:GetSpeedRatio()

	self:updatePosition()

	if Vector3.Distance(self:GetPosition(), self._moveTargetPosition) < 1 then
		self:changePartolState(BattleFunnelUnit.STOP_STATE)
	end
end

--- @class BattleFunnelUnit
--- @return nil
--- 生成随机移动目标点：在活动范围内随机选择X和Z坐标
function BattleFunnelUnit.generateMoveTargetPoint(self)
	local targetX = math.random(self._leftBound, self._rightBound)
	local targetZ = math.random(self._upperBound, self._lowerBound)

	self._moveTargetPosition = Vector3(targetX, self:GetPosition().y, targetZ)

	-- 计算目标方向的单位向量并乘以速度得到方向速度
	local direction = (self._moveTargetPosition - self._pos).normalized

	direction.y = 0

	direction:Mul(self._velocity)

	self._direction = direction
end

--- @class BattleFunnelUnit
--- @return nil
--- 切换到坠毁状态：清除存在起始时间，根据IFF设定飞出方向(左/右)
function BattleFunnelUnit.changeToCrashState(self)
	self._existStartTime = nil

	if self:GetIFF() == BattleConfig.FOE_CODE then
		self._speedDir = Vector3.left
	elseif self:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self._speedDir = Vector3.right
	end

	self.updatePatrol = self._updateCrash
end

--- @class BattleFunnelUnit
--- @return nil
--- 坠毁状态的每帧更新：更新速度和位置(飞出屏幕)
function BattleFunnelUnit._updateCrash(self)
	self:UpdateSpeed()
	self:updatePosition()
end
