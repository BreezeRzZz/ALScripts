ys = ys or {}

local ys = ys

ys.Battle.BattleBuffManualTorpedoCoolDown = class("BattleBuffManualTorpedoCoolDown", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffManualTorpedoCoolDown.__name = "BattleBuffManualTorpedoCoolDown"

-- 此类BuffEffect按概率, 瞬间完成(队列头)手动鱼雷的冷却
-- 算是"快速起飞"的一个鱼雷版本. 但目前没有使用例
local BattleBuffManualTorpedoCoolDown = ys.Battle.BattleBuffManualTorpedoCoolDown

function BattleBuffManualTorpedoCoolDown.Ctor(self, effectData)
	BattleBuffManualTorpedoCoolDown.super.Ctor(self, effectData)
end

function BattleBuffManualTorpedoCoolDown.SetArgs(self, owner, buff)
	self._rant = self._tempData.arg_list.rant or 10000
end

function BattleBuffManualTorpedoCoolDown.onTrigger(self, owner)
	BattleBuffManualTorpedoCoolDown.super.onTrigger(self, owner, buff, attach)

	if ys.Battle.BattleFormulas.IsHappen(self._rant) then
		local manualTorpedo = owner:GetTorpedoQueue():GetQueueHead()

		if manualTorpedo then
			manualTorpedo:QuickCoolDown()
		end
	end
end
