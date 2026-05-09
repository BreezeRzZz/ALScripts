ys = ys or {}

--- @class OxyState : 潜艇氧气状态机
--- 管理潜艇的下潜、上浮、突袭、撤退等状态
local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleConst = ys.Battle.BattleConst

ys.Battle.OxyState = class("OxyState")
ys.Battle.OxyState.__name = "OxyState"

local OxyState = ys.Battle.OxyState

OxyState.STATE_IDLE = "STATE_IDLE"
OxyState.STATE_DIVE = "STATE_DIVE"
OxyState.STATE_FLOAT = "STATE_FLOAT"
OxyState.STATE_RAID = "STATE_RAID"
OxyState.STATE_RETREAT = "STATE_RETREAT"
OxyState.STATE_FREE_DIVE = "STATE_FREE_DIVE"
OxyState.STATE_FREE_FLOAT = "STATE_FREE_FLOAT"
OxyState.STATE_FREE_BENCH = "STATE_FREE_BENCH"
OxyState.STATE_DEEP_MINE = "STATE_DEEP_MINE"

--- 构造函数：创建所有子状态，添加初始氧气Buff，初始化为Idle
--- @param target BattleUnit: 状态机所属的单位
function OxyState.Ctor(self, target)
	self._target = target
	self._idleState = ys.Battle.IdleOxyState.New()
	self._diveState = ys.Battle.DiveOxyState.New()
	self._floatState = ys.Battle.FloatOxyState.New()
	self._raidState = ys.Battle.RaidOxyState.New()
	self._retreatState = ys.Battle.RetreatOxyState.New()
	self._freeDiveState = ys.Battle.FreeDiveOxyState.New()
	self._freeFloatState = ys.Battle.FreeFloatOxyState.New()
	self._freeBenchState = ys.Battle.FreeBenchOxyState.New()
	self._deepMineState = ys.Battle.DeepMineOxyState.New()

	local initBuff = ys.Battle.BattleBuffUnit.New(8520)

	self._target:AddBuff(initBuff)
	-- 初始状态为Idle
	self:OnIdleState()
end

--- 设置回收标记
--- @param recycle any: 回收标记
function OxyState.SetRecycle(self, recycle)
	self._recycle = recycle
end

--- 设置气泡模板和间隔
--- @param bubbleInitial number: 气泡初始X坐标
--- @param bubbleInterval number: 气泡间隔
function OxyState.SetBubbleTemplate(self, bubbleInitial, bubbleInterval)
	self._bubbleInitial = bubbleInitial or 0
	self._bubbleInterval = bubbleInterval or 0
	self._bubbleTimpStamp = nil
end

--- 更新氧气（委托给当前状态）
function OxyState.UpdateOxygen(self)
	self._currentState:DoUpdateOxy(self)
end

--- 获取下一个气泡时间戳
--- @return number|nil: 气泡时间戳
function OxyState.GetNextBubbleStamp(self)
	if self._currentState:GetBubbleFlag() then
		if self._target:GetPosition().x < self._bubbleInitial and self._bubbleTimpStamp == nil then
			self._bubbleTimpStamp = 0
		end

		return self._bubbleTimpStamp
	else
		return nil
	end
end

--- 设置强制暴露
--- @param isForceExpose boolean: 是否强制暴露
function OxyState.SetForceExpose(self, isForceExpose)
	self._forceExpose = isForceExpose

	self._target:SetForceVisible()
end

--- 获取强制暴露状态
--- @return boolean: 是否强制暴露
function OxyState.GetForceExpose(self)
	return self._forceExpose
end

--- 刷新气泡时间戳
--- @param currentTime number: 当前时间
function OxyState.FlashBubbleStamp(self, currentTime)
	self._bubbleTimpStamp = currentTime + self._bubbleInterval
end

--- 潜艇状态切换
--- @param newState string: 新状态
--- @param _ any: 未使用参数
function OxyState.ChangeState(self, newState, _)
	if newState == OxyState.STATE_IDLE then
		self:OnIdleState()
	elseif newState == OxyState.STATE_DIVE then
		self:OnDiveState()
	elseif newState == OxyState.STATE_FLOAT then
		self:OnFloatState()
	elseif newState == OxyState.STATE_RAID then
		self:OnRaidState()
	elseif newState == OxyState.STATE_RETREAT then
		self:OnRetreatState()
	elseif newState == OxyState.STATE_FREE_DIVE then
		self:OnFreeDiveState()
	elseif newState == OxyState.STATE_FREE_FLOAT then
		self:OnFreeFloatState()
	elseif newState == OxyState.STATE_FREE_BENCH then
		self:OnFreeBenchState()
	elseif newState == OxyState.STATE_DEEP_MINE then
		self:OnDeepMineState()
	else
		assert(false, self._target.__name .. "'s oxygen state machine, unexcepted state: " .. newState)
	end

	self._target:GetCldData().Surface = self._currentState:GetDiveState()
end

--- 氧气消耗
function OxyState.OxyConsume(self)
	self._target:OxyConsume()
