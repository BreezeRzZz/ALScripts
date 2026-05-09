ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleAirFighterUnit = class("BattleAirFighterUnit", ys.Battle.BattleAircraftUnit)
ys.Battle.BattleAirFighterUnit.__name = "BattleAirFighterUnit"

local BattleAirFighterUnit = ys.Battle.BattleAirFighterUnit

BattleAirFighterUnit.AIRFIGHTER_ENTER_POINT = Vector3(Screen.width * -0.5, Screen.height * 0.5, 15)
BattleAirFighterUnit.SPEED_FLY = Vector3(3, 0, 0)
BattleAirFighterUnit.BACK_X = 100
BattleAirFighterUnit.DOWN_X = 30
BattleAirFighterUnit.ATTACK_X = -23
BattleAirFighterUnit.UP_X = -70
BattleAirFighterUnit.FREE_X = -75
BattleAirFighterUnit.HEIGHT = ys.Battle.BattleConfig.AirFighterHeight
BattleAirFighterUnit.STRIKE_STATE_FLY = 0
BattleAirFighterUnit.STRIKE_STATE_BACK = 1
BattleAirFighterUnit.STRIKE_STATE_DOWN = 2
BattleAirFighterUnit.STRIKE_STATE_ATTACK = 3
BattleAirFighterUnit.STRIKE_STATE_UP = 4
BattleAirFighterUnit.STRIKE_STATE_FREE = 5
BattleAirFighterUnit.STRIKE_STATE_BACKWARD = 6
BattleAirFighterUnit.STRIKE_STATE_RECYCLE = 7

--- 构造函数：初始化方向、类型、Y轴抖动等
--- @param uid number: 单位唯一ID
function BattleAirFighterUnit.Ctor(self, uid)
	BattleAirFighterUnit.super.Ctor(self, uid)

	self._dir = ys.Battle.BattleConst.UnitDir.LEFT
	self._type = ys.Battle.BattleConst.UnitType.AIRFIGHTER_UNIT

	self:changeState(BattleAirFighterUnit.STRIKE_STATE_FLY)
	self:calcYShakeMin()
	self:calcYShakeMax()

	self._speedDir = Vector3(1, 0, 0)
	self._backwardWeaponID = {}
end

--- 每帧更新：更新速度和攻击阶段
--- @param timeStamp number: 时间戳
function BattleAirFighterUnit.Update(self, timeStamp)
	self:UpdateSpeed()
	self:updateStrike()
end

--- 更新武器：检查是否有后向武器触发后退状态
function BattleAirFighterUnit.UpdateWeapon(self)
	for index, weapon in ipairs(self:GetWeapon()) do
		local weaponID = weapon:GetWeaponId()
		local isBackwardWeapon = table.contains(self._backwardWeaponID, weaponID)
		local previousState = weapon:GetCurrentState()

		weapon:Update()

		local currentState = weapon:GetCurrentState()

		if isBackwardWeapon and previousState == weapon.STATE_READY and (currentState == weapon.STATE_ATTACK or currentState == weapon.STATE_OVER_HEAT) then
			self:changeState(BattleAirFighterUnit.STRIKE_STATE_BACKWARD)
		end
	end
end

--- 创建武器列表（包含回旋武器）
--- @return table: 武器列表
function BattleAirFighterUnit.CreateWeapon(self)
	local weaponList = {}

	if type(self._weaponTemplateID) == "table" then
		for index, weaponID in ipairs(self._weaponTemplateID) do
			weaponList[index] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(weaponID, self, index)
		end
	else
		weaponList[1] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(self._weaponTemplateID, self, 1)
	end

	if self._backwardWeaponID then
		for index, weaponID in ipairs(self._backwardWeaponID) do
			weaponList[index] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(weaponID, self, index)
		end
	end

	return weaponList
end

--- 设置武器模板ID
--- @param weaponTemplateID table|number: 武器模板ID或ID列表
function BattleAirFighterUnit.SetWeaponTemplateID(self, weaponTemplateID)
	self._weaponTemplateID = weaponTemplateID
end

--- 设置回旋武器ID
--- @param backwardWeaponID table: 回旋武器ID列表
function BattleAirFighterUnit.SetBackwardWeaponID(self, backwardWeaponID)
	self._backwardWeaponID = backwardWeaponID
end

-- 被BattleDataFunction.CreateAirFighterUnit调用
--- @param tmpData table: 模板数据
function BattleAirFighterUnit.SetTemplate(self, tmpData)
	self:SetAttr(tmpData)
	-- 注意这里调用了父类的SetTemplate(即BattleAircraftUnit.SetTemplate)
	BattleAirFighterUnit.super.SetTemplate(self, tmpData)
end

-- 被BattleAirFighterUnit.SetTemplate调用
--- @param tmpData table: 模板数据
function BattleAirFighterUnit.SetAttr(self, tmpData)
	ys.Battle.BattleAttr.SetAirFighterAttr(self, tmpData)
	self:SetIFF(-1)
