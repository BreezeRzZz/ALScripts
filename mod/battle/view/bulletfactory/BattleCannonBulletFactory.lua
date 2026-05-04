ys = ys or {}

local ys = ys
local UnitType = ys.Battle.BattleConst.UnitType
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleCannonBulletFactory = singletonClass("BattleCannonBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleCannonBulletFactory.__name = "BattleCannonBulletFactory"

local BattleCannonBulletFactory = ys.Battle.BattleCannonBulletFactory

function BattleCannonBulletFactory.Ctor(self)
	BattleCannonBulletFactory.super.Ctor(self)
end

--- 创建炮弹类型的BulletUnit View
--- @return BattleCannonBullet
function BattleCannonBulletFactory.MakeBullet(self)
	return ys.Battle.BattleCannonBullet.New()
end

-- 命中特效旋转用的预计算四元数（绕X轴-90度，用于将特效对齐到目标表面法线方向）
local hitFXRotation = Quaternion.Euler(-90, 0, 0)

--- 炮弹命中回调（碰撞检测触发）
--- 处理命中/未命中视觉效果、伤害结算、碰撞前Buff触发
--- @param targetUID number 被命中单位的UID
--- @param unitType number 单位类型（Aircraft / Character）
function BattleCannonBulletFactory.onBulletHitFunc(self, targetUID, unitType)
	local dataProxy = BattleCannonBulletFactory.GetDataProxy()
	local bulletData = self:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()
	local targetUnit
	-- 根据单位类型从SceneMediator获取对应的GameObject
	if table.contains(AircraftUnitType, unitType) then
		targetUnit = BattleCannonBulletFactory.GetSceneMediator():GetAircraft(targetUID)
	elseif table.contains(CharacterUnitType, unitType) then
		targetUnit = BattleCannonBulletFactory.GetSceneMediator():GetCharacter(targetUID)
	end

	if not targetUnit then
		return
	end

	local targetUnitData = targetUnit:GetUnitData()
	local triggerData = {
		_bullet = bulletData,
		equipIndex = bulletData:GetWeapon():GetEquipmentIndex(),
		bulletTag = bulletData:GetExtraTag()
	}

	-- 子弹碰撞前Buff触发（ON_BULLET_COLLIDE_BEFORE）
	bulletData:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_COLLIDE_BEFORE, triggerData)

	local isMiss, damageResult = dataProxy:HandleDamage(bulletData, targetUnitData)
	local hitEffect

	if targetUnit:GetGO() then
		if isMiss then
			-- 未命中：在目标附近随机位置播放miss特效
			local missFX, missOffset = BattleCannonBulletFactory.GetFXPool():GetFX(self:GetMissFXID())
			local boxSize = targetUnit:GetUnitData():GetBoxSize()
			local randomSide = math.random(0, 1)

			if randomSide == 0 then
				randomSide = -1
			end

			local randomX = (math.random() - 0.5) * boxSize.x
			local missPos = Vector3(randomX, 0, boxSize.z * randomSide):Add(targetUnit:GetPosition())

			pg.EffectMgr.GetInstance():PlayBattleEffect(missFX, missPos:Add(missOffset), true)
			ys.Battle.PlayBattleSFX(bulletData:GetMissSFX())
		else
			-- 命中：在目标身上添加命中特效，并根据碰撞方向调整特效位置
			hitEffect = targetUnit:AddFX(self:GetFXID())

			ys.Battle.PlayBattleSFX(bulletData:GetHitSFX())

			local direction = targetUnitData:GetDirection()
			local hitDir = self:GetPosition() - targetUnit:GetPosition()

			hitDir.x = hitDir.x * direction

			local hitLocalPos = hitEffect.transform.localPosition
			local targetRotX = (hitFXRotation * targetUnit:GetTf().localRotation).eulerAngles.x

			hitDir.y = math.cos(math.deg2Rad * targetRotX) * hitDir.z
			hitDir.z = 0

			local localHitDir = hitDir / targetUnit:GetInitScale()

			hitLocalPos:Add(localHitDir)

			hitEffect.transform.localPosition = hitLocalPos
		end
	end

	-- 命中敌方单位时翻转特效Y轴，使特效朝向正确方向
	if hitEffect and targetUnitData:GetIFF() == dataProxy:GetFoeCode() then
		local hitEffectTF = hitEffect.transform
		local hitEffectRot = hitEffectTF.localRotation

		hitEffectTF.localRotation = Vector3(hitEffectRot.x, 180, hitEffectRot.z)
	end

	-- 穿透次数耗尽时移除子弹
	if bulletData:GetPierceCount() <= 0 then
		dataProxy:RemoveBulletUnit(bulletData:GetUniqueID())
	end
end

--- 炮弹未命中回调（飞出边界/脱靶时触发）
--- 在当前位置播放miss特效和音效
function BattleCannonBulletFactory.onBulletMissFunc(self)
	local bulletData = self:GetBulletData()
	local bulletTemplate = bulletData:GetTemplate()
	local missFX, missOffset = BattleCannonBulletFactory.GetFXPool():GetFX(self:GetMissFXID())

	pg.EffectMgr.GetInstance():PlayBattleEffect(missFX, missOffset:Add(self:GetPosition()), true)
	ys.Battle.PlayBattleSFX(bulletData:GetMissSFX())
end

--- 创建炮弹的视觉模型
--- 通过ResourceManager异步实例化模型，若资源未就绪则使用临时占位对象
--- 设置生成位置、命中/未命中回调，并注册到SceneMediator
--- @param bulletView BattleBulletUnit View层子弹
--- @param spawnPos Vector3 生成位置
--- @param fireFXID string 发射特效ID（此方法内未使用，由父类CreateBullet调用PlayFireFX）
--- @param dir BattleConst.UnitDir 方向（未使用）
function BattleCannonBulletFactory.MakeModel(self, bulletView, spawnPos, fireFXID, dir)
	local dataProxy = self:GetDataProxy()
	local bulletData = bulletView:GetBulletData()

	if not self:GetBulletPool():InstBullet(bulletData:GetModleID(), function(instGO)
		bulletView:AddModel(instGO)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(spawnPos)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end
