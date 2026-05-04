ys = ys or {}

-- 潜艇日常（SubRoutine）战斗Command，继承自BattleSubmarineRunCommand
-- 核心差异：添加buff 9040、玩家沉没后可手动切换替补潜艇、有独立的结算方法
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleConst = ys.Battle.BattleConst
local BattleSubRoutineCommand = class("BattleSubRoutineCommand", ys.Battle.BattleSubmarineRunCommand)

ys.Battle.BattleSubRoutineCommand = BattleSubRoutineCommand
BattleSubRoutineCommand.__name = "BattleSubRoutineCommand"

function BattleSubRoutineCommand.Ctor(self)
	BattleSubRoutineCommand.super.Ctor(self)
end

function BattleSubRoutineCommand.Initialize(self)
	BattleSubRoutineCommand.super.Initialize(self)
	self._dataProxy:SubmarineRunInit()
end

-- 入场序幕：除继承SubmarineRun的标准流程外，额外给所有单位添加buff 9040
function BattleSubRoutineCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function afterSurfaceShift()
		self._uiMediator:OpeningEffect(function()
			self._uiMediator:ShowTimer()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()
		end, SYSTEM_SUB_ROUTINE)

		-- 获取己方舰队，设置为自由下潜模式
		local fleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

		fleet:FleetWarcry()
		fleet:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE)
		fleet:GetSubBoostVO():ResetCurrent()
		self._dataProxy:InitAllFleetUnitsWeaponCD()
		self._dataProxy:TirggerBattleStartBuffs()
	end

	self._dataProxy:AutoStatistics(0)

	local unitList = self._userFleet:GetUnitList()

	for _, unit in ipairs(unitList) do
		-- 给所有单位添加SubRoutine专属buff 9040
		local subRoutineBuff = ys.Battle.BattleBuffUnit.New(9040)

		unit:AddBuff(subRoutineBuff)
		unit:RemoveBuff(8520)
	end

	self._uiMediator:SeaSurfaceShift(45, 0, nil, afterSurfaceShift)
end

-- 波次模块：无空袭和AOE区域，仅刷怪和结算（与SubmarineRun相同但结算方法不同）
function BattleSubRoutineCommand.initWaveModule(self)
	-- 刷怪回调
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE)
	end

	-- 战斗结束回调：使用SubRoutine专属结算
	local function clearFunc()
		if self._vertifyFail then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._vertifyFail
			})

			return
		end

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcSubRoutineScore()
		self._state:BattleEnd()
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, nil, clearFunc, nil)
end

-- 倒计时归零 → 敌人逃脱，按时间到结算
function BattleSubRoutineCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self._dataProxy:CalcSubRountineTimeUp()
		self._state:BattleTimeUp()
	end
end

-- 单位ShutDown：从Dispatcher获取UID并调用ShutdownPlayerUnit
function BattleSubRoutineCommand.onShutDownPlayer(self, event)
	local uid = event.Dispatcher:GetUniqueID()

	self._dataProxy:ShutdownPlayerUnit(uid)
end

-- 玩家沉没处理：如果有后备潜艇（SubBench），则手动切换；否则战斗结束
-- 这是SubRoutine与SubmarineRun最大的不同——允许替补潜艇接力
function BattleSubRoutineCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	local unit = event.Data.unit

	-- 检查是否有后备潜艇可切换
	if #self._userFleet:GetSubBench() > 0 then
		self._userFleet:ShiftManualSub() -- 手动切换替补潜艇
	else
		-- 无后备 → 战斗失败
		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcSubRountineElimate()
		self._state:BattleEnd()
	end
end
