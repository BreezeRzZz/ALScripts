ys = ys or {}

local ys = ys

ys.Battle = ys.Battle or {}

local bfConsts = {}

pg.bfConsts = bfConsts
bfConsts.DFT_CRIT_EFFECT = 1.5
bfConsts.DFT_CRIT_RATE = 0.05
bfConsts.SECONDs = 60
bfConsts.PERCENT = 0.01
bfConsts.PERCENT1 = 0.001
bfConsts.PERCENT2 = 0.0001
bfConsts.HUNDRED = 100
bfConsts.SCORE_RATE = {
	0.7,
	0.8,
	0.3
}
bfConsts.CRASH_RATE = {
	0.05,
	0.025
}
bfConsts.SUBMARINE_KAMIKAZE = {
	80,
	3.5,
	1.5,
	1,
	0.5,
	0.5,
	1,
	0.005
}
bfConsts.LEAK_RATE = {
	10,
	2.2,
	0.7,
	0.3,
	1,
	0.005,
	0.5
}
bfConsts.PLANE_LEAK_RATE = {
	1,
	1,
	0.01,
	0.5,
	0.7,
	0.3,
	1,
	0.005,
	150,
	150,
	1,
	1
}
bfConsts.METEO_RATE = {
	0.05,
	20,
	0.6,
	0.4
}
bfConsts.NUM1 = 1
bfConsts.NUM0 = 0
bfConsts.NUM10000 = 10000
bfConsts.ACCURACY = {
	0.1,
	2
}
bfConsts.DRATE = {
	25,
	0.02,
	0.0002,
	2000,
	0.1,
	0.8,
	150
}
bfConsts.SPEED_CONST = 0.02
bfConsts.HP_CONST = 1.5

local BattleState = singletonClass("BattleState", ys.MVC.Facade)

ys.Battle.BattleState = BattleState
BattleState.__name = "BattleState"
BattleState.BATTLE_STATE_IDLE = "BATTLE_IDLE"
BattleState.BATTLE_STATE_OPENING = "BATTLE_OPENING"
BattleState.BATTLE_STATE_FIGHT = "BATTLE_FIGHT"
BattleState.BATTLE_STATE_REPORT = "BATTLE_REPORT"

function BattleState.Ctor(arg_1_0)
	BattleState.super.Ctor(arg_1_0)
	arg_1_0:ChangeState(BattleState.BATTLE_STATE_IDLE)
end

function BattleState.GetCombatSkinKey()
	return COMBAT_SKIN_KEY or "Standard"
end

function BattleState.IsAutoBotActive(arg_3_0)
	local var_3_0 = AutoBotCommand.GetAutoBotMark(arg_3_0)

	return PlayerPrefs.GetInt("autoBotIsAcitve" .. var_3_0, 0) == 1 and AutoBotCommand.autoBotSatisfied()
end

function BattleState.IsAutoSubActive(arg_4_0)
	local var_4_0 = AutoSubCommand.GetAutoSubMark(arg_4_0)

	return PlayerPrefs.GetInt("autoSubIsAcitve" .. var_4_0, 0) == 1
end

function BattleState.ChatUseable(arg_5_0)
	local var_5_0 = PlayerPrefs.GetInt(HIDE_CHAT_FLAG)
	local var_5_1 = not var_5_0 or var_5_0 ~= 1
	local var_5_2 = arg_5_0:GetBattleType()
	local var_5_3 = arg_5_0.IsAutoBotActive(var_5_2)
	local var_5_4 = var_5_2 == SYSTEM_DUEL
	local var_5_5 = var_5_2 == SYSTEM_CARDPUZZLE

	return var_5_1 and (var_5_4 or var_5_3) and not var_5_5
end

function BattleState.GetState(arg_6_0)
	return arg_6_0._state
end

function BattleState.GetBattleType(arg_7_0)
	return arg_7_0._battleType
end

function BattleState.SetBattleUI(arg_8_0, arg_8_1)
	arg_8_0._baseUI = arg_8_1
end

