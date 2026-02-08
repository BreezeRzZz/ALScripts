ys = ys or {}

local ys = ys

ys.Battle.BattleBuffRecordShield = class("BattleBuffRecordShield", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffRecordShield.__name = "BattleBuffRecordShield"

local BattleBuffRecordShield = ys.Battle.BattleBuffRecordShield

BattleBuffRecordShield.MODE_RECORD = "record"
BattleBuffRecordShield.MODE_SHIELD = "shield"

-- 此类BuffEffect会先进入记录模式，记录满足条件的伤害，持续时间结束后转换为护盾，护盾持续时间结束或者护盾值耗尽后再次转换为记录模式，如此循环
-- 使用例: 莫加多尔2技能
function BattleBuffRecordShield.Ctor(self, arg_1_1)
	BattleBuffRecordShield.super.Ctor(self, arg_1_1)
end

function BattleBuffRecordShield.GetEffectAttachData(self)
	return self._shieldValue
end

function BattleBuffRecordShield.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._damageAttrRequire = arg_list.damageAttr
	self._damageSrcTagRequire = arg_list.srcTag
	self._convertRate = arg_list.convertRate
	self._shieldDuration = arg_list.shield_duration
	self._recordDuration = arg_list.record_duration
	self._exhaustRemove = arg_list.exhaust_remove
	self._shieldValue = 0
	self._recordDamage = 0
	self._shieldStartTimeStamp = 0
	self._recordStartTimeStamp = 0
	self._unit = owner
	self._fxName = arg_list.effect
	self._effectIndex = "BattleBuffRecordShield" .. buff:GetID()

	self:switchMode(BattleBuffRecordShield.MODE_RECORD)
end

function BattleBuffRecordShield.onUpdate(self, owner, buff)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	if self._buffMode == BattleBuffRecordShield.MODE_SHIELD then
		-- 护盾持续时间到或者护盾值耗尽
		if self._shieldDuration and currentTime - self._shieldStartTimeStamp > self._shieldDuration or self._shieldValue <= 0 then
			self:handleShieldExhaust(buff)
		end
	elseif self._buffMode == BattleBuffRecordShield.MODE_RECORD and self._recordDuration and currentTime - self._recordStartTimeStamp > self._recordDuration then
		self:switchMode(BattleBuffRecordShield.MODE_SHIELD)
	end
end

function BattleBuffRecordShield.handleShieldExhaust(self, buff)
	if self._exhaustRemove then
		buff:SetToCancel()
	else
		self:switchMode(BattleBuffRecordShield.MODE_RECORD)
	end
end

function BattleBuffRecordShield.switchMode(self, mode)
	self._buffMode = mode

	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()
	-- 根据模式不同，写了两种onTakeDamage函数，分别处理护盾和记录两种情况
	-- (两种模式会互相切换，所以需要两种函数，不能在一个函数里处理两种情况)
	if mode == BattleBuffRecordShield.MODE_SHIELD then
		self._shieldStartTimeStamp = currentTime
		self._shieldValue = self:calcNumber()
		self.onTakeDamage = BattleBuffRecordShield.__shieldTakeDamage

		local addEffectArgs = {
			index = self._effectIndex,
			effect = self._fxName
		}

		self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, addEffectArgs))
	elseif mode == BattleBuffRecordShield.MODE_RECORD then
		self._recordStartTimeStamp = currentTime
		self._recordDamage = 0
		self._shieldValue = 0
		self.onTakeDamage = BattleBuffRecordShield.__recordDamage

		self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.CANCEL_EFFECT, {
			index = self._effectIndex
		}))
	end
end

function BattleBuffRecordShield.__shieldTakeDamage(self, owner, buff, args)
	if self:damageCheck(args) then
		local damage = args.damage

		self._shieldValue = self._shieldValue - damage

		if self._shieldValue > 0 then
			args.damage = 0
		else
			args.damage = -self._shieldValue

			self:handleShieldExhaust(buff)
		end
	end
end

function BattleBuffRecordShield.__recordDamage(self, owner, buff, args)
	if not self:damageCheck(args) then
		return
	end

	if not self:DamageSourceRequire(args.damageSrc) then
		return
	end

	self._recordDamage = self._recordDamage + args.damage

	if not self._recordDuration and self:calcNumber() >= 1 then
		self:switchMode(BattleBuffRecordShield.MODE_SHIELD)
	end
end

-- 核心: 将记录模式下记录的伤害转换为护盾值
function BattleBuffRecordShield.calcNumber(self)
	return (math.max(0, math.floor(self._recordDamage * self._convertRate)))
end

function BattleBuffRecordShield.Clear(self)
	self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.CANCEL_EFFECT, {
		index = self._effectIndex
	}))
	BattleBuffRecordShield.super.Clear(self)
end
