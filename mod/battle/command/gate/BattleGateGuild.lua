--- @class BattleGateGuild : 公会Boss战斗Gate，包含自定义的SendRequest和结算逻辑
local BattleGateGuild = class("BattleGateGuild")

ys.Battle.BattleGateGuild = BattleGateGuild
BattleGateGuild.__name = "BattleGateGuild"

--- 进入公会Boss战斗
--- @param self BattleGateGuild
--- @param sendData table BeginStageCommand实例
function BattleGateGuild.Entrance(self, sendData)
	local oilCost = pg.guildset.use_oil.key_value
	local playerData = getProxy(PlayerProxy):getRawData()

	if oilCost > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	local bossMission = BattleGateGuild.GetGuildBossMission()
	local myShipIds = bossMission:GetMyShipIds()
	local shipsSplitByUser = bossMission:GetShipsSplitByUserID()
	local shipUserMap = {}

	for _, splitInfo in ipairs(shipsSplitByUser) do
		table.insert(shipUserMap, {
			ship_id = splitInfo.shipID,
			user_id = splitInfo.userID
		})
	end

	local stageId = bossMission:GetStageID()

	--- 服务器验证成功回调
	local function onServerSuccess(tokenData)
		local stageData = {
			prefabFleet = {},
			bossId = bossMission.id,
			actId = bossMission.id,
			stageId = stageId,
			system = SYSTEM_GUILD,
			token = tokenData.key
		}
		local guildProxy = getProxy(GuildProxy)
		local guildData = guildProxy:getData()
		local livenessValue = pg.guildset.operation_boss_guild_active.key_value

		guildData:getMemberById(playerData.id):AddLiveness(livenessValue)
		guildProxy:updateGuild(guildData)
		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败回调
	local function onServerFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_GUILD, myShipIds, {
		stageId
	}, onServerSuccess, onServerFail, shipUserMap)
end

--- 退出公会Boss，处理伤害统计、指挥官经验和结算
--- @param self BattleGateGuild
--- @param callback table 回调对象
function BattleGateGuild.Exit(self, callback)
	local fleetProxy = getProxy(FleetProxy)
	local battleScore = self.statistics._battleScore
	local oilCost = pg.guildset.use_oil.key_value
	local shipList = {}
	local bossMission = BattleGateGuild.GetGuildBossMission()
	local mainFleet = bossMission:GetMainFleet()
	local commanderIdList = {}

	for _, commander in pairs(mainFleet:getCommanders()) do
		table.insert(commanderIdList, commander.id)
	end

	local mainShips = mainFleet:GetShips()

	for _, shipEntry in ipairs(mainShips) do
		table.insert(shipList, shipEntry.ship)
	end

	if self.statistics.submarineAid then
		local subFleet = bossMission:GetSubFleet()

		if subFleet then
			local subShips = subFleet:GetShips()

			for _, shipEntry in ipairs(subShips) do
				local ship = shipEntry.ship

				if self.statistics[ship.id] then
					table.insert(shipList, ship)
				end
			end

			for _, commander in pairs(subFleet:getCommanders()) do
				table.insert(commanderIdList, commander.id)
			end
		else
			originalPrint("finish stage error: can not find submarin fleet.")
		end
	end

	-- 计算MVP（最高输出）
	local maxOutput = 0
	local mvpShipId = 0

	for _, ship in ipairs(shipList) do
		local shipStat = self.statistics[ship.id]

		if maxOutput < shipStat.output then
			mvpShipId = ship.id
			maxOutput = shipStat.output
		end
	end

	local generalPackage = BattleGateGuild.GeneralPackage(self, shipList)

	generalPackage.commander_id_list = commanderIdList

	--- 结算成功回调
	local function onFinishSuccess(serverResult)
		self.statistics.mvpShipID = mvpShipId

		local drops, extraDrops = callback:GeneralLoot(serverResult)
		local isWin = battleScore > ys.Battle.BattleConst.BattleScore.C
		local commanderExp = callback.GenerateCommanderExp(serverResult, mainFleet, bossMission:GetSubFleet())

		BattleGateGuild.GeneralPlayerCosume(SYSTEM_GUILD, isWin, oilCost, serverResult.player_exp, exFlag)

		local finishData = {
			system = SYSTEM_GUILD,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = commanderExp,
			result = serverResult.result,
			extraDrops = extraDrops
		}

		BattleGateGuild.UpdateGuildBossMission()
		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	BattleGateGuild.SendRequest(callback, generalPackage, onFinishSuccess)
end

--- 发送公会战斗请求（自定义协议 40003/40004）
--- @param self BattleGateGuild
--- @param sendData table 数据包
--- @param callbackFn function 成功回调
function BattleGateGuild.SendRequest(self, sendData, callbackFn)
	pg.ConnectionMgr.GetInstance():Send(40003, sendData, 40004, function(response)
		if response.result == 0 or response.result == 1030 then
			callbackFn(response)
		elseif response.result == 20 then
			pg.MsgboxMgr.GetInstance():ShowMsgBox({
				hideNo = true,
				content = i18n("guild_battle_result_boss_is_death"),
				onYes = function()
					pg.m02:sendNotification(GAME.QUIT_BATTLE)
				end
			})
		elseif response.result == 4 then
			pg.m02:sendNotification(GAME.QUIT_BATTLE)
		else
			self:RequestFailStandardProcess(response)
		end
	end)
end

