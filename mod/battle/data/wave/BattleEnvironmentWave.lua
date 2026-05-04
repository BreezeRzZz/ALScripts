ys = ys or {}

local ys = ys

ys.Battle.BattleEnvironmentWave = class("BattleEnvironmentWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleEnvironmentWave.__name = "BattleEnvironmentWave"

local BattleEnvironmentWave = ys.Battle.BattleEnvironmentWave

--- 波次类型：环境触发波
--- 生成战场环境元素（如天气效果、场景机制等）。
--- 支持延迟生成（通过 BattleTimer），并可在警告启用时通过 doPass 关闭警告。
function BattleEnvironmentWave.Ctor(self)
	BattleEnvironmentWave.super.Ctor(self)

	self._spawnTimerList = {}
end

--- 设置波次数据，从 waveData 读取生成列表和警告配置
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleEnvironmentWave.SetWaveData(self, waveData)
	BattleEnvironmentWave.super.SetWaveData(self, waveData)

	self._spawnData      = waveData.spawn or {}    -- 环境元素的生成数据列表
	self._environWarning = waveData.warning          -- 是否显示环境警告提示
end

--- 执行波次：遍历 spawnData，有延迟的启动定时器，无延迟的直接生成
--- 如果配置了 warning，则通过 DataProxy 显示警告
function BattleEnvironmentWave.DoWave(self)
	BattleEnvironmentWave.super.DoWave(self)

	for _, spawnItem in ipairs(self._spawnData) do
		if spawnItem.delay and spawnItem.delay > 0 then
			-- 延迟生成：启动 BattleTimer
			self:spawnTimer(spawnItem)
		else
			-- 立即生成环境元素
			self:doSpawn(spawnItem)
		end
	end

	-- 显示环境警告提示
	if self._environWarning then
		ys.Battle.BattleDataProxy.GetInstance():DispatchWarning(true)
	end
end

--- 生成单个环境元素
--- 调用 DataProxy.SpawnEnvironment 创建环境对象，生成完成后回调 doPass
--- @param spawnItem table 单个环境元素生成数据
function BattleEnvironmentWave.doSpawn(self, spawnItem)
	local environmentObj = ys.Battle.BattleDataProxy.GetInstance():SpawnEnvironment(spawnItem)

	-- 环境对象生成完成后回调 doPass
	local function onEnvironmentReady()
		self:doPass()
	end

	environmentObj:ConfigCallback(onEnvironmentReady)
end

--- 覆写 doPass，关闭环境警告提示
function BattleEnvironmentWave.doPass(self)
	if self._environWarning then
		ys.Battle.BattleDataProxy.GetInstance():DispatchWarning(false)
	end
end

--- 为指定环境元素启动延迟生成定时器
--- @param spawnItem table 单个环境元素生成数据
function BattleEnvironmentWave.spawnTimer(self, spawnItem)
	local spawnTimer
	local delayTime = spawnItem.delay

	-- 定时器回调：生成环境元素，移除定时器
	local function onTimerEnds()
		self:doSpawn(spawnItem)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(spawnTimer)
	end

	spawnTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 1, delayTime, onTimerEnds, true)
	self._spawnTimerList[spawnTimer] = true
end

--- 销毁：清除所有未完成的 spawnTimer
function BattleEnvironmentWave.Dispose(self)
	for timer, _ in pairs(self._spawnTimerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)
	end

	self._spawnTimerList = nil
end
