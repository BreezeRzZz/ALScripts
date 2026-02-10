ys = ys or {}

local ys = ys

ys.Battle.BattleFleetBuffEffect = class("BattleFleetBuffEffect")
ys.Battle.BattleFleetBuffEffect.__name = "BattleFleetBuffEffect"

local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleFleetBuffEffect = ys.Battle.BattleFleetBuffEffect

function BattleFleetBuffEffect.Ctor(self, tempData)
	self._tempData = Clone(tempData)
	self._type = self._tempData.type

	self:SetActive()
end

function BattleFleetBuffEffect.SetArgs(self, fleetVO, fleetBuff)
	self._fleetVO = fleetVO
	self._fleetBuff = fleetBuff
end

-- BattleFleetBuffUnit.onTrigger调用
-- 从这里出发，到对应的各种各样的onXXX函数(包括子类的各种重载函数)
function BattleFleetBuffEffect.Trigger(self, trigger, host, fleetBuff, timeStamp)
	self[trigger](self, host, fleetBuff, timeStamp)
end

function BattleFleetBuffEffect.onAttach(arg_4_0, arg_4_1, arg_4_2)
	arg_4_0:onTrigger(arg_4_1, arg_4_2)
end

function BattleFleetBuffEffect.onRemove(arg_5_0, arg_5_1, arg_5_2)
	arg_5_0:onTrigger(arg_5_1, arg_5_2)
end

function BattleFleetBuffEffect.onUpdate(arg_6_0, arg_6_1, arg_6_2)
	arg_6_0:onTrigger(arg_6_1, arg_6_2)
end

function BattleFleetBuffEffect.onStack(arg_7_0, arg_7_1, arg_7_2)
	arg_7_0:onTrigger(arg_7_1, arg_7_2)
end

function BattleFleetBuffEffect.getTargetList(arg_8_0, arg_8_1, arg_8_2, arg_8_3)
	local var_8_0
	local var_8_1 = arg_8_1:GetUnitList()[1]

	for iter_8_0, iter_8_1 in ipairs(arg_8_2) do
		var_8_0 = ys.Battle.BattleTargetChoise[iter_8_1](var_8_1, arg_8_3, var_8_0)
	end

	return var_8_0
end

function BattleFleetBuffEffect.IsActive(arg_9_0)
	return arg_9_0._isActive
end

function BattleFleetBuffEffect.SetActive(arg_10_0)
	arg_10_0._isActive = true
end

function BattleFleetBuffEffect.NotActive(arg_11_0)
	arg_11_0._isActive = false
end

function BattleFleetBuffEffect.Clear(arg_12_0)
	return
end

function BattleFleetBuffEffect.Dispose(arg_13_0)
	return
end
