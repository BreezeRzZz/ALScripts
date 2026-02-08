ys = ys or {}

local ys = ys
local BattleBuffCancelBuff = class("BattleBuffCancelBuff", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffCancelBuff = BattleBuffCancelBuff
BattleBuffCancelBuff.__name = "BattleBuffCancelBuff"

-- 此BuffEffect会在条件满足(count不足，并在delay时间后)时取消自己(buff_id参数没用到过)
function BattleBuffCancelBuff.Ctor(self, effectData)
	BattleBuffCancelBuff.super.Ctor(self, effectData)
end

function BattleBuffCancelBuff.SetArgs(self, owner, buff)
	self._buff_id = self._tempData.arg_list.buff_id
	-- 如果不指定count，可以认为无效，永远无法触发取消
	self._count = self._tempData.arg_list.count or 99999
	self._delay = self._tempData.arg_list.delay
end

function BattleBuffCancelBuff.onTrigger(self, owner, buff, attach)
	BattleBuffCancelBuff.super.onTrigger(self, owner, buff, attach)

	self._count = self._count - 1

	if self._count <= 0 then
		buff:SetToCancel(self._delay)
	end
end
