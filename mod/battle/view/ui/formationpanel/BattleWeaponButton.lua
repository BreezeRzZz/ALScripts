ys = ys or {}

local ys = ys
local BattleWeaponButton = class("BattleWeaponButton")

ys.Battle.BattleWeaponButton = BattleWeaponButton
BattleWeaponButton.__name = "BattleWeaponButton"
BattleWeaponButton.ICON_BY_INDEX = {
	"cannon",
	"torpedo",
	"aircraft",
	"submarine",
	"dive",
	"rise",
	"boost",
	"switch",
	"special",
	"aamissile",
	"meteor",
	"pointairstrike"
}

--- 构造函数，初始化事件触发器
--- @class BattleWeaponButton
function BattleWeaponButton.Ctor(self)
	ys.EventListener.AttachEventListener(self)

	self.eventTriggers = {}
end

--- 配置按钮回调函数
--- @param downFunc function 按下回调
--- @param upFunc function 抬起回调
--- @param cancelFunc function 取消回调（手指滑出）
--- @param emptyFunc function 空槽点击回调
function BattleWeaponButton.ConfigCallback(self, downFunc, upFunc, cancelFunc, emptyFunc)
	self._downFunc = downFunc
	self._upFunc = upFunc
	self._cancelFunc = cancelFunc
	self._emptyFunc = emptyFunc
end

--- 设置按钮可见性
--- @param visible boolean
function BattleWeaponButton.SetActive(self, visible)
	SetActive(self._skin, visible)
end

--- 设置干扰（Jam）状态
--- @param isJam boolean 是否处于干扰状态
function BattleWeaponButton.SetJam(self, isJam)
	SetActive(self._jam, isJam)
	SetActive(self._icon, not isJam)
	SetActive(self._progress, not isJam)
end

--- 切换武器图标（根据图标索引加载对应sprite）
--- @param iconIndex number 图标索引，对应ICON_BY_INDEX表
--- @param skinKey string 皮肤键，默认从BattleState获取
function BattleWeaponButton.SwitchIcon(self, iconIndex, skinKey)
	self._iconIndex = iconIndex

	local iconName = BattleWeaponButton.ICON_BY_INDEX[iconIndex]
	local finalSkinKey = skinKey or ys.Battle.BattleState.GetCombatSkinKey()

	-- 非Standard皮肤使用空字符串作为资源路径前缀
	if finalSkinKey ~= "Standard" then
		finalSkinKey = ""
	end

	setImageSprite(self._unfill, LoadSprite("ui/CombatUI" .. finalSkinKey .. "_atlas", "weapon_unfill_" .. iconName))
	setImageSprite(self._filled, LoadSprite("ui/CombatUI" .. finalSkinKey .. "_atlas", "filled_combined_" .. iconName))

	return finalSkinKey, iconName
end

--- 切换图标特效（填充特效和干扰图标）
--- @param iconIndex number 图标索引
--- @param skinKey string|nil 皮肤键
function BattleWeaponButton.SwitchIconEffect(self, iconIndex, skinKey)
	local iconName = BattleWeaponButton.ICON_BY_INDEX[iconIndex]
	local finalSkinKey = skinKey or ys.Battle.BattleState.GetCombatSkinKey()

	if finalSkinKey ~= "Standard" then
		finalSkinKey = ""
	end

	setImageSprite(self._filledEffect, LoadSprite("ui/CombatUI" .. finalSkinKey .. "_atlas", "filled_effect_" .. iconName), true)
	setImageSprite(self._jam, LoadSprite("ui/CombatUI" .. finalSkinKey .. "_atlas", "skill_jam_" .. iconName), true)
end

--- 配置皮肤及子节点引用
--- @param skin Transform 按钮皮肤根Transform
function BattleWeaponButton.ConfigSkin(self, skin)
	self._skin = skin
	self._btn = skin:Find("ActCtl")
	self._block = skin:Find("ActCtl/block").gameObject
	self._progress = skin:Find("ActCtl/skill_progress")
	self._progressBar = self._progress:GetComponent(typeof(Image))
	self._icon = skin:Find("ActCtl/skill_icon")
	self._filled = self._icon:Find("filled")
	self._unfill = self._icon:Find("unfill")
	self._count = skin:Find("ActCtl/Count")
	self._text = self._count:Find("CountText")
	self._selected = skin:Find("ActCtl/selected")
	self._unSelect = skin:Find("ActCtl/unselect")
	self._filledEffect = skin:Find("ActCtl/filledEffect")
	self._jam = skin:Find("ActCtl/jam")
	self._countTxt = self._text:GetComponent(typeof(Text))

	skin.gameObject:SetActive(true)
	self._block:SetActive(false)
	self._progress.gameObject:SetActive(true)

	-- 配置填充特效结束回调
	local filledEffectGO = self._filledEffect.gameObject

	filledEffectGO:SetActive(false)
	filledEffectGO:GetComponent("DftAniEvent"):SetEndEvent(function(event)
		SetActive(self._filledEffect, false)
	end)

	self._animtor = skin:GetComponent(typeof(Animator))
	self._bgEff = skin:Find("ActCtl/bg_eff")
	self._gizmos1 = skin:Find("ActCtl/gizmos_1")
	self._gizmosXue = skin:Find("ActCtl/gizmos_xue")
