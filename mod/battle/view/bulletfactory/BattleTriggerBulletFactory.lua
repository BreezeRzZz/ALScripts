ys = ys or {}

local ys = ys

ys.Battle.BattleTriggerBulletFactory = singletonClass("BattleTriggerBulletFactory", ys.Battle.BattleBombBulletFactory)
ys.Battle.BattleTriggerBulletFactory.__name = "BattleTriggerBulletFactory"

local BattleTriggerBulletFactory = ys.Battle.BattleTriggerBulletFactory

function BattleTriggerBulletFactory.Ctor(self)
	BattleTriggerBulletFactory.super.Ctor(self)
end

--- 触发炸弹超出范围回调
--- 与普通炸弹不同，触发炸弹使用 SpawnTriggerColumnArea（触发型区域）
--- 而非 SpawnColumnArea（持续伤害区域）
--- 额外特性：multy 参数控制每个单位受到多少次伤害判定
---   - 通过 while 循环重复造成伤害，直到目标死亡或达到 multy 次数
---
--- @param bullet BattleBulletUnit 炸弹子弹数据
function BattleTriggerBulletFactory.OutRangeFunc(bullet)
	local bulletTemplate = bullet:GetTemplate()
	local hitType = bulletTemplate.hit_type
	local multy = bulletTemplate.extra_param.multy or 1
	local dataProxy = BattleTriggerBulletFactory.GetDataProxy()
	local diveFilter = bullet:GetDiveFilter()
	local areaData

	-- 触发区域碰撞回调：每个进入区域的单位受到 multy 次伤害
	local function onAreaTrigger(unitList)
		local decay = hitType.decay

		if decay then
			areaData:UpdateDistanceInfo()
		end

		for index, unitEntry in ipairs(unitList) do
			if unitEntry.Active then
				local uid = unitEntry.UID
				local decayFactor = 0

				if decay then
					decayFactor = areaData:GetDistance(uid) / (hitType.range * 0.5) * decay
				end

				local unitData = BattleTriggerBulletFactory.GetSceneMediator():GetCharacter(uid):GetUnitData()
				local damageCount = 0

				-- 重复造成伤害直到目标死亡或达到multy次数
				while unitData:IsAlive() and damageCount < multy do
					dataProxy:HandleDamage(bullet, unitData, decayFactor)

					damageCount = damageCount + 1
				end
			end
		end

		ys.Battle.PlayBattleSFX(bullet:GetHitSFX())
		dataProxy:SpawnEffect(bulletTemplate.hit_fx, bullet:GetExplodePostion())
	end

	areaData = dataProxy:SpawnTriggerColumnArea(bullet:GetEffectField(), bullet:GetIFF(), bullet:GetExplodePostion(), hitType.range, hitType.time, false, bulletTemplate.miss_fx, onAreaTrigger)

	areaData:SetDiveFilter(diveFilter)
	dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
end

--- 触发炸弹命中回调（空实现，伤害逻辑在OutRangeFunc）
function BattleTriggerBulletFactory.onBulletHitFunc(self, targetUID, unitType)
	return
end

--- 触发炸弹预警圈（空实现，触发炸弹不需要预警圈）
function BattleTriggerBulletFactory.CreateBulletAlert(self)
	return
end
