ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleBulletFactory = singletonClass("BattleBulletFactory")
ys.Battle.BattleBulletFactory.__name = "BattleBulletFactory"

local BattleBulletFactory = ys.Battle.BattleBulletFactory

--- 构造函数（singleton 无实际初始化逻辑）
function BattleBulletFactory.Ctor(self)
	return
end

--- 回收临时GameObject到对象池
--- @param go UnityEngine.GameObject 待回收的临时对象
function BattleBulletFactory.RecyleTempModel(self, go)
	self._tempGOPool:Recycle(go)
end

--- 清理工厂，释放临时对象池
function BattleBulletFactory.Clear(self)
	if self._tempGOPool then
		self._tempGOPool:Dispose()

		self._tempGOPool = nil
	end
end

--- 创建完整的Bullet View实例（BulletUnit + Model + FireFX）
--- 这是工厂的核心入口方法，子类通常重写 MakeBullet / MakeModel
--- @param tf Transform 发射Transform，用于随弹丸移动的特效
--- @param bullet BattleBulletUnit 子弹数据对象
--- @param position Vector3 生成位置
--- @param fireFXID string 开火特效ID（可选，为nil或空字符串则跳过）
--- @param direction BattleConst.UnitDir 发射方向
--- @return BattleBulletUnit View层子弹实例
function BattleBulletFactory.CreateBullet(self, tf, bullet, position, fireFXID, direction)
	bullet:SetOutRangeCallback(self.OutRangeFunc)

	local bulletView = self:MakeBullet()

	bulletView:SetFactory(self)
	bulletView:SetBulletData(bullet)
	self:MakeModel(bulletView, position, fireFXID, direction)

	if fireFXID and fireFXID ~= "" then
		self:PlayFireFX(tf, bullet, position, fireFXID, direction, nil)
	end

	return bulletView
end

--- 获取场景中介者（SceneMediator）
function BattleBulletFactory.GetSceneMediator(self)
	return ys.Battle.BattleState.GetInstance():GetSceneMediator()
end

--- 获取战斗数据代理（BattleDataProxy）
function BattleBulletFactory.GetDataProxy(self)
	return ys.Battle.BattleDataProxy.GetInstance()
end

--- 获取特效池
function BattleBulletFactory.GetFXPool(self)
	return ys.Battle.BattleFXPool.GetInstance()
end

--- 获取子弹资源管理器（用于模型实例化）
function BattleBulletFactory.GetBulletPool(self)
	return ys.Battle.BattleResourceManager.GetInstance()
end

--- 子弹超出范围时的默认回调
--- 从数据代理中移除该子弹
--- @param bullet BattleBulletUnit
function BattleBulletFactory.OutRangeFunc(bullet)
	BattleBulletFactory.GetDataProxy():RemoveBulletUnit(bullet:GetUniqueID())
end

--- 获取临时GameObject池（惰性初始化）
--- 用于在模型资源异步加载期间提供不可见的占位GameObject
--- 这些临时对象被挂载到子弹根节点下，激活状态为false
function BattleBulletFactory.GetTempGOPool(self)
	if self._tempGOPool == nil then
		local tempObj = GameObject("temp_bullet_OBJ")

		SetActive(tempObj, false)

		local bulletRootTF = self:GetSceneMediator():GetBulletRoot().transform

		LuaHelper.SetGOParentTF(tempObj, bulletRootTF, false)

		self._tempGOPool = pg.Pool.New(bulletRootTF, tempObj, 1, 15, false, false):InitSize()
	end

	return self._tempGOPool
end

--- 播放发射特效
--- 支持两种模式：
--- 1. 随弹丸移动的特效（weaponTempData.effect_move == 1）：特效绑定在tf上
--- 2. 静止特效：在spawnPos位置生成一次
--- 左侧发射时会翻转Y轴180度做镜像
--- @param tf Transform 发射Transform
--- @param bullet BattleBulletUnit 子弹数据
--- @param spawnPos Vector3 生成位置
--- @param fireFXID string 特效ID
--- @param dir BattleConst.UnitDir 方向
--- @param callback function 特效完成后的回调（可选）
function BattleBulletFactory.PlayFireFX(self, tf, bullet, spawnPos, fireFXID, dir, callback)
	local isMoveFX = bullet:GetWeaponTempData().effect_move == 1

	if fireFXID == "" or fireFXID == nil then
		if callback then
			callback()
		end
	else
		local fxGO
		local fxPos

		if isMoveFX then
			-- 随弹丸移动：特效跟随tf生成
			fxGO, fxPos = self:GetFXPool():GetFX(fireFXID, tf)
		else
			-- 静止特效：在spawnPos生成
			fxGO, fxPos = self:GetFXPool():GetFX(fireFXID)
			fxPos = fxPos:Add(spawnPos)
		end

		-- 左侧发射需要Y轴翻转180度（场景镜像）
		if dir == BattleConst.UnitDir.LEFT then
			local fxTF = fxGO.transform
			local fxEuler = fxTF.localEulerAngles

			fxEuler.y = 180
			fxTF.localEulerAngles = fxEuler
		end

		pg.EffectMgr.GetInstance():PlayBattleEffect(fxGO, fxPos, true, callback, true)
	end
