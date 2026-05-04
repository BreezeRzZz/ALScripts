ys = ys or {}

local ys = ys
local BattleWeaponButtonSkinElite_20251218 = class("BattleWeaponButtonSkinElite_20251218", ys.Battle.BattleWeaponButtonSkinElite_20250520)

ys.Battle.BattleWeaponButtonSkinElite_20251218 = BattleWeaponButtonSkinElite_20251218
BattleWeaponButtonSkinElite_20251218.__name = "BattleWeaponButtonSkinElite_20251218"

--- 2025年12月18日精英武器按钮皮肤
--- 继承自 BattleWeaponButtonSkinElite_20250520

function BattleWeaponButtonSkinElite_20251218.OnTotalChange(self, event)
	if self._progressInfo:GetTotal() <= 0 then
		self._block:SetActive(true)

		self._progressBar.fillAmount = 0
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 0
		self._text:GetComponent(typeof(Text)).text = "0/0"

		self:SetControllerActive(false)
		SetActive(self._glowEff, false)
		self:OnUnfill()
		self:OnUnSelect()
		-- 额外隐藏 gizmos 节点
		SetActive(self._gizmos1, false)
		SetActive(self._gizmosXue, false)
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

function BattleWeaponButtonSkinElite_20251218.OnCountChange(self)
	BattleWeaponButtonSkinElite_20251218.super.OnCountChange(self)
	-- 有弹药时显示雪（xue）特效
	SetActive(self._gizmosXue, self._progressInfo:GetCount() > 0)
end

--- 设置战斗UI预览模式
function BattleWeaponButtonSkinElite_20251218.SetToCombatUIPreview(self, isActive)
	if isActive then
		SetActive(self._filled, true)
		SetActive(self._unfill, false)

		self._progressBar.fillAmount = 1
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1
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
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 0
		self._countTxt.text = "0/0"

		SetActive(self._glowEff, false)

		if self._gizmos1 then
			SetActive(self._gizmos1, false)
			SetActive(self._gizmosXue, false)
		end
	end
end

--- 更新进度条填充量
function BattleWeaponButtonSkinElite_20251218.updateProgressBar(self)
	local ratio = self._progressInfo:GetCurrent() / self._progressInfo:GetMax()

	self._progressBar.fillAmount = ratio

	if self._progressInfo.GetCount and self._progressInfo:GetCount() > 0 then
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1
	else
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = ratio
	end
end
