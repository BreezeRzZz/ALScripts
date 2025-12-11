ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local UnitState = ys.Battle.UnitState
local BattleMinionUnit = class("BattleMinionUnit", ys.Battle.BattleEnemyUnit)
-- Minion继承的是Enemy，但己方的Minion也是用这个类
-- 因此不能靠Enemy的逻辑来区分友方和敌方，必须用IFF来区分
ys.Battle.BattleMinionUnit = BattleMinionUnit
BattleMinionUnit.__name = "BattleMinionUnit"

function BattleMinionUnit.Ctor(self, uid, iff)
	BattleMinionUnit.super.Ctor(self, uid, iff)
end

function BattleMinionUnit.GetUnitType(self)
	return BattleConst.UnitType.MINION_UNIT
end

function BattleMinionUnit.SetMaster(self, master)
	self._master = master
end

function BattleMinionUnit.InheritMasterAttr(self)
	BattleAttr.SetMinionAttr(self)
	BattleAttr.InitDOTAttr(self._attr, self._tmpData)
	self:setStandardLabelTag()
end

function BattleMinionUnit.SetTemplate(self, templateID, templateData)
	self._tmpID = templateID
	self._tmpData = BattleDataFunction.GetMonsterTmpDataFromID(self._tmpID)

	self:configWeaponQueueParallel()
	self:InitCldComponent()
end

function BattleMinionUnit.IsShowHPBar(self)
	return false
end

function BattleMinionUnit.GetMaster(self)
	return self._master
end

function BattleMinionUnit.DispatchVoice(self)
	return
end

function BattleMinionUnit.Retreat(self)
	BattleMinionUnit.super.Retreat(self)
	self:SetDeathReason(BattleConst.UnitDeathReason.LEAVE)
	self:DeacActionClear()
	self._battleProxy:KillUnit(self:GetUniqueID())
end
