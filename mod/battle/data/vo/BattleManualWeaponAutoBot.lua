ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleManualWeaponAutoBot = class("BattleManualWeaponAutoBot")
ys.Battle.BattleManualWeaponAutoBot.__name = "BattleManualWeaponAutoBot"

local BattleManualWeaponAutoBot = ys.Battle.BattleManualWeaponAutoBot

-- BattleManualWeaponAutoBot: 管理的是三个手动武器VO的自动释放(对应三个按钮)
-- 在BattleControllerWeaponCommand.onUnitInitFinish中初始化
function BattleManualWeaponAutoBot.Ctor(self, fleetVO)
	ys.EventListener.AttachEventListener(self)

	self._fleetVO = fleetVO

	self:init(fleetVO)
end

-- BattleManualWeaponAutoBot初始化
-- 可以看到，该AutoBot负责三个武器VO: 跨射(charge)、鱼雷(torpedo)、空袭(air assist)
-- 直接是对应fleetVO的三个武器VO
function BattleManualWeaponAutoBot.init(self)
	self._active = false
	self._isPlayFocus = true
	self._chargeVO = self._fleetVO:GetChargeWeaponVO()
	self._torpedoVO = self._fleetVO:GetTorpedoWeaponVO()
	self._AAVO = self._fleetVO:GetAirAssistVO()
	self._totalTime = 0
	self._lastActiveTimeStamp = nil
end

-- 自动武器的更新逻辑
-- 简单来说就是每个AI帧，都尝试立刻释放这三种武器
-- 被BattleControllerWeaponCommand.Update调用
function BattleManualWeaponAutoBot.Update(self)
	if self._active then
		if not self._torpedoVO:IsOverLoad() and self._fleetVO:QuickCastTorpedo() then
			return
		end

		if not self._AAVO:IsOverLoad() and self._fleetVO:UnleashAllInStrike() then
			return
		end

		if not self._chargeVO:IsOverLoad() and self._fleetVO:QuickTagChrageWeapon(self._isPlayFocus) then
			return
		end
	end
end

function BattleManualWeaponAutoBot.IsActive(self)
	return self._active
end

-- 触发自动/手动状态切换
-- 被BattleControllerWeaponCommand.ActiveBot调用
function BattleManualWeaponAutoBot.SetActive(self, active, isPlayFocus)
	if self._active ~= active and active == true then
		self._lastActiveTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime()
	elseif self._active ~= active and active == false and self._lastActiveTimeStamp ~= nil then
		local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

		self._totalTime = self._totalTime + (currentTime - self._lastActiveTimeStamp)
		self._lastActiveTimeStamp = nil
	end

	self._fleetVO:AutoBotUpdated(active)

	self._active = active
	self._isPlayFocus = isPlayFocus
end

function BattleManualWeaponAutoBot.GetTotalActiveDuration(self)
	if self._lastActiveTimeStamp then
		local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

		self._totalTime = self._totalTime + (currentTime - self._lastActiveTimeStamp)
		self._lastActiveTimeStamp = nil
	end

	return self._totalTime
end

function BattleManualWeaponAutoBot.Dispose(self)
	self._chargeVO = nil
	self._torpedoVO = nil
	self._AAVO = nil
	self._dataProxy = nil
	self._uiMediator = nil

	ys.EventListener.DetachEventListener(self)
end
