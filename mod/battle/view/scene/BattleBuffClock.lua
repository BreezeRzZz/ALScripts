ys = ys or {}

local ys = ys

ys.Battle.BattleBuffClock = class("BattleBuffClock")
ys.Battle.BattleBuffClock.__name = "BattleBuffClock"

local BattleBuffClock = ys.Battle.BattleBuffClock

BattleBuffClock.OFFSET = Vector3(1.8, 2.3, 0)
BattleBuffClock.TYPE_INDEX = 3

--- @class BattleBuffClock
--- @param clockTF Transform Buff计时器的Transform引用
function BattleBuffClock.Ctor(self, clockTF)
	self._castClockTF = clockTF
	self._castClockGO = self._castClockTF.gameObject
	self._bgList = self._castClockTF:Find("bg")
	self._danger = self._castClockTF:Find("danger")
	self._interrupt = self._castClockTF:Find("interrupt")
	self._casting = self._castClockTF:Find("casting")
	self._progressProtected = self._castClockTF:Find("progress/protected")
	self._progressInterrupt = self._castClockTF:Find("progress/interrupt")
	self._clockCG = self._castClockTF:GetComponent(typeof(CanvasGroup))
end

--- 切换指定父节点下的Type子节点显示（1~TYPE_INDEX）
--- @param parentTF Transform 父Transform
--- @param targetIndex number 目标Type索引
function BattleBuffClock.switchToIndex(self, parentTF, targetIndex)
	for i = 1, BattleBuffClock.TYPE_INDEX do
		local childTF = parentTF:Find(tostring(i))

		SetActive(childTF, targetIndex == i)
	end
end

--- Buff计时器是否激活中
function BattleBuffClock.IsActive(self)
	return self._buffEffect ~= nil
end

--- 开始计时（显示计时器并设置图标类型）
--- @param cfg table { iconType, interrupt, buffEffect }
function BattleBuffClock.Casting(self, cfg)
	LeanTween.cancel(self._castClockGO)

	self._castClockTF.localScale = Vector3(0.1, 0.1, 1)

	local iconType = cfg.iconType

	self:switchToIndex(self._bgList, iconType)
	self:switchToIndex(self._danger, iconType)
	self:switchToIndex(self._interrupt, iconType)
	self:switchToIndex(self._casting, iconType)
	SetActive(self._progressInterrupt, cfg.interrupt)
	SetActive(self._progressProtected, not cfg.interrupt)

	self._castProgress = cfg.interrupt and self._progressInterrupt:GetComponent(typeof(Image)) or self._progressProtected:GetComponent(typeof(Image))

	SetActive(self._castClockTF, true)
	SetActive(self._casting, true)
	SetActive(self._interrupt, false)
	LeanTween.scale(rtf(self._castClockGO), Vector3.New(1, 1, 1), 0.1):setEase(LeanTweenType.easeInBack)
	LeanTween.rotate(rtf(self._danger), 360, 5):setLoopClamp()

	self._buffEffect = cfg.buffEffect
end

--- 中断计时（播放闪烁动画后隐藏）
--- @param cfg table { interrupt }
function BattleBuffClock.Interrupt(self, cfg)
	if cfg.interrupt then
		SetActive(self._casting, false)
		SetActive(self._interrupt, true)
	end

	LeanTween.cancel(go(self._danger))

	-- 闪烁两次效果
	for i = 1, 2 do
		LeanTween.alphaCanvas(self._clockCG, 0.3, 0.3):setFrom(1):setDelay(0.3 * (i - 1))
		LeanTween.alphaCanvas(self._clockCG, 1, 0.3):setDelay(0.3 * i)
	end

	LeanTween.scale(rtf(self._castClockGO), Vector3.New(0.1, 0.1, 1), 0.3):setEase(LeanTweenType.easeInBack):setDelay(1.25):setOnComplete(System.Action(function()
		self._buffEffect = nil

		SetActive(self._castClockTF, false)
	end))
end

--- 更新Buff计时器世界坐标
--- @param position Vector3
function BattleBuffClock.UpdateCastClockPosition(self, position)
	self._castClockTF.position = position + BattleBuffClock.OFFSET
end

--- 每帧更新计时器进度（由BuffEffect驱动）
function BattleBuffClock.UpdateCastClock(self)
	self._castProgress.fillAmount = self._buffEffect:GetCountProgress()
end

--- 销毁计时器
function BattleBuffClock.Dispose(self)
	self._buffEffect = nil

	Object.Destroy(self._castClockGO)

	self._castClockTF = nil
	self._castClockGO = nil
	self._castProgress = nil
	self._interrupt = nil
	self._casting = nil
	self._bgList = nil
	self._danger = nil
	self._progressInterrupt = nil
	self._progressProtected = nil
end
