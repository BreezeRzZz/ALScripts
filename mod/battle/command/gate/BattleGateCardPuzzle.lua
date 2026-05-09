--- @class BattleGateCardPuzzle : 卡牌谜题Gate
local BattleGateCardPuzzle = class("BattleGateCardPuzzle")

ys.Battle.BattleGateCardPuzzle = BattleGateCardPuzzle
BattleGateCardPuzzle.__name = "BattleGateCardPuzzle"

--- 进入卡牌谜题战斗
--- @param self BattleGateCardPuzzle
--- @param sendData table 发送数据
function BattleGateCardPuzzle.Entrance(self, sendData)
	local combatID = self.combatID
	local dungeonTemplate = ys.Battle.BattleDataFunction.GetPuzzleDungeonTemplate(combatID)
	local dungeonId = dungeonTemplate.dungeon_id
	local fleetData = {
		CardPuzzleShip.New({
			configId = dungeonTemplate.scout_id
		}),
		CardPuzzleShip.New({
			configId = dungeonTemplate.main_id
		})
	}
	local deckCards = dungeonTemplate.deck
	local relicList = {}

	for _, relicId in ipairs(dungeonTemplate.relic) do
		table.insert(relicList, CardPuzzleGift.New({
			configId = relicId
		}))
	end

	-- 立即构造并发送战斗数据
	;(function()
		local stageData = {
			hp = 1,
			cardPuzzleFleet = fleetData,
			prefabFleet = {},
			cards = deckCards,
			relics = relicList,
			stageId = dungeonId,
			system = SYSTEM_CARDPUZZLE,
			puzzleCombatID = combatID
		}

		sendData:sendNotification(GAME.BEGIN_STAGE_DONE, stageData)
	end)()
end

--- 退出卡牌谜题，S评分以上触发活动卡片谜题通知
--- @param self BattleGateCardPuzzle
--- @param callback table 回调对象
function BattleGateCardPuzzle.Exit(self, callback)
	local score = self.statistics._battleScore

	if score >= ys.Battle.BattleConst.BattleScore.S then
		local cardPuzzleActivity = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_CARD_PUZZLE)

		callback:sendNotification(GAME.ACT_CARD_PUZZLE, {
			cmd = 1,
			activity_id = cardPuzzleActivity and cardPuzzleActivity.id,
			arg1 = self.puzzleCombatID
		})
	end

	local result = {
		system = SYSTEM_CARDPUZZLE,
		score = score
	}

	callback:sendNotification(GAME.FINISH_STAGE_DONE, result)
end

--- 获取预加载资源列表
--- @param self BattleGateCardPuzzle
--- @return table shipResources, table skinResources
function BattleGateCardPuzzle.GetPreloadList(self)
	local resList = {}
	local skinList = {}
	local resMgr = ys.Battle.BattleResourceManager.GetInstance()
	local cards = self.cards

	-- 加载卡牌效果资源
	for _, cardId in ipairs(cards) do
		local effectId = ys.Battle.BattleDataFunction.GetPuzzleCardDataTemplate(cardId).effect[1]
		local cardResList = ys.Battle.BattleDataFunction.GetCardRes(effectId)

		for _, res in ipairs(cardResList) do
			table.insert(cardResList, res)
		end
	end

	-- 加载舰船资源
	for _, shipData in ipairs(self.cardPuzzleFleet) do
		local shipConfigId = shipData:getConfig("id")
		local shipTemplate = ys.Battle.BattleDataFunction.GetPuzzleShipDataTemplate(shipConfigId)

		table.insert(skinList, shipTemplate.skin_id)
		table.insert(resList, resMgr.GetShipResource(shipTemplate.id, shipTemplate.skin_id, true))
	end

	table.insert(resList, resMgr.GetUIPath("CardTowerCardCombat"))
	table.insert(resList, resMgr.GetFXPath("kapai_weizhi"))

	return resList, skinList
end

return BattleGateCardPuzzle
