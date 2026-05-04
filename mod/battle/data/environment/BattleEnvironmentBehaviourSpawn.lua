ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleFormulas = ys.Battle.BattleFormulas
local BattleEnvironmentBehaviourSpawn = class("BattleEnvironmentBehaviourSpawn", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourSpawn = BattleEnvironmentBehaviourSpawn
BattleEnvironmentBehaviourSpawn.__name = "BattleEnvironmentBehaviourSpawn"

--- @class BattleEnvironmentBehaviourSpawn : BattleEnvironmentBehaviour
--- 环境生成行为：在AOE区域内按轮次生成子环境单元（含预警特效）
--- @field _content table 生成内容模板（含count, child_prefab, alert等）
--- @field _route table 每轮位置偏移路线
--- @field _reloadTime number 每轮间隔时间
--- @field _rounds number 总轮数
--- @field _targetIndex number 当前轮次索引
--- @field _alertTimer any 预警计时器句柄
function BattleEnvironmentBehaviourSpawn.Ctor(self)
	self._moveEndTime = nil
	self._targetIndex = 0

	BattleEnvironmentBehaviourSpawn.super.Ctor(self)
end

--- 读取生成参数：内容模板、路线、轮次
--- @param tmpData table
function BattleEnvironmentBehaviourSpawn.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourSpawn.super.SetTemplate(self, tmpData)

	self._content = tmpData.content
	self._route = tmpData.route or {}
	self._reloadTime = tmpData.reload_time
	self._rounds = tmpData.rounds
end

--- 每轮在AOE区域内生成count个子环境单元
--- CUBE区域使用矩形随机分布，COLUMN区域使用圆形随机分布
function BattleEnvironmentBehaviourSpawn.doBehaviour(self)
	self._targetIndex = self._targetIndex + 1

	if self._targetIndex <= self._rounds then
		local routeEntry = self._route[self._targetIndex]
		local dataProxy = ys.Battle.BattleDataProxy.GetInstance()
		local aoeData = self._unit._aoeData
		local originPos = aoeData:GetPosition()
		local contentData = Clone(self._content)

		if routeEntry then
			table.merge(contentData, routeEntry)
		end

		local count = contentData.count
		local childPrefab = contentData.child_prefab
		local positions

		if aoeData:GetAreaType() == BattleConst.AreaType.CUBE then
			local prefabCldX, prefabCldZ = unpack(childPrefab.cld_data)

			positions = self.GenerateRandomRectanglePosition(aoeData:GetWidth(), aoeData:GetHeight(), count, math.max(prefabCldX, prefabCldZ or 0))
		elseif aoeData:GetAreaType() == BattleConst.AreaType.COLUMN then
			local prefabCldX, prefabCldZ = unpack(childPrefab.cld_data)

			positions = self.GenerateRandomCirclePosition(aoeData:GetRange(), count, math.max(prefabCldX, prefabCldZ or 0))
		end

		-- 将本地坐标偏移到世界坐标
		for i = 1, count do
			positions[i] = positions[i] + originPos
		end

		seriesAsync({
			function(nextStep)
				if not contentData.alert then
					nextStep()

					return
				end

				-- 播放预警特效
				for i = 1, count do
					local pos = positions[i]

					self.PlayAlert(contentData.alert, pos)
				end

				self:RemoveAlertTimer()

				-- 延迟后进入下一阶段（生成子单元）
				self._alertTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 1, contentData.alert.delay or 1, nextStep, true)
			end,
			function(nextStep)
				for i = 1, count do
					local spawnData = Clone(childPrefab)
					local pos = positions[i]

					spawnData.coordinate = {
						pos.x,
						pos.y,
						pos.z
					}

					dataProxy:SpawnEnvironment(spawnData)
				end
			end
		})
		BattleEnvironmentBehaviourSpawn.super.doBehaviour(self)
	else
		self:doExpire()
	end
end

--- 移除预警计时器
function BattleEnvironmentBehaviourSpawn.RemoveAlertTimer(self)
	if self._alertTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._alertTimer)
	end

	self._alertTimer = nil
end

--- 在指定位置播放预警特效
--- @param alertConfig table 预警配置 {range, alert_fx, ...}
--- @param position Vector3 播放位置
function BattleEnvironmentBehaviourSpawn.PlayAlert(self, alertConfig, position)
	local range = alertConfig.range
	local alertFX = alertConfig.alert_fx

	if not alertFX then
		return
	end

	local fx = ys.Battle.BattleFXPool.GetInstance():GetFX(alertFX)
	local fxTrans = fx.transform
	local yScale = 0
	local effectOffset = pg.effect_offset

	if effectOffset[alertFX] and effectOffset[alertFX].y_scale == true then
		yScale = range
	end

	fxTrans.localScale = Vector3(range, yScale, range)

	pg.EffectMgr.GetInstance():PlayBattleEffect(fx, position)
