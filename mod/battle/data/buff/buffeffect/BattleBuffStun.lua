ys = ys or {}

local ys = ys

ys.Battle.BattleBuffStun = class("BattleBuffStun", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffStun.__name = "BattleBuffStun"

local BattleBuffStun = ys.Battle.BattleBuffStun

-- 此类BuffEffect的作用是使目标进入眩晕/停滞状态，无法移动
-- 使用例: 各种定身效果, 如冤仇的定身
function BattleBuffStun.Ctor(self, effectData)
	BattleBuffStun.super.Ctor(self, effectData)
end

function BattleBuffStun.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list
end

function BattleBuffStun.onAttach(self, owner, buff)
	self:onTrigger(owner, buff)
end

function BattleBuffStun.onUpdate(self, owner, buff)
	self:onTrigger(owner, buff)
end

function BattleBuffStun.onTrigger(self, owner, buff)
	BattleBuffStun.super.onTrigger(self, owner, buff)
	ys.Battle.BattleAttr.Stun(owner)
	owner:UpdateMoveLimit()
end

function BattleBuffStun.onRemove(self, owner, buff)
	ys.Battle.BattleAttr.CancelStun(owner)
	owner:UpdateMoveLimit()
end
