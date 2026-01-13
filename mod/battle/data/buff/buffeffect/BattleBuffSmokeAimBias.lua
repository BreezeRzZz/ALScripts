ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr

ys.Battle.BattleBuffSmokeAimBias = class("BattleBuffSmokeAimBias", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffSmokeAimBias.__name = "BattleBuffSmokeAimBias"

local BattleBuffSmokeAimBias = ys.Battle.BattleBuffSmokeAimBias
local BattleAttr = ys.Battle.BattleAttr

BattleBuffSmokeAimBias.ATTR_SMOKE = "smoke_aim_bias"

function BattleBuffSmokeAimBias.Ctor(self, effectData)
	BattleBuffSmokeAimBias.super.Ctor(self, effectData)
end

function BattleBuffSmokeAimBias.SetArgs(self, owner, buff)
	return
end

function BattleBuffSmokeAimBias.onAttach(self, owner, buff)
	-- 设置属性，标记为在烟雾中
	-- 在烟雾中的敌人，获得夜战隐蔽相关效果（被敌方瞄准偏移）
	BattleAttr.SetCurrent(owner, BattleBuffSmokeAimBias.ATTR_SMOKE, 1)
	BattleDataFunction.AttachSmoke(owner)

	if BATTLE_ENEMY_AIMBIAS_RANGE then
		ys.Battle.BattleDataProxy.GetInstance():DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.ADD_AIM_BIAS, {
			aimBias = owner:GetAimBias()
		}))
	end
end

function BattleBuffSmokeAimBias.onUpdate(self, owner, buff, effectArgs)
	local baseDecaySpeed = {
		[BattleConfig.FRIENDLY_CODE] = 0,
		[BattleConfig.FOE_CODE] = 0
	}
	local extraDecaySpeed = {
		[BattleConfig.FRIENDLY_CODE] = 0,
		[BattleConfig.FOE_CODE] = 0
	}
	local unitList = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()

	for _, unit in pairs(unitList) do
		local unitIFF = unit:GetIFF()
		local _baseDecaySpeed = baseDecaySpeed[unitIFF]
		-- 命中属性值
		local attackRating = BattleAttr.GetCurrent(unit, "attackRating")
		-- (敌方)的隐蔽强度额外降低速度
		local aimBiasExtraACC = BattleAttr.GetCurrent(unit, "aimBiasExtraACC")
		-- 这里也是根据己方的命中值，来计算敌方的基础隐蔽衰减速度
		baseDecaySpeed[unitIFF] = math.max(_baseDecaySpeed, attackRating)
		extraDecaySpeed[unitIFF] = extraDecaySpeed[unitIFF] + aimBiasExtraACC
	end

	local aimBias = owner:GetAimBias()

	aimBias:SetDecayFactor(baseDecaySpeed[BattleConfig.FRIENDLY_CODE], extraDecaySpeed[BattleConfig.FRIENDLY_CODE])

	local timeStamp = effectArgs.timeStamp

	aimBias:Update(timeStamp)
end

function BattleBuffSmokeAimBias.onRemove(self, owner, buff)
	if BATTLE_ENEMY_AIMBIAS_RANGE then
		ys.Battle.BattleDataProxy.GetInstance():DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.REMOVE_AIM_BIAS, {
			aimBias = owner:GetAimBias()
		}))
	end

	BattleAttr.SetCurrent(owner, BattleBuffSmokeAimBias.ATTR_SMOKE, 0)
	owner:ExitSmokeArea()
end
