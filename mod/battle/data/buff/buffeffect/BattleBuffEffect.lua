ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas

ys.Battle.BattleBuffEffect = class("BattleBuffEffect")
ys.Battle.BattleBuffEffect.__name = "BattleBuffEffect"

local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleBuffEffect = ys.Battle.BattleBuffEffect

BattleBuffEffect.FX_TYPE_NOR = 0
BattleBuffEffect.FX_TYPE_MOD_ATTR = 1
BattleBuffEffect.FX_TYPE_CASTER = 2
BattleBuffEffect.FX_TYPE_LINK = 3
BattleBuffEffect.FX_TYPE_MOD_VELOCTIY = 4
BattleBuffEffect.FX_TYPE_DOT = 5
BattleBuffEffect.FX_TTPE_MOD_BATTLE_UNIT_TYPE = 6
BattleBuffEffect.FX_TYPE_COUNTER = 7
BattleBuffEffect.FX_TYPE_MOD_MODEL_SCALE = 8

function BattleBuffEffect.Ctor(self, effectData)
	self._tempData = Clone(effectData)
	self._type = self._tempData.type

	local arg_list = self._tempData.arg_list

	self._quota = arg_list.quota or -1
	self._indexRequire = arg_list.index
	self._damageAttrRequire = arg_list.damageAttr
	self._damageReasonRequire = arg_list.damageReason
	self._damageSrcTagRequire = arg_list.srcTag
	self._deathCauseRequire = arg_list.deathCause
	self._countType = arg_list.countType
	self._behit = arg_list.be_hit_condition
	self._ammoTypeRequire = arg_list.ammoType
	self._ammoIndexRequire = arg_list.ammoIndex
	self._bulletTagRequire = arg_list.bulletTag
	self._victimTagRequire = arg_list.victimTag
	self._buffStateIDRequire = arg_list.buff_state_id
	self._cloakRequire = arg_list.cloak_state
	self._fleetAttrRequire = arg_list.fleetAttr
	self._fleetAttrDeltaRequire = arg_list.fleetAttrDelta
	self._stackRequire = arg_list.stack_require

	self:ConfigHPTrigger()
	self:ConfigAttrTrigger()
	self:SetActive()
end

function BattleBuffEffect.GetEffectType(self)
	return BattleBuffEffect.FX_TYPE_NOR
end

function BattleBuffEffect.GetPopConfig(self)
	return self._tempData.pop
end

function BattleBuffEffect.HaveQuota(self)
	if self._quota == 0 then
		return false
	else
		return true
	end
end

function BattleBuffEffect.GetEffectAttachData(self)
	return nil
end

function BattleBuffEffect.ConfigHPTrigger(self)
	local arg_list = self._tempData.arg_list

	self._hpUpperBound = arg_list.hpUpperBound
	self._hpLowerBound = arg_list.hpLowerBound

	if self._hpUpperBound and self._hpLowerBound == nil then
		self._hpLowerBound = 0
	end

	if self._hpLowerBound and self._hpUpperBound == nil then
		self._hpUpperBound = 1
	end

	self._hpSigned = arg_list.hpSigned or -1
	self._hpOutInterval = arg_list.hpOutInterval
	self._dHPGreater = arg_list.dhpGreater
	self._dhpSmaller = arg_list.dhpSmaller
	self._dHPGreaterMaxHP = arg_list.dhpGreaterMaxhp
	self._dhpSmallerMaxhp = arg_list.dhpSmallerMaxhp
end

function BattleBuffEffect.ConfigAttrTrigger(self)
	local arg_list = self._tempData.arg_list

	self._attrLowerBound = arg_list.attrLowerBound
	self._attrUpperBound = arg_list.attrUpperBound
	self._attrInterval = arg_list.attrInterval
end

--- @class BattleBuffEffect
--- @param caster BattleUnit
--- @return nil
function BattleBuffEffect.SetCaster(self, caster)
	self._caster = caster
end

function BattleBuffEffect.SetCommander(self, commander)
	self._commander = commander
end

function BattleBuffEffect.SetBullet(self, bullet)
	return
end

function BattleBuffEffect.SetArgs(self, owner, buff)
	return
end

function BattleBuffEffect.SetOrb(self)
	return
end

--- @class BattleBuffEffect
--- @param effectType string
--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @param args table<string, any>
--- @return nil
--- BuffEffect的触发接口
function BattleBuffEffect.Trigger(self, effectType, owner, buff, args)
	-- effectType跟这些函数名是一样的
	-- 因此对应到的就是onAttach、onRemove等函数...
	-- 需要注意使用的是对应子类重载后的Trigger，因此调用的也是子类重载后的onAttach等函数
	-- 这样设计就让不同的BuffEffect在不同的Trigger下有不同的行为
		-- 一般的调用链为：基类:Trigger(因为子类大概率不重写Trigger)->子类:onXXX(子类重载后的函数)
	-- 这个基类里面的onXXX函数只是一个最基本的实现，避免子类没有重载时调用时报错，因此不用太在意
		-- 有些子类会重载onTrigger, 所以不管哪种情况都要调用onTrigger，逻辑相同
	self[effectType](self, owner, buff, args)
