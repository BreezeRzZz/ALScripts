ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConst = ys.Battle.BattleConst
local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent
local BattleUIMediator = class("BattleUIMediator", ys.MVC.Mediator)

ys.Battle.BattleUIMediator = BattleUIMediator
BattleUIMediator.__name = "BattleUIMediator"

--- 构造函数
function BattleUIMediator.Ctor(self)
	BattleUIMediator.super.Ctor(self)
end

--- 设置战斗UI引用
function BattleUIMediator.SetBattleUI(self)
	self._ui = self._state:GetUI()
end

--- 初始化中介者
function BattleUIMediator.Initialize(self)
	BattleUIMediator.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	self._uiMGR = pg.UIMgr.GetInstance()
	self._fxPool = ys.Battle.BattleFXPool.GetInstance()
	self._updateViewList = {}

	self:SetBattleUI()
	self:AddUIEvent()
	self:InitCamera()
	self:InitGuide()
end

--- 重新初始化
function BattleUIMediator.Reinitialize(self)
	self._skillView:Dispose()
end

--- 启用/禁用组件
--- @param enable boolean 是否启用
function BattleUIMediator.EnableComponent(self, enable)
	self._ui._tf:Find("PauseBtn"):GetComponent(typeof(Button)).enabled = enable

	self._skillView:EnableWeaponButton(enable)
end

--- 启用/禁用摇杆
--- @param enable boolean 是否启用
function BattleUIMediator.EnableJoystick(self, enable)
	self._stickController.enabled = enable

	local animComp = self._joystick:GetComponent(typeof(Animation))

	if animComp then
		animComp.enabled = enable
	end

	local animatorComp = self._joystick:GetComponent(typeof(Animator))

	if animatorComp then
		animatorComp.enabled = enable
	end

	setActive(self._joystick, enable)

	local spineTF = self._joystick:Find("Area/BG/spine")

	if spineTF then
		local spineAnim = spineTF:GetComponent(typeof(SpineAnimUI))

		if enable then
			spineAnim:SetAction("cut_in", 0)
		end
	end
end

--- 启用/禁用武器按钮
--- @param enable boolean 是否启用
function BattleUIMediator.EnableWeaponButton(self, enable)
	self._skillView:EnableWeaponButton(enable)
end

--- 启用/禁用技能浮窗
--- @param enable boolean 是否启用
function BattleUIMediator.EnableSkillFloat(self, enable)
	self._ui:EnableSkillFloat(enable)
end

--- 获取Boss出场特效
--- @return GameObject|nil
function BattleUIMediator.GetAppearFX(self)
	return self._appearEffect
end

--- 禁用所有交互组件
function BattleUIMediator.DisableComponent(self)
	self._ui._tf:Find("PauseBtn"):GetComponent(typeof(Button)).enabled = false

	self._skillView:DisableWeapnButton()
	SetActive(self._ui._tf:Find("HPBarContainer"), false)
	SetActive(self._ui._tf:Find("flagShipMark"), false)

	if self._jammingView then
		self._jammingView:Eliminate(false)
	end

	if self._inkView then
		self._inkView:SetActive(false)
	end
end

--- 激活调试控制台
function BattleUIMediator.ActiveDebugConsole(self)
	self._debugConsoleView:SetActive(true)
end

--- 开场效果，根据不同战斗系统类型配置UI按钮布局
--- @param callback function 开场效果完成后的回调
--- @param systemType number 战斗系统类型常量
function BattleUIMediator.OpeningEffect(self, callback, systemType)
	self._uiMGR:SetActive(false)

	if systemType == SYSTEM_SUBMARINE_RUN then
		self._skillView:SubmarineButton()

		local defaultPref = BattleConfig.JOY_STICK_DEFAULT_PREFERENCE

		self._joystick.anchorMin = Vector2(defaultPref.x, defaultPref.y)
		self._joystick.anchorMax = Vector2(defaultPref.x, defaultPref.y)
	elseif systemType == SYSTEM_SUB_ROUTINE then
		self._skillView:SubRoutineButton()
	elseif systemType == SYSTEM_AIRFIGHT then
		self._skillView:AirFightButton()
	elseif systemType == SYSTEM_DEBUG then
		self._skillView:NormalButton()
	elseif systemType == SYSTEM_CARDPUZZLE then
		self._skillView:CardPuzzleButton()
	else
		local guideMgr = pg.SeriesGuideMgr.GetInstance()

		if guideMgr.currIndex and guideMgr:isEnd() then
			self._skillView:NormalButton()
		else
			local hiddenSkills = self._dataProxy:GetDungeonData().skill_hide or {}

			self._skillView:CustomButton(hiddenSkills)
		end
	end

	LeanTween.delayedCall(BattleConfig.COMBAT_DELAY_ACTIVE, System.Action(function()
		self._uiMGR:SetActive(true)
		self:EnableComponent(true)

		if callback then
			callback()
		end
	end))
	SetActive(self._ui._go, true)
	self._skillView:ButtonInitialAnima()
end

--- 初始化战斗场景（海域背景）
function BattleUIMediator.InitScene(self)
	self._mapId = self._dataProxy._mapId
	self._seaView = ys.Battle.BattleMap.New(self._mapId)
end

--- 初始化摇杆
function BattleUIMediator.InitJoystick(self)
	self._joystick = self._ui._tf:Find("Stick")

	local defaultPref = BattleConfig.JOY_STICK_DEFAULT_PREFERENCE
	local joystick = self._joystick
	local baseScale = 1
	local savedScale = PlayerPrefs.GetFloat("joystick_scale", defaultPref.scale)
	local savedAnchorX = PlayerPrefs.GetFloat("joystick_anchorX", defaultPref.x)
	local savedAnchorY = PlayerPrefs.GetFloat("joystick_anchorY", defaultPref.y)
	local finalScale = baseScale * savedScale

	self._joystick.localScale = Vector3(finalScale, finalScale, 1)

	originalPrint("scale: ", self._joystick.localScale)

	joystick.anchoredPosition = joystick.anchoredPosition * finalScale
	self._joystick.anchorMin = Vector2(savedAnchorX, savedAnchorY)
	self._joystick.anchorMax = Vector2(savedAnchorX, savedAnchorY)
	self._stickController = self._joystick:GetComponent("StickController")

	self._uiMGR:AttachStickOb(self._joystick)

	local spineTF = self._joystick:Find("Area/BG/spine")

	if spineTF then
		local spineAnim = spineTF:GetComponent(typeof(SpineAnimUI))

		spineAnim:SetActionCallBack(function(event)
			if event == "finish" then
				if self._stickController.enabled then
					spineAnim:SetAction("normal", 0)
				else
					SetActive(self._joystick, false)
				end
			end
		end)
	end
