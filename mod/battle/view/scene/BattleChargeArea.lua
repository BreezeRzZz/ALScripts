ys = ys or {}

local ys = ys

ys.Battle.BattleChargeArea = class("BattleChargeArea")
ys.Battle.BattleChargeArea.__name = "BattleChargeArea"

--- @class BattleChargeArea
--- 蓄力武器范围显示（如战列舰瞄准圈）
--- 从武器模板读取range和angle，动态调整扇形区域的尺寸和角度范围
--- @param chargeAreaGO GameObject 蓄力区域GameObject（挂载ChargeArea组件）
function ys.Battle.BattleChargeArea.Ctor(self, chargeAreaGO)
	chargeAreaGO.gameObject:SetActive(false)

	self._areaTf = chargeAreaGO.transform
	self._areaGO = chargeAreaGO
end

--- 初始化区域参数
--- 从关联武器读取range/angle，计算扇形显示尺寸
--- 5.5 是基准range对应的缩放值
function ys.Battle.BattleChargeArea.InitArea(self)
	local areaTf = self._areaTf

	self._controller = areaTf:GetComponent("ChargeArea")

	local weaponRange = self._chargeWeapon:GetTemplateData().range
	local weaponAngle = self._chargeWeapon:GetTemplateData().angle
	local scale = areaTf.localScale

	-- 范围映射到缩放：range / 5.5（5.5是基础比例因子）
	scale.x = weaponRange / 5.5
	scale.y = weaponRange / 5.5
	areaTf.localScale = scale
	self._controller.maxAngle = weaponAngle
	self._controller.minAngle = self._chargeWeapon:GetMinAngle()

	-- 修正上下边沿缩放，防止拉伸变形
	areaTf:Find("UpperEdge").transform.localScale = Vector3(1, 1 / scale.y, 1)
	areaTf:Find("LowerEdge").transform.localScale = Vector3(1, 1 / scale.y, 1)

	-- 初始蓄力速率
	self._controller.rate = 0.5
end

--- 每帧更新位置
--- @param worldPos Vector3 世界坐标
function ys.Battle.BattleChargeArea.Update(self, worldPos)
	self._areaTf.position = worldPos
end

--- 绑定武器，初始化显示参数
--- @param weapon BattleWeaponUnit
function ys.Battle.BattleChargeArea.SetWeapon(self, weapon)
	self._chargeWeapon = weapon

	self:InitArea()
end

--- 激活/隐藏蓄力区域
--- @param isActive boolean
function ys.Battle.BattleChargeArea.SetActive(self, isActive)
	self._areaGO:SetActive(isActive)
end

--- 获取当前激活状态
--- @return boolean
function ys.Battle.BattleChargeArea.GetActive(self)
	return self._areaGO:GetActive()
end

--- 重置蓄力速率到满值
function ys.Battle.BattleChargeArea.Reset(self)
	self._controller.rate = 1
end
