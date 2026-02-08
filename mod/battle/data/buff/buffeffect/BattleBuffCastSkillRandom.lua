ys = ys or {}

local ys = ys
local BattleAttr = ys.Battle.BattleAttr

ys.Battle.BattleBuffCastSkillRandom = class("BattleBuffCastSkillRandom", ys.Battle.BattleBuffCastSkill)
ys.Battle.BattleBuffCastSkillRandom.__name = "BattleBuffCastSkillRandom"

local BattleBuffCastSkillRandom = ys.Battle.BattleBuffCastSkillRandom

-- 此BuffEffect是BattleBuffCastSkill的一个变种
-- 根据给定的概率列表和技能列表，随机释放一个技能
function BattleBuffCastSkillRandom.Ctor(self, effectData)
	BattleBuffCastSkillRandom.super.Ctor(self, effectData)

	self._skillList = {}
end

function BattleBuffCastSkillRandom.spell(self, target, args)
	local arg_list = self._tempData.arg_list

	if arg_list.skill_id_list then
		local randomRanges = {}
		local range = arg_list.range

		for index, skillId in ipairs(arg_list.skill_id_list) do
			randomRanges[skillId] = range[index]
		end

		local random = math.random()

		for skillId, randomRange in pairs(randomRanges) do
			local rangeMin = randomRange[1]
			local rangeMax = randomRange[2]
			-- [rangeMin, rangeMax)
			if rangeMin <= random and random < rangeMax then
				self._skillList[skillId] = self._skillList[skillId] or ys.Battle.BattleSkillUnit.GenerateSpell(skillId, self._level, target, attData)

				local skill = self._skillList[skillId]

				if args and args.target then
					skill:SetTarget({
						args.target
					})
				end

				skill:Cast(target, self._commander)
			end
		end
	elseif arg_list.random_skill_tag then
		local random_skill_tag = arg_list.random_skill_tag
		local labelTagList = target:GetLabelTag()
		local randomSkillIdTable = {}

		for _, labelTag in ipairs(labelTagList) do
			-- 举例：random_skill_tag = "YUMIAITEMSKILL"
			-- tag = "YUMIAITEMSKILL60860", "YUMIAITEMSKILL60871", ...
			-- 后面的就是skill ID
			local randomTagStart, randomTagEnd = string.find(labelTag, random_skill_tag)

			if randomTagStart then
				local skillId = tonumber(string.sub(labelTag, randomTagEnd + 1, #labelTag))
				-- 去重
				if not table.contains(randomSkillIdTable, skillId) then
					table.insert(randomSkillIdTable, skillId)
				end
			end
		end

		if #randomSkillIdTable > 0 then
			-- 等概率随机选一个
			local randomSkillId = randomSkillIdTable[math.random(#randomSkillIdTable)]

			self._skillList[randomSkillId] = self._skillList[randomSkillId] or ys.Battle.BattleSkillUnit.GenerateSpell(randomSkillId, self._level, target, attData)

			local skill = self._skillList[randomSkillId]

			if args and args.target then
				skill:SetTarget({
					args.target
				})
			end

			skill:Cast(target, self._commander)
		end
	end
end

function BattleBuffCastSkillRandom.Clear(self)
	BattleBuffCastSkillRandom.super.Clear(self)

	for _, skill in pairs(self._skillList) do
		skill:Clear()
	end
end
