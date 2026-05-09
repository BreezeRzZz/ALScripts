--- @class BattleGatePerform : 回忆/表演关Gate，支持memory模式和普通发送请求模式
local BattleGatePerform = class("BattleGatePerform")

ys.Battle.BattleGatePerform = BattleGatePerform
BattleGatePerform.__name = "BattleGatePerform"

--- 进入表演战斗
--- @param self BattleGatePerform
--- @param sendData table 发送数据
function BattleGatePerform.Entrance(self, sendData)
	local stageId = self.stageId
	local dungeonTemplateID = pg.expedition_data_template[stageId].dungeon_id
	local fleetPrefab = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonTemplateID).fleet_prefab or {}
	local shipIdList = {}

	if self.mainFleetId then
		local bayProxy = getProxy(BayProxy)
		local fleetProxy = getProxy(FleetProxy)

		if not sendData.LegalFleet(self.mainFleetId) then
			return
		end

		local fleet = fleetProxy:getFleetById(self.mainFleetId)
		local sortShips = bayProxy:getSortShipsByFleet(fleet)

		for _, ship in ipairs(sortShips) do
			shipIdList[#shipIdList + 1] = ship.id
		end
	end

	local stageData = {
		stageId = stageId,
		system = SYSTEM_PERFORM,
		memory = self.memory,
		exitCallback = self.exitCallback,
		prefabFleet = fleetPrefab,
		mainFleetId = self.mainFleetId
	}

	if self.memory then
		-- memory模式直接发送进入
		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	else
		-- 普通模式先发Story更新再发BeginStage
		local function onSuccess(tokenData)
			sendData:sendNotification(GAME.STORY_UPDATE, {
				storyId = tostring(stageId)
			})

			stageData.token = tokenData.key

			sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
		end

		local function onFail(errData)
			sendData:RequestFailStandardProcess(errData)
		end

		BeginStageCommand.SendRequest(SYSTEM_PERFORM, shipIdList, {
			stageId
		}, onSuccess, onFail)
	end
end

--- 退出表演战斗
--- @param self BattleGatePerform
--- @param callback table 回调对象
function BattleGatePerform.Exit(self, callback)
	if self.memory then
		-- memory模式直接结束
		callback:sendNotification(GAME.FINISH_STAGE_DONE, {
			system = SYSTEM_PERFORM
		})
	else
		-- 普通模式需要发包结算
		local generalPackage = callback.GeneralPackage(self, {})

		local function onSuccess(result)
			print(self.exitCallback)
			callback:sendNotification(GAME.FINISH_STAGE_DONE, {
				system = SYSTEM_PERFORM,
				exitCallback = self.exitCallback
			})
		end

		local function onFail(errData)
			callback:RequestFailStandardProcess(errData)
		end

		callback:SendRequest(generalPackage, onSuccess, onFail)
	end
end

return BattleGatePerform
