ys = ys or {}

local ys = ys

ys.Battle.BattleFleetBuffEffect = class("BattleFleetBuffEffect")
ys.Battle.BattleFleetBuffEffect.__name = "BattleFleetBuffEffect"

local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleFleetBuffEffect = ys.Battle.BattleFleetBuffEffect

--- @class BattleFleetBuffEffect
--- @param tempData table 效果模板数据
function BattleFleetBuffEffect.Ctor(self, tempData)
	self._tempData = Clone(tempData)
	self._type = self._tempData.type

	self:SetActive()
end

--- 设置关联的舰队VO和舰队Buff
--- @param fleetVO BattleFleetVO
--- @param fleetBuff BattleFleetBuffUnit
function BattleFleetBuffEffect.SetArgs(self, fleetVO, fleetBuff)
	self._fleetVO = fleetVO
	self._fleetBuff = fleetBuff
end

-- BattleFleetBuffUnit.onTrigger调用
-- 从这里出发，到对应的各种各样的onXXX函数(包括子类的各种重载函数)
--- @param trigger string 触发方法名
--- @param host BattleUnit 宿主单位
--- @param fleetBuff BattleFleetBuffUnit
--- @param timeStamp number 时间戳
function BattleFleetBuffEffect.Trigger(self, trigger, host, fleetBuff, timeStamp)
	self[trigger](self, host, fleetBuff, timeStamp)
end

--- Buff附加回调
--- @param host BattleUnit
--- @param fleetBuff BattleFleetBuffUnit
function BattleFleetBuffEffect.onAttach(self, host, fleetBuff)
	self:onTrigger(host, fleetBuff)
end

--- Buff移除回调
--- @param host BattleUnit
--- @param fleetBuff BattleFleetBuffUnit
function BattleFleetBuffEffect.onRemove(self, host, fleetBuff)
	self:onTrigger(host, fleetBuff)
end

--- Buff更新回调
--- @param host BattleUnit
--- @param fleetBuff BattleFleetBuffUnit
function BattleFleetBuffEffect.onUpdate(self, host, fleetBuff)
	self:onTrigger(host, fleetBuff)
end

--- Buff堆叠回调
--- @param host BattleUnit
--- @param fleetBuff BattleFleetBuffUnit
function BattleFleetBuffEffect.onStack(self, host, fleetBuff)
	self:onTrigger(host, fleetBuff)
end

--- 获取目标列表：根据方法名链式调用TargetChoise
--- @param host BattleUnit
--- @param targetMethodNames table 目标选择方法名列表
--- @param targetArgs table 目标选择参数
function BattleFleetBuffEffect.getTargetList(self, host, targetMethodNames, targetArgs)
	local result
	local unit = host:GetUnitList()[1]

	for _, methodName in ipairs(targetMethodNames) do
		result = ys.Battle.BattleTargetChoise[methodName](unit, targetArgs, result)
	end

	return result
end

--- 是否激活中
function BattleFleetBuffEffect.IsActive(self)
	return self._isActive
end

--- 设置为激活状态
function BattleFleetBuffEffect.SetActive(self)
	self._isActive = true
end

--- 设置为非激活状态
function BattleFleetBuffEffect.NotActive(self)
	self._isActive = false
end

function BattleFleetBuffEffect.Clear(self)
	return
end

function BattleFleetBuffEffect.Dispose(self)
	return
end
