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
-- TODO
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

	for iter_1_0, iter_1_1 in ipairs(self._tempData.effect_list) do
		local var_1_0 = ys.Battle[iter_1_1.type].New(iter_1_1)

		self._effectList[iter_1_0] = var_1_0

		local var_1_1 = iter_1_1.trigger

		for iter_1_2, iter_1_3 in ipairs(var_1_1) do
			local var_1_2 = self._triggerSearchTable[iter_1_3]

			if var_1_2 == nil then
				var_1_2 = {}
				self._triggerSearchTable[iter_1_3] = var_1_2
			end

			var_1_2[#var_1_2 + 1] = var_1_0
		end
	end
end
-- TODO
function BattleBuffUnit.GetTriggerPriority(arg_2_0, arg_2_1)
	local var_2_0 = BattleConfig.TRIGGER_PRIORITY[arg_2_1]
	local var_2_1 = math.huge

	for iter_2_0, iter_2_1 in ipairs(arg_2_0._tempData.effect_list) do
		local var_2_2 = var_2_0[iter_2_1.type] or BattleConfig.TRIGGER_PRIORITY_LOWEST

		var_2_1 = math.min(var_2_1, var_2_2)
	end

	return var_2_1
end

function BattleBuffUnit.SetTemplate(arg_3_0, arg_3_1, arg_3_2)
	arg_3_0._tempData = ys.Battle.BattleDataFunction.GetBuffTemplate(arg_3_1, arg_3_2)
end

function BattleBuffUnit.Attach(arg_4_0, arg_4_1)
	arg_4_0._owner = arg_4_1
	arg_4_0._stack = 1

	arg_4_0:SetArgs(arg_4_1)
	arg_4_0:onTrigger(BuffEffectType.ON_ATTACH, arg_4_1)
	arg_4_0:SetRemoveTime()
end
-- TODO
-- 新groupLevel <= 原groupLevel时触发
function BattleBuffUnit.Stack(arg_5_0, arg_5_1)
	arg_5_0._stack = math.min(arg_5_0._stack + 1, arg_5_0._tempData.stack)

	arg_5_0:onTrigger(BuffEffectType.ON_STACK, arg_5_1)
	arg_5_0:SetRemoveTime()
end

function BattleBuffUnit.SetOrb(arg_6_0, arg_6_1, arg_6_2)
	for iter_6_0, iter_6_1 in ipairs(arg_6_0._effectList) do
		iter_6_1:SetOrb(arg_6_0, arg_6_1, arg_6_2)
	end
end

function BattleBuffUnit.SetOrbDuration(arg_7_0, arg_7_1)
	arg_7_0._time = arg_7_1 + arg_7_0._time
end

function BattleBuffUnit.SetOrbLevel(arg_8_0, arg_8_1)
	arg_8_0._level = arg_8_1
end

function BattleBuffUnit.SetGroupLevel(arg_9_0, arg_9_1)
	arg_9_0._groupLevel = arg_9_1
end

function BattleBuffUnit.GetGroupLevel(arg_10_0)
	return arg_10_0._groupLevel or 1
end

function BattleBuffUnit.SetInfection(arg_11_0, arg_11_1)
	for iter_11_0, iter_11_1 in ipairs(arg_11_0._effectList) do
		if iter_11_1.SetInfection then
			iter_11_1:SetInfection(arg_11_1)
		end
	end
end

function BattleBuffUnit.SetCommander(arg_12_0, arg_12_1)
	arg_12_0._commander = arg_12_1

	for iter_12_0, iter_12_1 in ipairs(arg_12_0._effectList) do
		iter_12_1:SetCommander(arg_12_1)
	end
end

function BattleBuffUnit.GetEffectList(arg_13_0)
	return arg_13_0._effectList
end

function BattleBuffUnit.GetCommander(arg_14_0)
	return arg_14_0._commander
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

function BattleBuffUnit.Remove(arg_16_0, arg_16_1)
	local var_16_0 = arg_16_0._owner
	local var_16_1 = arg_16_0._id
	local var_16_2 = {
		unit_id = var_16_0:GetUniqueID(),
		buff_id = var_16_1
	}

	var_16_0:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_REMOVE, var_16_2))
	arg_16_0:onTrigger(BuffEffectType.ON_REMOVE, var_16_0)
	arg_16_0:Clear()

	var_16_0:GetBuffList()[var_16_1] = nil
