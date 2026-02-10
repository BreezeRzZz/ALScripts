ys = ys or {}

local ys = ys

ys.Battle.BattleFleetBuffInk = class("BattleFleetBuffInk", ys.Battle.BattleFleetBuffEffect)
ys.Battle.BattleFleetBuffInk.__name = "BattleFleetBuffInk"

local BattleFleetBuffInk = ys.Battle.BattleFleetBuffInk

-- 致盲舰队: 不能使用武器
function BattleFleetBuffInk.Ctor(self, tempData)
	BattleFleetBuffInk.super.Ctor(self, tempData)
end

function BattleFleetBuffInk.onAttach(self, fleetVO, fleetBuff)
	fleetVO:Blinding(true)
	fleetVO:SetWeaponBlock(1)
end

function BattleFleetBuffInk.onRemove(self, fleetVO, fleetBuff)
	fleetVO:Blinding(false)
	fleetVO:SetWeaponBlock(-1)
end
