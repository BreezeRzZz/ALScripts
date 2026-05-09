--- @class BattleGateWorldBoss : 大世界Boss战斗Gate
local BattleGateWorldBoss = class("BattleGateWorldBoss")

ys.Battle.BattleGateWorldBoss = BattleGateWorldBoss
BattleGateWorldBoss.__name = "BattleGateWorldBoss"

--- 进入大世界Boss战斗
--- @param self BattleGateWorldBoss
--- @param sendData table BeginStageCommand实例
function BattleGateWorldBoss.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local costTemplate = pg.battle_cost_template[SYSTEM_WORLD_BOSS]
	local hasOilCost = true
	local shipIdList = {}
	local goldCost = 0
	local oilCost = 0
	local world = nowWorld()
	local fleet = world:GetBossProxy():GetFleet(self.bossId)
	local fleetShips = fleet.ships

	for _, shipId in ipairs(fleetShips) do
		shipIdList[#shipIdList + 1] = shipId
	end

	local sortShips = bayProxy:getSortShipsByFleet(fleet)
	local playerData = playerProxy:getData()
	local bossId = self.bossId
	local hpRate = self.hpRate
	local bossProxy = world:GetBossProxy()
	local bossData = bossProxy:GetBossById(bossId)
	local stageId = bossData:GetStageID()

	if bossProxy:IsSelfBoss(bossData) and bossData:GetSelfFightCnt() > 0 then
		oilCost = bossData:GetOilConsume()
	end

	if hasOilCost and oilCost > playerData.oil then
		pg.TipsMgr.GetInstance():ShowTips(i18n("stage_beginStage_error_noResource"))

		return
	end

	sendData.ShipVertify()

	--- 服务器验证成功回调
	local function onServerSuccess(tokenData)
		if hasOilCost then
			playerData:consume({
				gold = 0,
				oil = oilCost
			})
		end

		if costTemplate.enter_energy_cost > 0 then
			local energyCost = pg.gameset.battle_consume_energy.key_value

			for _, ship in ipairs(sortShips) do
				ship:cosumeEnergy(energyCost)
				bayProxy:updateShip(ship)
			end
		end

		if bossProxy:IsSelfBoss(bossData) then
			bossData:IncreaseFightCnt()
		else
			if WorldBossConst._IsCurrBoss(bossData) then
				bossProxy:reducePt()
			end

			bossProxy:LockCacheBoss(bossId)
		end

		playerProxy:updatePlayer(playerData)

		local stageData = {
			prefabFleet = {},
			bossId = bossId,
			actId = actId,
			stageId = stageId,
			system = SYSTEM_WORLD_BOSS,
			token = tokenData.key,
			bossLevel = bossData:GetLevel(),
			bossConfigId = bossData:GetConfigID(),
			hpRate = hpRate
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 服务器验证失败回调，根据不同错误码处理Boss缓存解锁
	local function onServerFail(errData)
		--- 解锁并移除缓存的Boss
		local function unlockBoss()
			bossProxy:UnlockCacheBoss()
			bossProxy:RemoveCacheBoss(bossData.id)
			pg.m02:sendNotification(GAME.WORLD_BOSS_START_BATTLE_FIALED)
		end

		if errData.result == 1 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("world_boss_none"))
			unlockBoss()
		elseif errData.result == 3 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("world_boss_none"))
			unlockBoss()
		elseif errData.result == 6 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("world_max_challenge_cnt"))
			unlockBoss()
		elseif errData.result == 20 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("world_boss_none"))
			unlockBoss()
		elseif errData.result == 9997 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("world_boss_maintenance"))
			unlockBoss()
		else
			sendData:RequestFailStandardProcess(errData)
			pg.TipsMgr.GetInstance():ShowTips(ERROR_MESSAGE[errData.result] .. errData.result)
		end
	end

	BeginStageCommand.SendRequest(SYSTEM_WORLD_BOSS, shipIdList, {
		bossId
	}, onServerSuccess, onServerFail)
end

--- 退出大世界Boss，处理伤害排行和结算
--- @param self BattleGateWorldBoss
--- @param callback table 回调对象
function BattleGateWorldBoss.Exit(self, callback)
	if callback.CheaterVertify() then
		return
	end

	local costTemplate = pg.battle_cost_template[SYSTEM_WORLD_BOSS]
	local battleScore = self.statistics._battleScore
	local extraParam = {}
	local bossFleet = nowWorld():GetBossProxy():GetFleet(self.bossId)
	local sortShips = getProxy(BayProxy):getSortShipsByFleet(bossFleet)
	local generalPackage = callback.GeneralPackage(self, sortShips)
	local maxEnemyDamage = 0
	local enemyInfoList = {}

	for _, enemy in ipairs(self.statistics._enemyInfoList) do
		table.insert(enemyInfoList, {
			enemy_id = enemy.id,
			damage_taken = enemy.damage,
			total_hp = enemy.totalHp
		})

		if maxEnemyDamage < enemy.damage then
			maxEnemyDamage = enemy.damage
		end
	end

	generalPackage.enemy_info = enemyInfoList

	--- 结算成功回调
	local function onFinishSuccess(serverResult)
		local drops, extraDrops = callback:GeneralLoot(serverResult)

		callback.addShipsExp(serverResult.ship_exp_list, self.statistics, accumulate)

		local bossProxy = nowWorld():GetBossProxy()
		local bossData = bossProxy:GetBossById(self.bossId)
		local bossName = bossData:GetName()

		bossProxy:ClearRank(bossData.id)
		bossProxy:UpdateHighestDamage(maxEnemyDamage)

		self.statistics.mvpShipID = serverResult.mvp

		local finishData = {
			system = SYSTEM_WORLD_BOSS,
			statistics = self.statistics,
			score = battleScore,
			drops = drops,
			commanderExps = {},
			result = serverResult.result,
			extraDrops = extraDrops,
			bossId = self.bossId,
			name = bossName
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
		bossProxy:UnlockCacheBoss()
	end

	callback:SendRequest(generalPackage, onFinishSuccess)
end

--- 获取预加载资源列表
--- @param self BattleGateWorldBoss
--- @return table shipResources, table skinResources
function BattleGateWorldBoss.GetPreloadList(self)
	local shipList = {}
	local skinList
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local bossProxy = nowWorld():GetBossProxy()
	local fleet = bossProxy:GetFleet(self.bossId)
	local sortShips = getProxy(BayProxy):getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		table.insert(shipList, ship)
	end

	local shipResources, skinResources = resMgr.GetPlayerShipResource(shipList, self.system)
	local bossData = bossProxy:GetBossById(self.bossId)

	if bossData and bossData:IsSelf() then
		local hasSupport, supportLevel, supportBuffId = bossProxy.GetSupportValue()

		if hasSupport then
			local supportRes = resMgr.GetResFromBuffIDList({
				supportBuffId
			})

			for _, res in ipairs(supportRes) do
				table.insert(shipResources, res)
			end
		end
	end

	return shipResources, skinResources
end

return BattleGateWorldBoss
