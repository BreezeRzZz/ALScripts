local BattleDataProxy = ys.Battle.BattleDataProxy
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable

function BattleDataProxy.SetupCalculateDamage(self, calculateFunc)
	self._calculateDamage = calculateFunc or BattleFormulas.CreateContextCalculateDamage()
end

function BattleDataProxy.SetupDamageKamikazeAir(self, calculateFunc)
	self._calculateDamageKamikazeAir = calculateFunc or BattleFormulas.CalculateDamageFromAircraftToMainShip
end

function BattleDataProxy.SetupDamageKamikazeShip(self, calculateFunc)
	self._calculateDamageKamikazeShip = calculateFunc or BattleFormulas.CalculateDamageFromShipToMainShip
end

function BattleDataProxy.SetupDamageCrush(self, calculateFunc)
	self._calculateDamageCrush = calculateFunc or BattleFormulas.CalculateCrashDamage
end

function BattleDataProxy.ClearFormulas(self)
	self._calculateDamage = nil
	self._calculateDamageKamikazeAir = nil
	self._calculateDamageKamikazeShip = nil
	self._calculateDamageCrush = nil
end

-- 处理子弹命中(仅碰撞系统相关)
-- 被BattleCldSystem.HandleBulletCldWithAircraft和BattleCldSystem.HandleBulletCldWithShip调用
function BattleDataProxy.HandleBulletHit(self, bullet, ship)
	if not ship then
		assert(false, "HandleBulletHit, but no vehicleData")

		return false
	elseif not bullet then
		assert(false, "HandleBulletHit, but no bulletData")

		return false
	end
	-- 灵体不处理
	if BattleAttr.IsSpirit(ship) then
		return false
	end
	-- 只判定未碰撞过的，仅一次
	-- 因此不会重复触发碰撞判定
	if bullet:IsCollided(ship:GetUniqueID()) == true then
		return
	end
	-- 调用子弹的命中(碰撞)函数
	bullet:Hit(ship:GetUniqueID(), ship:GetUnitType())

	local args = {
		_bullet = bullet,
		equipIndex = bullet:GetWeapon():GetEquipmentIndex(),
		bulletTag = bullet:GetExtraTag()
	}

	bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_COLLIDE, args)

	if ship:GetUnitType() == BattleConst.UnitType.PLAYER_UNIT and ship:GetIFF() == BattleConfig.FRIENDLY_CODE then
		ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[BattleConst.ShakeType.HIT])
	end

	return true
end

-- 常规伤害处理函数(核心逻辑)
-- 常规伤害指的是，需要用子弹实体参与计算的伤害
	-- 与之相对的就是下面的HandleDirectDamage，不需要子弹实体参与计算
