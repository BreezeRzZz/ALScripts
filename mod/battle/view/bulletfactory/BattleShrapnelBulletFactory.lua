ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleShrapnelBulletFactory = singletonClass("BattleShrapnelBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleShrapnelBulletFactory.__name = "BattleShrapnelBulletFactory"

local BattleShrapnelBulletFactory = ys.Battle.BattleShrapnelBulletFactory

BattleShrapnelBulletFactory.INHERIT_NONE = 0
BattleShrapnelBulletFactory.INHERIT_ANGLE = 1
BattleShrapnelBulletFactory.INHERIT_SPEED_NORMALIZE = 2
BattleShrapnelBulletFactory.INHERIT_VELOCITY_TEMPLATE = 1
BattleShrapnelBulletFactory.INHERIT_VELOCITY_CURRENT = 2
BattleShrapnelBulletFactory.FRAGILE_DAMAGE_NOT_SPLIT = 1
BattleShrapnelBulletFactory.FRAGILE_NOT_DAMAGE_NOT_SPLIT = 2

--- @class BattleShrapnelBulletFactory
--- @return nil
--- 构造函数
function BattleShrapnelBulletFactory.Ctor(self)
	BattleShrapnelBulletFactory.super.Ctor(self)
end

--- @class BattleShrapnelBulletFactory
--- @return BattleShrapnelBullet
--- 生成Shrapnel子弹
function BattleShrapnelBulletFactory.MakeBullet(self)
	return ys.Battle.BattleShrapnelBullet.New()
end

--- @class BattleShrapnelBulletFactory
--- @param tf Transform
--- @param bullet BattleShrapnelBulletUnit
--- @param position Vector3
--- @param fxID string
--- @param direction number
--- @return BattleShrapnelBullet
--- 创建Shaprnel子弹视图(视觉效果)
function BattleShrapnelBulletFactory.CreateBullet(self, tf, bullet, position, fxID, direction)
	bullet:SetOutRangeCallback(self.OutRangeFunc)

	--- @type BattleShrapnelBullet
	local bulletView = self:MakeBullet()

	bulletView:SetFactory(self)
	bulletView:SetBulletData(bullet)
	self:MakeModel(bulletView, position, fxID, direction)

	if fxID and fxID ~= "" then
		self:PlayFireFX(tf, bullet, position, fxID, direction, nil)
	end
	-- 不是rangeAA的情况
	if not bullet:GetTemplate().extra_param.rangeAA then
		BattleShrapnelBulletFactory.bulletSplit(bulletView)
	end

	return bulletView
end

function BattleShrapnelBulletFactory.onBulletHitFunc(self, uid, unitType)
	--- @type BattleDataProxy
	local battleDataProxy = BattleShrapnelBulletFactory.GetDataProxy()
	--- @type BattleShrapnelBulletUnit
	local bullet = self:GetBulletData()
	--- @type string
	--- 参考BattleShrapnelBulletUnit.lua中的STATE定义
	local currentState = bullet:GetCurrentState()
	local bulletTemplate = bullet:GetTemplate()
	local shrapnel = bulletTemplate.extra_param.shrapnel
	local fragile = bulletTemplate.extra_param.fragile
	local hitSplitOnly = bulletTemplate.extra_param.hitSplitOnly

	if not uid and hitSplitOnly then
		battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end
	-- fragile应该是决定命中时的表现
	if fragile and uid then
		if fragile == BattleShrapnelBulletFactory.FRAGILE_DAMAGE_NOT_SPLIT then
			-- 普通子弹的命中处理，造成伤害，不分裂
			ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(self, uid, unitType)
		elseif fragile == BattleShrapnelBulletFactory.FRAGILE_NOT_DAMAGE_NOT_SPLIT then
			-- 命中直接消失，没有伤害，也不分裂
			battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())
		end

		return
	end
	-- 检查BattleShrapnelBulletUnit的状态
	-- Spin/Split状态下的子弹，没有伤害判定
	if currentState == bullet.STATE_SPLIT or currentState == bullet.STATE_SPIN then
		-- block empty
	-- final_split同样没有伤害判定，且直接返回
	elseif currentState == bullet.STATE_FINAL_SPLIT then
		return
	-- 剩下的是normal状态，还存在穿透次数的情况，进行普通命中处理
	--
	elseif bullet:GetPierceCount() > 0 then
		ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(self, uid, unitType)

		return
	end

	if uid ~= nil and unitType ~= nil then
		--- @type BattleCharacter
		local character
		-- 如果命中的是飞机或角色
		if table.contains(AircraftUnitType, unitType) then
			character = BattleShrapnelBulletFactory.GetSceneMediator():GetAircraft(uid)
		elseif table.contains(CharacterUnitType, unitType) then
			character = BattleShrapnelBulletFactory.GetSceneMediator():GetCharacter(uid)
		end
		--- unit是指命中的单位
		--- @type BattleUnit
		local unit = character:GetUnitData()
		local fx = character:AddFX(self:GetFXID())
		-- 命中的是敌人则调整特效朝向
		if unit:GetIFF() == battleDataProxy:GetFoeCode() then
			local tf = fx.transform
			local localRotation = tf.localRotation

			tf.localRotation = Vector3(localRotation.x, 180, localRotation.z)
		end
	end

	ys.Battle.PlayBattleSFX(bullet:GetHitSFX())
	-- 如果rangeAA为true，则进行范围分裂
	-- 否则进行普通子弹分裂
	-- 一般来讲，只有防空弹会进行范围分裂
	if bulletTemplate.extra_param.rangeAA then
		BattleShrapnelBulletFactory.areaSplit(self)
	else
		BattleShrapnelBulletFactory.bulletSplit(self, true)
	end