-- note: 被BattleMediator.register调用
-- 决定战斗的command和mediator
function BattleState.EnterBattle(self, battleData, prePause)
	pg.TimeMgr.GetInstance():ResetCombatTime()
	self:Active()
	self:ResetTimer()

	arg_9_0._dataProxy = arg_9_0:AddDataProxy(var_0_0.Battle.BattleDataProxy.GetInstance())
	arg_9_0._uiMediator = arg_9_0:AddMediator(var_0_0.Battle.BattleUIMediator.New())
	arg_9_0._battleType = arg_9_1.battleType

	local var_9_0 = var_0_0.Battle.BattleFacadeGate.CommandGates[arg_9_0._battleType] or var_0_0.Battle.BattleSingleDungeonCommand

	arg_9_0._battleCommand = arg_9_0:AddCommand(var_9_0.New())
	arg_9_0._sceneMediator = arg_9_0:AddMediator(var_0_0.Battle.BattleSceneMediator.New())
	arg_9_0._weaponCommand = arg_9_0:AddCommand(var_0_0.Battle.BattleControllerWeaponCommand.New())

	self._dataProxy:InitBattle(battleData)

	if BATTLE_DEFAULT_UNIT_DETAIL then
		self:AddMediator(ys.Battle.BattleReferenceBoxMediator.New())
		self:GetMediatorByName(ys.Battle.BattleReferenceBoxMediator.__name):ActiveUnitDetail(true)
	end

	if prePause then
		-- block empty
	else
		self:ChangeState(BattleState.BATTLE_STATE_OPENING)
		UpdateBeat:Add(self.Update, self)
	end
end

function BattleState.GetSceneMediator(arg_10_0)
	return arg_10_0._sceneMediator
end

function BattleState.GetUIMediator(arg_11_0)
	return arg_11_0._uiMediator
end

function BattleState.ActiveBot(self, active)
	self._weaponCommand:ActiveBot(active, true)
	self:EnableJoystick(not active)
end

function BattleState.EnableJoystick(arg_13_0, arg_13_1)
	arg_13_0._uiMediator:EnableJoystick(arg_13_1)
end

function BattleState.IsBotActive(arg_14_0)
	return arg_14_0._weaponCommand:GetWeaponBot():IsActive()
end

function BattleState.Update(arg_15_0)
	if not arg_15_0._isPause then
		for iter_15_0, iter_15_1 in pairs(arg_15_0._mediatorList) do
			iter_15_1:Update()
		end
	else
		for iter_15_2, iter_15_3 in pairs(arg_15_0._mediatorList) do
			iter_15_3:UpdatePause()
		end
	end
end

function BattleState.GenerateVertifyData(self)
	return
end

function BattleState.Vertify()
	return true, -1
end

function BattleState.ChangeState(arg_18_0, arg_18_1)
	arg_18_0._state = arg_18_1

	if arg_18_1 == BattleState.BATTLE_STATE_OPENING then
		arg_18_0._dataProxy:Start()

		local var_18_0 = arg_18_0._dataProxy._dungeonInfo.beginStoy

		if var_18_0 then
			pg.NewStoryMgr.GetInstance():Play(var_18_0, function()
				arg_18_0._battleCommand:DoPrologue()
			end)
		else
			arg_18_0._battleCommand:DoPrologue()
		end
	elseif arg_18_1 == BattleState.BATTLE_STATE_FIGHT then
		arg_18_0:ActiveAutoComponentTimer()

		if not arg_18_0._dataProxy:GetFleetLegal(ys.Battle.BattleConfig.FRIENDLY_CODE, arg_18_0:GetBattleType()) then
			arg_18_0._battleCommand:CalcStatistic()
			arg_18_0:BattleEnd()
		end
	elseif arg_18_1 == BattleState.BATTLE_STATE_REPORT then
		-- block empty
	end
end

function BattleState.GetUI(arg_20_0)
	return arg_20_0._baseUI
end

function BattleState.ConfigBattleEndFunc(arg_21_0, arg_21_1)
	arg_21_0._endFunc = arg_21_1
end

