ys = ys or {}

local ys = ys
local BattleBuffFixVelocity = class("BattleBuffFixVelocity", ys.Battle.BattleBuffAddAttr)

ys.Battle.BattleBuffFixVelocity = BattleBuffFixVelocity
BattleBuffFixVelocity.__name = "BattleBuffFixVelocity"
BattleBuffFixVelocity.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_MOD_VELOCTIY

-- 此类BuffEffect专门用于调整航速，原理是对单位的velocity属性进行加算和乘算
-- 其逻辑和BattleBuffAddAttr基本完全一致(本身也是其子类), 但航速涉及上下限, 以及加算/乘算混合处理, 专门处理了一下.
function BattleBuffFixVelocity.Ctor(self, effectData)
	BattleBuffFixVelocity.super.Ctor(self, effectData)
end

function BattleBuffFixVelocity.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_MOD_VELOCTIY
end

function BattleBuffFixVelocity.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()

	local add = self._tempData.arg_list.add or 0

	self._baseAdd = ys.Battle.BattleFormulas.ConvertShipSpeed(add)
	self._addValue = self._baseAdd
	self._baseMul = (self._tempData.arg_list.mul or 0) * 0.0001
	self._mulValue = self._baseMul
end

function BattleBuffFixVelocity.onStack(self, owner, buff)
	self._addValue = self._baseAdd * buff._stack
	self._mulValue = self._baseMul * buff._stack

	self:UpdateAttr(owner)
end

function BattleBuffFixVelocity.onRemove(self, owner, buff)
	self._addValue = 0
	self._mulValue = 0

	self:UpdateAttr(owner)
end

function BattleBuffFixVelocity.UpdateAttr(self, owner)
	local mulValue = self:calcMulValue(owner)
	local addValue = self:calcAddValue(owner)

	ys.Battle.BattleAttr.FlashVelocity(owner, mulValue, addValue)
end

function BattleBuffFixVelocity.calcMulValue(self, owner)
	local factorPositive = 1
	local factorNegative = 1
	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}
	local buffList = owner:GetBuffList()

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffFixVelocity.FX_TYPE then
				local mulValue = effect._mulValue
				local group = effect._group
				local groupMaxFactorPositive = groupMaxTablePositive[group] or 1
				local roupMaxFactorNegative = groupMaxTableNegative[group] or 1
				local mulFactor = 1 + mulValue

				if mulValue > 0 and groupMaxFactorPositive < mulFactor then
					factorPositive = factorPositive / groupMaxFactorPositive * mulFactor
					groupMaxFactorPositive = mulFactor
				end

				if mulValue < 0 and mulFactor < roupMaxFactorNegative then
					factorNegative = factorNegative / roupMaxFactorNegative * mulFactor
					roupMaxFactorNegative = mulFactor
				end

				groupMaxTablePositive[group] = groupMaxFactorPositive
				groupMaxTableNegative[group] = roupMaxFactorNegative
			end
		end
	end

	return factorPositive * factorNegative
end

function BattleBuffFixVelocity.calcAddValue(self, owner)
	local buffList = owner:GetBuffList()
	local factorPositive = 0
	local factorNegative = 0
	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffFixVelocity.FX_TYPE then
				local addValue = effect._addValue
				local group = effect._group
				local groupMaxFactorPositive = groupMaxTablePositive[group] or 0
				local groupMaxFactorNegative = groupMaxTableNegative[group] or 0

				if groupMaxFactorPositive < addValue and addValue > 0 then
					factorPositive = factorPositive + addValue - groupMaxFactorPositive
					groupMaxFactorPositive = addValue
				end

				if addValue < groupMaxFactorNegative and addValue < 0 then
					factorNegative = factorNegative + addValue - groupMaxFactorNegative
					groupMaxFactorNegative = addValue
				end

				groupMaxTablePositive[group] = groupMaxFactorPositive
				groupMaxTableNegative[group] = groupMaxFactorNegative
			end
		end
	end

	return factorPositive + factorNegative
end
