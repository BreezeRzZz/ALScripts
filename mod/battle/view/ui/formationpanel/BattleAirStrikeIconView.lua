ys = ys or {}

local ys = ys
-- 用于获取飞机模板数据（icon字段）
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAirStrikeIconView = class("BattleAirStrikeIconView")

ys.Battle.BattleAirStrikeIconView = BattleAirStrikeIconView
BattleAirStrikeIconView.__name = "BattleAirStrikeIconView"
-- 无飞机数据时使用的默认图标
BattleAirStrikeIconView.DEFAULT_ICON_NAME = "99shijianbao"

--- 在BattleUIMediator.FighterIconCallBack中初始化
--- 管理空袭图标列表的显示
--- @param iconTpl Transform 图标模板
function BattleAirStrikeIconView.Ctor(self, iconTpl)
	self._iconList = {}

	self:ConfigIconSkin(iconTpl)
end

--- 配置图标模板和容器
--- @param iconTpl Transform 图标模板（其parent即为容器）
function BattleAirStrikeIconView.ConfigIconSkin(self, iconTpl)
	self._iconTpl = iconTpl
	self._iconContainer = iconTpl.parent
end

--- 添加一个空袭图标到列表中
--- @param index number 图标列表的key（通常为1-based序号）
--- @param airStrikeData table 空袭数据，含templateID和totalNumber
function BattleAirStrikeIconView.AppendIcon(self, index, airStrikeData)
	local iconGO = cloneTplTo(self._iconTpl, self._iconContainer).gameObject
	local fighterIconTF = iconGO.transform:Find("FighterIcon")

	iconGO:SetActive(true)
	self:setIconNumber(fighterIconTF, airStrikeData.totalNumber)

	-- 优先使用飞机模板配置的图标，否则使用默认图标
	local iconName = BattleDataFunction.GetAircraftTmpDataFromID(airStrikeData.templateID).icon or BattleAirStrikeIconView.DEFAULT_ICON_NAME
	local iconSprite = ys.Battle.BattleResourceManager.GetInstance():GetAircraftIcon(iconName)

	setImageSprite(fighterIconTF, iconSprite)

	self._iconList[index] = iconGO

	-- 如果有动画组件，播放入场动画
	if iconGO:GetComponent(typeof(Animation)) then
		quickPlayAnimation(iconGO, "anim_skinui_AFC_in")
	end
end

--- 移除一个空袭图标
--- @param index number 图标列表的key
--- @param airStrikeData table 空袭数据，含totalNumber
function BattleAirStrikeIconView.RemoveIcon(self, index, airStrikeData)
	local iconGO = self._iconList[index]

	if not iconGO then
		return
	end

	-- 数量归零则销毁图标GameObject
	if airStrikeData.totalNumber <= 0 then
		local function destroyIcon()
			Object.Destroy(iconGO)

			self._iconList[index] = nil
		end

		-- 有动画组件时先播放退出动画再销毁
		if iconGO:GetComponent(typeof(Animation)) then
			iconGO:GetComponent("DftAniEvent"):SetEndEvent(function(_)
				destroyIcon()
			end)
			quickPlayAnimation(iconGO, "anim_skinui_AFC_out")
		else
			destroyIcon()
		end
	else
		-- 数量未归零则仅更新数量文本
		self:setIconNumber(iconGO.transform:Find("FighterIcon"), airStrikeData.totalNumber)
	end
end

--- 清理所有图标
function BattleAirStrikeIconView.Dispose(self)
	for _, iconGO in pairs(self._iconList) do
		Object.Destroy(iconGO)
	end

	self._iconList = nil
end

--- 设置图标上显示的数量文本（X格式）
--- @param fighterIconTF Transform FighterIcon的Transform
--- @param number number 要显示的飞机数量
function BattleAirStrikeIconView.setIconNumber(self, fighterIconTF, number)
	fighterIconTF.transform:Find("FighterNum"):GetComponent(typeof(Text)).text = "X" .. number
end
