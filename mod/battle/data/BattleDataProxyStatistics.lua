local BattleDataProxy = ys.Battle.BattleDataProxy
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable

--- 战斗统计初始化：为友方舰队创建统计数据表
--- 包含每个单位的基础信息（id, damage, output, kill_count等）
--- @param self BattleDataProxy
--- @param unitList table: 友方单位列表
function BattleDataProxy.StatisticsInit(self, unitList)
	self._statistics = {}
	self._statistics._battleScore = BattleConst.BattleScore.D
	self._statistics.kill_id_list = {}
	self._statistics._totalTime = 0
	self._statistics._deadCount = 0
	self._statistics._boss_destruct = 0
	self._statistics._botPercentage = 0
	self._statistics._maxBossHP = 0
	self._statistics._enemyInfoList = {}

	for index, unit in ipairs(unitList) do
		local unitStats = {
			id = unit:GetAttrByName("id")
		}

		unitStats.damage = 0
		unitStats.output = 0
		unitStats.kill_count = 0
		unitStats.bp = 0
		unitStats.max_hp = unit:GetAttrByName("maxHP")
		unitStats.maxDamageOnce = 0
		unitStats.gearScore = unit:GetGearScore()
		self._statistics[unitStats.id] = unitStats
	end

	self._statistics._autoCount = 0
end

--- 初始化支援单位统计数据
--- @param self BattleDataProxy
--- @param aidUnit BattleUnit: 支援单位
function BattleDataProxy.InitAidUnitStatistics(self, aidUnit)
	local unitStats = {
		id = aidUnit:GetAttrByName("id")
	}

	unitStats.damage = 0
	unitStats.output = 0
	unitStats.kill_count = 0
	unitStats.bp = 0
	unitStats.max_hp = aidUnit:GetAttrByName("maxHP")
	unitStats.maxDamageOnce = 0
	unitStats.gearScore = aidUnit:GetGearScore()
	self._statistics[unitStats.id] = unitStats
	self._statistics.submarineAid = true
end

--- 初始化特定敌人统计数据（如boss、精英等）
--- @param self BattleDataProxy
--- @param specificEnemy BattleEnemyUnit: 特定敌人单位
function BattleDataProxy.InitSpecificEnemyStatistics(self, specificEnemy)
	local unitStats = {
		id = specificEnemy:GetAttrByName("id")
	}

	unitStats.damage = 0
	unitStats.output = 0
	unitStats.kill_count = 0
	unitStats.bp = 0
	unitStats.max_hp = specificEnemy:GetAttrByName("maxHP")
	unitStats.init_hp = specificEnemy:GetCurrentHP()
	unitStats.maxDamageOnce = 0
	unitStats.gearScore = specificEnemy:GetGearScore()
	self._statistics[unitStats.id] = unitStats
end

--- 初始化对手信息（用于对决等模式）
--- @param self BattleDataProxy
--- @param rivalList table: 对手单位列表
function BattleDataProxy.RivalInit(self, rivalList)
	self._statistics._rivalInfo = {}

	for index, rivalUnit in ipairs(rivalList) do
		local rivalID = rivalUnit:GetAttrByName("id")

		self._statistics._rivalInfo[rivalID] = {}
		self._statistics._rivalInfo[rivalID].id = rivalID
	end
end

--- 初始化躲避计数统计
--- @param self BattleDataProxy
function BattleDataProxy.DodgemCountInit(self)
	self._dodgemStatistics = {}
	self._dodgemStatistics.kill = 0
	self._dodgemStatistics.combo = 0
	self._dodgemStatistics.miss = 0
	self._dodgemStatistics.fail = 0
	self._dodgemStatistics.score = 0
	self._dodgemStatistics.maxCombo = 0
end

--- 初始化潜艇突袭统计
--- @param self BattleDataProxy
function BattleDataProxy.SubmarineRunInit(self)
	self._subRunStatistics = {}
	self._subRunStatistics.score = 0
end

--- 设置旗舰ID用于统计
--- @param self BattleDataProxy
--- @param flagShip BattleUnit: 旗舰单位
function BattleDataProxy.SetFlagShipID(self, flagShip)
	if flagShip then
		self._statistics._flagShipID = flagShip:GetAttrByName("id")
	end
