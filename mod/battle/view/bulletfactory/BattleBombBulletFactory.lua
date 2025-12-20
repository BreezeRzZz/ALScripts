ys = ys or {}

local ys = ys

ys.Battle.BattleBombBulletFactory = singletonClass("BattleBombBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleBombBulletFactory.__name = "BattleBombBulletFactory"

local BattleBombBulletFactory = ys.Battle.BattleBombBulletFactory

function BattleBombBulletFactory.Ctor(arg_1_0)
	BattleBombBulletFactory.super.Ctor(arg_1_0)
end

-- TODO
-- 炸弹类子弹的伤害结算流程
function BattleBombBulletFactory.OutRangeFunc(arg_2_0)
	local var_2_0 = arg_2_0:GetTemplate()
	local var_2_1 = var_2_0.hit_type
	local var_2_2 = BattleBombBulletFactory.GetDataProxy()
	local var_2_3 = var_2_0.extra_param
	local var_2_4 = arg_2_0:GetDiveFilter()
	local var_2_5 = {
		_bullet = arg_2_0,
		equipIndex = arg_2_0:GetWeapon():GetEquipmentIndex(),
		bulletTag = arg_2_0:GetExtraTag()
	}

	arg_2_0:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BOMB_BULLET_BANG, var_2_5)

	if var_2_3.directDMG then
		local var_2_6 = var_2_3.buff_id
		local var_2_7 = var_2_3.buff_level or 1
		local var_2_8 = var_2_3.area_FX or var_2_0.hit_fx

		local function var_2_9(arg_3_0)
			if arg_2_0:CanDealDamage() then
				for iter_3_0, iter_3_1 in ipairs(arg_3_0) do
					if iter_3_1.Active then
						local var_3_0 = iter_3_1.UID
						local var_3_1 = BattleBombBulletFactory.GetSceneMediator():GetCharacter(var_3_0):GetUnitData()
						local var_3_2 = ys.Battle.BattleBuffUnit.New(var_2_6, var_2_7)

						var_3_1:AddBuff(var_3_2)
						var_2_2:HandleDirectDamage(var_3_1, var_2_3.directDMG, arg_2_0)
					end
				end

				arg_2_0:DealDamage()
			end
		end

		local function var_2_10(arg_4_0)
			if arg_4_0.Active then
				BattleBombBulletFactory:GetSceneMediator():GetCharacter(arg_4_0.UID):GetUnitData():RemoveBuff(var_2_6)
			end
		end

		local function var_2_11(arg_5_0)
			for iter_5_0, iter_5_1 in ipairs(arg_5_0) do
				if iter_5_1.Active then
					local var_5_0 = BattleBombBulletFactory:GetSceneMediator():GetCharacter(iter_5_1.UID):GetUnitData()

					if var_5_0:IsAlive() then
						var_5_0:RemoveBuff(var_2_6)
					end
				end
			end

			var_2_2:RemoveBulletUnit(arg_2_0:GetUniqueID())
		end

		var_2_2:SpawnLastingColumnArea(arg_2_0:GetEffectField(), arg_2_0:GetIFF(), arg_2_0:GetExplodePostion(), var_2_1.range, var_2_1.time, var_2_9, var_2_10, false, var_2_8, var_2_11, true):SetDiveFilter(var_2_4)
		arg_2_0:HideBullet()
	else
		local var_2_12

		local function var_2_13(arg_6_0)
			local var_6_0 = var_2_1.decay

			if var_6_0 then
				var_2_12:UpdateDistanceInfo()
			end

			for iter_6_0, iter_6_1 in ipairs(arg_6_0) do
				if iter_6_1.Active then
					local var_6_1 = iter_6_1.UID
					local var_6_2 = 0

					if var_6_0 then
						var_6_2 = var_2_12:GetDistance(var_6_1) / (var_2_1.range * 0.5) * var_6_0
					end

					local var_6_3 = BattleBombBulletFactory.GetSceneMediator():GetCharacter(var_6_1):GetUnitData()

					var_2_2:HandleDamage(arg_2_0, var_6_3, var_6_2)
				end
			end
		end

		var_2_12 = var_2_2:SpawnColumnArea(arg_2_0:GetEffectField(), arg_2_0:GetIFF(), arg_2_0:GetExplodePostion(), var_2_1.range, var_2_1.time, var_2_13)

		var_2_12:SetDiveFilter(var_2_4)

		if var_2_3.friendlyFire then
			var_2_2:SpawnColumnArea(arg_2_0:GetEffectField(), var_2_2.GetOppoSideCode(arg_2_0:GetIFF()), arg_2_0:GetExplodePostion(), var_2_1.range, var_2_1.time, var_2_13):SetDiveFilter(var_2_4)
		end

		var_2_12:SetIndiscriminate(var_2_3.indiscriminate)
		var_2_2:RemoveBulletUnit(arg_2_0:GetUniqueID())
	end
end

function BattleBombBulletFactory.MakeBullet(arg_7_0)
	return ys.Battle.BattleBombBullet.New()
end

function BattleBombBulletFactory.onBulletHitFunc(arg_8_0, arg_8_1, arg_8_2)
	local var_8_0 = arg_8_0:GetBulletData()
	local var_8_1 = var_8_0:GetTemplate()

	ys.Battle.PlayBattleSFX(var_8_0:GetHitSFX())

	local var_8_2, var_8_3 = BattleBombBulletFactory.GetFXPool():GetFX(arg_8_0:GetFXID())
	local var_8_4 = pg.Tool.FilterY(var_8_0:GetPosition())

	pg.EffectMgr.GetInstance():PlayBattleEffect(var_8_2, var_8_4:Add(var_8_3), true)
end

function BattleBombBulletFactory.onBulletMissFunc()
	return
end
-- TODO
function BattleBombBulletFactory.MakeModel(self, bulletView, position)
	local bullet = bulletView:GetBulletData()
	local explodePosition = bullet:GetExplodePostion()
	local totalUpperBound, _, _, _ = self:GetDataProxy():GetTotalBounds()
	-- 爆炸点过高，直接移除子弹
	-- 这一步在实际创建子弹的视觉模型前进行，可以避免不必要的资源开销
	if explodePosition.z > totalUpperBound + 3 then
		self:GetDataProxy():RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local bulletTemplate = bullet:GetTemplate()

	if not self:GetBulletPool():InstBullet(bulletView:GetModleID(), function(go)
		bulletView:AddModel(go)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end
	-- TODO
	bulletView:SetSpawn(position)

	if bullet:GetIFF() ~= self:GetDataProxy():GetFriendlyCode() and bullet:GetExist() and bulletTemplate.alert_fx ~= "" then
		BattleBombBulletFactory.CreateBulletAlert(bullet)
	end

	bullet:SetExist(true)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end

function BattleBombBulletFactory.CreateBulletAlert(arg_12_0)
	local var_12_0 = arg_12_0:GetTemplate().hit_type.range
	local var_12_1 = arg_12_0:GetTemplate().alert_fx
	local var_12_2 = ys.Battle.BattleFXPool.GetInstance():GetFX(var_12_1)
	local var_12_3 = var_12_2.transform
	local var_12_4 = 0
	local var_12_5 = pg.effect_offset

	if var_12_5[var_12_1] and var_12_5[var_12_1].y_scale == true then
		var_12_4 = var_12_0
	end

	var_12_3.localScale = Vector3(var_12_0, var_12_4, var_12_0)

	pg.EffectMgr.GetInstance():PlayBattleEffect(var_12_2, arg_12_0:GetExplodePostion())
end
