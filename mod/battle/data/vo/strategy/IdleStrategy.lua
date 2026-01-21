ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.IdleStrategy = class("IdleStrategy", ys.Battle.BattleJoyStickBotBaseStrategy)

local IdleStrategy = ys.Battle.IdleStrategy

IdleStrategy.__name = "IdleStrategy"

function IdleStrategy.Ctor(self, fleetVO)
	IdleStrategy.super.Ctor(self, fleetVO)
end

function IdleStrategy.GetStrategyType(self)
	return ys.Battle.BattleJoyStickAutoBot.IDLE
end

function IdleStrategy.analysis(self)
	self._hrz = 0
	self._vtc = 0
end
