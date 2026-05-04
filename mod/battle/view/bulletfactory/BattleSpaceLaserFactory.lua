ys = ys or {}

local ys = ys
local BattleSpaceLaserFactory = singletonClass("BattleSpaceLaserFactory", ys.Battle.BattleBulletFactory)

BattleSpaceLaserFactory.__name = "BattleSpaceLaserFactory"
ys.Battle.BattleSpaceLaserFactory = BattleSpaceLaserFactory

--- 创建天基激光的BulletUnit View
--- 天基激光使用特殊的 BattleLaserArea 而非普通 BulletUnit
--- @return BattleLaserArea
function BattleSpaceLaserFactory.MakeBullet(self)
	return ys.Battle.BattleLaserArea.New()
end

--- 创建天基激光的视觉模型
--- 天基激光的特殊之处：
--- 1. 使用 InstFX（而非 InstBullet）来实例化模型 —— 激光是持续特效而非飞行的子弹
--- 2. 碰撞回调内置伤害逻辑：检测与Character的碰撞，受 hitInterval 控制伤害频率
--- 3. 支持潜水过滤：特定氧气状态（水下/水面）的单位不受伤
--- 4. Alert阶段（IsAlert）不造成伤害
---
--- @param bulletView BattleLaserArea View层激光
--- @param spawnPos Vector3 生成位置
function BattleSpaceLaserFactory.MakeModel(self, bulletView, spawnPos)
	local bulletData = bulletView:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()
	local dataProxy = self:GetDataProxy()
	local instFX = self:GetBulletPool():InstFX(bulletData:GetModleID())

	if instFX then
		bulletView:AddModel(instFX)
	else
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

	-- 碰撞时的伤害处理函数
	local function onCollide(laserView, colliderUID, unitType)
		local laserData = laserView:GetBulletData()
		local laserTemplate = laserData:GetTemplate()
		local diveFilter = laserData:GetDiveFilter()
		local collidedList, lastHitTime = laserData:GetCollidedList()

		-- Alert预警阶段不造成伤害
		if laserData:IsAlert() then
			return
		end

		-- 伤害频率控制：距上次命中时间必须 >= hitInterval
		local lastHitTimestamp = lastHitTime[colliderUID] or 0

		if pg.TimeMgr.GetInstance():GetCombatTime() < lastHitTimestamp + laserData:GetHitInterval() then
			return
		end

		local unitData = BattleSpaceLaserFactory:GetSceneMediator():GetCharacter(colliderUID):GetUnitData()

		if unitData:GetCldData().Active then
			local isFiltered = false
			local oxyState = unitData:GetCurrentOxyState()

			-- 检查潜水过滤
			for filterIndex, filterState in ipairs(diveFilter) do
				if oxyState == filterState then
					isFiltered = true
				end
			end

			if not isFiltered then
				dataProxy:HandleDamage(laserData, unitData)
			end
		end

		-- 记录本次命中时间
		lastHitTime[colliderUID] = pg.TimeMgr.GetInstance():GetCombatTime()
	end

	-- 碰撞结束回调（空实现）
	local function onCollideEnd(unitEntry)
		return
	end

	bulletView:SetSpawn(spawnPos)
	bulletView:SetFXFunc(onCollide, onCollideEnd)
	self:GetSceneMediator():AddBullet(bulletView)
end

--- 天基激光超范围回调
--- 执行生命周期结束回调（用于清理激光特效），然后从数据代理移除
function BattleSpaceLaserFactory.OutRangeFunc(self)
	self:ExecuteLifeEndCallback()
	BattleSpaceLaserFactory.GetDataProxy():RemoveBulletUnit(self:GetUniqueID())
end
