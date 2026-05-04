ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleConst = ys.Battle.BattleConst
local BattleSubCharacter = class("BattleSubCharacter", ys.Battle.BattlePlayerCharacter)

ys.Battle.BattleSubCharacter = BattleSubCharacter
BattleSubCharacter.__name = "BattleSubCharacter"

--- 构造函数：调用父类初始化
function BattleSubCharacter.Ctor(self)
	BattleSubCharacter.super.Ctor(self)
end

--- 添加箭头条并初始化潜艇专有UI：氧气条和弹药计数
--- - _vectorOxygenSlider: 箭头上的氧气滑动条
--- - _vectorAmmoCount: 鱼雷剩余弹药文字
function BattleSubCharacter.AddArrowBar(self, arrowBarObj)
	BattleSubCharacter.super.AddArrowBar(self, arrowBarObj)

	self._vectorOxygenSlider = self._arrowBarTf:Find("submarine/oxygenBar/oxygen"):GetComponent(typeof(Slider))
	self._vectorOxygenSlider.value = 1
	self._vectorAmmoCount = self._arrowBarTf:Find("submarine/Count/CountText"):GetComponent(typeof(Text))

	local torpedoCount = #self._unitData:GetTorpedoList()

	self._vectorAmmoCount.text = torpedoCount .. "/" .. torpedoCount
end

--- 每帧Update：视野外时更新氧气指示器
function BattleSubCharacter.Update(self)
	BattleSubCharacter.super.Update(self)

	if not self._inViewArea then
		self:updateOxygenVector()
	end
end

--- 更新箭头上的氧气条进度
function BattleSubCharacter.updateOxygenVector(self)
	self._vectorOxygenSlider.value = self._unitData:GetOxygenProgress()
end

--- 鱼雷发射事件：更新箭头上弹药计数
function BattleSubCharacter.onTorpedoWeaponFire(self, event)
	BattleSubCharacter.super.onTorpedoWeaponFire(self, event)

	local readyCount = 0

	for _, torpedoWeapon in ipairs(self._unitData:GetTorpedoList()) do
		if torpedoWeapon:GetCurrentState() == torpedoWeapon.STATE_READY then
			readyCount = readyCount + 1
		end
	end

	self._vectorAmmoCount.text = readyCount .. "/" .. #self._unitData:GetTorpedoList()
end