end

--- 初始化计时器
function BattleUIMediator.InitTimer(self)
	if self._dataProxy:GetInitData().battleType == SYSTEM_DUEL then
		self._timerView = ys.Battle.BattleTimerView.New(self._ui._tf:Find("DuelTimer"))
	else
		self._timerView = ys.Battle.BattleTimerView.New(self._ui._tf:Find("Timer"))
	end
end

--- 初始化敌方血条
function BattleUIMediator.InitEnemyHpBar(self)
	self._enemyHpBar = ys.Battle.BattleEnmeyHpBarView.New(self._ui._tf:Find("EnemyHPBar"))
end

--- 初始化空袭图标
function BattleUIMediator.InitAirStrikeIcon(self)
	self._airStrikeView = ys.Battle.BattleAirStrikeIconView.New(self._ui._tf:Find("AirFighterContainer/AirStrikeIcon"))
	self._airSupportTF = self._ui._tf:Find("AirSupportLabel")
end

--- 初始化通用警告视图
function BattleUIMediator.InitCommonWarning(self)
	self._warningView = ys.Battle.BattleCommonWarningView.New(self._ui._tf:Find("WarningView"))
	self._updateViewList[self._warningView] = true
end

--- 初始化闪避计分条
function BattleUIMediator.InitScoreBar(self)
	self._scoreBarView = ys.Battle.BattleScoreBarView.New(self._ui._tf:Find("DodgemCountBar"))
end

--- 初始化空战计分条
function BattleUIMediator.InitAirFightScoreBar(self)
	self._scoreBarView = ys.Battle.BattleScoreBarView.New(self._ui._tf:Find("AirFightCountBar"))
end

--- 初始化自动按钮
function BattleUIMediator.InitAutoBtn(self)
	self._autoBtn = self._ui._tf:Find("AutoBtn")

	local defaultPref = BattleConfig.AUTO_DEFAULT_PREFERENCE
	local savedScale = PlayerPrefs.GetFloat("auto_scale", defaultPref.scale)
	local savedAnchorX = PlayerPrefs.GetFloat("auto_anchorX", defaultPref.x)
	local savedAnchorY = PlayerPrefs.GetFloat("auto_anchorY", defaultPref.y)

	self._autoBtn.localScale = Vector3(savedScale, savedScale, 1)
	self._autoBtn.anchorMin = Vector2(savedAnchorX, savedAnchorY)
	self._autoBtn.anchorMax = Vector2(savedAnchorX, savedAnchorY)
end

--- 初始化擂台伤害率条
function BattleUIMediator.InitDuelRateBar(self)
	self._duelRateBar = ys.Battle.BattleDuelDamageRateView.New(self._ui._tf:Find("DuelDamageRate"))

	return self._duelRateBar
end

--- 初始化模拟战buff计数
function BattleUIMediator.InitSimulationBuffCounting(self)
	self._simulationBuffCountView = ys.Battle.BattleSimulationBuffCountView.New(self._ui._tf:Find("SimulationWarning"))

	return self._simulationBuffCountView
end

--- 初始化主舰受损视图
function BattleUIMediator.InitMainDamagedView(self)
	self._mainDamagedView = ys.Battle.BattleMainDamagedView.New(self._ui._tf:Find("HPWarning"))
end

--- 初始化墨水（致盲）视图
--- @param fleet 舰队VO，用于注册视野更新事件
function BattleUIMediator.InitInkView(self, fleet)
	self._inkView = ys.Battle.BattleInkView.New(self._ui._tf:Find("InkContainer"))

	fleet:RegisterEventListener(self, BattleEvent.FLEET_HORIZON_UPDATE, self.onFleetHorizonUpdate)
end

--- 初始化调试控制台
function BattleUIMediator.InitDebugConsole(self)
	self._debugConsoleView = self._debugConsoleView or ys.Battle.BattleDebugConsole.New(self._ui._tf:Find("Debug_Console"), self._state)
end

--- 初始化摄像机手势滑块
function BattleUIMediator.InitCameraGestureSlider(self)
	self._gesture = ys.Battle.BattleCameraSlider.New(self._ui._tf:Find("CameraController"))

	ys.Battle.BattleCameraUtil.GetInstance():SetCameraSilder(self._gesture)
	self._cameraUtil:SwitchCameraPos("FOLLOW_GESTURE")
end

--- 初始化莱莎AP视图
function BattleUIMediator.InitAlchemistAPView(self)
	if not self._alchemistAP then
		local apPanel = ys.Battle.BattleResourceManager.GetInstance():InstReisalinAPUI()

		setParent(apPanel, self._ui.uiCanvas, false)

		self._alchemistAP = ys.Battle.BattleReisalinAPView.New(apPanel.transform:Find("APPanel"))
	end
end

--- 初始化优米雅Mana视图
function BattleUIMediator.InitAlchemistManaView(self)
	if not self._alchemistMana then
		local manaPanel = ys.Battle.BattleResourceManager.GetInstance():InstYumiaManaUI()

		setParent(manaPanel, self._ui.uiCanvas, false)

		self._alchemistMana = ys.Battle.BattleYumiaManaView.New(manaPanel.transform:Find("ManaPanel"))
	end
end

--- 初始化引导（暂未实现）
function BattleUIMediator.InitGuide(self)
	return
end

--- 初始化摄像机
function BattleUIMediator.InitCamera(self)
	self._camera = pg.UIMgr.GetInstance():GetMainCamera():GetComponent(typeof(Camera))
	self._uiCamera = GameObject.Find("UICamera"):GetComponent(typeof(Camera))
	self._cameraUtil = ys.Battle.BattleCameraUtil.GetInstance()

	self._cameraUtil:RegisterEventListener(self, BattleEvent.CAMERA_FOCUS, self.onCameraFocus)
	self._cameraUtil:RegisterEventListener(self, BattleEvent.SHOW_PAINTING, self.onShowPainting)
	self._cameraUtil:RegisterEventListener(self, BattleEvent.BULLET_TIME, self.onBulletTime)