end

--- 更新伤害统计核心
--- 关于调用点：HandleDamage/HandleDirectDamage中，以dHP为准
--- output: 造成的伤害
--- damage: 受到的伤害
--- DOT这类没有Caster的，不会计入造成伤害统计，但在受到伤害统计中正常计入
--- @param self BattleDataProxy
--- @param srcID number: 伤害来源ID
--- @param targetID number: 受伤目标ID
--- @param damage number: 伤害值
function BattleDataProxy.DamageStatistics(self, srcID, targetID, damage)
	if self._statistics[srcID] then
		self._statistics[srcID].output = self._statistics[srcID].output + damage
		self._statistics[srcID].maxDamageOnce = math.max(self._statistics[srcID].maxDamageOnce, damage)
	end

	if self._statistics[targetID] then
		self._statistics[targetID].damage = self._statistics[targetID].damage + damage
	end
end

--- 更新击杀统计
--- @param self BattleDataProxy
--- @param srcID number: 击杀者ID
--- @param _ number: 未使用
function BattleDataProxy.KillCountStatistics(self, srcID, _)
	if self._statistics[srcID] then
		self._statistics[srcID].kill_count = self._statistics[srcID].kill_count + 1
	end
end

--- 计算血量比例统计（用于结算BP）
--- @param self BattleDataProxy
function BattleDataProxy.HPRatioStatistics(self)
	for _, fleet in pairs(self._fleetList) do
		fleet:UndoFusion()
	end

	local unitList = self._fleetList[1]:GetUnitList()

	for index, unit in ipairs(unitList) do
		self._statistics[unit:GetAttrByName("id")].bp = math.ceil(unit:GetHPRate() * 10000)
	end
end

--- 计算Bot百分比
--- @param self BattleDataProxy
--- @param _ number: 未使用
function BattleDataProxy.BotPercentage(self, _)
	local totalTime = self._currentStageData.timeCount - self._countDown

	self._statistics._botPercentage = Mathf.Clamp(math.floor(_ / totalTime * 100), 0, 100)
end

--- 单位死亡时计算战斗评分
--- @param self BattleDataProxy
--- @param deadUnit BattleUnit: 死亡的单位
function BattleDataProxy.CalcBattleScoreWhenDead(self, deadUnit)
	local deadUnitIFF = deadUnit:GetIFF()

	if deadUnitIFF == BattleConfig.FRIENDLY_CODE then
		if not table.contains(ShipType.SubShipType, deadUnit:GetTemplate().type) then
			self:DelScoreWhenPlayerDead(deadUnit)
		end
	elseif deadUnitIFF == BattleConfig.FOE_CODE then
		self:AddScoreWhenEnemyDead(deadUnit)
	end
end

--- Boss被击破时加分
--- @param self BattleDataProxy
function BattleDataProxy.AddScoreWhenBossDestruct(self)
	self._statistics._boss_destruct = self._statistics._boss_destruct + 1
end