--- 获取当前公会Boss任务
--- @return table bossMission
function BattleGateGuild.GetGuildBossMission()
	local activeEvent = getProxy(GuildProxy):getData():GetActiveEvent()

	assert(activeEvent)

	local bossMission = activeEvent:GetBossMission()

	assert(bossMission)

	return bossMission
end

--- 更新公会Boss任务状态（减少次数等）
function BattleGateGuild.UpdateGuildBossMission()
	local guildProxy = getProxy(GuildProxy)
	local guildData = guildProxy:getData()
	local activeEvent = guildData:GetActiveEvent()

	assert(activeEvent)

	local bossMission = activeEvent:GetBossMission()

	assert(bossMission)
	bossMission:ReduceDailyCnt()
	guildProxy:ResetBossRankTime()
	guildProxy:ResetRefreshBossTime()
	guildProxy:updateGuild(guildData)
end

--- 通用玩家消耗处理（公会专用）
--- @param system number 战斗系统类型
--- @param isWin boolean 是否胜利
--- @param oilCost number 油耗
--- @param playerExp number 玩家经验
--- @param exFlag boolean 额外标记
function BattleGateGuild.GeneralPlayerCosume(system, isWin, oilCost, playerExp, exFlag)
	local playerProxy = getProxy(PlayerProxy)
	local playerData = playerProxy:getData()

	playerData:addExp(playerExp)
	playerData:consume({
		gold = 0,
		oil = oilCost
	})
	playerProxy:updatePlayer(playerData)
end

--- 生成通用结算数据包（公会专用，含校验）
--- @param self BattleGateGuild
--- @param shipList table 舰船列表
--- @return table generalPackage
function BattleGateGuild.GeneralPackage(self, shipList)
	local combatPower = 0
	local selfShipStats = {}
	local otherShipStats = {}
	local system = self.system
	local stageId = self.stageId
	local battleScore = self.statistics._battleScore
	local checkSeed = system + stageId + battleScore
	local playerId = getProxy(PlayerProxy):getRawData().id

	for _, ship in ipairs(shipList) do
		local shipStat = self.statistics[ship.id]

		if shipStat then
			local realShipId = GuildAssaultFleet.GetRealId(shipStat.id)
			local userId = GuildAssaultFleet.GetUserId(shipStat.id)
			local hpRest = math.floor(shipStat.bp)
			local damageOutput = math.floor(shipStat.output)
			local damageCaused = math.max(0, math.floor(shipStat.damage))
			local maxDamageOnce = math.floor(shipStat.maxDamageOnce)
			local gearScore = math.floor(shipStat.gearScore)
			local targetList = userId ~= playerId and otherShipStats or selfShipStats

			table.insert(targetList, {
				ship_id = realShipId,
				hp_rest = hpRest,
				damage_cause = damageOutput,
				damage_caused = damageCaused,
				max_damage_once = maxDamageOnce,
				ship_gear_score = gearScore
			})

			checkSeed = checkSeed + realShipId + hpRest + damageOutput + maxDamageOnce
			combatPower = combatPower + ship:getShipCombatPower()
		end
	end

	local checkKey, fileCheck = GetBattleCheckResult(checkSeed, self.token, self.statistics._totalTime)
	local enemyInfoList = {}

	for _, enemy in ipairs(self.statistics._enemyInfoList) do
		table.insert(enemyInfoList, {
			enemy_id = enemy.id,
			damage_taken = enemy.damage,
			total_hp = enemy.totalHp
		})
	end

	local autoMod = math.fmod(self.statistics._autoCount, 2)
	local autoAfterMod = math.fmod(autoMod + self.statistics._autoInit, 2)

	return {
		system = system,
		data = stageId,
		score = battleScore,
		key = checkKey,
		statistics = selfShipStats,
		otherstatistics = otherShipStats,
		kill_id_list = self.statistics.kill_id_list,
		total_time = self.statistics._totalTime,
		bot_percentage = self.statistics._botPercentage,
		extra_param = combatPower,
		file_check = fileCheck,
		enemy_info = enemyInfoList,
		data2 = {},
		auto_before = self.statistics._autoInit,
		auto_switch_time = self.statistics._autoCount,
		auto_after = autoAfterMod
	}
end

--- 获取预加载资源列表
--- @param self BattleGateGuild
--- @return table shipResources, table skinResources
function BattleGateGuild.GetPreloadList(self)
	local shipList = {}
	local buffList = {}
	local skinList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local bossMission = getProxy(GuildProxy):getRawData():GetActiveEvent():GetBossMission()
	local mainFleet = bossMission:GetMainFleet()
	local mainShips = mainFleet:GetShips()

	for _, shipEntry in ipairs(mainShips) do
		if shipEntry and shipEntry.ship then
			table.insert(shipList, shipEntry.ship)
		end
	end

	local mainBuffs = mainFleet:BuildBattleBuffList()
	local subFleet = bossMission:GetSubFleet()
	local subShips = subFleet:GetShips()

	for _, shipEntry in ipairs(subShips) do
		if shipEntry and shipEntry.ship then
			table.insert(shipList, shipEntry.ship)
		end
	end

	local subBuffs = subFleet:BuildBattleBuffList()

	for _, buff in ipairs(subBuffs) do
		table.insert(mainBuffs, buff)
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local commanderBuffs = resMgr.GetCommanderBuffRes(mainBuffs)

	for _, res in ipairs(commanderBuffs) do
		table.insert(shipResources, res)
	end

	return shipResources, skinResources
end

return BattleGateGuild
