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

function BattleShrapnelBulletFactory.CreateBullet(self, tf, bullet, arg_3_3, arg_3_4, direction)
	bullet:SetOutRangeCallback(self.OutRangeFunc)

	--- @type BattleShrapnelBullet
	local bulletView = self:MakeBullet()

	bulletView:SetFactory(self)
	bulletView:SetBulletData(bullet)
	self:MakeModel(bulletView, arg_3_3, arg_3_4, direction)

	if arg_3_4 and arg_3_4 ~= "" then
		self:PlayFireFX(tf, bullet, arg_3_3, arg_3_4, direction, nil)
	end

	if not bullet:GetTemplate().extra_param.rangeAA then
		BattleShrapnelBulletFactory.bulletSplit(bulletView)
	end

	return bulletView
end

function BattleShrapnelBulletFactory.onBulletHitFunc(arg_4_0, arg_4_1, arg_4_2)
	local var_4_0 = BattleShrapnelBulletFactory.GetDataProxy()
	local var_4_1 = arg_4_0:GetBulletData()
	local var_4_2 = var_4_1:GetCurrentState()
	local var_4_3 = var_4_1:GetTemplate()
	local var_4_4 = var_4_3.extra_param.shrapnel
	local var_4_5 = var_4_3.extra_param.fragile
	local var_4_6 = var_4_3.extra_param.hitSplitOnly

	if not arg_4_1 and var_4_6 then
		var_4_0:RemoveBulletUnit(var_4_1:GetUniqueID())

		return
	end

	if var_4_5 and arg_4_1 then
		if var_4_5 == BattleShrapnelBulletFactory.FRAGILE_DAMAGE_NOT_SPLIT then
			ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(arg_4_0, arg_4_1, arg_4_2)
		elseif var_4_5 == BattleShrapnelBulletFactory.FRAGILE_NOT_DAMAGE_NOT_SPLIT then
			var_4_0:RemoveBulletUnit(var_4_1:GetUniqueID())
		end

		return
	end

	if var_4_2 == var_4_1.STATE_SPLIT or var_4_2 == var_4_1.STATE_SPIN then
		-- block empty
	elseif var_4_2 == var_4_1.STATE_FINAL_SPLIT then
		return
	elseif var_4_1:GetPierceCount() > 0 then
		ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(arg_4_0, arg_4_1, arg_4_2)

		return
	end

	if arg_4_1 ~= nil and arg_4_2 ~= nil then
		local var_4_7

		if table.contains(AircraftUnitType, arg_4_2) then
			var_4_7 = BattleShrapnelBulletFactory.GetSceneMediator():GetAircraft(arg_4_1)
		elseif table.contains(CharacterUnitType, arg_4_2) then
			var_4_7 = BattleShrapnelBulletFactory.GetSceneMediator():GetCharacter(arg_4_1)
		end

		local var_4_8 = var_4_7:GetUnitData()
		local var_4_9 = var_4_7:AddFX(arg_4_0:GetFXID())

		if var_4_8:GetIFF() == var_4_0:GetFoeCode() then
			local var_4_10 = var_4_9.transform
			local var_4_11 = var_4_10.localRotation

			var_4_10.localRotation = Vector3(var_4_11.x, 180, var_4_11.z)
		end
	end

	ys.Battle.PlayBattleSFX(var_4_1:GetHitSFX())

	if var_4_3.extra_param.rangeAA then
		BattleShrapnelBulletFactory.areaSplit(arg_4_0)
	else
		BattleShrapnelBulletFactory.bulletSplit(arg_4_0, true)
	end
end

function BattleShrapnelBulletFactory.areaSplit(arg_5_0)
	local var_5_0 = BattleShrapnelBulletFactory.GetDataProxy()
	local var_5_1 = arg_5_0:GetBulletData()

	var_5_1:GetWeapon():DoAreaSplit(var_5_1)
	var_5_0:RemoveBulletUnit(var_5_1:GetUniqueID())
end

