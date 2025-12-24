ys = ys or {}

local ys = ys

ys.Battle.BattleSpawnWave = class("BattleSpawnWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleSpawnWave.__name = "BattleSpawnWave"

local BattleSpawnWave = ys.Battle.BattleSpawnWave

BattleSpawnWave.ASYNC_TIME_GAP = 0.03

function BattleSpawnWave.Ctor(self)
	BattleSpawnWave.super.Ctor(self)

	self._spawnUnitList = {}
	self._monsterList = {}
	self._reinforceKillCount = 0
	self._reinforceTotalKillCount = 0
	self._airStrikeTimerList = {}
	self._spawnTimerList = {}
	self._reinforceSpawnTimerList = {}
end

function BattleSpawnWave.SetWaveData(self, waveData)
	BattleSpawnWave.super.SetWaveData(self, waveData)
	-- spawnData对应单个wave中的spawn字段
	self._spawnData = waveData.spawn or {}
	self._airStrike = waveData.airFighter or {}
	self._reinforce = waveData.reinforcement or {}
	self._reinforceCount = #self._reinforce
	self._spawnCount = #self._spawnData
	self._reinforceDuration = self._reinforce.reinforceDuration or 0
	self._reinforeceExpire = false
	self._round = self._param.round
end

function BattleSpawnWave.IsBossWave(self)
	local isBossWave = false
	local spawnData = self._spawnData

	for _, spawnItem in ipairs(spawnData) do
		if spawnItem.bossData then
			isBossWave = true
		end
	end

	return isBossWave
end

-- 核心逻辑
-- 被BattleWaveInfo.DoBranch调用，这又被BattleWaveUpdater.Start调用
function BattleSpawnWave.DoWave(self)
	BattleSpawnWave.super.DoWave(self)

	-- 不知道拿来干啥的
	if self._round then
		local isPass = false
		local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()

		if battleDataProxy:GetInitData().ChallengeInfo then
			local roundIndex = battleDataProxy:GetInitData().ChallengeInfo:getRound()

			if self._round.less and roundIndex < self._round.less then
				isPass = true
			end

			if self._round.more and roundIndex > self._round.more then
				isPass = true
			end

			if self._round.equal and table.contains(self._round.equal, roundIndex) then
				isPass = true
			end
		end

		if not isPass then
			self:doPass()

			return
		end
	end

	for index, airStrike in ipairs(self._airStrike) do
		local totalDelay = airStrike.delay + index * BattleSpawnWave.ASYNC_TIME_GAP

		if totalDelay <= 0 then
			self:doAirStrike(airStrike)
		else
			self:airStrikeTimer(airStrike, totalDelay)
		end
	end

	local totalBossCount = 0

	for _, spawnItem in ipairs(self._spawnData) do
		if spawnItem.bossData then
			totalBossCount = totalBossCount + 1
		end
	end

	local bossCount = 0
	local deltaDelay = 0

	for _, spawnItem in ipairs(self._spawnData) do
		if (spawnItem.chance or 1) >= math.random() then
			if spawnItem.bossData and totalBossCount > 1 then
				bossCount = bossCount + 1
				spawnItem.bossData.bossCount = bossCount
			end

			local totalDelay = spawnItem.delay + deltaDelay

			if totalDelay <= 0 then
				self:doSpawn(spawnItem)
			else
				self:spawnTimer(spawnItem, totalDelay, self._spawnTimerList)
			end
		else
			self._spawnCount = self._spawnCount - 1
		end
		-- 同一波次内的不同spawn之间需要错开时间点，差距为0.03s
		deltaDelay = deltaDelay + BattleSpawnWave.ASYNC_TIME_GAP
	end

	if self._reinforce then
		self:doReinforce(deltaDelay)
	end

	if self._spawnCount == 0 and self._reinforceDuration == 0 then
		self:doPass()
	end

	if self._reinforceDuration ~= 0 then
		self:reinforceDurationTimer(self._reinforceDuration)
	end

	ys.Battle.BattleState.GenerateVertifyData(1)

	local success, reason = ys.Battle.BattleState.Vertify()

	if not success then
		local failReason = 100 + reason

		ys.Battle.BattleState.GetInstance():GetCommandByName(ys.Battle.BattleSingleDungeonCommand.__name):SetVertifyFail(failReason)
	end
end

function BattleSpawnWave.AddMonster(self, monster)
	--- monster: BattleEnemyUnit
	if monster:GetWaveIndex() ~= self._index then
		return
	end
	--- <UID, BattleEnemyUnit>
	self._monsterList[monster:GetUniqueID()] = monster
end

function BattleSpawnWave.RemoveMonster(self, monsterUID)
	-- 这会触发reinforce相关逻辑
	self:onWaveUnitDie(monsterUID)
end

-- 核心逻辑
-- spawnItem对应的单个spawn字段内容
function BattleSpawnWave.doSpawn(self, spawnItem)
	local enemyType = ys.Battle.BattleConst.UnitType.ENEMY_UNIT

	if spawnItem.bossData then
		enemyType = ys.Battle.BattleConst.UnitType.BOSS_UNIT
	end
	-- _spawnFunc是在BattleWaveUpdater中传入的回调函数
	-- 实际上一般对应到BattleDataProxy.SpawnMonster
	self._spawnFunc(spawnItem, self._index, enemyType)
end

function BattleSpawnWave.spawnTimer(self, spawnItem, delay, spawnTimerList)
	local spawnTimer

	local function onTimerEnds()
		spawnTimerList[spawnTimer] = nil

		self:doSpawn(spawnItem)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(spawnTimer)
	end

	spawnTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 1, delay, onTimerEnds, true)
	spawnTimerList[spawnTimer] = true
