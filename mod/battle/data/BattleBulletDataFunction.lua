ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local bullet_template = pg.bullet_template
local barrage_template = pg.barrage_template

ys.Battle.BattleDataFunction = ys.Battle.BattleDataFunction or {}

local BattleDataFunction = ys.Battle.BattleDataFunction
local LEFT = BattleConst.UnitDir.LEFT
local RIGHT = BattleConst.UnitDir.RIGHT

-- 被BattleDataProxy.CreateBulletUnit调用，实际创建子弹数据内容
function BattleDataFunction.CreateBattleBulletData(bulletUID, bulletID, host, weapon, targetPos)
	local bulletTemplate = BattleDataFunction.GetBulletTmpDataFromID(bulletID)
	local bulletType = bulletTemplate.type
	-- 如有currentdrop参数，目标点设为发射者位置
	if bulletTemplate.extra_param.currentdrop then
		targetPos = host:GetPosition()
	end
	-- 这一步会根据子弹类型，创建不同的子弹单位
	-- 得到的只有一个空壳（一般就只设置了UID和IFF），设置模板等信息还在下面
	-- 但看了下，有的子弹类型的创建函数又会设置一些模板信息，搞不懂为什么设计成这样...
	local bullet, bulletCld = BattleDataFunction.generateBulletFuncs[bulletType](bulletUID, bulletTemplate, host, weapon, targetPos)

	bullet:SetTemplateData(bulletTemplate)
	-- 创建子弹时，将发射者的属性传给子弹
	bullet:SetAttr(host._attr)
	bullet:SetBuffTrigger(host)
	bullet:SetWeapon(weapon)
	-- 如果是跨队武器设置了StandHost，则把(weapon)的StandHost的属性传给子弹
	if weapon and weapon:GetStandHost() then
		local standHostAttr = weapon:GetStandHost():GetAttr()

		bullet:SetStandHostAttr(standHostAttr)
	end

	local isIgnoreCld = bullet:IsIngoreCld()

	if isIgnoreCld ~= nil then
		local isCld = not isIgnoreCld

		bullet:SetIsCld(isCld)
		-- 此处根据isIgnoreCld，重新设置了bulletCld
		bulletCld = isCld
	end

	return bullet, bulletCld
end

function BattleDataFunction.GetBulletTmpDataFromID(bulletID)
	assert(bullet_template[bulletID] ~= nil, "找不到子弹配置：id = " .. bulletID)

	return bullet_template[bulletID]
end

function BattleDataFunction.GetBarrageTmpDataFromID(barrageID)
	assert(barrage_template[barrageID] ~= nil, "找不到弹幕配置：id = " .. barrageID)

	return barrage_template[barrageID]
end

function BattleDataFunction.GetConvertedBarrageTableFromID(barrageID, arg_4_1)
	assert(barrage_template[barrageID] ~= nil, "获取转换弹幕数据失败，找不到弹幕原型配置：id = " .. barrageID)

	if BattleDataFunction.ConvertedBarrageTableList[barrageID] == nil or BattleDataFunction.ConvertedBarrageTableList[barrageID][arg_4_1] == nil then
		BattleDataFunction.ConvertSpecificBarrage(barrageID, arg_4_1)
	end

	return BattleDataFunction.ConvertedBarrageTableList[barrageID]
end