--- 敌人死亡时加分（记录击杀ID）
--- @param self BattleDataProxy
--- @param enemy BattleEnemyUnit: 被击杀的敌人
function BattleDataProxy.AddScoreWhenEnemyDead(self, enemy)
	if enemy:GetDeathReason() == BattleConst.UnitDeathReason.KILLED then
		self._statistics.kill_id_list[#self._statistics.kill_id_list + 1] = enemy:GetTemplateID()
	end
end

--- 友方死亡时扣分
--- @param self BattleDataProxy
--- @param deadUnit BattlePlayerUnit: 死亡的友方单位
function BattleDataProxy.DelScoreWhenPlayerDead(self, deadUnit)
	self._statistics._deadCount = self._statistics._deadCount + 1
end

--- 友方离场时计算BP（剩余血量百分比）
--- @param self BattleDataProxy
--- @param unit BattlePlayerUnit: 离场的单位
function BattleDataProxy.CalcBPWhenPlayerLeave(self, unit)
	self._statistics[unit:GetAttrByName("id")].bp = math.ceil(unit:GetHPRate() * 10000)
end

--- 判定是否超时
--- @param self BattleDataProxy
--- @return boolean: 是否超时
function BattleDataProxy.isTimeOut(self)
	return self._currentStageData.timeCount - self._countDown >= 180
end

--- 计算卡牌模式最终评分
--- @param self BattleDataProxy
--- @param fleet BattleFleetVO: 舰队
function BattleDataProxy.CalcCardPuzzleScoreAtEnd(self, fleet)
	self._statistics._deadUnit = true
	self._statistics._badTime = true

	local commonHP = fleet:GetCardPuzzleComponent():GetCurrentCommonHP()

	self._statistics._battleScore = commonHP > 0 and BattleConst.BattleScore.S or BattleConst.BattleScore.D
	self._statistics._cardPuzzleStatistics = {}
	self._statistics._cardPuzzleStatistics.common_hp_rest = commonHP

	local timePassed = self._currentStageData.timeCount - self._countDown

	self._statistics._totalTime = timePassed

	self:AirFightInit()
end

--- 计算单人副本最终评分
--- @param self BattleDataProxy
--- @param fleet BattleFleetVO: 敌方舰队
function BattleDataProxy.CalcSingleDungeonScoreAtEnd(self, fleet)
	self._statistics._deadUnit = true
	self._statistics._badTime = true

	local timePassed = self._currentStageData.timeCount - self._countDown

	self._statistics._totalTime = timePassed

	local limitType = self._expeditionTmp.limit_type
	local sinkLimit = self._expeditionTmp.sink_limit
	local timeLimit = self._expeditionTmp.time_limit

	if sinkLimit > self._statistics._deadCount then
		self._statistics._deadUnit = false
	end

	local flagShip = fleet:GetFlagShip()
	local scoutList = fleet:GetScoutList()

	if limitType == 2 then
		if not flagShip:IsAlive() or #scoutList <= 0 then
			self._statistics._battleScore = BattleConst.BattleScore.D
			self._statistics._boss_destruct = 1
		else
			self._statistics._battleScore = BattleConst.BattleScore.S
		end
	elseif self._countDown <= 0 then
		self._statistics._battleScore = BattleConst.BattleScore.C
		self._statistics._boss_destruct = 1
	elseif flagShip and not flagShip:IsAlive() then
		self._statistics._battleScore = BattleConst.BattleScore.D
		self._statistics._boss_destruct = 1
		self._statistics._scoreMark = BattleConst.DEAD_FLAG
	elseif #scoutList <= 0 then
		self._statistics._battleScore = BattleConst.BattleScore.D
		self._statistics._boss_destruct = 1
	else
		local failCount = 0

		if self._statistics._deadUnit then
			failCount = failCount + 1
		end

		if timeLimit < timePassed then
			failCount = failCount + 1
		else
			self._statistics._badTime = false
		end

		if self._statistics._boss_destruct > 0 then
			failCount = failCount + 1
		end

		if failCount >= 2 then
			self._statistics._battleScore = BattleConst.BattleScore.B
		elseif failCount == 1 then
			self._statistics._battleScore = BattleConst.BattleScore.A
		elseif failCount == 0 then
			self._statistics._battleScore = BattleConst.BattleScore.S
		end
	end

	self._statistics._timeout = self:isTimeOut()

	if self._battleInitData.CMDArgs then
		self:CalcSpecificEnemyInfo({
			self._battleInitData.CMDArgs
		})
	end
end

--- 记录Boss最大剩余血量百分比
--- @param self BattleDataProxy
--- @param maxRestHPRateBossRate number: Boss最大剩余血量百分比
function BattleDataProxy.CalcMaxRestHPRateBossRate(self, maxRestHPRateBossRate)
	self._statistics._maxBossHP = maxRestHPRateBossRate
end

--- 计算对决模式超时时的评分
--- @param self BattleDataProxy
--- @param ourHPRate number: 己方血量百分比
--- @param enemyHPRate number: 敌方血量百分比
--- @param ourDeadCount number: 己方死亡数
--- @param enemyDeadCount number: 敌方死亡数
function BattleDataProxy.CalcDuelScoreAtTimesUp(self, ourHPRate, enemyHPRate, ourDeadCount, enemyDeadCount)
	self._statistics._deadUnit = true
	self._statistics._badTime = true
	self._statistics._timeout = false

	local timePassed = self._currentStageData.timeCount - self._countDown

	self._statistics._totalTime = timePassed

	if self._expeditionTmp.sink_limit > self._statistics._deadCount then
		self._statistics._deadUnit = false
	end

	if enemyHPRate < ourHPRate then
		self._statistics._battleScore = BattleConst.BattleScore.S
	elseif ourHPRate < enemyHPRate then
		self._statistics._battleScore = BattleConst.BattleScore.D
	elseif enemyDeadCount <= ourDeadCount then
		self._statistics._battleScore = BattleConst.BattleScore.S
	elseif ourDeadCount < enemyDeadCount then
		self._statistics._battleScore = BattleConst.BattleScore.D
	end
end

--- 计算对决模式结束时的评分
--- @param self BattleDataProxy
--- @param ourFleet BattleFleetVO: 己方舰队
--- @param enemyFleet BattleFleetVO: 敌方舰队
function BattleDataProxy.CalcDuelScoreAtEnd(self, ourFleet, enemyFleet)
	self._statistics._deadUnit = true
	self._statistics._badTime = true

	local timePassed = self._currentStageData.timeCount - self._countDown

	self._statistics._totalTime = timePassed

	local ourUnitCount = #ourFleet:GetUnitList()
	local enemyUnitCount = #enemyFleet:GetUnitList()
	local sinkLimit = self._expeditionTmp.sink_limit
	local timeLimit = self._expeditionTmp.time_limit

	if sinkLimit > self._statistics._deadCount then
		self._statistics._deadUnit = false
	end

	if ourUnitCount == 0 then
		self._statistics._battleScore = BattleConst.BattleScore.D
	elseif enemyUnitCount == 0 then
		self._statistics._battleScore = BattleConst.BattleScore.S
	end

	self._statistics._timeout = self:isTimeOut()
end

--- 计算演习模式评分
--- @param self BattleDataProxy
--- @param ourFleet BattleFleetVO: 己方舰队
--- @param enemyFleet BattleFleetVO: 敌方舰队
function BattleDataProxy.CalcSimulationScoreAtEnd(self, ourFleet, enemyFleet)
	self._statistics._deadUnit = true
	self._statistics._badTime = true

	local timePassed = self._currentStageData.timeCount - self._countDown

	self._statistics._totalTime = timePassed

	local ourUnitCount = #ourFleet:GetUnitList()
	local ourMaxCount = ourFleet:GetMaxCount()
	local ourScoutCount = #ourFleet:GetScoutList()
	local enemyUnitCount = #enemyFleet:GetUnitList()
	local sinkLimit = self._expeditionTmp.sink_limit
	local timeLimit = self._expeditionTmp.time_limit

	if self._statistics._deadCount <= 0 then
		self._statistics._deadUnit = false
	end

	if not ourFleet:GetFlagShip():IsAlive() then
		self._statistics._battleScore = BattleConst.BattleScore.D
		self._statistics._scoreMark = BattleConst.DEAD_FLAG
	elseif ourScoutCount == 0 then
		self._statistics._battleScore = BattleConst.BattleScore.D
	elseif enemyUnitCount == 0 then
		self._statistics._battleScore = BattleConst.BattleScore.S
	end

	self._statistics._timeout = self:isTimeOut()

	self:overwriteRivalStatistics(enemyFleet)
end

--- 计算演习模式超时评分
--- @param self BattleDataProxy
--- @param result1 number: 结果1（未使用）
--- @param result2 number: 结果2（未使用）
--- @param result3 number: 结果3（未使用）
--- @param result4 number: 结果4（未使用）
--- @param enemyFleet BattleFleetVO: 敌方舰队
function BattleDataProxy.CalcSimulationScoreAtTimesUp(self, result1, result2, result3, result4, enemyFleet)
	self._statistics._deadUnit = true
	self._statistics._badTime = true
	self._statistics._timeout = false

	local timePassed = self._currentStageData.timeCount - self._countDown

	self._statistics._totalTime = timePassed

	if self._statistics._deadCount <= 0 then
		self._statistics._deadUnit = false
	end

	self._statistics._battleScore = BattleConst.BattleScore.D

	self:overwriteRivalStatistics(enemyFleet)
end

--- 覆写对手统计数据（更新BP值）
--- @param self BattleDataProxy
--- @param rivalFleet BattleFleetVO: 对手舰队
function BattleDataProxy.overwriteRivalStatistics(self, rivalFleet)
	for rivalID, rivalInfo in pairs(self._statistics._rivalInfo) do
		local unitFound = false

		for index, unit in ipairs(rivalFleet:GetUnitList()) do
			if unit:GetAttrByName("id") == rivalID then
				rivalInfo.bp = math.ceil(unit:GetHPRate() * 10000)
				unitFound = true

				break
			end
		end

		if not unitFound then
			rivalInfo.bp = 0
		end
	end
end

--- 计算挑战模式评分
--- @param self BattleDataProxy
--- @param isWin boolean: 是否胜利
function BattleDataProxy.CalcChallengeScore(self, isWin)
	if isWin then
		self._statistics._battleScore = BattleConst.BattleScore.S
	else
		self._statistics._battleScore = BattleConst.BattleScore.D
	end

	self._statistics._totalTime = self._totalTime
end

--- 计算躲避模式计数
--- @param self BattleDataProxy
--- @param dodgemUnit BattleUnit: 被击中的躲避单位
function BattleDataProxy.CalcDodgemCount(self, dodgemUnit)
	local deathReason = dodgemUnit:GetDeathReason()
	local shipType = dodgemUnit:GetTemplate().type

	if deathReason == ys.Battle.BattleConst.UnitDeathReason.CRUSH then
		self._dodgemStatistics.kill = self._dodgemStatistics.kill + 1

		if shipType == ShipType.JinBi then
			self._dodgemStatistics.combo = self._dodgemStatistics.combo + 1
			self._dodgemStatistics.maxCombo = math.max(self._dodgemStatistics.maxCombo, self._dodgemStatistics.combo)

			local newScore = self._dodgemStatistics.score + self:GetScorePoint()

			self._dodgemStatistics.score = newScore

			self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_DODGEM_SCORE, {
				totalScore = newScore
			}))
		elseif shipType == ShipType.ZiBao then
			self._dodgemStatistics.fail = self._dodgemStatistics.fail + 1
			self._dodgemStatistics.combo = 0
		end

		self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_DODGEM_COMBO, {
			combo = self._dodgemStatistics.combo
		}))
	elseif shipType == ShipType.JinBi then
		self._dodgemStatistics.miss = self._dodgemStatistics.miss + 1
	end
