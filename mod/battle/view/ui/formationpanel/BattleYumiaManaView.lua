ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConfig = ys.Battle.BattleConfig
local BattleYumiaManaView = class("BattleYumiaManaView")

ys.Battle.BattleYumiaManaView = BattleYumiaManaView
BattleYumiaManaView.__name = "BattleYumiaManaView"
-- 提示显示时长（秒）
BattleYumiaManaView.TIPS_DURATION = 5

--- 优米娅（Yumia）魔力值UI视图
--- 显示战斗中优米娅角色的AP/魔力值进度条

function BattleYumiaManaView.Ctor(self, tf)
	pg.DelegateInfo.New(self)

	self._tf = tf
	self._go = tf.gameObject

	self:init()
end

function BattleYumiaManaView.init(self)
	-- 获取AP上限
	self._apCap = BattleConfig.FLEET_ATTR_CAP[self:GetAttrName()]
	self._count = findTF(self._tf, "count")
	self._progress = findTF(self._tf, "progress")
	self._countText = self._count:GetComponent(typeof(Text))

	SetActive(self._tf, true)

	self._barVector = rtf(self._progress).sizeDelta

	self:UpdateMana(0)
	-- 设置提示文本（中文和阴影）
	setText(findTF(self._tf, "tips/text"), i18n("yumia_mana_battle_tip"))
	setText(findTF(self._tf, "tips/text_shade"), i18n("yumia_mana_battle_tip"))
	-- 点击时显示提示
	onButton(self, self._tf, function()
		self:showTips()
	end)
end

--- 更新魔力值显示
--- @param mana number 当前魔力值
function BattleYumiaManaView.UpdateMana(self, mana)
	setText(self._count, mana)

	self._barVector.x = mana
	rtf(self._progress).sizeDelta = self._barVector
end

--- 获取属性名称
function BattleYumiaManaView.GetAttrName(self)
	return BattleConfig.YUMIA_MANA_NAME
end

--- 显示提示面板（自动在TIPS_DURATION秒后隐藏）
function BattleYumiaManaView.showTips(self)
	if LeanTween.isTweening(self._go) then
		return
	end

	SetActive(self._tf:Find("tips"), true)
	LeanTween.delayedCall(self._go, BattleYumiaManaView.TIPS_DURATION, System.Action(function()
		SetActive(self._tf:Find("tips"), false)
	end))
end

function BattleYumiaManaView.Dispose(self)
	LeanTween.cancel(self._go)
	pg.DelegateInfo.Dispose(self)

	self._count = nil
	self._progress = nil
	self._countText = nil
	self._tf = nil
end
