ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent
local BattleDataFunction = ys.Battle.BattleDataFunction

ys.Battle.CardPuzzleGoalRemind = class("CardPuzzleGoalRemind")

local CardPuzzleGoalRemind = ys.Battle.CardPuzzleGoalRemind

CardPuzzleGoalRemind.__name = "CardPuzzleGoalRemind"

--- 卡牌拼图目标提示面板
--- 显示当前迷宫副本的目标描述，点击可展开/收起详情

function CardPuzzleGoalRemind.Ctor(self, go)
	self._go = go

	self:init()
end

--- 设置关联的卡牌拼图组件，加载迷宫模板数据
function CardPuzzleGoalRemind.SetCardPuzzleComponent(self, cardPuzzleInfo)
	local dungeonID = cardPuzzleInfo:GetPuzzleDungeonID()

	self._tmp = BattleDataFunction.GetPuzzleDungeonTemplate(dungeonID)

	setText(self._bg:Find("text"), self._tmp.description)
end

function CardPuzzleGoalRemind.init(self)
	pg.DelegateInfo.New(self)

	self._tf = self._go.transform
	self._bg = self._tf:Find("bg")

	setText(self._bg:Find("label_ch"), i18n("card_puzzel_goal_ch"))
	setText(self._bg:Find("label_en"), i18n("card_puzzel_goal_en"))

	self._arrow = self._bg:Find("arrow")
	-- 展开/收起标志：1=收起, -1=展开
	self._openFlag = 1

	-- 点击背景切换展开/收起
	onButton(self, self._bg, function()
		local bgRect = rtf(self._bg).rect
		local newHeight = bgRect.height + self._openFlag * 150

		rtf(self._bg).sizeDelta = Vector2(bgRect.width, newHeight)
		self._openFlag = self._openFlag * -1
		-- 箭头翻转
		self._arrow.localScale = Vector3(1, self._openFlag, 1)
	end)
end

function CardPuzzleGoalRemind.Dispose(self)
	pg.DelegateInfo.Dispose(self)

	self._arrow = nil
	self._bg = nil
	self._tf = nil
end
