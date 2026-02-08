ys = ys or {}

local ys = ys

ys.Battle.BattleBuffBulletHitEmitter = class("BattleBuffBulletHitEmitter", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffBulletHitEmitter.__name = "BattleBuffBulletHitEmitter"

-- 这是一个已废弃的BuffEffect，原本是用来实现子弹弹射功能的，但现在这个功能已经被屏蔽了，所以这个BuffEffect也就没什么意义了
function ys.Battle.BattleBuffBulletHitEmitter.Ctor(self, effectData)
	ys.Battle.BattleBuffBulletHitEmitter.super.Ctor(self, effectData)
end

function ys.Battle.BattleBuffBulletHitEmitter.SetArgs(self, owner, buff)
	self._number = self._tempData.arg_list.number
	self._rate = self._tempData.arg_list.rate or 10000
	self._hitEmitterArgs = self._tempData.arg_list
end

function ys.Battle.BattleBuffBulletHitEmitter.onBulletCreate(self, owner, buff, args)
	local bullet = args._bullet

	if ys.Battle.BattleFormulas.IsHappen(self._rate) then
		assert(false, "子弹弹射功能已经屏蔽")
	end
end