function BattleShrapnelBulletFactory.bulletSplit(arg_6_0, arg_6_1)
	local var_6_0 = arg_6_0:GetBulletData()
	local var_6_1 = BattleShrapnelBulletFactory.GetDataProxy()
	local var_6_2 = var_6_0:GetTemplate()
	local var_6_3 = var_6_2.extra_param.shrapnel
	local var_6_4 = var_6_0:GetSrcHost()
	local var_6_5 = var_6_0:GetWeapon()

	if var_6_2.extra_param.FXID ~= nil then
		local var_6_6, var_6_7 = BattleShrapnelBulletFactory.GetFXPool():GetFX(var_6_2.extra_param.FXID)

		pg.EffectMgr.GetInstance():PlayBattleEffect(var_6_6, var_6_7:Add(arg_6_0:GetPosition()), true)
	end

	local var_6_8
	local var_6_9 = var_6_0:GetSpeed().x > 0 and 0 or 180

	for iter_6_0, iter_6_1 in ipairs(var_6_3) do
		if arg_6_1 ~= iter_6_1.initialSplit then
			local var_6_10 = iter_6_1.barrage_ID
			local var_6_11 = iter_6_1.bullet_ID
			local var_6_12 = iter_6_1.emitterType or ys.Battle.BattleWeaponUnit.EMITTER_SHOTGUN
			local var_6_13 = iter_6_1.inheritAngle
			local var_6_14 = iter_6_1.inheritSpeed
			local var_6_15 = iter_6_1.reaim
			local var_6_16 = iter_6_1.rotateOffset

			local function var_6_17(arg_7_0, arg_7_1, arg_7_2, arg_7_3)
				local var_7_0 = var_6_1:CreateBulletUnit(var_6_11, var_6_4, var_6_5, Vector3.zero)

				var_7_0:OverrideCorrectedDMG(iter_6_1.damage)
				var_7_0:SetOffsetPriority(arg_7_3)

				if var_6_16 then
					local var_7_1 = math.sqrt(arg_7_0 * arg_7_0 + arg_7_1 * arg_7_1)
					local var_7_2 = math.atan2(arg_7_1, arg_7_0)
					local var_7_3 = math.rad(var_6_0:GetYAngle())
					local var_7_4 = var_7_2 + var_7_3
					local var_7_5 = math.abs(math.cos(var_7_3))

					arg_7_0 = var_7_1 * math.cos(var_7_4) * (0.5 + 0.5 * var_7_5)
					arg_7_1 = var_7_1 * math.sin(var_7_4) * (2 - var_7_5)
				end

				var_7_0:SetShiftInfo(arg_7_0, arg_7_1)

				local var_7_6 = var_6_9

				if var_6_13 == BattleShrapnelBulletFactory.INHERIT_ANGLE then
					var_7_6 = var_6_0:GetYAngle()
				elseif var_6_13 == BattleShrapnelBulletFactory.INHERIT_SPEED_NORMALIZE then
					var_7_6 = var_6_0:GetCurrentYAngle()
				end

				if var_6_15 then
					local var_7_7
					local var_7_8 = var_6_0:GetWeapon():GetHost()

					if type(var_6_15) == "table" and var_7_8 then
						local var_7_9 = iter_6_1.reaimParam
						local var_7_10

						for iter_7_0, iter_7_1 in ipairs(var_6_15) do
							var_7_10 = ys.Battle.BattleTargetChoise[iter_7_1](var_7_8, var_7_9, var_7_10)
						end

						var_7_7 = var_7_10[1]
					else
						var_7_7 = ys.Battle.BattleTargetChoise.TargetHarmNearest(var_6_0)[1]
					end

					if var_7_7 == nil then
						var_7_0:SetRotateInfo(nil, var_7_6, arg_7_2)
					else
						var_7_0:SetRotateInfo(var_7_7:GetBeenAimedPosition(), var_7_6, arg_7_2)
					end
				else
					var_7_0:SetRotateInfo(nil, var_7_6, arg_7_2)
				end

				if var_6_14 == BattleShrapnelBulletFactory.INHERIT_VELOCITY_TEMPLATE then
					var_7_0:ResetVelocity(var_6_0:GetVelocity())
				elseif var_6_14 == BattleShrapnelBulletFactory.INHERIT_VELOCITY_CURRENT then
					var_7_0:InheritSpeed(var_6_0:GetSpeed())
				end

				BattleShrapnelBulletFactory.GetFactoryList()[var_7_0:GetTemplate().type]:CreateBullet(arg_6_0:GetTf(), var_7_0, arg_6_0:GetPosition())
			end

			local var_6_18

			local function var_6_19()
				var_6_18:Destroy()
				var_6_0:SplitFinishCount()

				if var_6_0:IsAllSplitFinish() then
					var_6_1:RemoveBulletUnit(var_6_0:GetUniqueID())
				end
			end

			var_6_18 = ys.Battle[var_6_12].New(var_6_17, var_6_19, var_6_10)

			var_6_0:CacheChildEimtter(var_6_18)
			var_6_18:Ready()
			var_6_18:Fire(nil, var_6_5:GetDirection(), ys.Battle.BattleDataFunction.GetBarrageTmpDataFromID(var_6_10).angle)
		end
	end

	if arg_6_1 then
		var_6_0:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_FINAL_SPLIT)
	end
end

function BattleShrapnelBulletFactory.onBulletMissFunc(arg_9_0)
	return
end

function BattleShrapnelBulletFactory.MakeModel(self, bulletView, arg_10_2, arg_10_3, arg_10_4)
	local var_10_0 = bulletView:GetBulletData()

	if not self:GetBulletPool():InstBullet(bulletView:GetModleID(), function(arg_11_0)
		bulletView:AddModel(arg_11_0)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(arg_10_2)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end

function BattleShrapnelBulletFactory.OutRangeFunc(arg_12_0)
	if arg_12_0:IsOutRange() then
		arg_12_0:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_SPIN)
	else
		arg_12_0:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_SPLIT)
	end
end
