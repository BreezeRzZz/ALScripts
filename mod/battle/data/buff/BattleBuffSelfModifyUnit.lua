ys = ys or {}

local ys = ys
local BattleBuffEvent = ys.Battle.BattleBuffEvent
local BuffEffectType = ys.Battle.BattleConst.BuffEffectType
local BattleBuffSelfModifyUnit = class("BattleBuffSelfModifyUnit", ys.Battle.BattleBuffUnit)

ys.Battle.BattleBuffSelfModifyUnit = BattleBuffSelfModifyUnit
BattleBuffSelfModifyUnit.__name = "BattleBuffSelfModifyUnit"

-- 用来重载Template
-- BattleBuffDamageConvert有用到
function BattleBuffSelfModifyUnit.Ctor(self, buffID, level, caster, selfModifyTempData)
	self._selfModifyTempData = selfModifyTempData

	BattleBuffSelfModifyUnit.super.Ctor(self, buffID, level, caster, selfModifyTempData)
end

function BattleBuffSelfModifyUnit.SetTemplate(self)
	self._tempData = self._selfModifyTempData
end
