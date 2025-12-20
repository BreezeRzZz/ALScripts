local ActivityLevelConst = class("ActivityLevelConst")

-- note: 计算EXTRA关卡分数主体算法
-- 被BattleResultMediator.showExtraChapterActSocre调用
function ActivityLevelConst.getExtraChapterSocre(stageId, totalTime, shipsPower, extraActivitiy)
	if not extraActivitiy or extraActivitiy:isEnd() then
		return 0, 0
	end

	local config_data = extraActivitiy:getConfig("config_data")

	assert(config_data, "miss config >>" .. stageId)

	local score = 0

	if config_data then
		-- 举例: 常见的
		-- config_data[2] = 5000
		-- config_data[3] = 50
		-- config_data[4] = 0.36
		-- config_data[5] = 0.6
		-- config_data[6] = 10
		-- 因此计算分数的公式为: floor(max((5000/(totalTime + 50)^0.36 - shipsPower^0.6) * 10, 1))
		score = (config_data[2] / math.pow(totalTime + config_data[3], config_data[4]) - math.pow(shipsPower, config_data[5])) * config_data[6]
		score = math.max(score, 1)
	end

	local maxScore = extraActivitiy:getData1() or 0

	return math.floor(score), math.floor(maxScore)
end

function ActivityLevelConst.getShipsPower(ships)
	local shipsPower = 0
	-- ship: Ship类型
	for _, ship in pairs(ships) do
		-- 这个战力计算，因为没有传入指挥喵参数，所以计算的只有本体+装备+科技的战力
		shipsPower = shipsPower + ship:getShipCombatPower()
	end

	return shipsPower
end

return ActivityLevelConst