end

--- 氧气恢复
--- @param recoverAmount number: 恢复量
function OxyState.OxyRecover(self, recoverAmount)
	self._target:OxyRecover(recoverAmount)
end

--- 进入待机状态
function OxyState.OnIdleState(self)
	self._currentState = self._idleState
end

--- 进入潜水状态：切换碰撞数据，设置AI，触发Buff
function OxyState.OnDiveState(self)
	local wasDiving = self._currentState:UpdateDive()
	local originalState = self._currentState

	self._currentState = self._diveState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()
	self._target:SetCrash(false)
	self._target:SetAI(BattleConfig.SUB_DEFAULT_ENGAGE_AI)

	if wasDiving then
		self._target:SetDiveInvisible(true)
	end

	self._target:StateChange(ys.Battle.UnitState.STATE_DIVE)
	self._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_DIVE, {})
	self._target:RemoveBuff(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF)
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF))
end

--- 进入上浮状态：取消隐身，播放特效，触发Buff
function OxyState.OnFloatState(self)
	local originalState = self._currentState

	self._currentState = self._floatState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()
	self._target:SetDiveInvisible(false)
	self._target:StateChange(ys.Battle.UnitState.STATE_MOVE)
	self._target:RemoveSonarExpose()
	self._target:PlayFX("qianting_chushui", false)
	self._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FLOAT, {})
	self._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

-- 潜艇攻击阶段
-- 一般来讲，是从Idle切换而来
--- @param self OxyState
function OxyState.OnRaidState(self)
	local wasDiving = self._currentState:UpdateDive()
	local originalState = self._currentState

	self._currentState = self._raidState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()

	if wasDiving then
		self._target:SetDiveInvisible(true)
	end

	-- AI 10006
	self._target:SetAI(BattleConfig.SUB_DEFAULT_STAY_AI)
	self._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_RAID, {})
	-- Buff 315
	self._target:RemoveBuff(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF)
	-- Buff 314
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF))
end

--- 进入撤退状态
--- @param self OxyState
function OxyState.OnRetreatState(self)
	local originalState = self._currentState

	self._currentState = self._retreatState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()
	self._target:SetDiveInvisible(false)
	self._target:SetAI(BattleConfig.SUB_DEFAULT_RETREAT_AI)
	self._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_RETREAT, {})
	self._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

--- 进入自由潜水状态（无消耗下潜）
function OxyState.OnFreeDiveState(self)
	local originalState = self._currentState

	self._currentState = self._freeDiveState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()
	self._target:SetCrash(false)
	self._target:SetDiveInvisible(true)
	self._target:StateChange(ys.Battle.UnitState.STATE_DIVE)
	self._target:PlayFX("qianting_rushui", false)
	self._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_DIVE, {})
	self._target:RemoveBuff(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF)
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF))
end

--- 进入自由上浮状态
function OxyState.OnFreeFloatState(self)
	local originalState = self._currentState

	self._currentState = self._freeFloatState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()
	self._target:SetDiveInvisible(false)
	self._target:StateChange(ys.Battle.UnitState.STATE_MOVE)
	self._target:PlayFX("qianting_chushui", false)
	self._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FLOAT, {})
	self._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

--- 进入自由停驻状态
function OxyState.OnFreeBenchState(self)
	local originalState = self._currentState

	self._currentState = self._freeBenchState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()
	self._target:SetDiveInvisible(false)
	self._target:StateChange(ys.Battle.UnitState.STATE_MOVE)
	self._target:PlayFX("qianting_chushui", false)
	self._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	self._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

--- 进入深潜采矿状态
function OxyState.OnDeepMineState(self)
	local originalState = self._currentState

	self._currentState = self._deepMineState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:SetDiveInvisible(false)
	self._target:ChangeWeaponDiveState()
	self._target:SetAI(20005)
end

--- 获取回收标记
--- @return boolean: 回收标记
function OxyState.GetRecycle(self)
	return false
end

--- 获取目标单位
--- @return BattleUnit: 目标单位
function OxyState.GetTarget(self)
	return self._target
end

--- 获取当前子状态
--- @return table: 当前状态实例
function OxyState.GetCurrentState(self)
	return self._currentState
end

--- 获取当前状态名
--- @return string: 状态名
function OxyState.GetCurrentStateName(self)
	return self._currentState.__name
end

--- 获取可用武器类型列表
--- @return table: 武器类型列表
function OxyState.GetWeaponType(self)
	return self._currentState:GetWeaponUseableList()
end

--- 获取进度条可见性
--- @return boolean: 是否可见
function OxyState.GetBarVisible(self)
	return self._currentState:GetBarVisible()
end

--- 获取运行模式
--- @return any: 运行模式
function OxyState.GetRundMode(self)
	return self._currentState:RunMode()
end

--- 获取当前潜水状态
--- @return number: 潜水状态码
function OxyState.GetCurrentDiveState(self)
	return self._currentState:GetDiveState()
end
