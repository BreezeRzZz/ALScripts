ys = ys or {}

--- @class BattleDuelArenaCommand : ys.MVC.Command
--- PvP 演习竞技场战斗指令。管理双方舰队的初始化、AI 机器人控制、
--- 演习 HP 血条同步、验证防作弊、以及双前锋全灭后的主力狂暴 Buff 等逻辑。
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleDuelArenaCommand = class("BattleDuelArenaCommand", ys.MVC.Command)

ys.Battle.BattleDuelArenaCommand = BattleDuelArenaCommand
BattleDuelArenaCommand.__name = "BattleDuelArenaCommand"

function BattleDuelArenaCommand.Ctor(self)
	BattleDuelArenaCommand.super.Ctor(self)
end

--- 初始化指令。获取 dataProxy 和 uiMediator，初始化协议并注册事件。
function BattleDuelArenaCommand.Initialize(self)
	self:Init()
	BattleDuelArenaCommand.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	self._uiMediator = self._state:GetMediatorByName(ys.Battle.BattleUIMediator.__name)

	self:InitProtocol()
	self:AddEvent()
end

--- 开场序幕。初始化敌方舰队数据、创建 AI 机器人、添加竞技场 Buff、
--- 显示演习血条并激活双方武器自动射击。
function BattleDuelArenaCommand.DoPrologue(self)
	local initData = self._dataProxy:GetInitData()

	-- 根据对手数据初始化敌方舰队
	self._dataProxy:InitUserShipsData(initData.RivalMainUnitList, initData.RivalVanguardUnitList, ys.Battle.BattleConfig.FOE_CODE, {})
	self._userFleet:SnapShot()
	self._rivalFleet:SnapShot()

	-- 创建对手的武器自动射击机器人和摇杆机器人
	self._rivalWeaponBot = ys.Battle.BattleManualWeaponAutoBot.New(self._rivalFleet)
	self._rivalJoyStickBot = ys.Battle.BattleJoyStickAutoBot.New(self._dataProxy, self._rivalFleet)

	-- 对手使用随机移动策略
	self._rivalJoyStickBot:SwitchStrategy(self._rivalJoyStickBot.RANDOM)

	local duelRateBar = self._uiMediator:InitDuelRateBar()
	local playerData = getProxy(PlayerProxy):getData()

	duelRateBar:SetFleetVO(self._userFleet, {
		name = playerData.name,
		level = playerData.level
	})

	local rivalVO = self._dataProxy:GetInitData().RivalVO

	duelRateBar:SetFleetVO(self._rivalFleet, {
		name = rivalVO.name,
		level = rivalVO.level
	})
	self._dataProxy:AutoStatistics(1)
	self._uiMediator:OpeningEffect(function()
		self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
		self._weaponCommand:ActiveBot(true, false)
		self._rivalWeaponBot:SetActive(true, false)
		self._rivalJoyStickBot:SetActive(true)
		self._uiMediator:InitCameraGestureSlider()
		self._uiMediator:ShowTimer()
		self._uiMediator:ShowDuelBar()
		self._uiMediator:EnableJoystick(false)
		self._uiMediator:EnableWeaponButton(false)
	end)

	-- 为所有单位的舰种类型添加竞技场 Buff
	local fleetList = self._dataProxy:GetFleetList()

	for _, fleet in pairs(fleetList) do
		fleet:FleetWarcry()

		local unitList = fleet:GetUnitList()

		for _, unit in ipairs(unitList) do
			local shipType = unit:GetTemplate().type
			local arenaBuffs = ys.Battle.BattleDataFunction.GetArenaBuffByShipType(shipType)

			for _, buffID in ipairs(arenaBuffs) do
				local buff = ys.Battle.BattleBuffUnit.New(buffID)

				unit:AddBuff(buff)
			end
		end
	end

	self._uiMediator:EnableWeaponButton(false)
	self._dataProxy:InitAllFleetUnitsWeaponCD()
	self._dataProxy:TirggerBattleStartBuffs()

	-- 给己方所有单位添加演习平衡 Buff
	local userUnitList = self._userFleet:GetUnitList()

	for _, unit in ipairs(userUnitList) do
		local balanceBuff = ys.Battle.BattleBuffUnit.New(ys.Battle.BattleConfig.DULE_BALANCE_BUFF)

		unit:AddBuff(balanceBuff)
	end
