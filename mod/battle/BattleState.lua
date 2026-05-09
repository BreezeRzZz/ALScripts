ys = ys or {}
-- 战斗状态机Facade，管理战斗整个生命周期的状态切换、Mediator/Command/Proxy的创建和销毁
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

--- @class BattleState : 战斗状态机Facade
local BattleState = singletonClass("BattleState", ys.MVC.Facade)

ys.Battle.BattleState = BattleState
BattleState.__name = "BattleState"
BattleState.BATTLE_STATE_IDLE = "BATTLE_IDLE"
BattleState.BATTLE_STATE_OPENING = "BATTLE_OPENING"
BattleState.BATTLE_STATE_FIGHT = "BATTLE_FIGHT"
BattleState.BATTLE_STATE_REPORT = "BATTLE_REPORT"

function BattleState.Ctor(self)
	BattleState.super.Ctor(self)
	self:ChangeState(BattleState.BATTLE_STATE_IDLE)
end

function BattleState.GetCombatSkinKey()
	return COMBAT_SKIN_KEY or "Standard"
end

--- 检查自律Bot是否激活
function BattleState.IsAutoBotActive(self)
	local botMark = AutoBotCommand.GetAutoBotMark(self)

	return PlayerPrefs.GetInt("autoBotIsAcitve" .. botMark, 0) == 1 and AutoBotCommand.autoBotSatisfied()
end

--- 检查自律潜艇是否激活
function BattleState.IsAutoSubActive(self)
	local subMark = AutoSubCommand.GetAutoSubMark(self)

	return PlayerPrefs.GetInt("autoSubIsAcitve" .. subMark, 0) == 1
end

--- 检查聊天功能是否可用
function BattleState.ChatUseable(self)
	local hideChatFlag = PlayerPrefs.GetInt(HIDE_CHAT_FLAG)
	local chatNotHidden = not hideChatFlag or hideChatFlag ~= 1
	local battleType = self:GetBattleType()
	local isAutoActive = self.IsAutoBotActive(battleType)
	local isDuel = battleType == SYSTEM_DUEL
	local isCardPuzzle = battleType == SYSTEM_CARDPUZZLE

	return chatNotHidden and (isDuel or isAutoActive) and not isCardPuzzle
end

function BattleState.GetState(self)
	return self._state
end

function BattleState.GetBattleType(self)
	return self._battleType
end

--- 设置战斗UI根节点
function BattleState.SetBattleUI(self, baseUI)
	self._baseUI = baseUI
end

-- note: 被BattleMediator.register调用
-- 决定战斗的command和mediator
function BattleState.EnterBattle(self, battleData, prePause)
	pg.TimeMgr.GetInstance():ResetCombatTime()
	self:Active()
	self:ResetTimer()

	self._dataProxy = self:AddDataProxy(ys.Battle.BattleDataProxy.GetInstance())
	self._uiMediator = self:AddMediator(ys.Battle.BattleUIMediator.New())
	self._battleType = battleData.battleType

	local command = ys.Battle.BattleFacadeGate.CommandGates[self._battleType] or ys.Battle.BattleSingleDungeonCommand

	self._battleCommand = self:AddCommand(command.New())
	self._sceneMediator = self:AddMediator(ys.Battle.BattleSceneMediator.New())
	self._weaponCommand = self:AddCommand(ys.Battle.BattleControllerWeaponCommand.New())

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

function BattleState.GetSceneMediator(self)
	return self._sceneMediator
end

function BattleState.GetUIMediator(self)
	return self._uiMediator
end

--- 激活/关闭自律Bot并同步摇杆状态
function BattleState.ActiveBot(self, active)
	self._weaponCommand:ActiveBot(active, true)
	self:EnableJoystick(not active)
end

function BattleState.EnableJoystick(self, enable)
	self._uiMediator:EnableJoystick(enable)
end

--- 检查武器Bot是否激活
function BattleState.IsBotActive(self)
	return self._weaponCommand:GetWeaponBot():IsActive()
end

--- 每帧Update，遍历所有Mediator调用Update或UpdatePause
function BattleState.Update(self)
	if not self._isPause then
		for _, mediator in pairs(self._mediatorList) do
			mediator:Update()
		end
	else
		for _, mediator in pairs(self._mediatorList) do
			mediator:UpdatePause()
		end
	end
end

--- 生成校验数据（空实现）
function BattleState.GenerateVertifyData(self)
	return
end

--- 战斗校验
function BattleState.Vertify()
	return true, -1
end

