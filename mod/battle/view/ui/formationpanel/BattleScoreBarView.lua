ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleScoreBarView = class("BattleScoreBarView")

ys.Battle.BattleScoreBarView = BattleScoreBarView
BattleScoreBarView.__name = "BattleScoreBarView"

--- 战斗分数条视图
--- 显示战斗中的得分和连击（combo）数

function BattleScoreBarView.Ctor(self, go)
	self._go = go
	self._tf = go.transform

	self:init()
end

function BattleScoreBarView.init(self)
	self._scoreTF = self._tf:Find("bg/Text")
	self._comboTF = self._tf:Find("comboMark")
	self._comboText = self._tf:Find("comboMark/value")
end

function BattleScoreBarView.SetActive(self, isActive)
	SetActive(self._tf, isActive)
end

--- 更新分数显示
function BattleScoreBarView.UpdateScore(self, score)
	setText(self._scoreTF, score)
end

--- 更新连击数显示（大于1时显示连击标记）
function BattleScoreBarView.UpdateCombo(self, combo)
	if combo > 1 then
		SetActive(self._comboTF, true)
	else
		SetActive(self._comboTF, false)
	end

	setText(self._comboText, combo)
end
