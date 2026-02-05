ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleBombWeaponUnit = class("BattleBombWeaponUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleBombWeaponUnit = BattleBombWeaponUnit
BattleBombWeaponUnit.__name = "BattleBombWeaponUnit"

function BattleBombWeaponUnit.Ctor(self)
	BattleBombWeaponUnit.super.Ctor(self)

	self._alertCache = {}
	self._cacheList = {}
end

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

function BattleBombWeaponUnit.createMajorEmitter(self, barrageID, index, emitter, paramSpawnFunc, paramStopFunc)
	local cachedBulletList = {}
	local var_9_1

	local function cachedSpawnFunc()
		self:DispatchBulletEvent(table.remove(cachedBulletList, 1))
	end

	local var_9_3

	local function cachedStopFunc()
		for _, cachedEmitter in ipairs(self._cacheList) do
			if cachedEmitter:GetState() ~= cachedEmitter.STATE_STOP then
				return
			end
		end

		self:EnterCoolDown()
	end

	local cachedEmitter = ys.Battle.BattleBulletEmitter.New(cachedSpawnFunc, cachedStopFunc, barrageID)

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

function BattleBombWeaponUnit.showBombAlert(self, bullet)
	bullet:SetExist(false)

	if bullet:GetTemplate().alert_fx ~= "" then
		ys.Battle.BattleBombBulletFactory.CreateBulletAlert(bullet)
	end
end
