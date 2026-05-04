ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent

ys.Battle.CardPuzzleDeckPool = class("CardPuzzleDeckPool")

local CardPuzzleDeckPool = ys.Battle.CardPuzzleDeckPool

CardPuzzleDeckPool.__name = "CardPuzzleDeckPool"

--- 卡牌拼图牌组视图
--- 显示当前牌组中剩余卡牌数量的UI

function CardPuzzleDeckPool.Ctor(self, go)
	self._go = go

	self:init()
end

--- 设置关联的卡牌拼图组件，注册牌组更新事件
function CardPuzzleDeckPool.SetCardPuzzleComponent(self, cardPuzzleInfo)
	self._cardPuzzleInfo = cardPuzzleInfo
	self._deck = self._cardPuzzleInfo:GetDeck()

	self._deck:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_CARDS, self.onUpdateDeckCard)
	self:onUpdateDeckCard()
end

--- 牌组卡牌更新回调
function CardPuzzleDeckPool.onUpdateDeckCard(self, event)
	setText(self._deckCountLabel, self._deck:GetLength())
end

function CardPuzzleDeckPool.init(self)
	ys.EventListener.AttachEventListener(self)

	self._tf = self._go.transform
	self._deckCountLabel = self._tf:Find("count/text")

	setText(self._tf:Find("label"), i18n("card_puzzle_deck"))
end

function CardPuzzleDeckPool.Dispose(self)
	self._deckCountLabel = nil
	self._tf = nil
end
