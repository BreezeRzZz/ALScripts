ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleSkillView = class("BattleSkillView")

local BattleSkillView = ys.Battle.BattleSkillView

BattleSkillView.__name = "BattleSkillView"

--- 构造函数
--- @class BattleSkillView
--- @param mediator BattleUIMediator 战斗UI中介者
function BattleSkillView.Ctor(self, mediator)
	ys.EventListener.AttachEventListener(self)

	self._mediator = mediator
	self._ui = mediator._ui

	self:InitBtns()
	self:EnableWeaponButton(false)
end

--- 启用/禁用所有武器按钮
--- @param enable boolean
function BattleSkillView.EnableWeaponButton(self, enable)
	for _, btn in ipairs(self._skillBtnList) do
		btn:Enabled(enable)
	end
end

--- 禁用所有武器按钮
function BattleSkillView.DisableWeapnButton(self)
	for _, btn in ipairs(self._skillBtnList) do
		btn:Disable()
	end
end

--- 设置所有技能按钮的干扰状态
--- @param isJam boolean
function BattleSkillView.JamSkillButton(self, isJam)
	for _, btn in ipairs(self._skillBtnList) do
		btn:SetJam(isJam)
	end
end

--- 手动切换潜艇上浮/下潜按钮的显示
--- @param state number OxyState状态常量
function BattleSkillView.ShiftSubmarineManualButton(self, state)
	if state == ys.Battle.OxyState.STATE_FREE_FLOAT then
		self._diveBtn:SetActive(true)
		self._floatBtn:SetActive(false)
	elseif state == ys.Battle.OxyState.STATE_FREE_DIVE then
		self._diveBtn:SetActive(false)
		self._floatBtn:SetActive(true)
	end
end