end

--- 每帧更新，驱动所有注册的更新视图
function BattleUIMediator.Update(self)
	for view, _ in pairs(self._updateViewList) do
		view:Update()
	end
end

--- 注册所有UI事件监听
function BattleUIMediator.AddUIEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH, self.onStageInit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.COMMON_DATA_INIT_FINISH, self.onCommonInit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_FLEET, self.onAddFleet)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.HIT_ENEMY, self.onEnemyHit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_AIR_FIGHTER_ICON, self.onAddAirStrike)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_AIR_FIGHTER_ICON, self.onRemoveAirStrike)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_AIR_SUPPORT_LABEL, self.onUpdateAirSupportLabel)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_HOSTILE_SUBMARINE, self.onUpdateHostileSubmarine)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_ENVIRONMENT_WARNING, self.onUpdateEnvironmentWarning)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN, self.onUpdateCountDown)
	self._dataProxy:RegisterEventListener(self, BattleEvent.HIDE_INTERACTABLE_BUTTONS, self.OnHideButtons)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UI_FX, self.OnAddUIFX)
	self._dataProxy:RegisterEventListener(self, BattleEvent.EDIT_CUSTOM_WARNING_LABEL, self.onEditCustomWarning)
	self._dataProxy:RegisterEventListener(self, BattleEvent.GRIDMAN_SKILL_FLOAT, self.onGridmanSkillFloat)
	self._dataProxy:RegisterEventListener(self, BattleCardPuzzleEvent.CARD_PUZZLE_INIT, self.OnCardPuzzleInit)
end

--- 移除所有UI事件监听
function BattleUIMediator.RemoveUIEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.COMMON_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_FLEET)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.HIT_ENEMY)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_AIR_FIGHTER_ICON)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_AIR_FIGHTER_ICON)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_AIR_SUPPORT_LABEL)
	self._cameraUtil:UnregisterEventListener(self, BattleEvent.SHOW_PAINTING)
	self._cameraUtil:UnregisterEventListener(self, BattleEvent.CAMERA_FOCUS)
	self._cameraUtil:UnregisterEventListener(self, BattleEvent.BULLET_TIME)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_SUBMARINE_WARINING)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_SUBMARINE_WARINING)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_DODGEM_SCORE)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_DODGEM_COMBO)
	self._userFleet:UnregisterEventListener(self, BattleEvent.SHOW_BUFFER)
	self._userFleet:UnregisterEventListener(self, BattleUnitEvent.POINT_HIT_CHARGE)
	self._userFleet:UnregisterEventListener(self, BattleUnitEvent.POINT_HIT_CANCEL)
	self._userFleet:UnregisterEventListener(self, BattleEvent.MANUAL_SUBMARINE_SHIFT)
	self._userFleet:UnregisterEventListener(self, BattleEvent.FLEET_BLIND)
	self._userFleet:UnregisterEventListener(self, BattleEvent.FLEET_HORIZON_UPDATE)
	self._userFleet:UnregisterEventListener(self, BattleEvent.UPDATE_FLEET_ATTR)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_HOSTILE_SUBMARINE)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_ENVIRONMENT_WARNING)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.HIDE_INTERACTABLE_BUTTONS)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UI_FX)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.EDIT_CUSTOM_WARNING_LABEL)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.GRIDMAN_SKILL_FLOAT)
	self._dataProxy:UnregisterEventListener(self, BattleCardPuzzleEvent.CARD_PUZZLE_INIT)
	self._dataProxy:UnregisterEventListener(self, BattleCardPuzzleEvent.UPDATE_FLEET_SHIP)
	self._dataProxy:UnregisterEventListener(self, BattleCardPuzzleEvent.COMMON_BUTTON_ENABLE)
	self._dataProxy:UnregisterEventListener(self, BattleCardPuzzleEvent.LONG_PRESS_BULLET_TIME)
	self._dataProxy:UnregisterEventListener(self, BattleCardPuzzleEvent.SHOW_CARD_DETAIL)
end

--- 显示技能立绘
--- @param caster BattleUnit 技能释放者
--- @param skillData table|nil 技能数据（含cutin_cover/cutin_cover_DAL）
--- @param speed number 播放速度，默认1
function BattleUIMediator.ShowSkillPainting(self, caster, skillData, speed)
	speed = speed or 1

	local cutinCover

	if skillData then
		if skillData.cutin_cover then
			cutinCover = skillData.cutin_cover
		elseif skillData.cutin_cover_DAL then
			self._ui:CutInPaintingDAL(caster:GetTemplate(), speed, caster:GetIFF(), skillData)

			return
		end
	end

	self._ui:CutInPainting(caster:GetTemplate(), speed, caster:GetIFF(), cutinCover)
end

--- 显示技能浮窗
--- @param commander number 指挥官ID
--- @param skillIcon string|number 技能图标资源
--- @param forceOrNot boolean 是否强制显示
function BattleUIMediator.ShowSkillFloat(self, commander, skillIcon, forceOrNot)
	self._ui:SkillHrzPop(skillIcon, commander, forceOrNot)
end

--- 显示技能浮窗（覆盖版）
--- @param commander number 指挥官ID
--- @param coverIcon string 覆盖图标资源
--- @param forceOrNot boolean 是否强制显示
function BattleUIMediator.ShowSkillFloatCover(self, commander, coverIcon, forceOrNot)
	self._ui:SkillHrzPopCover(coverIcon, commander, forceOrNot)
end

--- 进行海面位移
--- @param countStart number 起始偏移量
--- @param countEnd number 目标偏移量
--- @param interval number|nil 移动间隔，默认使用BattleConfig.calcInterval
--- @param callback function|nil 完成回调
function BattleUIMediator.SeaSurfaceShift(self, countStart, countEnd, interval, callback)
	local finalInterval = interval or ys.Battle.BattleConfig.calcInterval

	self._seaView:ShiftSurface(countStart, countEnd, finalInterval, callback)
end