end

function BattleBuffEffect.onAttach(self, owner, buff)
	self:onTrigger(owner, buff)
end

function BattleBuffEffect.onRemove(self, owner, buff)
	self:onTrigger(owner, buff)
end

function BattleBuffEffect.onBuffAdded(self, owner, buff, args)
	if not self:buffStateRequire(args.buffID) then
		return
	end

	self:onTrigger(owner, buff)
end

function BattleBuffEffect.onBuffRemoved(self, owner, buff, args)
	if not self:buffStateRequire(args.buffID) then
		return
	end

	self:onTrigger(owner, buff)
end

function BattleBuffEffect.onUpdate(self, arg_18_1, arg_18_2, arg_18_3)
	self:onTrigger(arg_18_1, arg_18_2, arg_18_3)
end

function BattleBuffEffect.onStack(self, arg_19_1, arg_19_2)
	self:onTrigger(arg_19_1, arg_19_2)
end

function BattleBuffEffect.onBulletHit(self, arg_20_1, arg_20_2, arg_20_3)
	if not self:equipIndexRequire(arg_20_3.equipIndex) then
		return
	end

	if not self:bulletTagRequire(arg_20_3.bulletTag) then
		return
	end

	if not self:victimRequire(arg_20_3.target, arg_20_1) then
		return
	end

	self:onTrigger(arg_20_1, arg_20_2, arg_20_3)
end

function BattleBuffEffect.onTeammateBulletHit(self, arg_21_1, arg_21_2, arg_21_3)
	self:onBulletHit(arg_21_1, arg_21_2, arg_21_3)
end

function BattleBuffEffect.onBeHit(self, arg_22_1, arg_22_2, arg_22_3)
	if self._behit then
		if self._behit.damage_type == arg_22_3.weaponType and self._behit.bullet_type == arg_22_3.bulletType then
			self:onTrigger(arg_22_1, arg_22_2)
		end
	else
		self:onTrigger(arg_22_1, arg_22_2)
	end
end

function BattleBuffEffect.onFire(self, arg_23_1, arg_23_2, arg_23_3)
	if not self:equipIndexRequire(arg_23_3.equipIndex) then
		return
	end

	self:onTrigger(arg_23_1, arg_23_2)
end

function BattleBuffEffect.onCombo(self, arg_24_1, arg_24_2, arg_24_3)
	if not self:equipIndexRequire(arg_24_3.equipIndex) then
		return
	end

	local var_24_0 = arg_24_3.matchUnitCount
	local var_24_1 = self._tempData.arg_list.upperBound
	local var_24_2 = self._tempData.arg_list.lowerBound

	if var_24_1 and var_24_0 <= var_24_1 then
		self:onTrigger(arg_24_1, arg_24_2)
	elseif var_24_2 and var_24_2 <= var_24_0 then
		self:onTrigger(arg_24_1, arg_24_2)
	end
end

function BattleBuffEffect.stackRequire(self, buff)
	if self._stackRequire then
		local stack = buff:GetStack()

		return BattleFormulas.simpleCompare(self._stackRequire, stack)
	else
		return true
	end
end

function BattleBuffEffect.fleetAttrRequire(self, owner, attr)
	if self._fleetAttrRequire then
		local opStart, opEnd = string.find(self._fleetAttrRequire, "%p+")
		local requiredAttr = string.sub(self._fleetAttrRequire, 1, opStart - 1)
		-- 比较的是同种属性
		if attr ~= nil and requiredAttr ~= attr then
			return false
		elseif owner:GetFleetVO() then
			local fleetAttr = owner:GetFleetVO():GetFleetAttr()
			
			return BattleFormulas.parseCompare(self._fleetAttrRequire, fleetAttr)
		else
			return false
		end
	end

	return true
end

function BattleBuffEffect.fleetAttrDelatRequire(self, delta)
	if self._fleetAttrDeltaRequire then
		return delta and BattleFormulas.simpleCompare(self._fleetAttrDeltaRequire, delta)
	end

	return true
end

function BattleBuffEffect.fleetAttrRepeatConsume(self, attrConsumeRepeat)
	local fleetAttr = self._caster:GetFleetVO():GetFleetAttr()
	local attrValue = fleetAttr:GetCurrent(attrConsumeRepeat.attrName)
	local consumedStacks = math.modf(attrValue / attrConsumeRepeat.value)

	if attrConsumeRepeat.repeatCeil then
		consumedStacks = math.min(attrConsumeRepeat.repeatCeil, consumedStacks)
	end

	local consumedAttr = consumedStacks * attrConsumeRepeat.value

	fleetAttr:SetCurrent(attrConsumeRepeat.attrName, attrValue - consumedAttr)

	return consumedStacks
end