end

function BattleBuffUnit.Update(arg_17_0, arg_17_1, arg_17_2)
	if arg_17_0:IsTimeToRemove(arg_17_2) then
		arg_17_0:Remove(arg_17_2)
	else
		arg_17_0:onTrigger(BuffEffectType.ON_UPDATE, arg_17_1, {
			timeStamp = arg_17_2
		})
	end
end

function BattleBuffUnit.SetArgs(arg_18_0, arg_18_1)
	for iter_18_0, iter_18_1 in ipairs(arg_18_0._effectList) do
		iter_18_1:SetCaster(arg_18_0._caster)
		iter_18_1:SetArgs(arg_18_1, arg_18_0)
	end
end

--- @class BattleBuffUnit
--- @param owner BattleUnit
--- @param effectType string
--- @param args table<string, any>
--- @return nil
--- Buff本身的触发接口
--- - 这是一个静态方法
--- - 遍历owner的所有Buff，找到可以触发effectType的Buff，调用它们的onTrigger方法
function BattleBuffUnit.Trigger(owner, effectType, args)
	local buffList = owner:GetBuffList() or {}
	local canTriggerBuffList = {}

	for _, buff in pairs(buffList) do
		--- @type table<number, BattleBuffEffect>
		local buffEffectList = buff._triggerSearchTable[effectType]

		if buffEffectList ~= nil and #buffEffectList > 0 then
			canTriggerBuffList[#canTriggerBuffList + 1] = buff
		end
	end
	-- 按照优先级排序并按顺序触发
	-- 这个优先级，目前只针对ON_TAKE_DAMAGE的Trigger，具体参考BattleConfig.TRIGGER_PRIORITY
	-- 优先级越小，则触发顺序越靠前，以下描述的">"表示优先级更高，越先触发，对应的就是数值越小
	-- 简要描述：BattleBuffLockHealth > BattleBuffHPLink > BattleBuffShield = BattleBuffOverHealingShield = BattleBuffRecordShield = BattleBuffBarrier > BattleBuffCastSkillDamageCount > BattleBuffCount
	-- 如果优先级相同，按照Buff的添加顺序触发(一般来说，就是Buff ID优先？），先添加的先触发
	BattleBuffUnit.sortTriggerBuff(canTriggerBuffList, effectType)

	for _, buff in ipairs(canTriggerBuffList) do
		buff:onTrigger(effectType, owner, args)
	end
end

--- @class BattleBuffUnit
--- @param buffList table<number, BattleBuffUnit>
--- @param effectType string
--- @return table<number, BattleBuffUnit>
function BattleBuffUnit.sortTriggerBuff(buffList, effectType)
	if not BattleConfig.TRIGGER_PRIORITY[effectType] then
		return buffList
	end

	--- @type table<string, number>
	local triggerPriority = BattleConfig.TRIGGER_PRIORITY[effectType]

	table.sort(buffList, function(buff1, buff2)
		return buff1:GetTriggerPriority(effectType) < buff2:GetTriggerPriority(effectType)
	end)
end

function BattleBuffUnit.DisptachSkillFloat(arg_22_0, arg_22_1, arg_22_2, arg_22_3)
	if arg_22_3.trigger == nil or table.contains(arg_22_3.trigger, arg_22_2) then
		local var_22_0

		if arg_22_3.painting and type(arg_22_3.painting) == "string" then
			var_22_0 = arg_22_3
		end

		local var_22_1 = getSkillName(arg_22_3.displayID or arg_22_0._id)

		arg_22_1:DispatchSkillFloat(var_22_1, nil, var_22_0)

		local var_22_2

		if arg_22_3.castCV ~= false then
			var_22_2 = arg_22_3.castCV or "skill"
		end

		local var_22_3 = type(var_22_2)

		if var_22_3 == "string" then
			arg_22_1:DispatchVoice(var_22_2)
		elseif var_22_3 == "table" then
			local var_22_4, var_22_5, var_22_6 = ShipWordHelper.GetWordAndCV(var_22_2.skinID, var_22_2.key)

			pg.CriMgr.GetInstance():PlaySoundEffect_V3(var_22_5)
		end

		local var_22_7 = arg_22_3.aniEffect or BattleBuffUnit.DEFAULT_ANI_FX_CONFIG
		local var_22_8 = {
			effect = var_22_7.effect,
			offset = var_22_7.offset
		}

		arg_22_1:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, var_22_8))
	end