end

local math = math

--- 六边形七个方向的偏移向量，用于圆形区域的六边形分层分布
local hexagonOffsets = {
	Vector2(0, 0),
	Vector2(-0.66, 0),
	Vector2(-0.33, 0.58),
	Vector2(0.33, 0.58),
	Vector2(0.66, 0),
	Vector2(0.33, -0.58),
	Vector2(-0.33, -0.58)
}

--- 在矩形区域内生成随机分布位置（基于网格的泊松分布采样）
--- 通过权重递减避免生成点过近
--- @param width number 区域宽度
--- @param height number 区域高度
--- @param count number 生成数量
--- @param collideRadius number 碰撞间距（传入后逐步减半）
--- @return Vector3[] 位置列表
function BattleEnvironmentBehaviourSpawn.GenerateRandomRectanglePosition(self, width, height, count, collideRadius)
	local gridSize = math.ceil(math.sqrt(count))
	local weightList = {}

	for _ = 1, gridSize * gridSize do
		table.insert(weightList, {
			weight = 65536,
			rst = _
		})
	end

	local positions = {}

	for i = 1, count do
		local selected = BattleFormulas.WeightRandom(weightList)

		weightList[selected].weight = 0

		local row = math.floor((selected - 1) / gridSize)
		local rowStart = row * gridSize

		-- 降低同行权重，避免点聚集在同一行
		for col = 0, gridSize - 1 do
			weightList[rowStart + col + 1].weight = weightList[rowStart + col + 1].weight / 2
		end

		local col = selected - row * gridSize

		-- 降低同列权重，避免点聚集在同一列
		for r = 0, gridSize - 1 do
			weightList[col + r * gridSize].weight = weightList[col + r * gridSize].weight / 2
		end

		collideRadius = collideRadius / 2

		local posX = (col - 1 - gridSize / 2) * (width / gridSize) + math.random(1, 1000) / 1000 * (width / gridSize - 2 * collideRadius) + collideRadius
		local posZ = (row - gridSize / 2) * (height / gridSize) + math.random(1, 1000) / 1000 * (height / gridSize - 2 * collideRadius) + collideRadius

		table.insert(positions, Vector3(posX, 0, posZ))
	end

	return positions
end

--- 在圆形区域内生成随机分布位置（基于七边形递归分层的泊松分布采样）
--- @param radius number 区域半径
--- @param count number 生成数量
--- @return Vector3[] 位置列表
function BattleEnvironmentBehaviourSpawn.GenerateRandomCirclePosition(self, radius, count)
	local level = 1
	local levelMax = 1
	local subRadius = radius

	while levelMax < count do
		levelMax = levelMax * 7
		level = level + 1
		subRadius = subRadius / 3
	end

	local weightList = {}

	for _ = 1, levelMax do
		table.insert(weightList, {
			weight = 256,
			rst = _
		})
	end

	local positions = {}

	for i = 1, count do
		local selected = BattleFormulas.WeightRandom(weightList)

		weightList[selected].weight = 0

		local idx = selected - 1
		local curCount = 1
		local offset = Vector2(0, 0)
		local curRadius = subRadius

		-- 递归反推七边形分层坐标
		for levelIdx = level, 2, -1 do
			local idxCopy = idx

			idx = math.floor(idx / 7)

			local cell = idxCopy - idx * 7

			curRadius = curRadius * 3

			offset:Add(curRadius * hexagonOffsets[cell + 1])

			curCount = curCount * 7

			if levelIdx > 2 and levelIdx == level then
				-- 降低同父节点的权重
				for j = idx * curCount + 1, idx * curCount + curCount do
					weightList[j].weight = weightList[j].weight / 2
				end
			end
		end

		-- 在采样点周围加随机偏移
		local angle = math.random(1, 360)
		local randR = math.random(1, 1000) / 1000 * math.max(subRadius - count, 0)

		offset:Add(Vector2(randR * math.cos(angle), randR * math.sin(angle)))
		table.insert(positions, Vector3(offset.x, 0, offset.y))
	end

	return positions
end

function BattleEnvironmentBehaviourSpawn.Dispose(self)
	self:RemoveAlertTimer()
	table.clear(self)
	BattleEnvironmentBehaviourSpawn.super.Dispose(self)
end
