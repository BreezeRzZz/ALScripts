ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent

ys.Battle.CardPuzzleFleetHead = class("CardPuzzleFleetHead")

local CardPuzzleFleetHead = ys.Battle.CardPuzzleFleetHead

CardPuzzleFleetHead.__name = "CardPuzzleFleetHead"

--- 卡牌拼图舰队头像视图
--- 显示舰队旗舰和前锋的立绘头像，以及测试属性面板（开发用）

function CardPuzzleFleetHead.Ctor(self, go)
	self._go = go
	self._tf = self._go.transform
	self._mainIcon = self._tf:Find("main/icon")
	self._scoutIcon = self._tf:Find("scout/icon")
	self._testAttrContainer = self._tf:Find("test_attr_list")
	self._testAttrTpl = self._tf:Find("test_attr_tpl")
	self._testAttrList = {}
	self._loader = AutoLoader.New()
end

--- 设置关联的卡牌拼图组件
function CardPuzzleFleetHead.SetCardPuzzleComponent(self, info)
	ys.EventListener.AttachEventListener(self)

	self._info = info

	-- 测试属性面板（仅在开发模式下显示）
	if TEST_ATTR_PANEL then
		self._info:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_FLEET_ATTR, self.onUpdateFleetAttr)
		self:onUpdateFleetAttr()
	end
end

function CardPuzzleFleetHead.Update(self)
	return
end

--- 更新舰船立绘图标
--- @param pos number 舰队位置（FLAG_SHIP/LEADER）
function CardPuzzleFleetHead.UpdateShipIcon(self, pos)
	local unit
	local icon

	if pos == TeamType.TeamPos.FLAG_SHIP then
		unit = self._info:GetMainUnit()
		icon = self._mainIcon
	elseif pos == TeamType.TeamPos.LEADER then
		unit = self._info:GetScoutUnit()
		icon = self._scoutIcon
	end

	local paintingName = CardPuzzleShip.getPaintingName(unit:GetTemplate().id)

	self._loader:GetSprite("cardtowerselectships/" .. paintingName .. "_select", "", icon)
end

function CardPuzzleFleetHead.UpdateShipBuff(self)
	return
end

--- 舰队属性更新回调（测试面板用）
function CardPuzzleFleetHead.onUpdateFleetAttr(self)
	local attrList = self._info:GetAttrManager()._attrList

	for attrName, attrValue in pairs(attrList) do
		if self._testAttrList[attrName] == nil then
			local attrTF = cloneTplTo(self._testAttrTpl, self._testAttrContainer)

			self._testAttrList[attrName] = attrTF

			setText(attrTF:Find("name"), attrName)
		end

		local attrTF = self._testAttrList[attrName]
		local currentValue = self._info:GetAttrManager():GetCurrent(attrName)

		setText(attrTF:Find("value"), currentValue)
	end
end

function CardPuzzleFleetHead.updateHPBar(self)
	return
end

function CardPuzzleFleetHead.Dispose(self)
	self._mainIcon = nil
	self._scoutIcon = nil
	self._testAttrContainer = nil
	self._testAttrTpl = nil
	self._testAttrList = nil

	self._loader:Clear()
end
