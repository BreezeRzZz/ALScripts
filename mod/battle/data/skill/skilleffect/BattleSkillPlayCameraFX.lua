ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleSkillPlayCameraFX = class("BattleSkillPlayCameraFX", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillPlayCameraFX = BattleSkillPlayCameraFX
BattleSkillPlayCameraFX.__name = "BattleSkillPlayCameraFX"

-- 此类SkillEffect为镜头效果
function BattleSkillPlayCameraFX.Ctor(self, template, level)
	BattleSkillPlayCameraFX.super.Ctor(self, template, level)

	self._FXID = self._tempData.arg_list.effect
	self._scale = self._tempData.arg_list.scale
	self._order = self._tempData.arg_list.order
end

function BattleSkillPlayCameraFX.DoDataEffect(self, caster, target)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster, target)

	ys.Battle.BattleDataProxy.GetInstance():SpawnCameraFX(self._FXID, corrdinate, self._scale, self._order)
end

function BattleSkillPlayCameraFX.DoDataEffectWithoutTarget(self, caster)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster)

	ys.Battle.BattleDataProxy.GetInstance():SpawnCameraFX(self._FXID, corrdinate, self._scale, self._order)
end
