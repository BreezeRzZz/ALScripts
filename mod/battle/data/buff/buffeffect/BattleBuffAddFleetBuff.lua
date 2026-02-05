ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleBuffAddFleetBuff = class("BattleBuffAddFleetBuff", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddFleetBuff = BattleBuffAddFleetBuff
BattleBuffAddFleetBuff.__name = "BattleBuffAddFleetBuff"

function BattleBuffAddFleetBuff.Ctor(self, effectData)
	BattleBuffAddFleetBuff.super.Ctor(self, effectData)
end

function BattleBuffAddFleetBuff.SetArgs(self, owner, buff)
	self._level = buff:GetLv()
	self._fleetBuffID = self._tempData.arg_list.fleet_buff_id
end

function BattleBuffAddFleetBuff.onAttach(self, owner, buff)
	if owner:GetUnitType() ~= BattleConst.UnitType.PLAYER_UNIT then
		return
	end

	local fleetBuff = ys.Battle.BattleFleetBuffUnit.New(self._fleetBuffID)

	owner:GetFleetVO():AttachFleetBuff(fleetBuff)
end

function BattleBuffAddFleetBuff.onRemove(self, owner, buff)
	if owner:GetUnitType() ~= BattleConst.UnitType.PLAYER_UNIT then
		return
	end

	owner:GetFleetVO():RemoveFleetBuff(self._fleetBuffID)
end
