ys = ys or {}

local ys = ys
local BattleSkillPlaySFX = class("BattleSkillPlaySFX", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillPlaySFX = BattleSkillPlaySFX
BattleSkillPlaySFX.__name = "BattleSkillPlaySFX"

-- 此类SkillEffect用于播放音效
--- @param tempData table: 技能效果模板数据
--- @param level number: 技能等级
function BattleSkillPlaySFX.Ctor(self, tempData, level)
	BattleSkillPlaySFX.super.Ctor(self, tempData, level)

	self._SFXID = self._tempData.arg_list.sound_effect
end

--- 播放音效（有目标时）
--- @param caster BattleUnit: 施法者
--- @param target BattleUnit: 目标
function BattleSkillPlaySFX.DoDataEffect(self, caster, target)
	self:playSound()
end

--- 播放音效（无目标时）
--- @param caster BattleUnit: 施法者
function BattleSkillPlaySFX.DoDataEffectWithoutTarget(self, caster)
	self:playSound()
end

--- 实际播放音效
function BattleSkillPlaySFX.playSound(self)
	ys.Battle.PlayBattleSFX(self._SFXID)
end
