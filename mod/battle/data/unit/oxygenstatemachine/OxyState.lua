ys = ys or {}
-- TODO
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

function OxyState.Ctor(arg_1_0, arg_1_1)
	arg_1_0._target = arg_1_1
	arg_1_0._idleState = ys.Battle.IdleOxyState.New()
	arg_1_0._diveState = ys.Battle.DiveOxyState.New()
	arg_1_0._floatState = ys.Battle.FloatOxyState.New()
	arg_1_0._raidState = ys.Battle.RaidOxyState.New()
	arg_1_0._retreatState = ys.Battle.RetreatOxyState.New()
	arg_1_0._freeDiveState = ys.Battle.FreeDiveOxyState.New()
	arg_1_0._freeFloatState = ys.Battle.FreeFloatOxyState.New()
	arg_1_0._freeBenchState = ys.Battle.FreeBenchOxyState.New()
	arg_1_0._deepMineState = ys.Battle.DeepMineOxyState.New()

	local var_1_0 = ys.Battle.BattleBuffUnit.New(8520)

	arg_1_0._target:AddBuff(var_1_0)
	-- 初始状态为Idle
	arg_1_0:OnIdleState()
end

function OxyState.SetRecycle(arg_2_0, arg_2_1)
	arg_2_0._recycle = arg_2_1
end

function OxyState.SetBubbleTemplate(arg_3_0, arg_3_1, arg_3_2)
	arg_3_0._bubbleInitial = arg_3_1 or 0
	arg_3_0._bubbleInterval = arg_3_2 or 0
	arg_3_0._bubbleTimpStamp = nil
end

function OxyState.UpdateOxygen(arg_4_0)
	arg_4_0._currentState:DoUpdateOxy(arg_4_0)
end

function OxyState.GetNextBubbleStamp(arg_5_0)
	if arg_5_0._currentState:GetBubbleFlag() then
		if arg_5_0._target:GetPosition().x < arg_5_0._bubbleInitial and arg_5_0._bubbleTimpStamp == nil then
			arg_5_0._bubbleTimpStamp = 0
		end

		return arg_5_0._bubbleTimpStamp
	else
		return nil
	end
end

function OxyState.SetForceExpose(arg_6_0, arg_6_1)
	arg_6_0._forceExpose = arg_6_1

	arg_6_0._target:SetForceVisible()
end

function OxyState.GetForceExpose(arg_7_0)
	return arg_7_0._forceExpose
end

function OxyState.FlashBubbleStamp(arg_8_0, arg_8_1)
	arg_8_0._bubbleTimpStamp = arg_8_1 + arg_8_0._bubbleInterval
end

-- TODO
-- 潜艇状态切换
function OxyState.ChangeState(self, newState, arg_9_2)
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

function OxyState.OxyConsume(arg_10_0)
	arg_10_0._target:OxyConsume()
end

function OxyState.OxyRecover(arg_11_0, arg_11_1)
	arg_11_0._target:OxyRecover(arg_11_1)
end

function OxyState.OnIdleState(arg_12_0)
	arg_12_0._currentState = arg_12_0._idleState
end

function OxyState.OnDiveState(arg_13_0)
	local var_13_0 = arg_13_0._currentState:UpdateDive()
	local var_13_1 = arg_13_0._currentState

	arg_13_0._currentState = arg_13_0._diveState

	arg_13_0._currentState:UpdateCldData(arg_13_0._target, var_13_1)
	arg_13_0._target:ChangeWeaponDiveState()
	arg_13_0._target:SetCrash(false)
	arg_13_0._target:SetAI(BattleConfig.SUB_DEFAULT_ENGAGE_AI)

	if var_13_0 then
		arg_13_0._target:SetDiveInvisible(true)
	end

	arg_13_0._target:StateChange(ys.Battle.UnitState.STATE_DIVE)
	arg_13_0._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_DIVE, {})
	arg_13_0._target:RemoveBuff(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF)
	arg_13_0._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF))
end

