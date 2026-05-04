ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleSimulationBuffCountView = class("BattleSimulationBuffCountView")

ys.Battle.BattleSimulationBuffCountView = BattleSimulationBuffCountView
BattleSimulationBuffCountView.__name = "BattleSimulationBuffCountView"

--- 模拟战增益Buff倒计时视图
--- 显示模拟战（Simulation）中的增益倒计时/"强化"文本

function BattleSimulationBuffCountView.Ctor(self, go)
	ys.EventListener.AttachEventListener(self)

	self._go = go
	self._tf = go.transform
	self._timer = self._tf:Find("buff_count/Text")
	self._text = self._timer:GetComponent(typeof(Text))
end

function BattleSimulationBuffCountView.SetActive(self, isActive)
	setActive(self._go, isActive)
end

--- 设置倒计时文本
function BattleSimulationBuffCountView.SetCountDownText(self, timeLeft)
	self._text.text = i18n("simulation_advantage_counting", math.floor(timeLeft))
end

--- 设置"已强化"文本
function BattleSimulationBuffCountView.SetEnhancedText(self)
	self._text.text = i18n("simulation_enhanced")
end

function BattleSimulationBuffCountView.Dispose(self)
	self._rateBarList = nil
	self._progressList = nil
end
