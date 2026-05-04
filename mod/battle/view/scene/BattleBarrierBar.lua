ys = ys or {}

local ys = ys

ys.Battle.BattleBarrierBar = class("BattleBarrierBar")
ys.Battle.BattleBarrierBar.__name = "BattleBarrierBar"

local BattleBarrierBar = ys.Battle.BattleBarrierBar

--- 护盾条相对角色的偏移量
BattleBarrierBar.OFFSET = Vector3(1.8, 2.3, 0)

--- @class BattleBarrierBar
--- 护盾/屏障倒计时条视图
--- 在角色头顶显示圆形护盾剩余时间进度条
--- 与BattleCastBar共用相似的UI结构（clock + progress + danger），
--- 但进度方向相反：护盾条显示的是剩余时间，施法条显示的是已用时间
--- @param barrierClockTF Transform 护盾条Transform
function BattleBarrierBar.Ctor(self, barrierClockTF)
	self._barrierClockTF = barrierClockTF
	self._barrierClockGO = self._barrierClockTF.gameObject
	self._castProgress = self._barrierClockTF:Find("shield_progress"):GetComponent(typeof(Image))
	self._danger = self._barrierClockTF:Find("danger")
	self._clockCG = self._barrierClockTF:GetComponent(typeof(CanvasGroup))
end

--- 开始护盾动画
--- @param duration number 护盾持续时间（秒）
function BattleBarrierBar.Shielding(self, duration)
	-- 弹出动画
	self._barrierClockTF.localScale = Vector3(0.1, 0.1, 1)

	SetActive(self._barrierClockTF, true)
	LeanTween.scale(rtf(self._barrierClockGO), Vector3.New(1, 1, 1), 0.1):setEase(LeanTweenType.easeInBack)

	-- 记录护盾结束时间
	self._barrierFinishTime = pg.TimeMgr.GetInstance():GetCombatTime() + duration
	self._barrierDuration = duration

	-- 旋转警告边框
	LeanTween.rotate(rtf(self._danger), 360, 5):setLoopClamp()
end

--- 护盾被打断/消失
function BattleBarrierBar.Interrupt(self)
	LeanTween.cancel(go(self._danger))
	LeanTween.scale(rtf(self._barrierClockGO), Vector3.New(0.1, 0.1, 1), 0.3):setEase(LeanTweenType.easeInBack):setOnComplete(System.Action(function()
		SetActive(self._barrierClockTF, false)
	end))
end

--- 更新护盾条位置
--- @param worldPos Vector3 角色世界坐标
function BattleBarrierBar.UpdateBarrierClockPosition(self, worldPos)
	self._barrierClockTF.position = worldPos + BattleBarrierBar.OFFSET
end

--- 每帧更新护盾剩余时间进度
--- fillAmount = 剩余时间 / 总时长（从1递减到0）
function BattleBarrierBar.UpdateBarrierClockProgress(self)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	self._castProgress.fillAmount = (self._barrierFinishTime - currentTime) / self._barrierDuration
end

--- 销毁护盾条
function BattleBarrierBar.Dispose(self)
	Object.Destroy(self._barrierClockGO)

	self._barrierClockTF = nil
	self._barrierClockGO = nil
	self._castProgress = nil
end
