ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent

ys.Battle.CardPuzzleMovePile = class("CardPuzzleMovePile")

local CardPuzzleMovePile = ys.Battle.CardPuzzleMovePile

CardPuzzleMovePile.__name = "CardPuzzleMovePile"

--- 卡牌拼图移动牌堆视图
--- 显示"移动"卡牌堆的数量和生成进度（类似抽卡牌堆的另一种表现）

function CardPuzzleMovePile.Ctor(self, go)
	self._go = go

	self:init()
end

--- 设置关联的卡牌拼图组件
function CardPuzzleMovePile.SetCardPuzzleComponent(self, cardPuzzleInfo)
	self._cardPuzzleInfo = cardPuzzleInfo
	self._moveDeck = self._cardPuzzleInfo:GetMoveDeck()

	self._moveDeck:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_CARDS, self.onUpdateMoveCards)
	self:onUpdateMoveCards()
end

--- 移动牌堆卡牌更新回调
function CardPuzzleMovePile.onUpdateMoveCards(self, event)
	setText(self._moveCountLabel, "X" .. self._moveDeck:GetLength())
end

function CardPuzzleMovePile.Update(self)
	return
end

function CardPuzzleMovePile.init(self)
	ys.EventListener.AttachEventListener(self)

	self._tf = self._go.transform
	self._btnTF = self._tf:Find("card")
	self._moveCountLabel = self._btnTF:Find("count")
	self._moveProgress = self._btnTF:Find("progress"):GetComponent(typeof(Image))
	self._moveProgress.fillAmount = 1
end

--- 更新移动卡牌生成进度
function CardPuzzleMovePile.updateMoveProgress(self)
	local progress = self._moveDeck:GetGeneratePorcess()

	if progress ~= self._progressCache then
		self._moveProgress.fillAmount = progress
	end

	self._progressCache = progress
end

function CardPuzzleMovePile.Dispose(self)
	self._moveCountLabel = nil
	self._moveProgress = nil
	self._btnTF = nil
	self._tf = nil
end
