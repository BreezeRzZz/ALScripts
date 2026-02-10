ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEvent = ys.Battle.BattleEvent
local BattleSkillCLSArea = class("BattleSkillCLSArea", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillCLSArea = BattleSkillCLSArea
BattleSkillCLSArea.__name = "BattleSkillCLSArea"
BattleSkillCLSArea.TYPE_BULLET = 1
BattleSkillCLSArea.TYPE_AIRCRAFT = 2
BattleSkillCLSArea.TYPE_MINION = 3

-- 此类SkillEffect会在指定位置生成一个持续性的AOE，AOE的碰撞逻辑是消弹（CLS），会消除掉所有在区域内的符合条件的子弹
-- 主要是两类: 区域型(环绕自身消弹)和放射型(发射一个小AOE，AOE以一定速度前进, 消除路径上的子弹)
-- 消除的类型根据bullet_type_list参数来区分，参数里需要包含子弹的类型，才会被消除
-- 使用例: 特殊兵装的斩击
function BattleSkillCLSArea.Ctor(self, effectData)
	BattleSkillCLSArea.super.Ctor(self, effectData, lv)

	self._range = self._tempData.arg_list.range
	self._width = self._tempData.arg_list.width
	self._height = self._tempData.arg_list.height
	self._minRange = self._tempData.arg_list.minRange or 0
	self._angle = self._tempData.arg_list.angle
	self._lifeTime = self._tempData.arg_list.life_time
	self._fx = self._tempData.arg_list.effect
	self._moveType = self._tempData.arg_list.move_type
	self._speed = self._tempData.arg_list.speed_x
	self._finaleFX = self._tempData.arg_list.finale_effect
	self._delayCLS = self._tempData.arg_list.cld_delay
	self._bulletType = self._tempData.arg_list.bullet_type_list
	self._damageSrcUnitTag = self._tempData.arg_list.damage_tag_list
	self._damageParamA = self._tempData.arg_list.damage_param_a
	self._damageParamB = self._tempData.arg_list.damage_param_b
	self._damageSFX = self._tempData.arg_list.damage_sfx or ""
	self._damageBuffID = self._tempData.arg_list.buff_id
	self._damageBuffLV = self._tempData.arg_list.buff_lv
	self._damageDiveFilter = self._tempData.arg_list.diveFilter or {
		2
	}
	self._damageDiveDMGRate = self._tempData.arg_list.diveDamageRate or {
		1,
		1
	}
	self._delayCLSTimerList = {}
end

function BattleSkillCLSArea.DoDataEffect(self, caster)
	self:doCLS(caster)
end

function BattleSkillCLSArea.DoDataEffectWithoutTarget(self, caster)
	self:doCLS(caster)
end

function BattleSkillCLSArea.doCLS(self, caster)
	if self._angle then
		self:cacheSectorData(caster)
	end

	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()

	-- 会消除掉所有在区域内的符合条件的子弹
	local function areaCldFunc(cldObjList)
		for _, cldObj in ipairs(cldObjList) do
			local cldObjUID = cldObj.UID
			local bullet = battleDataProxy:GetBulletList()[cldObj.UID]
			-- 子弹存在
			-- 子弹类型符合参数
			-- ImmuneCLS: BattleBulletDataFunction中的各种子弹的create方法，预定义了EffectBullet、GravitationBullet、SpaceLaser、Missile是免疫CLS的
			-- ImmuneBombCLS：看子弹的ignoreB参数
			-- isEnterBlind: 判断子弹是否超出range
			-- isOutOfAngle: 判断子弹是否在扇形范围内
			if bullet:GetExist() and self:checkBulletType(bullet) and not bullet:ImmuneCLS() and not bullet:ImmuneBombCLS() and not self:isEnterBlind(bullet) and not self:isOutOfAngle(bullet) then
				-- 如果有delayCLS，则延时销毁
				if self._delayCLS then
					local clsBulletTimer

					local function clsFunc()
						if bullet:GetExist() then
							battleDataProxy:RemoveBulletUnit(cldObjUID)
						end

						pg.TimeMgr.GetInstance():RemoveBattleTimer(clsBulletTimer)

						self._delayCLSTimerList[clsBulletTimer] = nil
					end

					clsBulletTimer = pg.TimeMgr.GetInstance():AddBattleTimer("clsBullet", -1, self._delayCLS, clsFunc, true)
					self._delayCLSTimerList[clsBulletTimer] = true
				else
					battleDataProxy:RemoveBulletUnit(cldObjUID)
				end
			end
		end
	end

	local function endFunc()
		for delayCLSTimer, _ in pairs(self._delayCLSTimerList) do
			delayCLSTimer.func()
			pg.TimeMgr.GetInstance():RemoveBattleTimer(delayCLSTimer)

			self._delayCLSTimerList[delayCLSTimer] = nil
		end

		self._delayCLSTimerList = {}

		if self._finaleFX then
			battleDataProxy:SpawnEffect(self._finaleFX, self._cldArea:GetPosition(), 1)
		end
	end

	self._cldArea = self:generateArea(caster, BattleConst.AOEField.BULLET, areaCldFunc, endFunc, self._fx)

	if self._damageSrcUnitTag then
		-- 以下涉及特殊兵装的消弹斩击伤害计算逻辑
		local candidateList1 = ys.Battle.BattleTargetChoise.TargetAllHelp(caster)
		local candidateList2 = ys.Battle.BattleTargetChoise.TargetShipTag(caster, {
			ship_tag_list = self._damageSrcUnitTag
		}, candidateList1)
		-- 上面两步计算友方单位中，符合tag条件的单位列表
		-- 一般就是分类别统计，分远程(sp_far)和近程(sp_near)两种
		local satisfiedNum = #candidateList2

		if satisfiedNum <= 0 then
			return
		end

		local formulaLevelSum = 0

		for _, unit in ipairs(candidateList2) do
			formulaLevelSum = formulaLevelSum + unit:GetAttrByName("formulaLevel")
		end
		-- 伤害计算公式
		local averageLevel = math.floor(formulaLevelSum / satisfiedNum)
		local baseDamage = self._damageParamA + averageLevel * self._damageParamB

		local function areaCldDamageFunc(cldObjList)
			for _, cldObj in ipairs(cldObjList) do
				if cldObj.Active then
					local cldObjUID = cldObj.UID
					local cldUnit = battleDataProxy:GetUnitList()[cldObjUID]
					local cldUnitOxyState = cldUnit:GetCurrentOxyState()
					-- 这没用到，实际上单位的OxyState就不重要了
					local diveDamage = math.floor(self._damageDiveDMGRate[cldUnitOxyState] * baseDamage)

					battleDataProxy:HandleDirectDamage(cldUnit, baseDamage)
					ys.Battle.PlayBattleSFX(self._damageSFX)

					if self._damageBuffID and cldUnit:IsAlive() then
						local damageBuff = ys.Battle.BattleBuffUnit.New(self._damageBuffID, nil, caster)

						damageBuff:SetOrb(caster, self._damageBuffLV or 1)
						cldUnit:AddBuff(damageBuff)
					end
				end
			end
		end

		local function endDamageFunc()
			return
		end

		self:generateArea(caster, BattleConst.AOEField.SURFACE, areaCldDamageFunc, endDamageFunc):SetDiveFilter(self._damageDiveFilter)
	end
end

function BattleSkillCLSArea.generateArea(self, caster, fieldType, areaCldFunc, endFunc, fx)
	local function exitCldFunc()
		return
	end

	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local casterIFF = caster:GetIFF()
	local lastingAOEData

	if self._range then
		lastingAOEData = battleDataProxy:SpawnLastingColumnArea(fieldType, casterIFF, caster:GetPosition(), self._range, self._lifeTime, areaCldFunc, exitCldFunc, false, fx, endFunc)
	else
		lastingAOEData = battleDataProxy:SpawnLastingCubeArea(fieldType, casterIFF, caster:GetPosition(), self._width, self._height, self._lifeTime, areaCldFunc, exitCldFunc, false, fx, endFunc)

		if casterIFF == BattleConfig.FRIENDLY_CODE then
			lastingAOEData:SetAnchorPointAlignment(lastingAOEData.ALIGNMENT_LEFT)
		elseif casterIFF == BattleConfig.FOE_CODE then
			lastingAOEData:SetAnchorPointAlignment(lastingAOEData.ALIGNMENT_RIGHT)
		end
	end

	local mobilizedComponent = ys.Battle.BattleAOEMobilizedComponent.New(lastingAOEData)

	mobilizedComponent:SetReferenceUnit(caster)

	local speedX = self._speed * casterIFF

	mobilizedComponent:ConfigData(self._moveType, {
		speedX = speedX
	})

	return lastingAOEData
end

-- 跟BattleWeaponUnit.cacheSectorData基本是一样的逻辑
function BattleSkillCLSArea.cacheSectorData(self, caster)
	local casterIFF = caster:GetIFF()
	local halfAngle = self._angle / 2

	self._upperEdge = math.deg2Rad * halfAngle
	self._lowerEdge = -1 * self._upperEdge

	if casterIFF == BattleConfig.FRIENDLY_CODE then
		self._normalizeOffset = 0
	elseif casterIFF == BattleConfig.FOE_CODE then
		self._normalizeOffset = math.pi
	end

	self._wholeCircle = math.pi - self._normalizeOffset
	self._negativeCircle = -math.pi - self._normalizeOffset
	self._wholeCircleNormalizeOffset = self._normalizeOffset - math.pi * 2
	self._negativeCircleNormalizeOffset = self._normalizeOffset + math.pi * 2
end

function BattleSkillCLSArea.isOutOfAngle(self, bullet)
	if not self._angle then
		return false
	end

	local bulletPos = bullet:GetPosition()
	local cldAreaPos = self._cldArea:GetPosition()
	local angle = math.atan2(bulletPos.z - cldAreaPos.z, bulletPos.x - cldAreaPos.x)

	if angle > self._wholeCircle then
		angle = angle + self._wholeCircleNormalizeOffset
	elseif angle < self._negativeCircle then
		angle = angle + self._negativeCircleNormalizeOffset
	else
		angle = angle + self._normalizeOffset
	end

	if angle > self._lowerEdge and angle < self._upperEdge then
		return false
	else
		return true
	end
end

function BattleSkillCLSArea.isEnterBlind(self, bullet)
	if self._minRange == 0 then
		return false
	end

	local bulletPos = bullet:GetPosition()
	local cldAreaPos = self._cldArea:GetPosition()

	return Vector3.BattleDistance(cldAreaPos, bulletPos) < self._minRange
end

function BattleSkillCLSArea.checkBulletType(self, bullet)
	if not self._bulletType then
		return true
	else
		local bulletType = bullet:GetType()
		-- SkillEffect的参数_bulletType中，需要包含子弹的类型，才返回true
		if table.contains(self._bulletType, bulletType) then
			return true
		else
			return false
		end
	end
end
