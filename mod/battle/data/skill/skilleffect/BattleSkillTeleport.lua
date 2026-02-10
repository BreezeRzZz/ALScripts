ys = ys or {}

local ys = ys
local BattleSkillTeleport = class("BattleSkillTeleport", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillTeleport = BattleSkillTeleport
BattleSkillTeleport.__name = "BattleSkillTeleport"

-- 此类SkillEffect的作用是将单位传送到指定位置
function BattleSkillTeleport.Ctor(self, template, level)
	BattleSkillTeleport.super.Ctor(self, template, level)
end

function BattleSkillTeleport.DoDataEffect(self, caster, target)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster, target)

	caster:SetPosition(corrdinate)
end

function BattleSkillTeleport.DoDataEffectWithoutTarget(self, caster)
	local corrdinate = self.calcCorrdinate(self._tempData.arg_list, caster)

	caster:SetPosition(corrdinate)
end