--- 显示自动按钮
function BattleUIMediator.ShowAutoBtn(self)
	SetActive(self._autoBtn.transform, true)

	local battleType = self:GetState():GetBattleType()

	triggerToggle(self._autoBtn, ys.Battle.BattleState.IsAutoBotActive(battleType))
end

--- 显示计时器
function BattleUIMediator.ShowTimer(self)
	self._timerView:SetActive(true)
end

--- 显示擂台伤害率条
function BattleUIMediator.ShowDuelBar(self)
	self._duelRateBar:SetActive(true)
end

--- 显示模拟战buff计数
function BattleUIMediator.ShowSimulationView(self)
	self._simulationBuffCountView:SetActive(true)
end

--- 显示/隐藏暂停按钮
--- @param visible boolean 是否可见
function BattleUIMediator.ShowPauseButton(self, visible)
	setActive(self._ui._tf:Find("PauseBtn"), visible)
end

--- 显示闪避计分条
function BattleUIMediator.ShowDodgemScoreBar(self)
	self:InitScoreBar()
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_DODGEM_SCORE, self.onUpdateDodgemScore)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_DODGEM_COMBO, self.onUpdateDodgemCombo)
	self._scoreBarView:UpdateScore(0)
	self._scoreBarView:SetActive(true)
end

--- 显示空战计分条
function BattleUIMediator.ShowAirFightScoreBar(self)
	self:InitAirFightScoreBar()
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_DODGEM_SCORE, self.onUpdateDodgemScore)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_DODGEM_COMBO, self.onUpdateDodgemCombo)
	self._scoreBarView:UpdateScore(0)
	self._scoreBarView:SetActive(true)
end

--- 缩放UI动画速度
--- @param speedScale number 目标速度倍率
function BattleUIMediator.ScaleUISpeed(self, speedScale)
	local onAnim = self._ui._tf:Find("AutoBtn/on"):GetComponent(typeof(Animation))

	if onAnim then
		onAnim:get_Item("autobtn_toOn").speed = speedScale
	end

	local offAnim = self._ui._tf:Find("AutoBtn/off"):GetComponent(typeof(Animation))

	if offAnim then
		offAnim:get_Item("autobtn_toOff").speed = speedScale
	end
end

--- 关卡数据初始化完成事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onStageInit(self, event)
	self:InitJoystick()
	self:InitScene()
	self:InitTimer()
	self:InitEnemyHpBar()
	self:InitAirStrikeIcon()
	self:InitCommonWarning()
	self:InitAutoBtn()
	self:InitMainDamagedView()
end

--- 命中敌人事件，切换敌人血条显示
--- @param event BattleEvent 事件对象（Data为被命中的敌方单位）
function BattleUIMediator.onEnemyHit(self, event)
	local hitEnemy = event.Data

	if hitEnemy:GetDiveInvisible() and not hitEnemy:GetDiveDetected() then
		return
	end

	local currentTarget = self._enemyHpBar:GetCurrentTarget()

	if currentTarget then
		if currentTarget ~= hitEnemy then
			self._enemyHpBar:SwitchTarget(hitEnemy, self._dataProxy:GetUnitList())
		end
	else
		self._enemyHpBar:SwitchTarget(hitEnemy, self._dataProxy:GetUnitList())
	end
end

--- 敌方血量更新事件
--- @param event BattleUnitEvent 事件对象（Dispatcher为触发单位）
function BattleUIMediator.onEnemyHpUpdate(self, event)
	local unit = event.Dispatcher

	if unit == self._enemyHpBar:GetCurrentTarget() and (not unit:GetDiveInvisible() or unit:GetDiveDetected()) then
		self._enemyHpBar:UpdateHpBar()
	end
end

--- 玩家主力舰血量更新事件，扣血时播放受损提示
--- @param event BattleUnitEvent 事件对象
function BattleUIMediator.onPlayerMainUnitHpUpdate(self, event)
	if event.Data.dHP < 0 then
		self._mainDamagedView:Play()
	end
end

--- 技能浮窗事件
--- @param event BattleUnitEvent 事件对象
function BattleUIMediator.onSkillFloat(self, event)
	local skillData = event.Data
	local coverIcon = skillData.coverHrzIcon
	local commander = skillData.commander
	local skillName = skillData.skillName
	local casterUnit = event.Dispatcher

	if coverIcon then
		self:ShowSkillFloatCover(casterUnit, skillName, coverIcon)
	else
		self:ShowSkillFloat(casterUnit, skillName, commander)
	end
end

--- 通用数据初始化完成事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onCommonInit(self, event)
	self._skillView = ys.Battle.BattleSkillView.New(self, event.Data)
	self._updateViewList[self._skillView] = true
	self._userFleet = self._dataProxy:GetFleetByIFF(BattleConfig.FRIENDLY_CODE)

	self._userFleet:RegisterEventListener(self, BattleEvent.SHOW_BUFFER, self.onShowBuffer)
	self._userFleet:RegisterEventListener(self, BattleUnitEvent.POINT_HIT_CHARGE, self.onPointHitSight)
	self._userFleet:RegisterEventListener(self, BattleUnitEvent.POINT_HIT_CANCEL, self.onPointHitSight)
	self._userFleet:RegisterEventListener(self, BattleEvent.MANUAL_SUBMARINE_SHIFT, self.onManualSubShift)
	self._userFleet:RegisterEventListener(self, BattleEvent.FLEET_BLIND, self.onFleetBlind)
	self._userFleet:RegisterEventListener(self, BattleEvent.UPDATE_FLEET_ATTR, self.onFleetAttrUpdate)

	self._sightView = ys.Battle.BattleOpticalSightView.New(self._ui._tf:Find("ChargeAreaContainer"))

	self._sightView:SetFleetVO(self._userFleet)

	local leftBound, rightBound, bottomBound, topBound = self._dataProxy:GetTotalBounds()

	self._sightView:SetAreaBound(bottomBound, topBound)

	local hasEnemyAdvantageBuff
	local hasSupportUnits

	if self._dataProxy:GetInitData().ChapterBuffIDs then
		for _, buffID in ipairs(self._dataProxy:GetInitData().ChapterBuffIDs) do
			if buffID == 9727 then
				hasEnemyAdvantageBuff = true

				break
			end
		end
	end

	if #self._dataProxy:GetFleetByIFF(BattleConfig.FRIENDLY_CODE):GetSupportUnitList() > 0 then
		hasSupportUnits = true
	end

	-- 根据制空状态和支援情况决定空中支援标签显示
	if hasSupportUnits and not hasEnemyAdvantageBuff then
		self._airAdavantageTF = self._airSupportTF:Find("player_advantage")
	elseif hasEnemyAdvantageBuff and not hasSupportUnits then
		self._airAdavantageTF = self._airSupportTF:Find("enemy_advantage")
	elseif hasEnemyAdvantageBuff and hasSupportUnits then
		self._airAdavantageTF = self._airSupportTF:Find("draw")
	end
