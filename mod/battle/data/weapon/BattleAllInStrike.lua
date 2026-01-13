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
function BattleAllInStrike.Ctor(self, skillID)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._skill = ys.Battle.BattleSkillUnit.New(skillID)
	self._skillID = skillID
	self._reloadFacotrList = {}
	self._reloadBoostList = {}
	self._jammingTime = 0
end

function BattleAllInStrike.Update(self)
	self:UpdateReload()
end

function BattleAllInStrike.UpdateReload(self)
	if self._CDstartTime and not self._jammingStartTime then
		if self:GetReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime() then
			self:handleCoolDown()
		else
			return
		end
	end
end

function BattleAllInStrike.Clear(self)
	self._skill:Clear()
end

function BattleAllInStrike.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
end

-- BattleDataFunction.CreateAllInStrike调用
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

-- 计算一次“空袭”所对应的总装填时间
-- "空袭"是对多个Hive构成的一次攻击的抽象概念
function BattleAllInStrike.FlushTotalReload(self)
	self._totalReload = BattleFormulas.CaclulateAirAssistReloadMax(self._hiveList)
end

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

function BattleAllInStrike.AppendReloadFactor(arg_9_0, arg_9_1, arg_9_2)
	arg_9_0._reloadFacotrList[arg_9_1] = arg_9_2
end

function BattleAllInStrike.RemoveReloadFactor(arg_10_0, arg_10_1)
	if arg_10_0._reloadFacotrList[arg_10_1] then
		arg_10_0._reloadFacotrList[arg_10_1] = nil
	end
end

function BattleAllInStrike.GetReloadFactorList(arg_11_0)
	return arg_11_0._reloadFacotrList
end

function BattleAllInStrike.SetAllInWeaponVO(arg_12_0, arg_12_1)
	arg_12_0._allInWeaponVo = arg_12_1
	arg_12_0._currentState = BattleAllInStrike.STATE_READY
end

function BattleAllInStrike.GetCurrentState(arg_13_0)
	return arg_13_0._currentState
end

function BattleAllInStrike.GetHost(arg_14_0)
	return arg_14_0._host
end

function BattleAllInStrike.GetType(arg_15_0)
	return BattleConst.EquipmentType.AIR_ASSIST
end

-- AllInStrike的Fire函数(持续输出, 对应常驻武器)
-- 实际上可以看到，AllInStrike的Fire函数只是触发了各个Hive的SingleFire(因为本身是个抽象概念, 没有对应具体的武器, 也不是BattleWeaponUnit的子类)
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

function BattleAllInStrike.TriggerBuffOnReady(self)
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_AIR_ASSIST_READY, {})
end

function BattleAllInStrike.SingleFire(self)
	-- 和Fire很接近，但没有触发onAllInStrikeSteady
	for _, hive in ipairs(self._hiveList) do
		hive:SingleFire()
	end

	self._skill:Cast(self._host)
	self._host:StrikeExpose()
	self._host:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_ALL_IN_STRIKE, {})
end

function BattleAllInStrike.GetReloadTime(self)
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")

	if self._reloadMax ~= self._cacheReloadMax or loadSpeed ~= self._cacheHostReload then
		self._cacheReloadMax = self._reloadMax
		self._cacheHostReload = loadSpeed
		self._cacheReloadTime = BattleFormulas.CalculateReloadTime(self._reloadMax, BattleAttr.GetCurrent(self._host, "loadSpeed"))
	end

	return self._cacheReloadTime
end

function BattleAllInStrike.GetReloadTimeByRate(self, reloadRate)
	local loadSpeed = BattleAttr.GetCurrent(self._host, "loadSpeed")
	local reloadMax = self._cacheReloadMax * reloadRate

	return (BattleFormulas.CalculateReloadTime(reloadMax, loadSpeed))
end

function BattleAllInStrike.SetModifyInitialCD(self)
	self._modInitCD = true
end

function BattleAllInStrike.GetModifyInitialCD(self)
	return self._modInitCD
end

function BattleAllInStrike.InitialCD(self)
	self:AddCDTimer(self:GetReloadTime())
	self._allInWeaponVo:InitialDeduct(self)
	self._allInWeaponVo:Charge(self)
end

function BattleAllInStrike.EnterCoolDown(self)
	self:AddCDTimer(self:GetReloadTime())
	self._allInWeaponVo:Charge(self)
end

function BattleAllInStrike.OverHeat(self)
	self._currentState = self.STATE_OVER_HEAT

	self._allInWeaponVo:Deduct(self)
end

function BattleAllInStrike.AddCDTimer(self, reloadRequire)
	self._currentState = BattleAllInStrike.STATE_OVER_HEAT
	self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	self._reloadRequire = reloadRequire
end

function BattleAllInStrike.GetCDStartTimeStamp(self)
	return self._CDstartTime
end

function BattleAllInStrike.handleCoolDown(self)
	self._currentState = BattleAllInStrike.STATE_READY

	self._allInWeaponVo:Plus(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_READY, {}))
	self:TriggerBuffOnReady()

	self._CDstartTime = nil
	self._jammingTime = 0
	self._reloadBoostList = {}
end

