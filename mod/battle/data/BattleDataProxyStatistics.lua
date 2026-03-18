local BattleDataProxy = ys.Battle.BattleDataProxy
local var_0_1 = ys.Battle.BattleEvent
local var_0_2 = ys.Battle.BattleFormulas
local var_0_3 = ys.Battle.BattleConst
local var_0_4 = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local var_0_6 = ys.Battle.BattleAttr
local var_0_7 = ys.Battle.BattleVariable
-- TODO
function BattleDataProxy.StatisticsInit(arg_1_0, arg_1_1)
	arg_1_0._statistics = {}
	arg_1_0._statistics._battleScore = var_0_3.BattleScore.D
	arg_1_0._statistics.kill_id_list = {}
	arg_1_0._statistics._totalTime = 0
	arg_1_0._statistics._deadCount = 0
	arg_1_0._statistics._boss_destruct = 0
	arg_1_0._statistics._botPercentage = 0
	arg_1_0._statistics._maxBossHP = 0
	arg_1_0._statistics._enemyInfoList = {}

	for iter_1_0, iter_1_1 in ipairs(arg_1_1) do
		local var_1_0 = {
			id = iter_1_1:GetAttrByName("id")
		}

		var_1_0.damage = 0
		var_1_0.output = 0
		var_1_0.kill_count = 0
		var_1_0.bp = 0
		var_1_0.max_hp = iter_1_1:GetAttrByName("maxHP")
		var_1_0.maxDamageOnce = 0
		var_1_0.gearScore = iter_1_1:GetGearScore()
		arg_1_0._statistics[var_1_0.id] = var_1_0
	end

	arg_1_0._statistics._autoCount = 0
end

function BattleDataProxy.InitAidUnitStatistics(arg_2_0, arg_2_1)
	local var_2_0 = {
		id = arg_2_1:GetAttrByName("id")
	}

	var_2_0.damage = 0
	var_2_0.output = 0
	var_2_0.kill_count = 0
	var_2_0.bp = 0
	var_2_0.max_hp = arg_2_1:GetAttrByName("maxHP")
	var_2_0.maxDamageOnce = 0
	var_2_0.gearScore = arg_2_1:GetGearScore()
	arg_2_0._statistics[var_2_0.id] = var_2_0
	arg_2_0._statistics.submarineAid = true
end

function BattleDataProxy.InitSpecificEnemyStatistics(arg_3_0, arg_3_1)
	local var_3_0 = {
		id = arg_3_1:GetAttrByName("id")
	}

	var_3_0.damage = 0
	var_3_0.output = 0
	var_3_0.kill_count = 0
	var_3_0.bp = 0
	var_3_0.max_hp = arg_3_1:GetAttrByName("maxHP")
	var_3_0.init_hp = arg_3_1:GetCurrentHP()
	var_3_0.maxDamageOnce = 0
	var_3_0.gearScore = arg_3_1:GetGearScore()
	arg_3_0._statistics[var_3_0.id] = var_3_0
end

function BattleDataProxy.RivalInit(arg_4_0, arg_4_1)
	arg_4_0._statistics._rivalInfo = {}

	for iter_4_0, iter_4_1 in ipairs(arg_4_1) do
		local var_4_0 = iter_4_1:GetAttrByName("id")

		arg_4_0._statistics._rivalInfo[var_4_0] = {}
		arg_4_0._statistics._rivalInfo[var_4_0].id = var_4_0
	end
end

function BattleDataProxy.DodgemCountInit(arg_5_0)
	arg_5_0._dodgemStatistics = {}
	arg_5_0._dodgemStatistics.kill = 0
	arg_5_0._dodgemStatistics.combo = 0
	arg_5_0._dodgemStatistics.miss = 0
	arg_5_0._dodgemStatistics.fail = 0
	arg_5_0._dodgemStatistics.score = 0
	arg_5_0._dodgemStatistics.maxCombo = 0
end

function BattleDataProxy.SubmarineRunInit(arg_6_0)
	arg_6_0._subRunStatistics = {}
	arg_6_0._subRunStatistics.score = 0
