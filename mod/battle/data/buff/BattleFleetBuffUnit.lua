ys = ys or {}

local ys = ys
local BattleBuffEvent = ys.Battle.BattleBuffEvent
local BuffEffectType = ys.Battle.BattleConst.BuffEffectType
local BattleFleetBuffUnit = class("BattleFleetBuffUnit")

ys.Battle.BattleFleetBuffUnit = BattleFleetBuffUnit
BattleFleetBuffUnit.__name = "BattleFleetBuffUnit"

-- FleetBuff是属于舰队的Buff，而不是属于某个Unit的Buff
-- 实际就是给FleetVO添加一个Buff, 用于给FleetVO添加一些属性或者监听FleetVO的事件(例如全队致盲)
-- FleetBuffID和BuffID用的是一套ID(配置文件), 但是BuffUnit和FleetBuffUnit是两套不同的类, 互不干扰
function BattleFleetBuffUnit.Ctor(self, buffID, level)
	level = level or 1
	self._id = buffID
	-- 从这里就能看出用的是同一套配置逻辑了
	self._tempData = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID, level)
	self._time = self._tempData.time
	self._RemoveTime = 0
	self._effectList = {}
	self._triggerSearchTable = {}
	self._level = level

	for effectIndex, effectData in ipairs(self._tempData.effect_list) do
		local effect = ys.Battle[effectData.type].New(effectData)

		self._effectList[effectIndex] = effect

		local triggerList = effectData.trigger

		for _, trigger in ipairs(triggerList) do
			-- 对应类型trigger能触发的effect列表
			local effectList = self._triggerSearchTable[trigger]

			if effectList == nil then
				effectList = {}
				self._triggerSearchTable[trigger] = effectList
			end

			effectList[#effectList + 1] = effect
		end
	end

	self:SetActive()
end

function BattleFleetBuffUnit.SetArgs(self, host)
	self._host = host

	for _, effect in ipairs(self._effectList) do
		effect:SetArgs(host, self)
	end
end

function BattleFleetBuffUnit.setRemoveTime(self)
	self._RemoveTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._time
	self._cancelTime = nil
end

-- BattleFleetVO.AttachFleetBuff调用
function BattleFleetBuffUnit.Attach(self, host)
	self._stack = 1

	self:SetArgs(host)
	self:onTrigger(BuffEffectType.ON_ATTACH, host)
	self:setRemoveTime()
end

function BattleFleetBuffUnit.Stack(self, host)
	self._stack = math.min(self._stack + 1, self._tempData.stack)

	self:onTrigger(BuffEffectType.ON_STACK, host)
	self:setRemoveTime()
end

function BattleFleetBuffUnit.UpdateStack(arg_6_0, arg_6_1, arg_6_2)
	return
end

function BattleFleetBuffUnit.Remove(self)
	self:onTrigger(BuffEffectType.ON_REMOVE, self._host)

	self._host:GetFleetBuffList()[self._id] = nil

	self:Clear()
end

function BattleFleetBuffUnit.Update(self, host, timeStamp)
	if self:IsTimeToRemove(timeStamp) then
		self:Remove()
	else
		self:onTrigger(BuffEffectType.ON_UPDATE, host, timeStamp)
	end
end

-- 核心: BattleFleetBuffUnit触发效果
-- 和BattleBuffUnit基本一样, 触发每一个effect, 只不过host是FleetVO而不是Unit
-- BattleFleetBuffUnit.Attach/Stack/Remove/Update都会调用这个函数
function BattleFleetBuffUnit.onTrigger(self, trigger, host, timeStamp)
	local effectList = self._triggerSearchTable[trigger]

	if effectList == nil or #effectList == 0 then
		return
	end

	for _, effect in ipairs(effectList) do
		assert(type(effect[trigger]) == "function", "fleet buff效果的触发函数缺失,buff id:>>" .. self._id .. "<<, trigger:>>" .. trigger .. "<<")

		if effect:IsActive() then
			effect:NotActive()
			effect:Trigger(trigger, host, self, timeStamp)
			effect:SetActive()
		end
	end
end

function BattleFleetBuffUnit.IsTimeToRemove(self, timeStamp)
	if self._time == 0 then
		return false
	else
		return timeStamp >= self._RemoveTime
	end
end

function BattleFleetBuffUnit.IsActive(self)
	return self._isActive
end

function BattleFleetBuffUnit.SetActive(self)
	self._isActive = true
end

function BattleFleetBuffUnit.NotActive(self)
	self._isActive = false
end

function BattleFleetBuffUnit.GetCaster(self)
	return nil
end

function BattleFleetBuffUnit.GetID(self)
	return self._id
end

function BattleFleetBuffUnit.GetLv(self)
	return 1
end

function BattleFleetBuffUnit.Clear(self)
	self._host = nil

	for _, effect in ipairs(self._effectList) do
		effect:Clear()
	end
end
