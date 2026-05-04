ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleConfig = ys.Battle.BattleCardPuzzleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent

ys.Battle.CardPuzzleHandBoard = class("CardPuzzleHandBoard")

local CardPuzzleHandBoard = ys.Battle.CardPuzzleHandBoard

CardPuzzleHandBoard.__name = "CardPuzzleHandBoard"
-- 手牌间隔（像素）
CardPuzzleHandBoard.BASE_GAP = 166
-- 手牌相对渲染层级偏移
CardPuzzleHandBoard.BASE_SIBLING = 4

--- 卡牌拼图手牌面板
--- 管理玩家手牌的显示、拖拽、出牌、回收等核心交互逻辑

function CardPuzzleHandBoard.Ctor(self, go, areaGO)
	self._go = go
	self._areaGO = areaGO

	self:init()
end

--- 设置关联的卡牌拼图组件，注册手牌和属性更新事件
function CardPuzzleHandBoard.SetCardPuzzleComponent(self, cardPuzzleInfo)
	self._cardPuzzleInfo = cardPuzzleInfo
	self._hand = self._cardPuzzleInfo:GetHand()

	self._hand:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_CARDS, self.onUpdateCards)
	self._cardPuzzleInfo:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_FLEET_ATTR, self.onUpdateFleetAttr)
	self:onUpdateCards()
end

--- 每帧更新所有活跃和空闲卡牌
function CardPuzzleHandBoard.Update(self)
	for _, card in ipairs(self._activeCardList) do
		card:Update()
	end

	for _, card in ipairs(self._freeCardList) do
		card:Update()
	end
end

--- 手牌更新事件回调：同步手牌列表中卡牌的增删
function CardPuzzleHandBoard.onUpdateCards(self, event)
	local cardList = self._hand:GetCardList()
	local count = #self._activeCardList

	-- 先移除不在手牌中的卡牌
	while count > 0 do
		local card = self._activeCardList[count]
		local cardInfo = card:GetCardInfo()

		if not table.contains(cardList, cardInfo) then
			if cardInfo:GetCurrentPile() == self._cardPuzzleInfo.CARD_PILE_INDEX_DECK then
				self:delayRecyleCard(card)
			else
				self:recyleCard(card)
			end
		end

		count = count - 1
	end

	-- 再添加新进入手牌的卡牌
	for _, cardInfo in ipairs(cardList) do
		local existingCard

		for _, activeCard in ipairs(self._activeCardList) do
			if activeCard:GetCardInfo() == cardInfo then
				existingCard = activeCard

				break
			end
		end

		if not existingCard then
			local newCard = self:getCard()

			newCard:SetCardInfo(cardInfo)
			newCard:UpdateView()

			-- 根据来源堆确定入场动画的起始位置
			local startPos

			if cardInfo:GetFromPile() == self._cardPuzzleInfo.CARD_PILE_INDEX_DECK then
				startPos = self._drawPos
			else
				startPos = self._generatePos
			end

			newCard:DrawAnima(startPos)
			newCard:SetMoveLerp(0.1)
			newCard:ChangeState(newCard.STATE_FREE)
			table.insert(self._activeCardList, newCard)
		end
	end

	self:updateCardReferenceInHand()
end

