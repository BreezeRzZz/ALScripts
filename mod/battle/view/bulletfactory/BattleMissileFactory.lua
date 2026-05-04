ys = ys or {}

local ys = ys
local BattleMissileFactory = singletonClass("BattleMissileFactory", ys.Battle.BattleBombBulletFactory)

BattleMissileFactory.__name = "BattleMissileFactory"
ys.Battle.BattleMissileFactory = BattleMissileFactory

--- 创建导弹的视觉模型
--- 导弹继承自BombBulletFactory（复用炸弹的爆炸逻辑），但在模型实例化上有区别：
--- 1. 使用 InstFX 而非 InstBullet 来实例化模型 —— 导弹使用特效类型的资源
--- 2. 命中/未命中回调都设为 onBulletHitFunc（导弹碰撞即爆炸）
--- @param bulletView BattleBulletUnit View层导弹
--- @param spawnPos Vector3 生成位置
function BattleMissileFactory.MakeModel(self, bulletView, spawnPos)
	local bulletData = bulletView:GetBulletData()
	local instFX = self:GetBulletPool():InstFX(bulletView:GetModleID())

	if instFX then
		bulletView:AddModel(instFX)
	else
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(spawnPos)
	-- 导弹的碰撞和脱靶都触发命中爆炸（碰撞即爆）
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletHitFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end

--- 创建导弹预警圈特效
--- 仅在敌方导弹且alert_fx非空时创建
--- 与Bomb的预警圈逻辑相同，但额外检查 IFF（友方导弹不显示预警）
--- @param bulletData BattleBulletUnit 导弹子弹数据
function BattleMissileFactory.CreateBulletAlert(bulletData)
	local bulletTemplate = bulletData:GetTemplate()

	-- 友方导弹不显示预警
	if bulletData:GetIFF() == BattleMissileFactory.GetDataProxy():GetFriendlyCode() then
		return
	end

	if #bulletTemplate.alert_fx <= 0 then
		return
	end

	local alertRange = bulletTemplate.hit_type.range
	local alertFXID = bulletTemplate.alert_fx
	local alertFX = ys.Battle.BattleFXPool.GetInstance():GetFX(alertFXID)
	local alertTF = alertFX.transform
	local yScale = 0
	local effectOffsetConfig = pg.effect_offset

	if effectOffsetConfig[alertFXID] and effectOffsetConfig[alertFXID].y_scale == true then
		yScale = alertRange
	end

	alertTF.localScale = Vector3(alertRange, yScale, alertRange)

	pg.EffectMgr.GetInstance():PlayBattleEffect(alertFX, bulletData:GetExplodePostion())
end
