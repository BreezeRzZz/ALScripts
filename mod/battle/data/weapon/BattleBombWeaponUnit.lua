ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleBombWeaponUnit = class("BattleBombWeaponUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleBombWeaponUnit = BattleBombWeaponUnit
BattleBombWeaponUnit.__name = "BattleBombWeaponUnit"

--- 构造函数：初始化预警缓存
function BattleBombWeaponUnit.Ctor(self)
	BattleBombWeaponUnit.super.Ctor(self)

	self._alertCache = {}
	self._cacheList = {}
end

--- 清理：移除预警计时器，销毁缓存发射器
function BattleBombWeaponUnit.Clear(self)
	if self._alertTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._alertTimer)
	end

	self._alertTimer = nil

	for _, emitter in pairs(self._cacheList) do
		emitter:Destroy()
	end

	BattleBombWeaponUnit._cacheList = nil

	BattleBombWeaponUnit.super.Clear(self)
end

--- 宿主瞄准敌人时：有alertTime则先显示预警再开火
function BattleBombWeaponUnit.HostOnEnemy(self)
	BattleBombWeaponUnit.super.HostOnEnemy(self)
	-- 如果有alertTime，则会等待alertTime(这段时间先显示预警特效)后再真正开火
	if self._preCastInfo.alertTime ~= nil then
		self._showPrecastAlert = true

		local function onAlertTimerEnds()
			self._alertTimer:Stop()
			self:Fire()
		end

		self._alertTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", -1, self._preCastInfo.alertTime or 3, onAlertTimerEnds, true, true)
	end
end

--- 每帧更新：装填进度 + 追踪目标 + 发射逻辑
--- @param timeStamp number: 时间戳
function BattleBombWeaponUnit.Update(self, timeStamp)
	self:UpdateReload()

	if self._currentState == self.STATE_READY then
		self:updateMovementInfo()

		local target = self:Tracking()

		if target then
			if self._showPrecastAlert then
				self:PreCast(target)
			-- 如果没有alert信息，就直接到准备实际开火的状态(跟普通武器一样)
			else
				self._currentState = self.STATE_PRECAST_FINISH
			end
		end
	end

	if self._currentState == self.STATE_PRECAST_FINISH then
		self:updateMovementInfo()

		local target = self:Tracking()
		local direction = self:GetDirection()
		local attackAngle = self:GetAttackAngle()

		for _, emitter in ipairs(self._majorEmitterList) do
			emitter:Ready()
		end

		for _, emitter in ipairs(self._majorEmitterList) do
			emitter:Fire(target, direction, attackAngle)
		end

		BattleBombWeaponUnit.super.Fire(self, target)
	end
end

--- 预警阶段：缓存子弹ID，发射后启动预警计时器
--- @param target BattleUnit: 目标
function BattleBombWeaponUnit.PreCast(self, target)
	self:cacheBulletID()

	for _, emitter in ipairs(self._majorEmitterList) do
		emitter:Ready()
	end

	for _, emitter in ipairs(self._majorEmitterList) do
		emitter:Fire(target, self:GetDirection(), self:GetAttackAngle())
	end

	BattleBombWeaponUnit.super.PreCast(self)
	self._alertTimer:Start()
end

--- 添加预警计时器
function BattleBombWeaponUnit.AddPreCastTimer(self)
	local function onPrecastTimerEnds()
		self._currentState = self.STATE_OVER_HEAT

		self:RemovePrecastTimer()

		local precastInfo = self._preCastInfo
		local precastEvent = ys.Event.New(ys.Battle.BattleUnitEvent.WEAPON_PRE_CAST_FINISH, precastInfo)

		self._host:SetWeaponPreCastBound(false)
		self:DispatchEvent(precastEvent)
	end

	self._precastTimer = pg.TimeMgr.GetInstance():AddBattleTimer("weaponPrecastTimer", 0, self._preCastInfo.time, onPrecastTimerEnds, true)
end

--- 创建主发射器（重载父类）：使用缓存发射器实现延迟发射
--- @param barrageID number: 弹幕ID
--- @param index number: 发射器索引
--- @param emitter any: 未使用（nil）
--- @param paramSpawnFunc function: 未使用
--- @param paramStopFunc function: 未使用
function BattleBombWeaponUnit.createMajorEmitter(self, barrageID, index, emitter, paramSpawnFunc, paramStopFunc)
	local cachedBulletList = {}
	local cachedEmitter

	local function cachedSpawnFunc()
		self:DispatchBulletEvent(table.remove(cachedBulletList, 1))
	end

	local cachedStopFunc

	local function cachedStopFunc()
		for _, cachedEmitter in ipairs(self._cacheList) do
			if cachedEmitter:GetState() ~= cachedEmitter.STATE_STOP then
				return
			end
		end

		self:EnterCoolDown()
	end

	cachedEmitter = ys.Battle.BattleBulletEmitter.New(cachedSpawnFunc, cachedStopFunc, barrageID)

	self._cacheList[cachedEmitter] = cachedEmitter

	local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority, target)
		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, target)

		bullet:SetOffsetPriority(isOffsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)

		if self._tmpData.aim_type == ys.Battle.BattleConst.WeaponAimType.AIM and target ~= nil then
			bullet:SetRotateInfo(target:GetBeenAimedPosition(), self:GetBaseAngle(), barrageAngle)
		else
			bullet:SetRotateInfo(nil, self:GetBaseAngle(), barrageAngle)
		end

		table.insert(cachedBulletList, bullet)
		self:showBombAlert(bullet)
	end

	local function stopFunc()
		return
	end

	BattleBombWeaponUnit.super.createMajorEmitter(self, barrageID, index, nil, spawnFunc, stopFunc)
end

--- 执行攻击：触发Buff并发射所有缓存子弹
function BattleBombWeaponUnit.DoAttack(self)
	self:TriggerBuffOnSteday()

	for _, emitter in pairs(self._cacheList) do
		emitter:Ready()
	end

	for _, emitter in pairs(self._cacheList) do
		emitter:Fire(nil, self:GetDirection())
	end

	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)
	self:TriggerBuffOnFire()
	self:CheckAndShake()
end

--- 显示炸弹预警特效
--- @param bullet BattleBulletUnit: 子弹
function BattleBombWeaponUnit.showBombAlert(self, bullet)
	bullet:SetExist(false)

	if bullet:GetTemplate().alert_fx ~= "" then
		ys.Battle.BattleBombBulletFactory.CreateBulletAlert(bullet)
	end
end
