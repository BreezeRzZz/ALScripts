ys = ys or {}

local ys = ys
local BattleBuffEvent = ys.Battle.BattleBuffEvent
local BuffEffectType = ys.Battle.BattleConst.BuffEffectType
local BattleConfig = ys.Battle.BattleConfig
local BattleBuffUnit = class("BattleBuffUnit")

ys.Battle.BattleBuffUnit = BattleBuffUnit
BattleBuffUnit.__name = "BattleBuffUnit"
BattleBuffUnit.DEFAULT_ANI_FX_CONFIG = {
	effect = "jineng",
	offset = {
		0,
		-2,
		0
	}
}

function BattleBuffUnit.Ctor(self, buffID, level, caster)
	level = level or 1
	self._id = buffID

	self:SetTemplate(buffID, level)

	self._time = self._tempData.time
	self._RemoveTime = 0
	self._effectList = {}
	self._triggerSearchTable = {}
	self._level = level
	self._caster = caster
	self._forceStack = self._tempData.force_stack
	self._stackCap = self._tempData.stack_cap or self._tempData.stack

	for index, effectData in ipairs(self._tempData.effect_list) do
		local effect = ys.Battle[effectData.type].New(effectData)

		self._effectList[index] = effect

		local triggerList = effectData.trigger

		for _, trigger in ipairs(triggerList) do
			-- 该Trigger对应能触发的Effect列表
			local effectList = self._triggerSearchTable[trigger]

			if effectList == nil then
				effectList = {}
				self._triggerSearchTable[trigger] = effectList
			end

			effectList[#effectList + 1] = effect
		end
	end
end

-- 被BattleBuffUnit.sortTriggerBuff调用
function BattleBuffUnit.GetTriggerPriority(self, trigger)
	local triggerPriority = BattleConfig.TRIGGER_PRIORITY[trigger]
	local minPriority = math.huge

	for _, effect in ipairs(self._tempData.effect_list) do
		local effectPriority = triggerPriority[effect.type] or BattleConfig.TRIGGER_PRIORITY_LOWEST
		-- Buff的优先级取优先级数值最小的Effect的优先级(表示优先级更高)
		minPriority = math.min(minPriority, effectPriority)
	end

	return minPriority
end

function BattleBuffUnit.SetTemplate(self, buffID, buffLevel)
	self._tempData = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID, buffLevel)
end

-- 附加Buff逻辑。注意会重置持续时间
function BattleBuffUnit.Attach(self, owner)
	self._owner = owner
	self._stack = 1

	self:SetArgs(owner)
	self:onTrigger(BuffEffectType.ON_ATTACH, owner)
	self:SetRemoveTime()
end


-- 新groupLevel <= 原groupLevel时触发
function BattleBuffUnit.Stack(self, owner)
	self._stack = math.min(self._stack + 1, self._tempData.stack)

	self:onTrigger(BuffEffectType.ON_STACK, owner)
	self:SetRemoveTime()
end

function BattleBuffUnit.SetOrb(self, orb, level)
	for _, effect in ipairs(self._effectList) do
		effect:SetOrb(self, orb, level)
	end
end

function BattleBuffUnit.SetOrbDuration(self, duration)
	self._time = duration + self._time
end

function BattleBuffUnit.SetOrbLevel(self, level)
	self._level = level
end

function BattleBuffUnit.SetGroupLevel(self, groupLevel)
	self._groupLevel = groupLevel
end

function BattleBuffUnit.GetGroupLevel(self)
	return self._groupLevel or 1
end

function BattleBuffUnit.SetInfection(self, infection)
	for _, effect in ipairs(self._effectList) do
		if effect.SetInfection then
			effect:SetInfection(infection)
		end
	end
end

function BattleBuffUnit.SetCommander(self, commander)
	self._commander = commander

	for _, effect in ipairs(self._effectList) do
		effect:SetCommander(commander)
	end
end

function BattleBuffUnit.GetEffectList(self)
	return self._effectList
end

function BattleBuffUnit.GetCommander(self)
	return self._commander
end

