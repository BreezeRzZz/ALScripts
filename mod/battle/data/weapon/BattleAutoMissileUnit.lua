ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleTargetChoise = ys.Battle.BattleTargetChoise

local BattleAutoMissileUnit = class("BattleAutoMissileUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleAutoMissileUnit = BattleAutoMissileUnit
BattleAutoMissileUnit.__name = "BattleAutoMissileUnit"

--- @class BattleAutoMissileUnit : BattleWeaponUnit
--- @param self BattleAutoMissileUnit
--- 构造函数，直接调用父类Ctor
function BattleAutoMissileUnit.Ctor(self)
	BattleAutoMissileUnit.super.Ctor(self)
end

--- 创建主发射器（自动追踪导弹武器）
--- @param self BattleAutoMissileUnit
--- @param barrageID number 弹幕ID
--- @param index number 发射器序号
--- @param emitterType string 发射器类型（可选，默认EMITTER_NORMAL）
--- @return BattleBulletEmitter 创建的发射器
function BattleAutoMissileUnit.createMajorEmitter(self, barrageID, index, emitterType)
	--- 子弹生成回调：创建带追踪目标的导弹子弹
	--- @param offsetX number X轴偏移
	--- @param offsetZ number Z轴偏移
	--- @param angle number 发射角度
	--- @param offsetPriority number 偏移优先级
	--- @param target BattleUnit 追踪目标
	--- @return BattleBulletUnit 生成的子弹
	local function spawnFunc(offsetX, offsetZ, angle, offsetPriority, target)
		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, target, BattleAutoMissileUnit.INTERNAL)

		bullet:SetOffsetPriority(offsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)

		-- 如果瞄准类型为AIM且有目标，则设置旋转指向目标位置
		if self._tmpData.aim_type == BattleConst.WeaponAimType.AIM and target ~= nil then
			bullet:SetRotateInfo(target:GetBeenAimedPosition(), self:GetBaseAngle(), angle)
		else
			bullet:SetRotateInfo(nil, self:GetBaseAngle(), angle)
		end

		-- 设置追踪目标
		bullet:setTrackingTarget(target)

		-- 追踪特效数据（空表）
		local trackingFXData = {}

		bullet:SetTrackingFXData(trackingFXData)
		self:DispatchBulletEvent(bullet)

		return bullet
	end

	--- 所有发射器完成后的回调：如果所有发射器都已停止，则进入冷却
	local function allEmitterFinished()
		for _, emitter in ipairs(self._majorEmitterList) do
			if emitter:GetState() ~= emitter.STATE_STOP then
				return
			end
		end

		self:EnterCoolDown()
	end

	-- 默认发射器类型为NORMAL
	emitterType = emitterType or BattleAutoMissileUnit.EMITTER_NORMAL

	-- 根据emitterType字符串动态查找对应的发射器类并创建实例
	local emitter = ys.Battle[emitterType].New(spawnFunc, allEmitterFinished, barrageID)

	self._majorEmitterList[#self._majorEmitterList + 1] = emitter

	return emitter
end

--- 追踪目标：选择权重最高的目标
--- @param self BattleAutoMissileUnit
--- @return BattleUnit 权重最高的目标单位
function BattleAutoMissileUnit.Tracking(self)
	return BattleTargetChoise.TargetWeightiest(self, nil, self:GetFilteredList())[1]
end
