ys = ys or {}

local ys = ys

ys.Battle.BattleBuffAddAircraftOrb = class("BattleBuffAddAircraftOrb", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffAddAircraftOrb.__name = "BattleBuffAddAircraftOrb"

local BattleBuffAddAircraftOrb = ys.Battle.BattleBuffAddAircraftOrb

function BattleBuffAddAircraftOrb.Ctor(self, effectData)
	BattleBuffAddAircraftOrb.super.Ctor(self, effectData)
end

function BattleBuffAddAircraftOrb.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._buffID = arg_list.buff_id
	self._rant = arg_list.rant or 10000
	self._level = arg_list.level or 1
	self._buffLevel = arg_list.buff_level or 1
end

function BattleBuffAddAircraftOrb.onAircraftCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	local attachBuff = {
		buffID = self._buffID,
		rant = self._rant,
		level = self._level,
		buff_level = self._buffLevel
	}
	local aircraftWeaponList = args.aircraft:GetWeapon()

	for _, aircraftWeapon in ipairs(aircraftWeaponList) do
		aircraftWeapon:SetBulletOrbData(attachBuff)
	end
end