end

--- 获取躲避模式的得分点数
--- @param self BattleDataProxy
--- @return number: 得分点数
function BattleDataProxy.GetScorePoint(self)
	local scorePoint

	if self._dodgemStatistics.combo == 1 then
		scorePoint = 1
	elseif self._dodgemStatistics.combo == 2 then
		scorePoint = 2
	elseif self._dodgemStatistics.combo > 2 then
		scorePoint = 3
	end

	return scorePoint
end

--- 计算躲避模式最终评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcDodgemScore(self)
	if self._dodgemStatistics.score >= BattleConfig.BATTLE_DODGEM_PASS_SCORE then
		self._statistics._battleScore = BattleConst.BattleScore.S
	else
		self._statistics._battleScore = BattleConst.BattleScore.B
	end

	self._statistics.dodgemResult = self._dodgemStatistics
end

--- 计算活动Boss伤害信息
--- @param self BattleDataProxy
--- @param actID number: 活动ID
function BattleDataProxy.CalcActBossDamageInfo(self, actID)
	local enemyIDList = BattleDataFunction.GetSpecificEnemyList(actID, self._expeditionID)

	self:CalcSpecificEnemyInfo(enemyIDList)
end

--- 计算大世界Boss伤害信息
--- @param self BattleDataProxy
--- @param actID number: 活动ID
--- @param bossConfigID number: Boss配置ID
--- @param bossLevel number: Boss等级
function BattleDataProxy.CalcWorldBossDamageInfo(self, actID, bossConfigID, bossLevel)
	local enemyID = BattleDataFunction.GetSpecificWorldJointEnemyList(actID, bossConfigID, bossLevel)

	self:CalcSpecificEnemyInfo(enemyID)
