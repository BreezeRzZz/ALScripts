ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleManualAAMissileUnit = class("BattleManualAAMissileUnit", ys.Battle.BattleManualTorpedoUnit)

ys.Battle.BattleManualAAMissileUnit = BattleManualAAMissileUnit
BattleManualAAMissileUnit.__name = "BattleManualAAMissileUnit"

--- @class BattleManualAAMissileUnit : BattleManualTorpedoUnit
--- 手动防空导弹单元：继承自BattleManualTorpedoUnit，支持瞄准模式(StrikeMode)，可标记目标并追踪发射AA导弹
function BattleManualAAMissileUnit.Ctor(self)
	BattleManualAAMissileUnit.super.Ctor(self)

	self._strikeMode = nil
	self._strikeModeData = nil
end

--- @param barrageID number 弹幕ID
--- @param index number 发射器索引
--- @param emitterType string|nil 发射器类型
--- @return BattleBulletEmitter 创建的发射器
function BattleManualAAMissileUnit.createMajorEmitter(self, barrageID, index, emitterType)
	local function spawnFunc(offsetX, offsetZ, barrageAngle, offsetPriority, target)
		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, target, BattleManualAAMissileUnit.INTERNAL)

		bullet:SetOffsetPriority(offsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)

		if self._tmpData.aim_type == BattleConst.WeaponAimType.AIM and target ~= nil then
			bullet:SetRotateInfo(target:GetBeenAimedPosition(), self:GetBaseAngle(), barrageAngle)
		else
			bullet:SetRotateInfo(nil, self:GetBaseAngle(), barrageAngle)
		end

		bullet:setTrackingTarget(target)

		local strikeData = {}

		for k, v in pairs(self._strikeModeData) do
			strikeData[k] = v
		end

		bullet:SetTrackingFXData(strikeData)
		self:DispatchBulletEvent(bullet)

		return bullet
	end

	local function stopFunc()
		for _, emitter in ipairs(self._majorEmitterList) do
			if emitter:GetState() ~= emitter.STATE_STOP then
				return
			end
		end

		self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_FIRE, {}))

		self._strikeModeData = nil
	end

	emitterType = emitterType or BattleManualAAMissileUnit.EMITTER_NORMAL

	local emitter = ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID)

	self._majorEmitterList[#self._majorEmitterList + 1] = emitter

	return emitter
end

--- @return boolean 是否处于打击模式
function BattleManualAAMissileUnit.IsStrikeMode(self)
	return self._strikeMode
end

--- @return boolean 是否正在攻击中
function BattleManualAAMissileUnit.IsAttacking(self)
	return self._currentState == BattleManualAAMissileUnit.STATE_ATTACK
end

--- 刷新装填，打击模式下标记目标
function BattleManualAAMissileUnit.Update(self)
	self:UpdateReload()

	if self:IsStrikeMode() then
		self:MarkTarget()
	end
end

--- 进入打击模式
function BattleManualAAMissileUnit.EnterStrikeMode(self)
	self._strikeMode = true
	self._strikeModeData = {}
	self._strikeModeData.fxName = self._preCastInfo.fx

	self:MarkTarget()
end

--- 标记目标：追踪权重最高的敌人，在角色身上添加瞄准特效
function BattleManualAAMissileUnit.MarkTarget(self)
	local oldTarget = self._strikeModeData.aimingTarget

	self:updateMovementInfo()

	local newTarget = self:Tracking()

	if oldTarget == newTarget then
		return
	end

	local sceneMediator = ys.Battle.BattleState.GetInstance():GetSceneMediator()

	if self._strikeModeData.aimingTarget and self._strikeModeData.aimingFX then
		local oldCharacter = sceneMediator:GetCharacter(oldTarget:GetUniqueID())

		if oldCharacter then
			oldCharacter:RemoveFX(self._strikeModeData.aimingFX)
		end
	end

	table.clear(self._strikeModeData)

	if not newTarget then
		return
	end

	local newCharacter = sceneMediator:GetCharacter(newTarget:GetUniqueID())
	local aimingFX

	if self._preCastInfo.fx and #self._preCastInfo.fx > 0 then
		aimingFX = newCharacter:AddFX(self._preCastInfo.fx)
	end

	self._strikeModeData.aimingTarget = newTarget
	self._strikeModeData.aimingFX = aimingFX
end

--- 取消打击模式
function BattleManualAAMissileUnit.CancelStrikeMode(self)
	if self._strikeModeData.aimingTarget and self._strikeModeData.aimingFX then
		local character = ys.Battle.BattleState.GetInstance():GetSceneMediator():GetCharacter(self._strikeModeData.aimingTarget:GetUniqueID())

		if character then
			character:RemoveFX(self._strikeModeData.aimingFX)
		end
	end

	self._strikeMode = nil
	self._strikeModeData = nil
end

--- @return BattleUnit|nil 权重最高的目标
function BattleManualAAMissileUnit.Tracking(self)
	return BattleTargetChoise.TargetWeightiest(self, nil, self:GetFilteredList())[1]
end

--- @return boolean
--- 开火：退出打击模式，向瞄准目标发射
function BattleManualAAMissileUnit.Fire(self)
	self._strikeMode = nil

	ys.Battle.BattleWeaponUnit.Fire(self, self._strikeModeData.aimingTarget)

	return true
end

--- @param target BattleUnit|nil 攻击目标
--- 目标无效时清除瞄准数据
function BattleManualAAMissileUnit.DoAttack(self, target, ...)
	if target == nil or not target:IsAlive() or self:outOfFireRange(target) then
		target = nil

		if self._strikeModeData.aimingTarget and self._strikeModeData.aimingFX then
			local character = ys.Battle.BattleState.GetInstance():GetSceneMediator():GetCharacter(self._strikeModeData.aimingTarget:GetUniqueID())

			if character then
				character:RemoveFX(self._strikeModeData.aimingFX)
			end
		end

		self._strikeModeData.aimingTarget = nil
		self._strikeModeData.aimingFX = nil
	end

	ys.Battle.BattleWeaponUnit.DoAttack(self, target, ...)
end

--- 准备：进入预施法状态并开启打击模式
function BattleManualAAMissileUnit.Prepar(self)
	self._currentState = self.STATE_PRECAST

	self:EnterStrikeMode()
end

--- 取消：回到READY状态
function BattleManualAAMissileUnit.Cancel(self)
	self._currentState = self.STATE_READY

	self:CancelStrikeMode()
end
