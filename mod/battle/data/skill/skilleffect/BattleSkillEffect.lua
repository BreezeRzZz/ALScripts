ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleSkillEffect = class("BattleSkillEffect")
ys.Battle.BattleSkillEffect.__name = "BattleSkillEffect"

local BattleSkillEffect = ys.Battle.BattleSkillEffect

-- 核心SkillEffect之一
-- 这是所有SkillEffect的基类，其他SkillEffect都继承自它
-- SkillEffect之于Skill，就像BuffEffect之于BuffUnit一样，都是Skill/Unit的效果组成部分
-- 只不过两套体系的作用方式不一样. 相对来说Buff更复杂(有多种Trigger, 有持续时间). Skill简单很多(没有Trigger, 瞬发)
--- @param tempData table: 技能效果模板数据
--- @param level number: 技能等级
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

--- @param commander BattleUnit: 指挥者
function BattleSkillEffect.SetCommander(self, commander)
	self._commander = commander
end

-- 稍微规范一下: Buff那边叫"owner"，Skill这边叫"caster"
-- 因为Buff是一个持续性效果，所以叫owner更合适
-- Skill是一个瞬发效果，所以叫caster更合适
	-- (skill没有各种onXXX的Trigger)
-- 这也是根据两边数据结构本来的字段名称推测的
-- 被BattleSkillUnit.Cast调用
--- @param caster BattleUnit: 施法者
--- @param targetList table: 目标列表
--- @param attachData table: 附加数据
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

--- @return boolean: 是否为终曲效果
function BattleSkillEffect.IsFinaleEffect(self)
	return false
end

--- @param callback function: 终曲回调
function BattleSkillEffect.SetFinaleCallback(self, callback)
	self._finaleCallback = callback
end

--- 播放动画特效
--- @param caster BattleUnit: 施法者
--- @param target BattleUnit: 目标
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

--- 数据效果（支持延迟）
--- @param caster BattleUnit: 施法者
--- @param target BattleUnit: 目标
--- @param attachData table: 附加数据
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

--- 无目标时的数据效果（支持延迟）
--- @param caster BattleUnit: 施法者
--- @param attachData table: 附加数据
function BattleSkillEffect.DataEffectWithoutTarget(self, caster, attachData)
	if self._delay > 0 then
		local timer
		local newTimerIndex = self._timerIndex + 1

		self._timerIndex = newTimerIndex

		local function delayEffectFunc()
			if caster and caster:IsAlive() then
				self:DoDataEffectWithoutTarget(caster, attachData)
			end

			pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

			self._timerList[newTimerIndex] = nil
		end

		timer = pg.TimeMgr.GetInstance():AddBattleTimer("BattleSkill", -1, self._delay, delayEffectFunc, true)
		self._timerList[newTimerIndex] = timer
	else
		self:DoDataEffectWithoutTarget(caster, attachData)
	end
end

--- 子类重写此方法以实现无目标时的具体效果
function BattleSkillEffect.DoDataEffectWithoutTarget(self, caster, attachData)
	return
end

-- 被BattleSkillUnit.Cast调用
-- 用于获取目标列表
-- 因此可知，BattleSkillFire等的Target选取，无视了各种武器索敌逻辑(索敌范围等)
--- @param caster BattleUnit: 施法者
--- @param skill BattleSkillUnit: 所属技能
--- @return table: 目标列表
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

--- 中断效果
function BattleSkillEffect.Interrupt(self)
	return
end

--- 清理：移除所有计时器
function BattleSkillEffect.Clear(self)
	for i, timer in pairs(self._timerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(timer)

		self._timerList[i] = nil
	end

	self._commander = nil
end

-- BattleSkillPlayCameraFX/BattleSkillPlayFX.DoDataEffect调用
--- @param caster BattleUnit: 施法者
--- @param target BattleUnit: 目标
--- @return Vector3|nil: 计算出的坐标
function BattleSkillEffect.calcCorrdinate(self, caster, target)
	local corrdinate

	if self.absoulteCorrdinate then
		corrdinate = Vector3(self.absoulteCorrdinate.x, 0, self.absoulteCorrdinate.z)
	elseif self.absoulteRandom then
		corrdinate = BattleFormulas.RandomPos(self.absoulteRandom)
	elseif self.casterRelativeCorrdinate then
		local casterIFF = caster:GetIFF()
		local casterPosition = caster:GetPosition()
		local relativeCorrdinateX = casterIFF * self.casterRelativeCorrdinate.hrz + casterPosition.x
		local relativeCorrdinateZ = casterIFF * self.casterRelativeCorrdinate.vrt + casterPosition.z

		corrdinate = Vector3(relativeCorrdinateX, 0, relativeCorrdinateZ)
	elseif self.casterRelativeRandom then
		local casterIFF = caster:GetIFF()
		local casterPosition = caster:GetPosition()
		local relativeRandomPoint = {
			X1 = casterIFF * self.casterRelativeRandom.front + casterPosition.x,
			X2 = casterIFF * self.casterRelativeRandom.rear + casterPosition.x,
			Z1 = self.casterRelativeRandom.upper + casterPosition.z,
			Z2 = self.casterRelativeRandom.lower + casterPosition.z
		}

		corrdinate = BattleFormulas.RandomPos(relativeRandomPoint)
	elseif self.targetRelativeCorrdinate then
		if target then
			local targetIFF = target:GetIFF()
			local targetPosition = target:GetPosition()
			local targetCorrdinateX = targetIFF * self.targetRelativeCorrdinate.hrz + targetPosition.x
			local targetCorrdinateZ = targetIFF * self.targetRelativeCorrdinate.vrt + targetPosition.z

			corrdinate = Vector3(targetCorrdinateX, 0, targetCorrdinateZ)
		end
	elseif self.targetRelativeRandom and target then
		local targetIFF = target:GetIFF()
		local targetPosition = target:GetPosition()
		local relativeRandomPoint = {
			X1 = targetIFF * self.targetRelativeRandom.front + targetPosition.x,
			X2 = targetIFF * self.targetRelativeRandom.rear + targetPosition.x,
			Z1 = self.targetRelativeRandom.upper + targetPosition.z,
			Z2 = self.targetRelativeRandom.lower + targetPosition.z
		}

		corrdinate = BattleFormulas.RandomPos(relativeRandomPoint)
	end

	return corrdinate
end

--- @return number: 伤害总和
function BattleSkillEffect.GetDamageSum(self)
	return 0
end
