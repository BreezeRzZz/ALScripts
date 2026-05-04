ys = ys or {}

local ys = ys

ys.Battle.BattleAntiAirBulletFactory = singletonClass("BattleAntiAirBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleAntiAirBulletFactory.__name = "BattleAntiAirBulletFactory"

local BattleAntiAirBulletFactory = ys.Battle.BattleAntiAirBulletFactory

function BattleAntiAirBulletFactory.Ctor(self)
	BattleAntiAirBulletFactory.super.Ctor(self)

	-- 定时器列表，key和value均为定时器ID
	-- 战斗结束时通过NeutralizeBullet清理所有活跃定时器
	self._tmpTimerList = {}
end

--- 停用所有正在追踪的防空子弹定时器
function BattleAntiAirBulletFactory.NeutralizeBullet(self)
	for timerKey, timerID in pairs(self._tmpTimerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)

		self._tmpTimerList[timerKey] = nil
	end
end

--- 创建防空子弹（重写父类CreateBullet以添加追踪逻辑）
--- 防空子弹锁定一个敌机目标，在延迟后于目标位置生成爆炸区域
--- 使用两个定时器协作：
--- 1. antiAirTimer（循环，0.5s间隔）：追踪目标存活状态，目标死亡时触发爆炸
--- 2. 爆炸在目标位置生成圆形柱体区域，对区域内所有可访问的飞机造成伤害
---
--- 视觉效果：发射特效播放完毕后，在目标附近随机位置播放命中特效（hit_fx）
--- @param tf Transform 发射Transform
--- @param bullet BattleBulletUnit 防空子弹数据
--- @param spawnPosition Vector3 生成位置
--- @param fireFXID string 发射特效ID
--- @param direction BattleConst.UnitDir 发射方向
function BattleAntiAirBulletFactory.CreateBullet(self, tf, bullet, spawnPosition, fireFXID, direction)
	local hitType = bullet:GetTemplate().hit_type
	local dataProxy = self:GetDataProxy()
	local directHitUnit = bullet:GetDirectHitUnit()

	if not directHitUnit then
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local targetUID = directHitUnit:GetUniqueID()
	local targetAircraft = self:GetSceneMediator():GetAircraft(targetUID)

	if targetAircraft == nil then
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local hitPos = targetAircraft:GetPosition():Clone()
	local hitRange = hitType.range

	-- 区域内碰撞回调：收集所有可访问的飞机，进行范围伤害
	local function onAreaCollide(unitList)
		local hitUnits = {}

		for index, unitEntry in ipairs(unitList) do
			if unitEntry.Active then
				local aircraft = self:GetSceneMediator():GetAircraft(unitEntry.UID)

				if aircraft then
					local aircraftUnit = aircraft:GetUnitData()

					if aircraftUnit:IsVisitable() then
						hitUnits[#hitUnits + 1] = aircraftUnit
					end
				end
			end
		end

		dataProxy:HandleMeteoDamage(bullet, hitUnits)
	end

	-- 最终爆炸：生成区域伤害并移除子弹
	local function finalExplosion()
		dataProxy:SpawnColumnArea(bullet:GetEffectField(), bullet:GetIFF(), hitPos, hitRange, hitType.time, onAreaCollide)
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
	end

	-- 在目标附近随机位置播放命中特效
	local function playHitEffect()
		local effectPos

		if directHitUnit:IsAlive() and targetAircraft then
			-- 目标存活时：在目标当前位置为基础做随机偏移
			effectPos = targetAircraft:GetPosition():Clone():Add(Vector3(math.random(hitRange) - hitRange * 0.5, 0, math.random(hitRange) - hitRange * 0.5))
			hitPos = effectPos
		else
			-- 目标已死亡：使用最后记录的命中位置
			effectPos = hitPos
		end

		local hitFX, hitOffset = self:GetFXPool():GetFX(bullet:GetTemplate().hit_fx)

		pg.EffectMgr.GetInstance():PlayBattleEffect(hitFX, hitOffset:Add(effectPos), true)
	end

	local antiAirTimer
	local onFireComplete

	-- 主逻辑：有发射特效则先播放特效，否则直接爆炸
	local function main()
		if fireFXID == nil then
			finalExplosion()
		else
			self:PlayFireFX(tf, bullet, spawnPosition, fireFXID, direction, onFireComplete)
		end
	end

	-- 发射特效完成回调：如果定时器仍有效则播放命中特效并爆炸
	function onFireComplete()
		if self._tmpTimerList[antiAirTimer] ~= nil then
			main()
			playHitEffect()
		else
			finalExplosion()
		end
	end

	-- 定时器到期回调：清理定时器（定时器被RemoveBattleTimer触发）
	local function onTimerEnd()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(antiAirTimer)

		self._tmpTimerList[antiAirTimer] = nil
		antiAirTimer = nil
	end

	-- 添加循环定时器：0.5秒间隔检查目标状态，目标死亡时触发onTimerEnd
	antiAirTimer = pg.TimeMgr.GetInstance():AddBattleTimer("antiAirTimer", -1, 0.5, onTimerEnd, true)
	self._tmpTimerList[antiAirTimer] = antiAirTimer

	main()
end
