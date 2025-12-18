ys = ys or {}

local ys = ys
local BattleBuffGuarded = class("BattleBuffGuarded", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffGuarded = BattleBuffGuarded
BattleBuffGuarded.__name = "BattleBuffGuarded"

function BattleBuffGuarded.Ctor(self, effectData)
	BattleBuffGuarded.super.Ctor(self, effectData)
end

function BattleBuffGuarded.SetArgs(self, owner, buff)
	self._casterUID = buff:GetCaster():GetUniqueID()
end

function BattleBuffGuarded.onAttach(self, owner, buff)
	ys.Battle.BattleAttr.AddGuardianID(owner, self._casterUID)
end

function BattleBuffGuarded.onRemove(self, owner, buff)
	ys.Battle.BattleAttr.RemoveGuardianID(owner, self._casterUID)
end
