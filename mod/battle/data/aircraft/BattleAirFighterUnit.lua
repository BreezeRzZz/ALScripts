ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleAirFighterUnit = class("BattleAirFighterUnit", ys.Battle.BattleAircraftUnit)
ys.Battle.BattleAirFighterUnit.__name = "BattleAirFighterUnit"

local BattleAirFighterUnit = ys.Battle.BattleAirFighterUnit

BattleAirFighterUnit.AIRFIGHTER_ENTER_POINT = Vector3(Screen.width * -0.5, Screen.height * 0.5, 15)
BattleAirFighterUnit.SPEED_FLY = Vector3(3, 0, 0)
BattleAirFighterUnit.BACK_X = 100
BattleAirFighterUnit.DOWN_X = 30
BattleAirFighterUnit.ATTACK_X = -23
BattleAirFighterUnit.UP_X = -70
BattleAirFighterUnit.FREE_X = -75
BattleAirFighterUnit.HEIGHT = ys.Battle.BattleConfig.AirFighterHeight
BattleAirFighterUnit.STRIKE_STATE_FLY = 0
BattleAirFighterUnit.STRIKE_STATE_BACK = 1
BattleAirFighterUnit.STRIKE_STATE_DOWN = 2
BattleAirFighterUnit.STRIKE_STATE_ATTACK = 3
BattleAirFighterUnit.STRIKE_STATE_UP = 4
BattleAirFighterUnit.STRIKE_STATE_FREE = 5
BattleAirFighterUnit.STRIKE_STATE_BACKWARD = 6
BattleAirFighterUnit.STRIKE_STATE_RECYCLE = 7

function BattleAirFighterUnit.Ctor(arg_1_0, arg_1_1)
	BattleAirFighterUnit.super.Ctor(arg_1_0, arg_1_1)

	arg_1_0._dir = ys.Battle.BattleConst.UnitDir.LEFT
	arg_1_0._type = ys.Battle.BattleConst.UnitType.AIRFIGHTER_UNIT

	arg_1_0:changeState(BattleAirFighterUnit.STRIKE_STATE_FLY)
	arg_1_0:calcYShakeMin()
	arg_1_0:calcYShakeMax()

	arg_1_0._speedDir = Vector3(1, 0, 0)
	arg_1_0._backwardWeaponID = {}
end

function BattleAirFighterUnit.Update(arg_2_0, arg_2_1)
	arg_2_0:UpdateSpeed()
	arg_2_0:updateStrike()
end

function BattleAirFighterUnit.UpdateWeapon(arg_3_0)
	for iter_3_0, iter_3_1 in ipairs(arg_3_0:GetWeapon()) do
		local var_3_0 = iter_3_1:GetWeaponId()
		local var_3_1 = table.contains(arg_3_0._backwardWeaponID, var_3_0)
		local var_3_2 = iter_3_1:GetCurrentState()

		iter_3_1:Update()

		local var_3_3 = iter_3_1:GetCurrentState()

		if var_3_1 and var_3_2 == iter_3_1.STATE_READY and (var_3_3 == iter_3_1.STATE_ATTACK or var_3_3 == iter_3_1.STATE_OVER_HEAT) then
			arg_3_0:changeState(BattleAirFighterUnit.STRIKE_STATE_BACKWARD)
		end
	end
end

function BattleAirFighterUnit.CreateWeapon(arg_4_0)
	local var_4_0 = {}

	if type(arg_4_0._weaponTemplateID) == "table" then
		for iter_4_0, iter_4_1 in ipairs(arg_4_0._weaponTemplateID) do
			var_4_0[iter_4_0] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(iter_4_1, arg_4_0, iter_4_0)
		end
	else
		var_4_0[1] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(arg_4_0._weaponTemplateID, arg_4_0, 1)
	end

	if arg_4_0._backwardWeaponID then
		for iter_4_2, iter_4_3 in ipairs(arg_4_0._backwardWeaponID) do
			var_4_0[iter_4_2] = ys.Battle.BattleDataFunction.CreateAirFighterWeaponUnit(iter_4_3, arg_4_0, iter_4_2)
		end
	end

	return var_4_0
