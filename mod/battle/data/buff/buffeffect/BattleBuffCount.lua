ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleBuffCount = class("BattleBuffCount", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffCount = BattleBuffCount
BattleBuffCount.__name = "BattleBuffCount"

-- 此BuffEffect是一个通用的计数器，可以基于不同的事件进行计数(攻击次数、受到伤害、血量变化等)，当计数达到指定数量时触发对应的效果(通常是触发另一个BuffEffect)
function BattleBuffCount.Ctor(self, effectData)
	BattleBuffCount.super.Ctor(self, effectData)
end

function BattleBuffCount.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_COUNTER
end

function BattleBuffCount.Repeater(self)
	return self._keepRestCount
end

function BattleBuffCount.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._countTarget = arg_list.countTarget or 1
	self._countType = arg_list.countType
	self._weaponType = arg_list.weaponType
	self._index = arg_list.index
	self._maxHPRatio = arg_list.maxHPRatio or 0
	self._casterMaxHPRatio = arg_list.casterMaxHPRatio or 0
	self._clock = self._tempData.arg_list.clock
	self._interrupt = self._tempData.arg_list.interrupt
	self._iconType = self._tempData.arg_list.iconType or 1
	self._gunnerBonus = arg_list.gunnerBonus
	self._keepRestCount = arg_list.keep

	self:ResetCount()

	if self._clock then
		owner:DispatchCastClock(true, self, self._iconType, self._interrupt)
	end
end

function BattleBuffCount.onRemove(self, owner, buff)
	if self._clock then
		local interrupt = self._interrupt and self._count < self._countTarget

		owner:DispatchCastClock(false, self, nil, interrupt)
	end
end

function BattleBuffCount.onTrigger(self, owner, buff)
	BattleBuffCount.super.onTrigger(self, owner, buff)

	self._count = self._count + 1

	self:checkCount(owner)
end
-- 这是onFire触发的计数器，主要用于全弹发射或其他基于攻击次数的触发
function BattleBuffCount.onFire(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self._count = self._count + 1
	-- 达到数量则触发
	self:checkModCount(owner)
end
-- 基于间隔时间的触发
function BattleBuffCount.onUpdate(self, owner, buff, args)
	local timeStamp = args.timeStamp

	self._count = timeStamp - (self._lastTriggerTime or buff:GetBuffStartTime())

	if self._count >= self._countTarget then
		self._lastTriggerTime = timeStamp

		self:ResetCount()
		owner:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_BATTLE_BUFF_COUNT, {
			buffFX = self
		})
	end
end
-- 基于受到伤害的触发，每受到一定伤害触发
function BattleBuffCount.onTakeDamage(self, owner, buff, args)
	-- damageCheck检查伤害的属性和伤害的原因(damageReason)
	if self:damageCheck(args) then
		local damage = args.damage

		self._count = self._count + damage

		self:checkHPCount(owner)
	end
end
-- 基于受到治疗的触发，每受到一定治疗量触发
function BattleBuffCount.onTakeHealing(self, owner, buff, args)
	local damage = args.damage

	self._count = self._count + damage

	self:checkHPCount(owner)
end
-- 基于血量变化的触发，每变动一定血量触发
function BattleBuffCount.onHPRatioUpdate(self, owner, buff, args)
	-- validDHP不计入溢出治疗和过量伤害
	local validDHP = math.abs(args.validDHP)

	self._count = self._count + validDHP

	self:checkHPCount(owner)
end
-- 基于叠层数的触发，每达到一定叠层数触发
function BattleBuffCount.onStack(self, owner, buff, args)
	self._count = buff:GetStack()

	self:checkCount(owner)
end
-- 基于子弹命中造成的伤害触发，每造成一定伤害触发
function BattleBuffCount.onBulletHit(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self._count = self._count + args.damage

	self:checkCount(owner)
end

function BattleBuffCount.checkCount(self, owner)
	if self._count >= self._countTarget then
		owner:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_BATTLE_BUFF_COUNT, {
			buffFX = self
		})
	end
end
-- 只有onFire会用，因为barrageCounterMod只影响全弹发射类的触发
function BattleBuffCount.checkModCount(self, owner)
	if self._count >= self:getCount(owner) then
		owner:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_BATTLE_BUFF_COUNT, {
			buffFX = self
		})
	end
end

function BattleBuffCount.getCount(self, owner)
	local countTarget = self._countTarget
	local barrageCounterMod = BattleAttr.GetCurrent(owner, "barrageCounterMod")
	-- barrageCounterMod 默认为1，对应加成的驱逐舰为2
	-- 为向上取整，例如11次攻击，驱逐舰加成后为6次触发
	if self._gunnerBonus then
		countTarget = math.ceil(countTarget / barrageCounterMod)
	end

	return countTarget
end
-- 检查计数是否到达指定血量
function BattleBuffCount.checkHPCount(self, owner)
	if not self._hpCountTarget then
		self:calcHPCount(owner)
	end

	if self._count >= self._hpCountTarget then
		owner:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_BATTLE_BUFF_COUNT, {
			buffFX = self
		})
	end
end

function BattleBuffCount.calcHPCount(self, owner)
	local _, ownerMaxHP = owner:GetHP()
	local _, casterMaxHP = self._caster:GetHP()

	self._hpCountTarget = math.floor(self._casterMaxHPRatio * casterMaxHP + self._maxHPRatio * ownerMaxHP + self._countTarget)
end

function BattleBuffCount.GetCountType(self)
	return self._countType
end

function BattleBuffCount.GetCountProgress(self)
	local target = self._hpCountTarget or self._countTarget

	return self._count / target
end

function BattleBuffCount.SetCount(self, count)
	self._count = count
end

function BattleBuffCount.ResetCount(self)
	self._count = 0
end

function BattleBuffCount.ConsumeCount(self)
	local target = self._hpCountTarget or self._countTarget

	self._count = math.max(self._count - target)
end
