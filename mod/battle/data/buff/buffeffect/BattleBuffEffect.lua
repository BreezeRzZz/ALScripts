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

--- @class BattleBuffEffect
--- @param effectData table BuffEffect配置数据（来自skill_data_template的effect列表项）
--- 核心BuffEffect之一
--- 这是所有BuffEffect的基类. 如果子类没重写, 请参考这个类的实现
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

--- @class BattleBuffEffect
--- @return number FX_TYPE_NOR(0)
--- 返回BuffEffect的类型，默认返回FX_TYPE_NOR
function BattleBuffEffect.GetEffectType(self)
	return BattleBuffEffect.FX_TYPE_NOR
end

--- @class BattleBuffEffect
--- @return table|nil pop配置表
function BattleBuffEffect.GetPopConfig(self)
	return self._tempData.pop
end

--- @class BattleBuffEffect
--- @return boolean 是否还有剩余触发次数
function BattleBuffEffect.HaveQuota(self)
	if self._quota == 0 then
		return false
	else
		return true
	end
end

--- @class BattleBuffEffect
--- @return nil 基类默认无附加数据
function BattleBuffEffect.GetEffectAttachData(self)
	return nil
end

--- 配置HP触发条件
--- 从arg_list读取hpUpperBound、hpLowerBound、hpSigned、dhpGreater、dhpSmaller等字段
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

--- 配置属性触发条件
function BattleBuffEffect.ConfigAttrTrigger(self)
	local arg_list = self._tempData.arg_list

	self._attrLowerBound = arg_list.attrLowerBound
	self._attrUpperBound = arg_list.attrUpperBound
	self._attrInterval = arg_list.attrInterval
end

--- @class BattleBuffEffect
--- @param caster BattleUnit 施法者单位
function BattleBuffEffect.SetCaster(self, caster)
	self._caster = caster
end

--- @class BattleBuffEffect
--- @param commander table 指挥官数据
function BattleBuffEffect.SetCommander(self, commander)
	self._commander = commander
end

--- @class BattleBuffEffect
--- @param bullet BattleBulletUnit 子弹单位
function BattleBuffEffect.SetBullet(self, bullet)
	return
end

--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @param buff BattleBuffUnit Buff实例
function BattleBuffEffect.SetArgs(self, owner, buff)
	return
end

--- @class BattleBuffEffect
function BattleBuffEffect.SetOrb(self)
	return
end

--- @class BattleBuffEffect
--- @param effectType string 触发类型（对应onAttach/onRemove等方法名）
--- @param owner BattleUnit Buff持有者
--- @param buff BattleBuffUnit Buff实例
--- @param args table<string, any> 事件附加参数
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

