ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local ActionName = BattleConst.ActionName
-- TODO
ys.Battle.UnitState = class("UnitState")
ys.Battle.UnitState.__name = "UnitState"
ys.Battle.UnitState.STATE_IDLE = "STATE_IDLE"
ys.Battle.UnitState.STATE_MOVE = "STATE_MOVE"
ys.Battle.UnitState.STATE_ATTACK = "STATE_ATTACK"
ys.Battle.UnitState.STATE_ATTACKLEFT = "STATE_ATTACKLEFT"
ys.Battle.UnitState.STATE_DEAD = "STATE_DEAD"
ys.Battle.UnitState.STATE_MOVELEFT = "STATE_MOVELEFT"
ys.Battle.UnitState.STATE_SKILL = "STATE_SKILL"
ys.Battle.UnitState.STATE_VICTORY = "STATE_VICTORY"
ys.Battle.UnitState.STATE_STAND = "STATE_STAND"
ys.Battle.UnitState.STATE_INTERRUPT = "STATE_INTERRUPT"
ys.Battle.UnitState.STATE_SKILL_START = "STATE_SKILL_START"
ys.Battle.UnitState.STATE_SKILL_END = "STATE_SKILL_END"
ys.Battle.UnitState.STATE_DIVING = "STATE_DIVING"
ys.Battle.UnitState.STATE_DIVE = "STATE_DIVE"
ys.Battle.UnitState.STATE_DIVELEFT = "STATE_DIVELEFT"
ys.Battle.UnitState.STATE_RAID = "STATE_RAID"
ys.Battle.UnitState.STATE_RAIDLEFT = "STATE_RAIDLEFT"

function ys.Battle.UnitState.Ctor(arg_1_0, arg_1_1)
	arg_1_0._target = arg_1_1
	arg_1_0._idleState = ys.Battle.IdleState.New()
	arg_1_0._moveState = ys.Battle.MoveState.New()
	arg_1_0._attackState = ys.Battle.AttackState.New()
	arg_1_0._attackLeftState = ys.Battle.AttackLeftState.New()
	arg_1_0._deadState = ys.Battle.DeadState.New()
	arg_1_0._moveLeftState = ys.Battle.MoveLeftState.New()
	arg_1_0._victoryState = ys.Battle.VictoryState.New()
	arg_1_0._victorySwimState = ys.Battle.VictorySwimState.New()
	arg_1_0._standState = ys.Battle.StandState.New()
	arg_1_0._spellState = ys.Battle.SpellState.New()
	arg_1_0._interruptState = ys.Battle.InterruptState.New()
	arg_1_0._skillStartState = ys.Battle.SkillStartState.New()
	arg_1_0._skillEndState = ys.Battle.SkillEndState.New()
	arg_1_0._diveState = ys.Battle.DiveState.New()
	arg_1_0._diveLeftState = ys.Battle.DiveLeftState.New()
	arg_1_0._raidState = ys.Battle.RaidState.New()
	arg_1_0._raidLeftState = ys.Battle.RaidLeftState.New()

	arg_1_0:OnIdleState()
end

function ys.Battle.UnitState.FreshActionKeyOffset(arg_2_0)
	local var_2_0 = arg_2_0:ActionKeyOffset()

	if var_2_0 then
		if string.find(arg_2_0._currentAction, var_2_0) == nil then
			arg_2_0:SendAction(arg_2_0._currentAction .. var_2_0)
		end
	elseif arg_2_0._offset ~= nil then
		local var_2_1 = string.find(arg_2_0._currentAction, arg_2_0._offset)

		arg_2_0:SendAction(string.sub(arg_2_0._currentAction, 1, var_2_1 - 1))
	end

	arg_2_0._offset = var_2_0
end