end

--- 获取按钮皮肤根Transform
--- @return Transform
function BattleWeaponButton.GetSkin(self)
	return self._skin
end

--- 启用/禁用按钮交互
--- @param enable boolean
function BattleWeaponButton.Enabled(self, enable)
	local btnListener = GetComponent(self._btn, "EventTriggerListener")
	local blockListener = GetComponent(self._block, "EventTriggerListener")

	self.eventTriggers[btnListener] = true
	self.eventTriggers[blockListener] = true
	btnListener.enabled = enable
	blockListener.enabled = enable
end

--- 禁用按钮交互并触发取消回调
function BattleWeaponButton.Disable(self)
	if self._cancelFunc then
		self._cancelFunc()
	end

	self:OnUnSelect()

	local btnListener = GetComponent(self._btn, "EventTriggerListener")
	local blockListener = GetComponent(self._block, "EventTriggerListener")

	btnListener.enabled = false
	blockListener.enabled = false
end

--- 选中状态（按下时），显示选中高亮
function BattleWeaponButton.OnSelected(self)
	SetActive(self._unSelect, false)
	SetActive(self._selected, true)
end

--- 取消选中状态，显示未选中
function BattleWeaponButton.OnUnSelect(self)
	SetActive(self._selected, false)
	SetActive(self._unSelect, true)
end

--- 填充完成状态，显示填充图标
function BattleWeaponButton.OnFilled(self)
	SetActive(self._filled, true)
	SetActive(self._unfill, false)
end

--- 未填充状态，显示空图标
function BattleWeaponButton.OnUnfill(self)
	SetActive(self._filled, false)
	SetActive(self._unfill, true)
end

--- 播放填充完成特效
function BattleWeaponButton.OnfilledEffect(self)
	SetActive(self._filledEffect, true)
end

--- 过载状态变化事件处理
--- @param event BattleEvent|nil 事件对象，包含预装填状态
function BattleWeaponButton.OnOverLoadChange(self, event)
	if self._progressInfo:IsOverLoad() then
		self._block:SetActive(true)
		self:OnUnfill()
	else
		self._block:SetActive(false)
		self:OnFilled()

		-- 根据预装填状态播放不同动画
		if event and event.Data then
			local preCast = event.Data.preCast

			if preCast then
				if preCast == 0 then
					quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_filled")
				elseif preCast > 0 then
					quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_charge")
				end
			end
		end
	end

	if event and event.Data and event.Data.postCast then
		quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_use")
	end

	if self._progressInfo:GetTotal() > 0 then
		self:updateProgressBar()
	end
end

--- 设置进度条可见性
--- @param active boolean
function BattleWeaponButton.SetProgressActive(self, active)
	self._progress.gameObject:SetActive(active)
end

--- 设置弹药数量文本可见性
--- @param active boolean
function BattleWeaponButton.SetTextActive(self, active)
	SetActive(self._count, active)
end

--- 设置进度信息对象并注册事件
--- @param progressInfo WeaponProgressInfo 武器进度信息
function BattleWeaponButton.SetProgressInfo(self, progressInfo)
	self._progressInfo = progressInfo

	self._progressInfo:RegisterEventListener(self, ys.Battle.BattleEvent.WEAPON_TOTAL_CHANGE, self.OnTotalChange)
	self._progressInfo:RegisterEventListener(self, ys.Battle.BattleEvent.WEAPON_COUNT_PLUS, self.OnfilledEffect)
	self._progressInfo:RegisterEventListener(self, ys.Battle.BattleEvent.OVER_LOAD_CHANGE, self.OnOverLoadChange)
	self._progressInfo:RegisterEventListener(self, ys.Battle.BattleEvent.COUNT_CHANGE, self.OnCountChange)
	self:OnTotalChange()
	self:OnOverLoadChange()
end

--- 弹药数量变化事件处理，更新UI图标和计数
function BattleWeaponButton.OnCountChange(self)
	local count = self._progressInfo:GetCount()
	local total = self._progressInfo:GetTotal()

	self._countTxt.text = string.format("%d/%d", count, total)

	-- 如果弹药类型切换，更新图标
	local currentIconIndex = self._progressInfo:GetCurrentWeaponIconIndex()

	if currentIconIndex ~= self._iconIndex then
		self:SwitchIcon(currentIconIndex)
		self:SwitchIconEffect(currentIconIndex)
	end

	-- 更新小装饰状态
	if self._gizmos1 then
		SetActive(self._gizmos1, count > 0)
		SetActive(self._gizmosXue, count == total)
	end
end

