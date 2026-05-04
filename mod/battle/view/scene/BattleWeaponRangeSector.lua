ys = ys or {}

local ys = ys

ys.Battle.BattleWeaponRangeSector = class("BattleWeaponRangeSector")
ys.Battle.BattleWeaponRangeSector.__name = "BattleWeaponRangeSector"

local BattleWeaponRangeSector = ys.Battle.BattleWeaponRangeSector

--- @class BattleWeaponRangeSector
--- 武器射程扇形指示器
--- 在场景中显示武器的最大/最小攻击范围，用于可视化展示武器射程区域
--- @param sectorTF Transform 扇形指示器Transform（包含minSector和maxSector子节点）
function BattleWeaponRangeSector.Ctor(self, sectorTF)
	self._tf = sectorTF

	setActive(self._tf, true)
	self:initSector()
end

--- 绑定宿主角色和武器
--- @param host BattleCharacter 宿主角色
--- @param weapon BattleWeaponUnit 武器实例
function BattleWeaponRangeSector.ConfigHost(self, host, weapon)
	self._host = host
	self._weapon = weapon

	self:updateSector(self._weapon)
end

--- 初始化扇形区域子节点和材质引用
function BattleWeaponRangeSector.initSector(self)
	self._minRange = self._tf:Find("minSector")
	self._minSector = self._minRange:Find("sector"):GetComponent(typeof(Renderer)).material
	self._maxRange = self._tf:Find("maxSector")
	self._maxSector = self._maxRange:Find("sector"):GetComponent(typeof(Renderer)).material
end

--- 根据武器数据更新扇形尺寸和角度
--- 从武器的攻击角度和rangeSqr计算显示缩放
--- @param weapon BattleWeaponUnit
function BattleWeaponRangeSector.updateSector(self, weapon)
	local attackAngle = weapon:GetAttackAngle()
	local maxRangeDiameter = weapon._maxRangeSqr * 2
	local minRangeDiameter = weapon._minRangeSqr * 2

	self._maxRange.localScale = Vector3(maxRangeDiameter, 1, maxRangeDiameter)
	self._minRange.localScale = Vector3(minRangeDiameter, 1, minRangeDiameter)

	-- 设置扇形shader的角度参数
	self._maxSector:SetInt("_Angle", attackAngle)
	self._minSector:SetInt("_Angle", attackAngle)
end

--- 销毁扇形指示器
function BattleWeaponRangeSector.Dispose(self)
	Destroy(self._tf)

	self._host = nil
	self._weapon = nil
end
