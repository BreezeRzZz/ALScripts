ys = ys or {}
-- 对应进入单个Dungeon战斗的指令处理（主要涉及战斗初始化、波次管理、战斗结束等逻辑）
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
--- @class BattleSingleDungeonCommand : 单个Dungeon战斗Command，管理战斗生命周期
local BattleSingleDungeonCommand = class("BattleSingleDungeonCommand", ys.MVC.Command)

ys.Battle.BattleSingleDungeonCommand = BattleSingleDungeonCommand
BattleSingleDungeonCommand.__name = "BattleSingleDungeonCommand"

function BattleSingleDungeonCommand.Ctor(self)
	BattleSingleDungeonCommand.super.Ctor(self)
end

function BattleSingleDungeonCommand.Initialize(self)
	BattleSingleDungeonCommand.super.Initialize(self)
	--- @type BattleDataProxy
	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	--- @type BattleUIMediator
	self._uiMediator = self._state:GetUIMediator()

	self:Init()
	self:InitProtocol()
	self:AddEvent()

	self._count = 0
end

-- 入场时的各种特效和准备工作
function BattleSingleDungeonCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function afterSurfaceShift()
		self._uiMediator:OpeningEffect(function()
			self._uiMediator:ShowAutoBtn()
			self._uiMediator:ShowTimer()
			self._state:GetCommandByName(ys.Battle.BattleControllerWeaponCommand.__name):TryAutoSub()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()

			if self._dataProxy:GetInitData().hideAllButtons then
				self._dataProxy:DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.HIDE_INTERACTABLE_BUTTONS, {
					isActive = false
				}))
			end
		end)
		-- 开场的台词
		self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE):FleetWarcry()
		-- 初始化武器CD和战斗开始Buff
		self._dataProxy:InitAllFleetUnitsWeaponCD()
		self._dataProxy:TirggerBattleStartBuffs()
		-- 潜艇支援弹幕
		self._dataProxy:ChapterSupportBarrage(ys.Battle.BattleConfig.FRIENDLY_CODE, ys.Battle.BattleConfig.SubSupportDelay)
	end
	-- 等效45帧(1.5s)后再执行afterSurfaceShift
	self._uiMediator:SeaSurfaceShift(45, 0, nil, afterSurfaceShift)
end

function BattleSingleDungeonCommand.Init(self)
	self._unitDataList = {}

	self:initWaveModule()
end

function BattleSingleDungeonCommand.Clear(self)
	for unitID, unit in pairs(self._unitDataList) do
		self:UnregisterUnitEvent(unit)

		self._unitDataList[unitID] = nil
	end

	self._waveUpdater:Clear()
end

function BattleSingleDungeonCommand.Reinitialize(self)
	self._state:Deactive()
	self:Clear()
	self:Init()
end

function BattleSingleDungeonCommand.Dispose(self)
	self:Clear()
	self:RemoveEvent()
	BattleSingleDungeonCommand.super.Dispose(self)
end

function BattleSingleDungeonCommand.SetVertifyFail(self, isFail)
	if not self._vertifyFail then
		self._vertifyFail = isFail
	end
end

function BattleSingleDungeonCommand.onInitBattle(self)
	self._userFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

	self._waveUpdater:SetWavesData(self._dataProxy:GetStageInfo())
end

function BattleSingleDungeonCommand.initWaveModule(self)
	-- 刷怪的回调函数
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE)
	end
	-- 敌方飞机的生成回调函数
	local function airFighterFunc(tmpData)
		self._dataProxy:SpawnAirFighter(tmpData)
	end
	-- 战斗结束的回调函数
	local function clearFunc()
		if self._vertifyFail then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._vertifyFail
			})

			return
		end

		self._dataProxy:TriggerFinishBattle()
		self:CalcStatistic()
		self._state:BattleEnd()
	end

	--- 区域生成回调（水面AOE区域）
	local function spawnAreaFunc(areaID, arg1, arg2, arg3, arg4)
		self._dataProxy:SpawnCubeArea(ys.Battle.BattleConst.AOEField.SURFACE, -1, areaID, arg1, arg2, arg3, arg4)
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
end

function BattleSingleDungeonCommand.InitProtocol(self)
	return
end

--- 注册战斗事件监听
function BattleSingleDungeonCommand.AddEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH, self.onInitBattle)
	self._dataProxy:RegisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER, self.onPlayerShutDown)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN, self.onUpdateCountDown)
end

--- 移除战斗事件监听
function BattleSingleDungeonCommand.RemoveEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_COUNT_DOWN)
end

