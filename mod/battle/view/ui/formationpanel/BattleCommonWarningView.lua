ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleSkillEditCustomWarning = ys.Battle.BattleSkillEditCustomWarning
local BattleCommonWarningView = class("BattleCommonWarningView")

ys.Battle.BattleCommonWarningView = BattleCommonWarningView
BattleCommonWarningView.__name = "BattleCommonWarningView"
BattleCommonWarningView.WARNING_TYPE_SUBMARINE = "submarine"
BattleCommonWarningView.WARNING_TYPE_ARTILLERY = "artillery"

--- 战斗中的通用警告视图，管理潜艇警告和炮击警告
--- @param go GameObject 警告UI的GameObject
function BattleCommonWarningView.Ctor(self, go)
	self._submarineCount = 0
	self._go = go
	self._tf = go.transform
	self._subIcon = self._tf:Find("submarineIcon")
	self._tips = self._tf:Find("warningTips")
	self._subWarn = self._tf:Find("submarineWarningTips")
	-- 警告请求表：按优先级排列，靠前的优先级更高
	self._warningRequestTable = {
		{
			flag = false,
			type = BattleCommonWarningView.WARNING_TYPE_ARTILLERY,
			tf = self._tips
		},
		{
			flag = false,
			type = BattleCommonWarningView.WARNING_TYPE_SUBMARINE,
			tf = self._subWarn
		}
	}
	self._customWarningTpl = self._tf:Find("customWarningTpl")
	self._customWarningContainer = self._tf:Find("customWarningContainer")
	self._customWarningList = {}
end

--- 更新敌方潜艇数量，控制潜艇警告的显示/隐藏
--- @param count number 敌方潜艇数量
function BattleCommonWarningView.UpdateHostileSubmarineCount(self, count)
	if count > 0 and self._submarineCount <= 0 then
		self:activeSubmarineWarning()
	elseif self._submarineCount > 0 and count <= 0 then
		self:deactiveSubmarineWarning()
	end

	self._submarineCount = count
end

--- @return number 当前敌方潜艇数量
function BattleCommonWarningView.GetCount(self)
	return self._submarineCount
end

--- 激活指定类型的警告
--- 按优先级排列，只有优先级最高（最靠前）的警告才会被显示
--- @param warningType string 警告类型
function BattleCommonWarningView.ActiveWarning(self, warningType)
	local alreadyActive = false
	local topActiveIndex = #self._warningRequestTable

	for index, entry in ipairs(self._warningRequestTable) do
		if warningType == entry.type then
			entry.flag = true

			if not alreadyActive then
				-- 尚未有更高优先级的警告在显示，则显示当前警告
				SetActive(entry.tf, true)

				topActiveIndex = index
			else
				break
			end
		else
			alreadyActive = alreadyActive or entry.flag

			-- 隐藏比当前激活警告优先级更低的警告
			if entry.flag and topActiveIndex < index then
				SetActive(entry.tf, false)
			end
		end
	end
end

--- 取消激活指定类型的警告
--- 如果取消后还有其他激活的警告，则重新激活最高优先级的那个
--- @param warningType string 警告类型
function BattleCommonWarningView.DeactiveWarning(self, warningType)
	for _, entry in ipairs(self._warningRequestTable) do
		if warningType == entry.type then
			entry.flag = false

			SetActive(entry.tf, false)
		elseif entry.flag then
			-- 存在其他激活的警告，重新激活它
			self:ActiveWarning(entry.type)

			break
		end
	end
end

--- 编辑自定义警告（技能脚本触发的自定义提示）
--- @param data table 警告数据，含op、key等字段
function BattleCommonWarningView.EditCustomWarning(self, data)
	local op = data.op
	local key = data.key

	if op == BattleSkillEditCustomWarning.OP_ADD then
		-- 添加一个新的自定义警告标签
		local labelGO = cloneTplTo(self._customWarningTpl, self._customWarningContainer)
		local label = ys.Battle.BattleCustomWarningLabel.New(labelGO)

		label:ConfigData(data)

		self._customWarningList[key] = label
	elseif op == BattleSkillEditCustomWarning.OP_REMOVE then
		-- 通过key移除指定警告
		local label = self._customWarningList[key]

		if label then
			label:SetExpire()
		end
	elseif op == BattleSkillEditCustomWarning.OP_REMOVE_PERMANENT then
		-- 移除所有永久性（duration<=0）的警告
		for _, label in pairs(self._customWarningList) do
			if label:GetDuration() <= 0 then
				label:SetExpire()
			end
		end
	elseif op == BattleSkillEditCustomWarning.OP_REMOVE_TEMPLATE then
		-- 移除所有带持续时间（duration>0）的警告
		for _, label in pairs(self._customWarningList) do
			if label:GetDuration() > 0 then
				label:SetExpire()
			end
		end
	end
end

--- 更新自定义警告列表，移除已过期的标签
function BattleCommonWarningView.Update(self)
	for key, label in pairs(self._customWarningList) do
		label:Update()

		if label:IsExpire() then
			label:Dispose()

			self._customWarningList[key] = nil
		end
	end
end

--- 激活潜艇警告的入场动画
function BattleCommonWarningView.activeSubmarineWarning(self)
	SetActive(self._subIcon, true)
	self:ActiveWarning(BattleCommonWarningView.WARNING_TYPE_SUBMARINE)
	LeanTween.cancel(go(self._subIcon))
	LeanTween.alpha(rtf(self._subIcon), 1, 2):setFrom(0)
end

--- 激活潜艇警告的退出动画
function BattleCommonWarningView.deactiveSubmarineWarning(self)
	LeanTween.cancel(go(self._subIcon))
	LeanTween.alpha(rtf(self._subIcon), 0, 1):setFrom(1):setOnComplete(System.Action(function()
		SetActive(self._subIcon, false)
		self:DeactiveWarning(BattleCommonWarningView.WARNING_TYPE_SUBMARINE)
	end))
end

--- 清理所有警告标签
function BattleCommonWarningView.Dispose(self)
	for key, label in pairs(self._customWarningList) do
		label:Dispose()

		self._customWarningList[key] = nil
	end

	self._customWarningList = nil
	self._go = nil
	self._tf = nil
	self._icon = nil
	self._tips = nil
end
