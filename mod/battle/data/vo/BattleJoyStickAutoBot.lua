ys = ys or {}

local ys = ys

ys.Battle.BattleJoyStickAutoBot = class("BattleJoyStickAutoBot")

local BattleJoyStickAutoBot = ys.Battle.BattleJoyStickAutoBot

BattleJoyStickAutoBot.__name = "BattleJoyStickAutoBot"
-- 一共来讲，有四种Strategy
-- 1. CounterMainRandomStrategy: 没用过，不知道是啥
-- 2. RandomStrategy: 前排自律移动逻辑
-- 3. AutoPilotStrategy: 由AI模板逻辑控制
-- 4. IdleStrategy: 静止不动
BattleJoyStickAutoBot.COUNTER_MAIN = "CounterMainRandomStrategy"
BattleJoyStickAutoBot.RANDOM = "RandomStrategy"
BattleJoyStickAutoBot.AUTO_PILOT = "AutoPilotStrategy"
BattleJoyStickAutoBot.IDLE = "IdleStrategy"

-- BattleJoyStickAutoBot: 管理的是舰队的摇杆自动控制(前排的自律移动，对应摇杆)
-- 在BattleControllerWeaponCommand.onUnitInitFinish中初始化
function BattleJoyStickAutoBot.Ctor(self, dataProxy, fleetVO)
	self._dataProxy = dataProxy
	self._fleetVO = fleetVO

	self:init()
end

function BattleJoyStickAutoBot.UpdateFleetArea(self)
	if self._strategy then
		self._strategy:SetBoardBound(self._fleetVO:GetFleetBound())
	end
end

function BattleJoyStickAutoBot.FleetFormationUpdate(self)
	if self._strategy:GetStrategyType() == BattleJoyStickAutoBot.AUTO_PILOT then
		self:SwitchStrategy(BattleJoyStickAutoBot.AUTO_PILOT)
	end
end

function BattleJoyStickAutoBot.SetActive(self, active)
	self._active = active

	if active then
		local function motionFunc()
			return self._strategy:Output()
		end

		self._fleetVO:SetMotionSource(motionFunc)
	else
		self._fleetVO:SetMotionSource()
	end
end

function BattleJoyStickAutoBot.SwitchStrategy(self, strategyName)
	if self._strategy then
		self._strategy:Dispose()
	end

	self._strategy = ys.Battle[strategyName].New(self._fleetVO)

	self:UpdateFleetArea()
	self._strategy:Input(self._dataProxy:GetFoeShipList(), self._dataProxy:GetFoeAircraftList())
end

function BattleJoyStickAutoBot.init(self)
	self._active = false
	self._uiMgr = pg.UIMgr.GetInstance()
end

function BattleJoyStickAutoBot.Dispose(self)
	if self._strategy then
		self._strategy:Dispose()
	end

	self._dataProxy = nil
	self._uiMediator = nil
	self._uiMgr = nil
end
