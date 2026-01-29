ys = ys or {}

local ys = ys
local BattleAntiAirUnit = class("BattleAntiAirUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleAntiAirUnit = BattleAntiAirUnit
BattleAntiAirUnit.__name = "BattleAntiAirUnit"

-- 代表武器：舰载机的对空机炮
function BattleAntiAirUnit.Ctor(self)
	BattleAntiAirUnit.super.Ctor(self)
end

function BattleAntiAirUnit.TriggerBuffOnFire(self)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ANTIAIR_FIRE_NEAR, {})
end

function BattleAntiAirUnit.FilterTarget(self)
	local aircraftLIst = self._dataProxy:GetAircraftList()
	local filteredList = {}
	local hostIFF = self._host:GetIFF()
	local index = 1

	for _, aircraft in pairs(aircraftLIst) do
		if aircraft:GetIFF() ~= hostIFF and aircraft:IsVisitable() then
			filteredList[index] = aircraft
			index = index + 1
		end
	end

	return filteredList
end

function BattleAntiAirUnit.Spawn(self, bulletID, target)
	local bullet = BattleAntiAirUnit.super.Spawn(self, bulletID, target)

	bullet:SetDirectHitUnit(target)

	return bullet
end

function BattleAntiAirUnit.TriggerBuffWhenSpawn(self, bullet)
	local args = {
		_bullet = bullet,
		bulletTag = bullet:GetExtraTag()
	}

	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_CREATE, args)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ANTIAIR_BULLET_CREATE, args)
end
