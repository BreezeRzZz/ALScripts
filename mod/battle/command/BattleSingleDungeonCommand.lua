ys = ys or {}
-- 对应进入单个Dungeon战斗的指令处理（主要涉及战斗初始化、波次管理、战斗结束等逻辑）
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
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
	local function airFighterFunc(arg_14_0)
		self._dataProxy:SpawnAirFighter(arg_14_0)
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

	local function spawnAreaFunc(arg_16_0, arg_16_1, arg_16_2, arg_16_3, arg_16_4)
		self._dataProxy:SpawnCubeArea(ys.Battle.BattleConst.AOEField.SURFACE, -1, arg_16_0, arg_16_1, arg_16_2, arg_16_3, arg_16_4)
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
end

function BattleSingleDungeonCommand.InitProtocol(arg_17_0)
	return
end

function BattleSingleDungeonCommand.AddEvent(arg_18_0)
	arg_18_0._dataProxy:RegisterEventListener(arg_18_0, BattleEvent.ADD_UNIT, arg_18_0.onAddUnit)
	arg_18_0._dataProxy:RegisterEventListener(arg_18_0, BattleEvent.REMOVE_UNIT, arg_18_0.onRemoveUnit)
	arg_18_0._dataProxy:RegisterEventListener(arg_18_0, BattleEvent.STAGE_DATA_INIT_FINISH, arg_18_0.onInitBattle)
	arg_18_0._dataProxy:RegisterEventListener(arg_18_0, BattleEvent.SHUT_DOWN_PLAYER, arg_18_0.onPlayerShutDown)
	arg_18_0._dataProxy:RegisterEventListener(arg_18_0, BattleEvent.UPDATE_COUNT_DOWN, arg_18_0.onUpdateCountDown)
end

function BattleSingleDungeonCommand.RemoveEvent(arg_19_0)
	arg_19_0._dataProxy:UnregisterEventListener(arg_19_0, BattleEvent.ADD_UNIT)
	arg_19_0._dataProxy:UnregisterEventListener(arg_19_0, BattleEvent.REMOVE_UNIT)
	arg_19_0._dataProxy:UnregisterEventListener(arg_19_0, BattleEvent.STAGE_DATA_INIT_FINISH)
	arg_19_0._dataProxy:UnregisterEventListener(arg_19_0, BattleEvent.SHUT_DOWN_PLAYER)
	arg_19_0._dataProxy:UnregisterEventListener(arg_19_0, BattleEvent.UPDATE_COUNT_DOWN)
end

function BattleSingleDungeonCommand.onAddUnit(arg_20_0, arg_20_1)
	local var_20_0 = arg_20_1.Data.type
	local var_20_1 = arg_20_1.Data.unit

	arg_20_0:RegisterUnitEvent(var_20_1)

	arg_20_0._unitDataList[var_20_1:GetUniqueID()] = var_20_1

	if var_20_0 == ys.Battle.BattleConst.UnitType.ENEMY_UNIT or var_20_0 == ys.Battle.BattleConst.UnitType.BOSS_UNIT then
		arg_20_0._waveUpdater:AddMonster(var_20_1)
	end
end

function BattleSingleDungeonCommand.RegisterUnitEvent(arg_21_0, arg_21_1)
	local var_21_0 = arg_21_1:GetUnitType()

	if var_21_0 ~= ys.Battle.BattleConst.UnitType.MINION_UNIT then
		arg_21_1:RegisterEventListener(arg_21_0, BattleUnitEvent.WILL_DIE, arg_21_0.onWillDie)
	end

	arg_21_1:RegisterEventListener(arg_21_0, BattleUnitEvent.DYING, arg_21_0.onUnitDying)

	if var_21_0 == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		arg_21_1:RegisterEventListener(arg_21_0, BattleUnitEvent.SHUT_DOWN_PLAYER, arg_21_0.onShutDownPlayer)
	end
end

function BattleSingleDungeonCommand.UnregisterUnitEvent(arg_22_0, arg_22_1)
	arg_22_1:UnregisterEventListener(arg_22_0, BattleUnitEvent.WILL_DIE)
	arg_22_1:UnregisterEventListener(arg_22_0, BattleUnitEvent.DYING)

	if arg_22_1:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		arg_22_1:UnregisterEventListener(arg_22_0, BattleUnitEvent.SHUT_DOWN_PLAYER)
	end
end

