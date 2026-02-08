ys = ys or {}

local ys = ys
local BattleAttr = ys.Battle.BattleAttr
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleBuffDOT = class("BattleBuffDOT", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffDOT.__name = "BattleBuffDOT"

local BattleBuffDOT = ys.Battle.BattleBuffDOT

BattleBuffDOT.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_DOT

-- 核心BuffEffect之一
-- 所有DOT类均使用这个实现
-- 这类BuffEffect会在持续时间内定期造成伤害(点燃/进水等)，伤害值可以根据Buff参数和目标属性计算得到。
-- DOT伤害可以被压制减免影响(但不受伤害加成影响)，如果DOT的伤害造成了目标死亡，并且这个DOT是具有传染性的，那么就会对周围的单位造成一个新的DOT效果(这个新的DOT效果的伤害值由原DOT的伤害值传染过来)，从而形成链式反应。此外
function BattleBuffDOT.Ctor(self, effectData)
	BattleBuffDOT.super.Ctor(self, effectData)
end

function BattleBuffDOT.GetEffectType(self)
	return ys.Battle.BattleBuffEffect.FX_TYPE_DOT
end

function BattleBuffDOT.SetArgs(self, owner, buff)
	self._number = self._tempData.arg_list.number or 0
	self._time = self._tempData.arg_list.time or 0
	self._nextEffectTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._time
	self._maxHPRatio = self._tempData.arg_list.maxHPRatio or 0
	self._currentHPRatio = self._tempData.arg_list.currentHPRatio or 0
	self._minRestHPRatio = self._tempData.arg_list.minRestHPRatio or 0
	self._randExtraRange = self._tempData.arg_list.randExtraRange or 0
	self._cloakExpose = self._tempData.arg_list.cloakExpose or 0
	self._exposeGroup = self._tempData.arg_list._exposeGroup or buff:GetID()
	self._level = self._level or 0
	self._metaDot = self._tempData.arg_list.metaDot

	local duration = 0
	-- 非META DOT
	if not self._metaDot then
		duration = BattleFormulas.CaclulateDOTDuration(self._tempData, self._orb, owner)
	end

	buff:SetOrbDuration(duration)

	if self._tempData.arg_list.WorldBossDotDamage then
		local WorldBossDotDamage = self._tempData.arg_list.WorldBossDotDamage
		-- 老版META DOT伤害公式
		self._igniteDMG = (ys.Battle.BattleDataProxy.GetInstance():GetInitData()[WorldBossDotDamage.useGlobalAttr] or pg.bfConsts.NUM0) * (WorldBossDotDamage.paramA or pg.bfConsts.NUM1)
	elseif self._orb then
		self._igniteAttr = self._tempData.arg_list.attr
		self._igniteCoefficient = self._tempData.arg_list.k
		self._igniteDMG = BattleFormulas.CalculateIgniteDamage(self._orb, self._igniteAttr, self._igniteCoefficient)
	-- 传染来的点燃伤害，相同
	elseif self._infection then
		self._igniteDMG = self._infection
	else
		self._igniteDMG = 0
	end

	if self._cloakExpose and self._cloakExpose > 0 then
		owner:CloakExpose(self._cloakExpose)
	end

	self._infective = self._tempData.arg_list.infective
	self._proxy = ys.Battle.BattleDataProxy.GetInstance()
end

function BattleBuffDOT.onStack(self, owner, buff)
	return
end

function BattleBuffDOT.onUpdate(self, owner, buff, args)
	if args.timeStamp >= self._nextEffectTime then
		self:doDamage(owner, buff)

		if owner:IsAlive() then
			self._nextEffectTime = self._nextEffectTime + self._time
		end
	end
end

function BattleBuffDOT.onSink(self, owner, buff, args)
	self:handleInfect(owner, buff)
end
-- 如果BuffEffect指定了有onRemove的话，在Buff移除时也会造成一次伤害
function BattleBuffDOT.onRemove(self, owner, buff)
	self:doDamage(owner, buff)
end

function BattleBuffDOT.doDamage(self, owner, buff)
	local aliveBeforeDamage = owner:IsAlive()
	local damage = self:CalcNumber(owner, buff)

	self._proxy:HandleDirectDamage(owner, damage)
	-- 在DOT持续期间死亡，可以传染
	if not owner:IsAlive() and aliveBeforeDamage then
		self:handleInfect(owner, buff)
	end
end

function BattleBuffDOT.handleInfect(self, owner, buff)
	if not self._infective then
		return
	end

	local target_choise = self._infective.target_choise
	-- 目前没有用infective.arg_list的BuffEffect
	local infectiveArgList = self._infective.arg_list
	local targetList = self:getTargetList(owner, target_choise, infectiveArgList, {})

	for _, target in ipairs(targetList) do
		local infectedBuff = ys.Battle.BattleBuffUnit.New(buff:GetID(), buff:GetLv())

		infectedBuff:SetInfection(self._igniteDMG)
		target:AddBuff(infectedBuff)
	end
end

function BattleBuffDOT.CalcNumber(self, owner, buff)
	if self._metaDot then
		local battleInitData = ys.Battle.BattleDataProxy.GetInstance():GetInitData()

		return (BattleFormulas.CaclulateMetaDotaDamage(battleInitData.bossConfigId, battleInitData.bossLevel))
	else
		local dotEnhanceRate = BattleFormulas.CaclulateDOTDamageEnhanceRate(self._tempData, self._orb, owner)
		local currentHP, maxHP = owner:GetHP()
		local baseDOTDMG = currentHP * self._currentHPRatio + maxHP * self._maxHPRatio + self._number + self._igniteDMG

		if self._randExtraRange > 0 then
			baseDOTDMG = baseDOTDMG + math.random(0, self._randExtraRange)
		end

		local finalDOTDMG = baseDOTDMG * (1 + dotEnhanceRate)
		-- 点燃伤害受到压制减免影响，按层数叠加(但目前的同ID DOT的stack都是1，不能叠层)
		-- 如果有minRestHPRatio，则目标最多被DOT掉到该比例的血量
		return math.max(0, math.floor(math.min(currentHP - maxHP * self._minRestHPRatio, finalDOTDMG * buff._stack * BattleAttr.GetCurrent(owner, "repressReduce"))))
	end
end
-- orb一般指的是源头，可以是BattleUnit，也可以是BattleBulletUnit等
function BattleBuffDOT.SetOrb(self, buff, orb, level)
	self._orb = orb
	self._level = level

	buff:SetOrbLevel(self._level)
end

function BattleBuffDOT.SetInfection(self, igniteDMG)
	self._infection = igniteDMG
end

-- 被BattleUnitCloakComponent.Update调用
-- 这是随动的. 如果某个Buff消失了，它的暴露值就不再提供了, 该单位的CloakValue会下降.
function BattleBuffDOT.UpdateCloakLock(owner)
	local buffList = owner:GetBuffList()
	local totalExpose = 0
	local groupMaxExpose = {}

	for _, buff in pairs(buffList) do
		for _, effect in ipairs(buff._effectList) do
			if effect:GetEffectType() == BattleBuffDOT.FX_TYPE then
				local cloakExpose = effect._cloakExpose
				local exposeGroup = effect._exposeGroup
				local maxExpose = groupMaxExpose[exposeGroup] or 0

				if maxExpose < cloakExpose then
					totalExpose = totalExpose + cloakExpose - maxExpose
					maxExpose = cloakExpose
				end

				groupMaxExpose[exposeGroup] = maxExpose
			end
		end
	end

	owner:CloakOnFire(totalExpose)
end
