ys = ys or {}

local ys = ys

ys.Battle.BattleBuffDeactiveCLDBox = class("BattleBuffDeactiveCLDBox", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffDeactiveCLDBox.__name = "BattleBuffDeactiveCLDBox"

local BattleBuffDeactiveCLDBox = ys.Battle.BattleBuffDeactiveCLDBox

function BattleBuffDeactiveCLDBox.Ctor(self, effectData)
	BattleBuffDeactiveCLDBox.super.Ctor(self, effectData)
end

function BattleBuffDeactiveCLDBox.GetEffectType(self)
	return BattleBuffDeactiveCLDBox.FX_TYPE
end

function BattleBuffDeactiveCLDBox.onAttach(self, owner, buff)
	owner:SetCldBoxImmune(true)
end

function BattleBuffDeactiveCLDBox.onRemove(self, owner, buff)
	owner:SetCldBoxImmune(false)
end
