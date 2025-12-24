ys = ys or {}

local ys = ys
local WaveTriggerType = ys.Battle.BattleConst.WaveTriggerType
local BattleWaveUpdater = class("BattleWaveUpdater")

ys.Battle.BattleWaveUpdater = BattleWaveUpdater
BattleWaveUpdater.__name = "BattleWaveUpdater"
BattleWaveUpdater.PREWAVES_CONDITION_AND = 0
BattleWaveUpdater.PREWAVES_CONDITION_OR = 1

-- BattleWaveUpdate一般在各个Command中被初始化
-- 以最常用的BattleSingleDungeonCommand为例，在BattleSingleDungeonCommand.Init中调用了initWaveModule，再创建了一个BattleWaveUpdater实例
function BattleWaveUpdater.Ctor(self, spawnFunc, airFighterFunc, clearFunc, spawnAreaFunc)
	ys.EventListener.AttachEventListener(self)

	self._spawnFunc = spawnFunc
	self._airFighterFunc = airFighterFunc
	self._clearFunc = clearFunc
	self._spawnAreaFunc = spawnAreaFunc

	self:Init()
end

function BattleWaveUpdater.Init(self)
	self._monsterList = {}
	self._spawnList = {}
	self._airFighter = {}
	self._waveInfos = {}
	self._timerList = {}
	self._waveUnitAliveList = {}
	self._keyList = {}
	self._waveInfoList = {}
end

