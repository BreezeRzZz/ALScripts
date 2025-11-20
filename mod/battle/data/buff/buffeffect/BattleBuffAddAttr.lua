ys = ys or {}

-- var_0_0 -> ys
-- var_0_1 -> BattleBuffAddAttr(继承自 BattleBuffEffect)
local ys = ys
local BattleBuffAddAttr = class("BattleBuffAddAttr", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddAttr = BattleBuffAddAttr
BattleBuffAddAttr.__name = "BattleBuffAddAttr"
BattleBuffAddAttr.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR
-- arg_1_0 -> self
-- arg_1_1 -> template
function BattleBuffAddAttr.Ctor(self, template)
	ys.Battle.BattleBuffAddAttr.super.Ctor(self, template)
end
-- arg_2_0 -> self
function BattleBuffAddAttr.GetEffectType(self)
	return BattleBuffAddAttr.FX_TYPE
end
-- arg_3_0 -> self
-- arg_3_1 -> owner
-- arg_3_2 -> buff(BattleBuffUnit)
function BattleBuffAddAttr.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()

	if self._tempData.arg_list.comboDamage then
		self._attr = ys.Battle.BattleAttr.GetCurrent(self._caster, "comboTag")
	else
		self._attr = self._tempData.arg_list.attr
	end

	self._number = self._tempData.arg_list.number
	self._numberBase = self._number
	self._attrID = self._tempData.arg_list.attr_group_ID
end
-- arg_4_0 -> self
-- arg_4_1 -> owner
-- arg_4_2 -> buff
function BattleBuffAddAttr.onAttach(self, owner, buff)
	self:UpdateAttr(owner)
end
-- arg_5_0 -> self
-- arg_5_1 -> owner
-- arg_5_2 -> buff
	-- effect叠层时，相当于每层叠加
function BattleBuffAddAttr.onStack(self, owner, buff)
	self._number = self._numberBase * buff._stack

	self:UpdateAttr(owner)
end
-- arg_6_0 -> self
-- arg_6_1 -> owner
-- arg_6_2 -> buff
	-- effect移除时，数值归0
function BattleBuffAddAttr.onRemove(self, owner, buff)
	self._number = 0

	self:UpdateAttr(owner)
end
-- arg_7_0 -> self
-- arg_7_1 -> attr
function BattleBuffAddAttr.IsSameAttr(self, attr)
	return self._attr == attr
end
-- arg_8_0 -> self
-- arg_8_1 -> owner
function BattleBuffAddAttr.UpdateAttr(self, owner)
	assert(self._attr ~= "velocity", ">>BattleBuffAddAttr(Ratio)不可用于修改速度，使用BattleBuffFixVelocity!")

	-- 如果是易伤区(injureRatio)，不同ID的injureRatio Effect乘算
		-- 对于同ID，按照onStack逻辑，也是进行加算
	-- 其他的不同ID的Effect都是加算
	if self._attr == "injureRatio" then
		self:UpdateAttrMul(owner)
	else
		self:UpdateAttrAdd(owner)
	end
	-- 更新隐匿状态
	if self._attr == "cloakExposeExtra" or self._attr == "cloakRestore" or self._attr == "cloakRecovery" then
		owner:UpdateCloakConfig()
	end
	-- 更新夜战隐蔽状态
	if self._attr == "lockAimBias" then
		owner:UpdateAimBiasSkillState()
	end
end
-- arg_9_0 -> self
function BattleBuffAddAttr.CheckWeapon(self)
	if self._attr == "loadSpeed" then
		return true
	else
		return false
	end
end
-- arg_10_0 -> self
-- arg_10_1 -> owner
function BattleBuffAddAttr.UpdateAttrMul(self, owner)
	-- var_10_0 -> factorPositive
	-- var_10_1 -> factorNegative
	local factorPositive = 1
	local factorNegative = 1
	-- var_10_2 -> groupMaxTablePositive
	-- var_10_3 -> groupMaxTableNegative
	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}
	-- var_10_4 -> buffList
	local buffList = owner:GetBuffList()
	-- iter_10_0 -> _
	-- iter_10_1 -> buff(BattleBuffUnit)
	for _, buff in pairs(buffList) do
		-- iter_10_2 -> _
		-- iter_10_3 -> effect
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffAddAttr.FX_TYPE and effect:IsSameAttr(self._attr) then
				-- var_10_5 -> number
				-- var_10_6 -> group
				local number = effect._number
				local group = effect._group
				-- var_10_7 -> groupMaxFactorPositive
				-- var_10_8 -> groupMaxFactorNegative
					-- 同组(ID)的effect，正数取最大值，负数取最小值
				local groupMaxFactorPositive = groupMaxTablePositive[group] or 0
				local groupMaxFactorNegative = groupMaxTableNegative[group] or 0

				-- 最后factor记录的只有各组的最大正数之积和最小负数之积
					-- 不同组的也是处理了的，max值按照初始的0计算
				if groupMaxFactorPositive < number and number > 0 then
					factorPositive = factorPositive * (1 + number) / (1 + groupMaxFactorPositive)
					groupMaxFactorPositive = number
				end

				if number < groupMaxFactorNegative and number < 0 then
					factorNegative = factorNegative * (1 + number) / (1 + groupMaxFactorNegative)
					groupMaxFactorNegative = number
				end

				groupMaxTablePositive[group] = groupMaxFactorPositive
				groupMaxTableNegative[group] = groupMaxFactorNegative
			end
		end
	end

	ys.Battle.BattleAttr.FlashByBuff(owner, self._attr, factorPositive * factorNegative - 1)

	if self:CheckWeapon() then
		owner:FlushReloadingWeapon()
	end
