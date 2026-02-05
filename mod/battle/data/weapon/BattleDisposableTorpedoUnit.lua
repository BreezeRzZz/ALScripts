ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleManualTorpedoUnit = class("BattleDisposableTorpedoUnit", ys.Battle.BattleManualTorpedoUnit)

ys.Battle.BattleDisposableTorpedoUnit = BattleManualTorpedoUnit
BattleManualTorpedoUnit.__name = "BattleDisposableTorpedoUnit"

function BattleManualTorpedoUnit.Ctor(self)
	BattleManualTorpedoUnit.super.Ctor(self)
end

function BattleManualTorpedoUnit.EnterCoolDown(self)
	return
end

function BattleManualTorpedoUnit.Fire(self)
	BattleManualTorpedoUnit.super.Fire(self)
	self._playerTorpedoVO:Deduct(self)
	self._playerTorpedoVO:DispatchOverLoadChange()

	return true
end

function BattleManualTorpedoUnit.OverHeat(self)
	self._currentState = self.STATE_OVER_HEAT
end

function BattleManualTorpedoUnit.GetType(self)
	return ys.Battle.BattleConst.EquipmentType.DISPOSABLE_TORPEDO
end

function BattleManualTorpedoUnit.createMajorEmitter(self, barrageID, index, emitterType, spawnFunc, stopFunc)
	-- barrageID = 1 -> 对应1hit
	return BattleManualTorpedoUnit.super.createMajorEmitter(self, 1, index, emitterType, spawnFunc, stopFunc)
end
