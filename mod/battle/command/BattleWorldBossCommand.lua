ys = ys or {}

--- @class BattleWorldBossCommand : BattleSingleDungeonCommand
--- 世界 Boss（共斗/World Joint）战斗指令。继承自 BattleSingleDungeonCommand，
--- 根据 ActID + bossConfigId + bossLevel 获取特定敌人列表，
--- 并计算世界 Boss 伤害数据。与 InheritDungeon 和 GuildBoss 的区别在于
--- Boss 有等级（bossLevel）参数，且使用 CalcWorldBossDamageInfo 进行结算。
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleWorldBossCommand = class("BattleWorldBossCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleWorldBossCommand = BattleWorldBossCommand
BattleWorldBossCommand.__name = "BattleWorldBossCommand"

function BattleWorldBossCommand.Ctor(self)
	BattleWorldBossCommand.super.Ctor(self)
end

--- 初始化波次模块。重写父类方法，在战斗结束时额外调用 calcDamageData。
function BattleWorldBossCommand.initWaveModule(self)
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
		self:calcDamageData()
		self._state:BattleEnd()
	end

	local function spawnAreaFunc(x, y, z, width, height)
		self._dataProxy:SpawnCubeArea(ys.Battle.BattleConst.AOEField.SURFACE, -1, x, y, z, width, height)
	end

	self._waveUpdater = ys.Battle.BattleWaveUpdater.New(spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
end

--- 战斗数据初始化完成回调。获取世界 Boss 特定敌人列表，
--- 使用 ActID、bossConfigId 和 bossLevel 三个维度进行查询。
function BattleWorldBossCommand.onInitBattle(self)
	BattleWorldBossCommand.super.onInitBattle(self)

	local initData = self._dataProxy:GetInitData()

	self._specificEnemyList = ys.Battle.BattleDataFunction.GetSpecificWorldJointEnemyList(initData.ActID, initData.bossConfigId, initData.bossLevel)
end

--- 单位添加回调。若单位在特定敌人列表中则初始化其统计信息。
function BattleWorldBossCommand.onAddUnit(self, event)
	BattleWorldBossCommand.super.onAddUnit(self, event)

	local unit = event.Data.unit

	if table.contains(self._specificEnemyList, unit:GetTemplateID()) then
		self._dataProxy:InitSpecificEnemyStatistics(unit)
	end
end

--- 玩家单位沉没问题。旗舰或前卫全灭时，调用 TriggerFinishBattle 再触发 calcDamageData 后结束战斗。
function BattleWorldBossCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	if event.Data.unit == self._userFleet:GetFlagShip() and self._dataProxy:GetInitData().battleType ~= SYSTEM_PROLOGUE and self._dataProxy:GetInitData().battleType ~= SYSTEM_PERFORM then
		self._dataProxy:TriggerFinishBattle()
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleEnd()

		return
	end

	if #self._userFleet:GetScoutList() == 0 then
		self._dataProxy:TriggerFinishBattle()
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleEnd()
	end
end

--- 倒计时归零时的超时结算。
function BattleWorldBossCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleTimeUp()
	end
end

--- 计算世界 Boss 伤害数据。将本次战斗伤害按 ActID + bossConfigId + bossLevel
--- 三个维度汇总到世界 Boss 总伤害池。
function BattleWorldBossCommand.calcDamageData(self)
	local initData = self._dataProxy:GetInitData()

	self._dataProxy:CalcWorldBossDamageInfo(initData.ActID, initData.bossConfigId, initData.bossLevel)
end
