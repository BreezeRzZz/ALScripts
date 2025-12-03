ys = ys or {}

local ys = ys
local BattleBuffAddAttr = class("BattleBuffAddAttr", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddAttr = BattleBuffAddAttr
BattleBuffAddAttr.__name = "BattleBuffAddAttr"
BattleBuffAddAttr.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_MOD_ATTR

--- @class BattleBuffAddAttr
--- @param effectData table
--- @return nil
--- 构造函数
function BattleBuffAddAttr.Ctor(self, effectData)
	ys.Battle.BattleBuffAddAttr.super.Ctor(self, effectData)
end

--- @return number
--- 获取效果类型
--- - 对于BattleBuffAddAttr，返回FX_TYPE_MOD_ATTR(= 1)
function BattleBuffAddAttr.GetEffectType(self)
	return BattleBuffAddAttr.FX_TYPE
end

--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @return nil
--- 设置参数
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

--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @return nil
--- 当Buff附加时立刻调用该回调
function BattleBuffAddAttr.onAttach(self, owner, buff)
	self:UpdateAttr(owner)
end

--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @return nil
--- 当Buff叠加时调用该回调
--- 相当于效果每层叠加
function BattleBuffAddAttr.onStack(self, owner, buff)
	self._number = self._numberBase * buff._stack

	self:UpdateAttr(owner)
end

--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @return nil
--- 当Buff移除时调用该回调
--- 数值归0
function BattleBuffAddAttr.onRemove(self, owner, buff)
	self._number = 0

	self:UpdateAttr(owner)
end

--- @param attr string: 该Effect对应的属性
--- @return boolean
--- 判断该Effect对应的属性是否与给定属性相同
function BattleBuffAddAttr.IsSameAttr(self, attr)
	return self._attr == attr
end

--- @param owner BattleUnit
--- @return nil
--- 更新属性值
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

--- @return boolean
--- 判断该Effect是否影响武器相关属性
--- - 看是不是装填属性
function BattleBuffAddAttr.CheckWeapon(self)
	if self._attr == "loadSpeed" then
		return true
	else
		return false
	end
end

--- @param owner BattleUnit
--- @return nil
--- 更新属性值（乘算）
function BattleBuffAddAttr.UpdateAttrMul(self, owner)
	local factorPositive = 1
	local factorNegative = 1

	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}

	local buffList = owner:GetBuffList()

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffAddAttr.FX_TYPE and effect:IsSameAttr(self._attr) then
				local number = effect._number
				local group = effect._group
				-- 同组(group ID)的effect，正数取最大值，负数取最小值
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

--- @param owner BattleUnit
--- @return nil
--- 更新属性值（加算）
function BattleBuffAddAttr.UpdateAttrAdd(self, owner)
	local currentHP, maxHP = owner:GetHP()
	local buffList = owner:GetBuffList()

	local factorPositive = 0
	local factorNegative = 0

	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffAddAttr.FX_TYPE and effect:IsSameAttr(self._attr) then
				local number = effect._number
				local group = effect._group
				-- 同组(groupID)的effect，正数取最大值，负数取最小值
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

--- @param owner BattleUnit
--- @return nil
--- 这个函数没有被用过。
function BattleBuffAddAttr.UpdateAttrHybrid(self, owner)
	local buffList = owner:GetBuffList()

	local groupMaxTablePositive = {}
	local groupMaxTableNegative = {}

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffAddAttr.FX_TYPE and effect:IsSameAttr(self._attr) then
				local number = effect._number
				local group = effect._group
				local attrID = effect._attrID or 0

				if number > 0 then
					-- roupMaxFactorPositive
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

	local function getFactorResult(groupMaxTable)
		local attrGroupSums = {}
		local factorResult

		-- 同attrGroup的value进行加算
		for _, groupMaxFactor in pairs(groupMaxTable) do
			local attrGroup = groupMaxFactor.attrGroup

			attrGroupSums[attrGroup] = (attrGroupSums[attrGroup] or 0) + groupMaxFactor.value
		end
		-- 不同attrGroup的value进行乘算
		for _, value in pairs(attrGroupSums) do
			factorResult = (factorResult or 1) * value
		end

		return factorResult
	end

	local factorResultPositive = getFactorResult(groupMaxTablePositive) or 0
	local factorResultNegative = getFactorResult(groupMaxTableNegative) or 0

	ys.Battle.BattleAttr.FlashByBuff(owner, self._attr, factorResultPositive + factorResultNegative)
end
