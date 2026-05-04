ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleAircraftCharacter = class("BattleAircraftCharacter", ys.Battle.BattleCharacter)
ys.Battle.BattleAircraftCharacter.__name = "BattleAircraftCharacter"

local BattleAircraftCharacter = ys.Battle.BattleAircraftCharacter

--- 构造函数：设置HP条偏移、Y轴抖动参数、阴影参数
function BattleAircraftCharacter.Ctor(self)
	BattleAircraftCharacter.super.Ctor(self)

	self._hpBarOffset = Vector3(0, 1.6, 0)

	self:SetYShakeMin()
	self:SetYShakeMax()

	self.shadowScale = Vector3.one
	self.shadowPos = Vector3.zero
end

--- 设置UnitData并注册事件
--- @param unitData BattleAircraftUnitData 飞机单位数据
function BattleAircraftCharacter.SetUnitData(self, unitData)
	self._unitData = unitData

	self:AddUnitEvent()
end

--- 初始化武器：从UnitData获取武器列表并注册子弹事件
function BattleAircraftCharacter.InitWeapon(self)
	self._weapon = self._unitData:GetWeapon()

	for _, weapon in ipairs(self._weapon) do
		weapon:RegisterEventListener(self, BattleUnitEvent.CREATE_BULLET, self.onCreateBullet)
	end
end

--- 获取模型prefab ID（使用皮肤ID）
--- @return number|string 皮肤ID
function BattleAircraftCharacter.GetModleID(self)
	return self._unitData:GetSkinID()
end

--- 飞机初始缩放固定为1
--- @return number 1
function BattleAircraftCharacter.GetInitScale(self)
	return 1
end

--- 飞机不注册默认单位事件（重写为空）
function BattleAircraftCharacter.AddUnitEvent(self)
	return
end

--- 移除武器事件：清理子弹创建监听和敌方飞机HP更新
function BattleAircraftCharacter.RemoveUnitEvent(self)
	for _, weapon in ipairs(self._weapon) do
		weapon:UnregisterEventListener(self, BattleUnitEvent.CREATE_BULLET)
	end

	if self._unitData:GetIFF() == ys.Battle.BattleConfig.FOE_CODE then
		self._unitData:UnregisterEventListener(self, BattleUnitEvent.UPDATE_AIR_CRAFT_HP)
	end
end

--- 飞机不播放动作动画（重写为空）
function BattleAircraftCharacter.PlayAction(self)
	return
end

--- 每帧Update：矩阵、朝向、UI组件、阴影、位置
--- 敌方飞机额外更新HP相关UI
function BattleAircraftCharacter.Update(self)
	self:UpdateMatrix()
	self:UpdateDirection()
	self:UpdateUIComponentPosition()
	self:UpdateShadow()
	self:UpdatePosition()

	if self._unitData:GetIFF() == ys.Battle.BattleConfig.FOE_CODE then
		self:UpdateHPPop()
		self:UpdateHPPopContainerPosition()
		self:UpdateHPBarPosition()
		self:UpdateHpBar()
	end
end

--- 更新飞机位置：视野外时不设置Transform
function BattleAircraftCharacter.UpdatePosition(self)
	if not self._unitData:IsOutViewBound() then
		self._tf.localPosition = self._unitData:GetPosition()
	end

	self._characterPos = self._unitData:GetPosition()
end

--- 更新飞机朝向：根据飞行方向翻转模型
function BattleAircraftCharacter.UpdateDirection(self)
	if self._unitData:GetCurrentState() ~= self._unitData.STATE_CREATE then
		return
	end

	local size = self._unitData:GetSize()

	if self._unitData:GetDirection() == ys.Battle.BattleConst.UnitDir.RIGHT then
		self._tf.localScale = Vector3(size, size, size)
	elseif self._unitData:GetDirection() == ys.Battle.BattleConst.UnitDir.LEFT then
		self._tf.localScale = Vector3(-size, size, size)
	end
end

--- 更新HP条位置
function BattleAircraftCharacter.UpdateHPBarPosition(self)
	self._hpBarPos:Copy(self._referenceVector):Add(self._hpBarOffset)

	self._HPBarTf.position = self._hpBarPos
end

--- 更新阴影缩放：根据飞机高度动态调整阴影大小（模拟高度感）
--- 高度越高阴影越小（2~4范围）
function BattleAircraftCharacter.UpdateShadow(self)
	if self._shadow and self._unitData:GetCurrentState() == self._unitData.STATE_CREATE then
		local unitPos = self._unitData:GetPosition()
		local shadowScale = math.min(4, math.max(2, 4 - 4 * unitPos.y / ys.Battle.BattleConfig.AircraftHeight))

		self.shadowScale.x, self.shadowScale.z = shadowScale, shadowScale
		self._shadowTF.localScale = self.shadowScale
		self.shadowPos.x, self.shadowPos.z = unitPos.x, unitPos.z
		self._shadowTF.position = self.shadowPos
	end
end

--- Y轴上下浮动模拟（simple harmonic-like motion）
--- @return number 当前Y轴浮动偏移
function BattleAircraftCharacter.GetYShake(self)
	self._YShakeCurrent = self._YShakeCurrent or 0
	self._YShakeDir = self._YShakeDir or 1
	self._YShakeCurrent = self._YShakeCurrent + 0.1 * self._YShakeDir

	if self._YShakeCurrent > self._YShakeMax and self._YShakeDir == 1 then
		self._YShakeDir = -1

		self:SetYShakeMin()
	elseif self._YShakeCurrent < self._YShakeMin and self._YShakeDir == -1 then
		self._YShakeDir = 1

		self:SetYShakeMax()
	end

	return self._YShakeCurrent
end

--- 设置Y轴抖动下限（-1 ~ -3 范围随机）
function BattleAircraftCharacter.SetYShakeMin(self)
	self._YShakeMin = -1 - 2 * math.random()
end

--- 设置Y轴抖动上限（1 ~ 3 范围随机）
function BattleAircraftCharacter.SetYShakeMax(self)
	self._YShakeMax = 1 + 2 * math.random()
end

--- 添加飞机模型：设置GameObject、碰撞盒和位置
--- @param modelGO GameObject 飞机模型GameObject
function BattleAircraftCharacter.AddModel(self, modelGO)
	self:SetGO(modelGO)

	self._hpBarOffset = Vector3(0, self._unitData:GetBoxSize().y, 0)

	self:SetBoneList()

	self._tf.position = self._unitData:GetPosition()

	self:UpdateMatrix()
	self._unitData:ActiveCldBox()
end

--- 飞机阴影从model/shadow子节点获取
--- @param shadowPlaceholder 未使用
function BattleAircraftCharacter.AddShadow(self, shadowPlaceholder)
	self._shadow = self:GetTf():Find("model/shadow").gameObject
	self._shadowTF = self._shadow.transform
end

--- 添加HP条（使用UPDATE_AIR_CRAFT_HP事件，与普通单位不同）
--- @param hpBarObj GameObject HP条对象
function BattleAircraftCharacter.AddHPBar(self, hpBarObj)
	self._HPBar = hpBarObj
	self._HPBarTf = hpBarObj.transform
	self._HPProgress = self._HPBarTf:Find("blood"):GetComponent(typeof(Image))

	hpBarObj:SetActive(true)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_AIR_CRAFT_HP, self.OnUpdateHP)
	self:UpdateHpBar()
end

--- 飞机不使用烟雾特效（重写为空）
function BattleAircraftCharacter.updateSomkeFX(self)
	return
end
