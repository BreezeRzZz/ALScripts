ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleEnemyCharacter = class("BattleEnemyCharacter", ys.Battle.BattleCharacter)
ys.Battle.BattleEnemyCharacter.__name = "BattleEnemyCharacter"

local BattleEnemyCharacter = ys.Battle.BattleEnemyCharacter

--- 构造函数：初始化prefab偏移量和前摇绑定标志
function BattleEnemyCharacter.Ctor(self)
	BattleEnemyCharacter.super.Ctor(self)

	self._preCastBound = false
	self._prefabPos = Vector3(0, 0, 0)
end

--- 武器注册时额外绑定前摇/打断事件
--- @param weapon BattleWeaponUnit 武器实例
function BattleEnemyCharacter.RegisterWeaponListener(self, weapon)
	BattleEnemyCharacter.super.RegisterWeaponListener(self, weapon)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST, self.onWeaponPreCast)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST_FINISH, self.onWeaponPrecastFinish)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_INTERRUPT, self.onWeaponInterrupted)
end

--- 取消武器注册
function BattleEnemyCharacter.UnregisterWeaponListener(self, weapon)
	BattleEnemyCharacter.super.UnregisterWeaponListener(self, weapon)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST_FINISH)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_INTERRUPT)
end

--- 每帧Update：位置、矩阵、箭头、反潜警戒条
function BattleEnemyCharacter.Update(self)
	BattleEnemyCharacter.super.Update(self)
	self:UpdatePosition()
	self:UpdateMatrix()
	self:UpdateArrowBarPosition()
	self:UpdateArrowBarRotation()

	if self._vigilantBar then
		self:UpdateVigilantBarPosition()
		self._vigilantBar:UpdateVigilantProgress()
	end
end

--- 销毁：清理警戒条，恢复Shader颜色
function BattleEnemyCharacter.Dispose(self)
	if self._vigilantBar then
		self._vigilantBar:Dispose()

		self._vigilantBar = nil
	end

	self:AddShaderColor()
	self._factory:GetArrowPool():DestroyObj(self._arrowBar)
	BattleEnemyCharacter.super.Dispose(self)
end

--- @return string 模型prefab名称
function BattleEnemyCharacter.GetModleID(self)
	return self._unitData:GetTemplate().prefab
end

--- 武器前摇开始：播放前摇特效
--- @param event table {Data = {fx, isBound}}
function BattleEnemyCharacter.onWeaponPreCast(self, event)
	local precastData = event.Data
	local fxName = precastData.fx

	self:AddFX(fxName, true)

	self._preCastBound = precastData.isBound
end

--- 武器前摇结束：移除缓存的特效
function BattleEnemyCharacter.onWeaponPrecastFinish(self, event)
	local fxName = event.Data.fx

	self:RemoveCacheFX(fxName)

	self._preCastBound = false
end

--- HP更新：受伤时添加白色闪烁效果
--- @param event table {Data = {dHP}}
function BattleEnemyCharacter.OnUpdateHP(self, event)
	BattleEnemyCharacter.super.OnUpdateHP(self, event)

	if event.Data.dHP <= 0 then
		self:AddBlink(1, 1, 1, 0.1, 0.1, true)
	end
end

--- 添加模型并设置HP条偏移（使用模板的hp_bar[2]）
--- @param modelGO GameObject 模型GameObject
function BattleEnemyCharacter.AddModel(self, modelGO)
	BattleEnemyCharacter.super.AddModel(self, modelGO)

	local hpBarHeight = self._unitData:GetTemplate().hp_bar[2]

	self._hpBarOffset = Vector3(0, hpBarHeight, 0)
end

--- 获取特定FX缩放（来自模板的specific_fx_scale）
--- @return table FX缩放表
function BattleEnemyCharacter.GetSpecificFXScale(self)
	return self._unitData:GetTemplate().specific_fx_scale
end

--- 动画触发回调
function BattleEnemyCharacter.OnAnimatorTrigger(self)
	self._unitData:CharacterActionTriggerCallback()
end

--- 动画结束回调
function BattleEnemyCharacter.OnAnimatorEnd(self)
	self._unitData:CharacterActionEndCallback()
end

--- 动画开始回调
function BattleEnemyCharacter.OnAnimatorStart(self)
	self._unitData:CharacterActionStartCallback()
end

--- 更新瞄准偏斜条：同时缩放迷雾特效以反映当前偏斜率
function BattleEnemyCharacter.UpdateAimBiasBar(self)
	BattleEnemyCharacter.super.UpdateAimBiasBar(self)

	if self._fogFx then
		local aimBiasRate = self:GetUnitData():GetAimBias():GetCurrentRate()

		self._fogFx.transform.localScale = Vector3(aimBiasRate, aimBiasRate, 1)
	end
end

--- 获取角色实际位置（加上prefab偏移）
--- @return Vector3 偏移后的位置
function BattleEnemyCharacter.getCharacterPos(self)
	local prefabOffset = self:GetUnitData():GetTemplate().prefab_offset

	self._prefabPos:Set(self._characterPos.x + prefabOffset[1], self._characterPos.y + prefabOffset[2], self._characterPos.z + prefabOffset[3])

	return self._prefabPos
end