end

--- 计算公会Boss敌人信息
--- @param self BattleDataProxy
--- @param actID number: 活动ID
function BattleDataProxy.CalcGuildBossEnemyInfo(self, actID)
	local enemyIDList = BattleDataFunction.GetSpecificGuildBossEnemyList(actID, self._expeditionID)

	self:CalcSpecificEnemyInfo(enemyIDList)
end

--- 计算特定敌人的伤害信息
--- @param self BattleDataProxy
--- @param enemyID table: 敌人ID列表
function BattleDataProxy.CalcSpecificEnemyInfo(self, enemyID)
	self._statistics.specificDamage = 0

	for _, id in ipairs(enemyID) do
		if self._statistics["enemy_" .. id] then
			local damage = self._statistics["enemy_" .. id].damage

			if table.contains(self._statistics.kill_id_list, id) then
				damage = self._statistics["enemy_" .. id].init_hp
			end

			self._statistics.specificDamage = self._statistics.specificDamage + damage

			local enemyInfo = {
				id = id,
				damage = damage,
				totalHp = self._statistics["enemy_" .. id].max_hp
			}

			table.insert(self._statistics._enemyInfoList, enemyInfo)
		end
	end
end

--- 计算击杀补给船（潜艇突袭模式）
--- @param self BattleDataProxy
function BattleDataProxy.CalcKillingSupplyShip(self)
	self._subRunStatistics.score = self._subRunStatistics.score + 1