end

function BattleShrapnelBulletFactory.areaSplit(self)
	--- @type BattleDataProxy
	local battleDataProxy = BattleShrapnelBulletFactory.GetDataProxy()
	--- @type BattleShrapnelBulletUnit
	local bullet = self:GetBulletData()
	-- 对应的WeaponUnit执行DoAreaSplit方法
	-- 看了一下，只有BattleFleetRangeAntiAirUnit才有这个方法
	bullet:GetWeapon():DoAreaSplit(bullet)
	battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())
end

function BattleShrapnelBulletFactory.bulletSplit(self, hitSplit)
	--- @type BattleShrapnelBulletUnit
	local bullet = self:GetBulletData()
	--- @type BattleDataProxy
	local battleDataProxy = BattleShrapnelBulletFactory.GetDataProxy()
	local bulletTemplate = bullet:GetTemplate()
	local shrapnel = bulletTemplate.extra_param.shrapnel
	--- @type BattleUnit
	local srcHost = bullet:GetSrcHost()
	--- @type BattleWeaponUnit
	local weapon = bullet:GetWeapon()

	if bulletTemplate.extra_param.FXID ~= nil then
		local fx, fxPosition = BattleShrapnelBulletFactory.GetFXPool():GetFX(bulletTemplate.extra_param.FXID)
		-- 在对应的位置播放特效
		pg.EffectMgr.GetInstance():PlayBattleEffect(fx, fxPosition:Add(self:GetPosition()), true)
	end

	local axisAngle = bullet:GetSpeed().x > 0 and 0 or 180

	for _, shrapnelItem in ipairs(shrapnel) do
		if hitSplit ~= shrapnelItem.initialSplit then
			local barrageID = shrapnelItem.barrage_ID
			local bulletID = shrapnelItem.bullet_ID
			-- 此处默认用SHOTGUN emitter
			local emitterType = shrapnelItem.emitterType or ys.Battle.BattleWeaponUnit.EMITTER_SHOTGUN
			local inheritAngle = shrapnelItem.inheritAngle
			local inheritSpeed = shrapnelItem.inheritSpeed
			local reaim = shrapnelItem.reaim
			local rotateOffset = shrapnelItem.rotateOffset

			local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority)
				-- 创建的是孩子子弹
				local _bullet = battleDataProxy:CreateBulletUnit(bulletID, srcHost, weapon, Vector3.zero)
				-- 重载标伤
				_bullet:OverrideCorrectedDMG(shrapnelItem.damage)
				_bullet:SetOffsetPriority(isOffsetPriority)

				if rotateOffset then
					local distance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
					local angle = math.atan2(offsetZ, offsetX)
					local yAngle = math.rad(bullet:GetYAngle())
					local resAngle = angle + yAngle
					local cosAngle = math.abs(math.cos(yAngle))

					offsetX = distance * math.cos(resAngle) * (0.5 + 0.5 * cosAngle)
					offsetZ = distance * math.sin(resAngle) * (2 - cosAngle)
				end

				_bullet:SetShiftInfo(offsetX, offsetZ)

				local baseAngle = axisAngle

				-- inheritAngle的类型
				-- nil/0: 不继承
				-- 1: 继承母弹发射角度
				-- 2: 继承母弹当前运动方向
				if inheritAngle == BattleShrapnelBulletFactory.INHERIT_ANGLE then
					baseAngle = bullet:GetYAngle()
				elseif inheritAngle == BattleShrapnelBulletFactory.INHERIT_SPEED_NORMALIZE then
					baseAngle = bullet:GetCurrentYAngle()
				end

				if reaim then
					local target
					local host = bullet:GetWeapon():GetHost()

					if type(reaim) == "table" and host then
						local reaimParam = shrapnelItem.reaimParam
						local candidateList

						for _, targetType in ipairs(reaim) do
							candidateList = ys.Battle.BattleTargetChoise[targetType](host, reaimParam, candidateList)
						end
						-- 选满足tag的第一个目标
						target = candidateList[1]
					else
						-- 选最近的目标
						target = ys.Battle.BattleTargetChoise.TargetHarmNearest(bullet)[1]
					end

					if target == nil then
						_bullet:SetRotateInfo(nil, baseAngle, barrageAngle)
					else
						_bullet:SetRotateInfo(target:GetBeenAimedPosition(), baseAngle, barrageAngle)
					end
				else
					_bullet:SetRotateInfo(nil, baseAngle, barrageAngle)
				end

				-- inheritSpeed的类型
				-- 1: 重设速度为模板速度
				-- 2: 继承母弹当前速度大小
				if inheritSpeed == BattleShrapnelBulletFactory.INHERIT_VELOCITY_TEMPLATE then
					_bullet:ResetVelocity(bullet:GetVelocity())
				elseif inheritSpeed == BattleShrapnelBulletFactory.INHERIT_VELOCITY_CURRENT then
					_bullet:InheritSpeed(bullet:GetSpeed())
				end

				BattleShrapnelBulletFactory.GetFactoryList()[_bullet:GetTemplate().type]:CreateBullet(self:GetTf(), _bullet, self:GetPosition())
			end

			local emitter

			local function stopFunc()
				emitter:Destroy()
				bullet:SplitFinishCount()
				-- 完成分裂后，母弹销毁
				if bullet:IsAllSplitFinish() then
					battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())
				end
			end

			emitter = ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID)

			bullet:CacheChildEimtter(emitter)
			emitter:Ready()
			emitter:Fire(nil, weapon:GetDirection(), ys.Battle.BattleDataFunction.GetBarrageTmpDataFromID(barrageID).angle)
		end
	end

	if hitSplit then
		-- 直接切换到final_split状态
		bullet:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_FINAL_SPLIT)
	end
end

function BattleShrapnelBulletFactory.onBulletMissFunc(self)
	return
end

--- @class BattleShrapnelBulletFactory
--- @param bulletView BattleShrapnelBullet
--- @param position Vector3
--- @param fxID string
--- @param direction number
--- @return nil
--- 创建子弹模型(视觉效果)
function BattleShrapnelBulletFactory.MakeModel(self, bulletView, position, fxID, direction)
	--- @type BattleShrapnelBulletUnit
	local bullet = bulletView:GetBulletData()

	if not self:GetBulletPool():InstBullet(bulletView:GetModleID(), function(arg_11_0)
		bulletView:AddModel(arg_11_0)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(position)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end

--- @class BattleShrapnelBulletFactory
--- @return nil
--- 子弹出界回调
--- - 如果是在出界时分裂，则切换到spin状态
--- - 否则切换到split状态
function BattleShrapnelBulletFactory.OutRangeFunc(self)
	if self:IsOutRange() then
		self:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_SPIN)
	else
		self:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_SPLIT)
	end
end