--- Buff挂载时触发
function BattleBuffEffect.onAttach(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- Buff移除时触发
function BattleBuffEffect.onRemove(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 有新Buff添加时触发
function BattleBuffEffect.onBuffAdded(self, owner, buff, args)
	if not self:buffStateRequire(args.buffID) then
		return
	end

	self:onTrigger(owner, buff)
end

--- Buff移除时触发
function BattleBuffEffect.onBuffRemoved(self, owner, buff, args)
	if not self:buffStateRequire(args.buffID) then
		return
	end

	self:onTrigger(owner, buff)
end

--- 每帧更新时触发
function BattleBuffEffect.onUpdate(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- Buff层数变化时触发
function BattleBuffEffect.onStack(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 子弹命中时触发（需满足indexRequire/bulletTagRequire/victimRequire）
function BattleBuffEffect.onBulletHit(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	if not self:bulletTagRequire(args.bulletTag) then
		return
	end

	if not self:victimRequire(args.target, owner) then
		return
	end

	self:onTrigger(owner, buff, args)
end

--- 队友子弹命中时触发
function BattleBuffEffect.onTeammateBulletHit(self, owner, buff, args)
	self:onBulletHit(owner, buff, args)
end

--- 被命中时触发
function BattleBuffEffect.onBeHit(self, owner, buff, args)
	if self._behit then
		if self._behit.damage_type == args.weaponType and self._behit.bullet_type == args.bulletType then
			self:onTrigger(owner, buff)
		end
	else
		self:onTrigger(owner, buff)
	end
end

--- 开火时触发
function BattleBuffEffect.onFire(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff)
end

--- 连击时触发（需满足上下界条件）
function BattleBuffEffect.onCombo(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	local matchUnitCount = args.matchUnitCount
	local upperBound = self._tempData.arg_list.upperBound
	local lowerBound = self._tempData.arg_list.lowerBound

	if upperBound and matchUnitCount <= upperBound then
		self:onTrigger(owner, buff)
	elseif lowerBound and lowerBound <= matchUnitCount then
		self:onTrigger(owner, buff)
	end
end

--- @class BattleBuffEffect
--- @param buff BattleBuffUnit Buff实例
--- @return boolean 堆叠数是否满足要求
function BattleBuffEffect.stackRequire(self, buff)
	if self._stackRequire then
		local stack = buff:GetStack()

		return BattleFormulas.simpleCompare(self._stackRequire, stack)
	else
		return true
	end
end

--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @param attr string 要比较的属性名
--- @return boolean 舰队属性是否满足要求
--- 检查舰队属性条件，支持解析比较运算符
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

--- @class BattleBuffEffect
--- @param delta number 属性变化量
--- @return boolean 舰队属性变化值是否满足要求
function BattleBuffEffect.fleetAttrDelatRequire(self, delta)
	if self._fleetAttrDeltaRequire then
		return delta and BattleFormulas.simpleCompare(self._fleetAttrDeltaRequire, delta)
	end

	return true
end

--- @class BattleBuffEffect
--- @param attrConsumeRepeat table {attrName, value, repeatCeil}
--- @return number 可消耗的层数
--- 消耗舰队属性值来触发重复效果，返回可触发的次数
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

--- @class BattleBuffEffect
--- @param repeatCount number|string 重复次数或属性表达式
--- @return number 解析后的重复次数
--- 解析repeat_count字段，支持number直接返回，string则从fleetAttr或attr取值
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

--- @class BattleBuffEffect
--- @param equipIndex number 装备索引
--- @return boolean 装备索引是否匹配
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

--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @return boolean 弹药类型和装备位置是否满足要求
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

--- @class BattleBuffEffect
--- @param bulletTags table<string> 子弹标签列表
--- @return boolean 子弹标签是否匹配
function BattleBuffEffect.bulletTagRequire(self, bulletTags)
	if not self._bulletTagRequire then
		return true
	else
		for _, tag in ipairs(self._bulletTagRequire) do
			if table.contains(bulletTags, tag) then
				return true
			else
				return false
			end
		end
	end
end

--- @class BattleBuffEffect
--- @param buffID number Buff ID
--- @return boolean Buff状态ID是否匹配
function BattleBuffEffect.buffStateRequire(self, buffID)
	if not self._buffStateIDRequire then
		return true
	else
		return buffID == self._buffStateIDRequire
	end
end

--- 武器准备就绪时触发（委托给onFire）
function BattleBuffEffect.onWeaponSteday(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 蓄力武器开火时触发
function BattleBuffEffect.onChargeWeaponFire(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 鱼雷武器开火时触发
function BattleBuffEffect.onTorpedoWeaponFire(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 防空炮远程开火时触发
function BattleBuffEffect.onAntiAirWeaponFireFar(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 防空炮近程开火时触发
function BattleBuffEffect.onAntiAirWeaponFireNear(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 手动导弹开火时触发
function BattleBuffEffect.onManualMissileFire(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 全弹发射时触发
function BattleBuffEffect.onAllInStrike(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 全弹发射准备时触发
function BattleBuffEffect.onAllInStrikeSteady(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 定点打击准备时触发
function BattleBuffEffect.onPointStrikeReady(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 定点打击准备就绪时触发
function BattleBuffEffect.onPointStrikeSteady(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 定点打击时触发
function BattleBuffEffect.onPointStrike(self, owner, buff, args)
	self:onFire(owner, buff, args)
end

--- 武器中断时触发
function BattleBuffEffect.onWeaonInterrupt(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 武器成功开火时触发
function BattleBuffEffect.onWeaponSuccess(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 蓄力武器准备就绪时触发
function BattleBuffEffect.onChargeWeaponReady(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 手动鱼雷准备就绪时触发
function BattleBuffEffect.onManualTorpedoReady(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 空袭支援准备就绪时触发
function BattleBuffEffect.onAirAssistReady(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 手动导弹准备就绪时触发
function BattleBuffEffect.onManualMissileReady(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 鱼雷按钮按下时触发
function BattleBuffEffect.onTorpedoButtonPush(self, owner, buff, args)
	self:onTrigger(owner, buff)
end

--- 受到致命伤害前触发
function BattleBuffEffect.onBeforeFatalDamage(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 舰载机创建时触发
function BattleBuffEffect.onAircraftCreate(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 友方舰载机被击落时触发
function BattleBuffEffect.onFriendlyAircraftDying(self, owner, buff, args)
	if self._tempData.arg_list.templateID then
		if args.unit:GetTemplateID() == self._tempData.arg_list.templateID then
			self:onTrigger(owner, buff)
		end
	else
		self:onTrigger(owner, buff)
	end
end

--- 友方舰船沉没时触发
function BattleBuffEffect.onTeammateShipDying(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 敌方舰载机被击落时触发
function BattleBuffEffect.onFoeAircraftDying(self, owner, buff, args)
	if self._tempData.arg_list.inside then
		local unit = args.unit

		if not owner:GetFleetVO():GetFleetAntiAirWeapon():IsOutOfRange(unit) then
			self:onTrigger(owner, buff)
		end
	elseif self._tempData.arg_list.killer then
		if self:killerRequire(self._tempData.arg_list.killer, args.killer, owner) then
			self:onTrigger(owner, buff)
		end
	else
		self:onTrigger(owner, buff)
	end
end

--- 敌方单位被击沉时触发
function BattleBuffEffect.onFoeDying(self, owner, buff, args)
	if self._tempData.arg_list.killer then
		if self:killerRequire(self._tempData.arg_list.killer, args.killer, owner) then
			self:onTrigger(owner, buff)
		end
	elseif self:victimRequire(args.unit, owner) then
		self:onTrigger(owner, buff)
	else
		self:onTrigger(owner, buff)
	end
end

--- 自身被击沉时触发
function BattleBuffEffect.onSink(self, owner, buff)
	if self:deathCauseRequire(owner) then
		self:onTrigger(owner, buff)
	end
end

--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @return boolean 死亡原因是否匹配
function BattleBuffEffect.deathCauseRequire(self, owner)
	if not self._deathCauseRequire then
		return true
	end

	local deathReason = owner:GetDeathReason()

	return table.contains(self._deathCauseRequire, deathReason)
end

--- @class BattleBuffEffect
--- @param requiredKiller string 要求的击杀者类型（"self"/"child"）
--- @param killer BattleUnit 击杀者单位
--- @param owner BattleUnit Buff持有者
--- @return boolean 击杀者是否匹配要求
--- 检查击杀者身份：killer可能是子弹的Host，需要向上追溯
function BattleBuffEffect.killerRequire(self, requiredKiller, killer, owner)
	if not killer then
		return false
	end

	local actualKiller
	local killerMother
	local killerName = killer.__name

	-- 如果killer是主要舰船类型，直接用；否则获取Host（可能是子弹的发射者）
	if killerName == ys.Battle.BattlePlayerUnit.__name or killerName == ys.Battle.BattleNPCUnit.__name or killerName == ys.Battle.BattleMinionUnit.__name or killerName == ys.Battle.BattleEnemyUnit.__name or killerName == ys.Battle.BattleAircraftUnit.__name or killerName == ys.Battle.BattleAirFighterUnit.__name then
		actualKiller = killer
	else
		actualKiller = killer:GetHost()
	end

	if actualKiller then
		local actualKillerName = actualKiller.__name

		if actualKillerName == ys.Battle.BattleAircraftUnit.__name then
			killerMother = actualKiller:GetMotherUnit()
		elseif actualKillerName == ys.Battle.BattleMinionUnit.__name then
			killerMother = actualKiller:GetMaster()
		else
			killerMother = actualKiller
			actualKiller = nil
		end
	else
		return false
	end

	if requiredKiller == "self" then
		if killerMother == owner and not actualKiller then
			return true
		end
	elseif requiredKiller == "child" and killerMother == owner and actualKiller then
		return true
	end

	return false
end

--- @class BattleBuffEffect
--- @param victim BattleUnit 受害者单位
--- @param owner BattleUnit Buff持有者
--- @return boolean 受害者标签是否匹配
function BattleBuffEffect.victimRequire(self, victim, owner)
	if not self._victimTagRequire then
		return true
	elseif victim:ContainsLabelTag(self._victimTagRequire) then
		return true
	else
		return false
	end
end

--- @class BattleBuffEffect
--- @param weaponIDList table<number> 要求的武器ID列表
--- @param killer BattleUnit 击杀者
--- @param owner BattleUnit Buff持有者
--- @return boolean 击杀者的武器ID是否在列表中
function BattleBuffEffect.killerWeaponRequire(self, weaponIDList, killer, owner)
	if not killer then
		return false
	end

	if not killer.GetWeapon then
		return false
	end

	local weaponId = killer:GetWeapon():GetWeaponId()

	if table.contains(weaponIDList, weaponId) then
		return true
	end
end

--- @class BattleBuffEffect
--- @param sourceID number 伤害来源ID
--- @param owner BattleUnit Buff持有者
--- @return boolean 伤害来源标签是否匹配
function BattleBuffEffect.DamageSourceRequire(self, sourceID, owner)
	if not self._damageSrcTagRequire then
		return true
	else
		if not sourceID then
			return false
		end

		local sourceUnit = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()[sourceID]

		if not sourceUnit then
			return false
		end

		if sourceUnit:ContainsLabelTag(self._damageSrcTagRequire) then
			return true
		else
			return false
		end
	end
end

--- 游戏初始化时触发
function BattleBuffEffect.onInitGame(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 游戏开始时触发
function BattleBuffEffect.onStartGame(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 游戏结束时触发
function BattleBuffEffect.onFinishGame(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 切换手动操作时触发
function BattleBuffEffect.onManual(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 切换自动战斗时触发
function BattleBuffEffect.onAutoBot(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 旗舰位触发
function BattleBuffEffect.onFlagShip(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- DAL联动旗舰位触发
function BattleBuffEffect.onDALCollabFlagShip(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 上位僚舰触发
function BattleBuffEffect.onUpperConsort(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 下位僚舰触发
function BattleBuffEffect.onLowerConsort(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 领舰触发
function BattleBuffEffect.onLeader(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 中位触发
function BattleBuffEffect.onCenter(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 后排触发
function BattleBuffEffect.onRear(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 潜艇领舰触发
function BattleBuffEffect.onSubLeader(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 潜艇上位僚舰触发
function BattleBuffEffect.onUpperSubConsort(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 潜艇下位僚舰触发
function BattleBuffEffect.onLowerSubConsort(self, owner, buff)
	self:onTrigger(owner, buff)
end

--- 子弹碰撞时触发
function BattleBuffEffect.onBulletCollide(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff)
end

--- 子弹碰撞前触发
function BattleBuffEffect.onBulletCollideBefore(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff)
end

--- 航弹爆炸时触发
function BattleBuffEffect.onBombBulletBang(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff)
end

--- 鱼雷爆炸时触发
function BattleBuffEffect.onTorpedoBulletBang(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff)
end

--- 子弹命中前触发（受behit条件限制）
function BattleBuffEffect.onBulletHitBefore(self, owner, buff, args)
	if self._behit then
		if self._behit.damage_type == args.weaponType and self._behit.bullet_type == args.bulletType then
			self:onTrigger(owner, buff)
		end
	else
		self:onTrigger(owner, buff)
	end
end

--- 子弹创建时触发
function BattleBuffEffect.onBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff, args)
end

--- 蓄力武器子弹创建时触发
function BattleBuffEffect.onChargeWeaponBulletCreate(self, owner, buff, args)
	self:onBulletCreate(owner, buff, args)
end

--- 鱼雷武器子弹创建时触发
function BattleBuffEffect.onTorpedoWeaponBulletCreate(self, owner, buff, args)
	self:onBulletCreate(owner, buff, args)
end

--- 内置子弹创建时触发
function BattleBuffEffect.onInternalBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff, args)
end

--- 手动发射子弹创建时触发
function BattleBuffEffect.onManualBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:onTrigger(owner, buff, args)
end

--- 受到伤害前触发（需damageCheck）
function BattleBuffEffect.onBeforeTakeDamage(self, owner, buff, args)
	if self:damageCheck(args) then
		self:onTrigger(owner, buff, args)
	end
end

--- 受到伤害时触发（需damageCheck）
function BattleBuffEffect.onTakeDamage(self, owner, buff, args)
	if self:damageCheck(args) then
		self:onTrigger(owner, buff, args)
	end
end

--- 受到治疗时触发
function BattleBuffEffect.onTakeHealing(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 护盾吸收伤害时触发
function BattleBuffEffect.onShieldAbsorb(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 伤害修正时触发
function BattleBuffEffect.onDamageFix(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 伤害结算完成时触发
function BattleBuffEffect.onDamageConclude(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 过量治疗时触发
function BattleBuffEffect.onOverHealing(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 舰队属性更新时触发
function BattleBuffEffect.onFleetAttrUpdate(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- @class BattleBuffEffect
--- @param args table {damageAttr, damageReason}
--- @return boolean 伤害属性与原因是否都满足
function BattleBuffEffect.damageCheck(self, args)
	return self:damageAttrRequire(args.damageAttr) and self:damageReasonRequire(args.damageReason)
end

--- @class BattleBuffEffect
--- @param damageAttr number 伤害属性
--- @return boolean 伤害属性是否匹配
function BattleBuffEffect.damageAttrRequire(self, damageAttr)
	if not self._damageAttrRequire or table.contains(self._damageAttrRequire, damageAttr) then
		return true
	else
		return false
	end
end

--- @class BattleBuffEffect
--- @param damageReason number 伤害原因
--- @return boolean 伤害原因是否匹配
function BattleBuffEffect.damageReasonRequire(self, damageReason)
	if not self._damageReasonRequire or table.contains(self._damageReasonRequire, damageReason) then
		return true
	else
		return false
	end
end

--- @class BattleBuffEffect
--- @param hpRate number 当前HP比例
--- @param dHP number HP变化量
--- @return boolean HP比例区间是否满足要求
--- 检查HP比例是否在指定区间内（或区间外），考虑方向符号
function BattleBuffEffect.hpIntervalRequire(self, hpRate, dHP)
	if self._hpUpperBound == nil and self._hpLowerBound == nil then
		return true
	end

	if not dHP or self._hpSigned == 0 then
		-- block empty
	elseif dHP * self._hpSigned < 0 then
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

--- @class BattleBuffEffect
--- @param maxHP number 最大HP
--- @param dHP number HP变化量
--- @return boolean HP变化量是否满足要求
--- 检查dHP的绝对值和符号是否满足条件
function BattleBuffEffect.dhpRequire(self, maxHP, dHP)
	if self._dHPGreater then
		return dHP * self._dHPGreater > 0 and math.abs(dHP) > math.abs(self._dHPGreater)
	elseif self._dHPGreaterMaxHP then
		local threshold = self._dHPGreaterMaxHP * maxHP

		return dHP * threshold > 0 and math.abs(dHP) > math.abs(threshold)
	elseif self._dhpSmaller then
		return dHP * self._dhpSmaller > 0 and math.abs(dHP) < math.abs(self._dhpSmaller)
	elseif self._dhpSmallerMaxhp then
		local threshold = self._dhpSmallerMaxhp * maxHP

		return dHP * threshold > 0 and math.abs(dHP) < math.abs(threshold)
	else
		return true
	end
end

--- @class BattleBuffEffect
--- @param attrIntervalValue number 属性值
--- @return boolean 属性值是否在开区间内
--- 注意: 这个检查略有不同，实际上满足要求的是开区间(lowerBound, upperBound)
function BattleBuffEffect.attrIntervalRequire(self, attrIntervalValue)
	local satisfied = true

	if self._attrUpperBound and attrIntervalValue >= self._attrUpperBound then
		satisfied = false
	end

	if self._attrLowerBound and attrIntervalValue <= self._attrLowerBound then
		satisfied = false
	end

	return satisfied
end

--- 自身HP比例更新时触发
function BattleBuffEffect.onHPRatioUpdate(self, owner, buff, args)
	local hpRate = owner:GetHPRate()
	local dHP = args.dHP

	if self:hpIntervalRequire(hpRate, dHP) and self:dhpRequire(owner:GetMaxHP(), dHP) then
		self:doOnHPRatioUpdate(owner, buff, args)
	end
end

--- 友方HP比例更新时触发
function BattleBuffEffect.onFriendlyHpRatioUpdate(self, owner, buff, args)
	local unit = args.unit
	local dHP = args.dHP
	local hpRate = unit:GetHPRate()

	if self:hpIntervalRequire(hpRate, dHP) and self:dhpRequire(unit:GetMaxHP(), dHP) then
		self:doOnHPRatioUpdate(owner, buff, args)
	end
end

--- 队友HP比例更新时触发
function BattleBuffEffect.onTeammateHpRatioUpdate(self, owner, buff, args)
	self:onFriendlyHpRatioUpdate(owner, buff, args)
end

--- 子弹击杀时触发
function BattleBuffEffect.onBulletKill(self, owner, buff, args)
	if self._tempData.arg_list.killer_weapon_id then
		if self:killerWeaponRequire(self._tempData.arg_list.killer_weapon_id, args.killer, owner) then
			self:onTrigger(owner, buff)
		end
	else
		self:onTrigger(owner, buff)
	end
end

--- 用于处理那些依赖buffEffect计数器的效果
--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @param buff BattleBuffUnit Buff实例
--- @param args table {buffFX: BattleBuffEffect}
--- 当buffEffect计数器变化时触发，支持Repeater模式（累计消耗）和一次性模式
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

--- 护盾被击破时触发
function BattleBuffEffect.onShieldBroken(self, owner, buff, args)
	if args.shieldBuffID == self._tempData.arg_list.shieldBuffID then
		self:onTrigger(owner, buff)
	end
end

--- @class BattleBuffEffect
--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @param args table<string, any>
--- BuffEffect通用触发函数
--- - quota -= 1
function BattleBuffEffect.onTrigger(self, owner, buff, args)
	if self._quota > 0 then
		self._quota = self._quota - 1
	end
end

--- HP比例更新后的实际操作（供子类重载）
function BattleBuffEffect.doOnHPRatioUpdate(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 友方HP比例更新后的实际操作
function BattleBuffEffect.doOnFriendlyHPRatioUpdate(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇下潜时触发
function BattleBuffEffect.onSubmarineDive(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇突袭时触发
function BattleBuffEffect.onSubmarineRaid(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇上浮时触发
function BattleBuffEffect.onSubmarineFloat(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇撤退时触发
function BattleBuffEffect.onSubmarineRetreat(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇支援时触发
function BattleBuffEffect.onSubmarineAid(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇自由下潜时触发
function BattleBuffEffect.onSubmarinFreeDive(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇自由上浮时触发
function BattleBuffEffect.onSubmarinFreeFloat(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇自由特殊行动时触发
function BattleBuffEffect.onSubmarineFreeSpecial(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇被侦测到时触发
function BattleBuffEffect.onSubDetected(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 潜艇脱离侦测时触发
function BattleBuffEffect.onSubUnDetected(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 反潜仇恨链时触发
function BattleBuffEffect.onAntiSubHateChain(self, owner, buff, args)
	self:onTrigger(owner, buff, attach)
end

--- 撤退时触发
function BattleBuffEffect.onRetreat(self, owner, buff, args)
	self:onTrigger(owner, buff, args)
end

--- 隐身状态变化时触发
function BattleBuffEffect.onCloakUpdate(self, owner, buff, args)
	if self:cloakStateRequire(args.cloakState) then
		self:onTrigger(owner, buff, args)
	end
end

--- 队友隐身状态变化时触发
function BattleBuffEffect.onTeammateCloakUpdate(self, owner, buff, args)
	if self:cloakStateRequire(args.cloakState) then
		self:onTrigger(owner, buff, args)
	end
end

--- @class BattleBuffEffect
--- @param cloakState number 隐身状态
--- @return boolean 隐身状态是否匹配
function BattleBuffEffect.cloakStateRequire(self, cloakState)
	if not self._cloakRequire then
		return true
	else
		return self._cloakRequire == cloakState
	end
end

--- 中断BuffEffect
function BattleBuffEffect.Interrupt(self)
	return
end

--- 清除BuffEffect状态
function BattleBuffEffect.Clear(self)
	self._commander = nil
end

--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @param targetTypeList string|table<string> 目标筛选类型列表
--- @param arg_list table<string, any> Buff配置参数
--- @param extraArgs table<string, any> 额外参数（如damageSrc）
--- @return table<BattleUnit> 目标列表
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

--- @class BattleBuffEffect
--- @param owner BattleUnit Buff持有者
--- @return boolean 指挥喵Buff条件是否满足
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

--- @class BattleBuffEffect
--- @return boolean 是否激活
function BattleBuffEffect.IsActive(self)
	return self._isActive
end

--- 设置为激活状态
function BattleBuffEffect.SetActive(self)
	self._isActive = true
end

--- 设置为非激活状态
function BattleBuffEffect.NotActive(self)
	self._isActive = false
end

--- @class BattleBuffEffect
--- @return boolean 是否锁定
function BattleBuffEffect.IsLock(self)
	return self._isLock
end

--- 设置为锁定状态
function BattleBuffEffect.SetLock(self)
	self._isLock = true
end

--- 设置为非锁定状态
function BattleBuffEffect.NotLock(self)
	self._isLock = false
end

--- 销毁BuffEffect
function BattleBuffEffect.Dispose(self)
	return
end
