ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local UnitState = ys.Battle.UnitState
local BattleEnemyUnit = class("BattleEnemyUnit", ys.Battle.BattleUnit)

ys.Battle.BattleEnemyUnit = BattleEnemyUnit
BattleEnemyUnit.__name = "BattleEnemyUnit"

function BattleEnemyUnit.Ctor(arg_1_0, arg_1_1, arg_1_2)
	BattleEnemyUnit.super.Ctor(arg_1_0, arg_1_1, arg_1_2)

	arg_1_0._type = BattleConst.UnitType.ENEMY_UNIT
	arg_1_0._level = arg_1_0._battleProxy:GetDungeonLevel()
end

function BattleEnemyUnit.Dispose(arg_2_0)
	if arg_2_0._aimBias then
		arg_2_0._aimBias:Dispose()
	end

	BattleEnemyUnit.super.Dispose(arg_2_0)
end

function BattleEnemyUnit.SetBound(arg_3_0, arg_3_1, arg_3_2, arg_3_3, arg_3_4, arg_3_5, arg_3_6)
	BattleEnemyUnit.super.SetBound(arg_3_0, arg_3_1, arg_3_2, arg_3_3, arg_3_4, arg_3_5, arg_3_6)

	arg_3_0._weaponRightBound = arg_3_4
	arg_3_0._weaponLowerBound = arg_3_2
end

function BattleEnemyUnit.UpdateAction(arg_4_0)
	if arg_4_0._oxyState and arg_4_0._oxyState:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
		if arg_4_0:GetSpeed().x > 0 then
			arg_4_0._unitState:ChangeState(UnitState.STATE_DIVELEFT)
		else
			arg_4_0._unitState:ChangeState(UnitState.STATE_DIVE)
		end
	elseif arg_4_0:GetSpeed().x > 0 then
		arg_4_0._unitState:ChangeState(UnitState.STATE_MOVELEFT)
	else
		arg_4_0._unitState:ChangeState(UnitState.STATE_MOVE)
	end
end

function BattleEnemyUnit.UpdateHP(arg_5_0, arg_5_1, arg_5_2, arg_5_3, arg_5_4)
	local var_5_0 = BattleEnemyUnit.super.UpdateHP(arg_5_0, arg_5_1, arg_5_2, arg_5_3, arg_5_4)

	if arg_5_0._phaseSwitcher then
		arg_5_0._phaseSwitcher:UpdateHP(arg_5_0:GetHPRate())
	end

	return var_5_0
end

function BattleEnemyUnit.SetMaster(arg_6_0, arg_6_1)
	arg_6_0._master = arg_6_1
end

function BattleEnemyUnit.GetMaster(arg_7_0)
	return arg_7_0._master
end

function BattleEnemyUnit.SetTemplate(arg_8_0, arg_8_1, arg_8_2)
	BattleEnemyUnit.super.SetTemplate(arg_8_0, arg_8_1)

	arg_8_0._tmpData = BattleDataFunction.GetMonsterTmpDataFromID(arg_8_0._tmpID)

	arg_8_0:configWeaponQueueParallel()
	arg_8_0:InitCldComponent()
	arg_8_0:SetAttr()

	arg_8_2 = arg_8_2 or {}

	local var_8_0 = arg_8_0:GetExtraInfo()

	for iter_8_0, iter_8_1 in pairs(arg_8_2) do
		var_8_0[iter_8_0] = iter_8_1
	end

	arg_8_0:setStandardLabelTag()
end

function BattleEnemyUnit.SetTeamVO(arg_9_0, arg_9_1)
	arg_9_0._team = arg_9_1
end

function BattleEnemyUnit.SetFormationIndex(arg_10_0, arg_10_1)
	arg_10_0._formationIndex = arg_10_1
end

function BattleEnemyUnit.SetWaveIndex(arg_11_0, arg_11_1)
	arg_11_0._waveIndex = arg_11_1
end

function BattleEnemyUnit.SetAttr(arg_12_0)
	BattleAttr.SetEnemyAttr(arg_12_0)
	BattleAttr.InitDOTAttr(arg_12_0._attr, arg_12_0._tmpData)
end

function BattleEnemyUnit.GetTemplate(arg_13_0)
	return arg_13_0._tmpData
end

function BattleEnemyUnit.GetRarity(arg_14_0)
	return arg_14_0._tmpData.rarity
end

function BattleEnemyUnit.GetLevel(arg_15_0)
	return arg_15_0._overrideLevel or arg_15_0._level or 1
end

function BattleEnemyUnit.GetTeam(arg_16_0)
	return arg_16_0._team
end

function BattleEnemyUnit.GetWaveIndex(arg_17_0)
	return arg_17_0._waveIndex
end

function BattleEnemyUnit.IsShowHPBar(arg_18_0)
	return arg_18_0._IFF ~= BattleConfig.FRIENDLY_CODE
end

function BattleEnemyUnit.IsSpectre(self)
	local battleUnitType
	local battleUnitTypeAttrKey = ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY

	if self:GetAttr()[battleUnitTypeAttrKey] ~= nil then
		battleUnitType = self:GetAttrByName(battleUnitTypeAttrKey)
	else
		battleUnitType = self._tmpData.battle_unit_type
	end

	return battleUnitType <= BattleConfig.SPECTRE_UNIT_TYPE, battleUnitType
end

function BattleEnemyUnit.InitCldComponent(arg_20_0)
	BattleEnemyUnit.super.InitCldComponent(arg_20_0)

	local var_20_0 = {
		type = BattleConst.CldType.SHIP,
		IFF = arg_20_0:GetIFF(),
		UID = arg_20_0:GetUniqueID(),
		Mass = BattleConst.CldMass.L1,
		IsBoss = arg_20_0._isBoss
	}

	arg_20_0._cldComponent:SetCldData(var_20_0)

	if arg_20_0:GetTemplate().friendly_cld ~= 0 then
		arg_20_0._cldComponent:ActiveFriendlyCld()
	end
end

function BattleEnemyUnit.ConfigBubbleFX(arg_21_0)
	arg_21_0._bubbleFX = arg_21_0._tmpData.bubble_fx[1]

	arg_21_0._oxyState:SetBubbleTemplate(arg_21_0._tmpData.bubble_fx[2], arg_21_0._tmpData.bubble_fx[3])
end
