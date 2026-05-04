ys = ys or {}

-- 模拟战（PVP 演习）战斗Command，不继承SingleDungeonCommand而是直接继承MVC.Command
-- 核心特性：双舰队对战（user vs rival），AI自动操控双方武器/摇杆，HP伤害统计，增益倒计时系统
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleSimulationCommand = class("BattleSimulationCommand", ys.MVC.Command)

ys.Battle.BattleSimulationCommand = BattleSimulationCommand
BattleSimulationCommand.__name = "BattleSimulationCommand"

function BattleSimulationCommand.Ctor(self)
	BattleSimulationCommand.super.Ctor(self)
end

-- 配置战斗初始化数据（由外部调用传入）
--- @param self BattleSimulationCommand
--- @param battleInitData table 战斗初始化数据
function BattleSimulationCommand.ConfigBattleData(self, battleInitData)
	self._battleInitData = battleInitData
end

function BattleSimulationCommand.Initialize(self)
	self:Init()
	BattleSimulationCommand.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	self._uiMediator = self._state:GetMediatorByName(ys.Battle.BattleUIMediator.__name)

	self:InitProtocol()
	self:AddEvent()
end

-- 入场序幕：初始化敌我双方舰队，设置AI自动Bot，应用buff，开始增益倒计时
function BattleSimulationCommand.DoPrologue(self)
	-- 将敌方舰队数据初始化为FOE_CODE部队
	self._dataProxy:InitUserShipsData(self._battleInitData.RivalMainUnitList, self._battleInitData.RivalVanguardUnitList, ys.Battle.BattleConfig.FOE_CODE, {})
	self._userFleet:SnapShot()
	self._rivalFleet:SnapShot()

	-- 敌方AI：武器自动Bot + 摇杆自动Bot
	self._rivalWeaponBot = ys.Battle.BattleManualWeaponAutoBot.New(self._rivalFleet)
	self._rivalJoyStickBot = ys.Battle.BattleJoyStickAutoBot.New(self._dataProxy, self._rivalFleet)
	-- 增益倒计时UI
	self._buffView = self._uiMediator:InitSimulationBuffCounting()

	self._uiMediator:OpeningEffect(function()
		self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
		self._uiMediator:ShowAutoBtn()
		self._rivalWeaponBot:SetActive(true, false)
		self._rivalJoyStickBot:SetActive(true)
		self._uiMediator:ShowTimer()
		self._uiMediator:ShowSimulationView()
	end)
	self._userFleet:FleetWarcry()
	self._dataProxy:InitAllFleetUnitsWeaponCD()
	self._dataProxy:TirggerBattleStartBuffs()

	-- 给己方所有单位添加平衡buff（演习平衡机制）
	local unitList = self._userFleet:GetUnitList()

	for _, unit in ipairs(unitList) do
		local balanceBuff = ys.Battle.BattleBuffUnit.New(ys.Battle.BattleConfig.SIMULATION_BALANCE_BUFF)

		unit:AddBuff(balanceBuff)
	end

	-- 判断敌方前排数量，决定是否进入劣势阶段
	local scoutCount = #self._rivalFleet:GetScoutList()
	local mainList = self._rivalFleet:GetMainList()
	local unusedVar

	if scoutCount == 0 then
		-- 无前排 → 直接进入主机队阶段
		self:rivalMainUnitPhase()
	elseif scoutCount > 0 then
		-- 有前排 → 给主机队添加优势buff
		local advantageBuffID = ys.Battle.BattleConfig.SIMULATION_ADVANTAGE_BUFF

		self._rivalDisadvatage = false

		for _, mainUnit in ipairs(mainList) do
			local advantageBuff = ys.Battle.BattleBuffUnit.New(advantageBuffID)

			mainUnit:AddBuff(advantageBuff)
		end
	end

	self:startBuffCount()
	self._dataProxy:RivalInit(self._rivalFleet:GetUnitList())
