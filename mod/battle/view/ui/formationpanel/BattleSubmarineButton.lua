ys = ys or {}

local ys = ys
local BattleSubmarineButton = class("BattleSubmarineButton", ys.Battle.BattleWeaponButton)

ys.Battle.BattleSubmarineButton = BattleSubmarineButton
BattleSubmarineButton.__name = "BattleSubmarineButton"

--- 潜艇专用武器按钮
--- 继承自 BattleWeaponButton，隐藏进度条和填装特效，使用简化的弹药计数

function BattleSubmarineButton.Ctor(self)
	BattleSubmarineButton.super.Ctor(self)
end

--- 只显示当前弹药数（不显示总数）
function BattleSubmarineButton.OnCountChange(self)
	local currentCount = self._progressInfo:GetCount()
	local totalCount = self._progressInfo:GetTotal()

	self._countTxt.text = string.format("%d", currentCount)
end

--- 配置皮肤时隐藏进度条和填满特效
function BattleSubmarineButton.ConfigSkin(self, skin)
	BattleSubmarineButton.super.ConfigSkin(self, skin)
	self._progress.gameObject:SetActive(false)
	self._filledEffect.gameObject:SetActive(false)
end

--- 配置回调时，将 up 回调替换为 cancel 回调（潜艇按钮不需要"松手"操作）
function BattleSubmarineButton.ConfigCallback(self, downFunc, upFunc, cancelFunc, emptyFunc)
	local function wrappedCancel()
		upFunc()
	end

	BattleSubmarineButton.super.ConfigCallback(self, downFunc, wrappedCancel, cancelFunc, emptyFunc)
end

--- 过载状态变化：弹药满时播放入场动画，空时播放使用动画
function BattleSubmarineButton.OnOverLoadChange(self, event)
	BattleSubmarineButton.super.OnOverLoadChange(self, event)

	if self._progressInfo:GetTotal() == self._progressInfo:GetCount() then
		quickCheckAndPlayAnimator(self._skin, "weapon_button_into")
	elseif self._progressInfo:GetCount() == 0 then
		quickCheckAndPlayAnimator(self._skin, "weapon_button_use")
	end
end

function BattleSubmarineButton.Update(self)
	return
end

function BattleSubmarineButton.updateProgressBar(self)
	return
end

function BattleSubmarineButton.OnfilledEffect(self)
	return
end