end

--- 更新速度：速度 = 方向 * 速率 * 速度倍率
function BattleAirFighterUnit.UpdateSpeed(self)
	self._speed:Copy(self._speedDir)
	self._speed:Mul(self._velocity * self:GetSpeedRatio())
end

--- 自由飞行结束（未击破但离场）
function BattleAirFighterUnit.Free(self)
	self._undefeated = true

	self:LiveCallBack()

	self._aliveState = false
end

--- 回收（返回母舰）
function BattleAirFighterUnit.recycle(self)
	self:LiveCallBack()

	self._aliveState = false
end

--- 被击毁
function BattleAirFighterUnit.onDead(self)
	self._currentState = self.STATE_DESTORY

	self:DeadCallBack()

	self._aliveState = false
end

--- 获取视觉位置
--- @return Vector3: 视觉位置
function BattleAirFighterUnit.GetPosition(self)
	return self._viewPos
end

--- 设置编队索引（影响缩放和飞行间距）
--- @param formationIndex number: 编队索引
function BattleAirFighterUnit.SetFormationIndex(self, formationIndex)
	self._formationIndex = formationIndex
	self._flyStateScale = 12 / (formationIndex + 3) + 1

	self:DispatchStrikeStateChange()
end

--- 获取编队索引
--- @return number: 编队索引
function BattleAirFighterUnit.GetFormationIndex(self)
	return self._formationIndex
end

--- 设置编队偏移量
--- @param offset Vector3: 编队偏移
function BattleAirFighterUnit.SetFormationOffset(self, offset)
	self._formationOffset = Vector3(offset.x, offset.y, offset.z)
	self._formationOffsetOppo = Vector3(offset.x * -1, offset.y, offset.z)
end

--- 设置死亡回调
--- @param callback function: 死亡回调函数
function BattleAirFighterUnit.SetDeadCallBack(self, callback)
	self._deadCallBack = callback
end

--- 执行死亡回调
function BattleAirFighterUnit.DeadCallBack(self)
	self._deadCallBack()
end

--- 设置存活回调（回收/离场时调用）
--- @param callback function: 存活回调函数
function BattleAirFighterUnit.SetLiveCallBack(self, callback)
	self._liveCallBack = callback
end

--- 执行存活回调
function BattleAirFighterUnit.LiveCallBack(self)
	self._liveCallBack()
end

--- 获取Y轴抖动偏移值
--- @return number: Y轴抖动值
function BattleAirFighterUnit.getYShake(self)
	local yShakeCurrent = self._YShakeCurrent or 0

	self._YShakeDir = self._YShakeDir or 1

	local newYShake = yShakeCurrent + (0.04 * math.random() + 0.01) * self._YShakeDir

	if newYShake > self._YShakeMax then
		self._YShakeDir = -1

		self:calcYShakeMin()
	elseif newYShake < self._YShakeMin then
		self._YShakeDir = 1

		self:calcYShakeMax()
	end

	self._YShakeCurrent = newYShake

	return newYShake
end

--- 计算Y轴抖动最小值
function BattleAirFighterUnit.calcYShakeMin(self)
	self._YShakeMin = -0.5 - math.random()
end

--- 计算Y轴抖动最大值
function BattleAirFighterUnit.calcYShakeMax(self)
	self._YShakeMax = 0.5 + math.random()
end

--- 派发攻击阶段变化事件
function BattleAirFighterUnit.DispatchStrikeStateChange(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.AIR_STRIKE_STATE_CHANGE, {}))
end

--- 获取当前攻击阶段
--- @return number: 攻击阶段
function BattleAirFighterUnit.GetStrikeState(self)
	return self._strikeState
end

--- 获取模型缩放
--- @return number: 缩放值
function BattleAirFighterUnit.GetSize(self)
	return self._scale
end

--- 切换攻击阶段状态机
--- @param newState number: 新的攻击阶段
function BattleAirFighterUnit.changeState(self, newState)
	if self._strikeState == newState then
		return
	end

	self._strikeState = newState

	if newState == BattleAirFighterUnit.STRIKE_STATE_FLY then
		self:changeToFlyState()

		self.updateStrike = BattleAirFighterUnit._updatePosFly
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_BACK then
		self.updateStrike = BattleAirFighterUnit._updatePosBack

		self:changeToBackState()
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_DOWN then
		self.updateStrike = BattleAirFighterUnit._updatePosDown

		self:changeToDownState()
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_ATTACK then
		self.updateStrike = BattleAirFighterUnit._updatePosAttack

		self:changeToAttackState()
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_UP then
		self.updateStrike = BattleAirFighterUnit._updatePosUp

		self:changeToUpState()
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_BACKWARD then
		self.updateStrike = BattleAirFighterUnit._updateBackward

		self:changeToBackwardState()
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_FREE then
		self.updateStrike = BattleAirFighterUnit._updateFree
	elseif newState == BattleAirFighterUnit.STRIKE_STATE_RECYCLE then
		self.updateStrike = BattleAirFighterUnit._updateRecycle
	end

	self:DispatchStrikeStateChange()