--- 切换战斗状态，根据目标状态执行不同的初始化逻辑
function BattleState.ChangeState(self, state)
	self._state = state

	if state == BattleState.BATTLE_STATE_OPENING then
		self._dataProxy:Start()

		local beginStory = self._dataProxy._dungeonInfo.beginStoy
		local chapterProxy = getProxy(ChapterProxy)
		local continuousData = chapterProxy and chapterProxy:GetContinuousData(SYSTEM_SCENARIO)

		if beginStory then
			if continuousData then
				pg.NewStoryMgr.GetInstance():ForceAutoPlay(beginStory, function()
					self._battleCommand:DoPrologue()
				end)
			else
				pg.NewStoryMgr.GetInstance():Play(beginStory, function()
					self._battleCommand:DoPrologue()
				end)
			end
		else
			self._battleCommand:DoPrologue()
		end
	elseif state == BattleState.BATTLE_STATE_FIGHT then
		self:ActiveAutoComponentTimer()

		if not self._dataProxy:GetFleetLegal(ys.Battle.BattleConfig.FRIENDLY_CODE, self:GetBattleType()) then
			self._battleCommand:CalcStatistic()
			self:BattleEnd()
		end
	elseif state == BattleState.BATTLE_STATE_REPORT then
		-- block empty
	end
end

function BattleState.GetUI(self)
	return self._baseUI
end

--- 配置战斗结束后的回调函数
function BattleState.ConfigBattleEndFunc(self, endFunc)
	self._endFunc = endFunc
end

--- 战斗结束，评分B以上播放庆祝动画，否则直接结算
function BattleState.BattleEnd(self)
	self:disableCommon()
	-- 大于等于B评分，庆祝胜利，否则直接结算
	if self._dataProxy:GetStatistics()._battleScore >= ys.Battle.BattleConst.BattleScore.B then
		self._dataProxy:CelebrateVictory(self._dataProxy:GetFriendlyCode())
		self:reportDelayTimer(function()
			self:DoResult()
		end, ys.Battle.BattleConfig.CelebrateDuration)
	else
		self:DoResult()
	end
end

--- 战斗超时，播放逃跑动画后进行结算
function BattleState.BattleTimeUp(self)
	self:disableCommon()
	self:ActiveEscape()
	self:reportDelayTimer(function()
		self:DeactiveEscape()
		self:DoResult()
	end, ys.Battle.BattleConfig.EscapeDuration)
end

--- 执行战斗结算：暂停角色动画、计算Bot比例和HP统计、调用endFunc
function BattleState.DoResult(self)
	self._sceneMediator:PauseCharacterAction(true)
	self._dataProxy:BotPercentage(self._weaponCommand:GetBotActiveDuration())
	self._dataProxy:HPRatioStatistics()
	self._endFunc(self._dataProxy:GetStatistics())
end

--- 退出战斗，清理所有Mediator/Command/Proxy和资源
function BattleState.ExitBattle(self)
	ys.Battle.BattleCameraUtil.GetInstance():Clear()

	for _, mediator in pairs(self._mediatorList) do
		self:RemoveMediator(mediator)
	end

	for _, command in pairs(self._commandList) do
		self:RemoveCommand(command)
	end

	for _, proxy in pairs(self._proxyList) do
		self:RemoveProxy(proxy)
	end

	ys.Battle.BattleConfig.BASIC_TIME_SCALE = 1

	self:RemoveAllTimer()
	ys.Battle.BattleResourceManager.GetInstance():Clear()

	self._takeoverProcess = nil

	self:ChangeState(BattleState.BATTLE_STATE_IDLE)

	self._baseUI = nil
	self._endFunc = nil
	self._uiMediator = nil
	self._sceneMediator = nil
	self._battleCommand = nil
	self._weaponCommand = nil

	removeSingletonInstance(ys.Battle.BattleDataProxy)

	self._dataProxy = nil

	ys.Battle.BattleVariable.Clear()
	ys.Battle.BattleBulletFactory.DestroyFactory()
	UpdateBeat:Remove(self.Update, self)
	pg.EffectMgr.GetInstance():ClearBattleEffectMap()

	self._timeScale = nil
	self._timescalerCache = nil

	gcAll(true)
end

--- 停止战斗
function BattleState.Stop(self, callback)
	self:disableCommon()
	self._baseUI:exitBattle(callback)
end

