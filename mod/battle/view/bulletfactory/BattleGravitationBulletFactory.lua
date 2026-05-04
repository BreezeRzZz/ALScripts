ys = ys or {}

local ys = ys

ys.Battle.BattleGravitationBulletFactory = singletonClass("BattleGravitationBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleGravitationBulletFactory.__name = "BattleGravitationBulletFactory"

local BattleGravitationBulletFactory = ys.Battle.BattleGravitationBulletFactory

function BattleGravitationBulletFactory.Ctor(self)
	BattleGravitationBulletFactory.super.Ctor(self)
end

--- 创建引力弹的BulletUnit View（复用TorpedoBullet类型）
--- 引力弹在视觉层使用鱼雷实例，因为二者都是大型爆炸特效
--- @return BattleTorpedoBullet
function BattleGravitationBulletFactory.MakeBullet(self)
	return ys.Battle.BattleTorpedoBullet.New()
end

--- 引力弹命中/爆炸回调
--- 生成持续圆形区域（LastingColumnArea），区域内单位受到以下效果：
--- 1. 引力Buff（buff_id / buff_level）
--- 2. 持续伤害（HandleDamage，除非noIntervalDMG）
--- 3. 向心力（SetUncontrollableSpeed）：将单位向爆炸中心吸引
--- 4. 爆炸结束伤害（exploDMG + knockBack击退）
---
--- 视觉：生成持续区域特效（areaFX），结束时播放爆炸特效
--- @param targetUID number
--- @param unitType number
function BattleGravitationBulletFactory.onBulletHitFunc(self, targetUID, unitType)
	local bulletView = self:GetBulletData()

	-- 穿透次数耗尽时不触发
	if bulletView:GetPierceCount() <= 0 then
		return
	end

	local hitType = bulletView:GetTemplate().hit_type
	local dataProxy = BattleGravitationBulletFactory.GetDataProxy()
	local bulletData = self:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()

	ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

	local diveFilter = bulletData:GetDiveFilter()
	local centerPos = bulletData:GetPosition():Clone()
	local extraParam = bulletData:GetTemplate().extra_param
	local buffID = extraParam.buff_id
	local buffLevel = extraParam.buff_level or 1

	-- 区域持续期间每帧回调：添加Buff、造成伤害、施加向心力
	local function onAreaTick(unitList)
		if bulletData:CanDealDamage() then
			for index, unitEntry in ipairs(unitList) do
				if unitEntry.Active then
					local unitData = BattleGravitationBulletFactory:GetSceneMediator():GetCharacter(unitEntry.UID):GetUnitData()
					local buffUnit = ys.Battle.BattleBuffUnit.New(buffID, buffLevel)

					unitData:AddBuff(buffUnit)

					-- 持续伤害（可选关闭）
					if not extraParam.noIntervalDMG then
						dataProxy:HandleDamage(bulletData, unitData)
					end

					-- 向心力：将单位向爆炸中心吸引
					-- force控制吸引力大小，小于引力距离时使用弱吸引力
					local gravForce = extraParam.force or 0.1
					local toCenter = pg.Tool.FilterY(centerPos - unitData:GetPosition())

					if gravForce > toCenter.magnitude then
						unitData:SetUncontrollableSpeed(toCenter, 0.001, 1e-06)
					else
						unitData:SetUncontrollableSpeed(toCenter, gravForce, 1e-07)
					end
				end
			end

			bulletData:DealDamage()
		end
	end

	-- 单位离开区域：清除不受控速度并移除Buff
	local function onExitArea(unitEntry)
		if unitEntry.Active then
			local unitData = BattleGravitationBulletFactory:GetSceneMediator():GetCharacter(unitEntry.UID):GetUnitData()

			unitData:ClearUncontrollableSpeed()
			unitData:RemoveBuff(buffID)
		end
	end

	-- 区域结束时：最后爆炸伤害 + 击退
	local function onAreaEnd(unitList)
		local exploDMG = extraParam.exploDMG
		local knockBack = extraParam.knockBack

		for index, unitEntry in ipairs(unitList) do
			if unitEntry.Active then
				local unitData = BattleGravitationBulletFactory:GetSceneMediator():GetCharacter(unitEntry.UID):GetUnitData()
				local isFiltered = false
				local oxyState = unitData:GetCurrentOxyState()

				-- 检查潜水状态是否在过滤列表中
				for filterIndex, filterState in ipairs(diveFilter) do
					if oxyState == filterState then
						isFiltered = true
					end
				end

				if not isFiltered then
					-- 爆炸直伤
					dataProxy:HandleDirectDamage(unitData, exploDMG, bulletData)

					if unitData:IsAlive() then
						local knockBackDir = pg.Tool.FilterY(unitData:GetPosition() - centerPos)

						-- 击退效果（knockBack不为false时）
						if knockBack ~= false then
							unitData:SetUncontrollableSpeed(knockBackDir, 1, 0.2, 6)
						end

						unitData:RemoveBuff(buffID)
					end
				end
			end
		end

		-- 播放爆炸结束特效
		local endFX, endOffset = BattleGravitationBulletFactory.GetFXPool():GetFX(self:GetMissFXID())

		pg.EffectMgr.GetInstance():PlayBattleEffect(endFX, endOffset:Add(centerPos), true)
		dataProxy:RemoveBulletUnit(bulletData:GetUniqueID())
	end

	dataProxy:SpawnLastingColumnArea(bulletData:GetEffectField(), bulletData:GetIFF(), pg.Tool.FilterY(centerPos), hitType.range, hitType.time, onAreaTick, onExitArea, false, self:GetFXID(), onAreaEnd, true):SetDiveFilter(diveFilter)
end

--- 引力弹未命中回调（与命中相同，都是碰撞即触发）
function BattleGravitationBulletFactory.onBulletMissFunc(self)
	BattleGravitationBulletFactory.onBulletHitFunc(self)
end

--- 创建引力弹的视觉模型
--- 敌方引力弹显示预警圈
--- @param bulletView BattleBulletUnit View层子弹
--- @param spawnPos Vector3
function BattleGravitationBulletFactory.MakeModel(self, bulletView, spawnPos)
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

	-- 敌方引力弹显示预警圈
	if bulletData:GetIFF() ~= dataProxy:GetFriendlyCode() and bulletTemplate.alert_fx ~= "" then
		bulletView:MakeAlert(self:GetFXPool():GetFX(bulletTemplate.alert_fx))
	end
end
