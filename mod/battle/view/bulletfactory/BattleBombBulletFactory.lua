ys = ys or {}

local ys = ys

ys.Battle.BattleBombBulletFactory = singletonClass("BattleBombBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleBombBulletFactory.__name = "BattleBombBulletFactory"

local BattleBombBulletFactory = ys.Battle.BattleBombBulletFactory

function BattleBombBulletFactory.Ctor(self)
	BattleBombBulletFactory.super.Ctor(self)
end

--- 炸弹超出范围回调（炸弹触地/到达目标爆炸点）
--- 炸弹的伤害结算主要在此完成，支持两种爆炸模式：
--- 1. directDMG 模式（持续区域伤害）：生成持续区域，进入区域的单位
---    被添加Buff并受到直伤；离开区域移除Buff；区域结束时清理
--- 2. 普通爆炸模式（一次性范围伤害）：圆形区域伤害 + 距离衰减，
---    可选友军伤害（friendlyFire）和无差别伤害（indiscriminate）
--- @param bullet BattleBombBullet 炸弹子弹数据
function BattleBombBulletFactory.OutRangeFunc(bullet)
	local bulletTemplate = bullet:GetTemplate()
	local hitType = bulletTemplate.hit_type
	local dataProxy = BattleBombBulletFactory.GetDataProxy()
	local extraParam = bulletTemplate.extra_param
	local diveFilter = bullet:GetDiveFilter()
	local triggerData = {
		_bullet = bullet,
		equipIndex = bullet:GetWeapon():GetEquipmentIndex(),
		bulletTag = bullet:GetExtraTag()
	}

	-- 炸弹爆炸Buff触发
	bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BOMB_BULLET_BANG, triggerData)

	if extraParam.directDMG then
		-- === 直接伤害模式：持续区域 + Buff ===
		local buffID = extraParam.buff_id
		local buffLevel = extraParam.buff_level or 1
		local areaFX = extraParam.area_FX or bulletTemplate.hit_fx

		-- 单位进入持续区域时：添加Buff并造成直伤
		local function onEnterArea(unitList)
			if bullet:CanDealDamage() then
				for index, unitEntry in ipairs(unitList) do
					if unitEntry.Active then
						local uid = unitEntry.UID
						local unitData = BattleBombBulletFactory.GetSceneMediator():GetCharacter(uid):GetUnitData()
						local buffUnit = ys.Battle.BattleBuffUnit.New(buffID, buffLevel)

						unitData:AddBuff(buffUnit)
						dataProxy:HandleDirectDamage(unitData, extraParam.directDMG, bullet)
					end
				end

				bullet:DealDamage()
			end
		end

		-- 单位离开持续区域时：移除Buff
		local function onExitArea(unitEntry)
			if unitEntry.Active then
				BattleBombBulletFactory:GetSceneMediator():GetCharacter(unitEntry.UID):GetUnitData():RemoveBuff(buffID)
			end
		end

		-- 持续区域消失时：清理还存活单位的Buff并移除子弹
		local function onAreaEnd(unitList)
			for index, unitEntry in ipairs(unitList) do
				if unitEntry.Active then
					local unitData = BattleBombBulletFactory:GetSceneMediator():GetCharacter(unitEntry.UID):GetUnitData()

					if unitData:IsAlive() then
						unitData:RemoveBuff(buffID)
					end
				end
			end

			dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
		end

		dataProxy:SpawnLastingColumnArea(bullet:GetEffectField(), bullet:GetIFF(), bullet:GetExplodePostion(), hitType.range, hitType.time, onEnterArea, onExitArea, false, areaFX, onAreaEnd, true):SetDiveFilter(diveFilter)
		bullet:HideBullet()
	else
		-- === 普通爆炸模式：一次性范围伤害 ===
		local areaInfo

		-- 爆炸区域内每帧伤害处理（支持距离衰减）
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
						decayFactor = areaInfo:GetDistance(uid) / (hitType.range * 0.5) * decay
					end

					local unitData = BattleBombBulletFactory.GetSceneMediator():GetCharacter(uid):GetUnitData()

					dataProxy:HandleDamage(bullet, unitData, decayFactor)
				end
			end
		end

		areaInfo = dataProxy:SpawnColumnArea(bullet:GetEffectField(), bullet:GetIFF(), bullet:GetExplodePostion(), hitType.range, hitType.time, onAreaTick)

		areaInfo:SetDiveFilter(diveFilter)

		-- 友军伤害：对敌方阵营也生成爆炸区域
		if extraParam.friendlyFire then
			dataProxy:SpawnColumnArea(bullet:GetEffectField(), dataProxy.GetOppoSideCode(bullet:GetIFF()), bullet:GetExplodePostion(), hitType.range, hitType.time, onAreaTick):SetDiveFilter(diveFilter)
		end

		areaInfo:SetIndiscriminate(extraParam.indiscriminate)
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
	end
