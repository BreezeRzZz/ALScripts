ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleMainDamagedView = class("BattleMainDamagedView")

local BattleMainDamagedView = class("BattleMainDamagedView")

ys.Battle.BattleMainDamagedView = BattleMainDamagedView
BattleMainDamagedView.__name = "BattleMainDamagedView"

--- 旗舰受损时的屏幕出血特效视图
--- 当旗舰受到伤害时播放红色出血动画
--- @param go GameObject 出血特效的GameObject
function BattleMainDamagedView.Ctor(self, go)
	self._go = go

	self:Init()
end

--- 初始化出血视图，绑定动画结束事件
function BattleMainDamagedView.Init(self)
	self._tf = self._go.transform
	self._bleedView = findTF(self._tf, "mainUnitDamaged")
	self._bleedAnimation = self._bleedView:GetComponent(typeof(Animator))

	-- 动画播放结束后自动隐藏
	self._bleedView:GetComponent(typeof(DftAniEvent)):SetEndEvent(function(_)
		setActive(self._bleedView, false)

		self._isPlaying = false
	end)
	setActive(self._bleedView, false)

	self._isPlaying = false
end

--- 播放出血特效（如果已经在播放则重新激活）
function BattleMainDamagedView.Play(self)
	if not self._isPlaying then
		setActive(self._bleedView, true)
	end

	self._isPlaying = true
end

--- 清理视图引用
function BattleMainDamagedView.Dispose(self)
	self._bleedView = nil
	self._bleedAnimation = nil
	self._tf = nil
	self._go = nil
end
