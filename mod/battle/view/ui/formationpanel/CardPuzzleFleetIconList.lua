ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleConfig = ys.Battle.BattleCardPuzzleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent

ys.Battle.CardPuzzleFleetIconList = class("CardPuzzleFleetIconList")

local CardPuzzleFleetIconList = ys.Battle.CardPuzzleFleetIconList

CardPuzzleFleetIconList.__name = "CardPuzzleFleetIconList"

--- 卡牌拼图舰队图标列表视图
--- 显示舰队属性和增益Buff的图标列表（类似其他游戏中的状态栏）

function CardPuzzleFleetIconList.Ctor(self, go)
	self._go = go

	self:init()
end

--- 设置关联的卡牌拼图组件
function CardPuzzleFleetIconList.SetCardPuzzleComponent(self, info)
	ys.EventListener.AttachEventListener(self)

	self._info = info
	self._attrManager = self._info:GetAttrManager()
	self._buffManager = self._info:GetBuffManager()

	self._info:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_FLEET_ATTR, self.onUpdateFleetAttr)
end

function CardPuzzleFleetIconList.init(self)
	self._buffIconList = {}
	self._attrIconList = {}
	self._tf = self._go.transform
	self._iconTpl = self._tf:Find("icon_tpl")
	self._iconContainer = self._tf:Find("icon_list")
end

--- 添加一个增益图标
function CardPuzzleFleetIconList.AddBuffIcon(self, buffID)
	local iconTF = cloneTplTo(self._iconTpl, self._iconContainer)
	local countLabel = iconTF:Find("count_bg/count_label")
	local iconImage = iconTF:Find("icon")
	local durationIMG = iconTF:Find("buff_duration"):GetComponent(typeof(Image))
	local iconData = {
		tf = iconTF,
		count = countLabel,
		durationIMG = durationIMG,
		buffID = buffID
	}

	self._buffIconList[buffID] = iconData

	self:updateBuffIcon(iconData)
end

--- 添加一个属性图标
function CardPuzzleFleetIconList.AddAttrIcon(self, attrName)
	local iconTF = cloneTplTo(self._iconTpl, self._iconContainer)
	local countLabel = iconTF:Find("count_bg/count_label")
	local iconImage = iconTF:Find("icon")
	local iconData = {
		tf = iconTF,
		count = countLabel,
		attr = attrName
	}

	self._attrIconList[attrName] = iconData

	self:updateAttrIcon(iconData)
end

--- 舰队属性更新事件回调
function CardPuzzleFleetIconList.onUpdateFleetAttr(self, event)
	local attrName = event.Data.attrName

	if BattleCardPuzzleConfig.FleetIconRegisterAttr[attrName] then
		local iconData = self._attrIconList[attrName]

		if iconData then
			self:updateAttrIcon(iconData)
		else
			self:AddAttrIcon(attrName)
		end
	end
end

--- 更新属性图标的数值
function CardPuzzleFleetIconList.updateAttrIcon(self, iconData)
	local countTF = iconData.count
	local attrName = iconData.attr
	local currentValue = self._attrManager:GetCurrent(attrName)

	setText(countTF, currentValue)
end

--- 更新增益图标的层数和持续时间
function CardPuzzleFleetIconList.updateBuffIcon(self, iconData)
	local buffID = iconData.buffID
	local buff = self._buffManager:GetCardPuzzleBuff(buffID)
	local countTF = iconData.count
	local stackCount = buff:GetStack()

	setText(countTF, stackCount)

	iconData.durationIMG.fillAmount = buff:GetDurationRate()
end

--- 每帧更新：检测新增的Buff并动态创建图标
function CardPuzzleFleetIconList.Update(self)
	local buffList = self._buffManager:GetCardPuzzleBuffList()

	for buffID, buff in pairs(buffList) do
		if BattleCardPuzzleConfig.FleetIconRegisterBuff[buffID] then
			local iconData = self._buffIconList[buffID]

			if iconData == nil then
				self:AddBuffIcon(buffID)
			else
				self:updateBuffIcon(iconData)
			end
		end
	end
end

function CardPuzzleFleetIconList.Dispose(self)
	self._buffIconList = nil
	self._attrIconList = nil
	self._tf = nil
	self._iconTpl = nil
	self._iconContainer = nil
end
