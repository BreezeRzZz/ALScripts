--- @class BattleGateTest : 测试模式Gate
local BattleGateTest = class("BattleGateTest")

ys.Battle.BattleGateTest = BattleGateTest
BattleGateTest.__name = "BattleGateTest"

--- 进入测试战斗
--- @param self BattleGateTest
--- @param sendData table 发送数据
function BattleGateTest.Entrance(self, sendData)
	if not sendData.LegalFleet(self.mainFleetId) then
		return
	end

	local bayProxy = getProxy(BayProxy)
	local fleetProxy = getProxy(FleetProxy)
	local shipIdList = {}
	local fleet = fleetProxy:getFleetById(self.mainFleetId)
	local sortShips = bayProxy:getSortShipsByFleet(fleet)

	for _, ship in ipairs(sortShips) do
		shipIdList[#shipIdList + 1] = ship.id
	end

	local mainFleetId = self.mainFleetId
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id

	--- 发送请求成功的回调
	local function onSuccess(tokenData)
		local stageData = {
			mainFleetId = mainFleetId,
			prefabFleet = {},
			stageId = stageId,
			system = SYSTEM_TEST,
			token = tokenData.key
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end

	--- 发送请求失败的回调
	local function onFail(errData)
		sendData:RequestFailStandardProcess(errData)
	end

	BeginStageCommand.SendRequest(SYSTEM_TEST, shipIdList, {
		stageId
	}, onSuccess, onFail)
end

--- 退出测试战斗
--- @param self BattleGateTest
--- @param callback table 回调对象
function BattleGateTest.Exit(self, callback)
	local costTemplate = pg.battle_cost_template[SYSTEM_TEST]
	local fleetProxy = getProxy(FleetProxy)
	local bayProxy = getProxy(BayProxy)
	local battleScore = self.statistics._battleScore
	local oilUsed = 0
	local shipList = {}
	local fleet = fleetProxy:getFleetById(self.mainFleetId)
	local sortShips = bayProxy:getSortShipsByFleet(fleet)
	local generalPackage = callback.GeneralPackage(self, sortShips)

	--- 结算成功的回调
	local function onSuccess(result)
		self.statistics.mvpShipID = -1

		local finishData = {
			system = SYSTEM_TEST,
			statistics = self.statistics,
			score = battleScore,
			drops = {},
			commanderExps = {},
			result = result.result,
			extraDrops = {}
		}

		callback:sendNotification(GAME.FINISH_STAGE_DONE, finishData)
	end

	callback:SendRequest(generalPackage, onSuccess)
end

return BattleGateTest
