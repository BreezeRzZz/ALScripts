ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleSkillView = class("BattleSkillView")

local BattleSkillView = ys.Battle.BattleSkillView

BattleSkillView.__name = "BattleSkillView"

-- 主要是管理右下角的几个按钮(按照逻辑会对应到几个武器VO)
-- 在BattleUIMediator.onCommonInit中初始化
function BattleSkillView.Ctor(self, mediator)
	ys.EventListener.AttachEventListener(self)

	self._mediator = mediator
	self._ui = mediator._ui

	self:InitBtns()
	self:EnableWeaponButton(false)
end

function BattleSkillView.EnableWeaponButton(self, enabled)
	for _, skillBtn in ipairs(self._skillBtnList) do
		-- skillBtn: BattleWeaponButton
		skillBtn:Enabled(enabled)
	end
end

function BattleSkillView.DisableWeaponButton(self)
	for _, skillBtn in ipairs(self._skillBtnList) do
		skillBtn:Disable()
	end
end

function BattleSkillView.JamSkillButton(self, isJam)
	for _, skillBtn in ipairs(self._skillBtnList) do
		skillBtn:SetJam(isJam)
	end
end

-- 被BattleUIMediator.onManualSubShift调用
-- 这个按钮只用在破交作战中
function BattleSkillView.ShiftSubmarineManualButton(self, state)
	if state == ys.Battle.OxyState.STATE_FREE_FLOAT then
		self._diveBtn:SetActive(true)
		self._floatBtn:SetActive(false)
	elseif state == ys.Battle.OxyState.STATE_FREE_DIVE then
		self._diveBtn:SetActive(false)
		self._floatBtn:SetActive(true)
	end
end