-- 举例：在BattleDataProxy.updateLoop中被调用，在各子弹工厂的onBulletHitFunc中也有调用
-- 被很多地方调用，主要的调用点是各个BulletFactory的onBulletHitFunc(典型的cannonBulletFactory/TorpedoBulletFactory)或OutRangeFunc(典型的BombBulletFactory)
function BattleDataProxy.HandleDamage(self, bullet, target, damageReduceDistance, meteoDamageRatio)
	-- isShowHPBar的本质是BattleEnemyUnit.IsShowHPBar, 只需要IFF不为友方
	if target:GetIFF() == BattleConfig.FOE_CODE and target:IsShowHPBar() then
		self:DispatchEvent(ys.Event.New(BattleEvent.HIT_ENEMY, target))
	end

	local weapon = bullet:GetWeapon()
	local weaponHostAttr = bullet:GetWeaponHostAttr()
	local extraTag = bullet:GetExtraTag()
	local weaponTemplate = weapon:GetTemplateData()
	local args = {
		weaponType = weaponTemplate.attack_attribute,
		bulletType = bullet:GetType(),
		bulletTag = extraTag
	}

	target:TriggerBuff(BattleConst.BuffEffectType.ON_BULLET_HIT_BEFORE, args)
	-- 检查isInvincible属性
	if BattleAttr.IsInvincible(target) then
		return
	end

	local damage, extraInfo, damageFont = self._calculateDamage(bullet, target, damageReduceDistance, meteoDamageRatio)
	local isMiss = extraInfo.isMiss
	local isCri = extraInfo.isCri
	local damageAttr = extraInfo.damageAttr

	bullet:AppendDamageUnit(target:GetUniqueID())

	local weaponType = weaponTemplate.type
	local equipIndex = weapon:GetEquipmentIndex()
	local bulletHitArgs = {
		target = target,
		damage = damage,
		weaponType = weaponType,
		equipIndex = equipIndex,
		bulletTag = extraTag
	}
	local updateHPArgs = {
		isHeal = false,
		isMiss = isMiss,
		isCri = isCri,
		attr = damageAttr,
		font = damageFont,
		cldPos = bullet:GetPosition(),
		srcID = weaponHostAttr.hostUID or weaponHostAttr.battleUID
	}

	bullet:GetWeapon():WeaponStatistics(damage, isCri, isMiss)

	local dHP = target:UpdateHP(damage * -1, updateHPArgs)

	self:DamageStatistics(weaponHostAttr.id, target:GetAttrByName("id"), -dHP)

	if not isMiss and bullet:GetWeaponTempData().type ~= BattleConst.EquipmentType.ANTI_AIR then
		bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_HIT, bulletHitArgs)

		local host = bullet:GetHost()

		if host and host:IsAlive() and host:GetUnitType() ~= ys.Battle.BattleConst.UnitType.AIRFIGHTER_UNIT then
			if table.contains(BattleConst.AircraftUnitType, host:GetUnitType()) then
				host = host:GetMotherUnit()
			end

			local hostIFF = host:GetIFF()

			for _, unit in pairs(self._unitList) do
				if unit:GetIFF() == hostIFF and unit ~= host then
					unit:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_TEAMMATE_BULLET_HIT, bulletHitArgs)
				end
			end
		end
	end

	local targetUnitType = target:GetUnitType()
	local isAircraft = true

	if targetUnitType ~= BattleConst.UnitType.AIRCRAFT_UNIT and targetUnitType ~= BattleConst.UnitType.AIRFIGHTER_UNIT and targetUnitType ~= BattleConst.UnitType.FUNNEL_UNIT and targetUnitType ~= BattleConst.UnitType.UAV_UNIT then
		isAircraft = false
	end

	if target:IsAlive() then
		if not isAircraft then
			for _, attachBuff in ipairs(bullet:GetAttachBuff()) do
				if attachBuff.hit_ignore or not isMiss then
					BattleDataProxy.HandleBuffPlacer(attachBuff, bullet, target)
				end
			end
		end

		if not isMiss then
			target:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, args)
		end
	else
		bullet:BuffTrigger(ys.Battle.BattleConst.BuffEffectType.ON_BULLET_KILL, {
			unit = target,
			killer = bullet
		})
		-- 亡语
		self:obituary(target, isAircraft, bullet)
		self:KillCountStatistics(weaponHostAttr.id, target:GetAttrByName("id"))
	end

	return isMiss, isCri
end