end
-- arg_11_0 -> self
-- arg_11_1 -> owner
function BattleBuffAddAttr.UpdateAttrAdd(self, owner)
	-- var_11_0 -> currentHP
	-- var_11_1 -> maxHP
	local currentHP, maxHP = owner:GetHP()
	-- var_11_2 -> buffList
	local buffList = owner:GetBuffList()
	-- var_11_3 -> factorPositive
	-- var_11_4 -> factorNegative
	local factorPositive = 0
	local factorNegative = 0
	-- var_11_5 -> groupMaxTablePositive
	-- var_11_6 -> groupMaxTableNegative
	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}

	-- iter_11_0 -> _
	-- iter_11_1 -> buff
	for _, buff in pairs(buffList) do
		-- iter_11_2 -> _
		-- iter_11_3 -> effect
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffAddAttr.FX_TYPE and effect:IsSameAttr(self._attr) then
				-- var_11_7 -> number
				-- var_11_8 -> group
				local number = effect._number
				local group = effect._group
				-- var_11_9 -> groupMaxFactorPositive
				-- var_11_10 -> groupMaxFactorNegative
					-- 同组(ID)的effect，正数取最大值，负数取最小值
				local groupMaxFactorPositive = groupMaxTablePositive[group] or 0
				local groupMaxFactorNegative = groupMaxTableNegative[group] or 0

				-- 最后factor记录的只有各组的最大正数之和和最小负数之和
					-- 不同组的也是处理了的，max值按照初始的0计算
				if groupMaxFactorPositive < number and number > 0 then
					factorPositive = factorPositive + number - groupMaxFactorPositive
					groupMaxFactorPositive = number
				end

				if number < groupMaxFactorNegative and number < 0 then
					factorNegative = factorNegative + number - groupMaxFactorNegative
					groupMaxFactorNegative = number
				end

				groupMaxTablePositive[group] = groupMaxFactorPositive
				groupMaxTableNegative[group] = groupMaxFactorNegative
			end
		end
	end

	ys.Battle.BattleAttr.FlashByBuff(owner, self._attr, factorPositive + factorNegative)

	-- 处理血量变化
	-- var_11_11 -> newMaxHP
	-- var_11_12 -> newCurrentHP
		-- 考虑了newMaxHP大于maxHP和newMaxHP小于currentHP的情况
	local newMaxHP = owner:GetMaxHP()
	local newCurrentHP = math.min(newMaxHP, currentHP + math.max(0, newMaxHP - maxHP))

	owner:SetCurrentHP(newCurrentHP)

	if self:CheckWeapon() then
		owner:FlushReloadingWeapon()
	end

	owner._move:ImmuneAreaLimit(ys.Battle.BattleAttr.IsImmuneAreaLimit(owner))
	owner._move:ImmuneMaxAreaLimit(ys.Battle.BattleAttr.IsImmuneMaxAreaLimit(owner))
