ys = ys or {}

local ys = ys
local BattleVariable = ys.Battle.BattleVariable
local BattleInkView = class("BattleInkView")

ys.Battle.BattleInkView = BattleInkView
BattleInkView.__name = "BattleInkView"
-- 状态常量（原始拼写保留）
BattleInkView.ANIMATION_STATE_INITIAL = "intial"
BattleInkView.ANIMATION_STATE_IDLE = "idle"
BattleInkView.ANIMATION_STATE_FINALE = "int"

--- 墨迹/视野遮挡视图
--- 受"blindedHorizon"属性影响，在单位周围显示墨迹圈来限制视野
--- @param go GameObject 墨迹视图的GameObject
function BattleInkView.Ctor(self, go)
	self._go = go

	self:init()
end

--- 初始化墨迹模板和容器
function BattleInkView.init(self)
	self._tf = self._go.transform
	self._hollowTpl = self._tf:Find("ink_tpl")
	self._hollowContainer = self._tf:Find("container")
	self._unitHollowList = {}
	self._state = BattleInkView.ANIMATION_STATE_IDLE
end

--- @return boolean 当前是否激活
function BattleInkView.IsActive(self)
	return self._isActive
end

--- 更新所有墨迹圈的位置（跟随单位移动）
function BattleInkView.Update(self)
	for unit, hollowData in pairs(self._unitHollowList) do
		if unit:IsAlive() then
			local hollowPos = hollowData.pos
			local hollowTF = hollowData.hollow
			local newPos = hollowPos:Copy(unit:GetPosition())

			-- 将3D坐标转换为UI坐标
			hollowTF.position = BattleVariable.CameraPosToUICamera(newPos + Vector3(0, 0, 0))
		else
			self:RemoveHollow(unit)
		end
	end
end

--- 激活/取消墨迹视野
--- @param isActive boolean 是否激活
--- @param unitList table 要添加墨迹的单位列表（激活时传入）
function BattleInkView.SetActive(self, isActive, unitList)
	self._isActive = isActive

	if isActive then
		self._state = BattleInkView.ANIMATION_STATE_INITIAL

		-- 为列表中的每个单位添加墨迹圈
		for _, unit in ipairs(unitList) do
			self:AddHollow(unit)
		end

		setActive(self._go, true)
	else
		-- 按顺序播放缩小动画后移除所有墨迹圈
		local isFirst = true

		for unit, hollowData in pairs(self._unitHollowList) do
			local hollowTF = hollowData.hollow

			local function onComplete()
				self:RemoveHollow(unit)
				setActive(self._go, false)

				self._state = BattleInkView.ANIMATION_STATE_IDLE
			end

			-- 仅第一个墨迹的完成回调会触发最终的清理
			self.doHollowScaleAnima(hollowTF, 125, 0.3, isFirst and onComplete or nil)

			isFirst = false
		end
	end
end

--- 为一个单位添加墨迹圈
--- 如果已有墨迹圈且范围改变，则进行缩放动画
--- @param unit table 战斗单位
function BattleInkView.AddHollow(self, unit)
	local blindRange = unit:GetAttrByName("blindedHorizon")
	local existingData = self._unitHollowList[unit]

	if existingData then
		if existingData.range ~= blindRange then
			self.doHollowScaleAnima(existingData.hollow, blindRange)
		end

		existingData.range = blindRange

		return
	elseif blindRange == 0 then
		return
	end

	local hollowData = {}
	local hollowTF = cloneTplTo(self._hollowTpl, self._hollowContainer)

	hollowTF.localScale = Vector3(125, 125, 0)

	-- 从125缩放到目标范围
	self.doHollowScaleAnima(hollowTF, blindRange)

	local unitPos = Vector3.zero

	unitPos:Copy(unit:GetPosition())

	hollowData.range = blindRange
	hollowData.hollow = hollowTF
	hollowData.pos = unitPos
	self._unitHollowList[unit] = hollowData
end

--- 移除单位的墨迹圈
--- @param unit table 战斗单位
function BattleInkView.RemoveHollow(self, unit)
	local hollowGO = self._unitHollowList[unit].hollow.gameObject

	LeanTween.cancel(hollowGO)
	Destroy(hollowGO)

	self._unitHollowList[unit] = nil
end

--- 批量更新墨迹圈（用于单位属性变化时）
--- @param unitList table 单位列表
function BattleInkView.UpdateHollow(self, unitList)
	for _, unit in ipairs(unitList) do
		self:AddHollow(unit)
	end
end

--- 执行墨迹圈的缩放到指定大小
--- @param hollowTF Transform 墨迹Transform
--- @param targetSize number 目标缩放大小
--- @param duration number 动画时长（默认0.5秒）
--- @param onCompleteFunc function 完成回调
function BattleInkView.doHollowScaleAnima(self, hollowTF, targetSize, duration, onCompleteFunc)
	local animDuration = duration or 0.5

	LeanTween.cancel(go(hollowTF))

	local tween = LeanTween.scale(hollowTF, Vector3(targetSize, targetSize, 0), animDuration)

	if onCompleteFunc then
		tween:setOnComplete(System.Action(function()
			onCompleteFunc()
		end))
	end
end

--- 清理所有墨迹圈
function BattleInkView.Dispose(self)
	self:SetActive(false)

	for _, hollowData in pairs(self._unitHollowList) do
		local hollowGO = hollowData.hollow.gameObject

		LeanTween.cancel(hollowGO)
		Destroy(hollowGO)
	end

	self._go = nil
	self._tf = nil
	self._unitHollowList = nil
end
