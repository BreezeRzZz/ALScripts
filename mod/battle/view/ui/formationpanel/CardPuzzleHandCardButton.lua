ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.CardPuzzleHandCardButton = class("CardPuzzleHandCardButton")

local CardPuzzleHandCardButton = ys.Battle.CardPuzzleHandCardButton

CardPuzzleHandCardButton.__name = "CardPuzzleHandCardButton"

--- 卡牌拼图手牌按钮视图
--- 用于 HandPool 中显示单张手牌的缩略按钮，包含费用、名称、稀有度、类型等

function CardPuzzleHandCardButton.Ctor(self, go)
	self._go = go

	self:init()
end

--- 设置卡牌信息并刷新显示
function CardPuzzleHandCardButton.SetCardInfo(self, cardInfo)
	self._cardInfo = cardInfo

	self:updateCardView()
end

--- 更新费用文本
function CardPuzzleHandCardButton.UpdateTotalCost(self)
	if self._cardInfo then
		setText(self._costTxt, self._cardInfo:GetTotalCost())
	end
end

--- 配置点击回调
function CardPuzzleHandCardButton.ConfigCallback(self, callback)
	self._callback = callback
end

function CardPuzzleHandCardButton.init(self)
	self._btnTF = self._go.transform
	self._icon = self._btnTF:Find("skill_icon/unfill")
	self._costTxt = self._btnTF:Find("cost/cost_label")
	self._cardName = self._btnTF:Find("name")
	self._cardType = self._btnTF:Find("icon_bg")
	self._cardTypeList = {}

	-- 卡牌类型图标列表（1~3）
	for i = 1, 3 do
		table.insert(self._cardTypeList, self._cardType:Find("card_type_" .. i))
	end

	self._cardRarity = self._btnTF:Find("bg")
	self._cardRarityList = {}

	-- 稀有度背景列表（0~4 = 白~彩）
	for i = 0, 4 do
		table.insert(self._cardRarityList, self._cardRarity:Find("rarity_" .. i))
	end

	self._tag = self._btnTF:Find("tag")

	-- 点击触发回调
	GetComponent(self._btnTF, "EventTriggerListener"):AddPointUpFunc(function()
		if self._cardInfo then
			self._callback(self._cardInfo)
		end
	end)
end

--- 刷新卡牌视图显示
function CardPuzzleHandCardButton.updateCardView(self)
	if self._cardInfo then
		setActive(self._btnTF, true)
		setText(self._costTxt, self._cardInfo:GetTotalCost())
		setText(self._cardName, self._cardInfo:GetCardTemplate().name)
		setText(self._tag, "词缀功能TODO")

		local rarity = self._cardInfo:GetRarity()
		local cardType = self._cardInfo:GetCardType()

		-- 设置稀有度背景
		for i, rarityTF in ipairs(self._cardRarityList) do
			setActive(rarityTF, i == rarity + 1)
		end

		-- 设置卡牌类型图标
		for i, typeTF in ipairs(self._cardTypeList) do
			setActive(typeTF, i == cardType)
		end

		-- 异步加载技能图标
		GetImageSpriteFromAtlasAsync("skillicon/" .. self._cardInfo:GetIconID(), "", self._icon)
	else
		setActive(self._btnTF, false)
	end
end

function CardPuzzleHandCardButton.Dispose(self)
	return
end
