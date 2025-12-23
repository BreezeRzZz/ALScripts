ys = ys or {}

local ys = ys

ys.Battle.BattleBuffSize = class("BattleBuffSize", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffSize.__name = "BattleBuffSize"

local BattleBuffSize = ys.Battle.BattleBuffSize

function BattleBuffSize.Ctor(self, effectData)
	ys.Battle.BattleBuffSize.super.Ctor(self, effectData)
end

function BattleBuffSize.SetArgs(self, owner, buff)
	self._base = self._tempData.arg_list.number or 1
	self._hpScale = self._tempData.arg_list.hp_scale or 0
end

function BattleBuffSize.onHPRatioUpdate(self, owner, buff)
	self:doScale(owner)
end

function BattleBuffSize.onAttach(self, owner, buff)
	self:doScale(owner)
end

function BattleBuffSize.onRemove(self, owner, buff)
	local args = {
		size = initScale
	}

	owner:DispatchEvent(ys.Event.New(ys.Battle.BattleBuffEvent.BUFF_EFFECT_CHNAGE_SIZE, args))
end

function BattleBuffSize.doScale(self, owner)
	local currentHPRate = owner:GetHPRate()
	local size = self._base + currentHPRate * self._hpScale
	local args = {
		size = size
	}

	owner:DispatchEvent(ys.Event.New(ys.Battle.BattleBuffEvent.BUFF_EFFECT_CHNAGE_SIZE, args))
end