--- 禁用通用组件：关闭Bot、缩放计时器、重置相机、清理飞机等
function BattleState.disableCommon(self)
	self._weaponCommand:ActiveBot(false)
	self:ScaleTimer()
	ys.Battle.BattleCameraUtil.GetInstance():ResetFocus()
	self:ChangeState(BattleState.BATTLE_STATE_REPORT)
	self._dataProxy:ClearAirFighterTimer()
	self._dataProxy:KillAllAircraft()
	self._sceneMediator:AllBulletNeutralize()
	ys.Battle.BattleCameraUtil.GetInstance():StopShake()
	ys.Battle.BattleCameraUtil.GetInstance():Deactive()
	self._uiMediator:DisableComponent()
	self:Deactive()
end

--- 延迟结算定时器，在指定时长后执行回调
function BattleState.reportDelayTimer(self, callbackFn, delay)
	local timer

	--- 定时器到期回调
	local function onTimerComplete()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

		timer = nil

		callbackFn()
	end

	self:RemoveAllTimer()
	pg.TimeMgr.GetInstance():ResumeBattleTimer()

	timer = pg.TimeMgr.GetInstance():AddBattleTimer("reportDelay", -1, delay, onTimerComplete)
end

--- 设置接管战斗过程（用于特殊流程接管）
function BattleState.SetTakeoverProcess(self, process)
	assert(self._takeoverProcess == nil, "已经有接管的战斗过程，暂时没有定义这种逻辑")
	assert(process.Pause ~= nil and type(process.Pause) == "function", "SetTakeoverProcess附加过程，必须要有Pause函数")
	assert(process.Pause ~= nil and type(process.Resume) == "function", "SetTakeoverProcess附加过程，必须要有Pause函数")

	self._takeoverProcess = process

	self:_pause()
end

--- 清除接管过程并恢复战斗
function BattleState.ClearTakeoverProcess(self)
	assert(self._takeoverProcess, "没有接管的战斗过程，暂时没有定义这种逻辑")

	self._takeoverProcess = nil

	self:_resume()
end

function BattleState.IsPause(self)
	return self._isPause
end

--- 暂停战斗，优先使用接管过程的Pause方法
function BattleState.Pause(self)
	local takeover = self._takeoverProcess

	if takeover then
		takeover.Pause()
	else
		self:_pause()
	end
end

--- 内部暂停实现
function BattleState._pause(self)
	self:Deactive()
	self._dataProxy:PausePuzzleComponent()
	self._sceneMediator:Pause()

	if self._timeScale ~= 1 then
		self:CacheTimescaler(self._timeScale)
		self:ScaleTimer(1)
	end

	ys.Battle.BattleCameraUtil.GetInstance():PauseCameraTween()
end

--- 恢复战斗，根据当前状态决定处理方式
function BattleState.Resume(self)
	if self._state == BattleState.BATTLE_STATE_IDLE then
		self:ChangeState(BattleState.BATTLE_STATE_OPENING)
		UpdateBeat:Add(self.Update, self)
	elseif self._state == BattleState.BATTLE_STATE_REPORT then
		return
	end

	local takeover = self._takeoverProcess

	if takeover then
		takeover.Resume()
	else
		self:_resume()
	end
end

--- 内部恢复实现
function BattleState._resume(self)
	self._sceneMediator:Resume()
	self:Active()
	self._dataProxy:ResumePuzzleComponent()

	if self._timescalerCache then
		self:ScaleTimer(self._timescalerCache)
		self:CacheTimescaler()
	end

	ys.Battle.BattleCameraUtil.GetInstance():ResumeCameraTween()
end

--- 缩放战斗计时器
function BattleState.ScaleTimer(self, scale)
	scale = scale or ys.Battle.BattleConfig.BASIC_TIME_SCALE

	pg.TimeMgr.GetInstance():ScaleBattleTimer(scale)

	self._timeScale = scale
end

function BattleState.GetTimeScaleRate(self)
	return self._timeScale or 1
end

--- 缓存时间缩放值（用于暂停后恢复）
function BattleState.CacheTimescaler(self, scale)
	self._timescalerCache = scale
end

--- 播放战斗音效
function ys.Battle.PlayBattleSFX(sfxName)
	if sfxName ~= "" then
		pg.CriMgr.GetInstance():PlaySoundEffect_V3("event:/" .. sfxName)
	end
end

--- 打开调试控制台
function BattleState.OpenConsole(self)
	self._uiMediator:InitDebugConsole()
	self._uiMediator:ActiveDebugConsole()
end

--- 激活参考Box
function BattleState.ActiveReference(self)
	self._controllerCommand = self:AddCommand(ys.Battle.BattleControllerCommand.New())
end