end

--- 添加舰队事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onAddFleet(self, event)
	local fleetVO = event.Data.fleetVO

	if PlayerPrefs.GetInt(BATTLE_EXPOSE_LINE, 1) == 1 then
		self:SetFleetCloakLine(fleetVO)
	end
end

--- 设置舰队隐身/暴露线
--- @param fleetVO BattleFleetVO 舰队视图对象
function BattleUIMediator.SetFleetCloakLine(self, fleetVO)
	if #fleetVO:GetCloakList() > 0 then
		local iff = fleetVO:GetIFF()
		local visionLine = fleetVO:GetFleetVisionLine()
		local exposeLine = fleetVO:GetFleetExposeLine()

		self._seaView:SetExposeLine(iff, visionLine, exposeLine)
	end
end

--- 添加单位事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onAddUnit(self, event)
	local unitType = event.Data.type
	local unit = event.Data.unit

	if unitType == BattleConst.UnitType.PLAYER_UNIT or unitType == BattleConst.UnitType.ENEMY_UNIT or unitType == BattleConst.UnitType.BOSS_UNIT then
		self:registerUnitEvent(unit)
	end

	if unit:IsBoss() and self._dataProxy:GetActiveBossCount() == 1 then
		self:AddBossWarningUI()
	elseif unitType == BattleConst.UnitType.ENEMY_UNIT then
		self:registerNPCUnitEvent(unit)
	elseif unitType == BattleConst.UnitType.PLAYER_UNIT and unit:IsMainFleetUnit() and unit:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self:registerPlayerMainUnitEvent(unit)
	end

	-- 根据单位国籍决定是否显示特殊资源面板（AP/Mana）
	local nationality = unit:GetTemplate().nationality

	if table.contains(BattleConfig.ALCHEMIST_AP_UI, nationality) and unit:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self:InitAlchemistAPView()
	end

	if table.contains(BattleConfig.YUMIA_MANA_UI, nationality) and unit:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self:InitAlchemistManaView()
	end
end

--- 潜艇被侦测事件
--- @param event BattleUnitEvent 事件对象
function BattleUIMediator.onSubmarineDetected(self, event)
	local submarine = event.Dispatcher

	if self._enemyHpBar:GetCurrentTarget() and self._enemyHpBar:GetCurrentTarget() == submarine and submarine:GetDiveDetected() == false then
		self._enemyHpBar:RemoveUnit()
	end
end

--- 移除单位事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onRemoveUnit(self, event)
	local unit = event.Data.unit
	local unitType = event.Data.type

	if unitType == BattleConst.UnitType.PLAYER_UNIT or unitType == BattleConst.UnitType.ENEMY_UNIT or unitType == BattleConst.UnitType.BOSS_UNIT then
		self:unregisterUnitEvent(unit)
	end

	if unitType == BattleConst.UnitType.ENEMY_UNIT and not unit:IsBoss() then
		self:unregisterNPCUnitEvent(unit)
	elseif unit:GetIFF() == BattleConfig.FRIENDLY_CODE and unit:IsMainFleetUnit() then
		self:unregisterPlayerMainUnitEvent(unit)
	end

	-- 如果当前血条目标因离开而移除，清除血条
	if event.Data.deadReason == BattleConst.UnitDeathReason.LEAVE and self._enemyHpBar:GetCurrentTarget() and self._enemyHpBar:GetCurrentTarget() == event.Data.unit then
		self._enemyHpBar:RemoveUnit(event.Data.deadReason)
	end
end

--- 倒计时更新事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onUpdateCountDown(self, event)
	self._timerView:SetCountDownText(self._dataProxy:GetCountDown())
end

--- 闪避计分更新事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onUpdateDodgemScore(self, event)
	local totalScore = event.Data.totalScore

	self._scoreBarView:UpdateScore(totalScore)
end

--- 闪避连击更新事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onUpdateDodgemCombo(self, event)
	local combo = event.Data.combo

	self._scoreBarView:UpdateCombo(combo)
end

--- 添加空袭图标事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onAddAirStrike(self, event)
	local index = event.Data.index
	local info = self._dataProxy:GetAirFighterInfo(index)

	self._airStrikeView:AppendIcon(index, info)
end

--- 移除空袭图标事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onRemoveAirStrike(self, event)
	local index = event.Data.index
	local info = self._dataProxy:GetAirFighterInfo(index)

	self._airStrikeView:RemoveIcon(index, info)
end

--- 空中支援标签更新事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onUpdateAirSupportLabel(self, event)
	local airFighterList = self._dataProxy:GetAirFighterList()
	local totalCount = 0

	for _, fighterInfo in ipairs(airFighterList) do
		totalCount = totalCount + fighterInfo.totalNumber
	end

	-- 没有飞机或有警告时隐藏空中支援标签，否则显示制空状态
	if totalCount == 0 or self._warningView:GetCount() > 0 then
		eachChild(self._airSupportTF, function(child)
			setActive(child, false)
		end)
	elseif self._airAdavantageTF then
		setActive(self._airAdavantageTF, true)
	end
end

--- 敌方潜艇数量更新事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onUpdateHostileSubmarine(self, event)
	local count = self._dataProxy:GetEnemySubmarineCount()

	self._warningView:UpdateHostileSubmarineCount(count)
	self:onUpdateAirSupportLabel()
end

--- 环境警告更新事件（炮击支援等）
--- @param event BattleEvent 事件对象
function BattleUIMediator.onUpdateEnvironmentWarning(self, event)
	if event.Data.isActive then
		self._warningView:ActiveWarning(self._warningView.WARNING_TYPE_ARTILLERY)
	else
		self._warningView:DeactiveWarning(self._warningView.WARNING_TYPE_ARTILLERY)
	end