-- 所有主要按钮的初始化, 以及回调函数的配置
-- 主要逻辑在这里
function BattleSkillView.InitBtns(self)
	self._skillBtnList = {}
	self._activeBtnList = {}
	self._delayAnimaList = {}
	self._fleetVO = self._mediator._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
	self._buttonContainer = self._ui._tf:Find("Weapon_button_container")
	self._buttonRes = self._ui._tf:Find("Weapon_button_Resource")

	local function ButtonEmptyTips()
		pg.TipsMgr.GetInstance():ShowTips(i18n("battle_emptyBlock"))
	end

	local function doNothing()
		return
	end

	local function onChargeButtonDown()
		if self._main_cannon_sound then
			self._main_cannon_sound:Stop(true)
		end

		self._main_cannon_sound = pg.CriMgr.GetInstance():PlaySE_V3("battle-cannon-main-prepared")

		self._fleetVO:CastChargeWeapon()
	end

	local function onChargeButtonUp()
		self._fleetVO:UnleashChrageWeapon()
	end

	local function onChargeButtonCancel()
		if self._main_cannon_sound then
			self._main_cannon_sound:Stop(true)
		end

		self._fleetVO:CancelChargeWeapon()
	end
	-- 跨射按钮
	self._chargeBtn = self:generateCommonButton(1)
	-- 对应BattleWeaponButton.ConfigCallback
	-- 四个函数分别对应: 按下, 抬起, 取消, 空按钮提示
	self._chargeBtn:ConfigCallback(onChargeButtonDown, onChargeButtonUp, onChargeButtonCancel, ButtonEmptyTips)

	local chargeWeaponVO = self._fleetVO:GetChargeWeaponVO()

	self._chargeBtn:SetProgressInfo(chargeWeaponVO)

	local function onTorpedoButtonDown()
		self._fleetVO:CastTorpedo()
	end

	local function onTorpedoButtonUp()
		self._fleetVO:UnleashTorpedo()
	end

	local function onTorpedoButtonCancel()
		self._fleetVO:CancelTorpedo()
	end

	self._torpedoBtn = self:generateCommonButton(2)

	self._torpedoBtn:ConfigCallback(onTorpedoButtonDown, onTorpedoButtonUp, onTorpedoButtonCancel, ButtonEmptyTips)

	local torpedoWeaponVO = self._fleetVO:GetTorpedoWeaponVO()

	self._torpedoBtn:SetProgressInfo(torpedoWeaponVO)

	local function onAirStrikeUp()
		self._fleetVO:UnleashAllInStrike(true)
	end

	self._airStrikeBtn = self:generateCommonButton(3)

	self._airStrikeBtn:ConfigCallback(doNothing, onAirStrikeUp, doNothing, ButtonEmptyTips)

	local airAssistVO = self._fleetVO:GetAirAssistVO()

	self._airStrikeBtn:SetProgressInfo(airAssistVO)

	local function onDiveButtonUp()
		self._fleetVO:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE, true)
	end
	-- 这个是破交模式下的下潜按钮
	self._diveBtn = self:generateSubmarineFuncButton(5)

	self._diveBtn:ConfigCallback(doNothing, onDiveButtonUp, doNothing, ButtonEmptyTips)

	local subFreeDiveVO = self._fleetVO:GetSubFreeDiveVO()

	self._diveBtn:SetProgressInfo(subFreeDiveVO)
	self._diveBtn:SetActive(false)

	local function onFloatButtonUp()
		self._fleetVO:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_FLOAT, true)
	end
	-- 破交模式下的上浮按钮
	self._floatBtn = self:generateSubmarineFuncButton(6)

	self._floatBtn:ConfigCallback(doNothing, onFloatButtonUp, doNothing, ButtonEmptyTips)

	local subFleetFloatVO = self._fleetVO:GetSubFreeFloatVO()

	self._floatBtn:SetProgressInfo(subFleetFloatVO)
	self._floatBtn:SetActive(false)

	local function onSubBoostButtonUp()
		self._fleetVO:SubmarinBoost()
	end
	-- 从回调来看，是加速按钮(但从来没出现过这个按钮)
	self._boostBtn = self:generateSubmarineFuncButton(7)

	self._boostBtn:ConfigCallback(doNothing, onSubBoostButtonUp, doNothing, ButtonEmptyTips)

	local subBoostVO = self._fleetVO:GetSubBoostVO()

	self._boostBtn:SetProgressInfo(subBoostVO)

	local function onSubSpecialButtonUp()
		self._fleetVO:UnleashSubmarineSpecial()
	end
	-- 破交作战中的潜艇弹幕发射按钮
	self._specialBtn = self:generateSubmarineButton(9)

	self._specialBtn:ConfigCallback(doNothing, onSubSpecialButtonUp, doNothing, ButtonEmptyTips)

	local subSpecialVO = self._fleetVO:GetSubSpecialVO()

	self._specialBtn:SetProgressInfo(subSpecialVO)

	local function onShiftSubButtonUp()
		self._fleetVO:ShiftManualSub()
	end
	-- 破交作战中的交换潜艇按钮
	self._shiftBtn = self:generateSubmarineFuncButton(8)

	self._shiftBtn:ConfigCallback(doNothing, onShiftSubButtonUp, doNothing, ButtonEmptyTips)

	local subShiftVO = self._fleetVO:GetSubShiftVO()

	self._shiftBtn:SetProgressInfo(subShiftVO)

	local submarineVO = self._fleetVO._submarineVO

	if submarineVO:GetUseable() and submarineVO:GetCount() > 0 then
		local function onSubStriveButtonUp()
			self._mediator._dataProxy:SubmarineStrike(ys.Battle.BattleConfig.FRIENDLY_CODE)
		end

		self._subStriveBtn = self:generateSubmarineButton(4)

		local subStriveButtonSkin = self._subStriveBtn:GetSkin()

		self.SetSkillButtonPreferences(subStriveButtonSkin, 4)
		self._subStriveBtn:ConfigCallback(doNothing, onSubStriveButtonUp, doNothing, ButtonEmptyTips)
		self._subStriveBtn:SetProgressInfo(submarineVO)
		table.insert(self._activeBtnList, self._subStriveBtn)
	end
	-- 这里又重新生成了一个鱼雷按钮, 是什么意思？无法理解(上面已经生成过了)
	local torpedoButton = ys.Battle.BattleWeaponButton.New()
	local buttonSkin = cloneTplTo(self._progressSkin, self._buttonContainer)

	self.SetSkillButtonPreferences(buttonSkin, 2)
	torpedoButton:ConfigSkin(buttonSkin)
	torpedoButton:SwitchIcon(10)
	torpedoButton:SwitchIconEffect(2)
	torpedoButton:ConfigCallback(onTorpedoButtonDown, onTorpedoButtonUp, onTorpedoButtonCancel, ButtonEmptyTips)
	table.insert(self._skillBtnList, torpedoButton)
	torpedoButton:SetProgressInfo(torpedoWeaponVO)
	torpedoButton:SetActive(false)
	self._boostBtn:SetActive(false)
	self._diveBtn:SetActive(false)
	self._floatBtn:SetActive(false)
	self._specialBtn:SetActive(false)
	self._shiftBtn:SetActive(false)