end

function BattleBuffUnit.IsSubmarineSpecial(arg_23_0)
	local var_23_0 = arg_23_0._triggerSearchTable[ys.Battle.BattleConst.BuffEffectType.ON_SUBMARINE_FREE_SPECIAL] or {}

	for iter_23_0, iter_23_1 in ipairs(var_23_0) do
		if iter_23_1:HaveQuota() then
			return true
		end
	end

	return false
end

--- @class BattleBuffUnit
--- @param effectType string
--- @param owner BattleUnit
--- @param args table<string, any>
--- @return nil
--- Buff触发接口的具体实现
--- - 遍历触发该buff的所有Effect，调用Effect的触发函数
function BattleBuffUnit.onTrigger(self, effectType, owner, args)
	local buffEffectList = self._triggerSearchTable[effectType]

	if buffEffectList == nil or #buffEffectList == 0 then
		return
	end

	for _, buffEffect in ipairs(buffEffectList) do
		assert(type(buffEffect[effectType]) == "function", "buff效果的触发名字和触发函数不相符,buff id:>>" .. self._id .. "<<, trigger:>>" .. effectType .. "<<")

		if buffEffect:HaveQuota() and buffEffect:IsActive() then
			buffEffect:NotActive()
			buffEffect:Trigger(effectType, owner, self, args)

			local pop = buffEffect:GetPopConfig()

			if pop then
				self:DisptachSkillFloat(owner, effectType, pop)
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
-- TODO
-- 重置移除时间
function BattleBuffUnit.SetRemoveTime(arg_25_0)
	local var_25_0 = pg.TimeMgr.GetInstance():GetCombatTime()

	arg_25_0._buffStartTimeStamp = var_25_0
	arg_25_0._RemoveTime = var_25_0 + arg_25_0._time
	arg_25_0._cancelTime = nil
end

function BattleBuffUnit.IsTimeToRemove(arg_26_0, arg_26_1)
	if arg_26_0._isCancel then
		return true
	elseif arg_26_0._cancelTime and arg_26_1 >= arg_26_0._cancelTime then
		return true
	elseif arg_26_0._time == 0 then
		return false
	else
		return arg_26_1 >= arg_26_0._RemoveTime
	end
end

function BattleBuffUnit.GetBuffLifeTime(arg_27_0)
	return arg_27_0._time
end

function BattleBuffUnit.GetBuffStartTime(arg_28_0)
	return arg_28_0._buffStartTimeStamp
end

function BattleBuffUnit.Interrupt(self)
	for _, effect in ipairs(self._effectList) do
		effect:Interrupt()
	end
end

function BattleBuffUnit.Clear(arg_30_0)
	for iter_30_0, iter_30_1 in ipairs(arg_30_0._effectList) do
		iter_30_1:Clear()
	end
end

function BattleBuffUnit.GetID(arg_31_0)
	return arg_31_0._id
end

function BattleBuffUnit.GetCaster(arg_32_0)
	return arg_32_0._caster
end

function BattleBuffUnit.GetLv(arg_33_0)
	return arg_33_0._level or 1
end

function BattleBuffUnit.GetDuration(arg_34_0)
	return arg_34_0._time
end

function BattleBuffUnit.GetStack(arg_35_0)
	return arg_35_0._stack or 1
end

function BattleBuffUnit.IsForceStack(arg_36_0)
	return arg_36_0._forceStack
end

function BattleBuffUnit.SetToCancel(arg_37_0, arg_37_1)
	if arg_37_1 then
		if not arg_37_0._cancelTime then
			arg_37_0._cancelTime = pg.TimeMgr.GetInstance():GetCombatTime() + arg_37_1
		end
	else
		arg_37_0._isCancel = true
	end
end

function BattleBuffUnit.Dispose(arg_38_0)
	arg_38_0._triggerSearchTable = nil
	arg_38_0._commander = nil
end
