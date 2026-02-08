ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleSkillEffect = class("BattleSkillEffect")
ys.Battle.BattleSkillEffect.__name = "BattleSkillEffect"

local BattleSkillEffect = ys.Battle.BattleSkillEffect

function BattleSkillEffect.Ctor(self, tempData, level)
	self._tempData = tempData
	self._type = self._tempData.type
	self._targetChoise = self._tempData.target_choise or "TargetNull"
	self._casterAniEffect = self._tempData.casterAniEffect
	self._targetAniEffect = self._tempData.targetAniEffect
	self._delay = self._tempData.arg_list.delay or 0
	self._lastEffectTarget = {}
	self._timerList = {}
	self._timerIndex = 0
	self._level = level
end

function BattleSkillEffect.SetCommander(self, commander)
	self._commander = commander
end

-- 稍微规范一下: Buff那边叫"owner"，Skill这边叫"caster"
-- 因为Buff是一个持续性效果，所以叫owner更合适
-- Skill是一个瞬发效果，所以叫caster更合适
	-- (skill没有各种onXXX的Trigger)
-- 这也是根据两边数据结构本来的字段名称推测的
-- 被BattleSkillUnit.Cast调用
function BattleSkillEffect.Effect(self, caster, targetList, attachData)
	if targetList and #targetList > 0 then
		for _, target in ipairs(targetList) do
			self:AniEffect(caster, target)
			self:DataEffect(caster, target, attachData)
		end
	else
		self:DataEffectWithoutTarget(caster, attachData)
	end
end

function BattleSkillEffect.IsFinaleEffect(self)
	return false
end

function BattleSkillEffect.SetFinaleCallback(self, callback)
	self._finaleCallback = callback
end

function BattleSkillEffect.AniEffect(self, caster, target)
	local targetPos = target:GetPosition()
	local casterPos = caster:GetPosition()

	if self._casterAniEffect and self._casterAniEffect ~= "" then
		local casterAniEffect = self._casterAniEffect
		local casterPosFun
		-- 一些skillEffect的casterAniEffect里会带posFun，用于动态计算特效位置
		if casterAniEffect.posFun then
			function casterPosFun(param)
				return casterAniEffect.posFun(casterPos, targetPos, param)
			end
		end

		local args = {
			effect = casterAniEffect.effect,
			offset = casterAniEffect.offset,
			posFun = casterPosFun
		}

		caster:DispatchEvent(ys.Event.New(BattleUnitEvent.ADD_EFFECT, args))
	end

	if self._targetAniEffect and self._targetAniEffect ~= "" then
		local targetAniEffect = self._targetAniEffect
		local targetPosFun

		if targetAniEffect.posFun then
			function targetPosFun(param)
				return targetAniEffect.posFun(casterPos, targetPos, param)
			end
		end

		local args = {
			effect = targetAniEffect.effect,
			offset = targetAniEffect.offset,
			posFun = targetPosFun
		}

		target:DispatchEvent(ys.Event.New(BattleUnitEvent.ADD_EFFECT, args))
	end
end

function BattleSkillEffect.DataEffect(self, caster, target, attachData)
	if self._delay > 0 then
		local timer
		local newTimerIndex = self._timerIndex + 1

		self._timerIndex = newTimerIndex

		local function dataEffectFunc()
			if caster and caster:IsAlive() then
				self:DoDataEffect(caster, target, attachData)
			end

			pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

			self._timerList[newTimerIndex] = nil
		end

		timer = pg.TimeMgr.GetInstance():AddBattleTimer("BattleSkill", -1, self._delay, dataEffectFunc, true)
		self._timerList[newTimerIndex] = timer
	else
		self:DoDataEffect(caster, target, attachData)
	end
end

--- 子类重写此方法以实现具体效果
function BattleSkillEffect.DoDataEffect(self, caster, target, attachData)
	return
end

function BattleSkillEffect.DataEffectWithoutTarget(self, caster, attachData)
	if self._delay > 0 then
		local var_12_0
		local var_12_1 = self._timerIndex + 1

		self._timerIndex = var_12_1

		local function var_12_2()
			if caster and caster:IsAlive() then
				self:DoDataEffectWithoutTarget(caster, attachData)
			end

			pg.TimeMgr.GetInstance():RemoveBattleTimer(var_12_0)

			self._timerList[var_12_1] = nil
		end

		var_12_0 = pg.TimeMgr.GetInstance():AddBattleTimer("BattleSkill", -1, self._delay, var_12_2, true)
		self._timerList[var_12_1] = var_12_0
	else
		self:DoDataEffectWithoutTarget(caster, attachData)
	end