--- 武器总数变化事件处理
--- @param event BattleEvent|nil
function BattleWeaponButton.OnTotalChange(self, event)
	if self._progressInfo:GetTotal() <= 0 then
		-- 没有可用武器，显示为禁用状态
		self._block:SetActive(true)

		self._progressBar.fillAmount = 0

		if self._bgEff then
			self._skin:Find("ActCtl/bg_eff"):GetComponent(typeof(CanvasGroup)).alpha = 0
		end

		self._text:GetComponent(typeof(Text)).text = "0/0"

		self:SetControllerActive(false)
		self:OnUnfill()
		self:OnUnSelect()
	else
		self:OnCountChange()
		self:SetControllerActive(true)

		-- 如果切换为第一个武器索引，取消选中
		if event then
			local index = event.Data.index

			if index and index == 1 then
				self:OnUnSelect()
			end
		end
	end
end

--- 设置控制器激活状态（注册/移除按钮事件）
--- @param active boolean 是否可交互
function BattleWeaponButton.SetControllerActive(self, active)
	if self._isActive == active then
		return
	end

	self._isActive = active

	local btnListener = GetComponent(self._btn, "EventTriggerListener")
	local blockListener = GetComponent(self._block, "EventTriggerListener")

	if active then
		-- 可交互状态：注册按下/抬起/取消事件
		local isPressed

		if self._downFunc ~= nil then
			btnListener:AddPointDownFunc(function()
				isPressed = true

				self._downFunc()
				self:OnSelected()
			end)
		end

		if self._upFunc ~= nil then
			btnListener:AddPointUpFunc(function()
				if isPressed then
					isPressed = false

					self._upFunc()
					self:OnUnSelect()
				end
			end)
		end

		if self._cancelFunc ~= nil then
			btnListener:AddPointExitFunc(function()
				if isPressed then
					isPressed = false

					self._cancelFunc()
					self:OnUnSelect()
				end
			end)
		end

		blockListener:RemovePointDownFunc()
	else
		-- 禁用状态：遮挡块捕获点击，触发空槽回调
		blockListener:AddPointDownFunc(self._emptyFunc)
		btnListener:RemovePointDownFunc()
		btnListener:RemovePointUpFunc()
		btnListener:RemovePointExitFunc()
	end
end

--- 按钮初始入场动画
--- @param delay number 动画延迟时间（秒）
function BattleWeaponButton.InitialAnima(self, delay)
	SetActive(self._btn, false)

	self._leanID = LeanTween.delayedCall(delay, System.Action(function()
		self._skin:GetComponent("Animator").enabled = true
		self._leanID = nil
	end))
end

--- 每帧更新进度条
function BattleWeaponButton.Update(self)
	local current = self._progressInfo:GetCurrent()
	local maxVal = self._progressInfo:GetMax()

	if self._progressInfo:GetTotal() > 0 and current < maxVal then
		self:updateProgressBar()
	end
end

--- 设置战斗UI预览模式（显示为满状态或空状态）
--- @param mode CombatUIPreviewer.WeaponButtonPreviewMode 预览模式
function BattleWeaponButton.SetToCombatUIPreview(self, mode)
	if mode ~= CombatUIPreviewer.WeaponButtonPreviewMode.UNFILLED then
		SetActive(self._filled, true)
		SetActive(self._unfill, false)

		self._progressBar.fillAmount = 1

		if self._bgEff then
			self._skin:Find("ActCtl/bg_eff"):GetComponent(typeof(CanvasGroup)).alpha = 1
		end

		self._countTxt.text = "1/1"

		if self._gizmos1 then
			SetActive(self._gizmos1, true)
			SetActive(self._gizmosXue, true)
		end
	else
		SetActive(self._unfill, true)
		SetActive(self._filled, false)

		self._progressBar.fillAmount = 0

		if self._bgEff then
			self._skin:Find("ActCtl/bg_eff"):GetComponent(typeof(CanvasGroup)).alpha = 0
		end

		self._countTxt.text = "0/0"

		if self._gizmos1 then
			SetActive(self._gizmos1, false)
			SetActive(self._gizmosXue, false)
		end
	end
end

--- 更新进度条填充比例
function BattleWeaponButton.updateProgressBar(self)
	local fillAmount = self._progressInfo:GetCurrent() / self._progressInfo:GetMax()

	self._progressBar.fillAmount = fillAmount

	-- 有弹药时背景特效完全不透明，否则跟随进度条比例
	if self._bgEff then
		if self._progressInfo.GetCount and self._progressInfo:GetCount() > 0 then
			self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1
		else
			self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = fillAmount
		end
	end
end

--- 销毁按钮，清理事件和引用
function BattleWeaponButton.Dispose(self)
	if self.eventTriggers then
		for listener, _ in pairs(self.eventTriggers) do
			ClearEventTrigger(listener)
		end

		self.eventTriggers = nil
	end

	self._progress = nil
	self._progressBar = nil

	self._progressInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.OVER_LOAD_CHANGE)
	self._progressInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.WEAPON_TOTAL_CHANGE)
	self._progressInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.WEAPON_COUNT_PLUS)
	self._progressInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.COUNT_CHANGE)
	ys.EventListener.DetachEventListener(self)
end