end

-- 生成普通按钮
function BattleSkillView.generateCommonButton(self, index)
	-- 作战主题
	local combatSkinKey = ys.Battle.BattleState.GetCombatSkinKey()
	local button
	-- 有些主题重写了整个按钮, 因此是可能存在逻辑变化的
	if ys.Battle["BattleWeaponButton" .. combatSkinKey] then
		button = ys.Battle["BattleWeaponButton" .. combatSkinKey].New()
	else
		button = ys.Battle.BattleWeaponButton.New()
	end
	-- 进度条皮肤
	self._progressSkin = self._progressSkin or self._ui._tf:Find("Weapon_button_progress")
	-- 
	local buttonSkin = cloneTplTo(self._progressSkin, self._buttonContainer)

	buttonSkin.name = "Skill_" .. index

	self.SetSkillButtonPreferences(buttonSkin, index)
	button:ConfigSkin(buttonSkin)
	button:SwitchIcon(index)
	button:SwitchIconEffect(index)
	button:SetTextActive(true)
	table.insert(self._skillBtnList, button)

	return button
end

function BattleSkillView.generateSubmarineFuncButton(arg_23_0, arg_23_1)
	local var_23_0 = ys.Battle.BattleSubmarineFuncButton.New()

	arg_23_0._progressSkin = arg_23_0._progressSkin or arg_23_0._ui._tf:Find("Weapon_button_progress")

	local var_23_1 = cloneTplTo(arg_23_0._progressSkin, arg_23_0._buttonContainer)

	var_23_0:ConfigSkin(var_23_1)
	var_23_0:SwitchIcon(arg_23_1)
	var_23_0:SetTextActive(false)
	table.insert(arg_23_0._skillBtnList, var_23_0)

	return var_23_0
end

function BattleSkillView.generateSubmarineButton(arg_24_0, arg_24_1)
	local var_24_0 = ys.Battle.BattleSubmarineButton.New()

	arg_24_0._disposableSkin = arg_24_0._disposableSkin or arg_24_0._ui._tf:Find("Weapon_button")

	local var_24_1 = cloneTplTo(arg_24_0._disposableSkin, arg_24_0._buttonContainer)

	var_24_0:ConfigSkin(var_24_1)
	var_24_0:SwitchIcon(arg_24_1)
	table.insert(arg_24_0._skillBtnList, var_24_0)

	return var_24_0
end

function BattleSkillView.CustomButton(arg_25_0, arg_25_1)
	for iter_25_0, iter_25_1 in ipairs(arg_25_1) do
		arg_25_0._skillBtnList[iter_25_1]:SetActive(false)
	end
end

