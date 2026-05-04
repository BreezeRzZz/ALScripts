ys = ys or {}

local ys = ys
local BattleWeaponButtonSkinElite_20250520 = class("BattleWeaponButtonSkinElite_20250520", ys.Battle.BattleWeaponButtonSkinNormal_20250227)

ys.Battle.BattleWeaponButtonSkinElite_20250520 = BattleWeaponButtonSkinElite_20250520
BattleWeaponButtonSkinElite_20250520.__name = "BattleWeaponButtonSkinElite_20250520"

--- 2025年5月20日精英武器按钮皮肤
--- 继承自 BattleWeaponButtonSkinNormal_20250227，用于精英活动期间的武器按钮样式

function BattleWeaponButtonSkinElite_20250520.OnTotalChange(self, event)
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

function BattleWeaponButtonSkinElite_20250520.OnCountChange(self)
	BattleWeaponButtonSkinElite_20250520.super.OnCountChange(self)
	-- 有弹药时显示 gizmos1 特效
	SetActive(self._gizmos1, self._progressInfo:GetCount() > 0)
end

--- 过载状态变化处理
function BattleWeaponButtonSkinElite_20250520.OnOverLoadChange(self, event)
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
