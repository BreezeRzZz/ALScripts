ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleHammerHeadWeaponUnit = class("BattleHammerHeadWeaponUnit", ys.Battle.BattleWeaponUnit)
ys.Battle.BattleHammerHeadWeaponUnit.__name = "BattleHammerHeadWeaponUnit"

local BattleHammerHeadWeaponUnit = ys.Battle.BattleHammerHeadWeaponUnit

function BattleHammerHeadWeaponUnit.Ctor(self)
	BattleHammerHeadWeaponUnit.super.Ctor(self)
end
-- 自爆船攻击前排逻辑，相当于创建这么个武器
function BattleHammerHeadWeaponUnit.DoAttack(self, target)
	if self._tmpData.bullet_ID[1] then
		local bulletType = BattleDataFunction.GetBulletTmpDataFromID(self._tmpData.bullet_ID[1]).type

		if bulletType == BattleConst.BulletType.DIRECT or bulletType == BattleConst.BulletType.ANTI_AIR or bulletType == BattleConst.BulletType.ANTI_SEA then
			local directBullet = self:Spawn(self._tmpData.bullet_ID[1], target)

			directBullet:SetDirectHitUnit(target)
			self:DispatchBulletEvent(directBullet)
		else
			BattleHammerHeadWeaponUnit.super.DoAttack(self, target)
			self._host:HandleDamageToDeath()

			return
		end
	end

	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)
	self:TriggerBuffOnFire()
	self:CheckAndShake()
	self._host:HandleDamageToDeath()
end
