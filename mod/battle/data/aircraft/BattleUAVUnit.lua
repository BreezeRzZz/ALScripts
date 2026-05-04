ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattelUAVUnit = class("BattelUAVUnit", ys.Battle.BattleAircraftUnit)
ys.Battle.BattelUAVUnit.__name = "BattelUAVUnit"

local BattelUAVUnit = ys.Battle.BattelUAVUnit

BattelUAVUnit.MOVE_STATE = "MOVE_STATE"
BattelUAVUnit.HOVER_STATE = "HOVER_STATE"

--- @class BattelUAVUnit
--- @param UID number: 单位唯一ID
--- @return nil
--- 构造函数：设置方向为左、类型为UAV_UNIT
function BattelUAVUnit.Ctor(self, UID)
	BattelUAVUnit.super.Ctor(self, UID)

	self._dir = ys.Battle.BattleConst.UnitDir.LEFT
	self._type = ys.Battle.BattleConst.UnitType.UAV_UNIT
end

--- @class BattelUAVUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- UAV的Update函数：更新巡逻状态
function BattelUAVUnit.Update(self, timeStamp)
	self:updatePatrol(timeStamp)
end

--- @class BattelUAVUnit
--- @param tmpData table: 模板数据(aircraft_template)
--- @return nil
--- 设置模板数据：计算悬停中心点和范围
function BattelUAVUnit.SetTemplate(self, tmpData)
	BattelUAVUnit.super.SetTemplate(self, tmpData)

	-- offsetX乘以IFF以适配阵营方向
	local offsetX = tmpData.funnel_behavior.offsetX * self:GetIFF()
	local offsetZ = tmpData.funnel_behavior.offsetZ
	local bornPos = ys.Battle.BattleDataProxy.GetInstance():GetVanguardBornCoordinate(self:GetIFF())

	self._centerPos = BuildVector3(bornPos) + Vector3(offsetX, 0, offsetZ)
	self._range = tmpData.funnel_behavior.hover_range
end

--- @class BattelUAVUnit
--- @param state string: 目标巡逻状态(MOVE_STATE/HOVER_STATE)
--- @return nil
--- 切换巡逻状态
function BattelUAVUnit.changePartolState(self, state)
	if state == BattelUAVUnit.MOVE_STATE then
		self:changeToMoveState()
	elseif state == BattelUAVUnit.HOVER_STATE then
		self:changeToHoverState()
	end

	self._portalState = state
end

--- @class BattelUAVUnit
--- @param direction Vector3: 创建时的飞行方向
--- @param delay number: 创建后延迟巡逻时间(默认1.5)
--- @return nil
--- 添加创建计时器：初始以20速度飞出，delay秒后进入MOVE巡逻状态
function BattelUAVUnit.AddCreateTimer(self, direction, delay)
	self._currentState = self.STATE_CREATE
	self._speedDir = direction
	self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(20)
	delay = delay or 1.5

	local function onTimerEnds()
		self._existStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
		self._velocity = ys.Battle.BattleFormulas.ConvertAircraftSpeed(self._tmpData.speed)

		self:changePartolState(BattelUAVUnit.MOVE_STATE)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._createTimer)

		self._createTimer = nil
	end

	self.updatePatrol = self._updateCreate
	self._createTimer = pg.TimeMgr.GetInstance():AddBattleTimer("AddCreateTimer", 0, delay, onTimerEnds)
end

--- @class BattelUAVUnit
--- @return nil
--- 创建阶段的更新：更新速度和位置
function BattelUAVUnit._updateCreate(self)
	self:UpdateSpeed()

	self._pos = self._pos + self._speed
end

--- @class BattelUAVUnit
--- @return nil
--- 切换到移动状态：设置巡航目标X为_centerPos.x
function BattelUAVUnit.changeToMoveState(self)
	self._cruiseLimit = self._centerPos.x
	self.updatePatrol = self._updateMove
end

--- @class BattelUAVUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 移动状态的每帧更新：更新速度后向巡航目标移动，到达则进入悬停状态
function BattelUAVUnit._updateMove(self, timeStamp)
	self:UpdateSpeed()

	self._pos = self._pos + self._speed

	-- 判断是否到达巡航目标X位置(友方往右飞、敌方往左飞)
	if self._IFF == BattleConfig.FRIENDLY_CODE then
		if self._pos.x > self._cruiseLimit then
			self:changePartolState(BattelUAVUnit.HOVER_STATE)
		end
	elseif self._IFF == BattleConfig.FOE_CODE and self._pos.x < self._cruiseLimit then
		self:changePartolState(BattelUAVUnit.HOVER_STATE)
	end
end

--- @class BattelUAVUnit
--- @return nil
--- 切换到悬停状态：记录悬停开始时间
function BattelUAVUnit.changeToHoverState(self)
	self._hoverStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self.updatePatrol = self._updateHover
end

--- @class BattelUAVUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 悬停状态的每帧更新：沿圆形轨迹绕_centerPos旋转(高度固定15)
function BattelUAVUnit._updateHover(self, timeStamp)
	local elapsed = timeStamp - self._hoverStartTime

	self._pos = Vector3(math.sin(elapsed) * self._range, 15, math.cos(elapsed) * self._range):Add(self._centerPos)
end

--- @class BattelUAVUnit
--- @return number: 当前的视觉缩放值
--- 获取UAV的显示大小：悬停状态下根据cos值动态变化(实现呼吸效果)
function BattelUAVUnit.GetSize(self)
	if self._portalState == BattelUAVUnit.HOVER_STATE then
		local hoverDuration = pg.TimeMgr.GetInstance():GetCombatTime() - self._hoverStartTime
		local scaleMultiplier = math.cos(hoverDuration)

		-- cos值接近0时锁定在正负0.2(避免完全不可见)
		if scaleMultiplier > 0 and scaleMultiplier < 0.2 then
			scaleMultiplier = 0.2
		elseif scaleMultiplier <= 0 and scaleMultiplier > -0.2 then
			scaleMultiplier = -0.2
		end

		return scaleMultiplier
	else
		BattelUAVUnit.super.GetSize(self)
	end
end