end

--- 切换到飞行状态：设置入口位置并播放音效
function BattleAirFighterUnit.changeToFlyState(self)
	self._pos = ys.Battle.BattleCameraUtil.GetInstance():GetS2WPoint(BattleAirFighterUnit.AIRFIGHTER_ENTER_POINT)
	self._viewPos = self._pos

	ys.Battle.PlayBattleSFX("battle/plane")
end

--- 飞行阶段位置更新
function BattleAirFighterUnit._updatePosFly(self)
	self._pos:Add(BattleAirFighterUnit.SPEED_FLY)

	self._viewPos = Vector3(self._formationOffset.x * self._flyStateScale, (self._formationOffset.z / 1.7 + self:getYShake()) * self._flyStateScale, 0):Add(self._pos)

	if self._pos.x > BattleAirFighterUnit.BACK_X then
		self:changeState(BattleAirFighterUnit.STRIKE_STATE_BACK)
	end
end

--- 切换到后退阶段：计算目标Z轴位置（跟随友方舰队）
function BattleAirFighterUnit.changeToBackState(self)
	local targetZ
	local friendlyMotion = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(BattleConfig.FRIENDLY_CODE):GetMotion()

	if friendlyMotion then
		targetZ = friendlyMotion:GetPos().z
	else
		targetZ = 45
	end

	self._pos = Vector3(self._pos.x, 15, targetZ)
end

--- 后退阶段位置更新
function BattleAirFighterUnit._updatePosBack(self)
	self._pos:Sub(self._speed)
	self._viewPos:Copy(self._pos)
	self._viewPos:Sub(self._formationOffset)

	if self._pos.x < BattleAirFighterUnit.DOWN_X then
		self:changeState(BattleAirFighterUnit.STRIKE_STATE_DOWN)
	end
end

--- 切换到下降阶段：启用碰撞可见
function BattleAirFighterUnit.changeToDownState(self)
	self._ySpeed = 0.5

	self:SetVisitable()
end

--- 下降阶段位置更新
function BattleAirFighterUnit._updatePosDown(self)
	self._pos:Sub(self._speed)

	self._pos.y = math.max(BattleAirFighterUnit.HEIGHT, self._pos.y - self._ySpeed)
	self._viewPos = self._pos + self._formationOffsetOppo
	self._ySpeed = math.max(0.02, self._ySpeed - 0.005)

	if self._pos.x < BattleAirFighterUnit.ATTACK_X then
		self:changeState(BattleAirFighterUnit.STRIKE_STATE_ATTACK)
	end
end

--- 切换到攻击阶段：播放攻击音效
function BattleAirFighterUnit.changeToAttackState(self)
	ys.Battle.PlayBattleSFX("battle/air-atk")
end

--- 攻击阶段位置更新：更新武器并添加Y轴抖动
function BattleAirFighterUnit._updatePosAttack(self)
	self._pos:Sub(self._speed)

	self._pos.y = math.max(BattleAirFighterUnit.HEIGHT, self._pos.y - 0.04)

	local offsetWithShake = self._formationOffsetOppo

	offsetWithShake.y = self:getYShake()
	self._viewPos = self._pos + offsetWithShake

	self:UpdateWeapon()

	if self._pos.x < BattleAirFighterUnit.UP_X then
		self:changeState(BattleAirFighterUnit.STRIKE_STATE_UP)
	end
end

--- 切换到上升阶段：设置初始上升速度
function BattleAirFighterUnit.changeToUpState(self)
	self._ySpeed = 0.1
end

--- 上升阶段位置更新
function BattleAirFighterUnit._updatePosUp(self)
	self._pos:Sub(self._speed)

	self._pos.y = self._pos.y + self._ySpeed
	self._ySpeed = math.min(0.7, self._ySpeed + 0.02)
	self._viewPos = self._pos + self._formationOffsetOppo

	if self._pos.x < BattleAirFighterUnit.FREE_X then
		self:changeState(BattleAirFighterUnit.STRIKE_STATE_FREE)
	end
end

--- 自由飞行阶段：标记为未击破并离场
function BattleAirFighterUnit._updateFree(self)
	self:Free()
end

--- 切换到后撤阶段
function BattleAirFighterUnit.changeToBackwardState(self)
	return
end

--- 后撤阶段位置更新：向回飞行
function BattleAirFighterUnit._updateBackward(self)
	self._pos:Add(self._speed)

	self._pos.y = math.max(BattleAirFighterUnit.HEIGHT, self._pos.y - 0.04)
	self._viewPos = self._pos + self._formationOffsetOppo

	if self._pos.x > BattleAirFighterUnit.DOWN_X then
		self:changeState(BattleAirFighterUnit.STRIKE_STATE_RECYCLE)
	end
end

--- 回收阶段：调用回收逻辑
function BattleAirFighterUnit._updateRecycle(self)
	self:recycle()
end