function ys.Battle.UnitState.ChangeState(arg_3_0, arg_3_1, arg_3_2)
	if arg_3_1 == arg_3_0.STATE_IDLE then
		arg_3_0._currentState:AddIdleState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_MOVE then
		arg_3_0._currentState:AddMoveState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_MOVE then
		arg_3_0._currentState:AddMoveState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_ATTACK then
		arg_3_0._currentState:AddAttackState(arg_3_0, arg_3_2)
	elseif arg_3_1 == arg_3_0.STATE_DEAD then
		arg_3_0._currentState:AddDeadState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_MOVELEFT then
		arg_3_0._currentState:AddMoveLeftState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_VICTORY then
		local var_3_0 = arg_3_0:GetTarget():GetOxyState()

		if var_3_0 and var_3_0:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
			arg_3_0._currentState:AddVictorySwimState(arg_3_0)
		else
			arg_3_0._currentState:AddVictoryState(arg_3_0)
		end
	elseif arg_3_1 == arg_3_0.STATE_INTERRUPT then
		arg_3_0._currentState:AddInterruptState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_STAND then
		arg_3_0._currentState:AddStandState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_DIVE then
		arg_3_0._currentState:AddDiveState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_DIVELEFT then
		arg_3_0._currentState:AddDiveLeftState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_SKILL_START then
		arg_3_0._currentState:AddSkillStartState(arg_3_0)
	elseif arg_3_1 == arg_3_0.STATE_SKILL_END then
		arg_3_0._currentState:AddSkillEndState(arg_3_0)
	else
		assert(false, arg_3_0._target.__name .. "'s state machine, unexcepted state: " .. arg_3_1)
	end
end

function ys.Battle.UnitState.OnMoveState(arg_4_0)
	arg_4_0._currentState = arg_4_0._moveState

	local var_4_0 = arg_4_0._currentState:GetActionName(arg_4_0)

	arg_4_0:SendAction(var_4_0)
end

function ys.Battle.UnitState.OnMoveLeftState(arg_5_0)
	arg_5_0._currentState = arg_5_0._moveLeftState

	local var_5_0 = arg_5_0._currentState:GetActionName(arg_5_0)

	arg_5_0:SendAction(var_5_0)
end

function ys.Battle.UnitState.OnIdleState(arg_6_0)
	arg_6_0._currentState = arg_6_0._idleState

	local var_6_0 = arg_6_0._currentState:GetActionName(arg_6_0)

	arg_6_0:SendAction(var_6_0)
end

function ys.Battle.UnitState.OnAttackState(arg_7_0, arg_7_1)
	arg_7_0._currentState = arg_7_0._attackState

	local var_7_0 = arg_7_0._currentState:GetActionName(arg_7_0, arg_7_1)

	arg_7_0:SendAction(var_7_0)
end

function ys.Battle.UnitState.OnAttackLeftState(arg_8_0, arg_8_1)
	arg_8_0._currentState = arg_8_0._attackLeftState

	local var_8_0 = arg_8_0._currentState:GetActionName(arg_8_0, arg_8_1)

	arg_8_0:SendAction(var_8_0)
end

function ys.Battle.UnitState.OnDiveState(arg_9_0)
	arg_9_0._currentState = arg_9_0._diveState

	local var_9_0 = arg_9_0._currentState:GetActionName(arg_9_0)

	arg_9_0:SendAction(var_9_0)
end

function ys.Battle.UnitState.OnDiveLeftState(arg_10_0)
	arg_10_0._currentState = arg_10_0._diveLeftState

	local var_10_0 = arg_10_0._currentState:GetActionName(arg_10_0)

	arg_10_0:SendAction(var_10_0)
end

function ys.Battle.UnitState.OnRaidState(arg_11_0, arg_11_1)
	arg_11_0._currentState = arg_11_0._raidState

	local var_11_0 = arg_11_0._currentState:GetActionName(arg_11_0)

	arg_11_0:SendAction(var_11_0)
end

function ys.Battle.UnitState.OnRaidLeftState(arg_12_0, arg_12_1)
	arg_12_0._currentState = arg_12_0._raidLeftState

	local var_12_0 = arg_12_0._currentState:GetActionName(arg_12_0)

	arg_12_0:SendAction(var_12_0)
