ys = ys or {}

local ys = ys

ys.Battle.BattleBuffSize = class("BattleBuffSize", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffSize.__name = "BattleBuffSize"

local BattleBuffSize = ys.Battle.BattleBuffSize

BattleBuffSize.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_MOD_MODEL_SCALE

function BattleBuffSize.Ctor(self, effectData)
	ys.Battle.BattleBuffSize.super.Ctor(self, effectData)
end

function BattleBuffSize.GetEffectType(self)
	return BattleBuffSize.FX_TYPE
end

function BattleBuffSize.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or owner:GetID()
	self._base = self._tempData.arg_list.number or 1
	self._hpScale = self._tempData.arg_list.hp_scale or 0

	self._attr = "modelScale"
end

function BattleBuffSize.onHPRatioUpdate(self, owner, buff)
	self:doScale(owner)
	self:UpdateScale(owner)
end

function BattleBuffSize.onAttach(self, owner, buff)
	self:doScale(owner)
	self:UpdateScale(owner)
end

function BattleBuffSize.onStack(self, owner, buff)
	self:doScale(owner)

	local number = self._number
	-- 这里是乘算的，与一般BuffEffect的stack不同
	for _ = 1, buff._stack do
		number = number * self._number
	end

	self._number = number

	self:UpdateScale(owner)
end

function BattleBuffSize.onRemove(self, owner, buff)
	self._number = 0

	self:UpdateScale(owner)
end

-- 这个更新逻辑基本类似于BattleBuffAddAttr.UpdateAttrMul的逻辑，可以参考一下
function BattleBuffSize.UpdateScale(self, owner)
	local factorPositive = 1
	local factorNegative = 1
	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}
	local buffList = owner:GetBuffList()

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffSize.FX_TYPE then
				local number = effect._number
				local group = effect._group
				local groupMaxFactorPositive = groupMaxTablePositive[group] or 1
				local groupMaxFactorNegative = groupMaxTableNegative[group] or 1

				if groupMaxFactorPositive < number and number > 1 then
					factorPositive = factorPositive * number / groupMaxFactorPositive
					groupMaxFactorPositive = number
				end

				if number < groupMaxFactorNegative and number < 1 then
					factorNegative = factorNegative * number / groupMaxFactorNegative
					groupMaxFactorNegative = number
				end

				groupMaxTablePositive[group] = groupMaxFactorPositive
				groupMaxTableNegative[group] = groupMaxFactorNegative
			end
		end
	end

	local scaleValue = ys.Battle.BattleAttr.GetCurrent(owner, "baseScale") * factorPositive * factorNegative

	ys.Battle.BattleAttr.SetCurrent(owner, "modelScale", scaleValue)
	owner:DispatchEvent(ys.Event.New(ys.Battle.BattleBuffEvent.BUFF_EFFECT_CHNAGE_SIZE))
end

function BattleBuffSize.doScale(self, owner)
	local hpRate = owner:GetHPRate()

	self._number = self._base + hpRate * self._hpScale
end