function BattleBuffEffect.repeatCountParse(self, repeatCount)
	local countType = type(repeatCount)

	if countType == "number" then
		return repeatCount
	-- 目前没有发现是string的情况
	elseif countType == "string" then
		local opStart, opEnd = string.find(repeatCount, "%p+")
		local attrTypeString = string.sub(repeatCount, 1, opStart - 1)
		local attrName = string.sub(repeatCount, opEnd + 1, #repeatCount)

		if attrTypeString == "fleetAttr" then
			return self._caster:GetFleetVO():GetFleetAttr():GetCurrent(attrName)
		elseif attrTypeString == "attr" then
			return self._caster:GetAttrByName(attrName)
		end
	end
end

function BattleBuffEffect.equipIndexRequire(self, equipIndex)
	if not self._indexRequire then
		return true
	else
		for _, index in ipairs(self._indexRequire) do
			if index == equipIndex then
				return true
			end
		end

		return false
	end
end

function BattleBuffEffect.ammoRequire(self, owner)
	if not self._ammoTypeRequire then
		return true
	else
		-- 检查武器(对应的装备)的位置
		local weapon = owner:GetWeaponByIndex(self._ammoIndexRequire)
		-- 检查弹药类型
		if not weapon or weapon:GetPrimalAmmoType() ~= self._ammoTypeRequire then
			return false
		else
			return true
		end
	end
end

function BattleBuffEffect.bulletTagRequire(arg_32_0, arg_32_1)
	if not arg_32_0._bulletTagRequire then
		return true
	else
		for iter_32_0, iter_32_1 in ipairs(arg_32_0._bulletTagRequire) do
			if table.contains(arg_32_1, iter_32_1) then
				return true
			else
				return false
			end
		end
	end
end

function BattleBuffEffect.buffStateRequire(arg_33_0, arg_33_1)
	if not arg_33_0._buffStateIDRequire then
		return true
	else
		return arg_33_1 == arg_33_0._buffStateIDRequire
	end
end

function BattleBuffEffect.onWeaponSteday(self, arg_34_1, arg_34_2, arg_34_3)
	self:onFire(arg_34_1, arg_34_2, arg_34_3)
end

function BattleBuffEffect.onChargeWeaponFire(self, arg_35_1, arg_35_2, arg_35_3)
	self:onFire(arg_35_1, arg_35_2, arg_35_3)
end

function BattleBuffEffect.onTorpedoWeaponFire(self, arg_36_1, arg_36_2, arg_36_3)
	self:onFire(arg_36_1, arg_36_2, arg_36_3)
end

function BattleBuffEffect.onAntiAirWeaponFireFar(self, arg_37_1, arg_37_2, arg_37_3)
	self:onFire(arg_37_1, arg_37_2, arg_37_3)
end

function BattleBuffEffect.onAntiAirWeaponFireNear(self, arg_38_1, arg_38_2, arg_38_3)
	self:onFire(arg_38_1, arg_38_2, arg_38_3)
end

function BattleBuffEffect.onManualMissileFire(self, arg_39_1, arg_39_2, arg_39_3)
	self:onFire(arg_39_1, arg_39_2, arg_39_3)
end

function BattleBuffEffect.onAllInStrike(self, arg_40_1, arg_40_2, arg_40_3)
	self:onFire(arg_40_1, arg_40_2, arg_40_3)
end

function BattleBuffEffect.onAllInStrikeSteady(self, arg_41_1, arg_41_2, arg_41_3)
	self:onFire(arg_41_1, arg_41_2, arg_41_3)
end

function BattleBuffEffect.onPointStrikeReady(self, arg_42_1, arg_42_2, arg_42_3)
	self:onFire(arg_42_1, arg_42_2, arg_42_3)
end

function BattleBuffEffect.onPointStrikeSteady(self, arg_43_1, arg_43_2, arg_43_3)
	self:onFire(arg_43_1, arg_43_2, arg_43_3)
end

function BattleBuffEffect.onPointStrike(self, arg_44_1, arg_44_2, arg_44_3)
	self:onFire(arg_44_1, arg_44_2, arg_44_3)
end

function BattleBuffEffect.onWeaonInterrupt(self, arg_45_1, arg_45_2, arg_45_3)
	self:onTrigger(arg_45_1, arg_45_2)
end

function BattleBuffEffect.onWeaponSuccess(self, arg_46_1, arg_46_2, arg_46_3)
	self:onTrigger(arg_46_1, arg_46_2)
end

function BattleBuffEffect.onChargeWeaponReady(self, arg_47_1, arg_47_2, arg_47_3)
	self:onTrigger(arg_47_1, arg_47_2)
end

function BattleBuffEffect.onManualTorpedoReady(self, arg_48_1, arg_48_2, arg_48_3)
	self:onTrigger(arg_48_1, arg_48_2)
end

function BattleBuffEffect.onAirAssistReady(self, arg_49_1, arg_49_2, arg_49_3)
	self:onTrigger(arg_49_1, arg_49_2)
end

function BattleBuffEffect.onManualMissileReady(self, arg_50_1, arg_50_2, arg_50_3)
	self:onTrigger(arg_50_1, arg_50_2)
end

function BattleBuffEffect.onTorpedoButtonPush(self, arg_51_1, arg_51_2, arg_51_3)
	self:onTrigger(arg_51_1, arg_51_2)
end

function BattleBuffEffect.onBeforeFatalDamage(self, arg_52_1, arg_52_2)
	self:onTrigger(arg_52_1, arg_52_2)
end

function BattleBuffEffect.onAircraftCreate(self, arg_53_1, arg_53_2, arg_53_3)
	self:onTrigger(arg_53_1, arg_53_2, arg_53_3)
end

function BattleBuffEffect.onFriendlyAircraftDying(self, arg_54_1, arg_54_2, arg_54_3)
	if self._tempData.arg_list.templateID then
		if arg_54_3.unit:GetTemplateID() == self._tempData.arg_list.templateID then
			self:onTrigger(arg_54_1, arg_54_2)
		end
	else
		self:onTrigger(arg_54_1, arg_54_2)
	end
end

function BattleBuffEffect.onTeammateShipDying(self, arg_55_1, arg_55_2)
	self:onTrigger(arg_55_1, arg_55_2)
end

function BattleBuffEffect.onFoeAircraftDying(self, arg_56_1, arg_56_2, arg_56_3)
	if self._tempData.arg_list.inside then
		local var_56_0 = arg_56_3.unit

		if not arg_56_1:GetFleetVO():GetFleetAntiAirWeapon():IsOutOfRange(var_56_0) then
			self:onTrigger(arg_56_1, arg_56_2)
		end
	elseif self._tempData.arg_list.killer then
		if self:killerRequire(self._tempData.arg_list.killer, arg_56_3.killer, arg_56_1) then
			self:onTrigger(arg_56_1, arg_56_2)
		end
	else
		self:onTrigger(arg_56_1, arg_56_2)
	end
end

function BattleBuffEffect.onFoeDying(self, arg_57_1, arg_57_2, arg_57_3)
	if self._tempData.arg_list.killer then
		if self:killerRequire(self._tempData.arg_list.killer, arg_57_3.killer, arg_57_1) then
			self:onTrigger(arg_57_1, arg_57_2)
		end
	elseif self:victimRequire(arg_57_3.unit, arg_57_1) then
		self:onTrigger(arg_57_1, arg_57_2)
	else
		self:onTrigger(arg_57_1, arg_57_2)
	end
end

function BattleBuffEffect.onSink(self, arg_58_1, arg_58_2)
	if self:deathCauseRequire(arg_58_1) then
		self:onTrigger(arg_58_1, arg_58_2)
	end
end

function BattleBuffEffect.deathCauseRequire(arg_59_0, arg_59_1)
	if not arg_59_0._deathCauseRequire then
		return true
	end

	local var_59_0 = arg_59_1:GetDeathReason()

	return table.contains(arg_59_0._deathCauseRequire, var_59_0)
end

function BattleBuffEffect.killerRequire(arg_60_0, arg_60_1, arg_60_2, arg_60_3)
	if not arg_60_2 then
		return false
	end

	local var_60_0
	local var_60_1
	local var_60_2 = arg_60_2.__name

	if var_60_2 == ys.Battle.BattlePlayerUnit.__name or var_60_2 == ys.Battle.BattleNPCUnit.__name or var_60_2 == ys.Battle.BattleMinionUnit.__name or var_60_2 == ys.Battle.BattleEnemyUnit.__name or var_60_2 == ys.Battle.BattleAircraftUnit.__name or var_60_2 == ys.Battle.BattleAirFighterUnit.__name then
		var_60_0 = arg_60_2
	else
		var_60_0 = arg_60_2:GetHost()
	end

	if var_60_0 then
		local var_60_3 = var_60_0.__name

		if var_60_3 == ys.Battle.BattleAircraftUnit.__name then
			var_60_1 = var_60_0:GetMotherUnit()
		elseif var_60_3 == ys.Battle.BattleMinionUnit.__name then
			var_60_1 = var_60_0:GetMaster()
		else
			var_60_1 = var_60_0
			var_60_0 = nil
		end
	else
		return false
	end

	if arg_60_1 == "self" then
		if var_60_1 == arg_60_3 and not var_60_0 then
			return true
		end
	elseif arg_60_1 == "child" and var_60_1 == arg_60_3 and var_60_0 then
		return true
	end

	return false
end

function BattleBuffEffect.victimRequire(arg_61_0, arg_61_1, arg_61_2)
	if not arg_61_0._victimTagRequire then
		return true
	elseif arg_61_1:ContainsLabelTag(arg_61_0._victimTagRequire) then
		return true
	else
		return false
	end
end

function BattleBuffEffect.killerWeaponRequire(arg_62_0, arg_62_1, arg_62_2, arg_62_3)
	if not arg_62_2 then
		return false
	end

	if not arg_62_2.GetWeapon then
		return false
	end

	local var_62_0 = arg_62_2:GetWeapon():GetWeaponId()

	if table.contains(arg_62_1, var_62_0) then
		return true
	end
end

function BattleBuffEffect.DamageSourceRequire(arg_63_0, arg_63_1, arg_63_2)
	if not arg_63_0._damageSrcTagRequire then
		return true
	else
		if not arg_63_1 then
			return false
		end

		local var_63_0 = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()[arg_63_1]

		if not var_63_0 then
			return false
		end

		if var_63_0:ContainsLabelTag(arg_63_0._damageSrcTagRequire) then
			return true
		else
			return false
		end
	end
end

function BattleBuffEffect.onInitGame(self, arg_64_1, arg_64_2)
	self:onTrigger(arg_64_1, arg_64_2)
end

function BattleBuffEffect.onStartGame(self, arg_65_1, arg_65_2)
	self:onTrigger(arg_65_1, arg_65_2)
end

function BattleBuffEffect.onFinishGame(self, arg_66_1, arg_66_2)
	self:onTrigger(arg_66_1, arg_66_2)
end

function BattleBuffEffect.onManual(self, arg_67_1, arg_67_2)
	self:onTrigger(arg_67_1, arg_67_2)
end

function BattleBuffEffect.onAutoBot(self, arg_68_1, arg_68_2)
	self:onTrigger(arg_68_1, arg_68_2)
end

function BattleBuffEffect.onFlagShip(self, arg_69_1, arg_69_2)
	self:onTrigger(arg_69_1, arg_69_2)
end

function BattleBuffEffect.onDALCollabFlagShip(self, arg_70_1, arg_70_2)
	self:onTrigger(arg_70_1, arg_70_2)
end

function BattleBuffEffect.onUpperConsort(self, arg_71_1, arg_71_2)
	self:onTrigger(arg_71_1, arg_71_2)
end

function BattleBuffEffect.onLowerConsort(self, arg_72_1, arg_72_2)
	self:onTrigger(arg_72_1, arg_72_2)
end

function BattleBuffEffect.onLeader(self, arg_73_1, arg_73_2)
	self:onTrigger(arg_73_1, arg_73_2)
end

function BattleBuffEffect.onCenter(self, arg_74_1, arg_74_2)
	self:onTrigger(arg_74_1, arg_74_2)
end

function BattleBuffEffect.onRear(self, arg_75_1, arg_75_2)
	self:onTrigger(arg_75_1, arg_75_2)
end

function BattleBuffEffect.onSubLeader(self, arg_76_1, arg_76_2)
	self:onTrigger(arg_76_1, arg_76_2)
end

function BattleBuffEffect.onUpperSubConsort(self, arg_77_1, arg_77_2)
	self:onTrigger(arg_77_1, arg_77_2)
end

function BattleBuffEffect.onLowerSubConsort(self, arg_78_1, arg_78_2)
	self:onTrigger(arg_78_1, arg_78_2)
end

function BattleBuffEffect.onBulletCollide(self, arg_79_1, arg_79_2, arg_79_3)
	if not self:equipIndexRequire(arg_79_3.equipIndex) then
		return
	end

	self:onTrigger(arg_79_1, arg_79_2)
end

function BattleBuffEffect.onBulletCollideBefore(self, arg_80_1, arg_80_2, arg_80_3)
	if not self:equipIndexRequire(arg_80_3.equipIndex) then
		return
	end

	self:onTrigger(arg_80_1, arg_80_2)
end

function BattleBuffEffect.onBombBulletBang(self, arg_81_1, arg_81_2, arg_81_3)
	if not self:equipIndexRequire(arg_81_3.equipIndex) then
		return
	end

	self:onTrigger(arg_81_1, arg_81_2)
end

function BattleBuffEffect.onTorpedoBulletBang(self, arg_82_1, arg_82_2, arg_82_3)
	if not self:equipIndexRequire(arg_82_3.equipIndex) then
		return
	end

	self:onTrigger(arg_82_1, arg_82_2)
end

function BattleBuffEffect.onBulletHitBefore(self, arg_83_1, arg_83_2, arg_83_3)
	if self._behit then
		if self._behit.damage_type == arg_83_3.weaponType and self._behit.bullet_type == arg_83_3.bulletType then
			self:onTrigger(arg_83_1, arg_83_2)
		end
	else
		self:onTrigger(arg_83_1, arg_83_2)
	end
end

function BattleBuffEffect.onBulletCreate(self, arg_84_1, arg_84_2, arg_84_3)
	if not self:equipIndexRequire(arg_84_3.equipIndex) then
		return
	end

	self:onTrigger(arg_84_1, arg_84_2, arg_84_3)
end

function BattleBuffEffect.onChargeWeaponBulletCreate(self, arg_85_1, arg_85_2, arg_85_3)
	self:onBulletCreate(arg_85_1, arg_85_2, arg_85_3)
end

function BattleBuffEffect.onTorpedoWeaponBulletCreate(self, arg_86_1, arg_86_2, arg_86_3)
	self:onBulletCreate(arg_86_1, arg_86_2, arg_86_3)
end

function BattleBuffEffect.onInternalBulletCreate(self, arg_87_1, arg_87_2, arg_87_3)
	if not self:equipIndexRequire(arg_87_3.equipIndex) then
		return
	end

	self:onTrigger(arg_87_1, arg_87_2, arg_87_3)
end

function BattleBuffEffect.onManualBulletCreate(self, arg_88_1, arg_88_2, arg_88_3)
	if not self:equipIndexRequire(arg_88_3.equipIndex) then
		return
	end

	self:onTrigger(arg_88_1, arg_88_2, arg_88_3)
end

function BattleBuffEffect.onBeforeTakeDamage(self, arg_89_1, arg_89_2, arg_89_3)
	if self:damageCheck(arg_89_3) then
		self:onTrigger(arg_89_1, arg_89_2, arg_89_3)
	end
end

function BattleBuffEffect.onTakeDamage(self, arg_90_1, arg_90_2, arg_90_3)
	if self:damageCheck(arg_90_3) then
		self:onTrigger(arg_90_1, arg_90_2, arg_90_3)
	end
end

function BattleBuffEffect.onTakeHealing(self, arg_91_1, arg_91_2, arg_91_3)
	self:onTrigger(arg_91_1, arg_91_2, arg_91_3)
end

function BattleBuffEffect.onShieldAbsorb(self, arg_92_1, arg_92_2, arg_92_3)
	self:onTrigger(arg_92_1, arg_92_2, arg_92_3)
end

function BattleBuffEffect.onDamageFix(self, arg_93_1, arg_93_2, arg_93_3)
	self:onTrigger(arg_93_1, arg_93_2, arg_93_3)
end

function BattleBuffEffect.onDamageConclude(self, arg_94_1, arg_94_2, arg_94_3)
	self:onTrigger(arg_94_1, arg_94_2, arg_94_3)
end

function BattleBuffEffect.onOverHealing(self, arg_95_1, arg_95_2, arg_95_3)
	self:onTrigger(arg_95_1, arg_95_2, arg_95_3)
end

function BattleBuffEffect.onFleetAttrUpdate(self, arg_96_1, arg_96_2, arg_96_3)
	self:onTrigger(arg_96_1, arg_96_2, arg_96_3)
end

function BattleBuffEffect.damageCheck(arg_97_0, arg_97_1)
	return arg_97_0:damageAttrRequire(arg_97_1.damageAttr) and arg_97_0:damageReasonRequire(arg_97_1.damageReason)
end

function BattleBuffEffect.damageAttrRequire(arg_98_0, arg_98_1)
	if not arg_98_0._damageAttrRequire or table.contains(arg_98_0._damageAttrRequire, arg_98_1) then
		return true
	else
		return false
	end
end

function BattleBuffEffect.damageReasonRequire(arg_99_0, arg_99_1)
	if not arg_99_0._damageReasonRequire or table.contains(arg_99_0._damageReasonRequire, arg_99_1) then
		return true
	else
		return false
	end
end

function BattleBuffEffect.hpIntervalRequire(self, hpRate, arg_100_2)
	if self._hpUpperBound == nil and self._hpLowerBound == nil then
		return true
	end

	if not arg_100_2 or self._hpSigned == 0 then
		-- block empty
	elseif arg_100_2 * self._hpSigned < 0 then
		return false
	end

	local satisfied
	-- 如果要求是区间外
	-- 注意并不是完全相反，包含了等于的情况
	if self._hpOutInterval then
		if hpRate >= self._hpUpperBound or hpRate <= self._hpLowerBound then
			satisfied = true
		end
	elseif hpRate <= self._hpUpperBound and hpRate >= self._hpLowerBound then
		satisfied = true
	end

	return satisfied
end

function BattleBuffEffect.dhpRequire(arg_101_0, arg_101_1, arg_101_2)
	if arg_101_0._dHPGreater then
		return arg_101_2 * arg_101_0._dHPGreater > 0 and math.abs(arg_101_2) > math.abs(arg_101_0._dHPGreater)
	elseif arg_101_0._dHPGreaterMaxHP then
		local var_101_0 = arg_101_0._dHPGreaterMaxHP * arg_101_1

		return arg_101_2 * var_101_0 > 0 and math.abs(arg_101_2) > math.abs(var_101_0)
	elseif arg_101_0._dhpSmaller then
		return arg_101_2 * arg_101_0._dhpSmaller > 0 and math.abs(arg_101_2) < math.abs(arg_101_0._dhpSmaller)
	elseif arg_101_0._dhpSmallerMaxhp then
		local var_101_1 = arg_101_0._dhpSmallerMaxhp * arg_101_1

		return arg_101_2 * var_101_1 > 0 and math.abs(arg_101_2) < math.abs(var_101_1)
	else
		return true
	end
end

function BattleBuffEffect.attrIntervalRequire(self, attrIntervalValue)
	local satisfied = true
	-- 注意: 这个检查略有不同，实际上满足要求的是开区间
	-- 即(lowerBound, upperBound)，与其他的闭区间不同
	if self._attrUpperBound and attrIntervalValue >= self._attrUpperBound then
		satisfied = false
	end

	if self._attrLowerBound and attrIntervalValue <= self._attrLowerBound then
		satisfied = false
	end

	return satisfied
end

function BattleBuffEffect.onHPRatioUpdate(self, arg_103_1, arg_103_2, arg_103_3)
	local var_103_0 = arg_103_1:GetHPRate()
	local var_103_1 = arg_103_3.dHP

	if self:hpIntervalRequire(var_103_0, var_103_1) and self:dhpRequire(arg_103_1:GetMaxHP(), var_103_1) then
		self:doOnHPRatioUpdate(arg_103_1, arg_103_2, arg_103_3)
	end
end

function BattleBuffEffect.onFriendlyHpRatioUpdate(self, arg_104_1, arg_104_2, arg_104_3)
	local var_104_0 = arg_104_3.unit
	local var_104_1 = arg_104_3.dHP
	local var_104_2 = var_104_0:GetHPRate()

	if self:hpIntervalRequire(var_104_2, var_104_1) and self:dhpRequire(var_104_0:GetMaxHP(), var_104_1) then
		self:doOnHPRatioUpdate(arg_104_1, arg_104_2, arg_104_3)
	end
end

function BattleBuffEffect.onTeammateHpRatioUpdate(self, arg_105_1, arg_105_2, arg_105_3)
	self:onFriendlyHpRatioUpdate(arg_105_1, arg_105_2, arg_105_3)
end

function BattleBuffEffect.onBulletKill(self, arg_106_1, arg_106_2, arg_106_3)
	if self._tempData.arg_list.killer_weapon_id then
		if self:killerWeaponRequire(self._tempData.arg_list.killer_weapon_id, arg_106_3.killer, arg_106_1) then
			self:onTrigger(arg_106_1, arg_106_2)
		end
	else
		self:onTrigger(arg_106_1, arg_106_2)
	end
end
-- 用于处理那些依赖buffEffect计数器的效果
function BattleBuffEffect.onBattleBuffCount(self, owner, buff, args)
	local buffEffect = args.buffFX
	-- 检查countType是否匹配
	if buffEffect:GetCountType() == self._countType then
		-- 表示是累计计数，然后消耗计数来触发的类型
		-- 对应的是buffEffect.arg_list的keep字段
		if buffEffect:Repeater() then
			while buffEffect:GetCountProgress() >= 1 do
				self:onTrigger(owner, buff)
				buffEffect:ConsumeCount()
			end
		elseif self:onTrigger(owner, buff) ~= "overheat" then
			buffEffect:ResetCount()
		end
	end
end

function BattleBuffEffect.onShieldBroken(self, arg_108_1, arg_108_2, arg_108_3)
	if arg_108_3.shieldBuffID == self._tempData.arg_list.shieldBuffID then
		self:onTrigger(arg_108_1, arg_108_2)
	end
end

--- @class BattleBuffEffect
--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @param args table<string, any>
--- @return nil
--- BuffEffect通用触发函数
--- - quota -= 1
function BattleBuffEffect.onTrigger(self, owner, buff, args)
	if self._quota > 0 then
		self._quota = self._quota - 1
	end
end

function BattleBuffEffect.doOnHPRatioUpdate(self, arg_110_1, arg_110_2, arg_110_3)
	self:onTrigger(arg_110_1, arg_110_2, arg_110_3)
end

function BattleBuffEffect.doOnFriendlyHPRatioUpdate(self, arg_111_1, arg_111_2, arg_111_3)
	self:onTrigger(arg_111_1, arg_111_2, arg_111_3)
end

function BattleBuffEffect.onSubmarineDive(self, arg_112_1, arg_112_2, arg_112_3)
	self:onTrigger(arg_112_1, arg_112_2, arg_112_3)
end

function BattleBuffEffect.onSubmarineRaid(self, arg_113_1, arg_113_2, arg_113_3)
	self:onTrigger(arg_113_1, arg_113_2, arg_113_3)
end

function BattleBuffEffect.onSubmarineFloat(self, arg_114_1, arg_114_2, arg_114_3)
	self:onTrigger(arg_114_1, arg_114_2, arg_114_3)
end

function BattleBuffEffect.onSubmarineRetreat(self, arg_115_1, arg_115_2, arg_115_3)
	self:onTrigger(arg_115_1, arg_115_2, arg_115_3)
end

function BattleBuffEffect.onSubmarineAid(self, arg_116_1, arg_116_2, arg_116_3)
	self:onTrigger(arg_116_1, arg_116_2, arg_116_3)
end

function BattleBuffEffect.onSubmarinFreeDive(self, arg_117_1, arg_117_2, arg_117_3)
	self:onTrigger(arg_117_1, arg_117_2, arg_117_3)
end

function BattleBuffEffect.onSubmarinFreeFloat(self, arg_118_1, arg_118_2, arg_118_3)
	self:onTrigger(arg_118_1, arg_118_2, arg_118_3)
end

function BattleBuffEffect.onSubmarineFreeSpecial(self, arg_119_1, arg_119_2, arg_119_3)
	self:onTrigger(arg_119_1, arg_119_2, arg_119_3)
end

function BattleBuffEffect.onSubDetected(self, arg_120_1, arg_120_2, arg_120_3)
	self:onTrigger(arg_120_1, arg_120_2, arg_120_3)
end

function BattleBuffEffect.onSubUnDetected(self, arg_121_1, arg_121_2, arg_121_3)
	self:onTrigger(arg_121_1, arg_121_2, arg_121_3)
end

function BattleBuffEffect.onAntiSubHateChain(self, arg_122_1, arg_122_2, arg_122_3)
	self:onTrigger(arg_122_1, arg_122_2, attach)
end

function BattleBuffEffect.onRetreat(self, arg_123_1, arg_123_2, arg_123_3)
	self:onTrigger(arg_123_1, arg_123_2, arg_123_3)
end

function BattleBuffEffect.onCloakUpdate(self, arg_124_1, arg_124_2, arg_124_3)
	if self:cloakStateRequire(arg_124_3.cloakState) then
		self:onTrigger(arg_124_1, arg_124_2, arg_124_3)
	end
end

function BattleBuffEffect.onTeammateCloakUpdate(self, arg_125_1, arg_125_2, arg_125_3)
	if self:cloakStateRequire(arg_125_3.cloakState) then
		self:onTrigger(arg_125_1, arg_125_2, arg_125_3)
	end
end

function BattleBuffEffect.cloakStateRequire(arg_126_0, arg_126_1)
	if not arg_126_0._cloakRequire then
		return true
	else
		return arg_126_0._cloakRequire == arg_126_1
	end
end

function BattleBuffEffect.Interrupt(arg_127_0)
	return
end

function BattleBuffEffect.Clear(arg_128_0)
	arg_128_0._commander = nil
end

--- @class BattleBuffEffect
--- @param owner BattleUnit
--- @param targetTypeList string|table<string>
--- @param arg_list table<string, any>
--- @param extraArgs table<string, any>
--- @return table<BattleUnit>
--- 获取目标列表的通用函数
function BattleBuffEffect.getTargetList(self, owner, targetTypeList, arg_list, extraArgs)
	if type(targetTypeList) == "string" then
		targetTypeList = {
			targetTypeList
		}
	end

	local argList = arg_list

	if table.contains(targetTypeList, "TargetDamageSource") then
		argList = Clone(arg_list)
		argList.damageSourceID = extraArgs.damageSrc
	end
	-- 注：这个表最开始是空的
	-- 具体怎么初始化，要看第一个调用的targetChoise函数是什么，不同的函数初始化targetList的方式不同
	-- 比较常见的初始化方式有: TargetEntityUnit, getShipListByIFF等
	local targetList

	for _, targetType in ipairs(targetTypeList) do
		-- 到BattleTargetChoise调用对应的函数获取目标
		-- 注意是多层筛选，也即需要全部类型都满足
		targetList = ys.Battle.BattleTargetChoise[targetType](owner, argList, targetList)
	end

	return targetList
end

function BattleBuffEffect.commanderRequire(self, owner)
	if self._tempData.arg_list.CMDBuff_id then
		local commanderBuff, subCommanderBuff = ys.Battle.BattleDataProxy.GetInstance():GetCommanderBuff()
		local CMDbuffs
		local shipType = owner:GetTemplate().type

		if table.contains(ShipType.SubShipType, shipType) then
			CMDbuffs = subCommanderBuff
		else
			CMDbuffs = commanderBuff
		end

		local fleetCommanderBuffList = {}
		local CMDBuff_id = self._tempData.arg_list.CMDBuff_id

		for _, CMDbuff in ipairs(CMDbuffs) do
			-- 找到对应的指挥喵天赋Buff
			if CMDbuff.id == CMDBuff_id then
				table.insert(fleetCommanderBuffList, CMDbuff)
			end
		end

		return #fleetCommanderBuffList > 0
	else
		return true
	end
end

function BattleBuffEffect.IsActive(arg_131_0)
	return arg_131_0._isActive
end

function BattleBuffEffect.SetActive(arg_132_0)
	arg_132_0._isActive = true
end

function BattleBuffEffect.NotActive(arg_133_0)
	arg_133_0._isActive = false
end

function BattleBuffEffect.IsLock(arg_134_0)
	return arg_134_0._isLock
end

function BattleBuffEffect.SetLock(arg_135_0)
	arg_135_0._isLock = true
end

function BattleBuffEffect.NotLock(arg_136_0)
	arg_136_0._isLock = false
end

function BattleBuffEffect.Dispose(arg_137_0)
	return
end
