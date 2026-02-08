ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleSkillAddFleetBuff = class("BattleSkillAddFleetBuff", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillAddFleetBuff.__name = "BattleSkillAddFleetBuff"

local BattleSkillAddFleetBuff = ys.Battle.BattleSkillAddFleetBuff

function BattleSkillAddFleetBuff.Ctor(self, template, level)
	BattleSkillAddFleetBuff.super.Ctor(self, template, level)

	self._fleetBuffID = self._tempData.arg_list.fleet_buff_id
end

function BattleSkillAddFleetBuff.DoDataEffect(self, caster, target)
	if target:IsAlive() and target:GetUnitType() == BattleConst.UnitType.PLAYER_UNIT then
		local fleetBuff = ys.Battle.BattleFleetBuffUnit.New(self._fleetBuffID)

		target:GetFleetVO():AttachFleetBuff(fleetBuff)
	end
end
