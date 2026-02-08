ys = ys or {}

local ys = ys

ys.Battle.BattleBuffLink = class("BattleBuffLink", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffLink.__name = "BattleBuffLink"

-- 这类BuffEffect的作用是为目标单位的Buff触发提供一个链接, 也即当满足条件时, 该BuffEffect会让目标单位的指定Buff触发
-- 目前只有Buff 60026使用(可能废弃)
function ys.Battle.BattleBuffLink.Ctor(self, effectData)
	ys.Battle.BattleBuffLink.super.Ctor(self, effectData)
end

function ys.Battle.BattleBuffLink.SetArgs(self, owner, buff)
	self._target = self._tempData.arg_list.target
	self._buff_id = self._tempData.arg_list.buff_id
end

function ys.Battle.BattleBuffLink.Trigger(self, effectType, owner, buff, args)
	local targetList = self:getTargetList(owner, self._target, self._tempData.arg_list)

	if targetList then
		for _, target in ipairs(targetList) do
			local buff = target:GetBuff(self._buff_id)

			if buff then
				buff:onTrigger(effectType, target, args)
			end
		end
	end
end
