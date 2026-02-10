ys = ys or {}

local ys = ys
local BattleSkillPlaySFX = class("BattleSkillPlaySFX", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillPlaySFX = BattleSkillPlaySFX
BattleSkillPlaySFX.__name = "BattleSkillPlaySFX"

-- 此类SkillEffect用于播放音效
function BattleSkillPlaySFX.Ctor(self, arg_1_1, arg_1_2)
	BattleSkillPlaySFX.super.Ctor(self, arg_1_1, arg_1_2)

	self._SFXID = self._tempData.arg_list.sound_effect
end

function BattleSkillPlaySFX.DoDataEffect(self, arg_2_1, arg_2_2)
	self:playSound()
end

function BattleSkillPlaySFX.DoDataEffectWithoutTarget(self, arg_3_1)
	self:playSound()
end

function BattleSkillPlaySFX.playSound(self)
	ys.Battle.PlayBattleSFX(self._SFXID)
end
