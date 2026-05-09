ys = ys or {}

local ys = ys

ys.Battle.BattleCastBar = class("BattleCastBar")
ys.Battle.BattleCastBar.__name = "BattleCastBar"

local BattleCastBar = ys.Battle.BattleCastBar

BattleCastBar.OFFSET = Vector3(1.8, 2.3, 0)

--- @class BattleCastBar
--- @param clockTF Transform 施法条的Transform引用
function BattleCastBar.Ctor(self, clockTF)
	self._castClockTF = clockTF
	self._castClockGO = self._castClockTF.gameObject
	self._castProgress = self._castClockTF:Find("cast_progress"):GetComponent(typeof(Image))
	self._interrupt = self._castClockTF:Find("interrupt")
	self._casting = self._castClockTF:Find("casting")
	self._danger = self._castClockTF:Find("danger")
	self._clockCG = self._castClockTF:GetComponent(typeof(CanvasGroup))
end

--- 开始施法动画
--- @param duration number 施法总时长（秒）
--- @param weapon BattleWeaponUnit 正在施法的武器
function BattleCastBar.Casting(self, duration, weapon)
	LeanTween.cancel(self._castClockGO)

	self._castClockTF.localScale = Vector3(0.1, 0.1, 1)

	SetActive(self._castClockTF, true)
	SetActive(self._casting, true)
	SetActive(self._interrupt, false)
	LeanTween.scale(rtf(self._castClockGO), Vector3.New(1, 1, 1), 0.1):setEase(LeanTweenType.easeInBack)

	self._castFinishTime = pg.TimeMgr.GetInstance():GetCombatTime() + duration
	self._castDuration = duration

	LeanTween.rotate(rtf(self._danger), 360, 5):setLoopClamp()

	self._weapon = weapon
end

--- 中断施法动画
--- @param showInterrupt boolean 是否显示中断效果
function BattleCastBar.Interrupt(self, showInterrupt)
	self._weapon = nil

	if showInterrupt then
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
		SetActive(self._castClockTF, false)
	end))
end

--- 获取当前施法武器
--- @return BattleWeaponUnit|nil
function BattleCastBar.GetCastingWeapon(self)
	return self._weapon
end

--- 更新施法条的世界坐标位置
--- @param position Vector3 绑定角色的世界位置
function BattleCastBar.UpdateCastClockPosition(self, position)
	self._castClockTF.position = position + BattleCastBar.OFFSET
end

--- 每帧更新施法进度条填充比例
function BattleCastBar.UpdateCastClock(self)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	self._castProgress.fillAmount = 1 - (self._castFinishTime - currentTime) / self._castDuration
end

--- 销毁施法条
function BattleCastBar.Dispose(self)
	self._weapon = nil

	Object.Destroy(self._castClockGO)

	self._castClockTF = nil
	self._castClockGO = nil
	self._castProgress = nil
	self._interrupt = nil
	self._casting = nil
end
