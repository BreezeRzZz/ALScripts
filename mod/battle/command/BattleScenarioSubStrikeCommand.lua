ys = ys or {}
-- 关卡潜艇打击Command，继承自BattleSingleDungeonCommand，重写DoPrologue和部分事件处理
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
--- @class BattleScenarioSubStrikeCommand : 关卡潜艇打击Command
local BattleScenarioSubStrikeCommand = class("BattleScenarioSubStrikeCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleScenarioSubStrikeCommand = BattleScenarioSubStrikeCommand
BattleScenarioSubStrikeCommand.__name = "BattleScenarioSubStrikeCommand"

function BattleScenarioSubStrikeCommand.Ctor(self)
	BattleScenarioSubStrikeCommand.super.Ctor(self)
end

--- 重写开场逻辑：禁用摇杆和武器按钮，启用相机手势
function BattleScenarioSubStrikeCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	--- 海面切换完成后的回调
	local function afterShift()
		self._uiMediator:OpeningEffect(function()
			self._uiMediator:ShowTimer()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()

			if self._dataProxy:GetInitData().hideAllButtons then
				self._dataProxy:DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.HIDE_INTERACTABLE_BUTTONS, {
					isActive = false
				}))
			end

			self._uiMediator:InitCameraGestureSlider()
			self._uiMediator:EnableJoystick(false)
			self._uiMediator:EnableWeaponButton(false)
		end)
		self._dataProxy:SubmarineStrike(ys.Battle.BattleConfig.FRIENDLY_CODE)
	end

	self._uiMediator:SeaSurfaceShift(45, 0, nil, afterShift)
end

function BattleScenarioSubStrikeCommand.initWaveModule(self)
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE)
	end

	local function airFighterFunc(tmpData)
		self._dataProxy:SpawnAirFighter(tmpData)
	end

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

	--- 区域生成回调
	local function spawnAreaFunc(areaID, arg2, arg3, arg4, arg5)
		self._dataProxy:SpawnCubeArea(ys.Battle.BattleConst.AOEField.SURFACE, -1, areaID, arg2, arg3, arg4, arg5)
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
end

--- 重写添加单位逻辑，Boss单位加入潜艇打击Boss列表
function BattleScenarioSubStrikeCommand.onAddUnit(self, event)
	BattleScenarioSubStrikeCommand.super.onAddUnit(self, event)

	if event.Data.type == ys.Battle.BattleConst.UnitType.BOSS_UNIT then
		local unit = event.Data.unit

		self._dataProxy:AddScenarioSubStrikeBoss(unit)
	end
end

--- 潜艇打击模式下，潜艇全灭则战斗结束
function BattleScenarioSubStrikeCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	if #self._userFleet:GetSubList() == 0 then
		self._dataProxy:TriggerFinishBattle()
		self:CalcStatistic()
		self._state:BattleEnd()
	end
end

function BattleScenarioSubStrikeCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self:CalcStatistic()
		self._state:BattleTimeUp()
	end
end

--- 重写单位死亡逻辑，精简了评分计算
function BattleScenarioSubStrikeCommand.onWillDie(self, event)
	local unit = event.Dispatcher
	local deathReason = ys.Battle.BattleConst.UnitDeathReason

	if unit:GetDeathReason() == deathReason.LEAVE then
		if unit:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE then
			self._dataProxy:CalcBPWhenPlayerLeave(unit)
		end
	else
		self._dataProxy:CalcBattleScoreWhenDead(unit)
	end

	local hasBoss = self._dataProxy:IsThereBoss()

	if unit:IsBoss() and not hasBoss then
		self._dataProxy:KillAllEnemy()
	end
end

--- 强制结束战斗
function BattleScenarioSubStrikeCommand.CalcBattleEnd(self)
	self._dataProxy:TriggerFinishBattle()
	self:CalcStatistic()
	self._state:BattleEnd()
end

--- 重写统计计算，使用ScenarioSubStrike专用方法
function BattleScenarioSubStrikeCommand.CalcStatistic(self)
	self._dataProxy:CalcScenarioSubStrikeScoreAtEnd()
end