end

function BattleAirFighterUnit.SetWeaponTemplateID(arg_5_0, arg_5_1)
	arg_5_0._weaponTemplateID = arg_5_1
end

function BattleAirFighterUnit.SetBackwardWeaponID(arg_6_0, arg_6_1)
	arg_6_0._backwardWeaponID = arg_6_1
end

-- 被BattleDataFunction.CreateAirFighterUnit调用
function BattleAirFighterUnit.SetTemplate(self, tmpData)
	self:SetAttr(tmpData)
	-- 注意这里调用了父类的SetTemplate(即BattleAircraftUnit.SetTemplate)
	BattleAirFighterUnit.super.SetTemplate(self, tmpData)
end

-- 被BattleAirFighterUnit.SetTemplate调用
function BattleAirFighterUnit.SetAttr(self, tmpData)
	ys.Battle.BattleAttr.SetAirFighterAttr(self, tmpData)
	self:SetIFF(-1)
end

function BattleAirFighterUnit.UpdateSpeed(arg_9_0)
	arg_9_0._speed:Copy(arg_9_0._speedDir)
	arg_9_0._speed:Mul(arg_9_0._velocity * arg_9_0:GetSpeedRatio())
end

function BattleAirFighterUnit.Free(arg_10_0)
	arg_10_0._undefeated = true

	arg_10_0:LiveCallBack()

	arg_10_0._aliveState = false
end

function BattleAirFighterUnit.recycle(arg_11_0)
	arg_11_0:LiveCallBack()

	arg_11_0._aliveState = false
end

function BattleAirFighterUnit.onDead(arg_12_0)
	arg_12_0._currentState = arg_12_0.STATE_DESTORY

	arg_12_0:DeadCallBack()

	arg_12_0._aliveState = false
end

function BattleAirFighterUnit.GetPosition(arg_13_0)
	return arg_13_0._viewPos
end

function BattleAirFighterUnit.SetFormationIndex(arg_14_0, arg_14_1)
	arg_14_0._formationIndex = arg_14_1
	arg_14_0._flyStateScale = 12 / (arg_14_1 + 3) + 1

	arg_14_0:DispatchStrikeStateChange()
end

function BattleAirFighterUnit.GetFormationIndex(arg_15_0)
	return arg_15_0._formationIndex
end

function BattleAirFighterUnit.SetFormationOffset(arg_16_0, arg_16_1)
	arg_16_0._formationOffset = Vector3(arg_16_1.x, arg_16_1.y, arg_16_1.z)
	arg_16_0._formationOffsetOppo = Vector3(arg_16_1.x * -1, arg_16_1.y, arg_16_1.z)
end

function BattleAirFighterUnit.SetDeadCallBack(arg_17_0, arg_17_1)
	arg_17_0._deadCallBack = arg_17_1
end

function BattleAirFighterUnit.DeadCallBack(arg_18_0)
	arg_18_0._deadCallBack()
end

function BattleAirFighterUnit.SetLiveCallBack(arg_19_0, arg_19_1)
	arg_19_0._liveCallBack = arg_19_1
end

function BattleAirFighterUnit.LiveCallBack(arg_20_0)
	arg_20_0._liveCallBack()
end

function BattleAirFighterUnit.getYShake(arg_21_0)
	local var_21_0 = arg_21_0._YShakeCurrent or 0

	arg_21_0._YShakeDir = arg_21_0._YShakeDir or 1

	local var_21_1 = var_21_0 + (0.04 * math.random() + 0.01) * arg_21_0._YShakeDir

	if var_21_1 > arg_21_0._YShakeMax then
		arg_21_0._YShakeDir = -1

		arg_21_0:calcYShakeMin()
	elseif var_21_1 < arg_21_0._YShakeMin then
		arg_21_0._YShakeDir = 1

		arg_21_0:calcYShakeMax()
	end

	arg_21_0._YShakeCurrent = var_21_1

	return var_21_1
