ys = ys or {}

local ys = ys

ys.Battle.BattleDamageRateView = class("BattleDamageRateView")
ys.Battle.BattleDamageRateView.__name = "BattleDamageRateView"

--- 战斗伤害评分进度条视图（C/B/A/S评分条）
--- @param go GameObject 评分条的GameObject
function ys.Battle.BattleDamageRateView.Ctor(self, go)
	self._go = go
	self.tick_bar = go.transform:Find("tick_bar"):GetComponent(typeof(Image))
	self.tickBarOb = self.tick_bar.gameObject
	self.tick_bar.fillAmount = 0
end

--- 根据当前分数和章节ID更新评分条
--- @param score number 当前战斗分数
--- @param chapterID number 章节ID
function ys.Battle.BattleDamageRateView.UpdateScore(self, score, chapterID)
	local targetFill = self:CalScore(score, chapterID)

	LeanTween.cancel(self.tickBarOb)
	-- 平滑过渡到目标填充率
	LeanTween.value(self.tickBarOb, self.tick_bar.fillAmount, targetFill, 0.5):setOnUpdate(System.Action_float(function(fillValue)
		self.tick_bar.fillAmount = fillValue
	end))
end

--- 计算分数对应的评分条填充率
--- @param score number 当前分数
--- @param chapterID number 章节ID，用于查询expedition_data_template
--- @return number 填充率（0~1）
function ys.Battle.BattleDamageRateView.CalScore(self, score, chapterID)
	local chapterData = pg.expedition_data_template[chapterID]
	-- 分数档位键名列表
	local scoreKeys = {
		"c_score_point",
		"b_score_point",
		"a_score_point",
		"s_score_point",
		"score_max"
	}
	-- 对应填充率
	local fillRatios = {
		0,
		0.445,
		0.7,
		0.88,
		1
	}
	local tierIndex = 0

	-- 找到当前分数所在的档位
	for i, scoreKey in ipairs(scoreKeys) do
		if score < chapterData[scoreKey] then
			break
		end

		tierIndex = i
	end

	-- 在档位之间做线性插值
	local fillAmount = 0

	if tierIndex < #scoreKeys then
		local lowerBound = chapterData[scoreKeys[tierIndex]]

		if lowerBound < 0 then
			lowerBound = 0
		end

		local ratioInTier = (score - lowerBound) / (chapterData[scoreKeys[tierIndex + 1]] - lowerBound)

		fillAmount = (fillRatios[tierIndex + 1] - fillRatios[tierIndex]) * ratioInTier + fillRatios[tierIndex]
	else
		fillAmount = 1
	end

	return fillAmount
end

--- 取消缓动动画
function ys.Battle.BattleDamageRateView.Dispose(self)
	LeanTween.cancel(self.tickBarOb)
end
