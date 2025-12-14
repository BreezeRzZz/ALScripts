ys = ys or {}

local ys = ys

ys.Battle.BattleBuffPointAirStrike = class("BattleBuffPointAirStrike", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffPointAirStrike.__name = "BattleBuffPointAirStrike"

local BattleBuffPointAirStrike = ys.Battle.BattleBuffPointAirStrike

function BattleBuffPointAirStrike.Ctor(self, effectData)
	BattleBuffPointAirStrike.super.Ctor(self, effectData)
end

function BattleBuffPointAirStrike.SetArgs(self, owner, buff)
	self._hiveIDList = self._tempData.arg_list.aircraft_id_list
	self._initCD = self._tempData.arg_list.initial_over_heat
	self._stackCount = self._tempData.arg_list.stack_count
	self._strikeWeapon = self._tempData.arg_list.weapon_id
end

function BattleBuffPointAirStrike.onAttach(self, owner, buff)
	self:addManualWeapon(owner)
end

function BattleBuffPointAirStrike.addManualWeapon(self, owner)
	for i = 1, self._stackCount do
		owner:AddPointAirStrike(self._strikeWeapon, self._coolDownDuration, self._initCD):SetAirUnit(self._hiveIDList)
	end
end