end

-- 每帧更新：驱动敌方武器Bot
function BattleSimulationCommand.Update(self)
	self._rivalWeaponBot:Update()
end

function BattleSimulationCommand.Init(self)
	self._unitDataList = {}
end

-- 清理所有注册的单位事件
function BattleSimulationCommand.Clear(self)
	for uid, unit in pairs(self._unitDataList) do
		self:UnregisterUnitEvent(unit)

		self._unitDataList[uid] = nil
	end
end

function BattleSimulationCommand.Reinitialize(self)
	self._state:Deactive()
	self:Clear()
	self:Init()
end

function BattleSimulationCommand.Dispose(self)
	self:Clear()
	self:RemoveEvent()
	BattleSimulationCommand.super.Dispose(self)
end

-- 战斗数据初始化完成后获取舰队引用
function BattleSimulationCommand.onInitBattle(self)
	self._weaponCommand = self._state:GetCommandByName(ys.Battle.BattleControllerWeaponCommand.__name)
	self._userFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
	self._rivalFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FOE_CODE)
end

function BattleSimulationCommand.InitProtocol(self)
	return
end

-- 注册核心战斗事件：单位添加/移除、数据初始化完毕、玩家沉没、倒计时更新
function BattleSimulationCommand.AddEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH, self.onInitBattle)
	self._dataProxy:RegisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER, self.onPlayerShutDown)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN, self.onUpdateCountDown)
end

function BattleSimulationCommand.RemoveEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN)
end

-- 单位添加事件：注册单位事件并记录到unitDataList
function BattleSimulationCommand.onAddUnit(self, event)
	local unitType = event.Data.type
	local unit = event.Data.unit

	self:RegisterUnitEvent(unit)

	self._unitDataList[unit:GetUniqueID()] = unit
end

-- 为单位注册事件：DYING（濒死）、UPDATE_HP（血量更新）、PLAYER_UNIT额外注册SHUT_DOWN_PLAYER
function BattleSimulationCommand.RegisterUnitEvent(self, unit)
	unit:RegisterEventListener(self, BattleUnitEvent.DYING, self.onUnitDying)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUpdateUnitHP)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER, self.onShutDownPlayer)
	end
end

function BattleSimulationCommand.UnregisterUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.DYING)
	unit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:UnregisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER)
	end
end

-- 单位移除事件：从waveUpdater和unitDataList中清除
function BattleSimulationCommand.onRemoveUnit(self, event)
	local uid = event.Data.UID
	local unit = self._unitDataList[uid]

	if unit == nil then
		return
	end

	self:UnregisterUnitEvent(unit)

	self._unitDataList[uid] = nil
end

-- 玩家方有人沉没/全灭的判定逻辑
-- 包含反作弊验证（Vertify），以及rival劣势阶段切换
function BattleSimulationCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	-- 首轮沉没时执行反作弊校验
	if self._failReason == nil then
		ys.Battle.BattleState.GenerateVertifyData(1)

		local vertifyResult, vertifyCode = ys.Battle.BattleState.Vertify()

		if not vertifyResult then
			self._failReason = 900 + vertifyCode
		end
	end

	-- 敌方全灭 → 判定胜负
	if #self._rivalFleet:GetUnitList() == 0 then
		self._dataProxy:CalcSimulationScoreAtEnd(self._userFleet, self._rivalFleet)

		if self._failReason then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._failReason
			})

			return
		end

		self._failReason = nil

		self._dataProxy:TriggerFinishBattle()
		self._state:BattleEnd()
	end

	-- 己方旗舰沉没 → 失败
	if event.Data.unit == self._userFleet:GetFlagShip() then
		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcSimulationScoreAtEnd(self._userFleet, self._rivalFleet)
		self._state:BattleEnd()

		return
	end

	-- 己方前排全灭 → 失败
	if #self._userFleet:GetScoutList() == 0 then
		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcSimulationScoreAtEnd(self._userFleet, self._rivalFleet)
		self._state:BattleEnd()
	end

	-- 敌方前排全灭且当前非劣势阶段 → 切换至rival主机队阶段
	if #self._rivalFleet:GetScoutList() == 0 and not self._rivalDisadvatage then
		self:rivalMainUnitPhase()
	end
