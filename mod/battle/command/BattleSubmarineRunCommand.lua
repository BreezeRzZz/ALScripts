ys = ys or {}

-- 潜艇猎杀（SubmarineRun）战斗Command，继承自BattleSingleDungeonCommand
-- 核心特性：潜艇自由下潜/浮上状态切换、敌方反潜仇恨链（HateChain）、运输船击杀奖励、玩家死亡扣分
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleConst = ys.Battle.BattleConst
local BattleSubmarineRunCommand = class("BattleSubmarineRunCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleSubmarineRunCommand = BattleSubmarineRunCommand
BattleSubmarineRunCommand.__name = "BattleSubmarineRunCommand"

function BattleSubmarineRunCommand.Ctor(self)
	BattleSubmarineRunCommand.super.Ctor(self)
end

-- 初始化：额外调用SubmarineRunInit进行潜艇模式特化初始化
function BattleSubmarineRunCommand.Initialize(self)
	BattleSubmarineRunCommand.super.Initialize(self)
	self._dataProxy:SubmarineRunInit()
end

-- 入场序幕：设置潜艇自由下潜状态、移除buff 8520、初始化氧气条、开始自动统计
function BattleSubmarineRunCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function afterSurfaceShift()
		self._uiMediator:OpeningEffect(function()
			self._uiMediator:ShowTimer()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()
		end, SYSTEM_SUBMARINE_RUN)

		-- 获取己方舰队，设置为自由下潜模式
		local fleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)

		fleet:FleetWarcry()
		fleet:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE) -- 自由下潜
		fleet:GetSubBoostVO():ResetCurrent() -- 重置氧气冲刺条
		self._dataProxy:InitAllFleetUnitsWeaponCD()
		self._dataProxy:TirggerBattleStartBuffs()
	end

	self._dataProxy:AutoStatistics(0)

	-- 移除所有单位的buff 8520（该buff可能用于非潜艇战斗模式）
	local unitList = self._userFleet:GetUnitList()

	for _, unit in ipairs(unitList) do
		unit:RemoveBuff(8520)
	end

	self._uiMediator:SeaSurfaceShift(45, 0, nil, afterSurfaceShift)
end

-- 战斗初始化后，额外注册潜艇上浮/下潜切换事件
function BattleSubmarineRunCommand.onInitBattle(self)
	BattleSubmarineRunCommand.super.onInitBattle(self)
	self._userFleet:RegisterEventListener(self, BattleEvent.MANUAL_SUBMARINE_SHIFT, self.onSubmarineShift)
end

-- 波次模块：无空袭和AOE区域，仅刷怪和结算
function BattleSubmarineRunCommand.initWaveModule(self)
	-- 刷怪回调
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE)
	end

	-- 战斗结束回调：计算潜艇猎杀分数
	local function clearFunc()
		if self._vertifyFail then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._vertifyFail
			})

			return
		end

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcSubRunScore()
		self._state:BattleEnd()
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, nil, clearFunc, nil)
end

-- 倒计时归零 → 敌人逃脱，按时间到结算
function BattleSubmarineRunCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self._dataProxy:CalcSubRunTimeUp()
		self._state:BattleTimeUp()
	end
end

-- 移除事件注册：额外解绑MANUAL_SUBMARINE_SHIFT
function BattleSubmarineRunCommand.RemoveEvent(self)
	self._userFleet:UnregisterEventListener(self, BattleEvent.MANUAL_SUBMARINE_SHIFT)
	BattleSubmarineRunCommand.super.RemoveEvent(self)
end

-- 解绑单位事件：额外移除ANTI_SUB_VIGILANCE_HATE_CHAIN
function BattleSubmarineRunCommand.UnregisterUnitEvent(self, unit)
	BattleSubmarineRunCommand.super.UnregisterUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.ANTI_SUB_VIGILANCE_HATE_CHAIN)
end

-- 单位添加：非玩家单位额外注册反潜仇恨链事件
function BattleSubmarineRunCommand.onAddUnit(self, event)
	BattleSubmarineRunCommand.super.onAddUnit(self, event)

	local unitType = event.Data.type
	local unit = event.Data.unit

	if unitType ~= ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.ANTI_SUB_VIGILANCE_HATE_CHAIN, self.onHateChain)
	end
end

-- 反潜仇恨链触发：对所有单位触发ON_ANTI_SUB_HATE_CHAIN buff效果
-- 这是反潜作战的核心机制，当敌方反潜单位发现潜艇时触发
function BattleSubmarineRunCommand.onHateChain(self, event)
	for _, unit in pairs(self._unitDataList) do
		unit:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ANTI_SUB_HATE_CHAIN)
	end
end

-- 单位即将死亡：处理死亡扣分、友军死亡buff触发、运输船击杀、Boss清除
function BattleSubmarineRunCommand.onWillDie(self, event)
	local unit = event.Dispatcher
	local deathReason = unit:GetDeathReason()

	-- 己方单位死亡 → 扣分
	if unit:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE then
		self._dataProxy:DelScoreWhenPlayerDead(unit)
	end

	-- 被击杀或破坏 → 触发所有单位的"队友沉没"buff
	if deathReason == ys.Battle.BattleConst.UnitDeathReason.KILLED or deathReason == ys.Battle.BattleConst.UnitDeathReason.DESTRUCT then
		for _, teammateUnit in pairs(self._unitDataList) do
			teammateUnit:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_TEAMMATE_SHIP_DYING, {
				unit = teammateUnit
			})
		end
	end

	-- 运输船（ShipType.JinBi）被击杀 → 计算奖励
	if unit:GetTemplate().type == ShipType.JinBi and deathReason == ys.Battle.BattleConst.UnitDeathReason.KILLED then
		self._dataProxy:CalcKillingSupplyShip()
	end

	-- Boss死亡检查：如果这是最后一个Boss，清场
	local hasBoss = self._dataProxy:IsThereBoss()

	if unit:IsBoss() and not hasBoss then
		if deathReason == ys.Battle.BattleConst.UnitDeathReason.DESTRUCT then
			self._dataProxy:AddScoreWhenBossDestruct()
		end

		self._dataProxy:KillAllEnemy()
	end
end

-- 潜艇上浮/下潜切换时，触发对应的buff效果
-- STATE_FREE_DIVE → ON_SUBMARINE_FREE_DIVE（自由下潜buff）
-- STATE_FREE_FLOAT → ON_SUBMARINE_FREE_FLOAT（自由浮上buff）
function BattleSubmarineRunCommand.onSubmarineShift(self, event)
	local state = event.Data.state
	local buffEffectType

	if state == ys.Battle.OxyState.STATE_FREE_DIVE then
		buffEffectType = ys.Battle.BattleConst.BuffEffectType.ON_SUBMARINE_FREE_DIVE
	elseif state == ys.Battle.OxyState.STATE_FREE_FLOAT then
		buffEffectType = ys.Battle.BattleConst.BuffEffectType.ON_SUBMARINE_FREE_FLOAT
	end

	for _, unit in pairs(self._unitDataList) do
		unit:TriggerBuff(buffEffectType)
	end
end

-- 玩家沉没 → 直接结束战斗（潜艇猎杀无复活）
function BattleSubmarineRunCommand.onShutDownPlayer(self)
	self._dataProxy:TriggerFinishBattle()
	self._dataProxy:CalcSubRunDead()
	self._state:BattleEnd()
end
