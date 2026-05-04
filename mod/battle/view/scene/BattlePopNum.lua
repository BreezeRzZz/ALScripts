ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattlePopNum = class("BattlePopNum")
ys.Battle.BattlePopNum.__name = "BattlePopNum"

local BattlePopNum = ys.Battle.BattlePopNum

--- 伤害数字的初始偏移量（从参考点向上偏移1.6单位）
BattlePopNum.NUM_INIT_OFFSET = Vector3(0, 1.6, 0)

--- 回收时移出屏幕的隐藏位置
local hiddenPosition = Vector3(10000, 10000)
--- 回收时重置的缩放值
local hiddenScale = Vector2(1, 1)

--- @class BattlePopNum
--- @param pool LuaObPool 所属的对象池
--- @param initData table {template: GameObject, parentTF: Transform, bundle: BattlePopNumBundle}
--- 构造函数：从模板实例化伤害数字GameObject，挂载到指定父节点，注册动画结束回调回池
function BattlePopNum.Ctor(self, pool, initData)
	self.bundle = initData.bundle
	self.pool = pool

	local go = Object.Instantiate(initData.template)

	self._go = go
	self._tf = go.transform

	self:SetParent(initData.parentTF)

	self._animator = go:GetComponent(typeof(Animator))

	-- 获取文字组件（伤害数字可能有不同字体样式的子节点）
	local textTF = self._tf:Find("text")

	if textTF then
		self.textCom = textTF:GetComponent(typeof(Text))
	end

	-- 动画播放完毕自动回池
	go:GetComponent(typeof(DftAniEvent)):SetEndEvent(function(eventName)
		pool:Recycle(self)
	end)

	self._offsetVector = Vector3.zero
end

--- 设置父节点Transform
--- @param parentTF Transform 新的父节点
function BattlePopNum.SetParent(self, parentTF)
	self._tf:SetParent(parentTF, false)
end

--- 设置显示的文字内容
--- @param text string|number 要显示的伤害数字
function BattlePopNum.SetText(self, text)
	self.textCom.text = tostring(text)
end

--- 设置参考坐标（用于定位在世界空间中）
--- @param referencePoint any 提供GetReferenceVector方法的参考对象
--- @param offset Vector3 额外偏移
function BattlePopNum.SetReferenceCharacter(self, referencePoint, offset)
	self._offsetVector.x = offset.x

	local worldPos = referencePoint:GetReferenceVector(self._offsetVector)

	worldPos:Add(BattlePopNum.NUM_INIT_OFFSET)

	self._tf.position = worldPos
end

--- 启动伤害数字弹出动画
function BattlePopNum.Play(self)
	self._animator.enabled = true
end

--- 设置数字缩放
--- @param scale number 缩放倍率
function BattlePopNum.SetScale(self, scale)
	self._tf.localScale = Vector2(scale, scale)
end

--- 初始化：激活GameObject（从对象池取出时调用）
function BattlePopNum.Init(self)
	self._go:SetActive(true)
end

--- 回收：关闭动画并移到屏幕外隐藏位置（回池时调用）
function BattlePopNum.Recycle(self)
	self._animator.enabled = false
	self._tf.position = hiddenPosition
	self._tf.localScale = hiddenScale
end

--- 销毁：禁用GameObject，清空引用
function BattlePopNum.Dispose(self)
	self._go:SetActive(false)

	self._go = nil
	self._tf = nil
end