end

function BattleDataProxy.SetFlagShipID(arg_7_0, arg_7_1)
	if arg_7_1 then
		arg_7_0._statistics._flagShipID = arg_7_1:GetAttrByName("id")
	end
end

-- TODO
-- 更新伤害统计核心
-- 关于调用点：HandleDamage/HandleDirectDamage中，以dHP为准
function BattleDataProxy.DamageStatistics(self, srcID, targetID, damage)
	-- output: 造成的伤害
	-- damage: 受到的伤害

	-- DOT这类没有Caster的，不会计入造成伤害统计，但在受到伤害统计中正常计入
	if self._statistics[srcID] then
		self._statistics[srcID].output = self._statistics[srcID].output + damage
		self._statistics[srcID].maxDamageOnce = math.max(self._statistics[srcID].maxDamageOnce, damage)
	end

	if self._statistics[targetID] then
		self._statistics[targetID].damage = self._statistics[targetID].damage + damage
	end
end

function BattleDataProxy.KillCountStatistics(arg_9_0, arg_9_1, arg_9_2)
	if arg_9_0._statistics[arg_9_1] then
		arg_9_0._statistics[arg_9_1].kill_count = arg_9_0._statistics[arg_9_1].kill_count + 1
	end
end

function BattleDataProxy.HPRatioStatistics(arg_10_0)
	for iter_10_0, iter_10_1 in pairs(arg_10_0._fleetList) do
		iter_10_1:UndoFusion()
	end

	local var_10_0 = arg_10_0._fleetList[1]:GetUnitList()

	for iter_10_2, iter_10_3 in ipairs(var_10_0) do
		arg_10_0._statistics[iter_10_3:GetAttrByName("id")].bp = math.ceil(iter_10_3:GetHPRate() * 10000)
	end
end

function BattleDataProxy.BotPercentage(arg_11_0, arg_11_1)
	local var_11_0 = arg_11_0._currentStageData.timeCount - arg_11_0._countDown

	arg_11_0._statistics._botPercentage = Mathf.Clamp(math.floor(arg_11_1 / var_11_0 * 100), 0, 100)
end

function BattleDataProxy.CalcBattleScoreWhenDead(arg_12_0, arg_12_1)
	local var_12_0 = arg_12_1:GetIFF()

	if var_12_0 == var_0_4.FRIENDLY_CODE then
		if not table.contains(ShipType.SubShipType, arg_12_1:GetTemplate().type) then
			arg_12_0:DelScoreWhenPlayerDead(arg_12_1)
		end
	elseif var_12_0 == var_0_4.FOE_CODE then
		arg_12_0:AddScoreWhenEnemyDead(arg_12_1)
	end
end

function BattleDataProxy.AddScoreWhenBossDestruct(arg_13_0)
	arg_13_0._statistics._boss_destruct = arg_13_0._statistics._boss_destruct + 1
end

