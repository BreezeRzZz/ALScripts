ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattlePatternFunnelUnit = class("BattlePatternFunnelUnit", ys.Battle.BattleAircraftUnit)
ys.Battle.BattlePatternFunnelUnit.__name = "BattlePatternFunnelUnit"

local BattlePatternFunnelUnit = ys.Battle.BattlePatternFunnelUnit

BattlePatternFunnelUnit.STOP_STATE = "STOP_STATE"
BattlePatternFunnelUnit.MOVE_STATE = "MOVE_STATE"
BattlePatternFunnelUnit.CRASH_STATE = "CRASH_STATE"

--- @class BattlePatternFunnelUnit
--- @param UID number: 单位唯一ID
--- @return nil
--- 构造函数：设置方向为左、类型为FUNNEL_UNIT，创建MoveComponent
function BattlePatternFunnelUnit.Ctor(self, UID)
	BattlePatternFunnelUnit.super.Ctor(self, UID)

	self._untDir = ys.Battle.BattleConst.UnitDir.LEFT
	self._type = ys.Battle.BattleConst.UnitType.FUNNEL_UNIT
	self._move = ys.Battle.MoveComponent.New()
end

--- @class BattlePatternFunnelUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 图案浮游炮的Update函数：更新巡逻、武器和位置
function BattlePatternFunnelUnit.Update(self, timeStamp)
	self:updatePatrol(timeStamp)
	self:UpdateWeapon()
	self:updatePosition()
end

--- @class BattlePatternFunnelUnit
--- @return nil
--- 当母单位死亡时调用：自身进入死亡状态
function BattlePatternFunnelUnit.OnMotherDead(self)
	self:onDead()
end

--- @class BattlePatternFunnelUnit
--- @return nil
--- 检查浮游炮是否超过存在时间，超过则进入CRASH状态
function BattlePatternFunnelUnit.updateExist(self)
	if not self._existStartTime then
		return
	end

	if self._existStartTime + self._existDuration < pg.TimeMgr.GetInstance():GetCombatTime() then
		self:changePartolState(BattlePatternFunnelUnit.CRASH_STATE)
	end
end

--- @class BattlePatternFunnelUnit
--- @return nil
--- 更新所有武器
function BattlePatternFunnelUnit.UpdateWeapon(self)
	for _, weapon in ipairs(self:GetWeapon()) do
		weapon:Update()
	end
end

--- @class BattlePatternFunnelUnit
--- @param mother BattleUnit: 母单位
--- @return nil
--- 设置母单位后，根据敌对IFF获取活动边界
function BattlePatternFunnelUnit.SetMotherUnit(self, mother)
	BattlePatternFunnelUnit.super.SetMotherUnit(self, mother)

	local hostileIFF = self:GetIFF() * -1

	self._upperBound, self._lowerBound, self._leftBound, self._rightBound = ys.Battle.BattleDataProxy.GetInstance():GetFleetBoundByIFF(hostileIFF)
end

--- @class BattlePatternFunnelUnit
--- @param tmpData table: 模板数据(aircraft_template)
--- @return nil
--- 设置模板数据：读取浮游炮存在时间
function BattlePatternFunnelUnit.SetTemplate(self, tmpData)
	BattlePatternFunnelUnit.super.SetTemplate(self, tmpData)

	self._existDuration = tmpData.funnel_behavior.exist
end

--- @class BattlePatternFunnelUnit
--- @param state string: 目标巡逻状态
--- @return nil
--- 切换巡逻状态：仅处理MOVE_STATE的切换
function BattlePatternFunnelUnit.changePartolState(self, state)
	if state == BattlePatternFunnelUnit.MOVE_STATE then
		self:changeToMoveState()
	end

	self._portalState = state
end

--- @class BattlePatternFunnelUnit
--- @param direction Vector3: 创建时的飞行方向
--- @param delay number: 创建后延迟巡逻时间(此处固定0.5)
--- @return nil
--- 添加创建计时器：初始以30速度飞出，0.5秒后进入MOVE巡逻状态
function BattlePatternFunnelUnit.AddCreateTimer(self, direction, delay)
	self._currentState = self.STATE_CREATE
	self._speedDir = direction
	self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(30)

	local function onTimerEnds()
		self._existStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
		self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(self._tmpData.speed)

		self:changePartolState(BattlePatternFunnelUnit.MOVE_STATE)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._createTimer)

		self._createTimer = nil
	end

	self.updatePatrol = self._updateCreate
	self._createTimer = pg.TimeMgr.GetInstance():AddBattleTimer("AddCreateTimer", 0, 0.5, onTimerEnds)
end

--- @class BattlePatternFunnelUnit
--- @return nil
--- 位置更新：当前位置 += 当前速度
function BattlePatternFunnelUnit.updatePosition(self)
	self._pos = self._pos + self._speed
end

--- @class BattlePatternFunnelUnit
--- @return nil
--- 创建阶段的更新：更新速度和位置
function BattlePatternFunnelUnit._updateCreate(self)
	self:UpdateSpeed()
	self:updatePosition()
end

--- @class BattlePatternFunnelUnit
--- @return nil
--- 切换到移动状态：根据funnel_behavior.AI创建AutoPilot并关联motherUnit作为HiveUnit
function BattlePatternFunnelUnit.changeToMoveState(self)
	self._currentState = BattlePatternFunnelUnit.MOVE_STATE

	-- 从模板获取AI数据，创建AutoPilot
	local aiTmpData = BattleDataFunction.GetAITmpDataFromID(self._tmpData.funnel_behavior.AI)
	local autoPilotAI = ys.Battle.AutoPilot.New(self, aiTmpData)

	self._move:ImmuneMaxAreaLimit(true)
	self._move:CancelFormationCtrl()

	self._autoPilotAI = autoPilotAI

	self._autoPilotAI:SetHiveUnit(self._motherUnit)

	self.updatePatrol = self._updateMove
end

--- @class BattlePatternFunnelUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 移动状态的每帧更新：由MoveComponent和AutoPilot控制移动，乘以速度比
function BattlePatternFunnelUnit._updateMove(self, timeStamp)
	self._move:Update()
	self._speed:Copy(self._move:GetSpeed())
	self._speed:Mul(self._velocity * self:GetSpeedRatio())
	self:updatePosition()
end