-- 处理防空伤害(分配)
-- 主要是AntiAirBulletFactory调用
-- 值得注意的是本质是依赖子弹的HandleDamage，尽管这类子弹全是隐形的，总之逻辑上是常规伤害
function BattleDataProxy.HandleMeteoDamage(self, bullet, candidateList)
	local meteoDamageRatio = BattleFormulas.GetMeteoDamageRatio(#candidateList)

	for index, candidate in ipairs(candidateList) do
		self:HandleDamage(bullet, candidate, nil, meteoDamageRatio[index])
	end
end

-- DOT、防空伤害等使用，不需要子弹. 此外, 也不需要经过伤害计算公式, 直接对目标造成伤害
-- 如下面的各种ShipMissDamage和AircraftMissDamage也是DirectDamage
function BattleDataProxy.HandleDirectDamage(self, target, damage, caster, damageReason, isReflect)
	local srcID

	if caster then
		srcID = caster:GetAttrByName("id")
	end

	local extraInfo = {
		isMiss = false,
		isCri = false,
		isHeal = false,
		damageReason = damageReason,
		srcID = srcID,
		isReflect = isReflect
	}
	local targetID = target:GetAttrByName("id")
	local targetDHP = target:UpdateHP(damage * -1, extraInfo)
	local isTargetAlive = target:IsAlive()

	self:DamageStatistics(srcID, targetID, -targetDHP)

	if not isTargetAlive and srcID then
		self:KillCountStatistics(srcID, targetID)
	end

	if not isTargetAlive then
		local targetUnitType = target:GetUnitType()
		local isAircraft = true

		if targetUnitType ~= BattleConst.UnitType.AIRCRAFT_UNIT and targetUnitType ~= BattleConst.UnitType.AIRFIGHTER_UNIT and targetUnitType ~= BattleConst.UnitType.FUNNEL_UNIT and targetUnitType ~= BattleConst.UnitType.UAV_UNIT then
			isAircraft = false
		end

		self:obituary(target, isAircraft, caster)
	end
end

-- 亡语，主要是触发各种死亡时的BuffEffect
function BattleDataProxy.obituary(self, unit, isAircraft, caster)
	for _, _unit in pairs(self._unitList) do
		-- 对于每个不是unit本身的单位，都触发相应的BuffEffect
		if _unit ~= unit then
			if _unit:GetIFF() == unit:GetIFF() then
				if isAircraft then
					_unit:TriggerBuff(BattleConst.BuffEffectType.ON_FRIENDLY_AIRCRAFT_DYING, {
						unit = unit,
						killer = caster
					})
				elseif not unit:GetWorldDeathMark() then
					_unit:TriggerBuff(BattleConst.BuffEffectType.ON_TEAMMATE_SHIP_DYING, {
						unit = unit,
						killer = caster
					})
				end
			elseif isAircraft then
				_unit:TriggerBuff(BattleConst.BuffEffectType.ON_FOE_AIRCRAFT_DYING, {
					unit = unit,
					killer = caster
				})
			else
				_unit:TriggerBuff(BattleConst.BuffEffectType.ON_FOE_DYING, {
					unit = unit,
					killer = caster
				})
			end
		end
	end
end


--- @class BattleDataProxy
--- @param aircraft BattleAircraftUnit
--- @param fleet BattleFleetVO
--- @return nil
--- 舰载机触底伤害主逻辑
function BattleDataProxy.HandleAircraftMissDamage(self, aircraft, fleet)
	if fleet == nil then
		return
	end
	-- 只包含轻航/正航/导驱M
	local cloakList = fleet:GetCloakList()
	-- 对全体轻航/正航/导驱M添加暴露值
	for _, cloakUnit in ipairs(cloakList) do
		cloakUnit:CloakExpose(self._airExpose)
	end

	local aircraftPos = aircraft:GetPosition()
	local nearestUnit = fleet:NearestUnitByType(aircraftPos, ShipType.CloakShipTypeList)
	-- 对离舰载机最近的轻航/正航/导驱M添加额外的暴露值
	if nearestUnit then
		nearestUnit:CloakExpose(self._airExposeEX)
	end
	-- 等概率随机选择一个后排造成伤害
	local victim = fleet:RandomMainVictim({
		"immuneDirectHit"
	})

	if victim then
		local damage = self._calculateDamageKamikazeAir(aircraft, victim)

		victim:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
		self:HandleDirectDamage(victim, damage, aircraft)
	end
end

-- 舰船触底伤害主逻辑(又可细分为潜艇和水面舰船)
-- 被BattleDataProxy.updateLoop调用
function BattleDataProxy.HandleShipMissDamage(self, ship, fleet)
	if fleet == nil then
		return
	end

	local cloakList = fleet:GetCloakList()

	for _, cloakUnit in ipairs(cloakList) do
		cloakUnit:CloakExpose(self._shipExpose)
	end

	local shipPos = ship:GetPosition()
	local nearestUnit = fleet:NearestUnitByType(shipPos, ShipType.CloakShipTypeList)

	if nearestUnit then
		nearestUnit:CloakExpose(self._shipExposeEX)
	end

	local victim = fleet:RandomMainVictim({
		"immuneDirectHit"
	})

	if victim then
		local shipType = ship:GetTemplate().type
		-- 如果触底的船(攻击者)是潜艇
		if table.contains(ShipType.SubShipType, shipType) then
			local subKamikazeDamage = BattleFormulas.CalculateDamageFromSubmarinToMainShip(ship, victim)
			-- 触底也算被命中，触发被命中BuffEffect
			victim:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
			self:HandleDirectDamage(victim, subKamikazeDamage, ship)
			-- 潜艇触底会额外有概率，再次对同一目标造成伤害
			-- (根据公式，这个概率最大不超过15%)
			if victim:IsAlive() and BattleFormulas.RollSubmarineDualDice(ship) then
				local subKamikazeDamage2 = BattleFormulas.CalculateDamageFromSubmarinToMainShip(ship, victim)

				victim:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
				self:HandleDirectDamage(victim, subKamikazeDamage2, ship)
			end
		else
			local shipKamikazeDamage = self._calculateDamageKamikazeShip(ship, victim)

			victim:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
			self:HandleDirectDamage(victim, shipKamikazeDamage, ship)
		end
	end
end

-- 处理舰船碰撞伤害的核心逻辑
function BattleDataProxy.HandleCrashDamage(self, ship1, ship2)
	local ship1CrashDamage, ship2CrashDamage = self._calculateDamageCrush(ship1, ship2)

	self:HandleDirectDamage(ship1, ship1CrashDamage, ship2, BattleConst.UnitDeathReason.CRUSH)
	self:HandleDirectDamage(ship2, ship2CrashDamage, ship1, BattleConst.UnitDeathReason.CRUSH)
end

-- 处理子弹附加Buff的触发
-- 被BattleDataProxy.HandleDamage调用
-- 注意点是，附加Buff是在伤害结算之后
-- 所以这颗上Buff的子弹自己吃不到附加Buff的效果
-- 另外，这是个类静态函数(从调用方式上看)，不依赖于BattleDataProxy实例
function BattleDataProxy.HandleBuffPlacer(attachBuff, bullet, target)
	local buffEffectList = BattleDataFunction.GetBuffTemplate(attachBuff.buff_id).effect_list
	local rantHappened = false
	-- 所以DOT一定是第一个效果(不然逻辑就有问题了)
	if buffEffectList[1].type == "BattleBuffDOT" then
		if BattleFormulas.CaclulateDOTPlace(attachBuff.rant, buffEffectList[1], bullet, target) then
			rantHappened = true
		end
	elseif BattleFormulas.IsHappen(attachBuff.rant or 10000) then
		rantHappened = true
	end

	if rantHappened then
		local buffLevel = attachBuff.buff_level or attachBuff.level
		local buff = ys.Battle.BattleBuffUnit.New(attachBuff.buff_id, buffLevel, bullet)

		buff:SetGroupLevel(attachBuff.group_level)
		buff:SetOrb(bullet, attachBuff.level)
		target:AddBuff(buff)
	end
end

-- 这个函数没用过，应该是BattleFormulas.CaclulateDOTPlace的旧版，不管了
function BattleDataProxy.HandleDOTPlace(arg_15_0, arg_15_1, arg_15_2)
	local var_15_0 = arg_15_0.arg_list
	local var_15_1 = BattleConfig.DOT_CONFIG[var_15_0.dotType]
	local var_15_2 = arg_15_1:GetAttrByName(var_15_1.hit)

	if BattleFormulas.IsHappen(var_15_0.ACC + arg_15_1:GetAttrByName(var_15_1.hit) - arg_15_2:GetAttrByName(var_15_1.resist)) then
		return true
	end

	return false
end

-- TODO
-- 处理舰船碰撞的伤害分配
-- 被BattleCldSystem.HandlePlayerShipCld调用
function BattleDataProxy.HandleShipCrashDamageList(arg_16_0, arg_16_1, arg_16_2)
	local var_16_0 = arg_16_1:GetHostileCldList()

	for iter_16_0, iter_16_1 in pairs(var_16_0) do
		if not table.contains(arg_16_2, iter_16_0) then
			arg_16_1:RemoveHostileCld(iter_16_0)
		end
	end

	for iter_16_2, iter_16_3 in ipairs(arg_16_2) do
		if var_16_0[iter_16_3] == nil then
			local var_16_1

			local function var_16_2()
				arg_16_0:HandleCrashDamage(arg_16_0._unitList[iter_16_3], arg_16_1)
			end

			local var_16_3 = pg.TimeMgr.GetInstance():AddBattleTimer("shipCld", nil, BattleConfig.SHIP_CLD_INTERVAL, var_16_2, true)

			arg_16_1:AppendHostileCld(iter_16_3, var_16_3)
			var_16_2()

			if not arg_16_1:IsAlive() then
				break
			end
		end
	end
end

function BattleDataProxy.HandleShipCrashDecelerate(arg_18_0, arg_18_1, arg_18_2)
	if arg_18_2 == 0 and arg_18_1:IsCrash() then
		arg_18_1:SetCrash(false)
	elseif arg_18_2 > 0 and not arg_18_1:IsCrash() then
		arg_18_1:SetCrash(true)
	end
end

function BattleDataProxy.HandleWallHitByBullet(arg_19_0, arg_19_1, arg_19_2)
	return (arg_19_1:GetCldFunc()(arg_19_2))
end

function BattleDataProxy.HandleWallHitByShip(arg_20_0, arg_20_1, arg_20_2)
	arg_20_1:GetCldFunc()(arg_20_2)
end

-- 被BattleBuffDamageWall调用，处理伤害墙对单位的伤害
function BattleDataProxy.HandleWallDamage(self, damageWall, target)
	if target:GetIFF() == BattleConfig.FOE_CODE and target:IsShowHPBar() then
		self:DispatchEvent(ys.Event.New(BattleEvent.HIT_ENEMY, target))
	end

	local damageWallID = BattleAttr.GetCurrent(damageWall, "id")

	if BattleAttr.IsInvincible(target) then
		return
	end

	-- damageWall作为一种抽象子弹(虽然并不具备真正子弹的很多属性)，在这里被用来调用CalculateDamage函数来计算伤害
	local damage, extraInfo, damageFont = self._calculateDamage(damageWall, target)
	local isMiss = extraInfo.isMiss
	local isCri = extraInfo.isCri
	local damageAttr = extraInfo.damageAttr
	local updateHPArgs = {
		isHeal = false,
		isMiss = isMiss,
		isCri = isCri,
		attr = damageAttr,
		font = damageFont,
		cldPos = damageWall:GetPosition(),
		srcID = damageWallID
	}
	local dHP = target:UpdateHP(damage * -1, updateHPArgs)

	self:DamageStatistics(damageWallID, target:GetAttrByName("id"), -dHP)

	if target:IsAlive() then
		if not isMiss then
			target:TriggerBuff(BattleConst.BuffEffectType.ON_BE_HIT, {})
		end
	else
		self:obituary(target, false, damageWall)
		self:KillCountStatistics(damageWallID, target:GetAttrByName("id"))
	end

	return isMiss, isCri
end
