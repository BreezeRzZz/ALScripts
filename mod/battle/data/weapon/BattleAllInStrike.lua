ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr

ys.Battle.BattleAllInStrike = class("BattleAllInStrike")

local BattleAllInStrike = ys.Battle.BattleAllInStrike

BattleAllInStrike.__name = "BattleAllInStrike"
BattleAllInStrike.EMITTER_NORMAL = "BattleBulletEmitter"
BattleAllInStrike.EMITTER_SHOTGUN = "BattleShotgunEmitter"
BattleAllInStrike.STATE_DISABLE = "DISABLE"
BattleAllInStrike.STATE_READY = "READY"
BattleAllInStrike.STATE_PRECAST = "PRECAST"
BattleAllInStrike.STATE_PRECAST_FINISH = "STATE_PRECAST_FINISH"
BattleAllInStrike.STATE_ATTACK = "ATTACK"
BattleAllInStrike.STATE_OVER_HEAT = "OVER_HEAT"

-- AllInStrike是一个抽象概念
-- 有些时候会直接关联到Skill
--- @param skillID number: 技能ID
function BattleAllInStrike.Ctor(self, skillID)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._skill = ys.Battle.BattleSkillUnit.New(skillID)
	self._skillID = skillID
	self._reloadFacotrList = {}
	self._reloadBoostList = {}
	self._jammingTime = 0
end

--- 每帧更新装填
function BattleAllInStrike.Update(self)
	self:UpdateReload()
end

--- 更新装填进度
function BattleAllInStrike.UpdateReload(self)
	if self._CDstartTime and not self._jammingStartTime then
		if self:GetReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime() then
			self:handleCoolDown()
		else
			return
		end
	end
end

--- 清理技能
function BattleAllInStrike.Clear(self)
	self._skill:Clear()
end

--- 销毁事件监听
function BattleAllInStrike.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
end

-- BattleDataFunction.CreateAllInStrike调用
--- @param host BattleUnit: 宿主单位
function BattleAllInStrike.SetHost(self, host)
	self._host = host

	local boom

	self._hiveList = host:GetHiveList()

	for _, hive in ipairs(self._hiveList) do
		local hiveSkinID = hive:GetSkinID()

		if hiveSkinID then
			local bullet_name, derivate_bullet, derivate_torpedo, derivate_boom = BattleDataFunction.GetEquipSkin(hiveSkinID)

			if derivate_boom then
				boom = derivate_boom

				break
			end
		end
	end

	if boom and boom ~= "" then
		local skillEffectList = self._skill:GetSkillEffectList()

		for _, skillEffect in ipairs(skillEffectList) do
			if skillEffect.__name == ys.Battle.BattleSkillFire.__name then
				skillEffect:SetWeaponSkin(boom)
			end
		end
	end

	self:FlushTotalReload()
	self:FlushReloadMax(1)
end

-- 计算一次"空袭"所对应的总装填时间
-- "空袭"是对多个Hive构成的一次攻击的抽象概念
function BattleAllInStrike.FlushTotalReload(self)
	self._totalReload = BattleFormulas.CaclulateAirAssistReloadMax(self._hiveList)
end

--- 刷新最大装填时间
--- @param reloadFactor number: 装填因子
--- @return boolean|nil: 是否需要重新计算装填需求
function BattleAllInStrike.FlushReloadMax(self, reloadFactor)
	local totalReload = self._totalReload

	reloadFactor = reloadFactor or 1
	self._reloadMax = totalReload * reloadFactor

	if not self._CDstartTime or self._reloadRequire == 0 then
		return true
	end

	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	self._reloadRequire = ys.Battle.BattleWeaponUnit.FlushRequireByInverse(self, loadSpeed)

	self._allInWeaponVo:RefreshReloadingBar()
end

--- 添加装填因子
--- @param factorKey string: 因子键
--- @param factorValue number: 因子值
function BattleAllInStrike.AppendReloadFactor(self, factorKey, factorValue)
	self._reloadFacotrList[factorKey] = factorValue
end

--- 移除装填因子
--- @param factorKey string: 因子键
function BattleAllInStrike.RemoveReloadFactor(self, factorKey)
	if self._reloadFacotrList[factorKey] then
		self._reloadFacotrList[factorKey] = nil
	end
end

--- 获取装填因子列表
--- @return table: 装填因子列表
function BattleAllInStrike.GetReloadFactorList(self)
	return self._reloadFacotrList
end

--- 设置关联的AllInWeaponVO
--- @param weaponVO BattleAllInWeaponVO: 武器视图对象
function BattleAllInStrike.SetAllInWeaponVO(self, weaponVO)
	self._allInWeaponVo = weaponVO
	self._currentState = BattleAllInStrike.STATE_READY
end

--- 获取当前状态
--- @return string: 当前状态
function BattleAllInStrike.GetCurrentState(self)
	return self._currentState
end

--- 获取宿主单位
--- @return BattleUnit: 宿主
function BattleAllInStrike.GetHost(self)
	return self._host
