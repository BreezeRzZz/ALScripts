ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local AircraftUnitType = ys.Battle.BattleConst.AircraftUnitType
local CharacterUnitType = ys.Battle.BattleConst.CharacterUnitType

ys.Battle.BattleShrapnelBulletFactory = singletonClass("BattleShrapnelBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleShrapnelBulletFactory.__name = "BattleShrapnelBulletFactory"

local BattleShrapnelBulletFactory = ys.Battle.BattleShrapnelBulletFactory

-- 角度继承模式
BattleShrapnelBulletFactory.INHERIT_NONE = 0               -- 不继承角度
BattleShrapnelBulletFactory.INHERIT_ANGLE = 1               -- 继承母弹发射角度
BattleShrapnelBulletFactory.INHERIT_SPEED_NORMALIZE = 2     -- 继承母弹当前运动方向
-- 速度继承模式
BattleShrapnelBulletFactory.INHERIT_VELOCITY_TEMPLATE = 1   -- 重设速度为模板速度
BattleShrapnelBulletFactory.INHERIT_VELOCITY_CURRENT = 2    -- 继承母弹当前速度大小
-- 易碎模式（fragile）
BattleShrapnelBulletFactory.FRAGILE_DAMAGE_NOT_SPLIT = 1    -- 造成伤害但不分裂
BattleShrapnelBulletFactory.FRAGILE_NOT_DAMAGE_NOT_SPLIT = 2 -- 不造成伤害也不分裂（直接消失）

--- 构造函数
function BattleShrapnelBulletFactory.Ctor(self)
	BattleShrapnelBulletFactory.super.Ctor(self)
end

--- 创建Shrapnel类型BulletUnit View
--- @return BattleShrapnelBullet
function BattleShrapnelBulletFactory.MakeBullet(self)
	return ys.Battle.BattleShrapnelBullet.New()
end

--- 创建Shrapnel子弹视图
--- 与父类CreateBullet类似，但额外处理：
--- 1. 非rangeAA类型：创建时立即触发bulletSplit（初始分裂）
--- 2. rangeAA类型：延期到命中时触发areaSplit
--- @param tf Transform
--- @param bullet BattleShrapnelBulletUnit
--- @param position Vector3
--- @param fxID string
--- @param direction number
--- @return BattleShrapnelBullet
function BattleShrapnelBulletFactory.CreateBullet(self, tf, bullet, position, fxID, direction)
	bullet:SetOutRangeCallback(self.OutRangeFunc)

	local bulletView = self:MakeBullet()

	bulletView:SetFactory(self)
	bulletView:SetBulletData(bullet)
	self:MakeModel(bulletView, position, fxID, direction)

	if fxID and fxID ~= "" then
		self:PlayFireFX(tf, bullet, position, fxID, direction, nil)
	end

	-- 非rangeAA类型：创建时立即进行初始分裂
	if not bullet:GetTemplate().extra_param.rangeAA then
		BattleShrapnelBulletFactory.bulletSplit(bulletView)
	end

	return bulletView
end

--- Shrapnel命中回调
--- 复杂的命中状态机，根据子弹当前状态和extra_param配置决定行为：
--- - fragile模式：命中后不分裂（造成伤害或直接消失）
--- - STATE_SPLIT / STATE_SPIN：正在分裂/旋转中，跳过伤害
--- - STATE_FINAL_SPLIT：最终阶段，跳过
--- - 有穿透次数：走普通炮弹命中逻辑
--- - 其余情况：命中特效 + 分裂
---
--- @param uid number 命中单位UID
--- @param unitType number 单位类型
function BattleShrapnelBulletFactory.onBulletHitFunc(self, uid, unitType)
	local dataProxy = BattleShrapnelBulletFactory.GetDataProxy()
	local bullet = self:GetBulletData()
	local currentState = bullet:GetCurrentState()
	local bulletTemplate = bullet:GetTemplate()
	local shrapnel = bulletTemplate.extra_param.shrapnel
	local fragile = bulletTemplate.extra_param.fragile
	local hitSplitOnly = bulletTemplate.extra_param.hitSplitOnly

	-- hitSplitOnly模式：未命中任何单位时直接移除子弹
	if not uid and hitSplitOnly then
		dataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	-- fragile模式：命中时根据fragile值决定是否分裂
	if fragile and uid then
		if fragile == BattleShrapnelBulletFactory.FRAGILE_DAMAGE_NOT_SPLIT then
			-- 仅造成伤害（走普通炮弹逻辑），不分裂
			ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(self, uid, unitType)
		elseif fragile == BattleShrapnelBulletFactory.FRAGILE_NOT_DAMAGE_NOT_SPLIT then
			-- 直接消失，无伤害也不分裂
			dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
		end

		return
	end

	-- 根据子弹状态决定是否处理伤害
	-- SPLIT/SPIN状态：正在进行分裂/旋转动画，不结算伤害
	if currentState == bullet.STATE_SPLIT or currentState == bullet.STATE_SPIN then
		-- 空块：延迟到动画完成后再处理
	-- FINAL_SPLIT状态：已完成最终分裂，直接返回
	elseif currentState == bullet.STATE_FINAL_SPLIT then
		return
	-- 普通状态且有穿透次数：走普通炮弹命中逻辑
	elseif bullet:GetPierceCount() > 0 then
		ys.Battle.BattleCannonBulletFactory.onBulletHitFunc(self, uid, unitType)

		return
	end

	-- 播放命中特效（在命中单位上添加FX，敌方单位翻转朝向）
	if uid ~= nil and unitType ~= nil then
		local character

		if table.contains(AircraftUnitType, unitType) then
			character = BattleShrapnelBulletFactory.GetSceneMediator():GetAircraft(uid)
		elseif table.contains(CharacterUnitType, unitType) then
			character = BattleShrapnelBulletFactory.GetSceneMediator():GetCharacter(uid)
		end

		local unit = character:GetUnitData()
		local fx = character:AddFX(self:GetFXID())

		-- 敌方单位：翻转特效Y轴
		if unit:GetIFF() == dataProxy:GetFoeCode() then
			local tf = fx.transform
			local localRotation = tf.localRotation

			tf.localRotation = Vector3(localRotation.x, 180, localRotation.z)
		end
	end

	ys.Battle.PlayBattleSFX(bullet:GetHitSFX())

	-- 根据rangeAA决定分裂方式
	if bulletTemplate.extra_param.rangeAA then
		-- 范围分裂：由WeaponUnit执行DoAreaSplit
		BattleShrapnelBulletFactory.areaSplit(self)
	else
		-- 普通子弹分裂：从shrapnel配置生成子子弹
		BattleShrapnelBulletFactory.bulletSplit(self, true)
	end
end

--- 范围分裂（防空弹）
--- 委托给WeaponUnit.DoAreaSplit处理（仅BattleFleetRangeAntiAirUnit有此方法）
--- @param self BattleShrapnelBullet View层子弹
function BattleShrapnelBulletFactory.areaSplit(self)
	local dataProxy = BattleShrapnelBulletFactory.GetDataProxy()
	local bullet = self:GetBulletData()

	bullet:GetWeapon():DoAreaSplit(bullet)
	dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
end

--- 子弹分裂：从母弹的shrapnel配置生成子子弹
--- 这是shrapnel子弹的核心机制 —— 在母弹碰撞点创建多个子子弹发射器
--- 每个shrapnel项可配置：
--- - bullet_ID：子子弹模板ID
--- - barrage_ID：弹幕模板ID
--- - emitterType：发射器类型（默认SHOTGUN）
--- - inheritAngle：角度继承模式
--- - inheritSpeed：速度继承模式
--- - reaim：是否重新瞄准目标
--- - rotateOffset：是否根据母弹角度旋转偏移
--- - initialSplit：是否为初始分裂（false则hitSplit时触发）
--- - damage：覆盖标伤值
---
--- @param self BattleShrapnelBullet View层子弹
--- @param hitSplit boolean 是否由命中触发（true）还是初始分裂（nil/false）
function BattleShrapnelBulletFactory.bulletSplit(self, hitSplit)
	local bullet = self:GetBulletData()
	local dataProxy = BattleShrapnelBulletFactory.GetDataProxy()
	local bulletTemplate = bullet:GetTemplate()
	local shrapnel = bulletTemplate.extra_param.shrapnel
	local srcHost = bullet:GetSrcHost()
	local weapon = bullet:GetWeapon()

	-- 播放分裂特效FXID
	if bulletTemplate.extra_param.FXID ~= nil then
		local fx, fxPosition = BattleShrapnelBulletFactory.GetFXPool():GetFX(bulletTemplate.extra_param.FXID)

		pg.EffectMgr.GetInstance():PlayBattleEffect(fx, fxPosition:Add(self:GetPosition()), true)
	end

	-- 母弹的X轴方向角：正X速度=0度，负X速度=180度
	local axisAngle = bullet:GetSpeed().x > 0 and 0 or 180

	for index, shrapnelItem in ipairs(shrapnel) do
		-- initialSplit匹配：初始分裂只处理initialSplit=true的项，命中分裂只处理false的项
		if hitSplit ~= shrapnelItem.initialSplit then
			local barrageID = shrapnelItem.barrage_ID
			local bulletID = shrapnelItem.bullet_ID
			local emitterType = shrapnelItem.emitterType or ys.Battle.BattleWeaponUnit.EMITTER_SHOTGUN
			local inheritAngle = shrapnelItem.inheritAngle
			local inheritSpeed = shrapnelItem.inheritSpeed
			local reaim = shrapnelItem.reaim
			local rotateOffset = shrapnelItem.rotateOffset

			-- 单个子子弹的生成函数（由Emitter调用）
			local function spawnFunc(offsetX, offsetZ, barrageAngle, isOffsetPriority)
				local childBullet = dataProxy:CreateBulletUnit(bulletID, srcHost, weapon, Vector3.zero)

				-- 覆盖标伤
				childBullet:OverrideCorrectedDMG(shrapnelItem.damage)
				childBullet:SetOffsetPriority(isOffsetPriority)

				-- rotateOffset：根据母弹Y轴角度旋转偏移方向
				if rotateOffset then
					local distance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
					local angle = math.atan2(offsetZ, offsetX)
					local yAngle = math.rad(bullet:GetYAngle())
					local resAngle = angle + yAngle
					local cosAngle = math.abs(math.cos(yAngle))

					offsetX = distance * math.cos(resAngle) * (0.5 + 0.5 * cosAngle)
					offsetZ = distance * math.sin(resAngle) * (2 - cosAngle)
				end

				childBullet:SetShiftInfo(offsetX, offsetZ)

				local baseAngle = axisAngle

				-- 角度继承
				if inheritAngle == BattleShrapnelBulletFactory.INHERIT_ANGLE then
					baseAngle = bullet:GetYAngle()
				elseif inheritAngle == BattleShrapnelBulletFactory.INHERIT_SPEED_NORMALIZE then
					baseAngle = bullet:GetCurrentYAngle()
				end

				-- 重新瞄准：选择目标并设置旋转朝向
				if reaim then
					local target
					local host = bullet:GetWeapon():GetHost()

					if type(reaim) == "table" and host then
						-- 表格式：链式调用多个TargetChoise筛选函数
						local reaimParam = shrapnelItem.reaimParam
						local candidateList

						for targetIndex, targetType in ipairs(reaim) do
							candidateList = ys.Battle.BattleTargetChoise[targetType](host, reaimParam, candidateList)
						end

						target = candidateList[1]
					else
						-- 简单模式：选最近的目标
						target = ys.Battle.BattleTargetChoise.TargetHarmNearest(bullet)[1]
					end

					if target == nil then
						childBullet:SetRotateInfo(nil, baseAngle, barrageAngle)
					else
						childBullet:SetRotateInfo(target:GetBeenAimedPosition(), baseAngle, barrageAngle)
					end
				else
					childBullet:SetRotateInfo(nil, baseAngle, barrageAngle)
				end

				-- 速度继承
				if inheritSpeed == BattleShrapnelBulletFactory.INHERIT_VELOCITY_TEMPLATE then
					childBullet:ResetVelocity(bullet:GetVelocity())
				elseif inheritSpeed == BattleShrapnelBulletFactory.INHERIT_VELOCITY_CURRENT then
					childBullet:InheritSpeed(bullet:GetSpeed())
				end

				-- 通过工厂映射创建子子弹的视觉表现
				BattleShrapnelBulletFactory.GetFactoryList()[childBullet:GetTemplate().type]:CreateBullet(self:GetTf(), childBullet, self:GetPosition())
			end

			local emitter

			-- Emitter停止回调：所有子子弹发射完毕后销毁母弹
			local function stopFunc()
				emitter:Destroy()
				bullet:SplitFinishCount()

				if bullet:IsAllSplitFinish() then
					dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
				end
			end

			emitter = ys.Battle[emitterType].New(spawnFunc, stopFunc, barrageID)

			bullet:CacheChildEimtter(emitter)
			emitter:Ready()
			emitter:Fire(nil, weapon:GetDirection(), ys.Battle.BattleDataFunction.GetBarrageTmpDataFromID(barrageID).angle)
		end
	end

	-- 命中触发的分裂完成后，母弹切换到FINAL_SPLIT状态
	if hitSplit then
		bullet:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_FINAL_SPLIT)
	end
