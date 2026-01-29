ys = ys or {}

local ys = ys

ys.Battle.BattleDirectHitWeaponUnit = class("BattleDirectHitWeaponUnit", ys.Battle.BattleWeaponUnit)
ys.Battle.BattleDirectHitWeaponUnit.__name = "BattleDirectHitWeaponUnit"

local BattleDirectHitWeaponUnit = ys.Battle.BattleDirectHitWeaponUnit

function BattleDirectHitWeaponUnit.Ctor(self)
	BattleDirectHitWeaponUnit.super.Ctor(self)
end

function BattleDirectHitWeaponUnit.Spawn(self, bulletID, target)
	local directBullet = BattleDirectHitWeaponUnit.super.Spawn(self, bulletID, target)

	directBullet:SetDirectHitUnit(target)

	return directBullet
end
