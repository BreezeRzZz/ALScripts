ys = ys or {}

local ys = ys
local WaveTriggerType = ys.Battle.BattleConst.WaveTriggerType

ys.Battle.BattleWaveInfo = class("BattleWaveInfo")
ys.Battle.BattleWaveInfo.__name = "BattleWaveInfo"

local BattleWaveInfo = ys.Battle.BattleWaveInfo

BattleWaveInfo.LOGIC_AND = 0
BattleWaveInfo.LGOIC_OR = 1
BattleWaveInfo.STATE_DEACTIVE = "STATE_DEACTIVE"
BattleWaveInfo.STATE_ACTIVE = "STATE_ACTIVE"
BattleWaveInfo.STATE_PASS = "STATE_PASS"
BattleWaveInfo.STATE_FAIL = "STATE_FAIL"

-- BattleWaveInfo类是战斗波次信息的基础类，定义了波次的基本属性和行为。
-- 其他的，BattleSpawnWave、BattleDelayWave等类继承自此类，并实现了具体的波次逻辑。
-- 子类中，如BattleSpawnWave这类是最重要的，需要重点关注
-- 其他的可能就是播放BGM之类非战斗行为的波次，了解即可。
function BattleWaveInfo.Ctor(self)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._preWaves = {}
	self._postWaves = {}
	self._branchWaves = {}
end

function BattleWaveInfo.IsReady(self)
	return self:IsPreWavesFinished()
end

function BattleWaveInfo.IsFlagsPass(self)
	if not self._blockFlags or not next(self._blockFlags) then
		return true
	end

	local waveFlags = ys.Battle.BattleDataProxy.GetInstance():GetWaveFlags()

	if not waveFlags or not next(waveFlags) then
		return false
	end

	for _, blockFlag in ipairs(self._blockFlags) do
		if not table.contains(waveFlags, blockFlag) then
			return false
		end
	end

	return true
end

function BattleWaveInfo.IsPreWavesFinished(self)
	local preWaves = #self._preWaves
	local isFinished

	if #self._preWaves == 0 then
		isFinished = true
	elseif self._logicType == BattleWaveInfo.LOGIC_AND then
		-- AND: 需要全部都通过才算
		isFinished = true

		for _, preWave in ipairs(self._preWaves) do
			if not preWave:IsFinish() then
				isFinished = false

				break
			end
		end
	elseif self._logicType == BattleWaveInfo.LGOIC_OR then
		-- OR: 有一个通过就算
		isFinished = false

		for _, preWave in ipairs(self._preWaves) do
			if preWave:IsFinish() then
				isFinished = true

				break
			end
		end
	end

	return isFinished
end

function BattleWaveInfo.IsFinish(self)
	return self:GetState() == BattleWaveInfo.STATE_PASS or self:GetState() == BattleWaveInfo.STATE_FAIL
end

function BattleWaveInfo.DoBranch(self)
	for _, branchWave in ipairs(self._branchWaves) do
		local branchWaveID = self._branchWaveIDs[branchWave:GetIndex()]

		if branchWaveID and branchWave:GetState() == BattleWaveInfo.STATE_PASS or not branchWaveID and branchWave:GetState() == BattleWaveInfo.STATE_FAIL then
			-- block empty
		else
			self:doFail()

			return
		end
	end

	if not self:IsFlagsPass() then
		self:doFail()

		return
	end

	self:DoWave()
end

function BattleWaveInfo.DoWave(self)
	self._state = BattleWaveInfo.STATE_ACTIVE
end

function BattleWaveInfo.AddMonster(self)
	return
end

function BattleWaveInfo.RemoveMonster(self)
	return
end

-- 此处设定数据
-- 在BattleWaveUpdater.SetWavesData中调用
-- waveData实际对应到dungeon配置文件中的waves字段下的每一个元素
function BattleWaveInfo.SetWaveData(self, waveData)
	self._index = waveData.waveIndex
	self._isKeyWave = waveData.key
	self._logicType = waveData.conditionType or BattleWaveInfo.LOGIC_AND
	self._param = waveData.triggerParams or {}
	self._preWaveIDs = waveData.preWaves or {}
	self._branchWaveIDs = waveData.conditionWaves or {}
	self._blockFlags = waveData.blockFlags
	self._type = waveData.triggerType
	self._state = BattleWaveInfo.STATE_DEACTIVE
end

function BattleWaveInfo.SetCallback(self, spawnFunc, airFunc)
	self._spawnFunc = spawnFunc
	self._airFunc = airFunc
end

function BattleWaveInfo.AppendBranchWave(self, branchWave)
	self._branchWaves[#self._branchWaves + 1] = branchWave
end

function BattleWaveInfo.AppendPreWave(self, preWave)
	self._preWaves[#self._preWaves + 1] = preWave
end

function BattleWaveInfo.AppendPostWave(self, postWave)
	self._postWaves[#self._postWaves + 1] = postWave
end

function BattleWaveInfo.IsKeyWave(self)
	return self._isKeyWave
end

function BattleWaveInfo.GetPostWaves(self)
	return self._postWaves
end

function BattleWaveInfo.GetIndex(self)
	return self._index
end

function BattleWaveInfo.GetType(self)
	return self._type
end

function BattleWaveInfo.GetState(self)
	return self._state
end

function BattleWaveInfo.GetPreWaveIDs(self)
	return self._preWaveIDs
end

function BattleWaveInfo.GetBranchWaveIDs(self)
	return self._branchWaveIDs
end

function BattleWaveInfo.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
end

function BattleWaveInfo.doPass(self)
	if not self:IsFinish() then
		self._state = BattleWaveInfo.STATE_PASS

		self:DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.WAVE_FINISH, {}))
	end
end

function BattleWaveInfo.doFail(self)
	if not self:IsFinish() then
		self._state = BattleWaveInfo.STATE_FAIL

		self:DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.WAVE_FINISH, {}))
	end
end
