ys = ys or {}

local ys = ys

ys.Battle.BattleFleetBuffJam = class("BattleFleetBuffJam", ys.Battle.BattleFleetBuffEffect)
ys.Battle.BattleFleetBuffJam.__name = "BattleFleetBuffJam"

local BattleFleetBuffJam = ys.Battle.BattleFleetBuffJam

-- 让舰队无法使用武器
function BattleFleetBuffJam.Ctor(self, tempData)
	BattleFleetBuffJam.super.Ctor(self, tempData)
end

function BattleFleetBuffJam.onAttach(self, fleetVO, fleetBuff)
	ys.Battle.BattleDataProxy.GetInstance():JamManualCast(true)
	fleetVO:Jamming(true)
	fleetVO:SetWeaponBlock(1)
end

function BattleFleetBuffJam.onRemove(self, fleetVO, fleetBuff)
	ys.Battle.BattleDataProxy.GetInstance():JamManualCast(false)
	fleetVO:Jamming(false)
	fleetVO:SetWeaponBlock(-1)
end
