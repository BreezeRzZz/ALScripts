ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction

ys.Battle.CardPuzzleCardDetailAffix = class("CardPuzzleCardDetailAffix")

local CardPuzzleCardDetailAffix = ys.Battle.CardPuzzleCardDetailAffix

CardPuzzleCardDetailAffix.__name = "CardPuzzleCardDetailAffix"

--- 卡牌拼图卡牌详情中的单个词缀视图
--- 显示词缀的中英文名和描述

function CardPuzzleCardDetailAffix.Ctor(self, go)
	self._go = go
	self._tf = self._go.transform
	self._nameLabel = self._tf:Find("name/labelCN")
	self._nameLabelEN = self._tf:Find("name/labelEN")
	self._desc = self._tf:Find("Desc")
end

function CardPuzzleCardDetailAffix.SetActive(self, isActive)
	setActive(self._go, isActive)
end

--- 设置词缀ID，根据模板数据更新显示
--- @param affixID number 词缀ID
function CardPuzzleCardDetailAffix.SetAffixID(self, affixID)
	local affixTemplate = BattleDataFunction.GetPuzzleCardAffixDataTemplate(affixID)

	setText(self._nameLabel, affixTemplate.name)
	setText(self._nameLabelEN, affixTemplate.name_EN)
	setText(self._desc, affixTemplate.discript)
end

function CardPuzzleCardDetailAffix.Dispose(self)
	self._nameLabel = nil
	self._nameLabelEN = nil
	self._desc = nil
	self._tf = nil
	self._go = nil
end