end

--- Shrapnel未命中回调（空实现）
function BattleShrapnelBulletFactory.onBulletMissFunc(self)
	return
end

--- 创建Shrapnel的视觉模型
--- @param bulletView BattleShrapnelBullet View层子弹
--- @param position Vector3
--- @param fxID string
--- @param direction number
function BattleShrapnelBulletFactory.MakeModel(self, bulletView, position, fxID, direction)
	local bullet = bulletView:GetBulletData()

	if not self:GetBulletPool():InstBullet(bulletView:GetModleID(), function(instGO)
		bulletView:AddModel(instGO)
	end) then
		bulletView:AddTempModel(self:GetTempGOPool():GetObject())
	end

	bulletView:SetSpawn(position)
	bulletView:SetFXFunc(self.onBulletHitFunc, self.onBulletMissFunc)
	self:GetSceneMediator():AddBullet(bulletView)
end

--- Shrapnel超出范围回调
--- - 如果是由边界触发出界（IsOutRange）：切换到SPIN状态（旋转分裂）
--- - 否则（主动分裂触发）：切换到SPLIT状态（直线分裂）
function BattleShrapnelBulletFactory.OutRangeFunc(self)
	if self:IsOutRange() then
		self:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_SPIN)
	else
		self:ChangeShrapnelState(ys.Battle.BattleShrapnelBulletUnit.STATE_SPLIT)
	end
end
