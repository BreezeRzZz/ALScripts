local CommanderTalent = class("CommanderTalent", import("..BaseVO"))
local commander_ability_group = pg.commander_ability_group

function CommanderTalent.Ctor(arg_1_0, arg_1_1)
	arg_1_0.id = arg_1_1.id
	arg_1_0.configId = arg_1_0.id
	arg_1_0.groupId = arg_1_0:getConfig("group_id")

	assert(commander_ability_group[arg_1_0.groupId])

	arg_1_0.list = commander_ability_group[arg_1_0.groupId].ability_list
end

function CommanderTalent.reset(arg_2_0)
	arg_2_0.id = arg_2_0.list[1]
	arg_2_0.configId = arg_2_0.id
end

function CommanderTalent.setOrigin(arg_3_0, arg_3_1)
	arg_3_0.origin = arg_3_1
end

function CommanderTalent.isOrigin(arg_4_0)
	return arg_4_0.origin
end

function CommanderTalent.getTalentList(arg_5_0)
	return arg_5_0.list
end

function CommanderTalent.bindConfigTable(arg_6_0)
	return pg.commander_ability_template
end

function CommanderTalent.getConsume(arg_7_0)
	local var_7_0 = 0
	local var_7_1 = table.indexof(arg_7_0.list, arg_7_0.id)

	if arg_7_0.origin then
		var_7_0 = var_7_1 - table.indexof(arg_7_0.list, arg_7_0.origin.id)
	else
		var_7_0 = var_7_1
	end

	return var_7_0
end

-- 单个天赋提供的属性加成(固定/百分比)
-- 被Commander.getTalentsAddition调用
function CommanderTalent.getAttrsAddition(self)
	local numberAdditions = {}
	local ratioAdditions = {}

	for propertyIndex, propertyName in ipairs(CommanderConst.PROPERTIES) do
		for _, addItem in ipairs(self:getConfig("add")) do
			if CommanderConst.TALENT_ADDITION_NUMBER == addItem[1] then
				if addItem[4] == propertyIndex then
					numberAdditions[propertyName] = {
						value = addItem[5],
						nation = addItem[2],
						shiptype = addItem[3]
					}
				end
			elseif CommanderConst.TALENT_ADDITION_RATIO == addItem[1] and addItem[4] == propertyIndex then
				ratioAdditions[propertyName] = {
					value = addItem[5],
					nation = addItem[2],
					shiptype = addItem[3]
				}
			end
		end
	end

	return numberAdditions, ratioAdditions
end

function CommanderTalent.getBuffsAddition(arg_9_0)
	local var_9_0 = {}

	for iter_9_0, iter_9_1 in ipairs(arg_9_0:getConfig("add")) do
		if CommanderConst.TALENT_ADDITION_BUFF == iter_9_1[1] then
			table.insert(var_9_0, iter_9_1[4])
		end
	end

	return var_9_0
end

function CommanderTalent.getDestoryExpValue(arg_10_0)
	local var_10_0 = 0
	local var_10_1 = arg_10_0:getConfig("add")

	for iter_10_0, iter_10_1 in ipairs(var_10_1) do
		if iter_10_1[1] == CommanderConst.TALENT_ADDITION_NUMBER and iter_10_1[4] == CommanderConst.DESTROY_ATTR_ID then
			var_10_0 = var_10_0 + iter_10_1[5]
		end
	end

	return var_10_0
end

function CommanderTalent.getDestoryExpRetio(arg_11_0)
	local var_11_0 = 0
	local var_11_1 = arg_11_0:getConfig("add")

	for iter_11_0, iter_11_1 in ipairs(var_11_1) do
		if iter_11_1[1] == CommanderConst.TALENT_ADDITION_RATIO and iter_11_1[4] == CommanderConst.DESTROY_ATTR_ID then
			var_11_0 = var_11_0 + iter_11_1[5]
		end
	end

	return var_11_0
end

function CommanderTalent.getDesc(arg_12_0)
	local var_12_0 = {}
	local var_12_1 = arg_12_0:getConfig("add_desc")

	for iter_12_0, iter_12_1 in ipairs(var_12_1) do
		local var_12_2 = iter_12_1[1]

		if var_12_0[var_12_2] then
			var_12_0[var_12_2].value = var_12_0[var_12_2].value + iter_12_1[2]
		else
			var_12_0[var_12_2] = {
				value = iter_12_1[2],
				type = iter_12_1[3] and CommanderConst.TALENT_ADDITION_RATIO or CommanderConst.TALENT_ADDITION_NUMBER
			}
		end
	end

	return var_12_0
end

return CommanderTalent
