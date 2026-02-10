ys = ys or {}

local ys = ys

ys.Battle.BattleFleetBuffFixSubRefLine = class("BattleFleetBuffFixSubRefLine", ys.Battle.BattleFleetBuffEffect)
ys.Battle.BattleFleetBuffFixSubRefLine.__name = "BattleFleetBuffFixSubRefLine"

local BattleFleetBuffFixSubRefLine = ys.Battle.BattleFleetBuffFixSubRefLine

-- 修正潜艇的攻击基准线到固定值
function BattleFleetBuffFixSubRefLine.Ctor(self, tempData)
	BattleFleetBuffFixSubRefLine.super.Ctor(self, tempData)
end

function BattleFleetBuffFixSubRefLine.onAttach(self, fleetVO, fleetBuff)
	fleetVO:FixSubRefLine(self._tempData.arg_list.line)
end

function BattleFleetBuffFixSubRefLine.onRemove(self, fleetVO, fleetBuff)
	fleetVO:FixSubRefLine()
end
