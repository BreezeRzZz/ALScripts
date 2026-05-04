ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleSupportCharacter = class("BattleSupportCharacter", ys.Battle.BattleCharacter)
ys.Battle.BattleSupportCharacter.__name = "BattleSupportCharacter"

local BattleSupportCharacter = ys.Battle.BattleSupportCharacter

--- 构造函数：初始化前摇绑定标志
function BattleSupportCharacter.Ctor(self)
	BattleSupportCharacter.super.Ctor(self)

	self._preCastBound = false
end

--- 武器注册时额外绑定前摇事件
--- @param weapon BattleWeaponUnit 武器实例
function BattleSupportCharacter.RegisterWeaponListener(self, weapon)
	BattleSupportCharacter.super.RegisterWeaponListener(self, weapon)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST, self.onWeaponPreCast)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST_FINISH, self.onWeaponPrecastFinish)
end

--- 取消武器前摇事件
function BattleSupportCharacter.UnregisterWeaponListener(self, weapon)
	BattleSupportCharacter.super.UnregisterWeaponListener(self, weapon)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_PRE_CAST_FINISH)
end

--- 支援角色不执行Update（静态站位）
function BattleSupportCharacter.Update(self)
	return
end

--- 支援角色不更新HP条位置（静态站位）
function BattleSupportCharacter.UpdateHPBarPosition(self)
	return
end

--- 发射子弹：支援角色不使用骨骼位置，直接在单位位置生成
--- @param bulletTmp BattleBulletTemplate 子弹模板
--- @param spawnBone string 生成骨骼名（不使用）
--- @param fireFxID string|nil 开火特效ID
--- @param spawnPos Vector3|nil 指定生成位置（不使用）
function BattleSupportCharacter.SpawnBullet(self, bulletTmp, spawnBone, fireFxID, spawnPos)
	local bulletFactory = self._bulletFactoryList[bulletTmp:GetTemplate().type]
	local unitPos = self._unitData:GetPosition()

	bulletFactory:CreateBullet(self._tf, bulletTmp, unitPos, fireFxID, self._unitData:GetDirection())
end

--- 添加特效：支援角色只执行回调，不创建实际特效
--- @param fxName string 特效名称
--- @param useCache boolean|nil 是否缓存
--- @param timeScale number|nil 时间缩放
--- @param callback function|nil 回调
function BattleSupportCharacter.AddFX(self, fxName, useCache, timeScale, callback)
	if callback then
		callback()
	end
end

--- 更新组件可见性：仅对敌方支援单位生效
function BattleSupportCharacter.updateComponentVisible(self)
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
function BattleSupportCharacter.updateComponentDiveInvisible(self)
	local isDetected = self._unitData:GetDiveDetected() and self._unitData:GetIFF() == BattleConfig.FOE_CODE
	local isDiveInvisible = self._unitData:GetDiveInvisible()
	local isVisible = (isDetected or not isDiveInvisible) and true or false

	SetActive(self._HPBarTf, isVisible)
	SetActive(self._FXAttachPoint, isVisible)
end

--- 销毁：恢复Shader颜色
function BattleSupportCharacter.Dispose(self)
	self:AddShaderColor()
	BattleSupportCharacter.super.Dispose(self)
end

--- @return string 模型prefab名称
function BattleSupportCharacter.GetModleID(self)
	return self._unitData:GetTemplate().prefab
end

--- 动画触发回调
function BattleSupportCharacter.OnAnimatorTrigger(self)
	self._unitData:CharacterActionTriggerCallback()
end

--- 动画结束回调
function BattleSupportCharacter.OnAnimatorEnd(self)
	self._unitData:CharacterActionEndCallback()
end

--- 动画开始回调
function BattleSupportCharacter.OnAnimatorStart(self)
	self._unitData:CharacterActionStartCallback()
end

--- 更新瞄准偏斜条：同时缩放迷雾特效
function BattleSupportCharacter.UpdateAimBiasBar(self)
	BattleSupportCharacter.super.UpdateAimBiasBar(self)

	if self._fogFx then
		local aimBiasRate = self:GetUnitData():GetAimBias():GetCurrentRate()

		self._fogFx.transform.localScale = Vector3(aimBiasRate, aimBiasRate, 1)
	end
end
