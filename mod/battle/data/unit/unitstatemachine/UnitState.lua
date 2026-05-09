ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local ActionName = BattleConst.ActionName

--- @class UnitState : 单位动作状态机
--- 管理单位的动画状态切换（移动、攻击、死亡、胜利等）
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

--- 构造函数：创建所有子状态并初始化为Idle
--- @param target BattleUnit: 状态机所属的单位
function ys.Battle.UnitState.Ctor(self, target)
	self._target = target
	self._idleState = ys.Battle.IdleState.New()
	self._moveState = ys.Battle.MoveState.New()
	self._attackState = ys.Battle.AttackState.New()
	self._attackLeftState = ys.Battle.AttackLeftState.New()
	self._deadState = ys.Battle.DeadState.New()
	self._moveLeftState = ys.Battle.MoveLeftState.New()
	self._victoryState = ys.Battle.VictoryState.New()
	self._victorySwimState = ys.Battle.VictorySwimState.New()
	self._standState = ys.Battle.StandState.New()
	self._spellState = ys.Battle.SpellState.New()
	self._interruptState = ys.Battle.InterruptState.New()
	self._skillStartState = ys.Battle.SkillStartState.New()
	self._skillEndState = ys.Battle.SkillEndState.New()
	self._diveState = ys.Battle.DiveState.New()
	self._diveLeftState = ys.Battle.DiveLeftState.New()
	self._raidState = ys.Battle.RaidState.New()
	self._raidLeftState = ys.Battle.RaidLeftState.New()

	self:OnIdleState()
end

--- 刷新动作键偏移量：检查是否需要追加偏移后缀
function ys.Battle.UnitState.FreshActionKeyOffset(self)
	local offset = self:ActionKeyOffset()

	if offset then
		if string.find(self._currentAction, offset) == nil then
			self:SendAction(self._currentAction .. offset)
		end
	elseif self._offset ~= nil then
		local offsetPos = string.find(self._currentAction, self._offset)

		self:SendAction(string.sub(self._currentAction, 1, offsetPos - 1))
	end

	self._offset = offset
end

--- 切换状态
--- @param newState string: 目标状态名
--- @param stateParam any: 状态参数（如攻击类型）
function ys.Battle.UnitState.ChangeState(self, newState, stateParam)
	if newState == self.STATE_IDLE then
		self._currentState:AddIdleState(self)
	elseif newState == self.STATE_MOVE then
		self._currentState:AddMoveState(self)
	elseif newState == self.STATE_MOVE then
		self._currentState:AddMoveState(self)
	elseif newState == self.STATE_ATTACK then
		self._currentState:AddAttackState(self, stateParam)
	elseif newState == self.STATE_DEAD then
		self._currentState:AddDeadState(self)
	elseif newState == self.STATE_MOVELEFT then
		self._currentState:AddMoveLeftState(self)
	elseif newState == self.STATE_VICTORY then
		local oxyState = self:GetTarget():GetOxyState()

		if oxyState and oxyState:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
			self._currentState:AddVictorySwimState(self)
		else
			self._currentState:AddVictoryState(self)
		end
	elseif newState == self.STATE_INTERRUPT then
		self._currentState:AddInterruptState(self)
	elseif newState == self.STATE_STAND then
		self._currentState:AddStandState(self)
	elseif newState == self.STATE_DIVE then
		self._currentState:AddDiveState(self)
	elseif newState == self.STATE_DIVELEFT then
		self._currentState:AddDiveLeftState(self)
	elseif newState == self.STATE_SKILL_START then
		self._currentState:AddSkillStartState(self)
	elseif newState == self.STATE_SKILL_END then
		self._currentState:AddSkillEndState(self)
	else
		assert(false, self._target.__name .. "'s state machine, unexcepted state: " .. newState)
	end
end

--- 进入移动状态
function ys.Battle.UnitState.OnMoveState(self)
	self._currentState = self._moveState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入左移状态
function ys.Battle.UnitState.OnMoveLeftState(self)
	self._currentState = self._moveLeftState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入待机状态
function ys.Battle.UnitState.OnIdleState(self)
	self._currentState = self._idleState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入攻击状态