end

--- 创建炸弹类型的BulletUnit View
--- @return BattleBombBullet
function BattleBombBulletFactory.MakeBullet(self)
	return ys.Battle.BattleBombBullet.New()
end

--- 炸弹碰撞命中回调
--- 仅播放命中特效和音效，实际爆炸伤害逻辑在 OutRangeFunc 中
--- @param targetUID number
--- @param unitType number
function BattleBombBulletFactory.onBulletHitFunc(self, targetUID, unitType)
	local bulletData = self:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()

	ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

	local hitFX, hitOffset = BattleBombBulletFactory.GetFXPool():GetFX(self:GetFXID())
	local hitPos = pg.Tool.FilterY(bulletData:GetPosition())

	pg.EffectMgr.GetInstance():PlayBattleEffect(hitFX, hitPos:Add(hitOffset), true)
end

--- 炸弹未命中回调（空实现，炸弹在OutRangeFunc中处理一切）
function BattleBombBulletFactory.onBulletMissFunc()
	return
end

--- 创建炸弹的视觉模型
--- 额外检查：爆炸位置超出战场前方边界（maxZ + 3）则直接移除
--- 敌方炸弹首次出现时创建预警圈特效
--- @param bulletView BattleBulletUnit View层子弹
--- @param position Vector3 生成位置
function BattleBombBulletFactory.MakeModel(self, bulletView, position)
	local bulletData = bulletView:GetBulletData()
	local explodePos = bulletData:GetExplodePostion()
	local minZ, maxZ, minX, maxX = self:GetDataProxy():GetTotalBounds()

	-- 爆炸位置超出战场前方边界则不移除（避免在不可见位置生成无效子弹）
	if explodePos.z > maxZ + 3 then
		self:GetDataProxy():RemoveBulletUnit(bulletData:GetUniqueID())

		return
	end

	local bulletTemplate = bulletData:GetTemplate()

	if not self:GetBulletPool():InstBullet(bulletData:GetModleID(), function(instGO)
		bulletView:AddModel(instGO)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(position)

	-- 敌方炸弹首次出现且未生成过预警圈时，创建预警圈
	if bulletData:GetIFF() ~= self:GetDataProxy():GetFriendlyCode() and bulletData:GetExist() and bulletTemplate.alert_fx ~= "" then
		BattleBombBulletFactory.CreateBulletAlert(bulletData)
	end

	bulletData:SetExist(true)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end

--- 创建炸弹预警圈特效（地面红色/黄色圆圈）
--- 根据 hit_type.range 缩放预警圈大小
--- 支持 pg.effect_offset 配置中的 y_scale 选项（用于全屏特效的Y轴缩放）
--- @param bulletData BattleBombBullet 炸弹子弹数据
function BattleBombBulletFactory.CreateBulletAlert(bulletData)
	local alertRange = bulletData:GetTemplate().hit_type.range
	local alertFXID = bulletData:GetTemplate().alert_fx
	local alertFX = ys.Battle.BattleFXPool.GetInstance():GetFX(alertFXID)
	local alertTF = alertFX.transform
	local yScale = 0
	local effectOffsetConfig = pg.effect_offset

	-- 某些预警特效需要Y轴也参与缩放（如全屏覆盖型预警）
	if effectOffsetConfig[alertFXID] and effectOffsetConfig[alertFXID].y_scale == true then
		yScale = alertRange
	end

	alertTF.localScale = Vector3(alertRange, yScale, alertRange)

	pg.EffectMgr.GetInstance():PlayBattleEffect(alertFX, bulletData:GetExplodePostion())
end