function BattleState.BattleEnd(arg_22_0)
	arg_22_0:disableCommon()

	if arg_22_0._dataProxy:GetStatistics()._battleScore >= ys.Battle.BattleConst.BattleScore.B then
		arg_22_0._dataProxy:CelebrateVictory(arg_22_0._dataProxy:GetFriendlyCode())
		arg_22_0:reportDelayTimer(function()
			arg_22_0:DoResult()
		end, ys.Battle.BattleConfig.CelebrateDuration)
	else
		arg_22_0:DoResult()
	end
end

function BattleState.BattleTimeUp(arg_24_0)
	arg_24_0:disableCommon()
	arg_24_0:ActiveEscape()
	arg_24_0:reportDelayTimer(function()
		arg_24_0:DeactiveEscape()
		arg_24_0:DoResult()
	end, ys.Battle.BattleConfig.EscapeDuration)
end

function BattleState.DoResult(arg_26_0)
	arg_26_0._sceneMediator:PauseCharacterAction(true)
	arg_26_0._dataProxy:BotPercentage(arg_26_0._weaponCommand:GetBotActiveDuration())
	arg_26_0._dataProxy:HPRatioStatistics()
	arg_26_0._endFunc(arg_26_0._dataProxy:GetStatistics())
end

function BattleState.ExitBattle(arg_27_0)
	ys.Battle.BattleCameraUtil.GetInstance():Clear()

	for iter_27_0, iter_27_1 in pairs(arg_27_0._mediatorList) do
		arg_27_0:RemoveMediator(iter_27_1)
	end

	for iter_27_2, iter_27_3 in pairs(arg_27_0._commandList) do
		arg_27_0:RemoveCommand(iter_27_3)
	end

	for iter_27_4, iter_27_5 in pairs(arg_27_0._proxyList) do
		arg_27_0:RemoveProxy(iter_27_5)
	end

	ys.Battle.BattleConfig.BASIC_TIME_SCALE = 1

	arg_27_0:RemoveAllTimer()
	ys.Battle.BattleResourceManager.GetInstance():Clear()

	arg_27_0._takeoverProcess = nil

	arg_27_0:ChangeState(BattleState.BATTLE_STATE_IDLE)

	arg_27_0._baseUI = nil
	arg_27_0._endFunc = nil
	arg_27_0._uiMediator = nil
	arg_27_0._sceneMediator = nil
	arg_27_0._battleCommand = nil
	arg_27_0._weaponCommand = nil

	removeSingletonInstance(ys.Battle.BattleDataProxy)

	arg_27_0._dataProxy = nil

	ys.Battle.BattleVariable.Clear()
	ys.Battle.BattleBulletFactory.DestroyFactory()
	UpdateBeat:Remove(arg_27_0.Update, arg_27_0)
	pg.EffectMgr.GetInstance():ClearBattleEffectMap()

	arg_27_0._timeScale = nil
	arg_27_0._timescalerCache = nil

	gcAll(true)
end

function BattleState.Stop(arg_28_0, arg_28_1)
	arg_28_0:disableCommon()
	arg_28_0._baseUI:exitBattle(arg_28_1)
end

function BattleState.disableCommon(arg_29_0)
	arg_29_0._weaponCommand:ActiveBot(false)
	arg_29_0:ScaleTimer()
	ys.Battle.BattleCameraUtil.GetInstance():ResetFocus()
	arg_29_0:ChangeState(BattleState.BATTLE_STATE_REPORT)
	arg_29_0._dataProxy:ClearAirFighterTimer()
	arg_29_0._dataProxy:KillAllAircraft()
	arg_29_0._sceneMediator:AllBulletNeutralize()
	ys.Battle.BattleCameraUtil.GetInstance():StopShake()
	ys.Battle.BattleCameraUtil.GetInstance():Deactive()
	arg_29_0._uiMediator:DisableComponent()
	arg_29_0:Deactive()
end

function BattleState.reportDelayTimer(arg_30_0, arg_30_1, arg_30_2)
	local var_30_0

	local function var_30_1()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(var_30_0)

		var_30_0 = nil

		arg_30_1()
	end

	arg_30_0:RemoveAllTimer()
	pg.TimeMgr.GetInstance():ResumeBattleTimer()

	var_30_0 = pg.TimeMgr.GetInstance():AddBattleTimer("reportDelay", -1, arg_30_2, var_30_1)
