ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local math = math

local BattleShotgunEmitter = class("BattleShotgunEmitter", ys.Battle.BattleBulletEmitter)

ys.Battle.BattleShotgunEmitter = BattleShotgunEmitter
BattleShotgunEmitter.__name = "BattleShotgunEmitter"

--- @class BattleShotgunEmitter : BattleBulletEmitter
--- @param self BattleShotgunEmitter
--- @param host BattleUnit 宿主单位
--- @param tmpData table 弹幕模板数据
--- @param emitterType string 发射器类型
--- 散弹发射器：覆盖迭代方式为无延迟原始迭代（PrimalIteration = nonDelayPrimalIteration）
function BattleShotgunEmitter.Ctor(self, host, tmpData, emitterType)
	ys.Battle.BattleShotgunEmitter.super.Ctor(self, host, tmpData, emitterType)

	self.PrimalIteration = self._nonDelayPrimalIteration
end

--- 开火：记录角度散布范围后调用父类Fire
--- @param self BattleShotgunEmitter
--- @param target BattleUnit 目标单位
--- @param dir Vector3 发射方向
--- @param angleRange number 散弹散布角度范围
function BattleShotgunEmitter.Fire(self, target, dir, angleRange)
	self._angleRange = angleRange

	ys.Battle.BattleShotgunEmitter.super.Fire(self, target, dir)
end

--- 生成散弹子弹：根据弹幕偏移和随机角度生成每颗子弹
--- @param self BattleShotgunEmitter
function BattleShotgunEmitter.GenerateBullet(self)
	-- 获取当前迭代序号对应的弹幕方向数据
	local barrageData = self._convertedDirBarrage[self._primalCounter]
	local offsetX = barrageData.OffsetX

	self._delay = barrageData.Delay

	-- 计算该子弹的随机散布角度
	local angleDelta

	if self._isRandomAngle then
		-- 双倍随机：先0-1随机决定中心偏移方向，再乘以随机大小的散布
		angleDelta = (math.random() - 0.5) * math.random(self._angleRange) - self._angleRange / 2
	else
		-- 均匀散布在 [-angleRange/2, angleRange/2] 范围内
		angleDelta = math.random(self._angleRange) - self._angleRange / 2
	end

	-- 调用spawnFunc生成子弹，传入偏移量、散布角度等信息
	self._spawnFunc(offsetX, barrageData.OffsetZ, angleDelta, self._offsetPriority, self._target, self._primalCounter)
	self:Interation()
end
