ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleMinionCharacter = class("BattleMinionCharacter", ys.Battle.BattleCharacter)
ys.Battle.BattleMinionCharacter.__name = "BattleMinionCharacter"

local BattleMinionCharacter = ys.Battle.BattleMinionCharacter

--- 构造函数：初始化前摇绑定标志
function BattleMinionCharacter.Ctor(self)
	BattleMinionCharacter.super.Ctor(self)

	self._preCastBound = false
end

--- 武器注册时额外绑定前摇事件
--- @param weapon BattleWeaponUnit 武器实例
function BattleMinionCharacter.RegisterWeaponListener(self, weapon)
	BattleMinionCharacter.super.RegisterWeaponListener(self, weapon)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST, self.onWeaponPreCast)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST_FINISH, self.onWeaponPrecastFinish)
end

--- 取消武器前摇事件
function BattleMinionCharacter.UnregisterWeaponListener(self, weapon)
	BattleMinionCharacter.super.UnregisterWeaponListener(self, weapon)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST_FINISH)
end

--- 每帧Update：位置、矩阵（不更新箭头，召唤物在屏幕内）
function BattleMinionCharacter.Update(self)
	BattleMinionCharacter.super.Update(self)
	self:UpdatePosition()
	self:UpdateMatrix()
end

--- 更新组件可见性：仅对敌方召唤物生效
function BattleMinionCharacter.updateComponentVisible(self)
	if self._unitData:GetIFF() ~= BattleConfig.FOE_CODE then
		return
	end

	local exposed = self._unitData:GetExposed()
	local diveDetected = self._unitData:GetDiveDetected()
	local diveInvisible = self._unitData:GetDiveInvisible()
	local isVisible = exposed and (not diveInvisible or not not diveDetected)

	SetActive(self._HPBarTf, isVisible)
	SetActive(self._FXAttachPoint, isVisible)
end

--- 更新潜入隐身时组件可见性
function BattleMinionCharacter.updateComponentDiveInvisible(self)
	local isDetected = self._unitData:GetDiveDetected() and self._unitData:GetIFF() == BattleConfig.FOE_CODE
	local isDiveInvisible = self._unitData:GetDiveInvisible()
	local isVisible = (isDetected or not isDiveInvisible) and true or false

	SetActive(self._HPBarTf, isVisible)
	SetActive(self._FXAttachPoint, isVisible)
end

--- 销毁：恢复Shader颜色
function BattleMinionCharacter.Dispose(self)
	self:AddShaderColor()
	BattleMinionCharacter.super.Dispose(self)
end

--- @return string 模型prefab名称
function BattleMinionCharacter.GetModleID(self)
	return self._unitData:GetTemplate().prefab
end

--- 武器前摇开始：播放前摇特效
--- @param event table {Data = {fx, isBound}}
function BattleMinionCharacter.onWeaponPreCast(self, event)
	local precastData = event.Data
	local fxName = precastData.fx

	self:AddFX(fxName, true)

	self._preCastBound = precastData.isBound
end

--- 武器前摇结束：移除缓存的特效
function BattleMinionCharacter.onWeaponPrecastFinish(self, event)
	local fxName = event.Data.fx

	self:RemoveCacheFX(fxName)

	self._preCastBound = false
end

--- HP更新：受伤时添加白色闪烁
--- @param event table {Data = {dHP}}
function BattleMinionCharacter.OnUpdateHP(self, event)
	BattleMinionCharacter.super.OnUpdateHP(self, event)

	if event.Data.dHP <= 0 then
		self:AddBlink(1, 1, 1, 0.1, 0.1, true)
	end
end

--- 添加模型并设置HP条偏移（使用模板的hp_bar[2]）
function BattleMinionCharacter.AddModel(self, modelGO)
	BattleMinionCharacter.super.AddModel(self, modelGO)

	local hpBarHeight = self._unitData:GetTemplate().hp_bar[2]

	self._hpBarOffset = Vector3(0, hpBarHeight, 0)
end

--- 获取特定FX缩放
--- @return table FX缩放表
function BattleMinionCharacter.GetSpecificFXScale(self)
	return self._unitData:GetTemplate().specific_fx_scale
end

--- 动画触发回调
function BattleMinionCharacter.OnAnimatorTrigger(self)
	self._unitData:CharacterActionTriggerCallback()
end

--- 动画结束回调
function BattleMinionCharacter.OnAnimatorEnd(self)
	self._unitData:CharacterActionEndCallback()
end

--- 动画开始回调
function BattleMinionCharacter.OnAnimatorStart(self)
	self._unitData:CharacterActionStartCallback()
end

--- 更新瞄准偏斜条：同时缩放迷雾特效
function BattleMinionCharacter.UpdateAimBiasBar(self)
	BattleMinionCharacter.super.UpdateAimBiasBar(self)

	if self._fogFx then
		local aimBiasRate = self:GetUnitData():GetAimBias():GetCurrentRate()

		self._fogFx.transform.localScale = Vector3(aimBiasRate, aimBiasRate, 1)
	end
end