end

--- 获取类型
--- @return number: 装备类型（AIR_ASSIST）
function BattleAllInStrike.GetType(self)
	return BattleConst.EquipmentType.AIR_ASSIST
end

-- AllInStrike的Fire函数(持续输出, 对应常驻武器)
-- 实际上可以看到，AllInStrike的Fire函数只是触发了各个Hive的SingleFire(因为本身是个抽象概念, 没有对应具体的武器, 也不是BattleWeaponUnit的子类)
--- @return boolean: 是否成功发射
function BattleAllInStrike.Fire(self)
	if self._host:IsCease() then
		return false
	else
		-- onAllInStrikeSteady: 已经Fire，但还没有实际进行SingleFire
		-- 这类BuffEffect的增益，本次攻击可以享受
		self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ALL_IN_STRIKE_STEADY, {})

		for _, hive in ipairs(self._hiveList) do
			hive:SingleFire()
		end

		self._skill:Cast(self._host)
		self._host:StrikeExpose()
		self._host:StateChange(ys.Battle.UnitState.STATE_ATTACK, "attack")
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_FIRE, {}))
		-- onAllInStrike: 在实际SingleFire之后触发
		-- 这类BuffEffect的增益，本次攻击不享受
		self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ALL_IN_STRIKE, {})
	end

	return true
end

--- 触发就绪时的Buff
function BattleAllInStrike.TriggerBuffOnReady(self)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_AIR_ASSIST_READY, {})
end

--- 单次发射（不触发onAllInStrikeSteady）
function BattleAllInStrike.SingleFire(self)
	-- 和Fire很接近，但没有触发onAllInStrikeSteady
	for _, hive in ipairs(self._hiveList) do
		hive:SingleFire()
	end

	self._skill:Cast(self._host)
	self._host:StrikeExpose()
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ALL_IN_STRIKE, {})
end

--- 获取装填时间（带缓存）
--- @return number: 装填时间
function BattleAllInStrike.GetReloadTime(self)
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	if self._reloadMax ~= self._cacheReloadMax or loadSpeed ~= self._cacheHostReload then
		self._cacheReloadMax = self._reloadMax
		self._cacheHostReload = loadSpeed
		self._cacheReloadTime = BattleFormulas.CalculateReloadTime(self._reloadMax, BattleAttr.GetCurrent(self._host, "loadSpeed"))
	end

	return self._cacheReloadTime
end

--- 按比例获取装填时间
--- @param reloadRate number: 装填比例
--- @return number: 装填时间
function BattleAllInStrike.GetReloadTimeByRate(self, reloadRate)
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")
	local reloadMax = self._cacheReloadMax * reloadRate

	return (BattleFormulas.CalculateReloadTime(reloadMax, loadSpeed))
end

--- 设置使用修正初始CD
function BattleAllInStrike.SetModifyInitialCD(self)
	self._modInitCD = true
end

--- 获取是否使用修正初始CD
--- @return boolean: 是否使用
function BattleAllInStrike.GetModifyInitialCD(self)
	return self._modInitCD
end

--- 初始冷却计时
function BattleAllInStrike.InitialCD(self)
	self:AddCDTimer(self:GetReloadTime())
	self._allInWeaponVo:InitialDeduct(self)
	self._allInWeaponVo:Charge(self)
end

--- 进入冷却
function BattleAllInStrike.EnterCoolDown(self)
	self:AddCDTimer(self:GetReloadTime())
	self._allInWeaponVo:Charge(self)
end

--- 过热
function BattleAllInStrike.OverHeat(self)
	self._currentState = self.STATE_OVER_HEAT

	self._allInWeaponVo:Deduct(self)
end

--- 添加CD计时器
--- @param reloadRequire number: 装填需求时间
function BattleAllInStrike.AddCDTimer(self, reloadRequire)
	self._currentState = BattleAllInStrike.STATE_OVER_HEAT
	self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._reloadRequire = reloadRequire
end

--- 获取CD开始时间戳
--- @return number: CD开始时间戳
function BattleAllInStrike.GetCDStartTimeStamp(self)
	return self._CDstartTime
end

--- 处理冷却完成：进入就绪状态
function BattleAllInStrike.handleCoolDown(self)
	self._currentState = BattleAllInStrike.STATE_READY

	self._allInWeaponVo:Plus(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_READY, {}))
	self:TriggerBuffOnReady()

	self._CDstartTime = nil
	self._jammingTime = 0
	self._reloadBoostList = {}
end

--- 刷新装填需求（装填速度变化时调用）
--- @return boolean|nil: 是否无需更新
function BattleAllInStrike.FlushReloadRequire(self)
	if not self._CDstartTime or self._reloadRequire == 0 then
		return true
	end

	local newReloadAttr = BattleFormulas.CaclulateReloadAttr(self._reloadMax, self._reloadRequire)

	self._reloadRequire = ys.Battle.BattleWeaponUnit.FlushRequireByInverse(self, newReloadAttr)

	self._allInWeaponVo:RefreshReloadingBar()
