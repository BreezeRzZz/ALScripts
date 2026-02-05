ys = ys or {}

local ys = ys

ys.Battle.BattleBuffAddAircraftAttr = class("BattleBuffAddAircraftAttr", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffAddAircraftAttr.__name = "BattleBuffAddAircraftAttr"

local BattleBuffAddAircraftAttr = ys.Battle.BattleBuffAddAircraftAttr

function BattleBuffAddAircraftAttr.Ctor(self, effectData)
	BattleBuffAddAircraftAttr.super.Ctor(self, effectData)
end

function BattleBuffAddAircraftAttr.SetArgs(self, owner, buff)
	self._attr = self._tempData.arg_list.attr
	self._number = self._tempData.arg_list.number
	self._numberBase = self._number
end

function BattleBuffAddAircraftAttr.onStack(self, owner, buff)
	self._number = self._numberBase * buff._stack
end

function BattleBuffAddAircraftAttr.onAircraftCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:calcAircraftAttr(args.aircraft)
end

function BattleBuffAddAircraftAttr.calcAircraftAttr(self, aircraft)
	ys.Battle.BattleAttr.Increase(aircraft, self._attr, self._number)
end
