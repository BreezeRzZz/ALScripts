ys = ys or {}

local ys = ys

ys.Battle.BattleAntiSeaBulletFactory = singletonClass("BattleAntiSeaBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleAntiSeaBulletFactory.__name = "BattleAntiSeaBulletFactory"

local BattleAntiSeaBulletFactory = ys.Battle.BattleAntiSeaBulletFactory

function BattleAntiSeaBulletFactory.Ctor(self)
	BattleAntiSeaBulletFactory.super.Ctor(self)

	-- 定时器列表，用于战斗结束时停用所有追踪中的反海子弹
	self._tmpTimerList = {}
end

--- 停用所有正在追踪的反海子弹定时器
function BattleAntiSeaBulletFactory.NeutralizeBullet(self)
	for timerKey, timerID in pairs(self._tmpTimerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)

		self._tmpTimerList[timerKey] = nil
	end
end

--- 创建反海子弹（锁定海上单位，延迟后造成单体伤害）
--- 与防空子弹不同，反海子弹造成的是直接单体伤害（HandleDamage）
--- 而非范围伤害（HandleMeteoDamage）
---
--- 定时器流程：
--- 1. damageTimer：0.5秒延迟后执行伤害
--- 2. hitEffectTimer（仅当有发射特效时）：0.1秒间隔周期性播放命中特效
---
--- @param tf Transform 发射Transform
--- @param bullet BattleBulletUnit 反海子弹数据
--- @param spawnPos Vector3 生成位置
--- @param fireFXID string 发射特效ID
--- @param dir BattleConst.UnitDir 发射方向
function BattleAntiSeaBulletFactory.CreateBullet(self, tf, bullet, spawnPos, fireFXID, dir)
	local hitType = bullet:GetTemplate().hit_type
	local dataProxy = self:GetDataProxy()
	local directHitUnit = bullet:GetDirectHitUnit()

	if not directHitUnit then
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local targetUID = directHitUnit:GetUniqueID()
	local targetCharacter = self:GetSceneMediator():GetCharacter(targetUID)

	if not targetCharacter then
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local hitRange = hitType.range
	local damageTimer
	local hitEffectTimer

	-- 在目标附近播放周期性命中特效
	local function playHitEffect()
		if damageTimer then
			local effectPos
			local targetPos = targetCharacter:GetPosition():Clone()

			if directHitUnit:IsAlive() and targetCharacter then
				-- 目标存活：在目标位置附近随机偏移播放特效
				effectPos = targetPos:Add(Vector3(math.random(hitRange) - hitRange * 0.5, 0, math.random(hitRange) - hitRange * 0.5))
			else
				effectPos = targetPos
			end

			local hitFX, hitOffset = self:GetFXPool():GetFX(bullet:GetTemplate().hit_fx)

			pg.EffectMgr.GetInstance():PlayBattleEffect(hitFX, hitOffset:Add(effectPos), true)
		end
	end

	-- 伤害定时器到期：造成单体直接伤害并移除子弹
	local function onDamageTimerExpire()
		if directHitUnit:IsAlive() then
			dataProxy:HandleDamage(bullet, directHitUnit)
			dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
		end

		pg.TimeMgr.GetInstance():RemoveBattleTimer(damageTimer)

		self._tmpTimerList[damageTimer] = nil
		damageTimer = nil
	end

	-- 添加伤害定时器：0.5秒延迟
	damageTimer = pg.TimeMgr.GetInstance():AddBattleTimer("antiAirTimer", 0, 0.5, onDamageTimerExpire, true)
	self._tmpTimerList[damageTimer] = damageTimer

	if fireFXID ~= nil then
		-- 有发射特效：播放特效，并启动周期性命中特效定时器
		self:PlayFireFX(tf, bullet, spawnPos, fireFXID, dir, nil)

		hitEffectTimer = pg.TimeMgr.GetInstance():AddBattleTimer("showHitFXTimer", -1, 0.1, playHitEffect, true)

		self._tmpTimerList[hitEffectTimer] = hitEffectTimer

		playHitEffect()
	else
		-- 无发射特效：立即造成伤害并移除
		dataProxy:HandleDamage(bullet, directHitUnit)
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
	end
end