end

--- 快速冷却（立即完成装填）
function BattleAllInStrike.QuickCoolDown(self)
	if self._currentState == self.STATE_OVER_HEAT then
		self._currentState = BattleAllInStrike.STATE_READY

		self._allInWeaponVo:InstantCoolDown(self)
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, {}))

		self._CDstartTime = nil
		self._reloadBoostList = {}
	end
end

--- 装填加速
--- @param boostAmount number: 加速量
function BattleAllInStrike.ReloadBoost(self, boostAmount)
	local totalBoost = 0

	for _, boost in ipairs(self._reloadBoostList) do
		totalBoost = totalBoost + boost
	end

	local projectedSum = totalBoost + boostAmount
	local elapsed = pg.TimeMgr.GetInstance():GetCombatTime() - self._jammingTime - self._CDstartTime
	local fixValue

	if projectedSum < 0 then
		fixValue = math.max(projectedSum, (self._reloadRequire - elapsed) * -1)
	else
		fixValue = math.min(projectedSum, elapsed)
	end

	fixValue = fixValue - projectedSum + boostAmount

	table.insert(self._reloadBoostList, fixValue)
end

--- 追加装填加速
--- @param boostAmount number: 加速量
function BattleAllInStrike.AppendReloadBoost(self, boostAmount)
	if self._currentState == self.STATE_OVER_HEAT then
		self._allInWeaponVo:ReloadBoost(self, boostAmount)
	end
end

--- 获取装填完成时间戳
--- @return number: 装填完成时间戳
function BattleAllInStrike.GetReloadFinishTimeStamp(self)
	local totalBoost = 0

	for _, boost in ipairs(self._reloadBoostList) do
		totalBoost = totalBoost + boost
	end

	return self._reloadRequire + self._CDstartTime + self._jammingTime + totalBoost
end

--- 开始干扰（暂停装填）
function BattleAllInStrike.StartJamming(self)
	self._jammingStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
end

--- 消除干扰（恢复装填）
function BattleAllInStrike.JammingEliminate(self)
	if not self._jammingStartTime then
		return
	end

	self._jammingTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._jammingStartTime
	self._jammingStartTime = nil
end

-- 消弹逻辑
-- 被BattleFleetVO.UnleashAllInStrike调用
-- 从传入参数来看， 只要敌方的Bullet不是immuneCLS或immuneBombCLS的，就能被消弹
-- 一个特例是激光类武器。因为激光武器的本质是创建一个持续存在的AOE区域，对碰撞判定的敌人创建"隐形"子弹
-- 所以激光类武器看起来不能被消除（区域当然不能被消除；子弹理论上可以消除，但由于"隐形"子弹是瞬间结算的，所以实际也不能被消除）
function BattleAllInStrike.CLSBullet(self)
	local oppositeIFF = self._host:GetIFF() * -1

	ys.Battle.BattleDataProxy.GetInstance():CLSBullet(oppositeIFF, true)
end

--- 派发闪烁事件
--- @param callbackFunc function: 回调函数
function BattleAllInStrike.DispatchBlink(self, callbackFunc)
	local blinkArgs = {
		callbackFunc = callbackFunc,
		timeScale = ys.Battle.BattleConfig.FOCUS_MAP_RATE
	}
	local chargeEvent = ys.Event.New(ys.Battle.BattleUnitEvent.CHARGE_WEAPON_FINISH, blinkArgs)

	self:DispatchEvent(chargeEvent)
end

--- 获取装填进度（0~1）
--- @return number: 装填进度（0=就绪, >0=冷却中）
function BattleAllInStrike.GetReloadRate(self)
	if self._currentState == self.STATE_READY then
		return 0
	elseif self._CDstartTime then
		return (self:GetReloadFinishTimeStamp() - pg.TimeMgr.GetInstance():GetCombatTime()) / self._reloadRequire
	else
		return 1
	end
end

--- 获取总伤害值（遍历所有Hive和技能效果）
--- @return number, number: Hive武器总伤害, 技能效果总伤害
function BattleAllInStrike.GetDamageSUM(self)
	local hiveDamageSum = 0
	local skillDamageSum = 0

	for _, hive in ipairs(self._hiveList) do
		for _, aircraft in ipairs(hive:GetATKAircraftList()) do
			local weaponList = aircraft:GetWeapon()

			for _, weapon in ipairs(weaponList) do
				hiveDamageSum = hiveDamageSum + weapon:GetDamageSUM()
			end
		end
	end

	local skillEffectList = self._skill:GetSkillEffectList()

	for _, skillEffect in ipairs(skillEffectList) do
		local damageSum = skillEffect:GetDamageSum()

		if damageSum then
			skillDamageSum = skillDamageSum + damageSum
		end
	end

	return hiveDamageSum, skillDamageSum
end

--- 获取关联的技能ID
--- @return number: 技能ID
function BattleAllInStrike.GetStrikeSkillID(self)
	return self._skillID
end