end

function BattleState.SetTakeoverProcess(arg_32_0, arg_32_1)
	assert(arg_32_0._takeoverProcess == nil, "已经有接管的战斗过程，暂时没有定义这种逻辑")
	assert(arg_32_1.Pause ~= nil and type(arg_32_1.Pause) == "function", "SetTakeoverProcess附加过程，必须要有Pause函数")
	assert(arg_32_1.Pause ~= nil and type(arg_32_1.Resume) == "function", "SetTakeoverProcess附加过程，必须要有Pause函数")

	arg_32_0._takeoverProcess = arg_32_1

	arg_32_0:_pause()
end

function BattleState.ClearTakeoverProcess(arg_33_0)
	assert(arg_33_0._takeoverProcess, "没有接管的战斗过程，暂时没有定义这种逻辑")

	arg_33_0._takeoverProcess = nil

	arg_33_0:_resume()
end

function BattleState.IsPause(arg_34_0)
	return arg_34_0._isPause
end

function BattleState.Pause(arg_35_0)
	local var_35_0 = arg_35_0._takeoverProcess

	if var_35_0 then
		var_35_0.Pause()
	else
		arg_35_0:_pause()
	end
end

function BattleState._pause(arg_36_0)
	arg_36_0:Deactive()
	arg_36_0._dataProxy:PausePuzzleComponent()
	arg_36_0._sceneMediator:Pause()

	if arg_36_0._timeScale ~= 1 then
		arg_36_0:CacheTimescaler(arg_36_0._timeScale)
		arg_36_0:ScaleTimer(1)
	end

	ys.Battle.BattleCameraUtil.GetInstance():PauseCameraTween()
end

function BattleState.Resume(arg_37_0)
	if arg_37_0._state == BattleState.BATTLE_STATE_IDLE then
		arg_37_0:ChangeState(BattleState.BATTLE_STATE_OPENING)
		UpdateBeat:Add(arg_37_0.Update, arg_37_0)
	elseif arg_37_0._state == BattleState.BATTLE_STATE_REPORT then
		return
	end

	local var_37_0 = arg_37_0._takeoverProcess

	if var_37_0 then
		var_37_0.Resume()
	else
		arg_37_0:_resume()
	end
end

function BattleState._resume(arg_38_0)
	arg_38_0._sceneMediator:Resume()
	arg_38_0:Active()
	arg_38_0._dataProxy:ResumePuzzleComponent()

	if arg_38_0._timescalerCache then
		arg_38_0:ScaleTimer(arg_38_0._timescalerCache)
		arg_38_0:CacheTimescaler()
	end

	ys.Battle.BattleCameraUtil.GetInstance():ResumeCameraTween()
end

function BattleState.ScaleTimer(arg_39_0, arg_39_1)
	arg_39_1 = arg_39_1 or ys.Battle.BattleConfig.BASIC_TIME_SCALE

	pg.TimeMgr.GetInstance():ScaleBattleTimer(arg_39_1)

	arg_39_0._timeScale = arg_39_1
end

function BattleState.GetTimeScaleRate(arg_40_0)
	return arg_40_0._timeScale or 1
end

function BattleState.CacheTimescaler(arg_41_0, arg_41_1)
	arg_41_0._timescalerCache = arg_41_1
end

function ys.Battle.PlayBattleSFX(SFXID)
	if SFXID ~= "" then
		pg.CriMgr.GetInstance():PlaySoundEffect_V3("event:/" .. SFXID)
	end
end

function BattleState.OpenConsole(arg_43_0)
	arg_43_0._uiMediator:InitDebugConsole()
	arg_43_0._uiMediator:ActiveDebugConsole()
end

function BattleState.ActiveReference(arg_44_0)
	arg_44_0._controllerCommand = arg_44_0:AddCommand(ys.Battle.BattleControllerCommand.New())
end
