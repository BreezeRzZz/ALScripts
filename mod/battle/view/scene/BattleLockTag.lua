ys = ys or {}

local ys = ys

ys.Battle.BattleLockTag = class("BattleLockTag")
ys.Battle.BattleLockTag.__name = "BattleLockTag"

local BattleLockTag = ys.Battle.BattleLockTag

--- @class BattleLockTag
--- 锁定标记指示器（瞄准锁定/集火标记）
--- 在目标敌人头顶显示圆形锁定进度动画，填满后表示锁定完成
--- @param markGO GameObject 标记GameObject（挂载LockTag组件）
--- @param ... any 额外参数（未使用但保留兼容）
function BattleLockTag.Ctor(self, markGO, ...)
	self._markGO = markGO
	self._markTF = markGO.transform
	self._controller = self._markTF:GetComponent("LockTag")
	self._flag = true
end

--- 开始标记/锁定
--- @param requiredTime number 锁定时长（秒）
function BattleLockTag.Mark(self, requiredTime)
	self._markTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._requiredTime = requiredTime

	SetActive(self._markGO, true)

	self._controller.enabled = true
end

--- 每帧更新锁定进度
--- @param combatTime number 当前战斗时间
function BattleLockTag.Update(self, combatTime)
	local rate = (combatTime - self._markTime) / self._requiredTime

	if rate >= 1 and self._flag then
		-- 锁定完成：设置进度为1，关闭控制器，播放完成动画
		self._controller:SetRate(1)

		self._controller.enabled = false
		self._markTF:GetComponent(typeof(Animator)).enabled = true
		self._flag = false
	elseif self._flag then
		-- 锁定中：更新进度
		self._controller:SetRate(rate)
	end
end

--- 更新标记位置
--- @param worldPos Vector3 世界坐标
function BattleLockTag.SetPosition(self, worldPos)
	self._markTF.position = worldPos
end

--- 设置锁定计数（显示当前有多少个单位在锁定该目标）
--- @param count number
function BattleLockTag.SetTagCount(self, count)
	self._controller.count = count
end

--- 销毁标记
function BattleLockTag.Dispose(self)
	Object.Destroy(self._markGO)
end
