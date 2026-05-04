ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConfig = ys.Battle.BattleConfig
local BattleReisalinAPView = class("BattleReisalinAPView")

ys.Battle.BattleReisalinAPView = BattleReisalinAPView
BattleReisalinAPView.__name = "BattleReisalinAPView"

--- 莱莎琳（Reisalin）AP值UI视图
--- 显示炼金术士角色的AP点数，满值时显示金色发光特效

function BattleReisalinAPView.Ctor(self, tf)
	self._tf = tf

	self:init()
end

function BattleReisalinAPView.init(self)
	self._apCap = BattleConfig.FLEET_ATTR_CAP[self:GetAttrName()]
	self._count = findTF(self._tf, "count")
	self._glow = findTF(self._tf, "glow_gizmos")
	self._countText = self._count:GetComponent(typeof(Text))

	SetActive(self._tf, true)
	self:UpdateAP(0)
end

--- 更新AP值显示
--- @param ap number 当前AP值
function BattleReisalinAPView.UpdateAP(self, ap)
	self._countText.text = ap

	-- AP满值时显示金色和发光特效
	if ap >= self._apCap then
		self._countText.color = Color.ReisalinGold

		SetActive(self._glow, true)
	else
		self._countText.color = Color.white

		SetActive(self._glow, false)
	end
end

--- 获取属性名称（ALCHEMIST_AP_NAME）
function BattleReisalinAPView.GetAttrName(self)
	return BattleConfig.ALCHEMIST_AP_NAME
end

function BattleReisalinAPView.Dispose(self)
	self._count = nil
	self._glow = nil
	self._countText = nil
	self._tf = nil
end