function BattleSkillView.NormalButton(arg_26_0)
	arg_26_0._chargeBtn:SetActive(true)
	arg_26_0._torpedoBtn:SetActive(true)
	arg_26_0._airStrikeBtn:SetActive(true)
	arg_26_0._boostBtn:SetActive(false)
	arg_26_0._diveBtn:SetActive(false)
	arg_26_0._floatBtn:SetActive(false)
	arg_26_0._specialBtn:SetActive(false)
	arg_26_0._shiftBtn:SetActive(false)
	table.insert(arg_26_0._activeBtnList, arg_26_0._chargeBtn)
	table.insert(arg_26_0._activeBtnList, arg_26_0._torpedoBtn)
	table.insert(arg_26_0._activeBtnList, arg_26_0._airStrikeBtn)
	table.insert(arg_26_0._delayAnimaList, arg_26_0._chargeBtn)
	table.insert(arg_26_0._delayAnimaList, arg_26_0._torpedoBtn)
	table.insert(arg_26_0._delayAnimaList, arg_26_0._airStrikeBtn)

	if arg_26_0._subStriveBtn then
		table.insert(arg_26_0._delayAnimaList, arg_26_0._subStriveBtn)
	end
end

function BattleSkillView.SubmarineButton(arg_27_0)
	arg_27_0._chargeBtn:SetActive(false)
	arg_27_0._torpedoBtn:SetActive(true)
	arg_27_0._airStrikeBtn:SetActive(false)
	arg_27_0._boostBtn:SetActive(true)
	arg_27_0._diveBtn:SetActive(true)
	arg_27_0._floatBtn:SetActive(true)
	table.insert(arg_27_0._activeBtnList, arg_27_0._diveBtn)
	table.insert(arg_27_0._activeBtnList, arg_27_0._torpedoBtn)
	table.insert(arg_27_0._activeBtnList, arg_27_0._boostBtn)
	table.insert(arg_27_0._activeBtnList, arg_27_0._floatBtn)
	table.insert(arg_27_0._delayAnimaList, arg_27_0._floatBtn)
	table.insert(arg_27_0._delayAnimaList, arg_27_0._torpedoBtn)
	table.insert(arg_27_0._delayAnimaList, arg_27_0._boostBtn)

	local var_27_0 = arg_27_0._torpedoBtn:GetSkin().transform
	local var_27_1 = BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[2]

	var_27_0.anchorMin = Vector2(var_27_1.x, var_27_1.y)
	var_27_0.anchorMax = Vector2(var_27_1.x, var_27_1.y)
end

function BattleSkillView.SubRoutineButton(arg_28_0)
	arg_28_0._chargeBtn:SetActive(false)
	arg_28_0._torpedoBtn:SetActive(true)
	arg_28_0._airStrikeBtn:SetActive(false)
	arg_28_0._boostBtn:SetActive(false)
	arg_28_0._diveBtn:SetActive(true)
	arg_28_0._floatBtn:SetActive(true)
	arg_28_0._specialBtn:SetActive(true)
	arg_28_0._shiftBtn:SetActive(true)
	table.insert(arg_28_0._activeBtnList, arg_28_0._diveBtn)
	table.insert(arg_28_0._activeBtnList, arg_28_0._torpedoBtn)
	table.insert(arg_28_0._activeBtnList, arg_28_0._specialBtn)
	table.insert(arg_28_0._activeBtnList, arg_28_0._floatBtn)
	table.insert(arg_28_0._activeBtnList, arg_28_0._shiftBtn)
	table.insert(arg_28_0._delayAnimaList, arg_28_0._floatBtn)
	table.insert(arg_28_0._delayAnimaList, arg_28_0._torpedoBtn)
	table.insert(arg_28_0._delayAnimaList, arg_28_0._shiftBtn)
	table.insert(arg_28_0._delayAnimaList, arg_28_0._specialBtn)
	arg_28_0.SetSkillButtonPreferences(arg_28_0._diveBtn:GetSkin(), 1)
	arg_28_0.SetSkillButtonPreferences(arg_28_0._floatBtn:GetSkin(), 1)
	arg_28_0.SetSkillButtonPreferences(arg_28_0._torpedoBtn:GetSkin(), 2)
	arg_28_0.SetSkillButtonPreferences(arg_28_0._shiftBtn:GetSkin(), 3)
	arg_28_0.SetSkillButtonPreferences(arg_28_0._specialBtn:GetSkin(), 4)