end

--- 每帧更新对手武器机器人。
function BattleDuelArenaCommand.Update(self)
	self._rivalWeaponBot:Update()
end

function BattleDuelArenaCommand.Init(self)
	self._unitDataList = {}
end

function BattleDuelArenaCommand.Clear(self)
	for unitID, unit in pairs(self._unitDataList) do
		self:UnregisterUnitEvent(unit)

		self._unitDataList[unitID] = nil
	end
end

function BattleDuelArenaCommand.Reinitialize(self)
	self._state:Deactive()
	self:Clear()
	self:Init()
end

function BattleDuelArenaCommand.Dispose(self)
	self:Clear()
	self:RemoveEvent()
	BattleDuelArenaCommand.super.Dispose(self)
end

--- 战斗数据初始化完成后的回调，获取双方舰队引用和武器指令。
function BattleDuelArenaCommand.onInitBattle(self)
	self._weaponCommand = self._state:GetCommandByName(ys.Battle.BattleControllerWeaponCommand.__name)
	self._userFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
	self._rivalFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FOE_CODE)
end

function BattleDuelArenaCommand.InitProtocol(self)
	return
end

function BattleDuelArenaCommand.AddEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH, self.onInitBattle)
	self._dataProxy:RegisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER, self.onPlayerShutDown)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN, self.onUpdateCountDown)
end

function BattleDuelArenaCommand.RemoveEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN)
end

--- 单位添加事件回调。
--- @param event table 包含 Data.type 和 Data.unit 的事件数据
function BattleDuelArenaCommand.onAddUnit(self, event)
	local unitType = event.Data.type
	local unit = event.Data.unit

	self:RegisterUnitEvent(unit)

	self._unitDataList[unit:GetUniqueID()] = unit
end

--- 为单位注册事件监听。同时监听 DYING、UPDATE_HP 和 PLAYER_UNIT 的 SHUT_DOWN_PLAYER。
--- @param unit BattleUnit 要注册的单位
function BattleDuelArenaCommand.RegisterUnitEvent(self, unit)
	unit:RegisterEventListener(self, BattleUnitEvent.DYING, self.onUnitDying)
	unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUpdateUnitHP)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER, self.onShutDownPlayer)
	end
end

--- 取消单位的注册事件。
function BattleDuelArenaCommand.UnregisterUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.DYING)
	unit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:UnregisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER)
	end
end

--- 单位移除事件回调。
function BattleDuelArenaCommand.onRemoveUnit(self, event)
	local uid = event.Data.UID
	local unit = self._unitDataList[uid]

	if unit == nil then
		return
	end

	self:UnregisterUnitEvent(unit)

	self._unitDataList[uid] = nil
end