end

--- 创建子弹的BulletUnit View对象（子类重写以返回具体类型）
--- @return BattleBulletUnit
function BattleBulletFactory.MakeBullet(self)
	return nil
end

--- 创建子弹的视觉模型（子类重写以实例化模型资源）
--- @param bulletView BattleBulletUnit View层子弹
--- @param spawnPos Vector3 生成位置
function BattleBulletFactory.MakeModel(self, bulletView, spawnPos)
	return nil
end

--- 炸弹预投警告阶段创建模型
--- 默认委托给 MakeModel，子类（如BombFactory）可重写
--- @param bulletView BattleBulletUnit
--- @param spawnPos Vector3
function BattleBulletFactory.MakeBombPreCastAlter(self, bulletView, spawnPos)
	return self:MakeModel(bulletView, spawnPos)
end

--- 炸弹预投警告特效之后创建模型（子类可重写）
--- @param bulletView BattleBulletUnit
function BattleBulletFactory.MakeModelAfterBombPreCastAlert(self, bulletView)
	return nil
end

--- 为子弹添加拖尾特效
--- @param bulletView BattleBulletUnit
--- @param trackGO GameObject 拖尾GameObject
--- @param trackPos Vector3 拖尾位置偏移
function BattleBulletFactory.MakeTrack(self, bulletView, trackGO, trackPos)
	bulletView:AddTrack(trackGO)
	pg.EffectMgr.GetInstance():PlayBattleEffect(trackGO, trackPos, true)
end

--- 移除并销毁子弹
--- @param bulletView BattleBulletUnit
function BattleBulletFactory.RemoveBullet(self, bulletView)
	bulletView:Dispose()
end

--- 获取 BulletType → Factory 的映射表（惰性初始化，全局单例）
--- 所有子弹类型都在这里注册，新增子弹类型需在此添加映射
--- @return table<number, BattleBulletFactory>
function BattleBulletFactory.GetFactoryList()
	if BattleBulletFactory._factoryList == nil then
		BattleBulletFactory._factoryList = {
			[BattleConst.BulletType.CANNON] = ys.Battle.BattleCannonBulletFactory.GetInstance(),
			[BattleConst.BulletType.BOMB] = ys.Battle.BattleBombBulletFactory.GetInstance(),
			[BattleConst.BulletType.TORPEDO] = ys.Battle.BattleTorpedoBulletFactory.GetInstance(),
			[BattleConst.BulletType.DIRECT] = ys.Battle.BattleDirectBulletFactory.GetInstance(),
			[BattleConst.BulletType.SHRAPNEL] = ys.Battle.BattleShrapnelBulletFactory.GetInstance(),
			[BattleConst.BulletType.ANTI_AIR] = ys.Battle.BattleAntiAirBulletFactory.GetInstance(),
			[BattleConst.BulletType.ANTI_SEA] = ys.Battle.BattleAntiSeaBulletFactory.GetInstance(),
			[BattleConst.BulletType.STRAY] = ys.Battle.BattleStrayBulletFactory.GetInstance(),
			[BattleConst.BulletType.EFFECT] = ys.Battle.BattleEffectBulletFactory.GetInstance(),
			[BattleConst.BulletType.BEAM] = ys.Battle.BattleBeamBulletFactory.GetInstance(),
			[BattleConst.BulletType.G_BULLET] = ys.Battle.BattleGravitationBulletFactory.GetInstance(),
			[BattleConst.BulletType.ELECTRIC_ARC] = ys.Battle.BattleElectricArcBulletFactory.GetInstance(),
			[BattleConst.BulletType.SPACE_LASER] = ys.Battle.BattleSpaceLaserFactory.GetInstance(),
			[BattleConst.BulletType.MISSILE] = ys.Battle.BattleMissileFactory.GetInstance(),
			[BattleConst.BulletType.SCALE] = ys.Battle.BattleScaleBulletFactory.GetInstance(),
			[BattleConst.BulletType.TRIGGER_BOMB] = ys.Battle.BattleTriggerBulletFactory.GetInstance(),
			[BattleConst.BulletType.AAMissile] = ys.Battle.BattleAAMissileFactory.GetInstance()
		}
	end

	return BattleBulletFactory._factoryList
end

--- 销毁工厂列表（用于战斗重置）
function BattleBulletFactory.DestroyFactory()
	BattleBulletFactory._factoryList = nil
end

--- 停用所有正在追踪的防空/反海子弹（战斗结束时调用）
function BattleBulletFactory.NeutralizeBullet()
	ys.Battle.BattleAntiAirBulletFactory.GetInstance():NeutralizeBullet()
	ys.Battle.BattleAntiSeaBulletFactory.GetInstance():NeutralizeBullet()
end

--- 从骨骼名列表中随机选取一个
--- @param boneList string[] 骨骼名列表（从bone_combat表获取）
--- @return string 随机骨骼名
function BattleBulletFactory.GetRandomBone(boneList)
	return boneList[math.floor(math.Random(0, #boneList)) + 1]
end
