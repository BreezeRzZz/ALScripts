ys = ys or {}

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

-- TODO
-- 尝试自律召唤潜艇
-- 被BattleSingleDungeonCommand.DoPrologue调用
function BattleControllerWeaponCommand.TryAutoSub(arg_4_0)
	local var_4_0 = arg_4_0:GetState():GetBattleType()

	if ys.Battle.BattleState.IsAutoSubActive(var_4_0) then
		local var_4_1 = arg_4_0._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)._submarineVO

		if var_4_1:GetUseable() and var_4_1:GetCount() > 0 then
			arg_4_0._dataProxy:SubmarineStrike(ys.Battle.BattleConfig.FRIENDLY_CODE)
			var_4_1:Cast()
		end
	end
end

function BattleControllerWeaponCommand.GetWeaponBot(arg_5_0)
	return arg_5_0._manualWeaponAutoBot
end

function BattleControllerWeaponCommand.GetBotActiveDuration(arg_6_0)
	return arg_6_0._manualWeaponAutoBot:GetTotalActiveDuration()
end

function BattleControllerWeaponCommand.GetStickBot(arg_7_0)
	return arg_7_0._joyStickAutoBot
end

function BattleControllerWeaponCommand.InitBattleEvent(arg_8_0)
	arg_8_0._dataProxy:RegisterEventListener(arg_8_0, BattleEvent.COMMON_DATA_INIT_FINISH, arg_8_0.onUnitInitFinish)
	arg_8_0._dataProxy:RegisterEventListener(arg_8_0, BattleEvent.JAMMING, arg_8_0.onJamming)
end

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

function BattleControllerWeaponCommand.onJamming(arg_10_0, arg_10_1)
	arg_10_0._jammingFlag = arg_10_1.Data.jammingFlag
end

function BattleControllerWeaponCommand.onUnitInitFinish(arg_11_0, arg_11_1)
	arg_11_0._fleetList = arg_11_0._dataProxy:GetFleetList()

	local var_11_0 = arg_11_0._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

	var_11_0:RegisterEventListener(arg_11_0, BattleEvent.REFRESH_FLEET_FORMATION, arg_11_0.onFleetFormationUpdate)
	var_11_0:RegisterEventListener(arg_11_0, BattleEvent.OVERRIDE_AUTO_BOT, arg_11_0.onOverrideAutoBot)

	arg_11_0._manualWeaponAutoBot = ys.Battle.BattleManualWeaponAutoBot.New(var_11_0)
	arg_11_0._joyStickAutoBot = ys.Battle.BattleJoyStickAutoBot.New(arg_11_0._dataProxy, var_11_0)

	if arg_11_0._dataProxy:GetInitData().battleType == SYSTEM_SCENARIO_SUB_STRIKE then
		arg_11_0._joyStickAutoBot:SwitchStrategy(arg_11_0._joyStickAutoBot.IDLE)
	else
		arg_11_0._joyStickAutoBot:SwitchStrategy(arg_11_0._joyStickAutoBot.RANDOM)
	end

	ys.Battle.BattleCameraUtil.GetInstance():RegisterEventListener(arg_11_0, BattleEvent.CAMERA_FOCUS, arg_11_0.onCameraFocus)
end

function BattleControllerWeaponCommand.onFleetFormationUpdate(arg_12_0, arg_12_1)
	arg_12_0._joyStickAutoBot:FleetFormationUpdate()
end

function BattleControllerWeaponCommand.onOverrideAutoBot(arg_13_0, arg_13_1)
	arg_13_0._joyStickAutoBot:SwitchStrategy(ys.Battle.BattleJoyStickAutoBot.AUTO_PILOT)
end

function BattleControllerWeaponCommand.onCameraFocus(arg_14_0, arg_14_1)
	local var_14_0 = arg_14_1.Data

	if var_14_0.unit ~= nil then
		arg_14_0._focusBlockCast = true
	else
		local var_14_1 = var_14_0.duration + var_14_0.extraBulletTime

		LeanTween.delayedCall(var_14_1, System.Action(function()
			arg_14_0._focusBlockCast = false
		end))
	end
end

function BattleControllerWeaponCommand.Dispose(arg_16_0)
	local var_16_0 = arg_16_0._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

	var_16_0:UnregisterEventListener(arg_16_0, BattleEvent.REFRESH_FLEET_FORMATION)
	var_16_0:UnregisterEventListener(arg_16_0, BattleEvent.OVERRIDE_AUTO_BOT)
	arg_16_0._dataProxy:UnregisterEventListener(arg_16_0, BattleEvent.COMMON_DATA_INIT_FINISH)
	ys.Battle.BattleCameraUtil.GetInstance():UnregisterEventListener(arg_16_0, BattleEvent.CAMERA_FOCUS)
	arg_16_0._joyStickAutoBot:Dispose()

	arg_16_0._joyStickAutoBot = nil

	arg_16_0._manualWeaponAutoBot:Dispose()

	arg_16_0._manualWeaponAutoBot = nil

	BattleControllerWeaponCommand.super.Dispose(arg_16_0)
end