-- note: 核心的波次数据设置函数
--在BattleSingleDungeonCommand.onInitBattle中被调用
-- waveTmpData来自于BattleDataProxy.GetStageInfo()
-- 这其中的_currentStageData又对应到具体dungeon的配置数据的某个stage字段
-- （但普遍是只有一个stage）
function BattleWaveUpdater.SetWavesData(self, waveTmpData)
	self._waveTmpData = waveTmpData
	-- 这里是stage中的waves字段，遍历每一个波次
	for _, wave in ipairs(waveTmpData.waves) do
		local triggerType = wave.triggerType
		--- @type BattleWaveInfo
		local waveInfo
		-- 根据不同的triggerType，创建不同类型的波次实例
		-- 均为BattleWaveInfo的子类

		-- NORMAL = 0，对应的是spawn波次，即实际的怪物生成波次
		-- 是最核心逻辑，为重点关注对象
		if triggerType == WaveTriggerType.NORMAL then
			waveInfo = ys.Battle.BattleSpawnWave.New()

			waveInfo:SetCallback(self._spawnFunc, self._airFighterFunc)
		-- TIMER = 1，一般就是给定一个timeout，在时间到达后触发
		-- 这种波次一般作为其他波次的前置波次使用，比如生成怪物前有0.5秒的延时波次
		elseif triggerType == WaveTriggerType.TIMER then
			waveInfo = ys.Battle.BattleDelayWave.New()
		elseif triggerType == WaveTriggerType.RANGE then
			waveInfo = ys.Battle.BattleRangeWave.New()

			waveInfo:SetCallback(self._spawnAreaFunc)
		elseif triggerType == WaveTriggerType.STORY then
			waveInfo = ys.Battle.BattleStoryWave.New()
		elseif triggerType == WaveTriggerType.AID then
			waveInfo = ys.Battle.BattleAidWave.New()
		elseif triggerType == WaveTriggerType.BGM then
			waveInfo = ys.Battle.BattleSwitchBGMWave.New()
		elseif triggerType == WaveTriggerType.GUIDE then
			waveInfo = ys.Battle.BattleGuideWave.New()
		elseif triggerType == WaveTriggerType.CAMERA then
			waveInfo = ys.Battle.BattleCameraWave.New()
		elseif triggerType == WaveTriggerType.CLEAR then
			waveInfo = ys.Battle.BattleClearWave.New()
		elseif triggerType == WaveTriggerType.JAMMING then
			waveInfo = ys.Battle.BattleJammingWave.New()
		elseif triggerType == WaveTriggerType.ENVIRONMENT then
			waveInfo = ys.Battle.BattleEnvironmentWave.New()
		elseif triggerType == WaveTriggerType.LABEL then
			waveInfo = ys.Battle.BattleLabelWave.New()
		elseif triggerType == WaveTriggerType.CARD_PUZZLE then
			waveInfo = ys.Battle.BattleCardPuzzleWave.New()
		end

		waveInfo:SetWaveData(wave)
		waveInfo:RegisterEventListener(self, ys.Battle.BattleEvent.WAVE_FINISH, self.onWaveFinish)

		self._waveInfoList[waveInfo:GetIndex()] = waveInfo

		if waveInfo:IsKeyWave() then
			self._keyList[#self._keyList + 1] = waveInfo
		end
	end

	for _, waveInfo in pairs(self._waveInfoList) do
		for _, preWaveID in ipairs(waveInfo:GetPreWaveIDs()) do
			local preWaveInfo = self._waveInfoList[preWaveID]

			if preWaveInfo then
				waveInfo:AppendPreWave(preWaveInfo)
				preWaveInfo:AppendPostWave(waveInfo)
			end
		end
		-- 这里是因为branchWaves的原始结构类似：conditionWaves = {[222] = false}，与preWaves不同
		for branchWaveID, _ in pairs(waveInfo:GetBranchWaveIDs()) do
			local branchWaveInfo = self._waveInfoList[branchWaveID]

			if branchWaveInfo then
				waveInfo:AppendBranchWave(branchWaveInfo)
			end
		end
	end
end

function BattleWaveUpdater.Start(self)
	self._active = true

	for _, waveInfo in pairs(self._waveInfoList) do
		if waveInfo:IsReady() then
			waveInfo:DoBranch()
		end
	end
end

function BattleWaveUpdater.AddMonster(self, monster)
	for _, waveInfo in pairs(self._waveInfoList) do
		-- 只有NORMAL类型对应的BattleSpawnWave才重写了AddMonster方法
		waveInfo:AddMonster(monster)
	end
end

function BattleWaveUpdater.RemoveMonster(self, monsterUID)
	for _, waveInfo in pairs(self._waveInfoList) do
		-- 只有NORMAL类型对应的BattleSpawnWave才重写了RemoveMonster方法
		waveInfo:RemoveMonster(monsterUID)
	end
end

function BattleWaveUpdater.onWaveFinish(self, event)
	if not self._active then
		return
	end

	if self:CheckAllKeyWave() then
		self._active = false

		self._clearFunc()
	end

	local postWaves = event.Dispatcher:GetPostWaves()

	for _, waveInfo in ipairs(postWaves) do
		if waveInfo:IsReady() and waveInfo:GetState() == waveInfo.STATE_DEACTIVE then
			waveInfo:DoBranch()
		end
	end
end

function BattleWaveUpdater.GetAllBossWave(self)
	local bossWaves = {}

	for _, waveInfo in pairs(self._waveInfoList) do
		if waveInfo:GetType() == WaveTriggerType.NORMAL and waveInfo:IsBossWave() then
			table.insert(bossWaves, waveInfo)
		end
	end

	return bossWaves
end

function BattleWaveUpdater.CheckAllKeyWave(self)
	for _, keyWaveInfo in ipairs(self._keyList) do
		if not keyWaveInfo:IsFinish() then
			return false
		end
	end

	return true
end

function BattleWaveUpdater.Clear(self)
	for timer, _ in pairs(self._timerList) do
		self:RemoveTimer(timer)
	end

	for _, waveInfo in pairs(self._waveInfoList) do
		waveInfo:UnregisterEventListener(self, ys.Battle.BattleEvent.WAVE_FINISH)
		waveInfo:Dispose()
	end

	self._waveInfoList = nil
	self._keyList = nil

	self:Init()
	ys.EventListener.DetachEventListener(self)
end

function BattleWaveUpdater.GetUnfinishedWaveCount(self)
	local unfinishedCount = 0

	for _, waveInfo in pairs(self._waveInfoList) do
		if not waveInfo:IsFinish() then
			unfinishedCount = unfinishedCount + 1
		end
	end

	return unfinishedCount
end
