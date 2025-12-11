ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleBulletFactory = singletonClass("BattleBulletFactory")
ys.Battle.BattleBulletFactory.__name = "BattleBulletFactory"

local BattleBulletFactory = ys.Battle.BattleBulletFactory

function BattleBulletFactory.Ctor(arg_1_0)
	return
end

function BattleBulletFactory.RecyleTempModel(arg_2_0, arg_2_1)
	arg_2_0._tempGOPool:Recycle(arg_2_1)
end

function BattleBulletFactory.Clear(arg_3_0)
	if arg_3_0._tempGOPool then
		arg_3_0._tempGOPool:Dispose()

		arg_3_0._tempGOPool = nil
	end
end
-- TODO
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

function BattleBulletFactory.GetSceneMediator(arg_5_0)
	return ys.Battle.BattleState.GetInstance():GetSceneMediator()
end

function BattleBulletFactory.GetDataProxy(arg_6_0)
	return ys.Battle.BattleDataProxy.GetInstance()
end

function BattleBulletFactory.GetFXPool(arg_7_0)
	return ys.Battle.BattleFXPool.GetInstance()
end

function BattleBulletFactory.GetBulletPool(arg_8_0)
	return ys.Battle.BattleResourceManager.GetInstance()
end

function BattleBulletFactory.OutRangeFunc(arg_9_0)
	BattleBulletFactory.GetDataProxy():RemoveBulletUnit(arg_9_0:GetUniqueID())
end

function BattleBulletFactory.GetTempGOPool(arg_10_0)
	if arg_10_0._tempGOPool == nil then
		local var_10_0 = GameObject("temp_bullet_OBJ")

		SetActive(var_10_0, false)

		local var_10_1 = arg_10_0:GetSceneMediator():GetBulletRoot().transform

		LuaHelper.SetGOParentTF(var_10_0, var_10_1, false)

		arg_10_0._tempGOPool = pg.Pool.New(var_10_1, var_10_0, 1, 15, false, false):InitSize()
	end

	return arg_10_0._tempGOPool
end

function BattleBulletFactory.PlayFireFX(arg_11_0, arg_11_1, arg_11_2, arg_11_3, arg_11_4, arg_11_5, arg_11_6)
	local var_11_0 = arg_11_2:GetWeaponTempData().effect_move == 1

	if arg_11_4 == "" or arg_11_4 == nil then
		if arg_11_6 then
			arg_11_6()
		end
	else
		local var_11_1
		local var_11_2

		if var_11_0 then
			var_11_1, var_11_2 = arg_11_0:GetFXPool():GetFX(arg_11_4, arg_11_1)
		else
			var_11_1, var_11_2 = arg_11_0:GetFXPool():GetFX(arg_11_4)
			var_11_2 = var_11_2:Add(arg_11_3)
		end

		if arg_11_5 == BattleConst.UnitDir.LEFT then
			local var_11_3 = var_11_1.transform
			local var_11_4 = var_11_3.localEulerAngles

			var_11_4.y = 180
			var_11_3.localEulerAngles = var_11_4
		end

		pg.EffectMgr.GetInstance():PlayBattleEffect(var_11_1, var_11_2, true, arg_11_6, true)
	end
end

function BattleBulletFactory.MakeBullet(arg_12_0)
	return nil
end

function BattleBulletFactory.MakeModel(arg_13_0, arg_13_1, arg_13_2)
	return nil
end

function BattleBulletFactory.MakeBombPreCastAlter(arg_14_0, arg_14_1, arg_14_2)
	return arg_14_0:MakeModel(arg_14_1, arg_14_2)
end

function BattleBulletFactory.MakeModelAfterBombPreCastAlert(arg_15_0, arg_15_1)
	return nil
end

function BattleBulletFactory.MakeTrack(arg_16_0, arg_16_1, arg_16_2, arg_16_3)
	arg_16_1:AddTrack(arg_16_2)
	pg.EffectMgr.GetInstance():PlayBattleEffect(arg_16_2, arg_16_3, true)
end

function BattleBulletFactory.RemoveBullet(arg_17_0, arg_17_1)
	arg_17_1:Dispose()
end

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

function BattleBulletFactory.DestroyFactory()
	BattleBulletFactory._factoryList = nil
end

function BattleBulletFactory.NeutralizeBullet()
	ys.Battle.BattleAntiAirBulletFactory.GetInstance():NeutralizeBullet()
	ys.Battle.BattleAntiSeaBulletFactory.GetInstance():NeutralizeBullet()
end

function BattleBulletFactory.GetRandomBone(arg_21_0)
	return arg_21_0[math.floor(math.Random(0, #arg_21_0)) + 1]
end
