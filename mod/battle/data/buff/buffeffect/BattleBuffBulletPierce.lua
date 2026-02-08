ys = ys or {}

local ys = ys

ys.Battle.BattleBuffBulletPierce = class("BattleBuffBulletPierce", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffBulletPierce.__name = "BattleBuffBulletPierce"

-- 此BuffEffect设置子弹的可穿透次数
-- 但目前没有使用过
function ys.Battle.BattleBuffBulletPierce.Ctor(self, effectData)
	ys.Battle.BattleBuffBulletPierce.super.Ctor(self, effectData)
end

function ys.Battle.BattleBuffBulletPierce.SetArgs(self, owner, buff)
	self._number = self._tempData.arg_list.number
	self._rate = self._tempData.arg_list.rate
	self._bulletType = self._tempData.arg_list.bulletType or 0
end

function ys.Battle.BattleBuffBulletPierce.onBulletCreate(self, owner, buff, args)
	local bullet = args._bullet

	if self:IsHappen(tonumber(self._rate)) and (self._bulletType == bullet._tempData.type or self._bulletType == 0) then
		bullet._pierceCount = self._number
	end
end
