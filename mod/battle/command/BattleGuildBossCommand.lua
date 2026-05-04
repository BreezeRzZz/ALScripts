ys = ys or {}

--- @class BattleGuildBossCommand : BattleSingleDungeonCommand
--- 公会 Boss 战斗指令。继承自 BattleSingleDungeonCommand，
--- 在通用 SingleDungeon 基础上增加了特定敌人统计和公会 Boss 伤害数据的计算。
--- 与普通关卡的差异：战斗结束时必须调用 calcDamageData 将伤害计入公会 Boss 总血量。
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleGuildBossCommand = class("BattleGuildBossCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleGuildBossCommand = BattleGuildBossCommand
BattleGuildBossCommand.__name = "BattleGuildBossCommand"

function BattleGuildBossCommand.Ctor(self)
	BattleGuildBossCommand.super.Ctor(self)
end

--- 初始化波次模块。重写父类方法，在战斗结束时额外调用 calcDamageData。
--- 内部闭包定义：
---   spawnFunc: 生成敌方怪物
---   airFighterFunc: 生成敌方飞机
---   clearFunc: 波次结束时的清理和结算（含验证 + 伤害计算）
---   spawnAreaFunc: 生成区域效果
function BattleGuildBossCommand.initWaveModule(self)
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

--- 战斗数据初始化完成回调。获取特定公会 Boss 敌人列表。
function BattleGuildBossCommand.onInitBattle(self)
	BattleGuildBossCommand.super.onInitBattle(self)

	local initData = self._dataProxy:GetInitData()

	self._specificEnemyList = ys.Battle.BattleDataFunction.GetSpecificGuildBossEnemyList(initData.ActID, initData.StageTmpId)
end

--- 单位添加回调。重写父类方法，若该单位在特定敌人列表中则初始化其统计信息。
function BattleGuildBossCommand.onAddUnit(self, event)
	BattleGuildBossCommand.super.onAddUnit(self, event)

	local unit = event.Data.unit

	if table.contains(self._specificEnemyList, unit:GetTemplateID()) then
		self._dataProxy:InitSpecificEnemyStatistics(unit)
	end
end

--- 玩家单位沉没问题。旗舰或前卫全灭时触发 calcDamageData 再进行战斗结束。
function BattleGuildBossCommand.onPlayerShutDown(self, event)
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
function BattleGuildBossCommand.onUpdateCountDown(self, event)
	if self._dataProxy:GetCountDown() <= 0 then
		self._dataProxy:EnemyEscape()
		self:CalcStatistic()
		self:calcDamageData()
		self._state:BattleTimeUp()
	end
end

--- 计算公会 Boss 伤害数据。调用 CalcGuildBossEnemyInfo 将战斗中的伤害
--- 汇总到公会 Boss 总伤害。
function BattleGuildBossCommand.calcDamageData(self)
	local initData = self._dataProxy:GetInitData()

	self._dataProxy:CalcGuildBossEnemyInfo(initData.ActID)
end