end

--- 摄像机聚焦事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onCameraFocus(self, event)
	local focusData = event.Data

	if focusData.unit ~= nil then
		-- 聚焦到某个单位时，禁用UI组件并可能禁用技能浮窗
		local hasSkill = focusData.skill or false

		self:EnableComponent(false)
		self:EnableSkillFloat(hasSkill)
	else
		-- 延迟后恢复组件
		local totalDuration = focusData.duration + focusData.extraBulletTime

		LeanTween.delayedCall(self._ui._go, totalDuration, System.Action(function()
			self:EnableComponent(true)
			self:EnableSkillFloat(true)
		end))
	end
end

--- 显示立绘事件（CutIn）
--- @param event BattleEvent 事件对象
function BattleUIMediator.onShowPainting(self, event)
	local paintingData = event.Data

	self:ShowSkillPainting(paintingData.caster, paintingData.skill, paintingData.speed)
end

--- 子弹时间事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onBulletTime(self, event)
	local bulletTimeData = event.Data
	local key = bulletTimeData.key
	local rate = bulletTimeData.rate

	if rate then
		BattleVariable.AppendMapFactor(key, rate)
	else
		BattleVariable.RemoveMapFactor(key)
	end

	self._seaView:UpdateSpeedScaler()
end

--- 显示缓冲区事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onShowBuffer(self, event)
	local dist = event.Data.dist

	self._seaView:UpdateBufferAlpha(dist)
end

--- 手动潜艇切换事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onManualSubShift(self, event)
	local state = event.Data.state

	self._skillView:ShiftSubmarineManualButton(state)
end

--- 瞄准触点命中/取消事件
--- @param event BattleUnitEvent 事件对象
function BattleUIMediator.onPointHitSight(self, event)
	local eventID = event.ID

	if eventID == BattleUnitEvent.POINT_HIT_CHARGE then
		self._sightView:SetActive(true)

		self._updateViewList[self._sightView] = true
	elseif eventID == BattleUnitEvent.POINT_HIT_CANCEL then
		self._sightView:SetActive(false)

		self._updateViewList[self._sightView] = nil
	end
end

--- 舰队致盲事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onFleetBlind(self, event)
	local isBlind = event.Data.isBlind
	local fleet = event.Dispatcher

	if not self._inkView then
		self:InitInkView(fleet)
	end

	if isBlind then
		local unitList = fleet:GetUnitList()

		self._inkView:SetActive(true, unitList)
		self._skillView:HideSkillButton(true)

		self._updateViewList[self._inkView] = true
	else
		self._inkView:SetActive(false)
		self._skillView:HideSkillButton(false)

		self._updateViewList[self._inkView] = nil
	end
end

--- 舰队视野更新事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onFleetHorizonUpdate(self, event)
	if not self._inkView then
		return
	end

	local unitList = event.Dispatcher:GetUnitList()

	self._inkView:UpdateHollow(unitList)
end

--- 舰队属性更新事件（AP/Mana等特殊资源）
--- @param event BattleEvent 事件对象
function BattleUIMediator.onFleetAttrUpdate(self, event)
	if self._alchemistAP and event.Data.attr == self._alchemistAP:GetAttrName() then
		self._alchemistAP:UpdateAP(event.Data.value)
	end

	if self._alchemistMana and event.Data.attr == self._alchemistMana:GetAttrName() then
		self._alchemistMana:UpdateMana(event.Data.value)
	end
end

--- 添加UI特效事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.OnAddUIFX(self, event)
	local fxID = event.Data.FXID
	local position = event.Data.position
	local localScale = event.Data.localScale
	local orderDiff = event.Data.orderDiff

	self:AddUIFX(orderDiff, fxID, position, localScale)
end

--- 添加UI特效到指定位置
--- @param orderDiff number 层级偏移（>0为前景层）
--- @param fxID string 特效ID
--- @param position Vector3 世界坐标位置
--- @param localScale number|nil 本地缩放比例
function BattleUIMediator.AddUIFX(self, orderDiff, fxID, position, localScale)
	local fx = self._fxPool:GetFX(fxID)

	orderDiff = orderDiff or 1

	-- 判断是否为前景层
	local isFrontLayer = orderDiff > 0

	local canvasScale = self._ui:AddUIFX(fx, orderDiff)

	localScale = localScale or 1
	fx.transform.localScale = Vector3(localScale / canvasScale.x, localScale / canvasScale.y, localScale / canvasScale.z)

	pg.EffectMgr.GetInstance():PlayBattleEffect(fx, position, true)
end

--- 添加Boss出场警告UI（含暂停动画控制）
function BattleUIMediator.AddBossWarningUI(self)
	self._dataProxy:BlockManualCast(true)

	local resourceMgr = ys.Battle.BattleResourceManager.GetInstance()

	self._appearEffect = resourceMgr:InstBossWarningUI()

	local animator = self._appearEffect:GetComponent(typeof(Animator))
	local takeoverProcess = {
		Pause = function()
			animator.speed = 0
		end,
		Resume = function()
			animator.speed = 1
		end
	}

	self._state:SetTakeoverProcess(takeoverProcess)

	animator.speed = 1 / self._state:GetTimeScaleRate()

	setParent(self._appearEffect, self._ui.uiCanvas, false)
	self._appearEffect:GetComponent(typeof(DftAniEvent)):SetEndEvent(function(animFinished)
		self._userFleet:CoupleEncourage()
		self._dataProxy:BlockManualCast(false)
		self._state:ClearTakeoverProcess()
		resourceMgr:DestroyOb(self._appearEffect)

		self._appearEffect = nil
	end)
	SetActive(self._appearEffect, true)
end

--- 隐藏/显示交互按钮事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.OnHideButtons(self, event)
	local isActive = event.Data.isActive

	self._skillView:HideSkillButton(not isActive)
	SetActive(self._autoBtn.transform, isActive)
end

--- 编辑自定义警告标签事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onEditCustomWarning(self, event)
	local labelData = event.Data.labelData

	self._warningView:EditCustomWarning(labelData)
end

