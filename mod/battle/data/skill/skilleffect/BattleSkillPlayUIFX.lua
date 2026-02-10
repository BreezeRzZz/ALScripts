ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleSkillPlayUIFX = class("BattleSkillPlayUIFX", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillPlayUIFX = BattleSkillPlayUIFX
BattleSkillPlayUIFX.__name = "BattleSkillPlayUIFX"

-- 此类SkillEffect用于播放UI特效
function BattleSkillPlayUIFX.Ctor(self, template, level)
	BattleSkillPlayUIFX.super.Ctor(self, template, level)

	self._FXID = self._tempData.arg_list.effect
	self._scale = self._tempData.arg_list.scale
	self._order = self._tempData.arg_list.order
end

function BattleSkillPlayUIFX.DoDataEffect(self, caster, target)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster, target)

	ys.Battle.BattleDataProxy.GetInstance():SpawnUIFX(self._FXID, corrdinate, self._scale, self._order)
end

function BattleSkillPlayUIFX.DoDataEffectWithoutTarget(self, caster)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster)

	ys.Battle.BattleDataProxy.GetInstance():SpawnUIFX(self._FXID, corrdinate, self._scale, self._order)
end