end

--- 潜艇突袭超时计算评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcSubRunTimeUp(self)
	self._statistics._battleScore = BattleConst.BattleScore.B
	self._statistics.subRunResult = self._subRunStatistics
end

--- 潜艇突袭完成计算评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcSubRunScore(self)
	self._statistics._battleScore = BattleConst.BattleScore.S
	self._statistics.subRunResult = self._subRunStatistics
end

--- 潜艇突袭死亡计算评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcSubRunDead(self)
	self._statistics._battleScore = BattleConst.BattleScore.D
	self._statistics.subRunResult = self._subRunStatistics
end

--- 潜艇日常超时计算评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcSubRountineTimeUp(self)
	self._statistics._badTime = true

	self:CalcSubRoutineScore()

	self._statistics._battleScore = BattleConst.BattleScore.C
end

--- 潜艇日常被消灭计算评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcSubRountineElimate(self)
	self._statistics._elimated = true

	self:CalcSubRoutineScore()

	self._statistics._battleScore = BattleConst.BattleScore.D
end

--- 计算潜艇日常模式评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcSubRoutineScore(self)
	local deadPointCost = self._statistics._deadCount * BattleConfig.SR_CONFIG.DEAD_POINT
	local pointsEarned = self._subRunStatistics.score * BattleConfig.SR_CONFIG.POINT
	local baseScore = (self._statistics._badTime or self._statistics._elimated) and 0 or BattleConfig.SR_CONFIG.BASE_POINT
	local totalScore = baseScore + pointsEarned - deadPointCost

	if totalScore >= BattleConfig.SR_CONFIG.BASE_POINT + BattleConfig.SR_CONFIG.M * BattleConfig.SR_CONFIG.POINT then
		self._statistics._battleScore = BattleConst.BattleScore.S
	elseif totalScore >= BattleConfig.SR_CONFIG.BASE_POINT then
		self._statistics._battleScore = BattleConst.BattleScore.A
	elseif totalScore >= BattleConfig.SR_CONFIG.BASE_POINT - 2 * BattleConfig.SR_CONFIG.DEAD_POINT then
		self._statistics._battleScore = BattleConst.BattleScore.B
	else
		self._statistics._battleScore = BattleConst.BattleScore.D
	end

	self._subRunStatistics.basePoint = baseScore
	self._subRunStatistics.deadCount = self._statistics._deadCount
	self._subRunStatistics.losePoint = deadPointCost
	self._subRunStatistics.point = pointsEarned
	self._subRunStatistics.total = totalScore
	self._statistics.subRunResult = self._subRunStatistics
