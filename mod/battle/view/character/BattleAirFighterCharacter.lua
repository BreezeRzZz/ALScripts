ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleAirFighterUnit = ys.Battle.BattleAirFighterUnit

ys.Battle.BattleAirFighterCharacter = class("BattleAirFighterCharacter", ys.Battle.BattleAircraftCharacter)
ys.Battle.BattleAirFighterCharacter.__name = "BattleAirFighterCharacter"

local BattleAirFighterCharacter = ys.Battle.BattleAirFighterCharacter

--- 构造函数：初始化缩放向量
function BattleAirFighterCharacter.Ctor(self)
	BattleAirFighterCharacter.super.Ctor(self)

	self._scaleVector = Vector3(1, 1, 1)
end

--- 设置UnitData并标记为不可选中
--- @param unitData BattleAirFighterUnitData 战斗机单位数据
function BattleAirFighterCharacter.SetUnitData(self, unitData)
	self._unitData = unitData

	self:AddUnitEvent()
	unitData:SetUnVisitable()
end

--- 添加战斗机模型
--- @param modelGO GameObject 模型GameObject
function BattleAirFighterCharacter.AddModel(self, modelGO)
	self:SetGO(modelGO)
	self:SetBoneList()
	self._unitData:ActiveCldBox()
end

--- 每帧Update：矩阵、UI、HP条、位置、阴影（仅在俯冲/攻击/爬升状态）
function BattleAirFighterCharacter.Update(self)
	self:UpdateMatrix()
	self:UpdateUIComponentPosition()
	self:UpdateHPPop()
	self:UpdateHPPopContainerPosition()
	self:UpdateHPBarPosition()
	self:UpdatePosition()
	self:UpdateHpBar()

	local strikeState = self._unitData:GetStrikeState()

	-- 俯冲、攻击、爬升状态下更新阴影
	if strikeState == BattleAirFighterUnit.STRIKE_STATE_DOWN or strikeState == BattleAirFighterUnit.STRIKE_STATE_ATTACK or strikeState == BattleAirFighterUnit.STRIKE_STATE_UP then
		self:UpdateShadow()
	end
end

--- 注册空袭状态变化事件
function BattleAirFighterCharacter.AddUnitEvent(self)
	BattleAirFighterCharacter.super.AddUnitEvent(self)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.AIR_STRIKE_STATE_CHANGE, self.onStrikeStateChange)
end

--- 移除空袭状态变化事件
function BattleAirFighterCharacter.RemoveUnitEvent(self)
	BattleAirFighterCharacter.super.RemoveUnitEvent(self)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.AIR_STRIKE_STATE_CHANGE)
end

--- 空袭状态变化：根据STRIKE状态调整模型缩放和UI可见性
---
--- 状态说明：
--- - FLY: 编队飞行，放大模型，隐藏阴影
--- - BACK: 返航（朝左），HP条和阴影显示
--- - BACKWARD: 返航（朝右）
--- - DOWN/ATTACK/UP: 俯冲轰炸三阶段，不改变缩放
function BattleAirFighterCharacter.onStrikeStateChange(self)
	local strikeState = self._unitData:GetStrikeState()

	if strikeState == BattleAirFighterUnit.STRIKE_STATE_FLY then
		-- 编队飞行：根据编队索引放大模型
		local flyScale = (12 / (self._unitData:GetFormationIndex() + 3) + 1) * self._unitData:GetSize()

		self._scaleVector:Set(flyScale, flyScale, flyScale)

		self._tf.localScale = self._scaleVector

		self._shadow:SetActive(false)
	elseif strikeState == BattleAirFighterUnit.STRIKE_STATE_BACK then
		-- 返航（朝左）
		local backScale = self._unitData:GetSize()

		self._scaleVector:Set(-backScale, backScale, backScale)

		self._tf.localScale = self._scaleVector

		self._HPBar:SetActive(true)
		self._shadow:SetActive(true)
	elseif strikeState == BattleAirFighterUnit.STRIKE_STATE_DOWN then
		-- 俯冲中，不改变视觉效果
	elseif strikeState == BattleAirFighterUnit.STRIKE_STATE_ATTACK then
		-- 攻击中
	elseif strikeState == BattleAirFighterUnit.STRIKE_STATE_UP then
		-- 爬升中
	elseif strikeState == BattleAirFighterUnit.STRIKE_STATE_FREE then
		-- 自由状态
	elseif strikeState == BattleAirFighterUnit.STRIKE_STATE_BACKWARD then
		-- 返航（朝右）
		local backwardScale = self._unitData:GetSize()

		self._scaleVector:Set(backwardScale, backwardScale, backwardScale)

		self._tf.localScale = self._scaleVector
	end
end
