ys = ys or {}

local ys = ys
local BattleBuffCease = class("BattleBuffCease", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffCease = BattleBuffCease
BattleBuffCease.__name = "BattleBuffCease"

function BattleBuffCease.Ctor(self, effectData)
	BattleBuffCease.super.Ctor(self, effectData)
end

function BattleBuffCease.onAttach(self, owner, buff)
	owner:CeaseAllWeapon(true)
end

function BattleBuffCease.onRemove(self, owner, buff)
	owner:CeaseAllWeapon(false)
end
