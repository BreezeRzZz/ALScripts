ys = ys or {}

local ys = ys

ys.Battle.BattleBuffOverHealingShield = class("BattleBuffOverHealingShield", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffOverHealingShield.__name = "BattleBuffOverHealingShield"

local BattleBuffOverHealingShield = ys.Battle.BattleBuffOverHealingShield

-- 此类BuffEffect会在单位受到过量治疗时生成一个护盾，持续一段时间。护盾会优先抵消伤害(并可以附加tag），直到护盾值为0或护盾持续时间结束。
-- 使用例: 目前只有阿尔比恩的3技能
function BattleBuffOverHealingShield.Ctor(self, effectData)
	BattleBuffOverHealingShield.super.Ctor(self, effectData)
end

function BattleBuffOverHealingShield.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._shieldDuration = self._tempData.arg_list.shield_duration
	self._shieldRate = self._tempData.arg_list.shield_rate
	self._shieldLabel = self._tempData.arg_list.shield_tag_list or {}
	self._shieldList = {}
end

function BattleBuffOverHealingShield.onOverHealing(self, owner, buff, args)
	local overHealing = args.overHealing
	local shieldNumber = math.ceil(overHealing * self._shieldRate)

	if shieldNumber > 0 then
		local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

		table.insert(self._shieldList, {
			timeStamp = currentTime,
			value = shieldNumber
		})
	end

	self:updateLabelTag(owner)
end

function BattleBuffOverHealingShield.onUpdate(self, owner, buff)
	local shieldListLength = #self._shieldList
	local startTimeStampThreshold = pg.TimeMgr.GetInstance():GetCombatTime() - self._shieldDuration

	while shieldListLength > 0 do
		-- 护盾到期移除
		if startTimeStampThreshold >= self._shieldList[shieldListLength].timeStamp then
			table.remove(self._shieldList, shieldListLength)
		end

		shieldListLength = shieldListLength - 1
	end

	self:updateLabelTag(owner)
end

function BattleBuffOverHealingShield.onTakeDamage(self, owner, buff, args)
	local shieldListLength = #self._shieldList
	-- 如果有护盾，且伤害满足条件，则优先扣除护盾
	-- 多个护盾时，可以认为按照护盾生成的时间戳先后顺序扣除(先生成的护盾优先扣除)
	-- 这里应该只有这类BuffEffect内部的护盾是这样的. 其他BuffEffect如果需要类似功能，自己实现
	-- 例如最常见的护盾是BattleBuffShield
	if self:damageCheck(args) and shieldListLength > 0 then
		local damage = args.damage
		local shieldIndex = 0

		while damage > 0 and shieldIndex < shieldListLength do
			shieldIndex = shieldIndex + 1

			local shieldValue = self._shieldList[shieldIndex].value

			if damage <= shieldValue then
				self._shieldList[shieldIndex].value = shieldValue - damage
				damage = 0
			else
				damage = damage - shieldValue
				self._shieldList[shieldIndex].value = 0
			end
		end

		args.damage = damage

		while shieldListLength > 0 do
			if self._shieldList[shieldListLength].value <= 0 then
				table.remove(self._shieldList, shieldListLength)
			end

			shieldListLength = shieldListLength - 1
		end

		self:updateLabelTag(owner)
	end
end

function BattleBuffOverHealingShield.updateLabelTag(self, owner)
	if #self._shieldList <= 0 then
		for iter_6_0, iter_6_1 in ipairs(self._shieldLabel) do
			owner:RemoveLabelTag(iter_6_1)
		end
	elseif not owner:ContainsLabelTag(self._shieldLabel) then
		for iter_6_2, iter_6_3 in ipairs(self._shieldLabel) do
			owner:AddLabelTag(iter_6_3)
		end
	end
end