function BattleDataProxy.AddScoreWhenEnemyDead(arg_14_0, arg_14_1)
	if arg_14_1:GetDeathReason() == var_0_3.UnitDeathReason.KILLED then
		arg_14_0._statistics.kill_id_list[#arg_14_0._statistics.kill_id_list + 1] = arg_14_1:GetTemplateID()
	end
end

function BattleDataProxy.DelScoreWhenPlayerDead(arg_15_0, arg_15_1)
	arg_15_0._statistics._deadCount = arg_15_0._statistics._deadCount + 1
end

function BattleDataProxy.CalcBPWhenPlayerLeave(arg_16_0, arg_16_1)
	arg_16_0._statistics[arg_16_1:GetAttrByName("id")].bp = math.ceil(arg_16_1:GetHPRate() * 10000)
end

function BattleDataProxy.isTimeOut(arg_17_0)
	return arg_17_0._currentStageData.timeCount - arg_17_0._countDown >= 180
end

function BattleDataProxy.CalcCardPuzzleScoreAtEnd(arg_18_0, arg_18_1)
	arg_18_0._statistics._deadUnit = true
	arg_18_0._statistics._badTime = true

	local var_18_0 = arg_18_1:GetCardPuzzleComponent():GetCurrentCommonHP()

	arg_18_0._statistics._battleScore = var_18_0 > 0 and var_0_3.BattleScore.S or var_0_3.BattleScore.D
	arg_18_0._statistics._cardPuzzleStatistics = {}
	arg_18_0._statistics._cardPuzzleStatistics.common_hp_rest = var_18_0

	local var_18_1 = arg_18_0._currentStageData.timeCount - arg_18_0._countDown

	arg_18_0._statistics._totalTime = var_18_1

	arg_18_0:AirFightInit()
end

function BattleDataProxy.CalcSingleDungeonScoreAtEnd(arg_19_0, arg_19_1)
	arg_19_0._statistics._deadUnit = true
	arg_19_0._statistics._badTime = true

	local var_19_0 = arg_19_0._currentStageData.timeCount - arg_19_0._countDown

	arg_19_0._statistics._totalTime = var_19_0

	local var_19_1 = arg_19_0._expeditionTmp.limit_type
	local var_19_2 = arg_19_0._expeditionTmp.sink_limit
	local var_19_3 = arg_19_0._expeditionTmp.time_limit

	if var_19_2 > arg_19_0._statistics._deadCount then
		arg_19_0._statistics._deadUnit = false
	end

	local var_19_4 = arg_19_1:GetFlagShip()
	local var_19_5 = arg_19_1:GetScoutList()

	if var_19_1 == 2 then
		if not var_19_4:IsAlive() or #var_19_5 <= 0 then
			arg_19_0._statistics._battleScore = var_0_3.BattleScore.D
			arg_19_0._statistics._boss_destruct = 1
		else
			arg_19_0._statistics._battleScore = var_0_3.BattleScore.S
		end
	elseif arg_19_0._countDown <= 0 then
		arg_19_0._statistics._battleScore = var_0_3.BattleScore.C
		arg_19_0._statistics._boss_destruct = 1
	elseif var_19_4 and not var_19_4:IsAlive() then
		arg_19_0._statistics._battleScore = var_0_3.BattleScore.D
		arg_19_0._statistics._boss_destruct = 1
		arg_19_0._statistics._scoreMark = var_0_3.DEAD_FLAG
	elseif #var_19_5 <= 0 then
		arg_19_0._statistics._battleScore = var_0_3.BattleScore.D
		arg_19_0._statistics._boss_destruct = 1
	else
		local var_19_6 = 0

		if arg_19_0._statistics._deadUnit then
			var_19_6 = var_19_6 + 1
		end

		if var_19_3 < var_19_0 then
			var_19_6 = var_19_6 + 1
		else
			arg_19_0._statistics._badTime = false
		end

		if arg_19_0._statistics._boss_destruct > 0 then
			var_19_6 = var_19_6 + 1
		end

		if var_19_6 >= 2 then
			arg_19_0._statistics._battleScore = var_0_3.BattleScore.B
		elseif var_19_6 == 1 then
			arg_19_0._statistics._battleScore = var_0_3.BattleScore.A
		elseif var_19_6 == 0 then
			arg_19_0._statistics._battleScore = var_0_3.BattleScore.S
		end
	end

	arg_19_0._statistics._timeout = arg_19_0:isTimeOut()

	if arg_19_0._battleInitData.CMDArgs then
		arg_19_0:CalcSpecificEnemyInfo({
			arg_19_0._battleInitData.CMDArgs
		})
	end
end

function BattleDataProxy.CalcMaxRestHPRateBossRate(self, maxRestHPRateBossRate)
	self._statistics._maxBossHP = maxRestHPRateBossRate
end

function BattleDataProxy.CalcDuelScoreAtTimesUp(arg_21_0, arg_21_1, arg_21_2, arg_21_3, arg_21_4)
	arg_21_0._statistics._deadUnit = true
	arg_21_0._statistics._badTime = true
	arg_21_0._statistics._timeout = false

	local var_21_0 = arg_21_0._currentStageData.timeCount - arg_21_0._countDown

	arg_21_0._statistics._totalTime = var_21_0

	if arg_21_0._expeditionTmp.sink_limit > arg_21_0._statistics._deadCount then
		arg_21_0._statistics._deadUnit = false
	end

	if arg_21_2 < arg_21_1 then
		arg_21_0._statistics._battleScore = var_0_3.BattleScore.S
	elseif arg_21_1 < arg_21_2 then
		arg_21_0._statistics._battleScore = var_0_3.BattleScore.D
	elseif arg_21_4 <= arg_21_3 then
		arg_21_0._statistics._battleScore = var_0_3.BattleScore.S
	elseif arg_21_3 < arg_21_4 then
		arg_21_0._statistics._battleScore = var_0_3.BattleScore.D
	end
end

function BattleDataProxy.CalcDuelScoreAtEnd(arg_22_0, arg_22_1, arg_22_2)
	arg_22_0._statistics._deadUnit = true
	arg_22_0._statistics._badTime = true

	local var_22_0 = arg_22_0._currentStageData.timeCount - arg_22_0._countDown

	arg_22_0._statistics._totalTime = var_22_0

	local var_22_1 = #arg_22_1:GetUnitList()
	local var_22_2 = #arg_22_2:GetUnitList()
	local var_22_3 = arg_22_0._expeditionTmp.sink_limit
	local var_22_4 = arg_22_0._expeditionTmp.time_limit

	if var_22_3 > arg_22_0._statistics._deadCount then
		arg_22_0._statistics._deadUnit = false
	end

	if var_22_1 == 0 then
		arg_22_0._statistics._battleScore = var_0_3.BattleScore.D
	elseif var_22_2 == 0 then
		arg_22_0._statistics._battleScore = var_0_3.BattleScore.S
	end

	arg_22_0._statistics._timeout = arg_22_0:isTimeOut()
end

function BattleDataProxy.CalcSimulationScoreAtEnd(arg_23_0, arg_23_1, arg_23_2)
	arg_23_0._statistics._deadUnit = true
	arg_23_0._statistics._badTime = true

	local var_23_0 = arg_23_0._currentStageData.timeCount - arg_23_0._countDown

	arg_23_0._statistics._totalTime = var_23_0

	local var_23_1 = #arg_23_1:GetUnitList()
	local var_23_2 = arg_23_1:GetMaxCount()
	local var_23_3 = #arg_23_1:GetScoutList()
	local var_23_4 = #arg_23_2:GetUnitList()
	local var_23_5 = arg_23_0._expeditionTmp.sink_limit
	local var_23_6 = arg_23_0._expeditionTmp.time_limit

	if arg_23_0._statistics._deadCount <= 0 then
		arg_23_0._statistics._deadUnit = false
	end

	if not arg_23_1:GetFlagShip():IsAlive() then
		arg_23_0._statistics._battleScore = var_0_3.BattleScore.D
		arg_23_0._statistics._scoreMark = var_0_3.DEAD_FLAG
	elseif var_23_3 == 0 then
		arg_23_0._statistics._battleScore = var_0_3.BattleScore.D
	elseif var_23_4 == 0 then
		arg_23_0._statistics._battleScore = var_0_3.BattleScore.S
	end

	arg_23_0._statistics._timeout = arg_23_0:isTimeOut()

	arg_23_0:overwriteRivalStatistics(arg_23_2)
end

function BattleDataProxy.CalcSimulationScoreAtTimesUp(arg_24_0, arg_24_1, arg_24_2, arg_24_3, arg_24_4, arg_24_5)
	arg_24_0._statistics._deadUnit = true
	arg_24_0._statistics._badTime = true
	arg_24_0._statistics._timeout = false

	local var_24_0 = arg_24_0._currentStageData.timeCount - arg_24_0._countDown

	arg_24_0._statistics._totalTime = var_24_0

	if arg_24_0._statistics._deadCount <= 0 then
		arg_24_0._statistics._deadUnit = false
	end

	arg_24_0._statistics._battleScore = var_0_3.BattleScore.D

	arg_24_0:overwriteRivalStatistics(arg_24_5)
end

function BattleDataProxy.overwriteRivalStatistics(arg_25_0, arg_25_1)
	for iter_25_0, iter_25_1 in pairs(arg_25_0._statistics._rivalInfo) do
		local var_25_0 = false

		for iter_25_2, iter_25_3 in ipairs(arg_25_1:GetUnitList()) do
			if iter_25_3:GetAttrByName("id") == iter_25_0 then
				iter_25_1.bp = math.ceil(iter_25_3:GetHPRate() * 10000)
				var_25_0 = true

				break
			end
		end

		if not var_25_0 then
			iter_25_1.bp = 0
		end
	end
end

function BattleDataProxy.CalcChallengeScore(arg_26_0, arg_26_1)
	if arg_26_1 then
		arg_26_0._statistics._battleScore = var_0_3.BattleScore.S
	else
		arg_26_0._statistics._battleScore = var_0_3.BattleScore.D
	end

	arg_26_0._statistics._totalTime = arg_26_0._totalTime
end

function BattleDataProxy.CalcDodgemCount(arg_27_0, arg_27_1)
	local var_27_0 = arg_27_1:GetDeathReason()
	local var_27_1 = arg_27_1:GetTemplate().type

	if var_27_0 == ys.Battle.BattleConst.UnitDeathReason.CRUSH then
		arg_27_0._dodgemStatistics.kill = arg_27_0._dodgemStatistics.kill + 1

		if var_27_1 == ShipType.JinBi then
			arg_27_0._dodgemStatistics.combo = arg_27_0._dodgemStatistics.combo + 1
			arg_27_0._dodgemStatistics.maxCombo = math.max(arg_27_0._dodgemStatistics.maxCombo, arg_27_0._dodgemStatistics.combo)

			local var_27_2 = arg_27_0._dodgemStatistics.score + arg_27_0:GetScorePoint()

			arg_27_0._dodgemStatistics.score = var_27_2

			arg_27_0:DispatchEvent(ys.Event.New(var_0_1.UPDATE_DODGEM_SCORE, {
				totalScore = var_27_2
			}))
		elseif var_27_1 == ShipType.ZiBao then
			arg_27_0._dodgemStatistics.fail = arg_27_0._dodgemStatistics.fail + 1
			arg_27_0._dodgemStatistics.combo = 0
		end

		arg_27_0:DispatchEvent(ys.Event.New(var_0_1.UPDATE_DODGEM_COMBO, {
			combo = arg_27_0._dodgemStatistics.combo
		}))
	elseif var_27_1 == ShipType.JinBi then
		arg_27_0._dodgemStatistics.miss = arg_27_0._dodgemStatistics.miss + 1
	end
end

function BattleDataProxy.GetScorePoint(arg_28_0)
	local var_28_0

	if arg_28_0._dodgemStatistics.combo == 1 then
		var_28_0 = 1
	elseif arg_28_0._dodgemStatistics.combo == 2 then
		var_28_0 = 2
	elseif arg_28_0._dodgemStatistics.combo > 2 then
		var_28_0 = 3
	end

	return var_28_0
end

function BattleDataProxy.CalcDodgemScore(arg_29_0)
	if arg_29_0._dodgemStatistics.score >= var_0_4.BATTLE_DODGEM_PASS_SCORE then
		arg_29_0._statistics._battleScore = var_0_3.BattleScore.S
	else
		arg_29_0._statistics._battleScore = var_0_3.BattleScore.B
	end

	arg_29_0._statistics.dodgemResult = arg_29_0._dodgemStatistics
end

function BattleDataProxy.CalcActBossDamageInfo(arg_30_0, arg_30_1)
	local var_30_0 = BattleDataFunction.GetSpecificEnemyList(arg_30_1, arg_30_0._expeditionID)

	arg_30_0:CalcSpecificEnemyInfo(var_30_0)
end

function BattleDataProxy.CalcWorldBossDamageInfo(self, actID, bossConfigID, bossLevel)
	local enemyID = BattleDataFunction.GetSpecificWorldJointEnemyList(actID, bossConfigID, bossLevel)

	self:CalcSpecificEnemyInfo(enemyID)
end

function BattleDataProxy.CalcGuildBossEnemyInfo(arg_32_0, arg_32_1)
	local var_32_0 = BattleDataFunction.GetSpecificGuildBossEnemyList(arg_32_1, arg_32_0._expeditionID)

	arg_32_0:CalcSpecificEnemyInfo(var_32_0)
end

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

function BattleDataProxy.CalcKillingSupplyShip(arg_34_0)
	arg_34_0._subRunStatistics.score = arg_34_0._subRunStatistics.score + 1
end

function BattleDataProxy.CalcSubRunTimeUp(arg_35_0)
	arg_35_0._statistics._battleScore = var_0_3.BattleScore.B
	arg_35_0._statistics.subRunResult = arg_35_0._subRunStatistics
end

function BattleDataProxy.CalcSubRunScore(arg_36_0)
	arg_36_0._statistics._battleScore = var_0_3.BattleScore.S
	arg_36_0._statistics.subRunResult = arg_36_0._subRunStatistics
end

function BattleDataProxy.CalcSubRunDead(arg_37_0)
	arg_37_0._statistics._battleScore = var_0_3.BattleScore.D
	arg_37_0._statistics.subRunResult = arg_37_0._subRunStatistics
end

function BattleDataProxy.CalcKillingSupplyShip(arg_38_0)
	arg_38_0._subRunStatistics.score = arg_38_0._subRunStatistics.score + 1
end

function BattleDataProxy.CalcSubRountineTimeUp(arg_39_0)
	arg_39_0._statistics._badTime = true

	arg_39_0:CalcSubRoutineScore()

	arg_39_0._statistics._battleScore = var_0_3.BattleScore.C
end

function BattleDataProxy.CalcSubRountineElimate(arg_40_0)
	arg_40_0._statistics._elimated = true

	arg_40_0:CalcSubRoutineScore()

	arg_40_0._statistics._battleScore = var_0_3.BattleScore.D
end

function BattleDataProxy.CalcSubRoutineScore(arg_41_0)
	local var_41_0 = arg_41_0._statistics._deadCount * var_0_4.SR_CONFIG.DEAD_POINT
	local var_41_1 = arg_41_0._subRunStatistics.score * var_0_4.SR_CONFIG.POINT
	local var_41_2 = (arg_41_0._statistics._badTime or arg_41_0._statistics._elimated) and 0 or var_0_4.SR_CONFIG.BASE_POINT
	local var_41_3 = var_41_2 + var_41_1 - var_41_0

	if var_41_3 >= var_0_4.SR_CONFIG.BASE_POINT + var_0_4.SR_CONFIG.M * var_0_4.SR_CONFIG.POINT then
		arg_41_0._statistics._battleScore = var_0_3.BattleScore.S
	elseif var_41_3 >= var_0_4.SR_CONFIG.BASE_POINT then
		arg_41_0._statistics._battleScore = var_0_3.BattleScore.A
	elseif var_41_3 >= var_0_4.SR_CONFIG.BASE_POINT - 2 * var_0_4.SR_CONFIG.DEAD_POINT then
		arg_41_0._statistics._battleScore = var_0_3.BattleScore.B
	else
		arg_41_0._statistics._battleScore = var_0_3.BattleScore.D
	end

	arg_41_0._subRunStatistics.basePoint = var_41_2
	arg_41_0._subRunStatistics.deadCount = arg_41_0._statistics._deadCount
	arg_41_0._subRunStatistics.losePoint = var_41_0
	arg_41_0._subRunStatistics.point = var_41_1
	arg_41_0._subRunStatistics.total = var_41_3
	arg_41_0._statistics.subRunResult = arg_41_0._subRunStatistics
end

function BattleDataProxy.AirFightInit(arg_42_0)
	arg_42_0._statistics._airFightStatistics = {}
	arg_42_0._statistics._airFightStatistics.kill = 0
	arg_42_0._statistics._airFightStatistics.score = 0
	arg_42_0._statistics._airFightStatistics.hit = 0
	arg_42_0._statistics._airFightStatistics.lose = 0
	arg_42_0._statistics._airFightStatistics.total = 0
end

function BattleDataProxy.AddAirFightScore(arg_43_0, arg_43_1)
	arg_43_0._statistics._airFightStatistics.score = arg_43_0._statistics._airFightStatistics.score + arg_43_1
	arg_43_0._statistics._airFightStatistics.kill = arg_43_0._statistics._airFightStatistics.kill + 1
	arg_43_0._statistics._airFightStatistics.total = math.max(arg_43_0._statistics._airFightStatistics.score - arg_43_0._statistics._airFightStatistics.lose, 0)

	arg_43_0:DispatchEvent(ys.Event.New(var_0_1.UPDATE_DODGEM_SCORE, {
		totalScore = arg_43_0._statistics._airFightStatistics.total
	}))
end

function BattleDataProxy.DecreaseAirFightScore(arg_44_0, arg_44_1)
	arg_44_0._statistics._airFightStatistics.lose = arg_44_0._statistics._airFightStatistics.lose + arg_44_1
	arg_44_0._statistics._airFightStatistics.hit = arg_44_0._statistics._airFightStatistics.hit + 1
	arg_44_0._statistics._airFightStatistics.total = math.max(arg_44_0._statistics._airFightStatistics.score - arg_44_0._statistics._airFightStatistics.lose, 0)

	arg_44_0:DispatchEvent(ys.Event.New(var_0_1.UPDATE_DODGEM_SCORE, {
		totalScore = arg_44_0._statistics._airFightStatistics.total
	}))
end

function BattleDataProxy.CalcAirFightScore(arg_45_0)
	arg_45_0._statistics._battleScore = var_0_3.BattleScore.S
end

function BattleDataProxy.AddScenarioSubStrikeBoss(arg_46_0, arg_46_1)
	arg_46_0._statistics._scenarioSubStrikebossUnit = arg_46_1
end

function BattleDataProxy.CalcScenarioSubStrikeScoreAtEnd(arg_47_0)
	local var_47_0 = arg_47_0._statistics._scenarioSubStrikebossUnit

	if not var_47_0 then
		arg_47_0._statistics._bossHP = 1
		arg_47_0._statistics._battleScore = var_0_3.BattleScore.C
	elseif not var_47_0:IsAlive() then
		arg_47_0._statistics._battleScore = var_0_3.BattleScore.S
		arg_47_0._statistics._bossHP = 0
	else
		local var_47_1 = var_47_0:GetHPRate()
		local var_47_2 = arg_47_0._expeditionTmp.objective_2[2] * 0.01
		local var_47_3 = arg_47_0._expeditionTmp.objective_3[2] * 0.01

		if var_47_1 < var_47_2 then
			arg_47_0._statistics._battleScore = var_0_3.BattleScore.A
		elseif var_47_2 <= var_47_1 and var_47_1 < var_47_3 then
			arg_47_0._statistics._battleScore = var_0_3.BattleScore.B
		elseif var_47_3 <= var_47_1 then
			arg_47_0._statistics._battleScore = var_0_3.BattleScore.C
		end

		arg_47_0._statistics._bossHP = var_47_1
	end

	local var_47_4 = 0

	for iter_47_0, iter_47_1 in pairs(arg_47_0._statistics) do
		if type(iter_47_1) == "table" and iter_47_1.id and iter_47_1.damage and var_47_4 < iter_47_1.damage then
			var_47_4 = iter_47_1.damage
			arg_47_0._statistics.mvpShipID = iter_47_1.id
		end
	end
end

function BattleDataProxy.AutoStatistics(arg_48_0, arg_48_1)
	if not arg_48_0._statistics._autoInit then
		arg_48_0._statistics._autoInit = not arg_48_1 and 1 or 0
	else
		arg_48_0._statistics._autoCount = arg_48_0._statistics._autoCount + 1
	end
end
