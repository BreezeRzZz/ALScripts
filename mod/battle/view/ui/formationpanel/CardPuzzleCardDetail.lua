ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction

ys.Battle.CardPuzzleCardDetail = class("CardPuzzleCardDetail")

local CardPuzzleCardDetail = ys.Battle.CardPuzzleCardDetail

CardPuzzleCardDetail.__name = "CardPuzzleCardDetail"

--- 卡牌拼图卡牌详情弹窗
--- 点击卡牌时显示卡牌描述、词缀（affix）列表等详细信息

function CardPuzzleCardDetail.Ctor(self, go)
	self._go = go
	self._tf = self._go.transform
	self._desc = self._tf:Find("Desc")
	self._affixList = self._tf:Find("affixList")
	self._affixContainer = self._affixList:Find("container")
	self._affixTpl = self._tf:Find("tpl")
	self._affixViewList = {}
	-- 计算显示边界（右侧不超出屏幕）
	self._bound = 960 - rtf(self._tf).rect.width * 0.5
end

function CardPuzzleCardDetail.Dispose(self)
	self._affixList = nil
	self._affixContainer = nil
	self._affixTpl = nil
	self._desc = nil
	self._tf = nil
	self._go = nil
end

--- 激活/隐藏详情面板
function CardPuzzleCardDetail.Active(self, isActive)
	setActive(self._go, isActive)
end

--- 设置参考卡牌，根据卡牌数据更新描述和词缀列表
--- @param card CardPuzzleCombatCard 参考卡牌对象
function CardPuzzleCardDetail.SetReferenceCard(self, card)
	local cardID = card:GetCardInfo():GetCardID()
	local cardTemplate = BattleDataFunction.GetPuzzleCardDataTemplate(cardID)

	setText(self._desc, cardTemplate.discript)

	-- 动态生成词缀视图
	local labelCount = #cardTemplate.label
	local filledCount = 0

	while filledCount < labelCount do
		filledCount = filledCount + 1

		local affixView = self._affixViewList[filledCount]

		if affixView == nil then
			local affixClone = cloneTplTo(self._affixTpl, self._affixContainer)

			affixView = ys.Battle.CardPuzzleCardDetailAffix.New(affixClone)

			table.insert(self._affixViewList, affixView)
		end

		affixView:SetAffixID(cardTemplate.label[filledCount])
	end

	-- 隐藏多余的词缀视图
	for i, affixView in ipairs(self._affixViewList) do
		local isUsed = i <= filledCount

		affixView:SetActive(isUsed)
	end

	-- 计算弹窗位置
	self._pos = self._pos or Vector3.New(0, 0, 0)

	local cardPos = card:GetUIPos()

	-- X方向边界保护
	if cardPos.x > self._bound then
		self._pos.x = self._bound
	else
		self._pos.x = cardPos.x
	end

	-- Y方向偏移显示在卡牌上方
	self._pos.y = cardPos.y + 130
	self._tf.anchoredPosition = self._pos
end
