ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourMovement = class("BattleEnvironmentBehaviourMovement", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourMovement = BattleEnvironmentBehaviourMovement
BattleEnvironmentBehaviourMovement.__name = "BattleEnvironmentBehaviourMovement"

--- @class BattleEnvironmentBehaviourMovement : BattleEnvironmentBehaviour
--- 环境移动行为：AOE区域沿预设路线移动，路线耗尽后随机游走
--- @field _movebeginTime number 当前段移动开始时间
--- @field _moveEndTime number 当前段移动结束时间
--- @field _lastPosition Vector3 上一个到达位置
--- @field _destPosition Vector3 目标位置
--- @field _targetIndex number 当前路线点索引
--- @field _route table 预设路线（可选）
--- @field _bounds table 移动边界（玩家舰队边界+碰撞数据偏移）
--- @field _random_duration table 随机持续时间范围 {min, max}
--- @field _random_speed number 随机速度
--- @field _randomRangeX number X轴随机范围
--- @field _randomRangeZ number Z轴随机范围
--- @field _resetRandomRange boolean 是否需要刷新随机边界
function BattleEnvironmentBehaviourMovement.Ctor(self)
	self._movebeginTime = nil
	self._moveEndTime = nil
	self._lastPosition = nil
	self._destPosition = nil
	self._targetIndex = 1

	BattleEnvironmentBehaviourMovement.super.Ctor(self)
end

--- 读取移动参数：路线、随机时长/速度、边界和起始位置
--- @param tmpData table
function BattleEnvironmentBehaviourMovement.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourMovement.super.SetTemplate(self, tmpData)

	self._route = tmpData.route or {}
	self._random_duration = tmpData.random_duration or {
		1,
		5
	}
	self._random_speed = tmpData.random_speed or 1

	local template = self._unit:GetTemplate()
	local cldX
	local cldZ

	if #template.cld_data == 1 then
		cldX = template.cld_data[1]
		cldZ = cldX
	elseif #template.cld_data == 2 then
		cldX, cldZ = unpack(template.cld_data)
	end

	local bounds = {
		ys.Battle.BattleDataProxy.GetInstance():GetFleetBoundByIFF(BattleConfig.FRIENDLY_CODE)
	}

	bounds[3] = bounds[3] + cldX
	bounds[4] = bounds[4] - cldX
	bounds[2] = bounds[2] + cldZ
	bounds[1] = bounds[1] - cldZ
	self._bounds = bounds
	self._lastPosition = Vector3(unpack(template.coordinate))

	if tmpData.random_range then
		self._randomRangeX = tmpData.random_range[1]
		self._randomRangeZ = tmpData.random_range[2]
		self._resetRandomRange = true
	end
end

--- 每帧计算Lerp插值位置；当前段结束时切换到下一路线点或生成随机目标
function BattleEnvironmentBehaviourMovement.doBehaviour(self)
	local now = pg.TimeMgr.GetInstance():GetCombatTime()

	if not self._moveEndTime then
		local routeEntry = self._route[self._targetIndex]

		self._movebeginTime = now

		if routeEntry then
			self._destPosition = Vector3(unpack(routeEntry))
			self._moveEndTime = now + routeEntry[4]
			self._targetIndex = self._targetIndex + 1
		else
			-- 路线耗尽，生成随机游走目标
			local randomPos = self:GenerateRandomPlayerAreaPoint()
			local duration = math.random(unpack(self._random_duration))
			local maxDistance = duration * self._random_speed
			local distance = (randomPos - self._lastPosition):Magnitude()

			if distance < maxDistance then
				duration = distance / self._random_speed
			else
				randomPos = Vector3.Lerp(self._lastPosition, randomPos, maxDistance / distance)
			end

			self._moveEndTime = now + duration
			self._destPosition = randomPos
		end
	end

	if now < self._moveEndTime then
		local lerpPos = Vector3.Lerp(self._lastPosition, self._destPosition, (now - self._movebeginTime) / (self._moveEndTime - self._movebeginTime))

		self._unit._aoeData:SetPosition(lerpPos)
	else
		self._unit._aoeData:SetPosition(self._destPosition)

		self._lastPosition = self._destPosition
		self._moveEndTime = nil
	end

	BattleEnvironmentBehaviourMovement.super.doBehaviour(self)
end

--- 在玩家舰队边界内随机生成一个目标点
--- @return Vector3
function BattleEnvironmentBehaviourMovement.GenerateRandomPlayerAreaPoint(self)
	local bounds = self._bounds
	local randX = math.random(bounds[3], bounds[4])
	local randZ = math.random(bounds[2], bounds[1])

	if self._resetRandomRange then
		self:resetRandomBound(randX, randZ)
	end

	return Vector3(randX, 0, randZ)
end

--- 以随机目标点为中心重置边界（用于random_range收缩搜索范围）
--- @param centerX number 新边界中心X
--- @param centerZ number 新边界中心Z
function BattleEnvironmentBehaviourMovement.resetRandomBound(self, centerX, centerZ)
	self._bounds[3] = centerX - self._randomRangeX
	self._bounds[4] = centerX + self._randomRangeX
	self._bounds[2] = centerZ - self._randomRangeZ
	self._bounds[1] = centerZ + self._randomRangeZ
	self._resetRandomRange = false
end

function BattleEnvironmentBehaviourMovement.Dispose(self)
	BattleEnvironmentBehaviourMovement.super.Dispose(self)
	table.clear(self)
end
