ys = ys or {}

local ys = ys
local BattleWeaponButtonSkinElite_20250327 = class("BattleWeaponButtonSkinElite_20250327", ys.Battle.BattleWeaponButton)

ys.Battle.BattleWeaponButtonSkinElite_20250327 = BattleWeaponButtonSkinElite_20250327
BattleWeaponButtonSkinElite_20250327.__name = "BattleWeaponButtonSkinElite_20250327"

--- 2025年3月27日精英武器按钮皮肤
--- 继承自 BattleWeaponButton，用于精英活动期间的武器按钮样式

function BattleWeaponButtonSkinElite_20250327.OnTotalChange(self, event)
	if self._progressInfo:GetTotal() <= 0 then
		self._block:SetActive(true)

		self._progressBar.fillAmount = 0
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1
		self._text:GetComponent(typeof(Text)).text = "0/0"

		self:SetControllerActive(false)
		SetActive(self._glowEff, false)
		self:OnUnfill()
		self:OnUnSelect()
	else
		-- 满弹时显示发光特效
		if self._progressInfo:GetTotal() == self._progressInfo:GetCount() then
			SetActive(self._glowEff, true)
		end

		self:OnCountChange()
		self:SetControllerActive(true)

		if event then
			local index = event.Data.index

			if index and index == 1 then
				self:OnUnSelect()
			end
		end
	end
end

function BattleWeaponButtonSkinElite_20250327.ConfigSkin(self, skin)
	BattleWeaponButtonSkinElite_20250327.super.ConfigSkin(self, skin)

	-- 从按钮内部查找发光特效节点
	self._glowEff = self._btn:Find("gizmos_1")
end

function BattleWeaponButtonSkinElite_20250327.OnCountChange(self)
	BattleWeaponButtonSkinElite_20250327.super.OnCountChange(self)
	-- 有弹药时显示发光
	SetActive(self._glowEff, self._progressInfo:GetCount() > 0)
end

--- 设置战斗UI预览模式
--- @param mode CombatUIPreviewer.WeaponButtonPreviewMode 预览模式
function BattleWeaponButtonSkinElite_20250327.SetToCombatUIPreview(self, mode)
	if mode ~= CombatUIPreviewer.WeaponButtonPreviewMode.UNFILLED then
		SetActive(self._filled, true)
		SetActive(self._unfill, false)

		self._progressBar.fillAmount = 1
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 0
		self._countTxt.text = "1/1"

		if self._gizmos1 then
			SetActive(self._gizmos1, true)
			SetActive(self._gizmosXue, true)
		end

		SetActive(self._glowEff, true)
		quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_filled")
	else
		SetActive(self._unfill, true)
		SetActive(self._filled, false)

		self._progressBar.fillAmount = 0
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1
		self._countTxt.text = "0/0"

		SetActive(self._glowEff, false)

		if self._gizmos1 then
			SetActive(self._gizmos1, false)
			SetActive(self._gizmosXue, false)
		end
	end
end

--- 更新进度条填充量
function BattleWeaponButtonSkinElite_20250327.updateProgressBar(self)
	local ratio = self._progressInfo:GetCurrent() / self._progressInfo:GetMax()

	self._progressBar.fillAmount = ratio

	-- 有弹药时隐藏背景特效，否则根据比例逐渐显示
	if self._progressInfo.GetCount and self._progressInfo:GetCount() > 0 then
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 0
	else
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1 - ratio
	end
end

--- 过载状态变化处理
function BattleWeaponButtonSkinElite_20250327.OnOverLoadChange(self, event)
	if self._progressInfo:IsOverLoad() then
		self._block:SetActive(true)
		self:OnUnfill()
	else
		self._block:SetActive(false)
		self:OnFilled()
	end

	-- 有弹药且非过载时，根据预装填/充能状态播放动画
	if self._progressInfo:GetCount() >= 1 and event and event.Data then
		local preCast = event.Data.preCast

		if preCast then
			if preCast == 0 then
				quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_filled")
			elseif preCast > 0 then
				quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_charge")
			end
		end
	end

	-- 后装填时播放使用动画
	if event and event.Data and event.Data.postCast then
		quickCheckAndPlayAnimator(self._skin, "weapon_button_progress_use")
	end

	if self._progressInfo:GetTotal() > 0 then
		self:updateProgressBar()
	end
end