--- Gridman技能浮窗事件
--- @param event BattleEvent 事件对象
function BattleUIMediator.onGridmanSkillFloat(self, event)
	if not self._gridmanSkillFloat then
		local gridmanGo = ys.Battle.BattleResourceManager.GetInstance():InstGridmanSkillUI()

		self._gridmanSkillFloat = ys.Battle.BattleGridmanSkillFloatView.New(gridmanGo)

		setParent(gridmanGo, self._ui.uiCanvas, false)
	end

	local gridmanData = event.Data
	local floatType = gridmanData.type
	local IFF = gridmanData.IFF

	-- type=5 为融合浮窗，其他为普通技能浮窗
	if floatType == 5 then
		self._gridmanSkillFloat:DoFusionFloat(IFF)
	else
		self._gridmanSkillFloat:DoSkillFloat(floatType, IFF)
	end
end

--- 为单位注册技能浮窗和CutIn事件
--- @param unit BattleUnit 战斗单位
function BattleUIMediator.registerUnitEvent(self, unit)
	unit:RegisterEventListener(self, BattleUnitEvent.SKILL_FLOAT, self.onSkillFloat)
	unit:RegisterEventListener(self, BattleUnitEvent.CUT_INT, self.onShowPainting)
end

--- 为NPC单位注册HP更新和潜艇侦测事件
--- @param unit BattleUnit 敌方单位
function BattleUIMediator.registerNPCUnitEvent(self, unit)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onEnemyHpUpdate)

	local shipType = unit:GetTemplate().type

	if table.contains(ShipType.SubShipType, shipType) then
		unit:RegisterEventListener(self, BattleUnitEvent.SUBMARINE_DETECTED, self.onSubmarineDetected)
	end
end

--- 为玩家主力舰注册HP更新事件
--- @param unit BattleUnit 玩家主力单位
function BattleUIMediator.registerPlayerMainUnitEvent(self, unit)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onPlayerMainUnitHpUpdate)
end

--- 取消单位的技能浮窗和CutIn事件
--- @param unit BattleUnit 战斗单位
function BattleUIMediator.unregisterUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.SKILL_FLOAT)
	unit:UnregisterEventListener(self, BattleUnitEvent.CUT_INT)
end

--- 取消NPC单位的所有事件注册
--- @param unit BattleUnit 敌方单位
function BattleUIMediator.unregisterNPCUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.SKILL_FLOAT)
	unit:UnregisterEventListener(self, BattleUnitEvent.CUT_INT)
	unit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)

	local shipType = unit:GetTemplate().type

	if table.contains(ShipType.SubShipType, shipType) then
		unit:UnregisterEventListener(self, BattleUnitEvent.SUBMARINE_DETECTED)
	end
end

--- 取消玩家主力舰的HP更新事件
--- @param unit BattleUnit 玩家主力单位
function BattleUIMediator.unregisterPlayerMainUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)
end

--- 销毁中介者，清理所有UI和事件
function BattleUIMediator.Dispose(self)
	LeanTween.cancel(self._ui._go)
	self._uiMGR:ClearStick()

	self._uiMGR = nil

	if self._appearEffect then
		Destroy(self._appearEffect)
	end

	self:RemoveUIEvent()

	self._updateViewList = nil

	self._timerView:Dispose()
	self._enemyHpBar:Dispose()
	self._skillView:Dispose()
	self._seaView:Dispose()
	self._airStrikeView:Dispose()
	self._sightView:Dispose()
	self._mainDamagedView:Dispose()
	self._warningView:Dispose()

	self._seaView = nil
	self._enemyHpBar = nil
	self._skillView = nil
	self._timerView = nil
	self._joystick = nil
	self._airStrikeView = nil
	self._warningView = nil
	self._mainDamagedView = nil

	if self._duelRateBar then
		self._duelRateBar:Dispose()

		self._duelRateBar = nil
	end

	if self._simulationBuffCountView then
		self._simulationBuffCountView:Dispose()

		self._simulationBuffCountView = nil
	end

	if self._jammingView then
		self._jammingView:Dispose()

		self._jammingView = nil
	end

	if self._inkView then
		self._inkView:Dispose()

		self._inkView = nil
	end

	if self._alchemistAP then
		self._alchemistAP:Dispose()

		self._alchemistAP = nil
	end

	if self._alchemistMana then
		self._alchemistMana:Dispose()

		self._alchemistMana = nil
	end

	if self._gridmanSkillFloat then
		self._gridmanSkillFloat:Dispose()
	end

	if go(self._ui._tf:Find("CardPuzzleConsole")).activeSelf then
		self:DisposeCardPuzzleComponent()
	end

	BattleUIMediator.super.Dispose(self)
end

--- 卡牌战斗初始化事件
--- @param event BattleCardPuzzleEvent 事件对象
function BattleUIMediator.OnCardPuzzleInit(self, event)
	self._cardPuzzleComponent = self._dataProxy:GetFleetByIFF(BattleConfig.FRIENDLY_CODE):GetCardPuzzleComponent()

	self:ShowCardPuzzleComponent()
	self:RegisterCardPuzzleEvent()
end

--- 注册卡牌战斗相关事件
function BattleUIMediator.RegisterCardPuzzleEvent(self)
	self._cardPuzzleComponent:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_FLEET_SHIP, self.onUpdateFleetShip)
	self._cardPuzzleComponent:RegisterEventListener(self, BattleCardPuzzleEvent.COMMON_BUTTON_ENABLE, self.onBlockCommonButton)
	self._cardPuzzleComponent:RegisterEventListener(self, BattleCardPuzzleEvent.LONG_PRESS_BULLET_TIME, self.onLongPressBulletTime)
	self._cardPuzzleComponent:RegisterEventListener(self, BattleCardPuzzleEvent.SHOW_CARD_DETAIL, self.onShowCardDetail)
end

--- 显示卡牌战斗所有UI组件
function BattleUIMediator.ShowCardPuzzleComponent(self)
	setActive(self._ui._tf:Find("CardPuzzleConsole"), true)
	self:InitCardPuzzleCommonHPBar()
	self:InitCardPuzzleEnergyBar()
	self:IntCardPuzzleFleetHead()
	self:InitCameraCardBoardClicker()
	self:InitCardPuzzleMovePile()
	self:InitCardPuzzleDeckPile()
	self:InitCardPuzzleIconList()
	self:InitCardPuzzleHandBoard()
	self:InitCardPuzzleCardDetail()
	self:InitCardPuzzleGoalRemind()
