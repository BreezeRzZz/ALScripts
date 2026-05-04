ys = ys or {}

local ys = ys
-- 未在文件中直接使用的引用，可能为下游预留
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleKizunaJammingView = class("BattleKizunaJammingView")

ys.Battle.BattleKizunaJammingView = BattleKizunaJammingView
BattleKizunaJammingView.__name = "BattleKizunaJammingView"
-- 需要点击的次数才能消除
BattleKizunaJammingView.COUNT = 3
-- 扩展动画持续时间基准（秒）
BattleKizunaJammingView.EXPAND_DURATION = 5

--- 绊爱联动活动中的屏幕干扰消除视图
--- 需要快速点击屏幕指定次数（COUNT）来消除干扰
--- @param go GameObject 干扰UI的GameObject
function BattleKizunaJammingView.Ctor(self, go)
	self._go = go
	self._tf = go.transform
	self._hitCount = 0
end

--- 配置消除完成后的回调函数，并初始化事件监听
--- @param callback function 消除完成后的回调
function BattleKizunaJammingView.ConfigCallback(self, callback)
	self._callback = callback

	self:init()
end

--- 初始化点击事件监听
function BattleKizunaJammingView.init(self)
	self.eventTriggers = {}
	self._blocker = self._tf:Find("KizunaAiBlocker")

	local eventTrigger = GetOrAddComponent(self._blocker, "EventTriggerListener")

	self.eventTriggers[eventTrigger] = true

	-- 按下：记录点击次数，达到COUNT时消除
	eventTrigger:AddPointDownFunc(function()
		self._hitCount = self._hitCount + 1

		if self._hitCount >= BattleKizunaJammingView.COUNT then
			self:Eliminate(true)
		else
			-- 显示被点击状态
			setActive(self._blocker:Find("normal"), false)
			setActive(self._blocker:Find("hitted"), true)
			LeanTween.cancel(go(self._blocker))
			self:ClickEase()
		end
	end)
	-- 抬起：如果未消除，恢复正常状态
	eventTrigger:AddPointUpFunc(function()
		if self._hitCount < BattleKizunaJammingView.COUNT then
			setActive(self._blocker:Find("normal"), true)
			setActive(self._blocker:Find("hitted"), false)
		end
	end)
end

--- 激活扩展动画（逐渐放大直至覆盖屏幕）
function BattleKizunaJammingView.Active(self)
	-- 根据当前缩放计算剩余动画时间
	local remainingDuration = (1 - self._blocker.localScale.x) * BattleKizunaJammingView.EXPAND_DURATION

	LeanTween.scale(self._blocker, Vector3(1, 1, 0), remainingDuration)
end

--- 暂停扩展动画
function BattleKizunaJammingView.Pause(self)
	LeanTween.cancel(go(self._blocker))
end

--- 每次点击后的缩小缓动效果
--- 将缩放减少0.05，然后重新激活扩展动画
function BattleKizunaJammingView.ClickEase(self)
	local newScale = self._blocker.localScale.x - 0.05

	LeanTween.scale(self._blocker, Vector3(newScale, newScale, 0), 0.03):setOnComplete(System.Action(function()
		self:Active()
	end))
end

--- 消除干扰（缩到0并触发回调）
--- @param isHit boolean 是否显示被点击状态
function BattleKizunaJammingView.Eliminate(self, isHit)
	LeanTween.cancel(go(self._blocker))
	setActive(self._blocker:Find("normal"), not isHit)
	setActive(self._blocker:Find("hitted"), isHit)
	LeanTween.scale(self._blocker, Vector3(0, 0, 0), 0.1):setOnComplete(System.Action(function()
		self._callback()
	end))
end

--- 清理事件触发器和缓动动画
function BattleKizunaJammingView.Dispose(self)
	if self.eventTriggers then
		for trigger, _ in pairs(self.eventTriggers) do
			ClearEventTrigger(trigger)
		end

		self.eventTriggers = nil
	end

	LeanTween.cancel(go(self._blocker))
end
