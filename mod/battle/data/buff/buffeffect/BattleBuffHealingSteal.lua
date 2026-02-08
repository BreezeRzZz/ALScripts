ys = ys or {}

local ys = ys

ys.Battle.BattleBuffHealingSteal = class("BattleBuffHealingSteal", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffHealingSteal.__name = "BattleBuffHealingSteal"

local BattleBuffHealingSteal = ys.Battle.BattleBuffHealingSteal

BattleBuffHealingSteal.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_LINK

-- 此类BuffEffect会在我方舰队受到治疗时偷窃治疗的一部分转化为对自身的治疗，stealRate参数控制偷窃比例，absorbRate参数控制转化为自身治疗的比例
-- 使用例: 大世界的恢复转移Buff
function BattleBuffHealingSteal.Ctor(self, effectData)
	BattleBuffHealingSteal.super.Ctor(self, effectData)
end

function BattleBuffHealingSteal.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._stealRate = arg_list.stealingRate or 1
	self._absorbRate = arg_list.arsorbRate or 1
end

function BattleBuffHealingSteal.onTakeHealing(self, owner, buff, args)
	-- 这里damage比较广义. 在这个场景下实际是治疗量
	local damage = args.damage
	local caster = buff:GetCaster()

	if caster and caster:IsAlive() and caster ~= owner then
		local stealPart = math.ceil(damage * self._stealRate)
		-- 受到治疗量减少被偷窃的部分
		args.damage = damage - stealPart

		local healingRate = caster:GetAttrByName("healingRate")
		-- 偷窃部分乘以吸收率转化为自身治疗量
		local absorbPart = stealPart * self._absorbRate
		local dHP = math.ceil(healingRate * absorbPart)
		local extraInfo = {
			isMiss = false,
			isCri = false,
			isHeal = true,
			isShare = false
		}

		caster:UpdateHP(dHP, extraInfo)
	end
end
