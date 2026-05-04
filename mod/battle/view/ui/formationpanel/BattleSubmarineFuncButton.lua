ys = ys or {}

local ys = ys
local BattleSubmarineFuncButton = class("BattleSubmarineFuncButton", ys.Battle.BattleWeaponButton)

ys.Battle.BattleSubmarineFuncButton = BattleSubmarineFuncButton
BattleSubmarineFuncButton.__name = "BattleSubmarineFuncButton"

--- 潜艇功能按钮（如浮上/下潜切换）
--- 继承自 BattleWeaponButton，简化为只有状态切换的功能按钮

function BattleSubmarineFuncButton.Ctor(self)
	ys.EventListener.AttachEventListener(self)

	self.eventTriggers = {}
end

function BattleSubmarineFuncButton.OnfilledEffect(self)
	SetActive(self._filledEffect, true)
end

--- 设置进度信息，只注册武器计数增加和过载变化事件
function BattleSubmarineFuncButton.SetProgressInfo(self, progressInfo)
	self._progressInfo = progressInfo

	self._progressInfo:RegisterEventListener(self, ys.Battle.BattleEvent.WEAPON_COUNT_PLUS, self.OnfilledEffect)
	self._progressInfo:RegisterEventListener(self, ys.Battle.BattleEvent.OVER_LOAD_CHANGE, self.OnOverLoadChange)
	self:OnOverLoadChange()
	self:SetControllerActive(true)
end

--- 每帧更新进度条
function BattleSubmarineFuncButton.Update(self)
	if self._progressInfo:GetCurrent() < self._progressInfo:GetMax() then
		self:updateProgressBar()
	end
end

function BattleSubmarineFuncButton.Dispose(self)
	if self.eventTriggers then
		for trigger, _ in pairs(self.eventTriggers) do
			ClearEventTrigger(trigger)
		end

		self.eventTriggers = nil
	end

	self._progress = nil
	self._progressBar = nil

	self._progressInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.OVER_LOAD_CHANGE)
	self._progressInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.WEAPON_COUNT_PLUS)
	ys.EventListener.DetachEventListener(self)
end