--- 初始化所有按钮（主炮、鱼雷、空袭、潜艇功能、特殊武器等）
function BattleSkillView.InitBtns(self)
	self._skillBtnList = {}
	self._activeBtnList = {}
	self._delayAnimaList = {}
	self._fleetVO = self._mediator._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
	self._buttonContainer = self._ui._tf:Find("Weapon_button_container")
	self._buttonRes = self._ui._tf:Find("Weapon_button_Resource")

	-- 空槽点击提示
	local function emptyTipFunc()
		pg.TipsMgr.GetInstance():ShowTips(i18n("battle_emptyBlock"))
	end

	-- 空操作（无实际逻辑）
	local function noopFunc()
		return
	end

	-- 主炮按下：播放准备音效，进入蓄力状态
	local function chargeDownFunc()
		if self._main_cannon_sound then
			self._main_cannon_sound:Stop(true)
		end

		self._main_cannon_sound = pg.CriMgr.GetInstance():PlaySE_V3("battle-cannon-main-prepared")

		self._fleetVO:CastChargeWeapon()
	end

	-- 主炮释放：开火
	local function chargeUpFunc()
		self._fleetVO:UnleashChrageWeapon()
	end

	-- 主炮取消：松手取消蓄力
	local function chargeCancelFunc()
		if self._main_cannon_sound then
			self._main_cannon_sound:Stop(true)
		end

		self._fleetVO:CancelChargeWeapon()
	end

	self._chargeBtn = self:generateCommonButton(1)

	self._chargeBtn:ConfigCallback(chargeDownFunc, chargeUpFunc, chargeCancelFunc, emptyTipFunc)

	local chargeVO = self._fleetVO:GetChargeWeaponVO()

	self._chargeBtn:SetProgressInfo(chargeVO)

	-- 鱼雷按钮回调
	local function torpedoDownFunc()
		self._fleetVO:CastTorpedo()
	end

	local function torpedoUpFunc()
		self._fleetVO:UnleashTorpedo()
	end

	local function torpedoCancelFunc()
		self._fleetVO:CancelTorpedo()
	end

	self._torpedoBtn = self:generateCommonButton(2)

	self._torpedoBtn:ConfigCallback(torpedoDownFunc, torpedoUpFunc, torpedoCancelFunc, emptyTipFunc)

	local torpedoVO = self._fleetVO:GetTorpedoWeaponVO()

	self._torpedoBtn:SetProgressInfo(torpedoVO)

	-- 空袭按钮回调
	local function airstrikeFunc()
		self._fleetVO:UnleashAllInStrike(true)
	end

	self._airStrikeBtn = self:generateCommonButton(3)

	self._airStrikeBtn:ConfigCallback(noopFunc, airstrikeFunc, noopFunc, emptyTipFunc)

	local airAssistVO = self._fleetVO:GetAirAssistVO()

	self._airStrikeBtn:SetProgressInfo(airAssistVO)

	-- 下潜按钮回调
	local function diveFunc()
		self._fleetVO:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE, true)
	end

	self._diveBtn = self:generateSubmarineFuncButton(5)

	self._diveBtn:ConfigCallback(noopFunc, diveFunc, noopFunc, emptyTipFunc)

	local subFreeDiveVO = self._fleetVO:GetSubFreeDiveVO()

	self._diveBtn:SetProgressInfo(subFreeDiveVO)
	self._diveBtn:SetActive(false)

	-- 上浮按钮回调
	local function floatFunc()
		self._fleetVO:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_FLOAT, true)
	end

	self._floatBtn = self:generateSubmarineFuncButton(6)

	self._floatBtn:ConfigCallback(noopFunc, floatFunc, noopFunc, emptyTipFunc)

	local subFreeFloatVO = self._fleetVO:GetSubFreeFloatVO()

	self._floatBtn:SetProgressInfo(subFreeFloatVO)
	self._floatBtn:SetActive(false)

	-- 潜艇加速按钮回调
	local function boostFunc()
		self._fleetVO:SubmarinBoost()
	end

	self._boostBtn = self:generateSubmarineFuncButton(7)

	self._boostBtn:ConfigCallback(noopFunc, boostFunc, noopFunc, emptyTipFunc)

	local subBoostVO = self._fleetVO:GetSubBoostVO()

	self._boostBtn:SetProgressInfo(subBoostVO)

	-- 潜艇特殊攻击按钮回调
	local function subSpecialFunc()
		self._fleetVO:UnleashSubmarineSpecial()
	end

	self._specialBtn = self:generateSubmarineButton(9)

	self._specialBtn:ConfigCallback(noopFunc, subSpecialFunc, noopFunc, emptyTipFunc)

	local subSpecialVO = self._fleetVO:GetSubSpecialVO()

	self._specialBtn:SetProgressInfo(subSpecialVO)

	-- 手动潜艇切换按钮回调
	local function shiftSubFunc()
		self._fleetVO:ShiftManualSub()
	end

	self._shiftBtn = self:generateSubmarineFuncButton(8)

	self._shiftBtn:ConfigCallback(noopFunc, shiftSubFunc, noopFunc, emptyTipFunc)

	local subShiftVO = self._fleetVO:GetSubShiftVO()

	self._shiftBtn:SetProgressInfo(subShiftVO)

	local submarineVO = self._fleetVO._submarineVO

	-- 如果潜艇可用且有数量，创建潜艇出击按钮
	if submarineVO:GetUseable() and submarineVO:GetCount() > 0 then
		local function subStrikeFunc()
			self._mediator._dataProxy:SubmarineStrike(ys.Battle.BattleConfig.FRIENDLY_CODE)
		end

		self._subStriveBtn = self:generateSubmarineButton(4)

		local subStrikeSkin = self._subStriveBtn:GetSkin()

		self.SetSkillButtonPreferences(subStrikeSkin, 4)
		self._subStriveBtn:ConfigCallback(noopFunc, subStrikeFunc, noopFunc, emptyTipFunc)
		self._subStriveBtn:SetProgressInfo(submarineVO)
		table.insert(self._activeBtnList, self._subStriveBtn)
	end

	-- 创建防空导弹按钮（图标索引10，鱼雷回调复用）
	local aaMissileBtn = ys.Battle.BattleWeaponButton.New()
	local aaMissileSkin = cloneTplTo(self._progressSkin, self._buttonContainer)

	self.SetSkillButtonPreferences(aaMissileSkin, 2)
	aaMissileBtn:ConfigSkin(aaMissileSkin)
	aaMissileBtn:SwitchIcon(10)
	aaMissileBtn:SwitchIconEffect(2)
	aaMissileBtn:ConfigCallback(torpedoDownFunc, torpedoUpFunc, torpedoCancelFunc, emptyTipFunc)
	table.insert(self._skillBtnList, aaMissileBtn)
	aaMissileBtn:SetProgressInfo(torpedoVO)
	aaMissileBtn:SetActive(false)
	self._boostBtn:SetActive(false)
	self._diveBtn:SetActive(false)
	self._floatBtn:SetActive(false)
	self._specialBtn:SetActive(false)
	self._shiftBtn:SetActive(false)
end

--- 生成通用武器按钮（带进度条皮肤）
--- @param index number 按钮索引（决定图标和位置偏好）
--- @return BattleWeaponButton
function BattleSkillView.generateCommonButton(self, index)
	local skinKey = ys.Battle.BattleState.GetCombatSkinKey()
	local btn

	-- 尝试使用皮肤特化按钮类
	if ys.Battle["BattleWeaponButton" .. skinKey] then
		btn = ys.Battle["BattleWeaponButton" .. skinKey].New()
	else
		btn = ys.Battle.BattleWeaponButton.New()
	end

	self._progressSkin = self._progressSkin or self._ui._tf:Find("Weapon_button_progress")

	local skinObj = cloneTplTo(self._progressSkin, self._buttonContainer)

	skinObj.name = "Skill_" .. index

	self.SetSkillButtonPreferences(skinObj, index)
	btn:ConfigSkin(skinObj)
	btn:SwitchIcon(index)
	btn:SwitchIconEffect(index)
	btn:SetTextActive(true)
	table.insert(self._skillBtnList, btn)

	return btn
