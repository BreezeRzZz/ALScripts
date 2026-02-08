ys = ys or {}

local ys = ys

ys.Battle.BattleBuffHealingCorrupt = class("BattleBuffHealingCorrupt", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffHealingCorrupt.__name = "BattleBuffHealingCorrupt"

local BattleBuffHealingCorrupt = ys.Battle.BattleBuffHealingCorrupt

BattleBuffHealingCorrupt.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_LINK

-- 此类BuffEffect会将受到的治疗转化为伤害，corruptRate参数控制转化比例，damageRate参数控制转化后伤害的倍率
-- 使用例: 大世界的毒奶Buff
function BattleBuffHealingCorrupt.Ctor(self, effectData)
	BattleBuffHealingCorrupt.super.Ctor(self, effectData)
end

function BattleBuffHealingCorrupt.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._corruptRate = arg_list.corruptRate or 1
	self._damageRate = arg_list.damageRate or 1
	self._proxy = ys.Battle.BattleDataProxy.GetInstance()
end

function BattleBuffHealingCorrupt.onTakeHealing(self, owner, buff, args)
	if args.incorrupt then
		return
	end
	-- 这里damage比较广义. 在这个场景下实际是治疗量
	local damage = args.damage
	local corruptedPart = math.ceil(damage * self._corruptRate)

	args.damage = damage - corruptedPart

	local corruptedDamage = math.ceil(corruptedPart * self._damageRate)

	self._proxy:HandleDirectDamage(owner, corruptedDamage)
end
