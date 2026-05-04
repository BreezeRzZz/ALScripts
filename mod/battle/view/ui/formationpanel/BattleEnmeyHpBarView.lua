ys = ys or {}

local ys = ys
local BattleEnmeyHpBarView = class("BattleEnmeyHpBarView")

ys.Battle.BattleEnmeyHpBarView = BattleEnmeyHpBarView
BattleEnmeyHpBarView.__name = "BattleEnmeyHpBarView"

--- 敌方血条视图（注意：原始拼写就是"Enmey"而非"Enemy"）
--- 显示当前锁定敌人的血条、名称、等级和类型图标
--- @param monsterTF Transform 敌方信息面板的Transform
function BattleEnmeyHpBarView.Ctor(self, monsterTF)
	self._monsterTF = monsterTF
	self.orgPos = monsterTF.anchoredPosition
	-- 隐藏位置：向下偏移100
	self.HidePos = self.orgPos + Vector2(0, 100)
	self._hpBarTF = monsterTF:Find("hpbar")
	self._hpBar = self._hpBarTF.gameObject
	self._hpBarProgress = self._hpBarTF:GetComponent(typeof(Image))
	self._hpBarText = self._hpBarTF:Find("Text"):GetComponent(typeof(Text))
	self._nameTF = monsterTF:Find("nameContain/name")
	self._lvText = monsterTF:Find("nameContain/Text"):GetComponent(typeof(Text))
	self._level = monsterTF:Find("level")
	self._typeIcon = monsterTF:Find("typeIcon/icon"):GetComponent(typeof(Image))
	self._eliteLabel = monsterTF:Find("grade/elite")
	self._generalLabel = monsterTF:Find("grade/general")
	self._flag = true
	self._isExistBoos = false

	self:Show(false)
end

--- @return table 当前目标单位
function BattleEnmeyHpBarView.GetCurrentTarget(self)
	return self._targetUnit
end

--- 显示/隐藏血条面板（通过移动位置实现隐藏）
--- @param show boolean
function BattleEnmeyHpBarView.Show(self, show)
	if self._curActive ~= show then
		self._curActive = show

		if show then
			self._monsterTF.anchoredPosition = self.orgPos
		else
			self._monsterTF.anchoredPosition = self.HidePos
		end
	end
end

--- 设置图标类型（精英/普通标签）
--- @param isElite boolean 是否为精英敌人
function BattleEnmeyHpBarView.SetIconType(self, isElite)
	if self._eliteType == isElite then
		return
	end

	self._eliteType = isElite

	setActive(self._generalLabel, not isElite)
	setActive(self._eliteLabel, isElite)
end

--- 切换到新的目标单位
--- 检查是否有Boss存在，有Boss时不显示小怪血条
--- @param targetUnit table 目标单位
--- @param unitList table 所有可见单位的列表（用于检查是否存在Boss）
function BattleEnmeyHpBarView.SwitchTarget(self, targetUnit, unitList)
	-- 检查列表中是否存在Boss
	for _, unit in pairs(unitList) do
		if unit:IsBoss() then
			self._isExistBoos = true

			break
		end
	end

	if self._flag == false or self._isExistBoos == true then
		self:Show(false)

		return
	end

	self._targetUnit = targetUnit

	self:Show(true)

	local hpRate = targetUnit:GetHPRate()

	self._hpBarProgress.fillAmount = hpRate

	self:UpdateHpText(targetUnit)
	self:SetIconType(targetUnit:GetTemplate().icon_type ~= 0)

	-- 设置船型图标
	local shipType = ys.Battle.BattleDataFunction.GetEnemyTypeDataByType(targetUnit:GetTemplate().type).type
	local typeSprite = GetSpriteFromAtlas("shiptype", shipType2Battleprint(shipType))

	self._typeIcon.sprite = typeSprite

	self._typeIcon:SetNativeSize()
	-- 滚动显示名称
	changeToScrollText(self._nameTF, targetUnit._tmpData.name)

	self._lvText.text = " Lv." .. targetUnit:GetLevel()
end

--- 更新血条上的HP数值文本
function BattleEnmeyHpBarView.UpdateHpText(self)
	local currentHP, maxHP = self._targetUnit:GetHP()

	self._hpBarText.text = tostring(math.floor(currentHP) .. "/" .. math.floor(maxHP))
end

--- 更新血条（动画平滑过渡），HP为0时移除单位
function BattleEnmeyHpBarView.UpdateHpBar(self)
	if self._flag == false or self._isExistBoos == true then
		return
	end

	LeanTween.cancel(self._hpBar)

	local hpRate = self._targetUnit:GetHPRate()

	self:UpdateHpText(target)

	local currentFill = self._hpBarProgress.fillAmount

	-- HP下降时使用平滑动画
	if hpRate < currentFill then
		LeanTween.value(self._hpBar, currentFill, hpRate, 0.5):setOnUpdate(System.Action_float(function(fillValue)
			self._hpBarProgress.fillAmount = fillValue
		end))
	else
		self._hpBarProgress.fillAmount = hpRate
	end

	if hpRate == 0 then
		self:RemoveUnit()
	end
end

--- 移除当前目标单位
--- @param useDeathTimer boolean 是否使用死亡延迟（等待死亡动画）
function BattleEnmeyHpBarView.RemoveUnit(self, useDeathTimer)
	self._targetUnit = nil
	self._flag = false

	local function resetFlag()
		self._flag = true

		self:Show(false)
	end

	if useDeathTimer then
		self._deathTimer = pg.TimeMgr.GetInstance():AddBattleTimer("death", 0, 1, function()
			resetFlag()
			pg.TimeMgr.GetInstance():RemoveBattleTimer(self._deathTimer)
		end)
	else
		resetFlag()
	end
end

--- 清理资源
function BattleEnmeyHpBarView.Dispose(self)
	self:Show(false)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._deathTimer)
	LeanTween.cancel(self._hpBar)

	self._hpBarProgress = nil
	self._hpBar = nil
	self._hpBarTF = nil
	self._monsterTF = nil
	self._monster = nil
end
