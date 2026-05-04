ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.CardPuzzleCommonHPBar = class("CardPuzzleCommonHPBar")

local CardPuzzleCommonHPBar = ys.Battle.CardPuzzleCommonHPBar

CardPuzzleCommonHPBar.__name = "CardPuzzleCommonHPBar"

--- 卡牌拼图通用HP血条视图
--- 显示战斗中公共HP的血条进度

function CardPuzzleCommonHPBar.Ctor(self, go)
	self._go = go
	self._tf = self._go.transform
	self._hpTF = self._tf:Find("fleetBlood/blood")
	self._hpProgress = self._hpTF:GetComponent(typeof(Image))
end

--- 设置关联的卡牌拼图组件
--- @param info CardPuzzleInfo 卡牌拼图信息对象
function CardPuzzleCommonHPBar.SetCardPuzzleComponent(self, info)
	self._info = info
end

--- 每帧更新
function CardPuzzleCommonHPBar.Update(self)
	self:updateHPBar()
end

--- 更新血条进度
function CardPuzzleCommonHPBar.updateHPBar(self)
	local ratio = self._info:GetCurrentCommonHP() / self._info:GetTotalCommonHP()

	self._hpProgress.fillAmount = ratio
end

function CardPuzzleCommonHPBar.Dispose(self)
	self._hpProgress = nil
	self._hpTF = nil
	self._tf = nil
	self._go = nil
end

function CardPuzzleCommonHPBar.updateResource(self)
	return
end