end
-- arg_12_0 -> self
-- arg_12_1 -> owner
	-- 这个函数没有被用过。
function BattleBuffAddAttr.UpdateAttrHybrid(self, owner)
	-- var_12_0 -> buffList
	local buffList = owner:GetBuffList()
	-- var_12_1 -> groupMaxTablePositive
	-- var_12_2 -> groupMaxTableNegative
	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}

	-- iter_12_0 -> _
	-- iter_12_1 -> buff
	for _, buff in pairs(buffList) do
		-- iter_12_2 -> _
		-- iter_12_3 -> effect
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffAddAttr.FX_TYPE and effect:IsSameAttr(self._attr) then
				-- var_12_3 -> number
				-- var_12_4 -> group
				-- var_12_5 -> attrID
				local number = effect._number
				local group = effect._group
				local attrID = effect._attrID or 0

				if number > 0 then
					-- var_12_6 -> groupMaxFactorPositive
						-- 与前两个函数的不同在于，多了一个attrID字段，仍在同group内取value最大/小
						-- 此外，此处只做了记录，没有像前两个函数那样直接计算最终值
						-- 计算过程在下面的函数中
					local groupMaxFactorPositive = groupMaxTablePositive[group] or {
						value = 0,
						attrGroup = attrID
					}

					groupMaxFactorPositive.value = math.max(groupMaxFactorPositive.value, number)
					groupMaxTablePositive[group] = groupMaxFactorPositive
				elseif number < 0 then
					-- var_12_7 -> groupMaxFactorNegative
					local groupMaxFactorNegative = groupMaxTableNegative[group] or {
						value = 0,
						attrGroup = attrID
					}

					groupMaxFactorNegative.value = math.min(groupMaxFactorNegative.value, number)
					groupMaxTableNegative[group] = groupMaxFactorNegative
				end
			end
		end
	end

	-- var_12_8 -> getFactorResult
	-- arg_13_0 -> groupMaxTable
	local function getFactorResult(groupMaxTable)
		-- var_13_0 -> attrGroupSums
		-- var_13_1 -> factorResult
		local attrGroupSums = {}
		local factorResult

		-- iter_13_0 -> _
		-- iter_13_1 -> groupMaxFactor
			-- 同attrGroup的value进行加算
		for _, groupMaxFactor in pairs(groupMaxTable) do
			-- var_13_2 -> attrGroup
			local attrGroup = groupMaxFactor.attrGroup

			attrGroupSums[attrGroup] = (attrGroupSums[attrGroup] or 0) + groupMaxFactor.value
		end
		-- 不同attrGroup的value进行乘算
		-- iter_13_2 -> _
		-- iter_13_3 -> value
		for _, value in pairs(attrGroupSums) do
			factorResult = (factorResult or 1) * value
		end

		return factorResult
	end

	-- var_12_9 -> factorResultPositive
	-- var_12_10 -> factorResultNegative
	local factorResultPositive = getFactorResult(groupMaxTablePositive) or 0
	local factorResultNegative = getFactorResult(groupMaxTableNegative) or 0

	ys.Battle.BattleAttr.FlashByBuff(owner, self._attr, factorResultPositive + factorResultNegative)
end
