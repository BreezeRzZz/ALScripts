ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleBombBulletUnit = class("BattleBombBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleBombBulletUnit.__name = "BattleBombBulletUnit"

local BattleBombBulletUnit = ys.Battle.BattleBombBulletUnit

-- 对应BOMB类型子弹
function BattleBombBulletUnit.Ctor(self, UID, IFF)
	BattleBombBulletUnit.super.Ctor(self, UID, IFF)

	self._randomOffset = Vector3.zero
end

function BattleBombBulletUnit.InitSpeed(self)
	if self._barrageLowPriority then
		-- 基础角度(+弹幕角度)
		self._yAngle = self._baseAngle + self._barrageAngle
	else
		-- 指向目标点的角度
		self._yAngle = math.rad2Deg * math.atan2(self._explodePos.z - self._spawnPos.z, self._explodePos.x - self._spawnPos.x)
	end

	self:calcSpeed()
	-- 炸弹类子弹没有加速表配置来控制速度变化，速度恒定
	self.updateSpeed = BattleBombBulletUnit.doNothing
end

function BattleBombBulletUnit.Update(self)
	if self._exist then
		BattleBombBulletUnit.super.Update(self)
	end
end

function BattleBombBulletUnit.GetPierceCount(self)
	return 1
end

function BattleBombBulletUnit.IsOutRange(self, timeStamp)
	if not self._exist then
		return false
	end
	-- 如果有explodeTime，在时间到达时引爆
	if self._explodeTime and timeStamp >= self._explodeTime then
		return true
	end
	-- 如果没有，到达目标点时引爆
	-- reachDestFlag的设置，在BattleBulletUnit.Update中
	if self._reachDestFlag and not self._explodeTime then
		return true
	else
		return false
	end
end

function BattleBombBulletUnit.OutRange(self)
	local explodeArgs = {
		UID = unitUniqueID
	}

	self:DispatchEvent(ys.Event.New(BattleBulletEvent.EXPLODE, explodeArgs))
	BattleBombBulletUnit.super.OutRange(self)
end

-- IMPORTANT: 炸弹类子弹的出生点设置
function BattleBombBulletUnit.SetSpawnPosition(self, pos)
	BattleBombBulletUnit.super.SetSpawnPosition(self, pos)
	-- 如果Bullet的extra_param中有barragePriority = true
	if self._barragePriority then
		-- 加上固定偏移部分
		self._explodePos = self._explodePos + Vector3(self._offsetX, 0, self._offsetZ)

		-- 下面实际是spawnPos绕y轴旋转barrageAngle度后的结果，作为最终的explodePos
		local barrageAngle = Quaternion.Euler(0, self._barrageAngle, 0)
		local spawnPos = pg.Tool.FilterY(self._spawnPos)

		self._explodePos = barrageAngle * (self._explodePos - spawnPos) + spawnPos
	end
	-- 有fixToRange的话，限制explodePos到最大射程范围内(与原爆炸点、出生点在同一条直线上)
	if self._fixToRange and Vector3.BattleDistance(self._explodePos, self._spawnPos) > self._range then
		local direction = pg.Tool.FilterY(self._explodePos - self._spawnPos)

		self._explodePos = Vector3.Normalize(direction) * self._range + self._spawnPos
	end
	-- 下面是根据水平速度，反推垂直速度
	-- 让子弹看起来是抛物线运动的
	if self._convertedVelocity ~= 0 then
		local spawnPos = pg.Tool.FilterY(self._spawnPos)
		-- 这里其实有点怪，因为explodePos的y已经被设定为1.2了，但spawnPos的y刚被过滤为0了，所以这里本来是想计算水平距离，但实际是多算了一个1.2^2的距离平方（不过影响非常小就是了）
		local flyTime = Vector3.Distance(spawnPos, self._explodePos) / self._convertedVelocity
		local dy = self._explodePos.y - self._spawnPos.y
		-- 因为dy = 1/2 * g * t^2 + v0 * t
		-- 所以 v0 = (dy - 1/2 * g * t^2) / t = dy / t - 1/2 * g * t
		-- 如果模板中有指定launchVrtSpeed，则使用指定值(会使动画对不上吗？有可能...)
		self._verticalSpeed = self:GetTemplate().extra_param.launchVrtSpeed or dy / flyTime - 0.5 * self._gravity * flyTime
	end
end

-- important: 炸弹类子弹的爆炸点设置
function BattleBombBulletUnit.SetExplodePosition(self, pos)
	local extra_param = self:GetTemplate().extra_param
	-- 如果指定了固定爆炸点坐标，则使用该坐标
	if extra_param.targetFixX and extra_param.targetFixZ then
		self._explodePos = Vector3(extra_param.targetFixX, 0, extra_param.targetFixZ)
	else
		self._explodePos = pos:Clone()
	end
	-- 如果没有barragePriority，则加上随机偏移
	if not self._barragePriority then
		self._explodePos = self._explodePos + self._randomOffset
	end

	self._explodePos.y = BattleConfig.BombDetonateHeight
end

function BattleBombBulletUnit.SetShiftInfo(self, offsetX, offsetZ)
	BattleBombBulletUnit.super.SetShiftInfo(self, offsetX, offsetZ)

	if self:GetTemplate().extra_param.currentdrop then
		self._explodePos.x = self._explodePos.x + self._offsetX
		self._explodePos.z = self._explodePos.z + self._offsetZ
	end
end

-- Important: 炸弹类子弹的模板数据设置(大量数据预处理)
function BattleBombBulletUnit.SetTemplateData(self, tmpData)
	BattleBombBulletUnit.super.SetTemplateData(self, tmpData)

	local extra_param = self:GetTemplate().extra_param

	self._barragePriority = extra_param.barragePriority
	self._barrageLowPriority = extra_param.barrageLowPriority
	self._fixToRange = extra_param.fixToRange
	-- barragePriority没有随机偏移
	if extra_param.barragePriority then
		self._randomOffset = Vector3.zero
	else
		-- TODO: chargeBulletAccuracy的使用
		-- 此处要用到template中的accuracy，值是一个类型字符串
		-- 一般只有装备的主炮会带这种子弹
		local accuracyType = extra_param.accuracy
		local accuracyBias = 0
		-- 如果有，获取子弹的对应属性值(散布减小)
		if accuracyType then
			accuracyBias = self:GetAttrByName(accuracyType)
		end

		local randomOffsetX = extra_param.randomOffsetX or 0
		local randomOffsetZ = extra_param.randomOffsetZ or 0
		local realRandomOffsetX = math.max(0, randomOffsetX - accuracyBias)
		local realRandomOffsetZ = math.max(0, randomOffsetZ - accuracyBias)
		local offsetX = extra_param.offsetX or 0
		local offsetZ = extra_param.offsetZ or 0

		if realRandomOffsetX ~= 0 then
			realRandomOffsetX = realRandomOffsetX * (math.random() - 0.5) + offsetX
		end

		if realRandomOffsetZ ~= 0 then
			realRandomOffsetZ = realRandomOffsetZ * (math.random() - 0.5) + offsetZ
		end

		local targetOffsetX = extra_param.targetOffsetX or 0
		local targetOffsetZ = extra_param.targetOffsetZ or 0
		-- 总的来说三部分：随机偏移((-0.5,0.5)的分布)、固定偏移、目标偏移
		self._randomOffset = Vector3(realRandomOffsetX + targetOffsetX, 0, realRandomOffsetZ + targetOffsetZ)
	end
	-- timeToExplode: 设定多少秒后强制引爆(走BattleTimer)
	if extra_param.timeToExplode then
		self._explodeTime = pg.TimeMgr.GetInstance():GetCombatTime() + extra_param.timeToExplode
	end
	-- 默认是-0.05. Bomb子弹都是有重力的, 因此会表现出抛物线运动的效果。gravity越大，抛物线越陡峭
	self._gravity = extra_param.gravity or ys.Battle.BattleConfig.GRAVITY
	-- hitInterval是判定两次伤害的时间间隔(很少用)
	self._hitInterval = tmpData.hit_type.interval or 0.2
end

function BattleBombBulletUnit.DealDamage(self)
	self._nextDamageTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._hitInterval
end

function BattleBombBulletUnit.CanDealDamage(self)
	if not self._nextDamageTime then
		self._nextDamageTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._tempData.extra_param.alert_duration

		return false
	else
		return self._nextDamageTime < pg.TimeMgr.GetInstance():GetCombatTime()
	end
end

function BattleBombBulletUnit.HideBullet(self)
	self._position.x = 0
	self._position.y = 100
	self._position.z = 0
end

function BattleBombBulletUnit.GetExplodePostion(self)
	return self._explodePos
end
