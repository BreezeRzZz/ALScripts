ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleSkillPlayFX = class("BattleSkillPlayFX", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillPlayFX = BattleSkillPlayFX
BattleSkillPlayFX.__name = "BattleSkillPlayFX"

-- 此类SkillEffect在指定位置播放特效
function BattleSkillPlayFX.Ctor(self, template, level)
	BattleSkillPlayFX.super.Ctor(self, template, level)

	self._FXID = self._tempData.arg_list.effect
end

function BattleSkillPlayFX.DoDataEffect(self, caster, target)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster, target)

	ys.Battle.BattleDataProxy.GetInstance():SpawnEffect(self._FXID, corrdinate)
end

function BattleSkillPlayFX.DoDataEffectWithoutTarget(self, caster)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster)

	ys.Battle.BattleDataProxy.GetInstance():SpawnEffect(self._FXID, corrdinate)
end
