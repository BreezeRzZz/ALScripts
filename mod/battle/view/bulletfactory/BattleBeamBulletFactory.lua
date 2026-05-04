ys = ys or {}

local ys = ys
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleBeamBulletFactory = singletonClass("BattleBeamBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleBeamBulletFactory.__name = "BattleBeamBulletFactory"

local BattleBeamBulletFactory = ys.Battle.BattleBeamBulletFactory

function BattleBeamBulletFactory.Ctor(self)
	BattleBeamBulletFactory.super.Ctor(self)
end

--- 创建光束子弹（类似直击子弹，无飞行过程）
--- 光束子弹直接命中目标，在目标身上显示命中特效并结算伤害
--- 与DirectBullet类似，不创建飞行模型，仅在目标上播放hit_fx
---
--- 视觉表现：无弹道，目标身上闪现命中特效
--- @param tf Transform
--- @param bullet BattleBulletUnit
--- @param spawnPos Vector3
--- @param fireFXID string
--- @param dir BattleConst.UnitDir
function BattleBeamBulletFactory.CreateBullet(self, tf, bullet, spawnPos, fireFXID, dir)
	local directHitUnit = bullet:GetDirectHitUnit()

	if directHitUnit == nil then
		return
	end

	local targetUID = directHitUnit:GetUniqueID()
	local unitType = directHitUnit:GetUnitType()
	local targetUnit

	if table.contains(AircraftUnitType, unitType) then
		targetUnit = BattleBeamBulletFactory.GetSceneMediator():GetAircraft(targetUID)
	elseif table.contains(CharacterUnitType, unitType) then
		targetUnit = BattleBeamBulletFactory.GetSceneMediator():GetCharacter(targetUID)
	end

	if targetUnit then
		targetUnit:AddFX(bullet:GetTemplate().hit_fx)
		self:GetDataProxy():HandleDamage(bullet, directHitUnit)
	end
end