end

--- 生成潜艇功能按钮（不带进度条文本，无图标）
--- 支持皮肤特化按钮类
--- @param index number 按钮索引
--- @return BattleSubmarineFuncButton
function BattleSkillView.generateSubmarineFuncButton(self, index)
	local skinKey = ys.Battle.BattleState.GetCombatSkinKey()
	local btn

	if ys.Battle["BattleSubmarineFuncButton" .. skinKey] then
		btn = ys.Battle["BattleSubmarineFuncButton" .. skinKey].New()
	else
		btn = ys.Battle.BattleSubmarineFuncButton.New()
	end

	self._progressSkin = self._progressSkin or self._ui._tf:Find("Weapon_button_progress")

	local skinObj = cloneTplTo(self._progressSkin, self._buttonContainer)

	btn:ConfigSkin(skinObj)
	btn:SwitchIcon(index)
	btn:SetTextActive(false)
	table.insert(self._skillBtnList, btn)

	return btn
end

--- 生成潜艇按钮（带一次性皮肤）
--- 支持皮肤特化按钮类
--- @param index number 按钮索引
--- @return BattleSubmarineButton
function BattleSkillView.generateSubmarineButton(self, index)
	local skinKey = ys.Battle.BattleState.GetCombatSkinKey()
	local btn

	if ys.Battle["BattleSubmarineButton" .. skinKey] then
		btn = ys.Battle["BattleSubmarineButton" .. skinKey].New()
	else
		btn = ys.Battle.BattleSubmarineButton.New()
	end

	self._disposableSkin = self._disposableSkin or self._ui._tf:Find("Weapon_button")

	local skinObj = cloneTplTo(self._disposableSkin, self._buttonContainer)

	btn:ConfigSkin(skinObj)
	btn:SwitchIcon(index)
	table.insert(self._skillBtnList, btn)

	return btn
end

--- 根据关卡配置隐藏指定索引的技能按钮
--- @param hideList number[] 需隐藏的按钮索引列表
function BattleSkillView.CustomButton(self, hideList)
	for _, index in ipairs(hideList) do
		self._skillBtnList[index]:SetActive(false)
	end
end

--- 普通按钮布局（主线/活动关卡）
function BattleSkillView.NormalButton(self)
	self._chargeBtn:SetActive(true)
	self._torpedoBtn:SetActive(true)
	self._airStrikeBtn:SetActive(true)
	self._boostBtn:SetActive(false)
	self._diveBtn:SetActive(false)
	self._floatBtn:SetActive(false)
	self._specialBtn:SetActive(false)
	self._shiftBtn:SetActive(false)
	table.insert(self._activeBtnList, self._chargeBtn)
	table.insert(self._activeBtnList, self._torpedoBtn)
	table.insert(self._activeBtnList, self._airStrikeBtn)
	table.insert(self._delayAnimaList, self._chargeBtn)
	table.insert(self._delayAnimaList, self._torpedoBtn)
	table.insert(self._delayAnimaList, self._airStrikeBtn)

	if self._subStriveBtn then
		table.insert(self._delayAnimaList, self._subStriveBtn)
	end
end

--- 潜艇关卡按钮布局
function BattleSkillView.SubmarineButton(self)
	self._chargeBtn:SetActive(false)
	self._torpedoBtn:SetActive(true)
	self._airStrikeBtn:SetActive(false)
	self._boostBtn:SetActive(true)
	self._diveBtn:SetActive(true)
	self._floatBtn:SetActive(true)
	table.insert(self._activeBtnList, self._diveBtn)
	table.insert(self._activeBtnList, self._torpedoBtn)
	table.insert(self._activeBtnList, self._boostBtn)
	table.insert(self._activeBtnList, self._floatBtn)
	table.insert(self._delayAnimaList, self._floatBtn)
	table.insert(self._delayAnimaList, self._torpedoBtn)
	table.insert(self._delayAnimaList, self._boostBtn)

	-- 设置鱼雷按钮在潜艇关卡的特定锚点位置
	local torpedoTransform = self._torpedoBtn:GetSkin().transform
	local defaultPref = BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[2]

	torpedoTransform.anchorMin = Vector2(defaultPref.x, defaultPref.y)
	torpedoTransform.anchorMax = Vector2(defaultPref.x, defaultPref.y)
end

