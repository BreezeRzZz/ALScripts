ys = ys or {}

local ys = ys

ys.Battle.BattleTorpedoUnit = class("BattleTorpedoUnit", ys.Battle.BattleWeaponUnit)
ys.Battle.BattleTorpedoUnit.__name = "BattleTorpedoUnit"

local BattleTorpedoUnit = ys.Battle.BattleTorpedoUnit

function BattleTorpedoUnit.Ctor(self)
	ys.Battle.BattleTorpedoUnit.super.Ctor(self)
end

function BattleTorpedoUnit.TriggerBuffOnFire(self)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_TORPEDO_FIRE, {
		equipIndex = self._equipmentIndex
	})
end

function BattleTorpedoUnit.EnterCoolDown(self)
	if self._isSupportWeapon then
		self._currentState = self.STATE_DISABLE
	else
		BattleTorpedoUnit.super.EnterCoolDown(self)
	end
end

function BattleTorpedoUnit.TriggerBuffWhenSpawn(self, bullet)
	local bulletCreateArgs = {
		_bullet = bullet,
		equipIndex = self._equipmentIndex,
		bulletTag = bullet:GetExtraTag()
	}
	-- 鱼雷子弹也会触发"普通子弹创建"的BuffEffect
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_CREATE, bulletCreateArgs)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_TORPEDO_BULLET_CREATE, bulletCreateArgs)
end
