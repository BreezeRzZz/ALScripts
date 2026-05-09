ys = ys or {}
-- 武器控制Command，管理自律武器Bot、摇杆Bot和相机焦点
local ys = ys
local BattleEvent = ys.Battle.BattleEvent

ys.Battle.BattleControllerWeaponCommand = class("BattleControllerWeaponCommand", ys.MVC.Command)
ys.Battle.BattleControllerWeaponCommand.__name = "BattleControllerWeaponCommand"

local BattleControllerWeaponCommand = ys.Battle.BattleControllerWeaponCommand

function BattleControllerWeaponCommand.Ctor(self)
	BattleControllerWeaponCommand.super.Ctor(self)
end

function BattleControllerWeaponCommand.Initialize(self)
	BattleControllerWeaponCommand.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)

	self:InitBattleEvent()

	self._focusBlockCast = false
end

-- 开启或关闭自律状态
-- 被BattleState.ActiveBot调用
function BattleControllerWeaponCommand.ActiveBot(self, active, isPlayFocus)
	-- _manualWeaponAutoBot:BattleManualWeaponAutoBot
	self._manualWeaponAutoBot:SetActive(active, isPlayFocus)
	self._joyStickAutoBot:SetActive(active)
end

-- 尝试自律召唤潜艇
-- 被BattleSingleDungeonCommand.DoPrologue调用
function BattleControllerWeaponCommand.TryAutoSub(self)
	local battleType = self:GetState():GetBattleType()

	if ys.Battle.BattleState.IsAutoSubActive(battleType) then
		local submarineVO = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)._submarineVO

		if submarineVO:GetUseable() and submarineVO:GetCount() > 0 then
			self._dataProxy:SubmarineStrike(ys.Battle.BattleConfig.FRIENDLY_CODE)
			submarineVO:Cast()
		end
	end
end

function BattleControllerWeaponCommand.GetWeaponBot(self)
	return self._manualWeaponAutoBot
end

function BattleControllerWeaponCommand.GetBotActiveDuration(self)
	return self._manualWeaponAutoBot:GetTotalActiveDuration()
end

function BattleControllerWeaponCommand.GetStickBot(self)
	return self._joyStickAutoBot
end

function BattleControllerWeaponCommand.InitBattleEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.COMMON_DATA_INIT_FINISH, self.onUnitInitFinish)
	self._dataProxy:RegisterEventListener(self, BattleEvent.JAMMING, self.onJamming)
end

--- 每帧Update，由BattleState的UpdateBeat驱动
--- @param timeStamp number 时间戳
function BattleControllerWeaponCommand.Update(self, timeStamp)
	if self._jammingFlag then
		return
	end

	if not self._focusBlockCast then
		self._manualWeaponAutoBot:Update()
	end

	for _, fleet in pairs(self._fleetList) do
		fleet:UpdateManualWeaponVO(timeStamp)
	end
end

--- 干扰状态变化事件
function BattleControllerWeaponCommand.onJamming(self, event)
	self._jammingFlag = event.Data.jammingFlag
end

--- 单位初始化完成，创建武器Bot和摇杆Bot
function BattleControllerWeaponCommand.onUnitInitFinish(self, event)
	self._fleetList = self._dataProxy:GetFleetList()

	local friendlyFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

	friendlyFleet:RegisterEventListener(self, BattleEvent.REFRESH_FLEET_FORMATION, self.onFleetFormationUpdate)
	friendlyFleet:RegisterEventListener(self, BattleEvent.OVERRIDE_AUTO_BOT, self.onOverrideAutoBot)

	self._manualWeaponAutoBot = ys.Battle.BattleManualWeaponAutoBot.New(friendlyFleet)
	self._joyStickAutoBot = ys.Battle.BattleJoyStickAutoBot.New(self._dataProxy, friendlyFleet)

	if self._dataProxy:GetInitData().battleType == SYSTEM_SCENARIO_SUB_STRIKE then
		self._joyStickAutoBot:SwitchStrategy(self._joyStickAutoBot.IDLE)
	else
		self._joyStickAutoBot:SwitchStrategy(self._joyStickAutoBot.RANDOM)
	end

	ys.Battle.BattleCameraUtil.GetInstance():RegisterEventListener(self, BattleEvent.CAMERA_FOCUS, self.onCameraFocus)
end

function BattleControllerWeaponCommand.onFleetFormationUpdate(self, event)
	self._joyStickAutoBot:FleetFormationUpdate()
end

function BattleControllerWeaponCommand.onOverrideAutoBot(self, event)
	self._joyStickAutoBot:SwitchStrategy(ys.Battle.BattleJoyStickAutoBot.AUTO_PILOT)
end

--- 相机焦点变化，存在焦点单位时阻挡武器释放
function BattleControllerWeaponCommand.onCameraFocus(self, event)
	local eventData = event.Data

	if eventData.unit ~= nil then
		self._focusBlockCast = true
	else
		local totalDelay = eventData.duration + eventData.extraBulletTime

		LeanTween.delayedCall(totalDelay, System.Action(function()
			self._focusBlockCast = false
		end))
	end
end

function BattleControllerWeaponCommand.Dispose(self)
	local friendlyFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

	friendlyFleet:UnregisterEventListener(self, BattleEvent.REFRESH_FLEET_FORMATION)
	friendlyFleet:UnregisterEventListener(self, BattleEvent.OVERRIDE_AUTO_BOT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.COMMON_DATA_INIT_FINISH)
	ys.Battle.BattleCameraUtil.GetInstance():UnregisterEventListener(self, BattleEvent.CAMERA_FOCUS)
	self._joyStickAutoBot:Dispose()

	self._joyStickAutoBot = nil

	self._manualWeaponAutoBot:Dispose()

	self._manualWeaponAutoBot = nil

	BattleControllerWeaponCommand.super.Dispose(self)
end