--- 潜艇日常按钮布局
function BattleSkillView.SubRoutineButton(self)
	self._chargeBtn:SetActive(false)
	self._torpedoBtn:SetActive(true)
	self._airStrikeBtn:SetActive(false)
	self._boostBtn:SetActive(false)
	self._diveBtn:SetActive(true)
	self._floatBtn:SetActive(true)
	self._specialBtn:SetActive(true)
	self._shiftBtn:SetActive(true)
	table.insert(self._activeBtnList, self._diveBtn)
	table.insert(self._activeBtnList, self._torpedoBtn)
	table.insert(self._activeBtnList, self._specialBtn)
	table.insert(self._activeBtnList, self._floatBtn)
	table.insert(self._activeBtnList, self._shiftBtn)
	table.insert(self._delayAnimaList, self._floatBtn)
	table.insert(self._delayAnimaList, self._torpedoBtn)
	table.insert(self._delayAnimaList, self._shiftBtn)
	table.insert(self._delayAnimaList, self._specialBtn)
	self.SetSkillButtonPreferences(self._diveBtn:GetSkin(), 1)
	self.SetSkillButtonPreferences(self._floatBtn:GetSkin(), 1)
	self.SetSkillButtonPreferences(self._torpedoBtn:GetSkin(), 2)
	self.SetSkillButtonPreferences(self._shiftBtn:GetSkin(), 3)
	self.SetSkillButtonPreferences(self._specialBtn:GetSkin(), 4)
end

--- 空战按钮布局（仅显示特殊攻击按钮，索引9）
function BattleSkillView.AirFightButton(self)
	local visibleIndices = {
		9
	}

	for index, btn in ipairs(self._skillBtnList) do
		local arrayIndex = table.indexof(visibleIndices, index)

		btn:SetActive(arrayIndex)

		if arrayIndex then
			table.insert(self._activeBtnList, btn)
			self.SetSkillButtonPreferences(btn:GetSkin(), arrayIndex)
		end
	end
end

--- 按钮入场动画（按索引延迟播放）
function BattleSkillView.ButtonInitialAnima(self)
	for index, btn in ipairs(self._delayAnimaList) do
		btn:InitialAnima(index * 0.2)
	end
end

--- 卡牌战斗按钮布局（全部隐藏）
function BattleSkillView.CardPuzzleButton(self)
	self._chargeBtn:SetActive(false)
	self._torpedoBtn:SetActive(false)
	self._airStrikeBtn:SetActive(false)
	self._boostBtn:SetActive(false)
	self._diveBtn:SetActive(false)
	self._floatBtn:SetActive(false)
	self._specialBtn:SetActive(false)
	self._shiftBtn:SetActive(false)
end

--- 隐藏/显示所有活跃的武器按钮
--- @param hide boolean true=隐藏, false=显示
function BattleSkillView.HideSkillButton(self, hide)
	for _, btn in ipairs(self._activeBtnList) do
		btn:SetActive(not hide)
	end
end

--- 技能冷却事件
--- @param event BattleEvent
function BattleSkillView.OnSkillCd(self, event)
	local skillID = event.Data.skillID
	local coolDownTime = event.Data.coolDownTime

	-- 已过冷却时间则忽略
	if coolDownTime < pg.TimeMgr.GetInstance():GetCombatTime() then
		return
	end

	self._skillCd[skillID] = coolDownTime
end

--- 销毁所有按钮和事件
function BattleSkillView.Dispose(self)
	self._delayAnimaList = nil
	self._activeBtnList = nil

	for _, btn in ipairs(self._skillBtnList) do
		btn:Dispose()
	end

	self._ui = nil

	if self._main_cannon_sound then
		self._main_cannon_sound:Stop(true)

		self._main_cannon_sound = nil
	end

	ys.EventListener.DetachEventListener(self)
end

--- 每帧更新所有技能按钮的进度条
function BattleSkillView.Update(self)
	for _, btn in ipairs(self._skillBtnList) do
		btn:Update()
	end
end

--- 设置技能按钮的位置偏好（从PlayerPrefs读取保存的锚点和缩放）
--- @param skin Transform 按钮皮肤Transform引用
--- @param index number 按钮索引
function BattleSkillView.SetSkillButtonPreferences(self, skin, index)
	local defaultPref = BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[index]
	local savedScale = PlayerPrefs.GetFloat("skill_" .. index .. "_scale", defaultPref.scale)
	local savedAnchorX = PlayerPrefs.GetFloat("skill_" .. index .. "_anchorX", defaultPref.x)
	local savedAnchorY = PlayerPrefs.GetFloat("skill_" .. index .. "_anchorY", defaultPref.y)
	local transform = skin.transform

	transform.localScale = Vector3(savedScale, savedScale, 1)
	transform.anchorMin = Vector2(savedAnchorX, savedAnchorY)
	transform.anchorMax = Vector2(savedAnchorX, savedAnchorY)
end
