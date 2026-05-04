ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleElectricArcBulletFactory = singletonClass("BattleElectricArcBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleElectricArcBulletFactory.__name = "BattleElectricArcBulletFactory"

local BattleElectricArcBulletFactory = ys.Battle.BattleElectricArcBulletFactory

function BattleElectricArcBulletFactory.Ctor(self)
	BattleElectricArcBulletFactory.super.Ctor(self)
end

--- 创建电弧子弹（直接命中 + 电弧连线特效）
--- 电弧子弹是一种特殊的直击子弹，除了在目标身上播放命中特效和结算伤害外，
--- 还会在发射者（Host）和目标之间创建电弧连线特效
---
--- 视觉表现：
--- 1. 发射特效（PlayFireFX）
--- 2. 目标命中特效（hit_fx）
--- 3. 电弧连线特效（AddArcEffect）：从Host连接到目标，使用子弹模板的modle_ID作为连线材质
---    spawn_bound参数控制连线的边界起始位置
--- @param tf Transform 发射Transform
--- @param bullet BattleBulletUnit 子弹数据
--- @param spawnPos Vector3 生成位置
--- @param fireFXID string 发射特效ID
--- @param dir BattleConst.UnitDir 方向
function BattleElectricArcBulletFactory.CreateBullet(self, tf, bullet, spawnPos, fireFXID, dir)
	self:PlayFireFX(tf, bullet, spawnPos, fireFXID, dir, nil)

	local directHitUnit = bullet:GetDirectHitUnit()

	if directHitUnit == nil then
		return
	end

	local targetUID = directHitUnit:GetUniqueID()
	local unitType = directHitUnit:GetUnitType()
	local targetUnit

	if table.contains(AircraftUnitType, unitType) then
		targetUnit = BattleElectricArcBulletFactory.GetSceneMediator():GetAircraft(targetUID)
	elseif table.contains(CharacterUnitType, unitType) then
		targetUnit = BattleElectricArcBulletFactory.GetSceneMediator():GetCharacter(targetUID)
	end

	if targetUnit then
		-- 目标命中特效和伤害
		targetUnit:AddFX(bullet:GetTemplate().hit_fx)
		self:GetDataProxy():HandleDamage(bullet, directHitUnit)

		-- 创建电弧连线：从Host（发射者）连到目标
		local host = bullet:GetWeapon():GetHost()

		if host then
			local spawnBound = bullet:GetWeapon():GetTemplateData().spawn_bound
			local hostCharacter = self:GetSceneMediator():GetCharacter(host:GetUniqueID())

			-- modle_ID 用作电弧的连线材质/特效ID
			self:GetSceneMediator():AddArcEffect(bullet:GetTemplate().modle_ID, hostCharacter, directHitUnit, spawnBound)
		end
	end
end
