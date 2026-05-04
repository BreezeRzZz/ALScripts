ys = ys or {}

local ys = ys
-- 未在文件中直接使用的引用，可能为下游预留
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleCustomWarningLabel = class("BattleCustomWarningLabel")

ys.Battle.BattleCustomWarningLabel = BattleCustomWarningLabel
BattleCustomWarningLabel.__name = "BattleCustomWarningLabel"

--- 技能自定义警告标签，显示在屏幕指定位置，有持续时间
--- @param go GameObject 标签的GameObject
function BattleCustomWarningLabel.Ctor(self, go)
	self._go = go
	self._tf = go.transform
	self._expire = false
end

--- 配置警告标签的数据（文本、位置、持续时间）
--- @param data table 含dialogue（对话文本）、x/y（屏幕坐标，范围-1~1）、duration（持续时间，秒）
function BattleCustomWarningLabel.ConfigData(self, data)
	setText(self._tf:Find("text"), i18n(data.dialogue))

	self._duration = data.duration

	-- 将-1~1的坐标映射到0~1的anchor范围
	local anchorX = (data.x + 1) * 0.5
	local anchorY = (data.y + 1) * 0.5

	self._tf.anchorMin = Vector2(anchorX, anchorY)
	self._tf.anchorMax = Vector2(anchorX, anchorY)
	self._startTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime()
end

--- @return number 标签的持续时间（0表示永久）
function BattleCustomWarningLabel.GetDuration(self)
	return self._duration
end

--- 标记为过期
function BattleCustomWarningLabel.SetExpire(self)
	self._expire = true
end

--- @return boolean 是否已过期
function BattleCustomWarningLabel.IsExpire(self)
	return self._expire
end

--- 检查持续时间，如果已超过则标记过期
function BattleCustomWarningLabel.Update(self)
	if self._duration > 0 and pg.TimeMgr.GetInstance():GetCombatTime() - self._startTimeStamp > self._duration then
		self:SetExpire()
	end
end

--- 销毁标签的GameObject
function BattleCustomWarningLabel.Dispose(self)
	Destroy(self._go)

	self._go = nil
	self._tf = nil
end