end

function BattleAirFighterUnit.calcYShakeMin(arg_22_0)
	arg_22_0._YShakeMin = -0.5 - math.random()
end

function BattleAirFighterUnit.calcYShakeMax(arg_23_0)
	arg_23_0._YShakeMax = 0.5 + math.random()
end

function BattleAirFighterUnit.DispatchStrikeStateChange(arg_24_0)
	arg_24_0:DispatchEvent(ys.Event.New(BattleUnitEvent.AIR_STRIKE_STATE_CHANGE, {}))
end

function BattleAirFighterUnit.GetStrikeState(arg_25_0)
	return arg_25_0._strikeState
end

function BattleAirFighterUnit.GetSize(arg_26_0)
	return arg_26_0._scale
end

function BattleAirFighterUnit.changeState(arg_27_0, arg_27_1)
	if arg_27_0._strikeState == arg_27_1 then
		return
	end

	arg_27_0._strikeState = arg_27_1

	if arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_FLY then
		arg_27_0:changeToFlyState()

		arg_27_0.updateStrike = BattleAirFighterUnit._updatePosFly
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_BACK then
		arg_27_0.updateStrike = BattleAirFighterUnit._updatePosBack

		arg_27_0:changeToBackState()
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_DOWN then
		arg_27_0.updateStrike = BattleAirFighterUnit._updatePosDown

		arg_27_0:changeToDownState()
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_ATTACK then
		arg_27_0.updateStrike = BattleAirFighterUnit._updatePosAttack

		arg_27_0:changeToAttackState()
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_UP then
		arg_27_0.updateStrike = BattleAirFighterUnit._updatePosUp

		arg_27_0:changeToUpState()
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_BACKWARD then
		arg_27_0.updateStrike = BattleAirFighterUnit._updateBackward

		arg_27_0:changeToBackwardState()
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_FREE then
		arg_27_0.updateStrike = BattleAirFighterUnit._updateFree
	elseif arg_27_1 == BattleAirFighterUnit.STRIKE_STATE_RECYCLE then
		arg_27_0.updateStrike = BattleAirFighterUnit._updateRecycle
	end

	arg_27_0:DispatchStrikeStateChange()
end

function BattleAirFighterUnit.changeToFlyState(arg_28_0)
	arg_28_0._pos = ys.Battle.BattleCameraUtil.GetInstance():GetS2WPoint(BattleAirFighterUnit.AIRFIGHTER_ENTER_POINT)
	arg_28_0._viewPos = arg_28_0._pos

	ys.Battle.PlayBattleSFX("battle/plane")
end

function BattleAirFighterUnit._updatePosFly(arg_29_0)
	arg_29_0._pos:Add(BattleAirFighterUnit.SPEED_FLY)

	arg_29_0._viewPos = Vector3(arg_29_0._formationOffset.x * arg_29_0._flyStateScale, (arg_29_0._formationOffset.z / 1.7 + arg_29_0:getYShake()) * arg_29_0._flyStateScale, 0):Add(arg_29_0._pos)

	if arg_29_0._pos.x > BattleAirFighterUnit.BACK_X then
		arg_29_0:changeState(BattleAirFighterUnit.STRIKE_STATE_BACK)
	end
end

function BattleAirFighterUnit.changeToBackState(arg_30_0)
	local var_30_0
	local var_30_1 = ys.Battle.BattleDataProxy.GetInstance():GetFleetByIFF(BattleConfig.FRIENDLY_CODE):GetMotion()

	if var_30_1 then
		var_30_0 = var_30_1:GetPos().z
	else
		var_30_0 = 45
	end

	arg_30_0._pos = Vector3(arg_30_0._pos.x, 15, var_30_0)
