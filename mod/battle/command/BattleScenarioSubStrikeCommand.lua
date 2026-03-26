ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleScenarioSubStrikeCommand = class("BattleScenarioSubStrikeCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleScenarioSubStrikeCommand = BattleScenarioSubStrikeCommand
BattleScenarioSubStrikeCommand.__name = "BattleScenarioSubStrikeCommand"

function BattleScenarioSubStrikeCommand.Ctor(arg_1_0)
	BattleScenarioSubStrikeCommand.super.Ctor(arg_1_0)
end

function BattleScenarioSubStrikeCommand.DoPrologue(arg_2_0)
	pg.UIMgr.GetInstance():Marching()

	local function var_2_0()
		arg_2_0._uiMediator:OpeningEffect(function()
			arg_2_0._uiMediator:ShowTimer()
			arg_2_0._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			arg_2_0._waveUpdater:Start()

			if arg_2_0._dataProxy:GetInitData().hideAllButtons then
				arg_2_0._dataProxy:DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.HIDE_INTERACTABLE_BUTTONS, {
					isActive = false
				}))
			end

			arg_2_0._uiMediator:InitCameraGestureSlider()
			arg_2_0._uiMediator:EnableJoystick(false)
			arg_2_0._uiMediator:EnableWeaponButton(false)
		end)
		arg_2_0._dataProxy:SubmarineStrike(ys.Battle.BattleConfig.FRIENDLY_CODE)
	end

	arg_2_0._uiMediator:SeaSurfaceShift(45, 0, nil, var_2_0)
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

	local function spawnAreaFunc(arg_9_0, arg_9_1, arg_9_2, arg_9_3, arg_9_4)
		self._dataProxy:SpawnCubeArea(ys.Battle.BattleConst.AOEField.SURFACE, -1, arg_9_0, arg_9_1, arg_9_2, arg_9_3, arg_9_4)
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
end

function BattleScenarioSubStrikeCommand.onAddUnit(arg_10_0, arg_10_1)
	BattleScenarioSubStrikeCommand.super.onAddUnit(arg_10_0, arg_10_1)

	if arg_10_1.Data.type == ys.Battle.BattleConst.UnitType.BOSS_UNIT then
		local var_10_0 = arg_10_1.Data.unit

		arg_10_0._dataProxy:AddScenarioSubStrikeBoss(var_10_0)
	end
end

function BattleScenarioSubStrikeCommand.onPlayerShutDown(arg_11_0, arg_11_1)
	if arg_11_0._state:GetState() ~= arg_11_0._state.BATTLE_STATE_FIGHT then
		return
	end

	if #arg_11_0._userFleet:GetSubList() == 0 then
		arg_11_0._dataProxy:TriggerFinishBattle()
		arg_11_0:CalcStatistic()
		arg_11_0._state:BattleEnd()
	end
end

function BattleScenarioSubStrikeCommand.onUpdateCountDown(arg_12_0, arg_12_1)
	if arg_12_0._dataProxy:GetCountDown() <= 0 then
		arg_12_0._dataProxy:EnemyEscape()
		arg_12_0:CalcStatistic()
		arg_12_0._state:BattleTimeUp()
	end
end

function BattleScenarioSubStrikeCommand.onWillDie(arg_13_0, arg_13_1)
	local var_13_0 = arg_13_1.Dispatcher
	local var_13_1 = ys.Battle.BattleConst.UnitDeathReason

	if var_13_0:GetDeathReason() == var_13_1.LEAVE then
		if var_13_0:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE then
			arg_13_0._dataProxy:CalcBPWhenPlayerLeave(var_13_0)
		end
	else
		arg_13_0._dataProxy:CalcBattleScoreWhenDead(var_13_0)
	end

	local var_13_2 = arg_13_0._dataProxy:IsThereBoss()

	if var_13_0:IsBoss() and not var_13_2 then
		arg_13_0._dataProxy:KillAllEnemy()
	end
end

function BattleScenarioSubStrikeCommand.CalcBattleEnd(arg_14_0)
	arg_14_0._dataProxy:TriggerFinishBattle()
	arg_14_0:CalcStatistic()
	arg_14_0._state:BattleEnd()
end

function BattleScenarioSubStrikeCommand.CalcStatistic(arg_15_0)
	arg_15_0._dataProxy:CalcScenarioSubStrikeScoreAtEnd()
end