end

--- 初始化空战统计
--- @param self BattleDataProxy
function BattleDataProxy.AirFightInit(self)
	self._statistics._airFightStatistics = {}
	self._statistics._airFightStatistics.kill = 0
	self._statistics._airFightStatistics.score = 0
	self._statistics._airFightStatistics.hit = 0
	self._statistics._airFightStatistics.lose = 0
	self._statistics._airFightStatistics.total = 0
end

--- 增加空战分数（击杀敌机）
--- @param self BattleDataProxy
--- @param score number: 得分
function BattleDataProxy.AddAirFightScore(self, score)
	self._statistics._airFightStatistics.score = self._statistics._airFightStatistics.score + score
	self._statistics._airFightStatistics.kill = self._statistics._airFightStatistics.kill + 1
	self._statistics._airFightStatistics.total = math.max(self._statistics._airFightStatistics.score - self._statistics._airFightStatistics.lose, 0)

	self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_DODGEM_SCORE, {
		totalScore = self._statistics._airFightStatistics.total
	}))
end

--- 减少空战分数（被击中）
--- @param self BattleDataProxy
--- @param loseScore number: 失去的分数
function BattleDataProxy.DecreaseAirFightScore(self, loseScore)
	self._statistics._airFightStatistics.lose = self._statistics._airFightStatistics.lose + loseScore
	self._statistics._airFightStatistics.hit = self._statistics._airFightStatistics.hit + 1
	self._statistics._airFightStatistics.total = math.max(self._statistics._airFightStatistics.score - self._statistics._airFightStatistics.lose, 0)

	self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_DODGEM_SCORE, {
		totalScore = self._statistics._airFightStatistics.total
	}))
end

--- 计算空战最终评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcAirFightScore(self)
	self._statistics._battleScore = BattleConst.BattleScore.S
end

--- 添加特殊剧情中的潜艇突袭Boss单位
--- @param self BattleDataProxy
--- @param bossUnit BattleUnit: Boss单位
function BattleDataProxy.AddScenarioSubStrikeBoss(self, bossUnit)
	self._statistics._scenarioSubStrikebossUnit = bossUnit
end

--- 计算特殊剧情潜艇突袭最终评分
--- @param self BattleDataProxy
function BattleDataProxy.CalcScenarioSubStrikeScoreAtEnd(self)
	local bossUnit = self._statistics._scenarioSubStrikebossUnit

	if not bossUnit then
		self._statistics._bossHP = 1
		self._statistics._battleScore = BattleConst.BattleScore.C
	elseif not bossUnit:IsAlive() then
		self._statistics._battleScore = BattleConst.BattleScore.S
		self._statistics._bossHP = 0
	else
		local bossHPRate = bossUnit:GetHPRate()
		local objective2Threshold = self._expeditionTmp.objective_2[2] * 0.01
		local objective3Threshold = self._expeditionTmp.objective_3[2] * 0.01

		if bossHPRate < objective2Threshold then
			self._statistics._battleScore = BattleConst.BattleScore.A
		elseif objective2Threshold <= bossHPRate and bossHPRate < objective3Threshold then
			self._statistics._battleScore = BattleConst.BattleScore.B
		elseif objective3Threshold <= bossHPRate then
			self._statistics._battleScore = BattleConst.BattleScore.C
		end

		self._statistics._bossHP = bossHPRate
	end

	local maxDamage = 0

	for key, value in pairs(self._statistics) do
		if type(value) == "table" and value.id and value.damage and maxDamage < value.damage then
			maxDamage = value.damage
			self._statistics.mvpShipID = value.id
		end
	end
end

--- 自动模式统计
--- @param self BattleDataProxy
--- @param isAuto boolean: 是否为自动模式
function BattleDataProxy.AutoStatistics(self, isAuto)
	if not self._statistics._autoInit then
		self._statistics._autoInit = not isAuto and 1 or 0
	else
		self._statistics._autoCount = self._statistics._autoCount + 1
	end
end