--- 新增单位事件，区分敌我类型加入波次管理
function BattleSingleDungeonCommand.onAddUnit(self, event)
	local unitType = event.Data.type
	local unit = event.Data.unit

	self:RegisterUnitEvent(unit)

	self._unitDataList[unit:GetUniqueID()] = unit

	if unitType == ys.Battle.BattleConst.UnitType.ENEMY_UNIT or unitType == ys.Battle.BattleConst.UnitType.BOSS_UNIT then
		self._waveUpdater:AddMonster(unit)
	end
end

--- 为单位注册死亡等事件监听
function BattleSingleDungeonCommand.RegisterUnitEvent(self, unit)
	local unitType = unit:GetUnitType()

	if unitType ~= ys.Battle.BattleConst.UnitType.MINION_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.WILL_DIE, self.onWillDie)
	end

	unit:RegisterEventListener(self, BattleUnitEvent.DYING, self.onUnitDying)

	if unitType == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER, self.onShutDownPlayer)
	end
end

--- 移除单位的事件监听
function BattleSingleDungeonCommand.UnregisterUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.WILL_DIE)
	unit:UnregisterEventListener(self, BattleUnitEvent.DYING)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:UnregisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER)
	end
end

--- 移除单位事件，从波次管理和单位列表中移除
function BattleSingleDungeonCommand.onRemoveUnit(self, event)
	local uid = event.Data.UID

	self._waveUpdater:RemoveMonster(uid)

	local unit = self._unitDataList[uid]

	if unit == nil then
		return
	end

	self:UnregisterUnitEvent(unit)

	self._unitDataList[uid] = nil
end

--- 玩家单位停机事件，旗舰死亡或前排全灭则战斗结束
function BattleSingleDungeonCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	if event.Data.unit == self._userFleet:GetFlagShip() and self._dataProxy:GetInitData().battleType ~= SYSTEM_PROLOGUE and self._dataProxy:GetInitData().battleType ~= SYSTEM_PERFORM then
		self._dataProxy:TriggerFinishBattle()
		self:CalcStatistic()
		self._state:BattleEnd()

		return
	end

	if #self._userFleet:GetScoutList() == 0 then
		self._dataProxy:TriggerFinishBattle()
		self:CalcStatistic()
		self._state:BattleEnd()
	end
end

--- 倒计时更新，倒计时归零时触发敌人逃跑和超时结算
function BattleSingleDungeonCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self:CalcStatistic()
		self._state:BattleTimeUp()
	end
end

--- 单位正在死亡事件，通知DataProxy击杀该单位
function BattleSingleDungeonCommand.onUnitDying(self, event)
	local uid = event.Dispatcher:GetUniqueID()

	self._dataProxy:KillUnit(uid)
end

-- note: 单位死亡前的回调函数，涉及结算BP、分数、以及Boss死亡后是否结束战斗等逻辑
function BattleSingleDungeonCommand.onWillDie(self, event)
	local unit = event.Dispatcher
	local deathReason = ys.Battle.BattleConst.UnitDeathReason
	local reason = unit:GetDeathReason()

	if reason == deathReason.LEAVE then
		if unit:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE then
			self._dataProxy:CalcBPWhenPlayerLeave(unit)
		end
	elseif reason == deathReason.DESTRUCT then
		self._dataProxy:CalcBattleScoreWhenDead(unit)

		if unit:IsBoss() then
			self._dataProxy:AddScoreWhenBossDestruct()
		end
	else
		self._dataProxy:CalcBattleScoreWhenDead(unit)
	end

	local hasBoss = self._dataProxy:IsThereBoss()

	if unit:IsBoss() and not hasBoss then
		self._dataProxy:KillAllEnemy()
	end
end

--- 玩家单位被停机，通知DataProxy处理
function BattleSingleDungeonCommand.onShutDownPlayer(self, event)
	local uid = event.Dispatcher:GetUniqueID()

	self._dataProxy:ShutdownPlayerUnit(uid)
end

--- 获取所有Boss波次中存活Boss的最大剩余HP比例
function BattleSingleDungeonCommand.GetMaxRestHPRateBossRate(self)
	local allBossWave = self._waveUpdater:GetAllBossWave()

	for _, bossWave in ipairs(allBossWave) do
		if bossWave:GetState() == bossWave.STATE_DEACTIVE then
			return 10000
		end
	end

	local maxHPRate = 0

	for _, unit in pairs(self._dataProxy:GetUnitList()) do
		if unit:IsBoss() and unit:IsAlive() then
			maxHPRate = math.max(maxHPRate, unit:GetHPRate())
		end
	end

	return maxHPRate * 10000
end

--- 计算单个Dungeon的结算统计
function BattleSingleDungeonCommand.CalcStatistic(self)
	self._dataProxy:CalcSingleDungeonScoreAtEnd(self._userFleet)

	local maxRestHPRateBossRate = self:GetMaxRestHPRateBossRate()

	self._dataProxy:CalcMaxRestHPRateBossRate(maxRestHPRateBossRate)
end