function BattleAllInStrike.FlushReloadRequire(arg_29_0)
	if not arg_29_0._CDstartTime or arg_29_0._reloadRequire == 0 then
		return true
	end

	local var_29_0 = BattleFormulas.CaclulateReloadAttr(arg_29_0._reloadMax, arg_29_0._reloadRequire)

	arg_29_0._reloadRequire = ys.Battle.BattleWeaponUnit.FlushRequireByInverse(arg_29_0, var_29_0)

	arg_29_0._allInWeaponVo:RefreshReloadingBar()
end

function BattleAllInStrike.QuickCoolDown(arg_30_0)
	if arg_30_0._currentState == arg_30_0.STATE_OVER_HEAT then
		arg_30_0._currentState = BattleAllInStrike.STATE_READY

		arg_30_0._allInWeaponVo:InstantCoolDown(arg_30_0)
		arg_30_0:DispatchEvent(ys.Event.New(BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, {}))

		arg_30_0._CDstartTime = nil
		arg_30_0._reloadBoostList = {}
	end
end

function BattleAllInStrike.ReloadBoost(arg_31_0, arg_31_1)
	local var_31_0 = 0

	for iter_31_0, iter_31_1 in ipairs(arg_31_0._reloadBoostList) do
		var_31_0 = var_31_0 + iter_31_1
	end

	local var_31_1 = var_31_0 + arg_31_1
	local var_31_2 = pg.TimeMgr.GetInstance():GetCombatTime() - arg_31_0._jammingTime - arg_31_0._CDstartTime
	local var_31_3

	if var_31_1 < 0 then
		var_31_3 = math.max(var_31_1, (arg_31_0._reloadRequire - var_31_2) * -1)
	else
		var_31_3 = math.min(var_31_1, var_31_2)
	end

	fixValue = var_31_3 - var_31_1 + arg_31_1

	table.insert(arg_31_0._reloadBoostList, fixValue)
end

function BattleAllInStrike.AppendReloadBoost(arg_32_0, arg_32_1)
	if arg_32_0._currentState == arg_32_0.STATE_OVER_HEAT then
		arg_32_0._allInWeaponVo:ReloadBoost(arg_32_0, arg_32_1)
	end
end

function BattleAllInStrike.GetReloadFinishTimeStamp(arg_33_0)
	local var_33_0 = 0

	for iter_33_0, iter_33_1 in ipairs(arg_33_0._reloadBoostList) do
		var_33_0 = var_33_0 + iter_33_1
	end

	return arg_33_0._reloadRequire + arg_33_0._CDstartTime + arg_33_0._jammingTime + var_33_0
end

function BattleAllInStrike.StartJamming(arg_34_0)
	arg_34_0._jammingStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
end

function BattleAllInStrike.JammingEliminate(arg_35_0)
	if not arg_35_0._jammingStartTime then
		return
	end

	arg_35_0._jammingTime = pg.TimeMgr.GetInstance():GetCombatTime() - arg_35_0._jammingStartTime
	arg_35_0._jammingStartTime = nil
end

function BattleAllInStrike.CLSBullet(arg_36_0)
	local var_36_0 = arg_36_0._host:GetIFF() * -1

	ys.Battle.BattleDataProxy.GetInstance():CLSBullet(var_36_0, true)
end

function BattleAllInStrike.DispatchBlink(arg_37_0, arg_37_1)
	local var_37_0 = {
		callbackFunc = arg_37_1,
		timeScale = ys.Battle.BattleConfig.FOCUS_MAP_RATE
	}
	local var_37_1 = ys.Event.New(ys.Battle.BattleUnitEvent.CHARGE_WEAPON_FINISH, var_37_0)

	arg_37_0:DispatchEvent(var_37_1)
end

function BattleAllInStrike.GetReloadRate(arg_38_0)
	if arg_38_0._currentState == arg_38_0.STATE_READY then
		return 0
	elseif arg_38_0._CDstartTime then
		return (arg_38_0:GetReloadFinishTimeStamp() - pg.TimeMgr.GetInstance():GetCombatTime()) / arg_38_0._reloadRequire
	else
		return 1
	end
end

function BattleAllInStrike.GetDamageSUM(arg_39_0)
	local var_39_0 = 0
	local var_39_1 = 0

	for iter_39_0, iter_39_1 in ipairs(arg_39_0._hiveList) do
		for iter_39_2, iter_39_3 in ipairs(iter_39_1:GetATKAircraftList()) do
			local var_39_2 = iter_39_3:GetWeapon()

			for iter_39_4, iter_39_5 in ipairs(var_39_2) do
				var_39_0 = var_39_0 + iter_39_5:GetDamageSUM()
			end
		end
	end

	local var_39_3 = arg_39_0._skill:GetSkillEffectList()

	for iter_39_6, iter_39_7 in ipairs(var_39_3) do
		local var_39_4 = iter_39_7:GetDamageSum()

		if var_39_4 then
			var_39_1 = var_39_1 + var_39_4
		end
	end

	return var_39_0, var_39_1
end

function BattleAllInStrike.GetStrikeSkillID(arg_40_0)
	return arg_40_0._skillID
end