end

function BattleSpawnWave.doAirStrike(self, airStrike)
	self._airFunc(airStrike)
end

function BattleSpawnWave.airStrikeTimer(self, airStrike, delay)
	local airStrikeTimer

	local function onTimerEnds()
		self._airStrikeTimerList[airStrikeTimer] = nil

		self:doAirStrike(airStrike)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(airStrikeTimer)
	end

	airStrikeTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 1, delay, onTimerEnds, true)
	self._airStrikeTimerList[airStrikeTimer] = true
end

function BattleSpawnWave.doReinforce(self, delay)
	self._reinforceKillCount = 0

	if self._reinforeceExpire then
		return
	end

	delay = delay or 0

	for _, reinforceItem in ipairs(self._reinforce) do
		reinforceItem.reinforce = true

		local totalDelay = reinforceItem.delay + delay

		if totalDelay <= 0 then
			self:doSpawn(reinforceItem)
		else
			self:spawnTimer(reinforceItem, totalDelay, self._reinforceSpawnTimerList)
		end

		delay = delay + BattleSpawnWave.ASYNC_TIME_GAP
	end
end

function BattleSpawnWave.reinforceTimer(self, time)
	self:clearReinforceTimer()

	local function var_14_0()
		self:doReinforce()
		self:clearReinforceTimer()
	end

	self._reinforceTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 1, time, var_14_0, true)
end

function BattleSpawnWave.clearReinforceTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._reinforceTimer)

	self._reinforceTimer = nil
end

function BattleSpawnWave.reinforceDurationTimer(self, time)
	local function onTimerEnds()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._reinforceDurationTimer)

		self._reinforeceExpire = true
		self._reinforceDuration = nil

		self:clearReinforceTimer()
		self.clearTimerList(self._reinforceSpawnTimerList)

		if self._spawnCount == 0 then
			self:doPass()
		end
	end

	self._reinforceDurationTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 1, time, onTimerEnds, true)
end

function BattleSpawnWave.clearReinforceDurationTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._reinforceDurationTimer)

	self._reinforceDurationTimer = nil
end

function BattleSpawnWave.onWaveUnitDie(self, monsterUID)
	local monster = self._monsterList[monsterUID]

	if monster == nil then
		return
	end

	local triggerReinforce

	if monster:IsReinforcement() then
		self._reinforceKillCount = self._reinforceKillCount + 1
		self._reinforceTotalKillCount = self._reinforceTotalKillCount + 1

		if self._reinforceCount ~= 0 and self._reinforceCount == self._reinforceKillCount then
			triggerReinforce = true
		end
	end

	local function delayedReinforcement(reinforceCastTime)
		if triggerReinforce and reinforceCastTime then
			if reinforceCastTime == 0 then
				self:doReinforce()
			else
				self:reinforceTimer(reinforceCastTime)
			end

			triggerReinforce = false
		end
	end

	local totalKillCount = 0
	local aliveCount = 0

	for _, _monster in pairs(self._monsterList) do
		if _monster:IsAlive() == false then
			if not _monster:IsReinforcement() then
				-- 不计入reinforce的死亡数量
				totalKillCount = totalKillCount + 1
			end
		else
			aliveCount = aliveCount + 1

			delayedReinforcement(_monster:GetReinforceCastTime())
		end
	end

	if self._reinforceDuration ~= 0 and not self._reinforeceExpire then
		delayedReinforcement(0)
	end
	-- 有点复杂，不过只需要知道，场上怪物全部死亡，且spawn和reinforce都刷完了，才会触发波次完成
	if aliveCount == 0 and totalKillCount >= self._spawnCount and self._reinforceTotalKillCount >= self._reinforceCount and (self._reinforceDuration == 0 or self._reinforeceExpire) then
		self:doPass()
	end
end

function BattleSpawnWave.doPass(self)
	self.clearTimerList(self._spawnTimerList)
	self.clearTimerList(self._reinforceSpawnTimerList)
	self:clearReinforceTimer()
	self:clearReinforceDurationTimer()
	ys.Battle.BattleDataProxy.GetInstance():KillWaveSummonMonster(self._index)
	BattleSpawnWave.super.doPass(self)
end

function BattleSpawnWave.clearTimerList(timerList)
	for timer, _ in pairs(timerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)
	end
end

function BattleSpawnWave.Dispose(self)
	self.clearTimerList(self._airStrikeTimerList)

	self._airStrikeTimerList = nil

	self.clearTimerList(self._spawnTimerList)

	self._spawnTimerList = nil

	self.clearTimerList(self._reinforceSpawnTimerList)

	self._reinforceSpawnTimerList = nil

	self:clearReinforceTimer()
	self:clearReinforceDurationTimer()
	BattleSpawnWave.super.Dispose(self)
end