end

--- 初始化卡牌战斗通用HP条
function BattleUIMediator.InitCardPuzzleCommonHPBar(self)
	self._cardPuzzleHPBar = ys.Battle.CardPuzzleCommonHPBar.New(self._ui._tf:Find("CardPuzzleConsole/commonHP"))

	self._cardPuzzleHPBar:SetCardPuzzleComponent(self._cardPuzzleComponent)

	self._updateViewList[self._cardPuzzleHPBar] = true
end

--- 初始化卡牌战斗能量条
function BattleUIMediator.InitCardPuzzleEnergyBar(self)
	self._cardPuzzleEnergyBar = ys.Battle.CardPuzzleEnergyBar.New(self._ui._tf:Find("CardPuzzleConsole/energy_block"))

	self._cardPuzzleEnergyBar:SetCardPuzzleComponent(self._cardPuzzleComponent)

	self._updateViewList[self._cardPuzzleEnergyBar] = true
end

--- 初始化卡牌棋盘点击控制器
function BattleUIMediator.InitCameraCardBoardClicker(self)
	self._cardPuzzleBoardClicker = ys.Battle.CardPuzzleBoardClicker.New(self._ui._tf:Find("CardBoardController"))

	self._cardPuzzleBoardClicker:SetCardPuzzleComponent(self._cardPuzzleComponent)
end

--- 初始化卡牌战斗舰队头像
function BattleUIMediator.IntCardPuzzleFleetHead(self)
	self._cardPuzzleFleetHead = ys.Battle.CardPuzzleFleetHead.New(self._ui._tf:Find("CardPuzzleConsole/fleet"))

	self._cardPuzzleFleetHead:SetCardPuzzleComponent(self._cardPuzzleComponent)
end

--- 初始化卡牌战斗移动牌堆
function BattleUIMediator.InitCardPuzzleMovePile(self)
	self._cardPuzzleMovePile = ys.Battle.CardPuzzleMovePile.New(self._ui._tf:Find("CardPuzzleConsole/movedeck"))

	self._cardPuzzleMovePile:SetCardPuzzleComponent(self._cardPuzzleComponent)

	self._updateViewList[self._cardPuzzleMovePile] = true
end

--- 初始化卡牌战斗牌库
function BattleUIMediator.InitCardPuzzleDeckPile(self)
	self._cardPuzzleDeckPile = ys.Battle.CardPuzzleDeckPool.New(self._ui._tf:Find("CardPuzzleConsole/deck"))

	self._cardPuzzleDeckPile:SetCardPuzzleComponent(self._cardPuzzleComponent)
end

--- 初始化卡牌战斗状态图标列表
function BattleUIMediator.InitCardPuzzleIconList(self)
	self._cardPuzzleStatusIcon = ys.Battle.CardPuzzleFleetIconList.New(self._ui._tf:Find("CardPuzzleConsole/statusIcon"))

	self._cardPuzzleStatusIcon:SetCardPuzzleComponent(self._cardPuzzleComponent)

	self._updateViewList[self._cardPuzzleStatusIcon] = true
end

--- 初始化卡牌战斗手牌面板
function BattleUIMediator.InitCardPuzzleHandBoard(self)
	self._cardPuzzleHandBoard = ys.Battle.CardPuzzleHandBoard.New(self._ui._tf:Find("CardPuzzleConsole/cardboard"), self._ui._tf:Find("CardPuzzleConsole/hand"))

	self._cardPuzzleHandBoard:SetCardPuzzleComponent(self._cardPuzzleComponent)

	self._updateViewList[self._cardPuzzleHandBoard] = true
end

--- 初始化卡牌战斗目标提示
function BattleUIMediator.InitCardPuzzleGoalRemind(self)
	self._cardPuzzleGoalRemind = ys.Battle.CardPuzzleGoalRemind.New(self._ui._tf:Find("CardPuzzleConsole/goal"))

	self._cardPuzzleGoalRemind:SetCardPuzzleComponent(self._cardPuzzleComponent)
end

--- 初始化卡牌详情面板
function BattleUIMediator.InitCardPuzzleCardDetail(self)
	self._cardPuzzleCardDetail = ys.Battle.CardPuzzleCardDetail.New(self._ui._tf:Find("CardPuzzleConsole/cardDetail"))
end

--- 销毁所有卡牌战斗UI组件
function BattleUIMediator.DisposeCardPuzzleComponent(self)
	self._cardPuzzleHPBar:Dispose()
	self._cardPuzzleEnergyBar:Dispose()
	self._cardPuzzleBoardClicker:Dispose()
	self._cardPuzzleFleetHead:Dispose()
	self._cardPuzzleMovePile:Dispose()
	self._cardPuzzleDeckPile:Dispose()
	self._cardPuzzleStatusIcon:Dispose()
	self._cardPuzzleHandBoard:Dispose()
	self._cardPuzzleGoalRemind:Dispose()
	self._cardPuzzleCardDetail:Dispose()
end

--- 舰队buff更新（暂未实现）
function BattleUIMediator.onUpdateFleetBuff(self)
	return
end

--- 舰队舰船更新事件
--- @param event BattleCardPuzzleEvent 事件对象
function BattleUIMediator.onUpdateFleetShip(self, event)
	self._cardPuzzleFleetHead:UpdateShipIcon(event.Data.teamType)
end

--- 屏蔽/启用通用按钮事件
--- @param event BattleCardPuzzleEvent 事件对象
function BattleUIMediator.onBlockCommonButton(self, event)
	local flag = event.Data.flag

	self:EnableComponent(flag)
end

--- 长按子弹时间事件
--- @param event BattleCardPuzzleEvent 事件对象
function BattleUIMediator.onLongPressBulletTime(self, event)
	local timeScale = event.Data.timeScale

	self._state:ScaleTimer(timeScale)
end

--- 显示卡牌详情事件
--- @param event BattleCardPuzzleEvent 事件对象
function BattleUIMediator.onShowCardDetail(self, event)
	local card = event.Data.card

	if card then
		self._cardPuzzleCardDetail:Active(true)
		self._cardPuzzleCardDetail:SetReferenceCard(card)
	else
		self._cardPuzzleCardDetail:Active(false)
	end
end
