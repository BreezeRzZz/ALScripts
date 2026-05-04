ys = ys or {}

local ys = ys
local BattleBuffEvent = ys.Battle.BattleBuffEvent
local BuffEffectType = ys.Battle.BattleConst.BuffEffectType
local BattleCardPuzzleFormulas = ys.Battle.BattleCardPuzzleFormulas
local BattleCardPuzzleFleetBuffUnit = class("BattleCardPuzzleFleetBuffUnit")

ys.Battle.BattleCardPuzzleFleetBuffUnit = BattleCardPuzzleFleetBuffUnit
BattleCardPuzzleFleetBuffUnit.__name = "BattleCardPuzzleFleetBuffUnit"

--- @class BattleCardPuzzleFleetBuffUnit
--- @param buffID number Buff模板ID
--- @param level number Buff等级
--- 卡牌谜题舰队Buff构造
function BattleCardPuzzleFleetBuffUnit.Ctor(self, buffID, level)
	level = level or 1
	self._id = buffID
	self._tempData = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID, level)
	self._effectList = {}
	self._triggerSearchTable = {}
	self._level = level

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

	self:SetActive()
end

--- 检查是否响应某个Trigger类型
function BattleCardPuzzleFleetBuffUnit.IsResponTo(self, trigger)
	local effectList = self._triggerSearchTable[trigger]

	if effectList ~= nil and #effectList > 0 then
		return true
	end

	return false
end

--- 设置Buff宿主及参数
function BattleCardPuzzleFleetBuffUnit.SetArgs(self, host)
	self._host = host

	for _, effect in ipairs(self._effectList) do
		effect:SetArgs(host, self)
	end
end

--- 设置移除时间。支持字符串公式解析持续时间
function BattleCardPuzzleFleetBuffUnit.setRemoveTime(self)
	if self._tempData.time == nil then
		return
	end

	local rawTime = self._tempData.time

	-- 字符串型持续时间为公式，需要解析计算
	if type(rawTime) == "string" then
		self._duration = math.max(0, BattleCardPuzzleFormulas.parseFormula(rawTime, self._host:GetAttrManager()))
	else
		self._duration = rawTime
	end

	self._expireTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime() + self._duration
end

--- 附加Buff：设置堆叠为1，触发ON_ATTACH
function BattleCardPuzzleFleetBuffUnit.Attach(self, host)
	self._stack = 1

	self:SetArgs(host)
	self:onTrigger(BuffEffectType.ON_ATTACH)
	self:setRemoveTime()
end

--- 堆叠Buff：stack=0时无限堆叠
function BattleCardPuzzleFleetBuffUnit.Stack(self)
	if self._tempData.stack == 0 then
		self._stack = self._stack + 1
	else
		self._stack = math.min(self._stack + 1, self._tempData.stack)
	end

	self:onTrigger(BuffEffectType.ON_STACK)
	self:setRemoveTime()
end

--- 初始化堆叠（卡牌谜题模式无操作）
function BattleCardPuzzleFleetBuffUnit.InitStack(self)
	return
end

--- 更新堆叠（卡牌谜题模式无操作）
function BattleCardPuzzleFleetBuffUnit.UpdateStack(self, stack)
	return
end

--- 移除Buff：触发ON_REMOVE并从舰队Buff列表清除
function BattleCardPuzzleFleetBuffUnit.Remove(self)
	self:onTrigger(BuffEffectType.ON_REMOVE)

	self._host:GetBuffManager():GetCardPuzzleBuffList()[self._id] = nil

	self:Clear()
end

--- Buff更新：检查是否过期，否则触发ON_UPDATE
function BattleCardPuzzleFleetBuffUnit.Update(self, timeStamp)
	if self:IsExpire(timeStamp) then
		self:Remove()
	else
		self:onTrigger(BuffEffectType.ON_UPDATE, timeStamp)
	end
end

--- Buff触发接口具体实现：遍历对应触发类型的所有Effect
function BattleCardPuzzleFleetBuffUnit.onTrigger(self, trigger, args)
	local buffEffectList = self._triggerSearchTable[trigger]

	if buffEffectList == nil or #buffEffectList == 0 then
		return
	end

	for _, buffEffect in ipairs(buffEffectList) do
		assert(type(buffEffect[trigger]) == "function", "fleet buff效果的触发函数缺失,buff id:>>" .. self._id .. "<<, trigger:>>" .. trigger .. "<<")

		if buffEffect:IsActive() then
			buffEffect:NotActive()
			buffEffect:Trigger(trigger, args)
			buffEffect:SetActive()
		end
	end
end

--- 检查是否过期（无过期时间则永不过期）
function BattleCardPuzzleFleetBuffUnit.IsExpire(self, timeStamp)
	if self._expireTimeStamp == nil then
		return false
	else
		return timeStamp >= self._expireTimeStamp
	end
end

function BattleCardPuzzleFleetBuffUnit.IsActive(self)
	return self._isActive
end

function BattleCardPuzzleFleetBuffUnit.SetActive(self)
	self._isActive = true
end

function BattleCardPuzzleFleetBuffUnit.NotActive(self)
	self._isActive = false
end

--- 舰队Buff无施法者
function BattleCardPuzzleFleetBuffUnit.GetCaster(self)
	return nil
end

function BattleCardPuzzleFleetBuffUnit.GetID(self)
	return self._id
end

function BattleCardPuzzleFleetBuffUnit.GetStack(self)
	return self._stack
end

--- 舰队Buff等级固定为1
function BattleCardPuzzleFleetBuffUnit.GetLv(self)
	return 1
end

--- 获取剩余持续时间比例（无过期时间则返回1）
function BattleCardPuzzleFleetBuffUnit.GetDurationRate(self)
	if self._expireTimeStamp == nil then
		return 1
	else
		local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

		return (self._expireTimeStamp - currentTime) / self._duration
	end
end

--- 清理：释放宿主引用及Effect资源
function BattleCardPuzzleFleetBuffUnit.Clear(self)
	self._host = nil

	for _, effect in ipairs(self._effectList) do
		effect:Clear()
	end
end
