ys = ys or {}

local ys = ys
local BattleBuffAntiSubMine = class("BattleBuffAntiSubMine", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAntiSubMine = BattleBuffAntiSubMine
BattleBuffAntiSubMine.__name = "BattleBuffAntiSubMine"

function BattleBuffAntiSubMine.Ctor(self, effectData)
	BattleBuffAntiSubMine.super.Ctor(self, effectData)
end

function BattleBuffAntiSubMine.onAttach(self, owner)
	owner:InitOxygen()
	owner:ChangeOxygenState(ys.Battle.OxyState.STATE_DEEP_MINE)
end
