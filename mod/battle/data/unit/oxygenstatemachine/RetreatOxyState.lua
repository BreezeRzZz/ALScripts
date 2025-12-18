ys = ys or {}

local var_0_0 = ys
local var_0_1 = var_0_0.Battle.BattleConst
local BattleAttr = var_0_0.Battle.BattleAttr

var_0_0.Battle.RetreatOxyState = class("RetreatOxyState", var_0_0.Battle.IOxyState)
var_0_0.Battle.RetreatOxyState.__name = "RetreatOxyState"

local var_0_3 = var_0_0.Battle.RetreatOxyState

function var_0_3.Ctor(arg_1_0)
	var_0_3.super.Ctor(arg_1_0)
end

function var_0_3.GetWeaponUseableList(arg_2_0)
	return {}
end

function var_0_3.UpdateCldData(self, target, originalState)
	local orginalDiveState = originalState:GetDiveState()
	local currentDiveState = self:GetDiveState()

	target:GetCldData().Surface = currentDiveState

	if orginalDiveState ~= currentDiveState then
		BattleAttr.UnitCldEnable(target)
	end
end

function var_0_3.GetDiveState(arg_4_0)
	return var_0_1.OXY_STATE.FLOAT
end

function var_0_3.GetBubbleFlag(arg_5_0)
	return false
end

function var_0_3.IsVisible(arg_6_0)
	return true
end

function var_0_3.GetBarVisible(arg_7_0)
	return false
end

function var_0_3.RunMode(arg_8_0)
	return false
end
