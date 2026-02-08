ys = ys or {}

local ys = ys
local BattleBuffRegisterWaveFlags = class("BattleBuffRegisterWaveFlags", ys.Battle.BattleBuffEffect)

BattleBuffRegisterWaveFlags.__name = "BattleBuffRegisterWaveFlags"
ys.Battle.BattleBuffRegisterWaveFlags = BattleBuffRegisterWaveFlags

-- 此类BuffEffect用于注册WaveFlags到具体Dungeon中
-- 注册后，会对应多出新的wave
-- 使用例: 15/16图的空袭支援; (某些)EX图的装备检测来决定出现不同敌人等. 广泛使用
-- (此类BuffEffect不是给舰船用的. 只是随便以某个舰船为载体)
function BattleBuffRegisterWaveFlags.SetArgs(self, owner, buff)
	self._flags = self._tempData.arg_list.flags
end

function BattleBuffRegisterWaveFlags.onTrigger(self, owner, buff, args)
	BattleBuffRegisterWaveFlags.super.onTrigger(self, owner, buff, args)

	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()

	for _, flag in ipairs(self._flags) do
		battleDataProxy:AddWaveFlag(flag)
	end
end
