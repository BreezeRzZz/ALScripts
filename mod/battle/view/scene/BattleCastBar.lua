ys = ys or {}

local ys = ys

ys.Battle.BattleCastBar = class("BattleCastBar")
ys.Battle.BattleCastBar.__name = "BattleCastBar"

local BattleCastBar = ys.Battle.BattleCastBar

--- 施法条相对角色的偏移量
BattleCastBar.OFFSET = Vector3(1.8, 2.3, 0)

--- @class BattleCastBar
--- 武器施法条（读条）视图
--- 在角色头顶显示圆形施法进度，支持casting状态、interrupt打断、danger动画
--- 与BattleBarrierBar/BattleBuffClock共用相同的UI布局结构
--- @param castClockTF Transform 施法条Transform预制体
function BattleCastBar.Ctor(self, castClockTF)
	self._castClockTF = castClockTF
	self._castClockGO = self._castClockTF.gameObject
	self._castProgress = self._castClockTF:Find("cast_progress"):GetComponent(typeof(Image))
	self._interrupt = self._castClockTF:Find("interrupt")
	self._casting = self._castClockTF:Find("casting")
	self._danger = self._castClockTF:Find("danger")
	self._clockCG = self._castClockTF:GetComponent(typeof(CanvasGroup))
end

--- 开始施法动画
--- @param duration number 施法持续时间（秒）
--- @param weapon BattleWeaponUnit 正在施法的武器实例
function BattleCastBar.Casting(self, duration, weapon)
	LeanTween.cancel(self._castClockGO)

	-- 从极小缩放到正常大小（弹出动画）
	self._castClockTF.localScale = Vector3(0.1, 0.1, 1)

	SetActive(self._castClockTF, true)
	SetActive(self._casting, true)
	SetActive(self._interrupt, false)
	LeanTween.scale(rtf(self._castClockGO), Vector3.New(1, 1, 1), 0.1):setEase(LeanTweenType.easeInBack)

	-- 计算施法结束时间
	self._castFinishTime = pg.TimeMgr.GetInstance():GetCombatTime() + duration
	self._castDuration = duration

	-- 危险警告旋转动画（红色指针持续旋转）
	LeanTween.rotate(rtf(self._danger), 360, 5):setLoopClamp()

	self._weapon = weapon
end

--- 施法被打断
--- @param showInterrupt boolean 是否显示打断图标
function BattleCastBar.Interrupt(self, showInterrupt)
	self._weapon = nil

	if showInterrupt then
		SetActive(self._casting, false)
		SetActive(self._interrupt, true)
	end

	-- 停止旋转警告
	LeanTween.cancel(go(self._danger))

	-- 闪烁两轮：alpha 从1→0.3→1→0.3→1
	for iter_3_0 = 1, 2 do
		LeanTween.alphaCanvas(self._clockCG, 0.3, 0.3):setFrom(1):setDelay(0.3 * (iter_3_0 - 1))
		LeanTween.alphaCanvas(self._clockCG, 1, 0.3):setDelay(0.3 * iter_3_0)
	end

	-- 缩小消失
	LeanTween.scale(rtf(self._castClockGO), Vector3.New(0.1, 0.1, 1), 0.3):setEase(LeanTweenType.easeInBack):setDelay(1.25):setOnComplete(System.Action(function()
		SetActive(self._castClockTF, false)
	end))
end

--- 获取当前正在施法的武器
--- @return BattleWeaponUnit|nil
function BattleCastBar.GetCastingWeapon(self)
	return self._weapon
end

--- 更新施法条位置（跟随角色移动）
--- @param worldPos Vector3 角色世界坐标
function BattleCastBar.UpdateCastClockPosition(self, worldPos)
	self._castClockTF.position = worldPos + BattleCastBar.OFFSET
end

--- 每帧更新施法进度条填充量
--- 进度 = 1 - 剩余时间 / 总时长
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
