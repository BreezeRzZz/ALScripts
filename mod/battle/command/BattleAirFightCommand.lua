ys = ys or {}

--- @class BattleAirFightCommand : BattleSingleDungeonCommand
--- 航空战斗（空战/空袭模式）指令。继承自 BattleSingleDungeonCommand。
--- 核心机制：
--- 1. 己方单位无敌 — 重载伤害计算，友方受到的伤害强制返回 1（miss+非暴击），
---    敌方正常计算伤害。这意味着空战是纯"打靶"模式。
--- 2. 击落计分 — 根据敌机的 ShipType 获得不同分数（鱼雷艇 200、金币船 300、自爆船 3000）。
--- 3. 受击扣分 — 己方被命中时扣分（每次受击扣 10 分 × dHP 绝对值）。
--- 4. 无飞机生成 — initWaveModule 中 airFighterFunc 和 spawnAreaFunc 均为 nil。
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleAirFightCommand = class("BattleAirFightCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleAirFightCommand = BattleAirFightCommand
BattleAirFightCommand.__name = "BattleAirFightCommand"

function BattleAirFightCommand.Ctor(self)
	BattleAirFightCommand.super.Ctor(self)
end

--- 重写 AddEvent，增加 COMMON_DATA_INIT_FINISH 事件监听用于空战初始化。
function BattleAirFightCommand.AddEvent(self, ...)
	BattleAirFightCommand.super.AddEvent(self, ...)
	self._dataProxy:RegisterEventListener(self, BattleEvent.COMMON_DATA_INIT_FINISH, self.onBattleDataInitFinished)
end

--- 重写 RemoveEvent，取消 COMMON_DATA_INIT_FINISH 事件。
function BattleAirFightCommand.RemoveEvent(self, ...)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.COMMON_DATA_INIT_FINISH)
	BattleAirFightCommand.super.RemoveEvent(self, ...)
end

--- 开场序幕。核心逻辑：
--- 1. 重载伤害计算函数，使己方单位无敌（友方受到伤害视为 1，miss + 非暴击）。
--- 2. 重载碰撞（Crush/Kamikaze）伤害计算，同样保护友方。
--- 3. 显示空战计分条。
function BattleAirFightCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function afterSeaSurfaceShift()
		self._uiMediator:OpeningEffect(function()
			local formulas = ys.Battle.BattleFormulas
			local normalDamageCalc = formulas.CreateContextCalculateDamage()

			-- 自定义伤害计算：友方无敌，敌方正常计算
			local function customCalcDamage(host, target, ...)
				local targetIFF = target:GetIFF()

				if targetIFF == ys.Battle.BattleConfig.FRIENDLY_CODE then
					-- 友方受击：伤害为 1，miss + 非暴击 + 无伤害减免
					return 1, {
						isMiss = false,
						isCri = false,
						isDamagePrevent = false
					}
				elseif targetIFF == ys.Battle.BattleConfig.FOE_CODE then
					return normalDamageCalc(host, target, ...)
				end
			end

			-- 自定义碰撞伤害计算：友方受到碰撞伤害恒为 1
			local function customCrashDamageCalc(host, target)
				local dmgRatio, dmg = formulas.CalculateCrashDamage(host, target)
				local dmgRatioResult = 1

				dmg = target:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE and 1 or dmg

				return dmgRatioResult, dmg
			end

			self._dataProxy:SetupCalculateDamage(customCalcDamage)
			self._dataProxy:SetupDamageKamikazeShip(ys.Battle.BattleFormulas.CalcDamageLockS2M)
			self._dataProxy:SetupDamageCrush(customCrashDamageCalc)
			self._uiMediator:ShowTimer()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()
		end, SYSTEM_AIRFIGHT)
		self._dataProxy:InitAllFleetUnitsWeaponCD()
	end

	self._uiMediator:SeaSurfaceShift(1, 15, nil, afterSeaSurfaceShift)
	self._dataProxy:AutoStatistics(0)

	local sceneMediator = self._state:GetSceneMediator()

	self._uiMediator:ShowAirFightScoreBar()
end

--- 初始化波次模块。空战模式不需要敌方飞机生成 (airFighterFunc=nil)
--- 和区域效果生成 (spawnAreaFunc=nil)。
function BattleAirFightCommand.initWaveModule(self)
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE)
	end

	local function clearFunc()
		if self._vertifyFail then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._vertifyFail
			})

			return
		end

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcAirFightScore()
		self._state:BattleEnd()
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, nil, clearFunc, nil)
end

--- 战斗数据通用初始化完成后的回调。执行空战初始化并隐藏前卫的 WaveFx。
function BattleAirFightCommand.onBattleDataInitFinished(self)
	self._dataProxy:AirFightInit()

	local scoutList = self._userFleet:GetScoutList()

	for _, unit in ipairs(scoutList) do
		unit:HideWaveFx()
	end
end

--- 重写 RegisterUnitEvent。为玩家单位增加 UPDATE_HP 事件监听。
function BattleAirFightCommand.RegisterUnitEvent(self, unit, ...)
	BattleAirFightCommand.super.RegisterUnitEvent(self, unit, ...)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onPlayerHPUpdate)
	end
end

--- 重写 UnregisterUnitEvent。取消玩家单位的 UPDATE_HP 事件。
function BattleAirFightCommand.UnregisterUnitEvent(self, unit, ...)
	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)
	end

	BattleAirFightCommand.super.UnregisterUnitEvent(self, unit, ...)
end

--- 击落敌机的分数表。按 ShipType 区分分值：
--- 鱼雷艇=200，金币船=300，自爆船=3000。
BattleAirFightCommand.ShipType2Point = {
	[ShipType.YuLeiTing] = 200,
	[ShipType.JinBi] = 300,
	[ShipType.ZiBao] = 3000
}
--- 每次被命中扣分值。
BattleAirFightCommand.BeenHitDecreasePoint = 10

--- 单位即将死亡回调。若死因为撞击(CRUSH)或被击杀(KILLED)，且该舰种
--- 在 ShipType2Point 表中有分数，则增加对应的空战得分。
function BattleAirFightCommand.onWillDie(self, event)
	local unit = event.Dispatcher
	local deathReason = unit:GetDeathReason()
	local shipType = unit:GetTemplate().type

	if deathReason == ys.Battle.BattleConst.UnitDeathReason.CRUSH or deathReason == ys.Battle.BattleConst.UnitDeathReason.KILLED then
		local point = BattleAirFightCommand.ShipType2Point[shipType]

		if point and point > 0 then
			self._dataProxy:AddAirFightScore(point)
		end
	end
end

--- 玩家 HP 更新回调。当 dHP <= 0（受到伤害）时，按 (扣分值 × |dHP|) 扣减空战分数。
function BattleAirFightCommand.onPlayerHPUpdate(self, event)
	if event.Data.dHP <= 0 then
		self._dataProxy:DecreaseAirFightScore(BattleAirFightCommand.BeenHitDecreasePoint * -event.Data.dHP)
	end
end
