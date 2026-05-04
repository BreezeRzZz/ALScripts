ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleDuelDamageRateView = class("BattleDuelDamageRateView")

ys.Battle.BattleDuelDamageRateView = BattleDuelDamageRateView
BattleDuelDamageRateView.__name = "BattleDuelDamageRateView"

--- 演习/对决中的双方伤害进度条视图
--- 显示己方和敌方的伤害百分比进度条
--- @param go GameObject 伤害进度条UI的GameObject
function BattleDuelDamageRateView.Ctor(self, go)
	ys.EventListener.AttachEventListener(self)

	self._go = go
	self._tf = go.transform
	self._progressList = {}
	self._rateBarList = {}
	self._fleetList = {}
	-- 左方为己方伤害条，右方为敌方伤害条
	self._rateBarList[BattleConfig.FRIENDLY_CODE] = self._tf:Find("leftDamageBar")
	self._rateBarList[BattleConfig.FOE_CODE] = self._tf:Find("rightDamageBar")
end

--- 显示/隐藏视图
--- @param isActive boolean
function BattleDuelDamageRateView.SetActive(self, isActive)
	setActive(self._go, isActive)
end

--- 设置要跟踪的舰队VO，显示对应的名称和等级
--- @param fleetVO table 舰队VO对象
--- @param fleetData table 舰队数据，含name和level字段
function BattleDuelDamageRateView.SetFleetVO(self, fleetVO, fleetData)
	self._fleetList[fleetVO] = true

	local rateBar = self._rateBarList[fleetVO:GetIFF()]

	rateBar:Find("nameText"):GetComponent(typeof(Text)).text = fleetData.name
	rateBar:Find("LVText"):GetComponent(typeof(Text)).text = "Lv." .. fleetData.level

	local progressImage = rateBar:Find("bar/progress"):GetComponent(typeof(Image))

	self._progressList[fleetVO:GetIFF()] = progressImage

	-- 监听舰队伤害变化事件
	fleetVO:RegisterEventListener(self, BattleEvent.FLEET_DMG_CHANGE, self.onDMGChange)
end

--- 舰队伤害变化事件回调，更新进度条
--- @param event table 事件对象，event.Dispatcher为舰队VO
function BattleDuelDamageRateView.onDMGChange(self, event)
	local fleet = event.Dispatcher
	local iff = fleet:GetIFF()

	self._progressList[iff].fillAmount = fleet:GetDamageRatio()
end

--- 清理事件监听和引用
function BattleDuelDamageRateView.Dispose(self)
	for fleetVO, _ in pairs(self._fleetList) do
		fleetVO:UnregisterEventListener(self, BattleEvent.FLEET_DMG_CHANGE)
	end

	self._rateBarList = nil
	self._progressList = nil
end
