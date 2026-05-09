--- @class BattleGateWorldBossSimulate : 世界Boss模拟战Gate（不消耗资源，不发送请求）
local BattleGateWorldBossSimulate = class("BattleGateWorldBossSimulate")

ys.Battle.BattleGateWorldBossSimulate = BattleGateWorldBossSimulate
BattleGateWorldBossSimulate.__name = "BattleGateWorldBossSimulate"

--- 进入世界Boss模拟战（直接本地进入，不发送服务器请求）
--- @param self BattleGateWorldBossSimulate
--- @param sendData table 发送数据
function BattleGateWorldBossSimulate.Entrance(self, sendData)
	if BeginStageCommand.DockOverload() then
		return
	end

	local actId = self.actId
	local playerProxy = getProxy(PlayerProxy)
	local bayProxy = getProxy(BayProxy)
	local shipIdList = {}
	local oilCost = 0
	local oilSum = 0
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
	local bossLevel
	local bossLevelID
	local bossTemplate = pg.world_joint_boss_template[bossId]

	if WorldBossConst.GetCurrBossID() == bossId then
		bossLevel = bossProxy.currentBossLV
		bossLevelID = bossTemplate.boss_level_id + bossProxy.currentBossLV - 1
	else
		bossLevel = 15
		bossLevelID = bossTemplate.boss_level_id + 14
	end

	local expeditionId = pg.world_boss_level[bossLevelID].expedition_id

	sendData.ShipVertify()

	local stageData = {
		isSimulate = true,
		prefabFleet = {},
		bossId = bossId,
		actId = actId,
		stageId = expeditionId,
		system = SYSTEM_WORLD_BOSS,
		bossLevel = bossLevel,
		bossConfigId = bossId,
		hpRate = hpRate
	}

	sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
end

--- 退出世界Boss模拟战（不发送服务器请求，仅本地结算）
--- @param self BattleGateWorldBossSimulate
--- @param callback table 回调对象
function BattleGateWorldBossSimulate.Exit(self, callback)
	local score = self.statistics._battleScore

	self.statistics.mvpShipID = -1

	local result = {
		result = 0,
		system = SYSTEM_WORLD_BOSS,
		statistics = self.statistics,
		score = score,
		drops = {},
		commanderExps = {},
		extraDrops = {},
		bossId = self.bossId,
		name = name
	}

	callback:sendNotification(GAME.FINISH_STAGE_DONE, result)
end

return BattleGateWorldBossSimulate
