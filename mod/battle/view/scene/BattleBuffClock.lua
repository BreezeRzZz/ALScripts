ys = ys or {}

local ys = ys

ys.Battle.BattleBuffClock = class("BattleBuffClock")
ys.Battle.BattleBuffClock.__name = "BattleBuffClock"

local BattleBuffClock = ys.Battle.BattleBuffClock

--- Buff时钟相对角色的偏移量
BattleBuffClock.OFFSET = Vector3(1.8, 2.3, 0)
--- Buff图标类型数量（最多3种图标样式）
BattleBuffClock.TYPE_INDEX = 3

--- @class BattleBuffClock
--- Buff特效倒计时视图
--- 在角色头顶显示圆形Buff倒计时，支持多种图标类型（bg/danger/interrupt/casting各有3种样式子节点）
--- 与BattleCastBar共用相似的UI布局，但进度是从buffEffect获取（通过GetCountProgress）
--- @param castClockTF Transform Buff时钟Transform
function BattleBuffClock.Ctor(self, castClockTF)
	self._castClockTF = castClockTF
	self._castClockGO = self._castClockTF.gameObject
	self._bgList = self._castClockTF:Find("bg")
	self._danger = self._castClockTF:Find("danger")
	self._interrupt = self._castClockTF:Find("interrupt")
	self._casting = self._castClockTF:Find("casting")
	self._progressProtected = self._castClockTF:Find("progress/protected")
	self._progressInterrupt = self._castClockTF:Find("progress/interrupt")
	self._clockCG = self._castClockTF:GetComponent(typeof(CanvasGroup))
end

--- 切换图标类型
--- 在parentTF下找1/2/3子节点，只激活匹配iconType的那一个
--- @param parentTF Transform 包含类型子节点的父节点
--- @param iconType number 目标类型 (1~TYPE_INDEX)
function BattleBuffClock.switchToIndex(self, parentTF, iconType)
	for iconIdx = 1, BattleBuffClock.TYPE_INDEX do
		local childTF = parentTF:Find(tostring(iconIdx))

		SetActive(childTF, iconType == iconIdx)
	end
end

--- 检查当前是否有活跃的buff特效
--- @return boolean
function BattleBuffClock.IsActive(self)
	return self._buffEffect ~= nil
end

--- 开始Buff倒计时动画
--- @param buffData table {iconType: number, interrupt: boolean, buffEffect: BattleBuffEffect}
--- 根据buffData的iconType切换所有图标节点的显示类型
--- 根据interrupt标记使用interrupt或protected进度条
function BattleBuffClock.Casting(self, buffData)
	LeanTween.cancel(self._castClockGO)

	self._castClockTF.localScale = Vector3(0.1, 0.1, 1)

	local iconType = buffData.iconType

	-- 切换所有图标子节点的类型
	self:switchToIndex(self._bgList, iconType)
	self:switchToIndex(self._danger, iconType)
	self:switchToIndex(self._interrupt, iconType)
	self:switchToIndex(self._casting, iconType)
	SetActive(self._progressInterrupt, buffData.interrupt)
	SetActive(self._progressProtected, not buffData.interrupt)

	-- 根据是否可打断选择对应的进度条组件
	self._castProgress = buffData.interrupt and self._progressInterrupt:GetComponent(typeof(Image)) or self._progressProtected:GetComponent(typeof(Image))

	SetActive(self._castClockTF, true)
	SetActive(self._casting, true)
	SetActive(self._interrupt, false)
	LeanTween.scale(rtf(self._castClockGO), Vector3.New(1, 1, 1), 0.1):setEase(LeanTweenType.easeInBack)
	LeanTween.rotate(rtf(self._danger), 360, 5):setLoopClamp()

	self._buffEffect = buffData.buffEffect
end

--- Buff被打断
--- @param buffData table {interrupt: boolean} 对应buff的配置
function BattleBuffClock.Interrupt(self, buffData)
	if buffData.interrupt then
		SetActive(self._casting, false)
		SetActive(self._interrupt, true)
	end

	-- 停止旋转警告
	LeanTween.cancel(go(self._danger))

	-- 闪烁两轮
	for iter_5_0 = 1, 2 do
		LeanTween.alphaCanvas(self._clockCG, 0.3, 0.3):setFrom(1):setDelay(0.3 * (iter_5_0 - 1))
		LeanTween.alphaCanvas(self._clockCG, 1, 0.3):setDelay(0.3 * iter_5_0)
	end

	-- 缩小后隐藏并清空buffEffect引用
	LeanTween.scale(rtf(self._castClockGO), Vector3.New(0.1, 0.1, 1), 0.3):setEase(LeanTweenType.easeInBack):setDelay(1.25):setOnComplete(System.Action(function()
		self._buffEffect = nil

		SetActive(self._castClockTF, false)
	end))
end

--- 更新Buff时钟位置
--- @param worldPos Vector3 角色世界坐标
function BattleBuffClock.UpdateCastClockPosition(self, worldPos)
	self._castClockTF.position = worldPos + BattleBuffClock.OFFSET
end

--- 每帧更新Buff倒计时进度
--- 进度直接从buffEffect获取（由buff逻辑层管理）
function BattleBuffClock.UpdateCastClock(self)
	self._castProgress.fillAmount = self._buffEffect:GetCountProgress()
end

--- 销毁Buff时钟
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
