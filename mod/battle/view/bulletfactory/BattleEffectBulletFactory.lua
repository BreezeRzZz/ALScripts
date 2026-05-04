ys = ys or {}

local ys = ys

ys.Battle.BattleEffectBulletFactory = singletonClass("BattleEffectBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleEffectBulletFactory.__name = "BattleEffectBulletFactory"

local BattleEffectBulletFactory = ys.Battle.BattleEffectBulletFactory

function BattleEffectBulletFactory.Ctor(self)
	BattleEffectBulletFactory.super.Ctor(self)
end

--- 创建EffectBullet的BulletUnit View（复用TorpedoBullet类型）
--- EffectBullet在数据层表现为区域效果子弹，但视觉层使用鱼雷的实例
--- @return BattleTorpedoBullet
function BattleEffectBulletFactory.MakeBullet(self)
	return ys.Battle.BattleTorpedoBullet.New()
end

--- EffectBullet命中回调
--- 非Flare类型（照明弹）时生成区域效果（spawnArea）
--- 播放命中特效和音效
--- @param targetUID number
--- @param unitType number
function BattleEffectBulletFactory.onBulletHitFunc(self, targetUID, unitType)
	local dataProxy = BattleEffectBulletFactory.GetDataProxy()
	local bulletData = self:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()

	ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

	-- Flare类型（照明弹）不生成区域效果
	if not bulletData:IsFlare() then
		bulletData:spawnArea()
	end

	local hitFX, hitOffset = BattleEffectBulletFactory.GetFXPool():GetFX(self:GetFXID())
	local hitPos = self:GetTf().localPosition

	pg.EffectMgr.GetInstance():PlayBattleEffect(hitFX, hitOffset:Add(hitPos), true)

	-- 穿透耗尽移除
	if bulletData:GetPierceCount() <= 0 then
		dataProxy:RemoveBulletUnit(bulletData:GetUniqueID())
	end
end

--- EffectBullet未命中回调（与命中相同）
function BattleEffectBulletFactory.onBulletMissFunc(self)
	BattleEffectBulletFactory.onBulletHitFunc(self)
end

--- 创建EffectBullet的视觉模型
--- @param bulletView BattleBulletUnit View层子弹
--- @param spawnPos Vector3
function BattleEffectBulletFactory.MakeModel(self, bulletView, spawnPos)
	local bulletTemplate = bulletView:GetBulletData():GetTemplate()
	local dataProxy = self:GetDataProxy()

	if not self:GetBulletPool():InstBullet(bulletView:GetModleID(), function(instGO)
		bulletView:AddModel(instGO)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(spawnPos)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end
