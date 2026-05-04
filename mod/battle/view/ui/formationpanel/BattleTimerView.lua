ys = ys or {}

local ys = ys

ys.Battle.BattleTimerView = class("BattleTimerView")
ys.Battle.BattleTimerView.__name = "BattleTimerView"

--- 战斗计时器视图
--- 显示战斗剩余时间，剩余30秒时开始闪烁

function ys.Battle.BattleTimerView.Ctor(self, go)
	self._go = go
	self._timer = self._go.transform:Find("Text")
	self._blinker = self._timer:GetComponent(typeof(Animator))
	self._isBlink = false
	self._text = self._timer:GetComponent(typeof(Text))
	self.timeStr = ""
end

function ys.Battle.BattleTimerView.SetActive(self, isActive)
	setActive(self._go, isActive)
end

--- 设置倒计时文本（MM:SS格式）
--- @param timeLeft number 剩余秒数
function ys.Battle.BattleTimerView.SetCountDownText(self, timeLeft)
	-- 剩余30秒时开始闪烁
	if timeLeft <= 30 and not self._isBlink then
		self._blinker.enabled = true
		self._isBlink = true
	end

	local timeStr = self.formatTime(math.floor(timeLeft))

	-- 相同文本不重复设置（避免闪烁动画重置）
	if timeStr == self.timeStr then
		return
	end

	self.timeStr = timeStr
	self._text.text = timeStr
end

--- 格式化时间为 MM:SS
function ys.Battle.BattleTimerView.formatTime(self)
	return string.format("%02u:%02u", math.floor(self / 60), self % 60)
end

function ys.Battle.BattleTimerView.Dispose(self)
	return
end