function BattleBuffUnit.UpdateStack(self, owner, stack)
	if self._stack == stack then
		return
	end

	self._stack = math.min(stack, self._tempData.stack)

	self:onTrigger(BuffEffectType.ON_STACK, owner)
	self:SetRemoveTime()

	local args = {
		unit_id = owner:GetUniqueID(),
		buff_id = self._id,
		stack_count = self._stack
	}

	owner:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_STACK, args))
end

function BattleBuffUnit.Remove(self, timeStamp)
	local owner = self._owner
	local buffID = self._id
	local buffRemoveArgs = {
		unit_id = owner:GetUniqueID(),
		buff_id = buffID
	}

	owner:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_REMOVE, buffRemoveArgs))
	self:onTrigger(BuffEffectType.ON_REMOVE, owner)
	self:Clear()

	owner:GetBuffList()[buffID] = nil
end

-- Buff更新接口，检查是否到达移除时间，触发ON_UPDATE
function BattleBuffUnit.Update(self, owner, timeStamp)
	if self:IsTimeToRemove(timeStamp) then
		self:Remove(timeStamp)
	else
		self:onTrigger(BuffEffectType.ON_UPDATE, owner, {
			timeStamp = timeStamp
		})
	end
end

function BattleBuffUnit.SetArgs(self, owner)
	for _, effect in ipairs(self._effectList) do
		effect:SetCaster(self._caster)
		effect:SetArgs(owner, self)
	end
end

--- @class BattleBuffUnit
--- @param owner BattleUnit
--- @param trigger string
--- @param args table<string, any>
--- @return nil
--- Buff本身的触发接口
--- - 这是一个静态方法
--- - 遍历owner的所有Buff，找到可以触发effectType的Buff，调用它们的onTrigger方法
function BattleBuffUnit.Trigger(owner, trigger, args)
	local buffList = owner:GetBuffList() or {}
	local canTriggerBuffList = {}

	for _, buff in pairs(buffList) do
		--- @type table<number, BattleBuffEffect>
		local buffEffectList = buff._triggerSearchTable[trigger]

		if buffEffectList ~= nil and #buffEffectList > 0 then
			canTriggerBuffList[#canTriggerBuffList + 1] = buff
		end
	end
	-- 按照优先级排序并按顺序触发
	-- 这个优先级，目前只针对ON_TAKE_DAMAGE的Trigger，具体参考BattleConfig.TRIGGER_PRIORITY
	-- 优先级越小，则触发顺序越靠前，以下描述的">"表示优先级更高，越先触发，对应的就是数值越小
	-- 简要描述：BattleBuffLockHealth > BattleBuffHPLink > BattleBuffShield = BattleBuffOverHealingShield = BattleBuffRecordShield = BattleBuffBarrier > BattleBuffCastSkillDamageCount > BattleBuffCount
	-- 如果优先级相同，按照Buff的添加顺序触发(一般来说，就是Buff ID优先？），先添加的先触发
	BattleBuffUnit.sortTriggerBuff(canTriggerBuffList, trigger)

	for _, buff in ipairs(canTriggerBuffList) do
		buff:onTrigger(trigger, owner, args)
	end
end

--- @class BattleBuffUnit
--- @param buffList table<number, BattleBuffUnit>
--- @param trigger string
--- @return table<number, BattleBuffUnit>
function BattleBuffUnit.sortTriggerBuff(buffList, trigger)
	if not BattleConfig.TRIGGER_PRIORITY[trigger] then
		return buffList
	end

	--- @type table<string, number>
	local triggerPriority = BattleConfig.TRIGGER_PRIORITY[trigger]

	table.sort(buffList, function(buff1, buff2)
		return buff1:GetTriggerPriority(trigger) < buff2:GetTriggerPriority(trigger)
	end)
end

function BattleBuffUnit.DisptachSkillFloat(self, owner, trigger, popConfig)
	if popConfig.trigger == nil or table.contains(popConfig.trigger, trigger) then
		local _popConfig

		if popConfig.painting and type(popConfig.painting) == "string" then
			_popConfig = popConfig
		end

		local popSkillName = getSkillName(popConfig.displayID or self._id)

		owner:DispatchSkillFloat(popSkillName, nil, _popConfig)

		local castCV

		if popConfig.castCV ~= false then
			castCV = popConfig.castCV or "skill"
		end

		local castCVValueType = type(castCV)

		if castCVValueType == "string" then
			owner:DispatchVoice(castCV)
		elseif castCVValueType == "table" then
			local _, sfx, _ = ShipWordHelper.GetWordAndCV(castCV.skinID, castCV.key)

			pg.CriMgr.GetInstance():PlaySoundEffect_V3(sfx)
		end

		local aniEffect = popConfig.aniEffect or BattleBuffUnit.DEFAULT_ANI_FX_CONFIG
		local addEffectArgs = {
			effect = aniEffect.effect,
			offset = aniEffect.offset
		}

		owner:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, addEffectArgs))
	end
