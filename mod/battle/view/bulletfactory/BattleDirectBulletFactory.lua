ys = ys or {}

local ys = ys
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleDirectBulletFactory = singletonClass("BattleDirectBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleDirectBulletFactory.__name = "BattleDirectBulletFactory"

local BattleDirectBulletFactory = ys.Battle.BattleDirectBulletFactory

function BattleDirectBulletFactory.Ctor(self)
	BattleDirectBulletFactory.super.Ctor(self)
end

--- 创建直击子弹（无弹道飞行过程，直接命中目标）
--- 与普通炮弹不同，直击子弹没有MakeBullet/MakeModel过程
--- 直接播放发射特效、在目标身上播放命中特效、造成伤害
---
--- 视觉表现：仅在目标身上显示命中特效（hit_fx），无飞行弹道
--- @param tf Transform 发射Transform
--- @param bullet BattleBulletUnit 子弹数据
--- @param spawnPos Vector3 生成位置
--- @param fireFXID string 发射特效ID
--- @param dir BattleConst.UnitDir 方向
function BattleDirectBulletFactory.CreateBullet(self, tf, bullet, spawnPos, fireFXID, dir)
	self:PlayFireFX(tf, bullet, spawnPos, fireFXID, dir, nil)

	local directHitUnit = bullet:GetDirectHitUnit()

	if directHitUnit == nil then
		return
	end

	local targetUID = directHitUnit:GetUniqueID()
	local unitType = directHitUnit:GetUnitType()
	local targetUnit

	if table.contains(AircraftUnitType, unitType) then
		targetUnit = BattleDirectBulletFactory.GetSceneMediator():GetAircraft(targetUID)
	elseif table.contains(CharacterUnitType, unitType) then
		targetUnit = BattleDirectBulletFactory.GetSceneMediator():GetCharacter(targetUID)
	end

	if targetUnit then
		-- 在目标身上播放命中特效并结算伤害
		targetUnit:AddFX(bullet:GetTemplate().hit_fx)
		self:GetDataProxy():HandleDamage(bullet, directHitUnit)
	end
end