end

function BattleSkillView.AirFightButton(arg_29_0)
	local var_29_0 = {
		9
	}

	for iter_29_0, iter_29_1 in ipairs(arg_29_0._skillBtnList) do
		local var_29_1 = table.indexof(var_29_0, iter_29_0)

		iter_29_1:SetActive(var_29_1)

		if var_29_1 then
			table.insert(arg_29_0._activeBtnList, iter_29_1)
			arg_29_0.SetSkillButtonPreferences(iter_29_1:GetSkin(), var_29_1)
		end
	end
end

function BattleSkillView.ButtonInitialAnima(arg_30_0)
	for iter_30_0, iter_30_1 in ipairs(arg_30_0._delayAnimaList) do
		iter_30_1:InitialAnima(iter_30_0 * 0.2)
	end
end

function BattleSkillView.CardPuzzleButton(arg_31_0)
	arg_31_0._chargeBtn:SetActive(false)
	arg_31_0._torpedoBtn:SetActive(false)
	arg_31_0._airStrikeBtn:SetActive(false)
	arg_31_0._boostBtn:SetActive(false)
	arg_31_0._diveBtn:SetActive(false)
	arg_31_0._floatBtn:SetActive(false)
	arg_31_0._specialBtn:SetActive(false)
	arg_31_0._shiftBtn:SetActive(false)
end

function BattleSkillView.HideSkillButton(arg_32_0, arg_32_1)
	for iter_32_0, iter_32_1 in ipairs(arg_32_0._activeBtnList) do
		iter_32_1:SetActive(not arg_32_1)
	end
end

function BattleSkillView.OnSkillCd(arg_33_0, arg_33_1)
	local var_33_0 = arg_33_1.Data.skillID
	local var_33_1 = arg_33_1.Data.coolDownTime

	if var_33_1 < pg.TimeMgr.GetInstance():GetCombatTime() then
		return
	end

	arg_33_0._skillCd[var_33_0] = var_33_1
end

function BattleSkillView.Dispose(arg_34_0)
	arg_34_0._delayAnimaList = nil
	arg_34_0._activeBtnList = nil

	for iter_34_0, iter_34_1 in ipairs(arg_34_0._skillBtnList) do
		iter_34_1:Dispose()
	end

	arg_34_0._ui = nil

	if arg_34_0._main_cannon_sound then
		arg_34_0._main_cannon_sound:Stop(true)

		arg_34_0._main_cannon_sound = nil
	end

	ys.EventListener.DetachEventListener(arg_34_0)
end

function BattleSkillView.Update(arg_35_0)
	for iter_35_0, iter_35_1 in ipairs(arg_35_0._skillBtnList) do
		iter_35_1:Update()
	end
end

function BattleSkillView.SetSkillButtonPreferences(arg_36_0, arg_36_1)
	local var_36_0 = BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[arg_36_1]
	local var_36_1 = PlayerPrefs.GetFloat("skill_" .. arg_36_1 .. "_scale", var_36_0.scale)
	local var_36_2 = PlayerPrefs.GetFloat("skill_" .. arg_36_1 .. "_anchorX", var_36_0.x)
	local var_36_3 = PlayerPrefs.GetFloat("skill_" .. arg_36_1 .. "_anchorY", var_36_0.y)
	local var_36_4 = arg_36_0.transform

	var_36_4.localScale = Vector3(var_36_1, var_36_1, 0)
	var_36_4.anchorMin = Vector2(var_36_2, var_36_3)
	var_36_4.anchorMax = Vector2(var_36_2, var_36_3)
end