--- 玩家单位沉没问题。处理演习胜负判定：
--- - 任一方舰队全灭时结算
--- - 前卫全灭但对方前卫存活时，对方舰队越界并切换反主力策略
--- - 双方前卫均全灭时，给双方主力添加狂暴 Buff（DUEL_MAIN_RAGE_BUFF）
function BattleDuelArenaCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	-- 第一次触发时进行防作弊验证
	if self._failReason == nil then
		ys.Battle.BattleState.GenerateVertifyData(1)

		local success, code = ys.Battle.BattleState.Vertify()

		if not success then
			self._failReason = 900 + code
		end
	end

	-- 任一方舰队全灭 -> 战斗结束
	if #self._userFleet:GetUnitList() == 0 or #self._rivalFleet:GetUnitList() == 0 then
		self._dataProxy:CalcDuelScoreAtEnd(self._userFleet, self._rivalFleet)

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

	local userScoutCount = #self._userFleet:GetScoutList()
	local rivalScoutCount = #self._rivalFleet:GetScoutList()

	-- 己方前卫全灭，对方前卫存活 -> 对方越界切换反主力策略
	if userScoutCount == 0 and rivalScoutCount ~= 0 then
		self._dataProxy:ShiftFleetBound(self._rivalFleet, ys.Battle.BattleConfig.FRIENDLY_CODE)
		self._rivalJoyStickBot:UpdateFleetArea()
		self._rivalJoyStickBot:SwitchStrategy(ys.Battle.BattleJoyStickAutoBot.COUNTER_MAIN)
	end

	-- 对方前卫全灭，己方前卫存活 -> 己方越界切换反主力策略
	if rivalScoutCount == 0 and userScoutCount ~= 0 then
		self._dataProxy:ShiftFleetBound(self._userFleet, ys.Battle.BattleConfig.FOE_CODE)
		self._weaponCommand:GetStickBot():UpdateFleetArea()
		self._weaponCommand:GetStickBot():SwitchStrategy(ys.Battle.BattleJoyStickAutoBot.COUNTER_MAIN)
	end

	-- 当沉没的并非主力单位，且双方前卫均已全灭时 -> 双方主力获得狂暴 Buff
	if not event.Data.unit:IsMainFleetUnit() and userScoutCount == 0 and rivalScoutCount == 0 then
		local userMainList = self._userFleet:GetMainList()
		local rivalMainList = self._rivalFleet:GetMainList()

		for _, unit in ipairs(userMainList) do
			local rageBuff = ys.Battle.BattleBuffUnit.New(ys.Battle.BattleConfig.DUEL_MAIN_RAGE_BUFF)

			unit:AddBuff(rageBuff)
		end

		for _, unit in ipairs(rivalMainList) do
			local rageBuff = ys.Battle.BattleBuffUnit.New(ys.Battle.BattleConfig.DUEL_MAIN_RAGE_BUFF)

			unit:AddBuff(rageBuff)
		end

		pg.TipsMgr.GetInstance():ShowTips(i18n("battle_duel_main_rage"))
	end
end

--- 倒计时归零时的时间到结算。比较双方伤害比例判定胜负。
--- @param event table 倒计时更新事件
function BattleDuelArenaCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		local userDmgRatio, userDmgNum = self._userFleet:GetDamageRatioResult()
		local rivalDmgRatio, rivalDmgNum = self._rivalFleet:GetDamageRatioResult()

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcDuelScoreAtTimesUp(userDmgRatio, rivalDmgRatio, userDmgNum, rivalDmgNum)
		self._state:BattleEnd()
	end
end

--- HP 更新事件回调。将有效伤害变化同步到 FleetVO 的伤害统计。
--- event.Data.validDHP 为有效 HP 变化量
function BattleDuelArenaCommand.onUpdateUnitHP(self, event)
	local fleetVO = event.Dispatcher:GetFleetVO()

	if fleetVO then
		local dHP = event.Data.validDHP

		fleetVO:UpdateFleetDamage(dHP)
	end
end

--- 单位死亡回调。非召唤物才计分。
function BattleDuelArenaCommand.onUnitDying(self, event)
	local unit = event.Dispatcher
	local uid = unit:GetUniqueID()

	if unit:GetUnitType() ~= ys.Battle.BattleConst.UnitType.MINION_UNIT then
		self._dataProxy:CalcBattleScoreWhenDead(unit)
	end

	self._dataProxy:KillUnit(uid)
end

--- 玩家单位停机回调。记录溢出伤害后关闭该单位。
function BattleDuelArenaCommand.onShutDownPlayer(self, event)
	local unit = event.Dispatcher
	local uid = unit:GetUniqueID()

	unit:GetFleetVO():UpdateFleetOverDamage(unit)
	self._dataProxy:ShutdownPlayerUnit(uid)
end
