ys = ys or {}

local ys = ys

ys.Battle.BattleBuffAirStrikeCoolDown = class("BattleBuffAirStrikeCoolDown", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffAirStrikeCoolDown.__name = "BattleBuffAirStrikeCoolDown"

local BattleBuffAirStrikeCoolDown = ys.Battle.BattleBuffAirStrikeCoolDown

function BattleBuffAirStrikeCoolDown.Ctor(self, effectData)
	BattleBuffAirStrikeCoolDown.super.Ctor(self, effectData)
end

function BattleBuffAirStrikeCoolDown.SetArgs(self, owner, buff)
	self._rant = self._tempData.arg_list.rant or 10000
end

function BattleBuffAirStrikeCoolDown.onTrigger(self, owner)
	BattleBuffAirStrikeCoolDown.super.onTrigger(self, owner, buff, attach)

	if ys.Battle.BattleFormulas.IsHappen(self._rant) then
		local airAssist = owner:GetAirAssistQueue():GetQueueHead()

		if airAssist then
			airAssist:QuickCoolDown()
		end
	end
end
