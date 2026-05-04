ys = ys or {}

local ys = ys

ys.Battle.BattleAimbiasBar = class("BattleAimbiasBar")
ys.Battle.BattleAimbiasBar.__name = "BattleAimbiasBar"

local BattleAimbiasBar = ys.Battle.BattleAimbiasBar

--- 瞄准偏差警告阈值：当偏差率低于此值时触发警告
BattleAimbiasBar.WARNING_VALUE = 0.1

--- @class BattleAimbiasBar
--- 瞄准偏差条（精确度/偏差指示器）
--- 显示玩家舰队的瞄准偏差状态，包含：
--- - progress：当前偏差进度条
--- - warning：低偏差警告图标
--- - lock：技能锁定状态图标
--- - recovery：正在恢复指示
--- @param aimBiasBar Transform 偏差条Transform
function BattleAimbiasBar.Ctor(self, aimBiasBar)
	self._aimBiasBar = aimBiasBar
	self._aimBiasBarGO = self._aimBiasBar.gameObject
	self._progress = self._aimBiasBar:Find("bias"):GetComponent(typeof(Image))
	self._warning = self._aimBiasBar:Find("warning")
	self._lock = self._aimBiasBar:Find("lock")
	self._recovery = self._aimBiasBar:Find("recovery")

	-- 初始状态：显示进度条和恢复，隐藏警告和锁定
	setActive(self._lock, false)
	setActive(self._warning, false)
	setActive(self._progress, true)
	setActive(self._aimBiasBar, true)
	setActive(self._recovery, true)

	self._cacheSpeed = 0
	self._cacheWarningFlag = 0
	self._lockBlock = false
end

--- 激活/隐藏偏差条
--- @param isActive boolean
function BattleAimbiasBar.SetActive(self, isActive)
	setActive(self._aimBiasBar, isActive)
end

--- 绑定瞄准偏差组件
--- @param aimBiasComponent BattleUnitAimBiasComponent
function BattleAimbiasBar.ConfigAimBias(self, aimBiasComponent)
	self._aimBiasComponent = aimBiasComponent
	self._hostile = aimBiasComponent:IsHostile()
end

--- 更新锁定状态视图
--- 检查技能暴露锁定状态，控制lock/recovery/warning的显隐
function BattleAimbiasBar.UpdateLockStateView(self)
	local isSkillExposeLocked = self._aimBiasComponent:GetCurrentState() == self._aimBiasComponent.STATE_SKILL_EXPOSE

	setActive(self._lock, isSkillExposeLocked)

	if isSkillExposeLocked then
		-- 技能暴露锁定中：隐藏恢复和警告
		setActive(self._recovery, false)
		setActive(self._warning, false)
	elseif self._aimBiasComponent:GetDecayRatioSpeed() < 0 then
		-- 偏差正在衰减（恢复中）
		setActive(self._recovery, true)
	elseif not self._hostile then
		-- 非敌方：检查低偏差警告
		local currentRate = self._aimBiasComponent:GetCurrentRate()

		if currentRate < BattleAimbiasBar.WARNING_VALUE and currentRate > 0 then
			setActive(self._warning, true)
		end
	end

	self._lockBlock = isSkillExposeLocked
end

--- 每帧更新偏差进度条和恢复/警告状态
--- 包含方向变化检测逻辑：
--- - 当衰减速度正负切换时，对应切换recovery显隐
--- - 当偏差值穿越WARNING_VALUE时，对应切换warning显隐
function BattleAimbiasBar.UpdateAimBiasProgress(self)
	local currentRate = self._aimBiasComponent:GetCurrentRate()

	self._progress.fillAmount = currentRate

	local decaySpeed = self._aimBiasComponent:GetDecayRatioSpeed()
	local warningDelta = currentRate - BattleAimbiasBar.WARNING_VALUE

	if not self._lockBlock then
		local isRecovering = decaySpeed < 0

		-- 速度方向切换时更新recovery状态
		if decaySpeed * self._cacheSpeed <= 0 then
			setActive(self._recovery, isRecovering)
		end

		if not self._hostile then
			if currentRate <= 0 then
				setActive(self._warning, false)
			elseif not isRecovering and warningDelta * self._cacheWarningFlag < 0 then
				-- 偏差值穿越WARNING_VALUE阈值时更新
				setActive(self._warning, currentRate < BattleAimbiasBar.WARNING_VALUE)
			end
		end
	end

	-- 敌方单位偏差归零时自动隐藏整个条
	if self._hostile and currentRate <= 0 then
		setActive(self._aimBiasBar, false)
	end

	-- 缓存当前速度和差值用于下次方向检测
	self._cacheSpeed = decaySpeed
	self._cacheWarningFlag = warningDelta
end

--- 更新瞄准偏差配置（预留，当前为空实现）
function BattleAimbiasBar.UpdateAimBiasConfig(self)
	return
end

--- 销毁偏差条
function BattleAimbiasBar.Dispose(self)
	self._aimBiasBar = nil
	self._progress = nil
	self._warning = nil
	self._lock = nil
	self._aimBiasBarGO = nil
end

--- 获取偏差条GameObject
--- @return GameObject
function BattleAimbiasBar.GetGO(self)
	return self._aimBiasBarGO
end