end

function ys.Battle.UnitState.OnDeadState(arg_13_0)
	arg_13_0._currentState = arg_13_0._deadState

	local var_13_0 = arg_13_0._currentState:GetActionName(arg_13_0)

	arg_13_0:SendAction(var_13_0)
end

function ys.Battle.UnitState.OnVictoryState(arg_14_0)
	arg_14_0._currentState = arg_14_0._victoryState

	local var_14_0 = arg_14_0._currentState:GetActionName(arg_14_0)

	arg_14_0:SendAction(var_14_0)
end

function ys.Battle.UnitState.OnVictorySwimState(arg_15_0)
	arg_15_0._currentState = arg_15_0._victorySwimState

	local var_15_0 = arg_15_0._currentState:GetActionName(arg_15_0)

	arg_15_0:SendAction(var_15_0)
end

function ys.Battle.UnitState.OnStandState(arg_16_0)
	arg_16_0._currentState = arg_16_0._standState

	local var_16_0 = arg_16_0._currentState:GetActionName(arg_16_0)

	arg_16_0:SendAction(var_16_0)
end

function ys.Battle.UnitState.OnInterruptState(arg_17_0)
	arg_17_0._currentState = arg_17_0._interruptState

	local var_17_0 = arg_17_0._currentState:GetActionName(arg_17_0)

	arg_17_0:SendAction(var_17_0)
end

function ys.Battle.UnitState.OnSkillStartState(arg_18_0)
	arg_18_0._currentState = arg_18_0._skillStartState

	local var_18_0 = arg_18_0._currentState:GetActionName(arg_18_0)

	arg_18_0:SendAction(var_18_0)
end

function ys.Battle.UnitState.OnSkillEndState(arg_19_0)
	arg_19_0._currentState = arg_19_0._skillEndState

	local var_19_0 = arg_19_0._currentState:GetActionName(arg_19_0)

	arg_19_0:SendAction(var_19_0)
end

function ys.Battle.UnitState.ChangeToMoveState(arg_20_0)
	local var_20_0 = arg_20_0:GetTarget():GetSpeed().x
	local var_20_1 = arg_20_0:GetTarget():GetOxyState()

	if var_20_1 and var_20_1:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
		if var_20_0 >= 0 then
			arg_20_0:OnDiveState()
		else
			arg_20_0:OnDiveLeftState()
		end
	elseif var_20_0 >= 0 then
		arg_20_0:OnMoveState()
	else
		arg_20_0:OnMoveLeftState()
	end
end

function ys.Battle.UnitState.SendAction(arg_21_0, arg_21_1)
	arg_21_0._currentAction = arg_21_1

	local var_21_0 = ys.Event.New(ys.Battle.BattleUnitEvent.CHANGE_ACTION, {
		actionType = arg_21_1
	})

	arg_21_0._target:DispatchEvent(var_21_0)
end

function ys.Battle.UnitState.ChangeOxyState(arg_22_0, arg_22_1)
	arg_22_0._target:ChangeOxygenState(arg_22_1)
end

function ys.Battle.UnitState.GetTarget(arg_23_0)
	return arg_23_0._target
end

function ys.Battle.UnitState.ActionKeyOffset(arg_24_0)
	return arg_24_0._target:GetActionKeyOffset()
end

function ys.Battle.UnitState.GetCurrentStateName(arg_25_0)
	return arg_25_0._currentState.__name
end

function ys.Battle.UnitState.NeedWeaponCache(arg_26_0)
	return arg_26_0._currentState:CacheWeapon()
end

function ys.Battle.UnitState.OnActionStart(arg_27_0)
	arg_27_0._currentState:OnStart(arg_27_0)
end

function ys.Battle.UnitState.OnActionTrigger(arg_28_0)
	arg_28_0._currentState:OnTrigger(arg_28_0)
end

function ys.Battle.UnitState.OnActionEnd(arg_29_0)
	arg_29_0._currentState:OnEnd(arg_29_0)
end