end

function BattleBuffUnit.IsSubmarineSpecial(self)
	local effectList = self._triggerSearchTable[ys.Battle.BattleConst.BuffEffectType.ON_SUBMARINE_FREE_SPECIAL] or {}

	for _, effect in ipairs(effectList) do
		if effect:HaveQuota() then
			return true
		end
	end

	return false
end

--- @class BattleBuffUnit
--- @param trigger string
--- @param owner BattleUnit
--- @param args table<string, any>
--- @return nil
--- Buff触发接口的具体实现
--- - 遍历触发该buff的所有Effect，调用Effect的触发函数
function BattleBuffUnit.onTrigger(self, trigger, owner, args)
	local buffEffectList = self._triggerSearchTable[trigger]

	if buffEffectList == nil or #buffEffectList == 0 then
		return
	end

	for _, buffEffect in ipairs(buffEffectList) do
		assert(type(buffEffect[trigger]) == "function", "buff效果的触发名字和触发函数不相符,buff id:>>" .. self._id .. "<<, trigger:>>" .. trigger .. "<<")

		if buffEffect:HaveQuota() and buffEffect:IsActive() then
			buffEffect:NotActive()
			buffEffect:Trigger(trigger, owner, self, args)
			local popConfig = buffEffect:GetPopConfig()

			if popConfig then
				self:DisptachSkillFloat(owner, trigger, popConfig)
			end

			buffEffect:SetActive()
		end

		if self._isCancel then
			break
		end
	end

	if self._isCancel then
		self._isCancel = nil

		self:Remove()
	end
end

-- 重置移除时间
function BattleBuffUnit.SetRemoveTime(self)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	self._buffStartTimeStamp = currentTime
	self._RemoveTime = currentTime + self._time
	self._cancelTime = nil
end

function BattleBuffUnit.IsTimeToRemove(self, timeStamp)
	if self._isCancel then
		return true
	elseif self._cancelTime and timeStamp >= self._cancelTime then
		return true
	elseif self._time == 0 then
		return false
	else
		return timeStamp >= self._RemoveTime
	end
end

function BattleBuffUnit.GetBuffLifeTime(self)
	return self._time
end

function BattleBuffUnit.GetBuffStartTime(self)
	return self._buffStartTimeStamp
end

function BattleBuffUnit.Interrupt(self)
	for _, effect in ipairs(self._effectList) do
		effect:Interrupt()
	end
end

function BattleBuffUnit.Clear(self)
	for _, effect in ipairs(self._effectList) do
		effect:Clear()
	end
end

function BattleBuffUnit.GetID(self)
	return self._id
end

function BattleBuffUnit.GetCaster(self)
	return self._caster
end

function BattleBuffUnit.GetLv(self)
	return self._level or 1
end

function BattleBuffUnit.GetDuration(self)
	return self._time
end

function BattleBuffUnit.GetStack(self)
	return self._stack or 1
end

function BattleBuffUnit.IsForceStack(self)
	return self._forceStack
end

-- 可以来自BattleBuffCancelBuff.onTrigger
function BattleBuffUnit.SetToCancel(self, delay)
	if delay then
		if not self._cancelTime then
			self._cancelTime = pg.TimeMgr.GetInstance():GetCombatTime() + delay
		end
	else
		self._isCancel = true
	end
end

function BattleBuffUnit.Dispose(self)
	self._triggerSearchTable = nil
	self._commander = nil
end
