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

function BattleBuffSize.UpdateScale(self, owner)
	local var_8_0 = 1
	local var_8_1 = 1
	local var_8_2 = {}
	local var_8_3 = {}
	local var_8_4 = owner:GetBuffList()

	for iter_8_0, iter_8_1 in pairs(var_8_4) do
		for iter_8_2, iter_8_3 in ipairs(iter_8_1._effectList) do
			if iter_8_3:GetEffectType() == BattleBuffSize.FX_TYPE then
				local var_8_5 = iter_8_3._number
				local var_8_6 = iter_8_3._group
				local var_8_7 = var_8_2[var_8_6] or 1
				local var_8_8 = var_8_3[var_8_6] or 1

				if var_8_7 < var_8_5 and var_8_5 > 1 then
					var_8_0 = var_8_0 * var_8_5 / var_8_7
					var_8_7 = var_8_5
				end

				if var_8_5 < var_8_8 and var_8_5 < 1 then
					var_8_1 = var_8_1 * var_8_5 / var_8_8
					var_8_8 = var_8_5
				end

				var_8_2[var_8_6] = var_8_7
				var_8_3[var_8_6] = var_8_8
			end
		end
	end

	local var_8_9 = var_0_0.Battle.BattleAttr.GetCurrent(owner, "baseScale") * var_8_0 * var_8_1

	var_0_0.Battle.BattleAttr.SetCurrent(owner, "modelScale", var_8_9)
	owner:DispatchEvent(var_0_0.Event.New(var_0_0.Battle.BattleBuffEvent.BUFF_EFFECT_CHNAGE_SIZE))
end

function BattleBuffSize.doScale(arg_9_0, arg_9_1)
	local var_9_0 = arg_9_1:GetHPRate()

	arg_9_0._number = arg_9_0._base + var_9_0 * arg_9_0._hpScale
end