--- 获取一张卡牌实例（优先从空闲池获取，否则新建）
function CardPuzzleHandBoard.getCard(self)
	local card

	if #self._idleCardList > 0 then
		card = table.remove(self._idleCardList, 1)
	else
		local cardTF = self._resManager:InstCardPuzzleCard().transform

		cardTF:SetParent(self._cardContainer)

		cardTF.localScale = Vector3(0.57, 0.57, 0)
		cardTF.localPosition = Vector3.zero
		card = ys.Battle.CardPuzzleCombatCard.New(cardTF)
	end

	-- 拖拽开始回调
	local function onDragStart()
		return
	end

	-- 长按结束回调
	local function onLongPressEnd()
		card:ChangeState(card.STATE_FREE)
		self._cardPuzzleInfo:LongPressCard(card, false)
	end

	-- 点击/拖拽开始回调：尝试拿起卡牌进行拖拽
	local function onBeginDrag()
		if card:GetState() == card.STATE_LONG_PRESS then
			onLongPressEnd()
		end

		if card:GetState() ~= card.STATE_LOCK then
			self:LockCardInHand()
			self:UnlockCardInHand(card)
			self:setDragingCard(card)

			self._holdingCard = card

			self:activeHighlight(true)
			self._cardPuzzleInfo:BlockComponentByCard(true)
			self:SetAllCardBlockRayCast(false)
			card:SetSibling(#self._activeCardList + CardPuzzleHandBoard.BASE_SIBLING)
			card:SetMoveLerp(0.5)
			card:ChangeState(card.STATE_DRAG)
		end
	end

	-- 拖拽中回调：更新卡牌位置
	local function onDrag(screenPos)
		card:UpdateDragPosition(screenPos)
	end

	-- 拖拽结束回调：尝试出牌或回手
	local function onDragEnd()
		local success = true

		self:setDragingCard()

		if self._cardEnterDeck then
			success = self:TryPlayReturnCard(card)
		else
			success = (self._cardEnterHand ~= true or false) and self:TryPlayCard(card)
		end

		if not success then
			card:SetMoveLerp()
			self:updateCardReferenceInHand()
		end

		self._cardEnterHand = nil
		self._cardEnterDeck = nil

		self:UnlockCardInHand()
		self:activeHighlight(false)
		self:SetAllCardBlockRayCast(true)
		onDelayTick(function()
			self._cardPuzzleInfo:BlockComponentByCard(false)
		end, 0.06)
	end

	-- 长按回调：进入长按预览状态
	local function onLongPress()
		card:ChangeState(card.STATE_LONG_PRESS)
		self._cardPuzzleInfo:LongPressCard(card, true)
	end

	card:ConfigOP(onBeginDrag, onDrag, onDragEnd, onLongPress, onLongPressEnd)

	return card
end

--- 回收卡牌到空闲池
function CardPuzzleHandBoard.recyleCard(self, card)
	for i, activeCard in ipairs(self._activeCardList) do
		if activeCard == card then
			card:SetToObjPoolRecylePos()
			table.remove(self._activeCardList, i)

			break
		end
	end

	table.insert(self._idleCardList, card)
end

--- 延迟回收卡牌（动画后回收，用于退回牌组的情况）
function CardPuzzleHandBoard.delayRecyleCard(self, card)
	card:ChangeState(card.STATE_LOCK)

	for i, activeCard in ipairs(self._activeCardList) do
		if activeCard == card then
			table.remove(self._activeCardList, i)

			break
		end
	end

	table.insert(self._freeCardList, card)
	card:MoveToDeck(function()
		for i, freeCard in ipairs(self._freeCardList) do
			if freeCard == card then
				card:SetToObjPoolRecylePos()
				table.remove(self._freeCardList, i)

				break
			end
		end

		table.insert(self._idleCardList, card)
	end, self._drawPos)
end

--- 舰队属性更新回调：刷新所有卡牌的费用和增益提示
function CardPuzzleHandBoard.onUpdateFleetAttr(self, event)
	for _, card in ipairs(self._activeCardList) do
		card:UpdateTotalCost()
		card:UpdateBoostHint()

		local cardInfo = card:GetCardInfo()
	end
end

function CardPuzzleHandBoard.init(self)
	ys.EventListener.AttachEventListener(self)

	self._cardContainer = self._go.transform
	self._resManager = ys.Battle.BattleResourceManager.GetInstance()
	self._activeCardList = {}
	self._idleCardList = {}
	self._freeCardList = {}
	self._startPos = self._cardContainer:Find("handStart").localPosition
	self._generatePos = self._cardContainer:Find("generateStart").localPosition
	self._drawPos = self._cardContainer:Find("drawStart").localPosition
	self._cancelArea = self._cardContainer:Find("cancel_area")
	self._returnArea = self._cardContainer:Find("return_area")
	self._handDelegate = GetOrAddComponent(self._cancelArea, "EventTriggerListener")
	self._deckDelegate = GetOrAddComponent(self._returnArea, "EventTriggerListener")
	self._area = self._areaGO.transform
	self._cancelHint = self._area:Find("hand_hint")
	self._returnHint = self._area:Find("deck_hint")
	self._readyHint = self._area:Find("cast_hint")
end

--- 更新手牌中各卡牌的参考位置（扇形排列）
function CardPuzzleHandBoard.updateCardReferenceInHand(self)
	for i, card in ipairs(self._activeCardList) do
		local gap = self:getcardGap()
		local targetPos = Vector3.New(self._startPos.x + (i - 1) * gap, self._startPos.y, 0)

		card:SetReferencePos(targetPos)
		card:SetSibling(i + CardPuzzleHandBoard.BASE_SIBLING)
	end
end

--- 计算手牌间距（超出基础手牌数时压缩间距）
function CardPuzzleHandBoard.getcardGap(self)
	local handCount = #self._activeCardList

	if #self._activeCardList <= BattleCardPuzzleConfig.BASE_MAX_HAND then
		return CardPuzzleHandBoard.BASE_GAP
	else
		return 830 / (handCount - 1)
	end
end

--- 设置当前拖拽中的卡牌
function CardPuzzleHandBoard.setDragingCard(self, card)
	self._cardPuzzleInfo:SetDragingCard(card)
	self._cardPuzzleInfo:SendUpdateAim()
end

function CardPuzzleHandBoard.sort(self)
	return
end

--- 激活/取消高亮提示区域（拖拽时显示取消/回手/释放提示）
function CardPuzzleHandBoard.activeHighlight(self, isActive)
	if isActive then
		self._handDelegate:AddPointEnterFunc(function()
			self._cardEnterHand = true

			setActive(self._cancelHint, true)
			setActive(self._returnHint, false)
			setActive(self._readyHint, false)
		end)
		self._handDelegate:AddPointExitFunc(function()
			self._cardEnterHand = false

			setActive(self._cancelHint, false)
			setActive(self._readyHint, true)
		end)
		self._deckDelegate:AddPointEnterFunc(function()
			self._cardEnterDeck = true

			setActive(self._readyHint, false)

			local canReturn = self._holdingCard:GetCardInfo():GetReturnCost() ~= nil

			setActive(self._cancelHint, not canReturn)
			setActive(self._returnHint, canReturn)
		end)
		self._deckDelegate:AddPointExitFunc(function()
			self._cardEnterDeck = false

			setActive(self._cancelHint, false)
			setActive(self._readyHint, true)
		end)
	else
		setActive(self._cancelHint, false)
		setActive(self._returnHint, false)
		setActive(self._readyHint, false)
		self._handDelegate:RemovePointEnterFunc()
		self._handDelegate:RemovePointExitFunc()
		self._deckDelegate:RemovePointEnterFunc()
		self._deckDelegate:RemovePointExitFunc()
	end

	setActive(self._cancelArea, isActive)
	setActive(self._returnArea, isActive)
end

--- 锁定手牌中所有卡牌（防误触）
function CardPuzzleHandBoard.LockCardInHand(self)
	for _, card in ipairs(self._activeCardList) do
		card:ChangeState(card.STATE_LOCK)
	end
end

--- 设置所有卡牌的射线阻挡
function CardPuzzleHandBoard.SetAllCardBlockRayCast(self, blocksRaycasts)
	for _, card in ipairs(self._activeCardList) do
		card:BlockRayCast(blocksRaycasts)
	end
end

--- 解锁手牌中卡牌（可指定某张保留锁定）
function CardPuzzleHandBoard.UnlockCardInHand(self, exceptCard)
	if exceptCard then
		exceptCard:ChangeState(ys.Battle.CardPuzzleCombatCard.STATE_FREE)
	else
		for _, card in ipairs(self._activeCardList) do
			card:ChangeState(ys.Battle.CardPuzzleCombatCard.STATE_FREE)
		end
	end
end

--- 尝试出牌
function CardPuzzleHandBoard.TryPlayCard(self, card)
	local cardInfo = card:GetCardInfo()

	return (self._cardPuzzleInfo:PlayCard(cardInfo))
end

--- 尝试回手（将卡牌退回牌组）
function CardPuzzleHandBoard.TryPlayReturnCard(self, card)
	local cardInfo = card:GetCardInfo()

	return (self._cardPuzzleInfo:ReturnCard(cardInfo))
end

function CardPuzzleHandBoard.Dispose(self)
	return
end
