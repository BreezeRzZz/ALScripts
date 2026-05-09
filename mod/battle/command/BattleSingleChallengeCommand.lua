ys = ys or {}

-- 极限挑战（Challenge Mode）战斗Command，继承自BattleSingleDungeonCommand
-- 核心特性：随挑战轮次递增，动态增强敌方属性（血量/攻击/闪避/幸运）和关卡等级
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleSingleChallengeCommand = class("BattleSingleChallengeCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleSingleChallengeCommand = BattleSingleChallengeCommand
BattleSingleChallengeCommand.__name = "BattleSingleChallengeCommand"

function BattleSingleChallengeCommand.Ctor(self)
	BattleSingleChallengeCommand.super.Ctor(self)

	-- 读取挑战增强系数配置
	self._challengeConst = ys.Battle.BattleConfig.CHALLENGE_ENHANCE
end

-- 战斗初始化时，根据当前挑战轮次计算敌方增强属性
function BattleSingleChallengeCommand.onInitBattle(self)
	BattleSingleChallengeCommand.super.onInitBattle(self)

	local currentRound = self._dataProxy:GetInitData().ChallengeInfo:getRound()

	-- 计算增强系数P = max(当前轮次 - K, 0)
	self._enhancemntP = math.max(currentRound - self._challengeConst.K, 0)
	self._enhancemntPPercent = self._enhancemntP * 0.01

	-- 关卡等级随轮次提升
	local levelDelta = self._challengeConst.A * self._enhancemntP
	local dungeonLevel = self._dataProxy:GetDungeonLevel()

	self._dataProxy:SetDungeonLevel(dungeonLevel + levelDelta)

	-- 计算各项属性的增强值
	-- DUR = 耐久(HP), ATK = 炮击+雷击+航空, EVD = 闪避, LUK = 幸运
	self._enahanceDURAttr = self._challengeConst.X1 * self._enhancemntPPercent
	self._enahanceATKAttr = self._challengeConst.X2 * self._enhancemntPPercent
	self._enahanceEVDAttr = self._challengeConst.Y1 * self._enhancemntP
	self._enahanceLUKAttr = self._challengeConst.Y2 * self._enhancemntP
end

-- 初始化波次模块，spawnFunc额外注入monsterEnhance回调
function BattleSingleChallengeCommand.initWaveModule(self)
	-- 刷怪回调：生成怪物后立即对其进行属性增强
	local function spawnFunc(spawnItem, waveIndex, enemyType)
		local spawnedMonster = self._dataProxy:SpawnMonster(spawnItem, waveIndex, enemyType, ys.Battle.BattleConfig.FOE_CODE, function(unit)
			self:monsterEnhance(unit)
		end)
	end

	-- 敌方飞机生成回调
	local function airFighterFunc(tmpData)
		self._dataProxy:SpawnAirFighter(tmpData)
	end

	-- 战斗结束回调：验证数据完整性后结算
	local function clearFunc()
		if self._vertifyFail then
			pg.m02:sendNotification(GAME.CHEATER_MARK, {
				reason = self._vertifyFail
			})

			return
		end

		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcChallengeScore(true) -- true = 胜利通关
		self._state:BattleEnd()
	end

	-- AOE区域生成回调
	local function spawnAreaFunc(x, y, z, width, height)
		self._dataProxy:SpawnCubeArea(ys.Battle.BattleConst.AOEField.SURFACE, -1, x, y, z, width, height)
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
end

-- 入场序幕：海面切换特效后进入战斗状态
function BattleSingleChallengeCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function afterSurfaceShift()
		self._uiMediator:OpeningEffect(function()
			local playerProxy = getProxy(PlayerProxy)

			self._uiMediator:ShowAutoBtn()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._uiMediator:ShowTimer()
			self._state:GetCommandByName(ys.Battle.BattleControllerWeaponCommand.__name):TryAutoSub()
			self._waveUpdater:Start()
		end)
		self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE):FleetWarcry()
		self._dataProxy:InitAllFleetUnitsWeaponCD()
		self._dataProxy:TirggerBattleStartBuffs()

		-- 记录挑战开始时间（用于计时结算）
		self._challengeStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end

	self._uiMediator:SeaSurfaceShift(45, 0, nil, afterSurfaceShift)
end

-- 玩家旗舰沉没或前排全灭 → 战斗失败结算
function BattleSingleChallengeCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	if event.Data.unit == self._userFleet:GetFlagShip() then
		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcChallengeScore(false) -- false = 失败
		self._state:BattleEnd()

		return
	end

	if #self._userFleet:GetScoutList() == 0 then
		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcChallengeScore(false)
		self._state:BattleEnd()
	end
end

-- 倒计时归零 → 战斗结束（时间到）
function BattleSingleChallengeCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:TriggerFinishBattle()
		self._dataProxy:CalcChallengeScore(false)
		self._state:BattleEnd()
	end
end

-- 对生成的怪物进行属性增强（FlashByBuff 直接修改基础属性）
-- 增强属性：最大HP、炮击、雷击、航空、闪避率、幸运
function BattleSingleChallengeCommand.monsterEnhance(self, unit)
	ys.Battle.BattleAttr.FlashByBuff(unit, "maxHP", self._enahanceDURAttr)
	ys.Battle.BattleAttr.FlashByBuff(unit, "cannonPower", self._enahanceATKAttr)
	ys.Battle.BattleAttr.FlashByBuff(unit, "torpedoPower", self._enahanceATKAttr)
	ys.Battle.BattleAttr.FlashByBuff(unit, "airPower", self._enahanceATKAttr)
	ys.Battle.BattleAttr.FlashByBuff(unit, "dodgeRate", self._enahanceEVDAttr)
	ys.Battle.BattleAttr.FlashByBuff(unit, "luck", self._enahanceLUKAttr)
end
