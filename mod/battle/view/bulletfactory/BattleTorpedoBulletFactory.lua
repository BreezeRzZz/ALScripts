ys = ys or {}

local ys = ys

ys.Battle.BattleTorpedoBulletFactory = singletonClass("BattleTorpedoBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleTorpedoBulletFactory.__name = "BattleTorpedoBulletFactory"

local BattleTorpedoBulletFactory = ys.Battle.BattleTorpedoBulletFactory

function BattleTorpedoBulletFactory.Ctor(self)
	BattleTorpedoBulletFactory.super.Ctor(self)
end

--- 创建鱼雷类型的BulletUnit View
--- @return BattleTorpedoBullet
function BattleTorpedoBulletFactory.MakeBullet(self)
	return ys.Battle.BattleTorpedoBullet.New()
end

--- 鱼雷命中/爆炸回调
--- 鱼雷的 hit 和 miss 共用同一逻辑（碰撞即爆炸，没有miss概念）
--- 爆炸区域支持两种形状：
--- 1. 圆形柱体（hit_type.range 存在时）
--- 2. 矩形盒体（hit_type.width + hit_type.height 存在时）
--- 伤害支持距离衰减（hit_type.decay）
--- @param targetUID number 未使用（鱼雷不依赖单个命中目标，而是范围爆炸）
--- @param unitType number 未使用
function BattleTorpedoBulletFactory.onBulletHitFunc(self, targetUID, unitType)
	local hitType = self:GetBulletData():GetTemplate().hit_type
	local dataProxy = BattleTorpedoBulletFactory.GetDataProxy()
	local bulletData = self:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()

	ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

	local triggerData = {
		_bullet = bulletData,
		equipIndex = bulletData:GetWeapon():GetEquipmentIndex(),
		bulletTag = bulletData:GetExtraTag()
	}

	-- 鱼雷爆炸前Buff触发
	bulletData:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_TORPEDO_BULLET_BANG, triggerData)

	local diveFilter = bulletData:GetDiveFilter()
	local areaInfo

	-- 爆炸区域内的每帧伤害处理
	local function onAreaTick(unitList)
		local decay = hitType.decay

		if decay then
			areaInfo:UpdateDistanceInfo()
		end

		for index, unitEntry in ipairs(unitList) do
			if unitEntry.Active then
				local uid = unitEntry.UID
				local decayFactor = 0

				if decay then
					-- 距离衰减：距中心越远伤害越低
					decayFactor = areaInfo:GetDistance(uid) / (hitType.range * 0.5) * decay
				end

				local unitData = BattleTorpedoBulletFactory:GetSceneMediator():GetCharacter(uid):GetUnitData()

				dataProxy:HandleDamage(bulletData, unitData, decayFactor)
			end
		end
	end

	-- 根据hit_type选择圆形或矩形爆炸区域
	if hitType.range then
		areaInfo = dataProxy:SpawnColumnArea(bulletData:GetEffectField(), bulletData:GetIFF(), pg.Tool.FilterY(self:GetPosition():Clone()), hitType.range, hitType.time, onAreaTick)
	else
		areaInfo = dataProxy:SpawnCubeArea(bulletData:GetEffectField(), bulletData:GetIFF(), pg.Tool.FilterY(self:GetPosition():Clone()), hitType.width, hitType.height, hitType.time, onAreaTick)
	end

	areaInfo:SetDiveFilter(diveFilter)

	-- 播放爆炸特效
	local hitFX, hitOffset = BattleTorpedoBulletFactory.GetFXPool():GetFX(self:GetFXID())
	local hitPos = self:GetTf().localPosition

	pg.EffectMgr.GetInstance():PlayBattleEffect(hitFX, hitOffset:Add(hitPos), true)

	-- 穿透耗尽时移除子弹
	if bulletData:GetPierceCount() <= 0 then
		dataProxy:RemoveBulletUnit(bulletData:GetUniqueID())
	end
end

--- 鱼雷脱靶回调（与命中相同，碰撞即爆炸）
function BattleTorpedoBulletFactory.onBulletMissFunc(self)
	BattleTorpedoBulletFactory.onBulletHitFunc(self)
end

--- 创建鱼雷的视觉模型
--- 敌方鱼雷会额外生成预警圈特效（alert_fx），提醒玩家规避
--- @param bulletView BattleBulletUnit View层子弹
--- @param spawnPos Vector3 生成位置
function BattleTorpedoBulletFactory.MakeModel(self, bulletView, spawnPos)
	local bulletData = bulletView:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()
	local dataProxy = self:GetDataProxy()

	if not self:GetBulletPool():InstBullet(bulletData:GetModleID(), function(instGO)
		bulletView:AddModel(instGO)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(spawnPos)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)

	-- 敌方鱼雷显示预警圈
	if bulletData:GetIFF() ~= dataProxy:GetFriendlyCode() and bulletTemplate.alert_fx ~= "" then
		bulletView:MakeAlert(self:GetFXPool():GetFX(bulletTemplate.alert_fx))
	end
end