--- @param attackType string: 攻击类型
function ys.Battle.UnitState.OnAttackState(self, attackType)
	self._currentState = self._attackState

	local actionName = self._currentState:GetActionName(self, attackType)

	self:SendAction(actionName)
end

--- 进入左侧攻击状态
--- @param attackType string: 攻击类型
function ys.Battle.UnitState.OnAttackLeftState(self, attackType)
	self._currentState = self._attackLeftState

	local actionName = self._currentState:GetActionName(self, attackType)

	self:SendAction(actionName)
end

--- 进入潜水状态
function ys.Battle.UnitState.OnDiveState(self)
	self._currentState = self._diveState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入左侧潜水状态
function ys.Battle.UnitState.OnDiveLeftState(self)
	self._currentState = self._diveLeftState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入突袭状态
--- @param raidType string: 突袭类型
function ys.Battle.UnitState.OnRaidState(self, raidType)
	self._currentState = self._raidState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入左侧突袭状态
--- @param raidType string: 突袭类型
function ys.Battle.UnitState.OnRaidLeftState(self, raidType)
	self._currentState = self._raidLeftState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入死亡状态
function ys.Battle.UnitState.OnDeadState(self)
	self._currentState = self._deadState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入胜利状态
function ys.Battle.UnitState.OnVictoryState(self)
	self._currentState = self._victoryState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入胜利泳姿状态
function ys.Battle.UnitState.OnVictorySwimState(self)
	self._currentState = self._victorySwimState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入站立状态
function ys.Battle.UnitState.OnStandState(self)
	self._currentState = self._standState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入中断状态
function ys.Battle.UnitState.OnInterruptState(self)
	self._currentState = self._interruptState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入技能开始状态
function ys.Battle.UnitState.OnSkillStartState(self)
	self._currentState = self._skillStartState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 进入技能结束状态
function ys.Battle.UnitState.OnSkillEndState(self)
	self._currentState = self._skillEndState

	local actionName = self._currentState:GetActionName(self)

	self:SendAction(actionName)
end

--- 根据速度方向自动切换到移动/潜水状态
function ys.Battle.UnitState.ChangeToMoveState(self)
	local speedX = self:GetTarget():GetSpeed().x
	local oxyState = self:GetTarget():GetOxyState()

	if oxyState and oxyState:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
		if speedX >= 0 then
			self:OnDiveState()
		else
			self:OnDiveLeftState()
		end
	elseif speedX >= 0 then
		self:OnMoveState()
	else
		self:OnMoveLeftState()
	end
end

--- 发送动作事件
--- @param actionName string: 动作名称
function ys.Battle.UnitState.SendAction(self, actionName)
	self._currentAction = actionName

	local event = ys.Event.New(ys.Battle.BattleUnitEvent.CHANGE_ACTION, {
		actionType = actionName
	})

	self._target:DispatchEvent(event)
end

--- 切换氧气状态
--- @param oxyState number: 氧气状态
function ys.Battle.UnitState.ChangeOxyState(self, oxyState)
	self._target:ChangeOxygenState(oxyState)
end

--- 获取目标单位
--- @return BattleUnit: 目标单位
function ys.Battle.UnitState.GetTarget(self)
	return self._target
end

--- 获取动作键偏移量（由子类重写）
--- @return string: 偏移量
function ys.Battle.UnitState.ActionKeyOffset(self)
	return self._target:GetActionKeyOffset()
end

--- 获取当前状态名
--- @return string: 状态名
function ys.Battle.UnitState.GetCurrentStateName(self)
	return self._currentState.__name
end

--- 是否需要武器缓存
--- @return boolean: 是否需要
function ys.Battle.UnitState.NeedWeaponCache(self)
	return self._currentState:CacheWeapon()
end

--- 动作开始回调
function ys.Battle.UnitState.OnActionStart(self)
	self._currentState:OnStart(self)
end

--- 动作触发回调
function ys.Battle.UnitState.OnActionTrigger(self)
	self._currentState:OnTrigger(self)
end

--- 动作结束回调
function ys.Battle.UnitState.OnActionEnd(self)
	self._currentState:OnEnd(self)
end
