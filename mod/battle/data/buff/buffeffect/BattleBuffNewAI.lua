ys = ys or {}

local ys = ys

ys.Battle.BattleBuffNewAI = class("BattleBuffNewAI", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffNewAI.__name = "BattleBuffNewAI"

-- 此类BuffEffect在Buff附加和移除时更改Unit的AI
function ys.Battle.BattleBuffNewAI.Ctor(self, effectData)
	ys.Battle.BattleBuffNewAI.super.Ctor(self, effectData)
end

function ys.Battle.BattleBuffNewAI.SetArgs(self, owner, buff)
	self._AIOnAttach = self._tempData.arg_list.ai_onAttach
	self._AIOnRemove = self._tempData.arg_list.ai_onRemove
end

function ys.Battle.BattleBuffNewAI.onAttach(self, owner, buff)
	if self._AIOnAttach then
		owner:SetAI(self._AIOnAttach)
	end
end

function ys.Battle.BattleBuffNewAI.onRemove(self, owner, buff)
	if self._AIOnRemove then
		owner:SetAI(self._AIOnRemove)
	end
end