end

-- 敌方主机队阶段：敌方前排被全灭后，主机队获得劣势buff，停止AI移动
function BattleSimulationCommand.rivalMainUnitPhase(self)
	self:startBuffCount()

	self._rivalDisadvatage = true

	self._rivalJoyStickBot:SetActive(false)
	self._rivalFleet:FreeMainUnit(ys.Battle.BattleConfig.SIMULATION_FREE_BUFF)

	local mainList = self._rivalFleet:GetMainList()

	for _, mainUnit in ipairs(mainList) do
		-- 移除之前的优势buff
		for _, buffID in ipairs(ys.Battle.BattleConfig.SIMULATION_ADVANTAGE_CANCEL_LIST) do
			mainUnit:RemoveBuff(buffID)
		end

		-- 添加劣势buff
		local disadvantageBuff = ys.Battle.BattleBuffUnit.New(ys.Battle.BattleConfig.SIMULATION_DISADVANTAGE_BUFF)

		mainUnit:AddBuff(disadvantageBuff)
	end
end

-- 倒计时更新：驱动增益倒计时UI，倒计时归零则按伤害比判定胜负
function BattleSimulationCommand.onUpdateCountDown(self, event)
	local countDown = self._dataProxy:GetCountDown()

	-- 增益倒计时逻辑：到达rage计数后显示"增强中"提示
	if self._buffStartTime then
		local remainingCount = ys.Battle.BattleConfig.SIMULATION_RIVAL_RAGE_TOTAL_COUNT - (self._buffStartTime - countDown)

		if remainingCount <= 0 then
			pg.TipsMgr.GetInstance():ShowTips(i18n("simulation_enhancing"))

			self._buffStartTime = nil

			self._buffView:SetEnhancedText()
		else
			self._buffView:SetCountDownText(remainingCount)
		end
	end

	-- 主倒计时归零 → 按双方伤害比率结算
	if countDown <= 0 then
		local userDmgRatio, userDmgRatioHp = self._userFleet:GetDamageRatioResult()
		local rivalDmgRatio, rivalDmgRatioHp = self._rivalFleet:GetDamageRatioResult()

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcSimulationScoreAtTimesUp(userDmgRatio, rivalDmgRatio, userDmgRatioHp, rivalDmgRatioHp, self._rivalFleet)
		self._state:BattleEnd()
	end
end

-- 单位HP更新 → 将有效伤害累加到对应的FleetVO
function BattleSimulationCommand.onUpdateUnitHP(self, event)
	local fleetVO = event.Dispatcher:GetFleetVO()

	if fleetVO then
		local validDHP = event.Data.validDHP

		fleetVO:UpdateFleetDamage(validDHP)
	end
end

-- 单位濒死 → 计算击杀分数并移除单位
function BattleSimulationCommand.onUnitDying(self, event)
	local unit = event.Dispatcher
	local uid = unit:GetUniqueID()

	self._dataProxy:CalcBattleScoreWhenDead(unit)
	self._dataProxy:KillUnit(uid)
end

-- 玩家单位ShutDown → 计算溢出伤害并移除
function BattleSimulationCommand.onShutDownPlayer(self, event)
	local unit = event.Dispatcher
	local uid = unit:GetUniqueID()

	unit:GetFleetVO():UpdateFleetOverDamage(unit)
	self._dataProxy:ShutdownPlayerUnit(uid)
end

-- 开始增益倒计时：记录当前剩余时间作为基准
function BattleSimulationCommand.startBuffCount(self)
	self._buffStartTime = self._dataProxy:GetCountDown()
end