end

function BattleSkillEffect.DoDataEffectWithoutTarget(self, caster, attachData)
	return
end

-- 被BattleSkillUnit.Cast调用
-- 用于获取目标列表
-- 因此可知，BattleSkillFire等的Target选取，无视了各种武器索敌逻辑(索敌范围等)
function BattleSkillEffect.GetTarget(self, caster, skill)
	if type(self._targetChoise) == "string" then
		if self._targetChoise == "TargetSameToLastEffect" then
			return skill._lastEffectTarget
		else
			-- 跟buffEffect一样，同样使用BattleTargetChoise来选目标
			return ys.Battle.BattleTargetChoise[self._targetChoise](caster, self._tempData.arg_list)
		end
	elseif type(self._targetChoise) == "table" then
		local targetList

		for _, targetType in ipairs(self._targetChoise) do
			targetList = ys.Battle.BattleTargetChoise[targetType](caster, self._tempData.arg_list, targetList)
		end

		return targetList
	end
end

function BattleSkillEffect.Interrupt(self)
	return
end

function BattleSkillEffect.Clear(self)
	for i, timer in pairs(self._timerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

		self._timerList[i] = nil
	end

	self._commander = nil
end

function BattleSkillEffect.calcCorrdinate(arg_18_0, arg_18_1, arg_18_2)
	local var_18_0

	if arg_18_0.absoulteCorrdinate then
		var_18_0 = Vector3(arg_18_0.absoulteCorrdinate.x, 0, arg_18_0.absoulteCorrdinate.z)
	elseif arg_18_0.absoulteRandom then
		var_18_0 = BattleFormulas.RandomPos(arg_18_0.absoulteRandom)
	elseif arg_18_0.casterRelativeCorrdinate then
		local var_18_1 = arg_18_1:GetIFF()
		local var_18_2 = arg_18_1:GetPosition()
		local var_18_3 = var_18_1 * arg_18_0.casterRelativeCorrdinate.hrz + var_18_2.x
		local var_18_4 = var_18_1 * arg_18_0.casterRelativeCorrdinate.vrt + var_18_2.z

		var_18_0 = Vector3(var_18_3, 0, var_18_4)
	elseif arg_18_0.casterRelativeRandom then
		local var_18_5 = arg_18_1:GetIFF()
		local var_18_6 = arg_18_1:GetPosition()
		local var_18_7 = {
			X1 = var_18_5 * arg_18_0.casterRelativeRandom.front + var_18_6.x,
			X2 = var_18_5 * arg_18_0.casterRelativeRandom.rear + var_18_6.x,
			Z1 = arg_18_0.casterRelativeRandom.upper + var_18_6.z,
			Z2 = arg_18_0.casterRelativeRandom.lower + var_18_6.z
		}

		var_18_0 = BattleFormulas.RandomPos(var_18_7)
	elseif arg_18_0.targetRelativeCorrdinate then
		if arg_18_2 then
			local var_18_8 = arg_18_2:GetIFF()
			local var_18_9 = arg_18_2:GetPosition()
			local var_18_10 = var_18_8 * arg_18_0.targetRelativeCorrdinate.hrz + var_18_9.x
			local var_18_11 = var_18_8 * arg_18_0.targetRelativeCorrdinate.vrt + var_18_9.z

			var_18_0 = Vector3(var_18_10, 0, var_18_11)
		end
	elseif arg_18_0.targetRelativeRandom and arg_18_2 then
		local var_18_12 = arg_18_2:GetIFF()
		local var_18_13 = arg_18_2:GetPosition()
		local var_18_14 = {
			X1 = var_18_12 * arg_18_0.targetRelativeRandom.front + var_18_13.x,
			X2 = var_18_12 * arg_18_0.targetRelativeRandom.rear + var_18_13.x,
			Z1 = arg_18_0.targetRelativeRandom.upper + var_18_13.z,
			Z2 = arg_18_0.targetRelativeRandom.lower + var_18_13.z
		}

		var_18_0 = BattleFormulas.RandomPos(var_18_14)
	end

	return var_18_0
end

function BattleSkillEffect.GetDamageSum(arg_19_0)
	return 0
end
