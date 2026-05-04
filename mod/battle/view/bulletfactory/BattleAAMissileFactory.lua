ys = ys or {}

local ys = ys
local UnitType = ys.Battle.BattleConst.UnitType
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleAAMissileFactory = singletonClass("BattleAAMissileFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleAAMissileFactory.__name = "BattleAAMissileFactory"

local BattleAAMissileFactory = ys.Battle.BattleAAMissileFactory

--- 创建防空导弹的BulletUnit View（复用TorpedoBullet类型）
--- 防空导弹在视觉层使用鱼雷实例（大型爆炸特效）
--- @return BattleTorpedoBullet
function BattleAAMissileFactory.MakeBullet(self)
	return ys.Battle.BattleTorpedoBullet.New()
end

--- 防空导弹命中回调
--- 防空导弹的核心机制：验证命中目标是否为追踪目标
--- 1. 没有追踪目标时（trackingTarget == -1）：走普通炮弹命中逻辑
--- 2. 有追踪目标时：验证命中单位UID是否匹配追踪目标UID，不匹配则忽略
--- 3. 匹配成功：播放命中特效、结算伤害、清理瞄准标记
---
--- @param targetUID number 命中单位UID
--- @param unitType number 单位类型
function BattleAAMissileFactory.onBulletHitFunc(self, targetUID, unitType)
	local bulletData = self:GetBulletData()
	local trackingTarget = bulletData:getTrackingTarget()

	-- 无追踪目标时走普通炮弹逻辑
	if trackingTarget == -1 then
		ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(self, targetUID, unitType)

		return
	end

	local bulletTemplate = bulletData:GetTemplate()
	local dataProxy = BattleAAMissileFactory.GetDataProxy()
	local hitUnitData

	-- 获取命中单位的UnitData
	if table.contains(AircraftUnitType, unitType) then
		hitUnitData = BattleAAMissileFactory.GetSceneMediator():GetAircraft(targetUID):GetUnitData()
	elseif table.contains(CharacterUnitType, unitType) then
		hitUnitData = BattleAAMissileFactory.GetSceneMediator():GetCharacter(targetUID):GetUnitData()
	end

	-- 验证命中目标是否为追踪目标，不匹配则忽略
	if not hitUnitData or not trackingTarget or hitUnitData:GetUniqueID() ~= trackingTarget:GetUniqueID() then
		return
	end

	ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

	-- 播放命中特效
	local hitFX, hitOffset = BattleAAMissileFactory.GetFXPool():GetFX(self:GetFXID())
	local hitPos = self:GetTf().localPosition

	pg.EffectMgr.GetInstance():PlayBattleEffect(hitFX, hitOffset:Add(hitPos), true)

	local isMiss, damageResult = dataProxy:HandleDamage(bulletData, hitUnitData)

	-- 穿透耗尽时清理瞄准标记并移除子弹
	if bulletData:GetPierceCount() <= 0 then
		bulletData:CleanAimMark()
		dataProxy:RemoveBulletUnit(bulletData:GetUniqueID())
	end
end

--- 防空导弹未命中回调（与命中相同）
function BattleAAMissileFactory.onBulletMissFunc(self)
	BattleAAMissileFactory.onBulletHitFunc(self)
end

--- 创建防空导弹的视觉模型
--- 敌方防空导弹显示预警圈
--- @param bulletView BattleBulletUnit View层子弹
--- @param spawnPos Vector3
function BattleAAMissileFactory.MakeModel(self, bulletView, spawnPos)
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

	-- 敌方防空导弹显示预警圈
	if bulletData:GetIFF() ~= dataProxy:GetFriendlyCode() and bulletTemplate.alert_fx ~= "" then
		bulletView:MakeAlert(self:GetFXPool():GetFX(bulletTemplate.alert_fx))
	end
end