function BattleSingleDungeonCommand.onRemoveUnit(arg_23_0, arg_23_1)
	local var_23_0 = arg_23_1.Data.UID

	arg_23_0._waveUpdater:RemoveMonster(var_23_0)

	local var_23_1 = arg_23_0._unitDataList[var_23_0]

	if var_23_1 == nil then
		return
	end

	arg_23_0:UnregisterUnitEvent(var_23_1)

	arg_23_0._unitDataList[var_23_0] = nil
end

function BattleSingleDungeonCommand.onPlayerShutDown(arg_24_0, arg_24_1)
	if arg_24_0._state:GetState() ~= arg_24_0._state.BATTLE_STATE_FIGHT then
		return
	end

	if arg_24_1.Data.unit == arg_24_0._userFleet:GetFlagShip() and arg_24_0._dataProxy:GetInitData().battleType ~= SYSTEM_PROLOGUE and arg_24_0._dataProxy:GetInitData().battleType ~= SYSTEM_PERFORM then
		arg_24_0._dataProxy:TriggerFinishBattle()
		arg_24_0:CalcStatistic()
		arg_24_0._state:BattleEnd()

		return
	end

	if #arg_24_0._userFleet:GetScoutList() == 0 then
		arg_24_0._dataProxy:TriggerFinishBattle()
		arg_24_0:CalcStatistic()
		arg_24_0._state:BattleEnd()
	end
end

function BattleSingleDungeonCommand.onUpdateCountDown(arg_25_0, arg_25_1)
	if arg_25_0._dataProxy:GetCountDown() <= 0 then
		arg_25_0._dataProxy:EnemyEscape()
		arg_25_0:CalcStatistic()
		arg_25_0._state:BattleTimeUp()
	end
end

function BattleSingleDungeonCommand.onUnitDying(arg_26_0, arg_26_1)
	local var_26_0 = arg_26_1.Dispatcher:GetUniqueID()

	arg_26_0._dataProxy:KillUnit(var_26_0)
end

function BattleSingleDungeonCommand.onWillDie(arg_27_0, arg_27_1)
	local var_27_0 = arg_27_1.Dispatcher
	local var_27_1 = ys.Battle.BattleConst.UnitDeathReason
	local var_27_2 = var_27_0:GetDeathReason()

	if var_27_2 == var_27_1.LEAVE then
		if var_27_0:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE then
			arg_27_0._dataProxy:CalcBPWhenPlayerLeave(var_27_0)
		end
	elseif var_27_2 == var_27_1.DESTRUCT then
		arg_27_0._dataProxy:CalcBattleScoreWhenDead(var_27_0)

		if var_27_0:IsBoss() then
			arg_27_0._dataProxy:AddScoreWhenBossDestruct()
		end
	else
		arg_27_0._dataProxy:CalcBattleScoreWhenDead(var_27_0)
	end

	local var_27_3 = arg_27_0._dataProxy:IsThereBoss()

	if var_27_0:IsBoss() and not var_27_3 then
		arg_27_0._dataProxy:KillAllEnemy()
	end
end

function BattleSingleDungeonCommand.onShutDownPlayer(arg_28_0, arg_28_1)
	local var_28_0 = arg_28_1.Dispatcher:GetUniqueID()

	arg_28_0._dataProxy:ShutdownPlayerUnit(var_28_0)
end

function BattleSingleDungeonCommand.GetMaxRestHPRateBossRate(arg_29_0)
	local var_29_0 = arg_29_0._waveUpdater:GetAllBossWave()

	for iter_29_0, iter_29_1 in ipairs(var_29_0) do
		if iter_29_1:GetState() == iter_29_1.STATE_DEACTIVE then
			return 10000
		end
	end

	local var_29_1 = 0

	for iter_29_2, iter_29_3 in pairs(arg_29_0._dataProxy:GetUnitList()) do
		if iter_29_3:IsBoss() and iter_29_3:IsAlive() then
			var_29_1 = math.max(var_29_1, iter_29_3:GetHPRate())
		end
	end

	return var_29_1 * 10000
end

function BattleSingleDungeonCommand.CalcStatistic(arg_30_0)
	arg_30_0._dataProxy:CalcSingleDungeonScoreAtEnd(arg_30_0._userFleet)

	local var_30_0 = arg_30_0:GetMaxRestHPRateBossRate()

	arg_30_0._dataProxy:CalcMaxRestHPRateBossRate(var_30_0)
end
