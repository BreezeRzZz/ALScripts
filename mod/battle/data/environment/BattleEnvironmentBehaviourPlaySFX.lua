ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourPlaySFX = class("BattleEnvironmentBehaviourPlaySFX", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourPlaySFX = BattleEnvironmentBehaviourPlaySFX
BattleEnvironmentBehaviourPlaySFX.__name = "BattleEnvironmentBehaviourPlaySFX"

--- @class BattleEnvironmentBehaviourPlaySFX : BattleEnvironmentBehaviour
--- 环境音效行为：播放战斗音效
function BattleEnvironmentBehaviourPlaySFX.Ctor(self)
	BattleEnvironmentBehaviourPlaySFX.super.Ctor(self)
end

--- 读取SFX_ID
--- @param tmpData table
function BattleEnvironmentBehaviourPlaySFX.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourPlaySFX.super.SetTemplate(self, tmpData)

	self._sfx = self._tmpData.SFX_ID
end

--- 播放指定战斗音效
function BattleEnvironmentBehaviourPlaySFX.doBehaviour(self)
	ys.Battle.PlayBattleSFX(self._sfx)
	BattleEnvironmentBehaviourPlaySFX.super.doBehaviour(self)
end
