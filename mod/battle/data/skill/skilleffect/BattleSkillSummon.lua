ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleSkillSummon = class("BattleSkillSummon", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillSummon.__name = "BattleSkillSummon"

local BattleSkillSummon = ys.Battle.BattleSkillSummon

function BattleSkillSummon.Ctor(self, template)
	BattleSkillSummon.super.Ctor(self, template, lv)

	self._spawnData = self._tempData.arg_list.spawnData
end

function BattleSkillSummon.DoDataEffectWithoutTarget(self, caster, attachData)
	self:DoSummon(caster, attachData)
end

function BattleSkillSummon.DoDataEffect(self, caster, target, attachData)
	self:DoSummon(caster, attachData)
end

function BattleSkillSummon.DoSummon(self, caster, attachData)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local casterIFF = caster:GetIFF()
	local unit

	if caster:GetUnitType() == BattleConst.UnitType.PLAYER_UNIT then
		unit = battleDataProxy:SpawnNPC(self._spawnData, caster)
	else
		local waveIndex = caster:GetWaveIndex()

		unit = battleDataProxy:SpawnMonster(self._spawnData, waveIndex, BattleConst.UnitType.ENEMY_UNIT, casterIFF)

		unit:SetMaster(caster)
	end

	if self._spawnData.damageSrcWarp then
		ys.Battle.BattleAttr.SetCurrent(unit, "id", nil)
	end
end
