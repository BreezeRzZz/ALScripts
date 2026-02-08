ys = ys or {}

local ys = ys

ys.Battle.BattleBuffLockHealth = class("BattleBuffLockHealth", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffLockHealth.__name = "BattleBuffLockHealth"

local BattleBuffLockHealth = ys.Battle.BattleBuffLockHealth

-- 此类BuffEffect用于锁血, 即当单位HP低于某个阈值时, 受到的伤害不会再降低HP, 但仍会触发受击等相关逻辑. rate参数控制锁血阈值占最大HP的比例(优先), value参数控制锁血阈值的固定数值
-- 使用例: 敌人的锁血, 例如偶像大师EX BOSS的锁血
function BattleBuffLockHealth.Ctor(self, effectData)
	BattleBuffLockHealth.super.Ctor(self, effectData)
end

function BattleBuffLockHealth.SetArgs(self, owner, buff)
	self._rate = self._tempData.arg_list.rate
	self._threshold = self._tempData.arg_list.value
end

function BattleBuffLockHealth.onAttach(self, owner, buff)
	if self._rate then
		self._threshold = math.floor(owner:GetMaxHP() * self._rate)
	end
end

function BattleBuffLockHealth.onTrigger(self, owner, buff, args)
	local currentHP = owner:GetCurrentHP()

	if currentHP <= self._threshold then
		args.damage = 0
	elseif currentHP - args.damage < self._threshold then
		args.damage = currentHP - self._threshold
	end
end