function OxyState.OnFloatState(arg_14_0)
	local var_14_0 = arg_14_0._currentState

	arg_14_0._currentState = arg_14_0._floatState

	arg_14_0._currentState:UpdateCldData(arg_14_0._target, var_14_0)
	arg_14_0._target:ChangeWeaponDiveState()
	arg_14_0._target:SetDiveInvisible(false)
	arg_14_0._target:StateChange(ys.Battle.UnitState.STATE_MOVE)
	arg_14_0._target:RemoveSonarExpose()
	arg_14_0._target:PlayFX("qianting_chushui", false)
	arg_14_0._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FLOAT, {})
	arg_14_0._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	arg_14_0._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

-- 潜艇攻击阶段
-- 一般来讲，是从Idle切换而来
function OxyState.OnRaidState(self)
	local var_15_0 = self._currentState:UpdateDive()
	local originalState = self._currentState

	self._currentState = self._raidState

	self._currentState:UpdateCldData(self._target, originalState)
	self._target:ChangeWeaponDiveState()

	if var_15_0 then
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
-- TODO
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

function OxyState.OnFreeDiveState(arg_17_0)
	local var_17_0 = arg_17_0._currentState

	arg_17_0._currentState = arg_17_0._freeDiveState

	arg_17_0._currentState:UpdateCldData(arg_17_0._target, var_17_0)
	arg_17_0._target:ChangeWeaponDiveState()
	arg_17_0._target:SetCrash(false)
	arg_17_0._target:SetDiveInvisible(true)
	arg_17_0._target:StateChange(ys.Battle.UnitState.STATE_DIVE)
	arg_17_0._target:PlayFX("qianting_rushui", false)
	arg_17_0._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_DIVE, {})
	arg_17_0._target:RemoveBuff(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF)
	arg_17_0._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF))
end

function OxyState.OnFreeFloatState(arg_18_0)
	local var_18_0 = arg_18_0._currentState

	arg_18_0._currentState = arg_18_0._freeFloatState

	arg_18_0._currentState:UpdateCldData(arg_18_0._target, var_18_0)
	arg_18_0._target:ChangeWeaponDiveState()
	arg_18_0._target:SetDiveInvisible(false)
	arg_18_0._target:StateChange(ys.Battle.UnitState.STATE_MOVE)
	arg_18_0._target:PlayFX("qianting_chushui", false)
	arg_18_0._target:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FLOAT, {})
	arg_18_0._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	arg_18_0._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

function OxyState.OnFreeBenchState(arg_19_0)
	local var_19_0 = arg_19_0._currentState

	arg_19_0._currentState = arg_19_0._freeBenchState

	arg_19_0._currentState:UpdateCldData(arg_19_0._target, var_19_0)
	arg_19_0._target:ChangeWeaponDiveState()
	arg_19_0._target:SetDiveInvisible(false)
	arg_19_0._target:StateChange(ys.Battle.UnitState.STATE_MOVE)
	arg_19_0._target:PlayFX("qianting_chushui", false)
	arg_19_0._target:RemoveBuff(BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF)
	arg_19_0._target:AddBuff(ys.Battle.BattleBuffUnit.New(BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF))
end

function OxyState.OnDeepMineState(arg_20_0)
	local var_20_0 = arg_20_0._currentState

	arg_20_0._currentState = arg_20_0._deepMineState

	arg_20_0._currentState:UpdateCldData(arg_20_0._target, var_20_0)
	arg_20_0._target:SetDiveInvisible(false)
	arg_20_0._target:ChangeWeaponDiveState()
	arg_20_0._target:SetAI(20005)
end

function OxyState.GetRecycle(arg_21_0)
	return false
end

function OxyState.GetTarget(arg_22_0)
	return arg_22_0._target
end

function OxyState.GetCurrentState(arg_23_0)
	return arg_23_0._currentState
end

function OxyState.GetCurrentStateName(arg_24_0)
	return arg_24_0._currentState.__name
end

function OxyState.GetWeaponType(arg_25_0)
	return arg_25_0._currentState:GetWeaponUseableList()
end

function OxyState.GetBarVisible(arg_26_0)
	return arg_26_0._currentState:GetBarVisible()
end

function OxyState.GetRundMode(arg_27_0)
	return arg_27_0._currentState:RunMode()
end

function OxyState.GetCurrentDiveState(arg_28_0)
	return arg_28_0._currentState:GetDiveState()
end