end

function BattleAirFighterUnit._updatePosBack(arg_31_0)
	arg_31_0._pos:Sub(arg_31_0._speed)
	arg_31_0._viewPos:Copy(arg_31_0._pos)
	arg_31_0._viewPos:Sub(arg_31_0._formationOffset)

	if arg_31_0._pos.x < BattleAirFighterUnit.DOWN_X then
		arg_31_0:changeState(BattleAirFighterUnit.STRIKE_STATE_DOWN)
	end
end

function BattleAirFighterUnit.changeToDownState(arg_32_0)
	arg_32_0._ySpeed = 0.5

	arg_32_0:SetVisitable()
end

function BattleAirFighterUnit._updatePosDown(arg_33_0)
	arg_33_0._pos:Sub(arg_33_0._speed)

	arg_33_0._pos.y = math.max(BattleAirFighterUnit.HEIGHT, arg_33_0._pos.y - arg_33_0._ySpeed)
	arg_33_0._viewPos = arg_33_0._pos + arg_33_0._formationOffsetOppo
	arg_33_0._ySpeed = math.max(0.02, arg_33_0._ySpeed - 0.005)

	if arg_33_0._pos.x < BattleAirFighterUnit.ATTACK_X then
		arg_33_0:changeState(BattleAirFighterUnit.STRIKE_STATE_ATTACK)
	end
end

function BattleAirFighterUnit.changeToAttackState(arg_34_0)
	ys.Battle.PlayBattleSFX("battle/air-atk")
end

function BattleAirFighterUnit._updatePosAttack(arg_35_0)
	arg_35_0._pos:Sub(arg_35_0._speed)

	arg_35_0._pos.y = math.max(BattleAirFighterUnit.HEIGHT, arg_35_0._pos.y - 0.04)

	local var_35_0 = arg_35_0._formationOffsetOppo

	var_35_0.y = arg_35_0:getYShake()
	arg_35_0._viewPos = arg_35_0._pos + var_35_0

	arg_35_0:UpdateWeapon()

	if arg_35_0._pos.x < BattleAirFighterUnit.UP_X then
		arg_35_0:changeState(BattleAirFighterUnit.STRIKE_STATE_UP)
	end
end

function BattleAirFighterUnit.changeToUpState(arg_36_0)
	arg_36_0._ySpeed = 0.1
end

function BattleAirFighterUnit._updatePosUp(arg_37_0)
	arg_37_0._pos:Sub(arg_37_0._speed)

	arg_37_0._pos.y = arg_37_0._pos.y + arg_37_0._ySpeed
	arg_37_0._ySpeed = math.min(0.7, arg_37_0._ySpeed + 0.02)
	arg_37_0._viewPos = arg_37_0._pos + arg_37_0._formationOffsetOppo

	if arg_37_0._pos.x < BattleAirFighterUnit.FREE_X then
		arg_37_0:changeState(BattleAirFighterUnit.STRIKE_STATE_FREE)
	end
end

function BattleAirFighterUnit._updateFree(arg_38_0)
	arg_38_0:Free()
end

function BattleAirFighterUnit.changeToBackwardState(arg_39_0)
	return
end

function BattleAirFighterUnit._updateBackward(arg_40_0)
	arg_40_0._pos:Add(arg_40_0._speed)

	arg_40_0._pos.y = math.max(BattleAirFighterUnit.HEIGHT, arg_40_0._pos.y - 0.04)
	arg_40_0._viewPos = arg_40_0._pos + arg_40_0._formationOffsetOppo

	if arg_40_0._pos.x > BattleAirFighterUnit.DOWN_X then
		arg_40_0:changeState(BattleAirFighterUnit.STRIKE_STATE_RECYCLE)
	end
end

function BattleAirFighterUnit._updateRecycle(arg_41_0)
	arg_41_0:recycle()
end