function BattleDataFunction.GenerateTransBarrage(arg_5_0, arg_5_1, arg_5_2)
	local var_5_0 = {}
	local var_5_1 = BattleDataFunction.GetBarrageTmpDataFromID(arg_5_0)

	while var_5_1.trans_ID ~= -1 do
		local var_5_2 = var_5_1.trans_ID

		var_5_1 = BattleDataFunction.GetBarrageTmpDataFromID(var_5_2)

		local var_5_3 = {
			transStartDelay = var_5_1.first_delay + var_5_1.delay * arg_5_2 + var_5_1.delta_delay * arg_5_2
		}

		if var_5_1.offset_prioritise then
			var_5_3.transAimPosX = var_5_1.offset_x + var_5_1.delta_offset_x * arg_5_2
			var_5_3.transAimPosZ = var_5_1.offset_z + var_5_1.delta_offset_z * arg_5_2
		else
			var_5_3.transAimAngle = var_5_1.angle + var_5_1.delta_angle * arg_5_2

			if arg_5_1 == -1 then
				var_5_3.transAimAngle = var_5_3.transAimAngle + 180
			end
		end

		var_5_0[#var_5_0 + 1] = var_5_3
	end

	return var_5_0
end

function BattleDataFunction._createCannonBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleCannonBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(true)

	return bullet, true
end

function BattleDataFunction._createBombBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleBombBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetAttr(host._attr)
	bullet:SetTemplateData(bulletTemplate)

	-- 如果目标点是零向量，则根据发射者位置和武器的最大索敌范围(range)，计算一个目标点
	if targetPos:EqualZero() then
		targetPos = host:GetPosition():Clone()

		local range = weapon:GetTemplateData().range

		if host:GetDirection() == BattleConst.UnitDir.RIGHT then
			targetPos.x = targetPos.x + range
		else
			targetPos.x = targetPos.x - range
		end
	end

	bullet:SetExplodePosition(targetPos)
	bullet:SetIsCld(false)

	return bullet, false
end

function BattleDataFunction._createStrayBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleStrayBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(true)

	return bullet, true
end

function BattleDataFunction._createTorpedoBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleTorpedoBulletUnit.New(bulletUID, host:GetIFF())
	-- torpedo既有指定爆炸点，也有碰撞检测、
	-- 实际结算伤害时一般是靠碰撞检测来实现的
	bullet:SetExplodePosition(targetPos)
	bullet:SetIsCld(true)

	return bullet, true
end

function BattleDataFunction._createDirectBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	-- DirectBullet本质也是BattleAntiAirBulletUnit
	-- 都用这个类，可能是因为这种子弹用的比较少，不会与其他子弹类型冲突，此外可能这种子弹没有模型
	local bullet = ys.Battle.BattleAntiAirBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(false)

	return bullet, false
end

function BattleDataFunction._createAntiAirBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleAntiAirBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(false)

	return bullet, false
end

function BattleDataFunction._createAntiSeaBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleAntiSeaBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(false)

	return bullet, false
end

function BattleDataFunction._createSharpnelBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleShrapnelBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetExplodePosition(targetPos)
	bullet:SetSrcHost(host)
	bullet:SetIsCld(true)

	return bullet, true
end

function BattleDataFunction._createEffectBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleEffectBulletUnit.New(bulletUID, host:GetIFF())
	bullet:SetTemplateData(bulletTemplate)
	bullet:SetIsCld(false)
	-- CLS指的是斩击等的清除子弹效果，所以ImmuneCLS表示这种子弹不会被清除
	bullet:SetImmuneCLS(true)
	-- 对于照明弹的处理
	if bulletTemplate.attach_buff[1].flare then
		bullet:spawnArea(true)
	end

	return bullet, false
end

function BattleDataFunction._createBeamBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	-- 激光武器逻辑总结：由BattleLaserUnit管理多个BattleBeamUnit，每个BattleBeamUnit对应一个barrage_template和bullet_template组合
	-- BattleBeamUnit负责激光的生成、发射点位置更新、碰撞检测等
	-- 实际伤害结算逻辑，是生成一个没有碰撞体的BattleAntiAirBulletUnit来处理的
	local bullet = ys.Battle.BattleAntiAirBulletUnit.New(bulletUID, host:GetIFF())
	
	bullet:SetIsCld(false)

	return bullet, false
end

function BattleDataFunction._createGravitationBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleGravitationBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetExplodePosition(targetPos)
	bullet:SetIsCld(true)
	bullet:SetImmuneCLS(true)

	return bullet, true
end

function BattleDataFunction._createMissile(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleMissileUnit.New(bulletUID, host:GetIFF())

	bullet:SetAttr(host._attr)
	bullet:SetTemplateData(bulletTemplate)
	bullet:SetImmuneCLS(true)
	-- 导弹实际上没有碰撞检测
	bullet:SetIsCld(false)

	return bullet, false
end

function BattleDataFunction._createSpaceLaser(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleSpaceLaserUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(true)
	bullet:SetImmuneCLS(true)

	return bullet, true
end

function BattleDataFunction._createScaleBullet(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleScaleBulletUnit.New(bulletUID, host:GetIFF())

	bullet:SetIsCld(true)

	return bullet, true
end

function BattleDataFunction._createAAMissile(bulletUID, bulletTemplate, host, weapon, targetPos)
	local bullet = ys.Battle.BattleTrackingAAMissileUnit.New(bulletUID, host:GetIFF())
	bullet:SetIsCld(true)

	return bullet, true
end

BattleDataFunction.generateBulletFuncs = {}
-- CANNON(1) -> CreateCannonBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.CANNON] = BattleDataFunction._createCannonBullet
-- BOMB(2) -> CreateBombBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.BOMB] = BattleDataFunction._createBombBullet
-- TORPEDO(3) -> CreateTorpedoBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.TORPEDO] = BattleDataFunction._createTorpedoBullet
-- DIRECT(4) -> CreateDirectBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.DIRECT] = BattleDataFunction._createDirectBullet
-- ANTI_AIR(6) -> CreateAntiAirBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.ANTI_AIR] = BattleDataFunction._createAntiAirBullet
-- ANTI_SEA(7) -> CreateAntiSeaBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.ANTI_SEA] = BattleDataFunction._createAntiSeaBullet
-- SHRAPNEL(5) -> CreateSharpnelBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.SHRAPNEL] = BattleDataFunction._createSharpnelBullet
-- STRAY(8) -> CreateStrayBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.STRAY] = BattleDataFunction._createStrayBullet
-- EFFECT(9) -> CreateEffectBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.EFFECT] = BattleDataFunction._createEffectBullet
-- BEAM(10) -> CreateBeamBullet(*实际创建BattleAntiAirBulletUnit负责实际的伤害结算逻辑，因为BattleBeamUnit本质不是子弹单位，不是BattleBulletUnit的子类)
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.BEAM] = BattleDataFunction._createBeamBullet
-- G_BULLET(11) -> CreateGravitationBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.G_BULLET] = BattleDataFunction._createGravitationBullet
-- ELECTRIC_ARC(12) -> CreateDirectBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.ELECTRIC_ARC] = BattleDataFunction._createDirectBullet
-- MISSILE(13) -> CreateMissile
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.MISSILE] = BattleDataFunction._createMissile
-- SPACE_LASER(14) -> CreateSpaceLaser
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.SPACE_LASER] = BattleDataFunction._createSpaceLaser
-- SCALE(15) -> CreateScaleBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.SCALE] = BattleDataFunction._createScaleBullet
-- TRIGGER_BOMB(16) -> CreateBombBullet
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.TRIGGER_BOMB] = BattleDataFunction._createBombBullet
-- AAMissile(17) -> CreateAAMissile
BattleDataFunction.generateBulletFuncs[BattleConst.BulletType.AAMissile] = BattleDataFunction._createAAMissile

