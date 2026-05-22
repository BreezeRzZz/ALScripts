ys = ys or {}

local ys = ys
local BattleWeaponButtonSkinElite_20260226 = class("BattleWeaponButtonSkinElite_20260226", ys.Battle.BattleWeaponButtonSkinElite_20250520)

ys.Battle.BattleWeaponButtonSkinElite_20260226 = BattleWeaponButtonSkinElite_20260226
BattleWeaponButtonSkinElite_20260226.__name = "BattleWeaponButtonSkinElite_20260226"

--- 2026年2月26日精英武器按钮皮肤
--- 继承自 BattleWeaponButtonSkinElite_20250520，增加了书本随机动画效果

function BattleWeaponButtonSkinElite_20260226.ConfigSkin(self, skin)
	BattleWeaponButtonSkinElite_20260226.super.ConfigSkin(self, skin)

	-- 查找书本动画节点，用于技能释放时的随机书本特效
	self._books = self._selected:Find("usdfx/fx/up/book/book/book1")
	self._bookList = {}

	for i = 1, 4 do
		table.insert(self._bookList, self._books:Find("text_" .. i))
	end
end

function BattleWeaponButtonSkinElite_20260226.OnCountChange(self)
	BattleWeaponButtonSkinElite_20260226.super.OnCountChange(self)
	SetActive(self._gizmos1, self._progressInfo:GetCount() > 0)
	SetActive(self._gizmosXue, self._progressInfo:GetCount() > 0)
end

--- 设置战斗UI预览模式
--- @param mode CombatUIPreviewer.WeaponButtonPreviewMode 预览模式
function BattleWeaponButtonSkinElite_20260226.SetToCombatUIPreview(self, mode)
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

--- 过载状态变化处理，增加了技能释放时的随机书本动画
function BattleWeaponButtonSkinElite_20260226.OnOverLoadChange(self, event)
	-- 后装填（技能释放）时，随机显示一本不同的书
	if event and event.Data and event.Data.postCast then
		local randomIndex = math.random(4)

		for i, book in ipairs(self._bookList) do
			SetActive(book, i == randomIndex)
		end
	end

	BattleWeaponButtonSkinElite_20260226.super.OnOverLoadChange(self, event)
end

--- 更新进度条填充量
function BattleWeaponButtonSkinElite_20260226.updateProgressBar(self)
	local ratio = self._progressInfo:GetCurrent() / self._progressInfo:GetMax()

	self._progressBar.fillAmount = ratio

	if self._bgEff then
		if self._progressInfo.GetCount and self._progressInfo:GetCount() > 0 then
			self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 0
		else
			self._bgEff:GetComponent(typeof(CanvasGroup)).alpha = 1 - ratio
		end
	end
end
