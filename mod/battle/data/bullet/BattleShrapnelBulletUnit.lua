ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleConst = ys.Battle.BattleConst
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleFormulas = ys.Battle.BattleFormulas

ys.Battle.BattleShrapnelBulletUnit = class("BattleShrapnelBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleShrapnelBulletUnit.__name = "BattleShrapnelBulletUnit"

local BattleShrapnelBulletUnit = ys.Battle.BattleShrapnelBulletUnit

BattleShrapnelBulletUnit.STATE_NORMAL = "normal"
BattleShrapnelBulletUnit.STATE_SPLIT = "split"
BattleShrapnelBulletUnit.STATE_SPIN = "spin"
BattleShrapnelBulletUnit.STATE_FINAL_SPLIT = "final_split"
BattleShrapnelBulletUnit.STATE_EXPIRE = "expire"
BattleShrapnelBulletUnit.STATE_PRIORITY = {
	[BattleShrapnelBulletUnit.STATE_EXPIRE] = 5,
	[BattleShrapnelBulletUnit.STATE_FINAL_SPLIT] = 4,
	[BattleShrapnelBulletUnit.STATE_SPLIT] = 3,
	[BattleShrapnelBulletUnit.STATE_SPIN] = 2,
	[BattleShrapnelBulletUnit.STATE_NORMAL] = 1
}

--- @class BattleShrapnelBulletUnit
--- @param uniqueID number
--- @param IFF number
--- @return nil
--- 构造函数
function BattleShrapnelBulletUnit.Ctor(self, uniqueID, IFF)
	BattleShrapnelBulletUnit.super.Ctor(self, uniqueID, IFF)

	self._splitCount = 0
	self._cacheEmitter = {}

	self:ChangeShrapnelState(self.STATE_NORMAL)
end

--- @class BattleShrapnelBulletUnit
--- @param uniqueID number
--- @param unitType number
--- @return nil
--- 命中处理
function BattleShrapnelBulletUnit.Hit(self, uniqueID, unitType)
	if self:GetTemplate().extra_param.rangeAA then
		return
	end

	BattleShrapnelBulletUnit.super.Hit(self, uniqueID, unitType)

	self._pierceCount = self._pierceCount - 1
end

--- @class BattleShrapnelBulletUnit
--- @return nil
--- 分裂计数加一
function BattleShrapnelBulletUnit.SplitFinishCount(self)
	self._splitCount = self._splitCount + 1
end

--- @class BattleShrapnelBulletUnit
--- @return boolean
--- 判断是否全部分裂完成
function BattleShrapnelBulletUnit.IsAllSplitFinish(self)
	return self._splitCount >= #self._tempData.extra_param.shrapnel
end

--- @class BattleShrapnelBulletUnit
--- @param template table
--- @return nil
--- 设置模板数据
function BattleShrapnelBulletUnit.SetTemplateData(self, template)
	BattleShrapnelBulletUnit.super.SetTemplateData(self, template)

	self._outbound = self._tempData.out_bound
end

--- @class BattleShrapnelBulletUnit
--- @return number
--- 获取出界处理方式(参考BattleConst.BulletOutBound)
--- - COMMON = 0
--- - EXIST = 1
--- - RANDOM = 2
--- - VISION = 3
--- - SPLIT = 4
--- - SHIFT_SPLIT = 5
function BattleShrapnelBulletUnit.GetOutBound(self)
	return self._outbound
end

--- @class BattleShrapnelBulletUnit
--- @param timeStamp number
--- @return nil
--- BattleShrapnelBulletUnit的Update函数
function BattleShrapnelBulletUnit.Update(self, timeStamp)
	-- 以下都是针对SHIFT_SPLIT类型的处理
	if self._startCount == nil and self._outbound == BattleConst.BulletOutBound.SHIFT_SPLIT then
		self._startCount = timeStamp
	end

	if self._outbound == BattleConst.BulletOutBound.SHIFT_SPLIT then
		if self._startCount == nil then
			self._startCount = timeStamp
		-- BULLET_SPLIT_SHIFT_DELAY = 0.2
		-- 0.2s后，切换到SPLIT出界处理方式
		elseif timeStamp - self._startCount > BattleConfig.BULLET_SPLIT_SHIFT_DELAY then
			self._outbound = BattleConst.BulletOutBound.SPLIT
		end
	end

	if self._currentState == BattleShrapnelBulletUnit.STATE_NORMAL then
		local verticalSpeed = self._verticalSpeed

		BattleShrapnelBulletUnit.super.Update(self, timeStamp)
		-- 意思是上一帧的垂直速度和当前帧的垂直速度符号不同，表示开始下落
		-- 切换到SPLIT状态
		if verticalSpeed ~= 0 and verticalSpeed * self._verticalSpeed < 0 then
			self:ChangeShrapnelState(BattleShrapnelBulletUnit.STATE_SPLIT)
		end
	-- 如果已经是SPIN状态，并且持续时间超过lastTime参数，切换到SPLIT状态
	elseif self._currentState == BattleShrapnelBulletUnit.STATE_SPIN and (not self._tempData.extra_param.lastTime or timeStamp - self._spinStartTime > self._tempData.extra_param.lastTime) then
		self:ChangeShrapnelState(BattleShrapnelBulletUnit.STATE_SPLIT)
	end
end

--- @class BattleShrapnelBulletUnit
--- @param state string
--- @return nil
--- 切换Shrapnel状态
function BattleShrapnelBulletUnit.ChangeShrapnelState(self, state)
	local priority = BattleShrapnelBulletUnit.STATE_PRIORITY[self._currentState]
	-- 只允许切换到更高优先级的状态
	-- 也即NORMAL -> SPIN -> SPLIT -> FINAL_SPLIT -> EXPIRE(中间可以跳过某些状态)
	if priority and priority >= BattleShrapnelBulletUnit.STATE_PRIORITY[state] then
		return
	end

	self._currentState = state
	-- 记录spin开始的时间戳
	if self._currentState == BattleShrapnelBulletUnit.STATE_SPIN then
		self._spinStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	-- 如果切换到SPLIT状态，派发SPLIT事件
	-- Listener: BattleShrapnelBullet.onBulletSplit
	elseif self._currentState == BattleShrapnelBulletUnit.STATE_SPLIT then
		self:DispatchEvent(ys.Event.New(BattleBulletEvent.SPLIT, {}))
	end
end

--- @class BattleShrapnelBulletUnit
--- @return boolean
--- 判断是否出界
--- - 原本有一个参数，但父类的IsOutRange没有参数，所以这里也去掉参数
function BattleShrapnelBulletUnit.IsOutRange(self)
	if self._currentState == BattleShrapnelBulletUnit.STATE_NORMAL then
		-- 对应的就是超出射程(range)的判断
		return BattleShrapnelBulletUnit.super.IsOutRange(self)
	else
		return false
	end
end

--- @class BattleShrapnelBulletUnit
--- @param host BattleUnit
--- @return nil
--- 设置子弹的来源单位
function BattleShrapnelBulletUnit.SetSrcHost(self, host)
	self._srcHost = host
end

--- @class BattleShrapnelBulletUnit
--- @return BattleUnit
--- 获取子弹的来源单位
function BattleShrapnelBulletUnit.GetSrcHost(self)
	return self._srcHost
end

--- @class BattleShrapnelBulletUnit
--- @return table
--- 获取子母弹相关参数
function BattleShrapnelBulletUnit.GetShrapnelParam(self)
	return self._tempData.extra_param
end

--- @class BattleShrapnelBulletUnit
--- @return string
--- 获取当前状态
function BattleShrapnelBulletUnit.GetCurrentState(self)
	return self._currentState
end

--- @class BattleShrapnelBulletUnit
--- @param position Vector3
--- @return nil
--- 设置子弹生成位置
--- ! 这个函数目前还有许多不明确的地方，待补充
function BattleShrapnelBulletUnit.SetSpawnPosition(self, position)
	local extra_param = self:GetTemplate().extra_param
	local _position = position

	if extra_param.directHit then
		_position = Clone(self._explodePos)
	end

	BattleShrapnelBulletUnit.super.SetSpawnPosition(self, _position)
	-- 计算时，不考虑y轴
	local spawnPos = pg.Tool.FilterY(self._spawnPos)
	local distance = Vector3.Distance(spawnPos, pg.Tool.FilterY(self._explodePos))

	if extra_param.flare then
		local childBulletID = extra_param.shrapnel[1].bullet_ID
		local childBulletTemplate = ys.Battle.BattleDataFunction.GetBulletTmpDataFromID(childBulletID)
		local childDropTime = childBulletTemplate.hit_type.childDropTime
		-- 减号左边: 孩子在这段时间内的高度变化，是负数
			-- h = 0.5gt^2
		-- 减号右边：母弹此刻的高度
		-- 因此这个值表示的是???为什么是减?确定没写错?
		local childFallHeight = 0.5 * math.abs(childBulletTemplate.extra_param.gravity or -0.0005) * (childDropTime * BattleConfig.calcFPS)^2 - self._spawnPos.y
		-- 计算母弹的水平速度，为了方便，下面对childFallHeight的符号取了反
		-- v_x = sqrt(gd^2 / 2h)
		-- 也即(v_x)^2 = gd^2 / 2h
		-- -> 2h(v_x)^2 = gd^2
		-- -> (d/v_x)^2 = 2h/g -> d/vx = sqrt(2h/g)
		-- 表示水平时间 = 下落时间. 
		-- 因此这里计算的v_x的意义是：让母弹飞行的时间等于孩子下落的时间
		self._convertedVelocity = math.sqrt(-0.5 * self._gravity * distance * distance / childFallHeight)
		-- 这个值表示母弹飞行的时间，理论上实际应该与childDropTime相等
		-- t = d/v_x
		local flightTime = distance / self._convertedVelocity
		-- 计算母弹的垂直速度, 为了方便，下面对g的符号取了反
		-- v_y = h/t + 0.5gt
		-- 对应h = v_yt - 0.5gt^2
		self._verticalSpeed = childFallHeight / flightTime - 0.5 * self._gravity * flightTime
	elseif extra_param.rangeAA then
		-- AircraftHeight = 10
		local targetHeightChange = BattleConfig.AircraftHeight - self._spawnPos.y
		local halfGravity = 0.5 * self._gravity

		self._velocity = math.sqrt(-halfGravity * distance * distance / targetHeightChange)

		local flightTime = distance / self._velocity

		self._verticalSpeed = targetHeightChange / flightTime - halfGravity * flightTime
		self._velocity = BattleFormulas.ConvertBulletDataSpeed(self._velocity)
	elseif self._convertedVelocity ~= 0 and self._explodePos.y ~= self._spawnPos.y then
		local flightTime = distance / self._convertedVelocity
		local heightChange = self._explodePos.y - self._spawnPos.y
		-- 这个比较好理解，就是用水平飞行的时间反推初始垂直速度
		self._verticalSpeed = extra_param.launchVrtSpeed or heightChange / flightTime - 0.5 * self._gravity * flightTime
	end
end

--- @class BattleShrapnelBulletUnit
--- @return Vector3
--- 获取指定爆炸位置
function BattleShrapnelBulletUnit.GetExplodePostion(self)
	return self._explodePos
end

--- @class BattleShrapnelBulletUnit
--- @param position Vector3
--- @return nil
--- 设置指定爆炸位置
function BattleShrapnelBulletUnit.SetExplodePosition(self, position)
	self._explodePos = Clone(position)
	self._explodePos.y = BattleConfig.BombDetonateHeight
end

--- @class BattleShrapnelBulletUnit
--- @param emitter BattleBulletEmitter
--- @return nil
--- 缓存孩子子弹的emitter
function BattleShrapnelBulletUnit.CacheChildEimtter(self, emitter)
	table.insert(self._cacheEmitter, emitter)
end

--- @class BattleShrapnelBulletUnit
--- @return nil
--- 中断所有孩子子弹的emitter
function BattleShrapnelBulletUnit.interruptChildEmitter(self)
	for _, emitter in ipairs(self._cacheEmitter) do
		emitter:Destroy()
	end
end

--- @class BattleShrapnelBulletUnit
--- @return nil
--- 销毁函数
function BattleShrapnelBulletUnit.Dispose(self)
	self:interruptChildEmitter()

	self._cacheEmitter = nil

	BattleShrapnelBulletUnit.super.Dispose(self)
end