function BattleDataFunction.ConvertSpecificBarrage(barrageID, arg_21_1)
	local var_21_0

	var_21_0[arg_21_1], var_21_0 = BattleDataFunction.barrageInteration(pg.barrage_template[barrageID], arg_21_1), BattleDataFunction.ConvertedBarrageTableList[barrageID] or {}
	BattleDataFunction.ConvertedBarrageTableList[barrageID] = var_21_0
end

function BattleDataFunction.ClearConvertedBarrage()
	BattleDataFunction.ConvertedBarrageTableList = {}
end

function BattleDataFunction.barrageInteration(arg_23_0, arg_23_1)
	local var_23_0 = 1
	local var_23_1 = arg_23_0.primal_repeat
	local var_23_2 = {}
	local var_23_3 = arg_23_0.offset_x
	local var_23_4 = arg_23_0.offset_z
	local var_23_5 = arg_23_0.angle
	local var_23_6 = arg_23_0.delay
	local var_23_7 = arg_23_0.delta_offset_x
	local var_23_8 = arg_23_0.delta_offset_z
	local var_23_9 = arg_23_0.delta_angle
	local var_23_10 = arg_23_0.delta_delay

	for iter_23_0 = 0, var_23_1 do
		local var_23_11 = {
			OffsetX = var_23_3 * arg_23_1,
			OffsetZ = var_23_4,
			Angle = var_23_5,
			Delay = var_23_6
		}

		table.insert(var_23_2, var_23_11)

		var_23_3 = var_23_3 + var_23_7
		var_23_4 = var_23_4 + var_23_8
		var_23_5 = var_23_5 + var_23_9
		var_23_6 = var_23_6 + var_23_10
	end

	return var_23_2
end

BattleDataFunction.ClearConvertedBarrage()
