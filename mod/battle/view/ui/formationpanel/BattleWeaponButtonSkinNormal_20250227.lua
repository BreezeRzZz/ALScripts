ys = ys or {}

local ys = ys
local BattleWeaponButtonSkinNormal_20250227 = class("BattleWeaponButtonSkinNormal_20250227", ys.Battle.BattleWeaponButton)

ys.Battle.BattleWeaponButtonSkinNormal_20250227 = BattleWeaponButtonSkinNormal_20250227
BattleWeaponButtonSkinNormal_20250227.__name = "BattleWeaponButtonSkinNormal_20250227"

--- 2025年2月27日普通武器按钮皮肤
--- 继承自 BattleWeaponButton，是所有后续精英皮肤的基类

function BattleWeaponButtonSkinNormal_20250227.OnTotalChange(self, event)
	if self._progressInfo:GetTotal() <= 0 then
		self._block:SetActive(true)

		self._progressBar.fillAmount = 0
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1
		self._text:GetComponent(typeof(Text)).text = "0/0"

		self:SetControllerActive(false)
		self:OnUnfill()
		self:OnUnSelect()
	else
		-- 满弹时显示 gizmos 发光特效
		if self._progressInfo:GetTotal() == self._progressInfo:GetCount() then
			SetActive(self._filled:Find("gizmos"))
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

function BattleWeaponButtonSkinNormal_20250227.ConfigSkin(self, skin)
	BattleWeaponButtonSkinNormal_20250227.super.ConfigSkin(self, skin)

	-- 从 filled 节点下获取 gizmos 发光特效
	self._glowEff = self._filled:Find("gizmos")
end

function BattleWeaponButtonSkinNormal_20250227.OnCountChange(self)
	BattleWeaponButtonSkinNormal_20250227.super.OnCountChange(self)
	-- 满弹时才显示发光
	SetActive(self._glowEff, self._progressInfo:GetTotal() == self._progressInfo:GetCount())
end

--- 设置战斗UI预览模式
function BattleWeaponButtonSkinNormal_20250227.SetToCombatUIPreview(self, isActive)
	if isActive then
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
function BattleWeaponButtonSkinNormal_20250227.updateProgressBar(self)
	local ratio = self._progressInfo:GetCurrent() / self._progressInfo:GetMax()

	self._progressBar.fillAmount = ratio

	-- 有弹药时隐藏背景特效，否则根据比例逐渐显示
	if self._progressInfo.GetCount and self._progressInfo:GetCount() > 0 then
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 0
	else
		self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1 - ratio
	end
end
