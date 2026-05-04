ys = ys or {}

-- 躲避战（Dodgem）战斗Command，继承自BattleSingleDungeonCommand
-- 核心特性：特殊碰撞伤害公式（LockS2M / UnilateralCrush）、躲避计数初始化、运输船碰撞计分
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleDodgemCommand = class("BattleDodgemCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleDodgemCommand = BattleDodgemCommand
BattleDodgemCommand.__name = "BattleDodgemCommand"

function BattleDodgemCommand.Ctor(self)
	BattleDodgemCommand.super.Ctor(self)
end

-- 初始化：额外调用DodgemCountInit进行躲避计数初始化
function BattleDodgemCommand.Initialize(self)
	BattleDodgemCommand.super.Initialize(self)
	self._dataProxy:DodgemCountInit()
end

-- 入场序幕：设置特殊的碰撞伤害公式，显示躲避计分条
-- 使用LockS2M（锁定伤害公式）和UnilateralCrush（单向碾压）替代默认伤害计算
function BattleDodgemCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function afterSurfaceShift()
		self._uiMediator:OpeningEffect(function()
			self._dataProxy:SetupDamageKamikazeShip(ys.Battle.BattleFormulas.CalcDamageLockS2M) -- 神风船锁定伤害
			self._dataProxy:SetupDamageCrush(ys.Battle.BattleFormulas.UnilateralCrush) -- 碰撞碾压伤害
			self._uiMediator:ShowTimer()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()
		end)
		self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE):FleetWarcry()
	end

	self._uiMediator:SeaSurfaceShift(45, 0, nil, afterSurfaceShift)
	self._uiMediator:ShowDodgemScoreBar()
end

-- 波次模块：无空袭和AOE区域，仅刷怪和Dodgem专属结算
function BattleDodgemCommand.initWaveModule(self)
	-- 刷怪回调
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE)
	end

	-- 战斗结束回调：计算躲避战分数
	local function clearFunc()
		if self._vertifyFail then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._vertifyFail
			})

			return
		end

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcDodgemScore()
		self._state:BattleEnd()
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, nil, clearFunc, nil)
end

-- 单位即将死亡：累计躲避计数，运输船被碾压时发放积分
function BattleDodgemCommand.onWillDie(self, event)
	local unit = event.Dispatcher

	self._dataProxy:CalcDodgemCount(unit)

	local deathReason = unit:GetDeathReason()

	-- 运输船被碾压（CRUSH） → 获取当前积分点并分发给该单位
	if unit:GetTemplate().type == ShipType.JinBi and deathReason == ys.Battle.BattleConst.UnitDeathReason.CRUSH then
		local scorePoint = self._dataProxy:GetScorePoint()

		unit:DispatchScorePoint(scorePoint)
	end
end
