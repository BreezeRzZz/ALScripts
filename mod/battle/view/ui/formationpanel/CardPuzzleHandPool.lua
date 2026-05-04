ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent

ys.Battle.CardPuzzleHandPool = class("CardPuzzleHandPool")

local CardPuzzleHandPool = ys.Battle.CardPuzzleHandPool

CardPuzzleHandPool.__name = "CardPuzzleHandPool"

--- 卡牌拼图手牌池视图
--- 在手牌区域中显示卡牌按钮列表，点击可直接出牌（简化操作模式）

function CardPuzzleHandPool.Ctor(self, go)
	self._go = go

	self:init()
	pg.DelegateInfo.New(self)
end

--- 设置关联的卡牌拼图组件，初始化固定数量的卡牌按钮
function CardPuzzleHandPool.SetCardPuzzleComponent(self, cardPuzzleInfo)
	self._cardPuzzleInfo = cardPuzzleInfo
	self._hand = self._cardPuzzleInfo:GetHand()

	-- 预先创建手牌上限数量的按钮视图
	for i = 1, ys.Battle.BattleFleetCardPuzzleHand.MAX_HAND do
		self:instCardView()
	end

	self._hand:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_CARDS, self.onUpdateCards)
	self._cardPuzzleInfo:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_FLEET_ATTR, self.onUpdateFleetAttr)
	self:onUpdateCards()
end

--- 手牌更新回调：将手牌数据同步到按钮视图
function CardPuzzleHandPool.onUpdateCards(self, event)
	local cardList = self._hand:GetCardList()

	for i = 1, self._hand.MAX_HAND do
		self._cardList[i]:SetCardInfo(cardList[i])
	end
end

--- 舰队属性更新回调：刷新所有按钮的费用
function CardPuzzleHandPool.onUpdateFleetAttr(self, event)
	for i = 1, self._hand.MAX_HAND do
		self._cardList[i]:UpdateTotalCost()
	end
end

function CardPuzzleHandPool.init(self)
	ys.EventListener.AttachEventListener(self)

	self._cardList = {}
	self._cardContainer = self._go.transform:Find("card_container")
	self._cardTpl = self._go.transform:Find("card_tpl")
end

--- 刷新所有按钮视图
function CardPuzzleHandPool.updateHandCard(self)
	for _, cardButton in ipairs(self._cardList) do
		cardButton:updateCardView()
	end
end

function CardPuzzleHandPool.sort(self)
	return
end

--- 实例化一个卡牌按钮视图并配置点击回调
function CardPuzzleHandPool.instCardView(self)
	local cardTF = cloneTplTo(self._cardTpl, self._cardContainer)
	local cardButton = ys.Battle.CardPuzzleHandCardButton.New(go(cardTF))

	table.insert(self._cardList, cardButton)
	-- 配置点击回调：直接打出卡牌
	cardButton:ConfigCallback(function(cardInfo)
		self._cardPuzzleInfo:PlayCard(cardInfo)
	end)

	return cardButton
end

--- 测试用方法：使用对象池加载战斗卡牌模型（开发/调试用）
function CardPuzzleHandPool.test(self, testContainer)
	self._testContainer = testContainer

	LoadAndInstantiateAsync("UI", "CardTowerCardCombat", function(prefab)
		self._cardPool = pg.Pool.New(self._testContainer, prefab, 7, 20, false, false):InitSize()

		local cardList = self._hand:GetCardList()

		for _, cardInfo in ipairs(cardList) do
			local cardObj = self._cardPool:GetObject()
			local cardTF = cardObj.transform

			cardTF.localScale = Vector3(0.57, 0.57, 0)

			local combatCard = ys.Battle.CardPuzzleCombatCard.New(cardTF)

			combatCard:SetCardInfo(cardInfo)
			combatCard:UpdateView()

			self._modelClick = GetOrAddComponent(cardObj, "ModelDrag")
			self._modelPress = GetOrAddComponent(cardObj, "UILongPressTrigger")
			self._dragDelegate = GetOrAddComponent(cardObj, "EventTriggerListener")

			pg.DelegateInfo.Add(self, self._modelClick.onModelClick)
			self._modelClick.onModelClick:AddListener(function()
				return
			end)
			pg.DelegateInfo.Add(self, self._modelPress.onLongPressed)

			self._modelPress.longPressThreshold = 1

			self._modelPress.onLongPressed:RemoveAllListeners()
			self._modelPress.onLongPressed:AddListener(function()
				return
			end)
		end
	end, true, true)
end

function CardPuzzleHandPool.Dispose(self)
	self._cardTpl = nil
	self._cardContainer = nil
	self._cardList = nil

	pg.DelegateInfo.Dispose(self)
end
