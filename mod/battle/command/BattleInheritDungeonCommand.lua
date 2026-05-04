ys = ys or {}

--- @class BattleInheritDungeonCommand : BattleSingleDungeonCommand
--- 继承式 Dungeon 战斗指令。用于活动关卡中"继承"（Inherit）类型的战斗，
--- 即从特定活动继承敌人配置、拥有特定敌人统计和活动 Boss 伤害计算。
--- 与 GuildBossCommand 类似，但使用 GetSpecificEnemyList 和 CalcActBossDamageInfo。
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleInheritDungeonCommand = class("BattleInheritDungeonCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleInheritDungeonCommand = BattleInheritDungeonCommand
BattleInheritDungeonCommand.__name = "BattleInheritDungeonCommand"

function BattleInheritDungeonCommand.Ctor(self)
	BattleInheritDungeonCommand.super.Ctor(self)
end

--- 初始化波次模块。重写父类方法，在战斗结束时额外调用 calcDamageData。
function BattleInheritDungeonCommand.initWaveModule(self)
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

--- 战斗数据初始化完成回调。获取活动特定的敌人列表。
function BattleInheritDungeonCommand.onInitBattle(self)
	BattleInheritDungeonCommand.super.onInitBattle(self)

	local initData = self._dataProxy:GetInitData()

	self._specificEnemyList = ys.Battle.BattleDataFunction.GetSpecificEnemyList(initData.ActID, initData.StageTmpId)
end

--- 单位添加回调。若单位在特定敌人列表中，初始化其单独统计。
function BattleInheritDungeonCommand.onAddUnit(self, event)
	BattleInheritDungeonCommand.super.onAddUnit(self, event)

	local unit = event.Data.unit

	if table.contains(self._specificEnemyList, unit:GetTemplateID()) then
		self._dataProxy:InitSpecificEnemyStatistics(unit)
	end
end

--- 玩家单位沉没问题。旗舰或前卫全灭时触发 calcDamageData 再结束战斗。
function BattleInheritDungeonCommand.onPlayerShutDown(self, event)
	if self._state:GetState() ~= self._state.BATTLE_STATE_FIGHT then
		return
	end

	if event.Data.unit == self._userFleet:GetFlagShip() and self._dataProxy:GetInitData().battleType ~= SYSTEM_PROLOGUE and self._dataProxy:GetInitData().battleType ~= SYSTEM_PERFORM then
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleEnd()

		return
	end

	if #self._userFleet:GetScoutList() == 0 then
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleEnd()
	end
end

--- 倒计时归零时的超时结算。
function BattleInheritDungeonCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleTimeUp()
	end
end

--- 计算活动 Boss 伤害数据。将本次战斗伤害计入活动 Boss 总伤害池，
--- 供跨多场战斗的累计伤害排行使用。
function BattleInheritDungeonCommand.calcDamageData(self)
	local initData = self._dataProxy:GetInitData()

	self._dataProxy:CalcActBossDamageInfo(initData.ActID)
end
