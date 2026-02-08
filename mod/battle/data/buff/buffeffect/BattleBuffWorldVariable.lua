ys = ys or {}

local ys = ys

ys.Battle.BattleBuffWorldVariable = class("BattleBuffWorldVariable", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffWorldVariable.__name = "BattleBuffWorldVariable"

local BattleBuffWorldVariable = ys.Battle.BattleBuffWorldVariable

-- 这个BuffEffect看起来是用来调控UI速度(子弹时间之类的效果)的. 具体是通过设置BattleVariable里的变量来实现的.
-- 但目前看起来是废弃的
function BattleBuffWorldVariable.Ctor(self, effectData)
	BattleBuffWorldVariable.super.Ctor(self, effectData)
end

function BattleBuffWorldVariable.SetArgs(self, owner, buff)
	self._variable = self._tempData.arg_list.variable
	self._key = self._tempData.arg_list.key
	self._number = self._tempData.arg_list.number
	self._resetNumber = self._tempData.arg_list.resetNumber
	self._speedFactorName = "buff_" .. self._tempData.id
end

function BattleBuffWorldVariable.onAttach(self, owner, buff)
	local BattleVariable = ys.Battle.BattleVariable

	if self._key then
		BattleVariable.AppendIFFFactor(self._key, self._speedFactorName, self._number)
	else
		BattleVariable.AppendMapFactor(self._speedFactorName, self._number)
	end
end

function BattleBuffWorldVariable.onRemove(self, owner, buff)
	local BattleVariable = ys.Battle.BattleVariable

	if self._key then
		BattleVariable.RemoveIFFFactor(self._key, self._speedFactorName)
	else
		BattleVariable.RemoveMapFactor(self._speedFactorName)
	end
end
