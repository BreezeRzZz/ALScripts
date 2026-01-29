ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleManualTorpedoUnit = class("BattleManualTorpedoUnit", ys.Battle.BattleTorpedoUnit)

ys.Battle.BattleManualTorpedoUnit = BattleManualTorpedoUnit
BattleManualTorpedoUnit.__name = "BattleManualTorpedoUnit"

function BattleManualTorpedoUnit.Ctor(self)
	BattleManualTorpedoUnit.super.Ctor(self)
end

function BattleManualTorpedoUnit.createMajorEmitter(self, barrageID, index)
	local function defaultSpawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority)
		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, nil, BattleManualTorpedoUnit.INTERNAL)

		bullet:SetOffsetPriority(isOffsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)
		bullet:SetRotateInfo(nil, self._botAutoAimAngle, barrageAngle)
		self:DispatchBulletEvent(bullet)

		return bullet
	end

	local function defaultStopFunc()
		return
	end

	BattleManualTorpedoUnit.super.createMajorEmitter(self, barrageID, index, nil, defaultSpawnFunc, defaultStopFunc)
end

function BattleManualTorpedoUnit.Update(self)
	self:UpdateReload()
end

function BattleManualTorpedoUnit.SetPlayerTorpedoWeaponVO(self, playerTorpedoWeaponVO)
	self._playerTorpedoVO = playerTorpedoWeaponVO
end

function BattleManualTorpedoUnit.TriggerBuffOnReady(self)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_MANUAL_TORPEDO_READY, {})
end

function BattleManualTorpedoUnit.Fire(self, target)
	if target then
		self:updateMovementInfo()
		-- 这里又选了一次目标, 用于计算自动瞄准角度
		-- 索敌方式：权重优先随机(优先权重，同权重再随机)
		local _target = ys.Battle.BattleTargetChoise.TargetHarmRandomByWeight(self._host, nil, self:GetFilteredList())[1]

		if _target then
			local targetPos = _target:GetPosition()
			local hostPos = self._host:GetPosition()

			self._botAutoAimAngle = math.rad2Deg * math.atan2(targetPos.z - hostPos.z, targetPos.x - hostPos.x)
		else
			self._botAutoAimAngle = self:GetBaseAngle()
		end
	else
		self._botAutoAimAngle = self:GetBaseAngle()
	end

	return BattleManualTorpedoUnit.super.Fire(self)
end

function BattleManualTorpedoUnit.DoAttack(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.TORPEDO_WEAPON_FIRE, {}))
	BattleManualTorpedoUnit.super.DoAttack(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_FIRE, {}))
end

function BattleManualTorpedoUnit.InitialCD(self)
	BattleManualTorpedoUnit.super.InitialCD(self)
	self._playerTorpedoVO:InitialDeduct(self)
	self._playerTorpedoVO:Charge(self)
end

function BattleManualTorpedoUnit.EnterCoolDown(self)
	BattleManualTorpedoUnit.super.EnterCoolDown(self)
	self._playerTorpedoVO:Charge(self)
end

function BattleManualTorpedoUnit.OverHeat(self)
	BattleManualTorpedoUnit.super.OverHeat(self)
	self._playerTorpedoVO:Deduct(self)
end

function BattleManualTorpedoUnit.Cease(self)
	if self._currentState == BattleManualTorpedoUnit.STATE_OVER_HEAT then
		self:interruptAllEmitter()
	end
end

function BattleManualTorpedoUnit.handleCoolDown(self)
	self._currentState = self.STATE_READY

	self._playerTorpedoVO:Plus(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.TORPEDO_WEAPON_READY, {}))
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_READY, {}))
	self:TriggerBuffOnReady()

	self._CDstartTime = nil
	self._reloadBoostList = {}
end

function BattleManualTorpedoUnit.FlushReloadMax(self, reloadMax)
	if BattleManualTorpedoUnit.super.FlushReloadMax(self, reloadMax) then
		return true
	end

	self._playerTorpedoVO:RefreshReloadingBar()
end

function BattleManualTorpedoUnit.FlushReloadRequire(self)
	if BattleManualTorpedoUnit.super.FlushReloadRequire(self) then
		return true
	end

	self._playerTorpedoVO:RefreshReloadingBar()
end

function BattleManualTorpedoUnit.QuickCoolDown(self)
	if self._currentState == self.STATE_OVER_HEAT then
		self._currentState = self.STATE_READY

		self._playerTorpedoVO:InstantCoolDown(self)
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, {}))

		self._CDstartTime = nil
		self._reloadBoostList = {}
	end
end

function BattleManualTorpedoUnit.Prepar(self)
	if self._host:IsCease() then
		return false
	else
		self._currentState = self.STATE_PRECAST

		local prepareArgs = {}
		local prepareEvent = ys.Event.New(BattleUnitEvent.TORPEDO_WEAPON_PREPAR, prepareArgs)

		self:DispatchEvent(prepareEvent)

		return true
	end
end

function BattleManualTorpedoUnit.Cancel(self)
	self._currentState = self.STATE_READY

	local cancelEvent = ys.Event.New(BattleUnitEvent.TORPEDO_WEAPON_CANCEL, {})

	self:DispatchEvent(cancelEvent)
end

function BattleManualTorpedoUnit.ReloadBoost(self, extraReloadBoost)
	local totalBoost = 0

	for _, reloadBoost in ipairs(self._reloadBoostList) do
		totalBoost = totalBoost + reloadBoost
	end
	-- 有点看不懂，之后再看，标记一下
	local finalBoost = totalBoost + extraReloadBoost
	local elapsedTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._jammingTime - self._CDstartTime
	local actualBoost

	if finalBoost < 0 then
		actualBoost = math.max(finalBoost, (self._reloadRequire - elapsedTime) * -1)
	else
		actualBoost = math.min(finalBoost, elapsedTime)
	end

	fixValue = actualBoost - finalBoost + extraReloadBoost

	table.insert(self._reloadBoostList, fixValue)
end

function BattleManualTorpedoUnit.AppendReloadBoost(self, extraReloadBoost)
	if self._currentState == self.STATE_OVER_HEAT then
		self._playerTorpedoVO:ReloadBoost(self, extraReloadBoost)
	end
end
