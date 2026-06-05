ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleBuffEvent = ys.Battle.BattleBuffEvent
local BattleConst = ys.Battle.BattleConst
local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleDataFunction = ys.Battle.BattleDataFunction
local UnitState = ys.Battle.UnitState
local BattleUnit = class("BattleUnit")

ys.Battle.BattleUnit = BattleUnit
BattleUnit.__name = "BattleUnit"

--- @class BattleUnit
--- @param uid number: Unit的唯一ID
--- @param iff number: 友方(1)/敌方(-1)
--- @return nil
--- 构造函数
function BattleUnit.Ctor(self, uid, iff)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._uniqueID = uid
	-- speedExemptKey用于子弹时间时，让开火的单位不受子弹时间影响
	self._speedExemptKey = "unit_" .. uid
	-- ? UnitState: TODO
	self._unitState = ys.Battle.UnitState.New(self)
	-- move: TODO, 大致是与移动相关的组件
	self._move = ys.Battle.MoveComponent.New()
	-- weaponQueue: 该单位的武器队列
	self._weaponQueue = ys.Battle.WeaponQueue.New()

	self:Init()
	self:SetIFF(iff)

	self._distanceBackup = {}
	self._battleProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._frame = 0
end

--- @class BattleUnit
--- @return nil
--- 撤退：触发ON_RETREAT类型的Buff效果
function BattleUnit.Retreat(self)
	self:TriggerBuff(BattleConst.BuffEffectType.ON_RETREAT, {})
end

--- @class BattleUnit
--- @param motionVO BattleFleetMotionVO
--- @return nil
function BattleUnit.SetMotion(self, motionVO)
	self._move:SetMotionVO(motionVO)
end

--- @class BattleUnit
--- @param upBorder number: 可活动区域上边界
--- @param downBorder number: 可活动区域下边界
--- @param leftBorder number: 可活动区域左边界
--- @param rightBorder number: 可活动区域右边界
--- @param leftCorpsBound number: 销毁左边界（超过该边界即销毁）
--- @param rightCorpsBound number: 销毁右边界（超过该边界即销毁）
--- @return nil
function BattleUnit.SetBound(self, upBorder, downBorder, leftBorder, rightBorder, leftCorpsBound, rightCorpsBound)
	self._move:SetCorpsArea(leftCorpsBound, rightCorpsBound)
	self._move:SetBorder(leftBorder, rightBorder, upBorder, downBorder)
end

--- @class BattleUnit
--- @return nil
--- 激活碰撞盒
function BattleUnit.ActiveCldBox(self)
	self._cldComponent:SetActive(true)
end

--- @class BattleUnit
--- @return nil
--- 取消碰撞盒
function BattleUnit.DeactiveCldBox(self)
	self._cldComponent:SetActive(false)
end

--- @class BattleUnit
--- @param bool boolean: 是否免疫碰撞
--- @return nil
--- 设置碰撞盒免疫状态
function BattleUnit.SetCldBoxImmune(self, bool)
	self._cldComponent:SetImmuneCLD(bool)
end

--- @class BattleUnit
--- @return nil
--- 初始化函数，设置各种字段的初始值
function BattleUnit.Init(self)
	self._hostileCldList = {}
	self._currentHPRate = 1
	self._currentDMGRate = 0
	self._tagCount = 0
	self._tagIndex = 0
	self._tagList = {}
	self._aliveState = true
	self._isMainFleetUnit = false
	self._bulletCache = {}
	self._speed = Vector3.zero
	self._dir = BattleConst.UnitDir.RIGHT
	self._extraInfo = {}
	self._GCDTimerList = {}
	self._buffList = {}
	self._buffStockList = {}
	self._labelTagList = {}
	self._exposedToSnoar = false
	self._moveCast = true
	self._remoteBoundBone = {}
end

--- @class BattleUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- BattleUnit的Update函数
--- - 该函数主要更新运动和AI Action
function BattleUnit.Update(self, timeStamp)
	if self:IsAlive() and not self._isSickness then
		self._move:Update()
		self._move:FixSpeed(self._cldComponent)
		self._move:Move(self:GetSpeedRatio())
	end

	self:UpdateAction()
end

--- @class BattleUnit
--- @param timeStamp number: 当前时间戳
--- @return nil
--- 更新武器(和Buff)
function BattleUnit.UpdateWeapon(self, timeStamp)
	if not self:IsAlive() or self._isSickness then
		return
	end

	if not self._antiSubVigilanceState or self._antiSubVigilanceState:IsWeaponUseable() then
		local currentPos = self._move:GetPos()
		local weaponRightBound = self._weaponRightBound
		local weaponLowerBound = self._weaponLowerBound

		-- 这是个什么鬼判断？
		-- 用这个来判断武器用了吗？然后更新武器队列？
		if (weaponRightBound == nil or weaponRightBound > currentPos.x) and (weaponLowerBound == nil or weaponLowerBound < currentPos.z) then
			self._weaponQueue:Update(timeStamp)
		end
	end

	if not self:IsAlive() then
		return
	end
	-- UpdateWeapon方法内部调用UpdateBuff
	self:UpdateBuff(timeStamp)
end

--- @class BattleUnit
--- @return nil
--- 更新支援编队
function BattleUnit.UpdateAirAssist(self)
	if self._airAssistList then
		for _, airAssist in ipairs(self._airAssistList) do
			airAssist:Update()
		end
	end
end

--- @class BattleUnit
--- @return nil
--- 更新阶段切换器
--- - 也就是说，dungeon中如果设定了生成的单位有switch参数，是由这个函数来更新的？
function BattleUnit.UpdatePhaseSwitcher(self)
	if self._phaseSwitcher then
		self._phaseSwitcher:Update()
	end
end

--- @class BattleUnit
--- @param bool boolean: 是否sickness(什么都不能做的状态)
--- @return nil
--- (打断情况下)设置sickness状态
function BattleUnit.SetInterruptSickness(self, bool)
	self._isSickness = bool
end

--- @class BattleUnit
--- @param duration number: (summonSickness)持续时间
--- @return nil
--- 当单位被召唤出来时的sickness状态，对应的处理函数
function BattleUnit.SummonSickness(self, duration)
	if self._isSickness == true then
		return
	end

	local function onSicknessEnd()
		self:RemoveSummonSickness()
	end

	self._isSickness = true
	self._sicknessTimer = pg.TimeMgr.GetInstance():AddBattleTimer("summonSickness", 0, duration, onSicknessEnd, true)
end

--- @class BattleUnit
--- @return nil
--- 移除summonSickness状态和sicknessTimer
function BattleUnit.RemoveSummonSickness(self)
	self._isSickness = false

	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._sicknessTimer)

	self._sicknessTimer = nil
end

--- @class BattleUnit
--- @return number
--- 获取自己被作为目标的优先级
--- 会被BattleTargetChoise.TargetHarmRandomByWeight/TargetWeightiest调用
function BattleUnit.GetTargetedPriority(self)
	local targetedPriority

	if self._aimBias then
		local aimBiasState = self._aimBias:GetCurrentState()

		if aimBiasState == self._aimBias.STATE_SKILL_EXPOSE or aimBiasState == self._aimBias.STATE_TOTAL_EXPOSE then
			targetedPriority = self:GetTemplate().battle_unit_type
		else
			targetedPriority = -200
		end
	else
		targetedPriority = self:GetTemplate().battle_unit_type
	end

	return targetedPriority
end

--- @class BattleUnit
--- @param fxName string
--- @param ifAttach boolean
--- @return nil
--- 发送对应的特效动画播事件
function BattleUnit.PlayFX(self, fxName, ifAttach)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.PLAY_FX, {
		fxName = fxName,
		notAttach = not ifAttach
	}))
end

--- @class BattleUnit
--- @param shader string
--- @param color Color: UnityEngine.Color(见tolua.lua)
--- @param args table<string, number>: 一般只有一个参数invisible，表示可见度
--- @return nil
--- 发送切换shader事件
--- - BattleBuffSwitchShader会用到，例如可以将单位变透明...
function BattleUnit.SwitchShader(self, shader, color, args)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SWITCH_SHADER, {
		shader = shader,
		color = color,
		args = args
	}))
end

--- @class BattleUnit
--- @return nil
--- 发送生成缓存子弹事件?
--- 这是由AttackState.OnTrigger调用的，对应了Spine攻击动画的action触发点(一般是0.2s)，对应的是"前摇"
--- 由BattleCharacter.onSpawnCacheBullet作为回调函数
function BattleUnit.SendAttackTrigger(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SPAWN_CACHE_BULLET, {}))
end

--- @class BattleUnit
--- @return nil
--- 当受到的伤害足以致死时的Handler
function BattleUnit.HandleDamageToDeath(self)
	local extraInfo = {
		isMiss = false,
		isCri = true,
		isHeal = false,
		damageReason = BattleConst.UnitDeathReason.DESTRUCT
	}

	self:UpdateHP(math.floor(-self._currentHP), extraInfo)
end

--- @class BattleUnit
--- @param dHP number: 血量的变化值
--- @param extraInfo table<string, any>
--- @return number: 血量的理论变化值（包含溢出伤害和溢出治疗）
--- 单位的更新生命值主逻辑
function BattleUnit.UpdateHP(self, dHP, extraInfo)
	local isAliveBeforeUpdate = self:IsAlive()
	-- 若更新前就已死亡，返回0
	if not isAliveBeforeUpdate then
		return 0
	end

	local isMiss = extraInfo.isMiss
	local isCri = extraInfo.isCri
	local isHeal = extraInfo.isHeal
	local isShare = extraInfo.isShare
	local attr = extraInfo.attr
	local damageReason = extraInfo.damageReason
	local font = extraInfo.font
	local cldPos = extraInfo.cldPos
	local incorrupt = extraInfo.incorrupt
	local isReflect = extraInfo.isReflect
	local isSpectreBullet = extraInfo.spectreBullet
	local ignoreInvincible = extraInfo.ignoreInvincible
	local preShieldHP
	local damageInfo
	-- 表示这次更新是来自于受到了伤害
	if not isHeal then
		damageInfo = {
			damage = -dHP,
			isShare = isShare,
			miss = isMiss,
			cri = isCri,
			damageSrc = extraInfo.srcID,
			damageAttr = attr,
			damageReason = damageReason,
			isReflect = isReflect
		}

		if not isShare then
			self:TriggerBuff(BattleConst.BuffEffectType.ON_BEFORE_TAKE_DAMAGE, damageInfo)

			if damageInfo.capFlag then
				self:TriggerBuff(BattleConst.BuffEffectType.ON_DAMAGE_FIX, damageInfo)
			end
		end
		-- 被护盾抵消前的伤害值
		preShieldHP = -damageInfo.damage
		-- 触发onTakeDamage的BuffEffect，因此可能会修改damageInfo.damage
		self:TriggerBuff(BattleConst.BuffEffectType.ON_TAKE_DAMAGE, damageInfo)

		if self._currentHP <= damageInfo.damage then
			self:TriggerBuff(BattleConst.BuffEffectType.ON_BEFORE_FATAL_DAMAGE, {})
		end

		dHP = -damageInfo.damage
		-- 计算护盾吸收的伤害，以及触发ON_SHIELD_ABSORB效果
		if preShieldHP ~= dHP then
			({}).absorb = preShieldHP - dHP

			self:TriggerBuff(BattleConst.BuffEffectType.ON_SHIELD_ABSORB, damageInfo)
		end

		if BattleAttr.IsInvincible(self) and not ignoreInvincible then
			return 0
		end
	-- 表示这次更新是来自于治疗
	else
		preShieldHP = dHP

		local damageInfo = {
			damage = dHP,
			isHeal = isHeal,
			incorrupt = incorrupt
		}
		-- 触发治疗效果，可能会修改damageInfo.damage
		self:TriggerBuff(BattleConst.BuffEffectType.ON_TAKE_HEALING, damageInfo)

		isHeal = damageInfo.isHeal
		dHP = damageInfo.damage

		local overHealing = math.max(0, self._currentHP + dHP - self:GetMaxHP())
		-- 触发溢出治疗效果
		if overHealing > 0 then
			self:TriggerBuff(BattleConst.BuffEffectType.ON_OVER_HEALING, {
				overHealing = overHealing
			})
		end
	end
	-- validDHP表示实际生效的血量变化值（不包含溢出伤害和溢出治疗）
	local finalCurrentHP = math.min(self:GetMaxHP(), math.max(0, self._currentHP + dHP))
	local validDHP = finalCurrentHP - self._currentHP

	self:SetCurrentHP(finalCurrentHP)

	local updateHPargs = {
		preShieldHP = preShieldHP,
		dHP = dHP,
		validDHP = validDHP,
		isMiss = isMiss,
		isCri = isCri,
		isHeal = isHeal,
		font = font
	}

	if not isHeal then
		damageInfo.validDHP = validDHP

		self:TriggerBuff(BattleConst.BuffEffectType.ON_DAMAGE_CONCLUDE, damageInfo)
	end

	if cldPos and not cldPos:EqualZero() then
		local position = self:GetPosition()
		local boxSizeX = self:GetBoxSize().x
		local cldBoxLeft = position.x - boxSizeX
		local cldBoxRight = position.x + boxSizeX
		local actualCldPos = cldPos:Clone()
		-- 调整碰撞位置到碰撞盒范围内
		actualCldPos.x = Mathf.Clamp(actualCldPos.x, cldBoxLeft, cldBoxRight)
		updateHPargs.posOffset = position - actualCldPos
	end

	if not isSpectreBullet then
		self:UpdateHPAction(updateHPargs)
	end

	if not self:IsAlive() and isAliveBeforeUpdate then
		self:SetDeathReason(extraInfo.damageReason)
		self:SetDeathSrcID(extraInfo.srcID)
		self:DeadAction()
	end

	if self:IsAlive() then
		self:TriggerBuff(BattleConst.BuffEffectType.ON_HP_RATIO_UPDATE, {
			dHP = dHP,
			unit = self,
			validDHP = validDHP
		})
	end

	return dHP
end

--- @class BattleUnit
--- @param args table<string, any>
--- @return nil
--- 发送更新血量的事件
--- 对应的Event: BattleUnitEvent.UPDATE_HP
--- 对应的Listener: 较多，举其中一个例子: BattleFleetVO.onUnitUpdateHP
function BattleUnit.UpdateHPAction(self, args)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_HP, args))
end

--- @class BattleUnit
--- @return nil
--- 单位死亡时的处理函数
function BattleUnit.DeadAction(self)
	self:TriggerBuff(BattleConst.BuffEffectType.ON_SINK, {})
	self:DeacActionClear()
end

--- @class BattleUnit
--- @return nil
--- 单位死亡时清理状态的处理函数
function BattleUnit.DeacActionClear(self)
	self._aliveState = false

	BattleAttr.Spirit(self)
	BattleAttr.AppendInvincible(self)
	self:DeadActionEvent()
end

--- @class BattleUnit
--- @return nil
--- 发送将要死亡和正在死亡的事件
--- willDie的Listener举例: BattleSingleDungeonCommand.onWillDie
--- dying的Listener举例: BattleSingleDungeonCommand.onUnitDying
function BattleUnit.DeadActionEvent(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.WILL_DIE, {}))
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.DYING, {}))
end
	
--- @class BattleUnit
--- @return nil
--- 发送正在死亡的事件
function BattleUnit.SendDeadEvent(self)
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.DYING, {}))
end

--- @class BattleUnit
--- @param reason number: 参考BattleConst.UnitDeathReason
--- @return nil
--- 设置死亡原因
function BattleUnit.SetDeathReason(self, reason)
	self._deathReason = reason
end

--- @class BattleUnit
--- @return number: 参考BattleConst.UnitDeathReason
--- 获取死亡原因，默认是KILLED
function BattleUnit.GetDeathReason(self)
	return self._deathReason or BattleConst.UnitDeathReason.KILLED
end

--- @class BattleUnit
--- @param srcID number: 伤害来源的Unit ID
--- @return nil
--- 设置死亡来源ID
function BattleUnit.SetDeathSrcID(self, srcID)
	self._deathSrcID = srcID
end

--- @class BattleUnit
--- @return number
--- 获取死亡来源ID
function BattleUnit.GetDeathSrcID(self)
	return self._deathSrcID
end

--- @class BattleUnit
--- @param score number: 得分
--- @return nil
--- 发送更新得分事件
function BattleUnit.DispatchScorePoint(self, score)
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.UPDATE_SCORE, {
		score = score
	}))
end

function BattleUnit.SetTemplate(self, templateID, templateData)
	self._tmpID = templateID
end

function BattleUnit.GetTemplateID(self)
	return self._tmpID
end

function BattleUnit.SetOverrideLevel(self, level)
	self._overrideLevel = level
end

function BattleUnit.SetSkinId(self)
	return
end
-- 被BattleDataProxy.generatePlayerUnit调用
function BattleUnit.SetGearScore(self, gs)
	self._GS = gs
end

function BattleUnit.GetGearScore(self)
	return self._GS or 0
end

function BattleUnit.GetSkinID(self)
	return self._tmpID
end

function BattleUnit.GetDefaultSkinID(self)
	return self._tmpID
end

function BattleUnit.GetSkinAttachmentInfo(self)
	return self._orbitSkinIDList
end

-- 获取武器绑定点信息: 影响子弹的生成点
function BattleUnit.GetWeaponBoundBone(self)
	return self._tmpData.bound_bone
end

function BattleUnit.ActionKeyOffsetUseable(self)
	return true
end

--- Remote Bound Bone相关 ---
--- 用于实现"远程绑定点": 将单位的某个骨骼绑定到另一个单位上，表现为该骨骼跟随目标单位移动
--- (并不常用)
function BattleUnit.RemoveRemoteBoundBone(self, group)
	self._remoteBoundBone[group] = nil
end

-- BattleBuffRemoteBone会调用这个函数来设定远程绑定点
-- 将单位的某个骨骼绑定到另一个单位上，表现为该骨骼跟随目标单位移动
function BattleUnit.SetRemoteBoundBone(self, group, bone, target)
	-- group: Buff ID
	-- remoteBoundBone: table<number, table<string, string>>
	-- 表示远程绑定点的表，第一层的key是Buff ID，第二层的key是骨骼名称(如"cannon")，value是目标单位的位置(如"FlagShip"之类的字符串)
	local boneGroup = self._remoteBoundBone[group] or {}

	boneGroup[bone] = target
	self._remoteBoundBone[group] = boneGroup
end

function BattleUnit.GetRemoteBoundBone(self, spawnBound)
	for _, boneGroup in pairs(self._remoteBoundBone) do
		local fleetPos = boneGroup[spawnBound]

		if fleetPos then
			local target = ys.Battle.BattleTargetChoise.TargetFleetIndex(self, {
				fleetPos = fleetPos
			})[1]

			if target and target:IsAlive() then
				local targetPos = Clone(target:GetPosition())
				-- 调整目标位置的y值，表现为绑定点在单位头顶(做视觉调整)
				targetPos:Set(targetPos.x, 1.5, targetPos.z)

				return targetPos
			end
		end
	end
end

function BattleUnit.GetLabelTag(self)
	return self._labelTagList
end

function BattleUnit.ContainsLabelTag(self, tags)
	if self._labelTagList == nil then
		return false
	end

	for _, tag in ipairs(tags) do
		if table.contains(self._labelTagList, tag) then
			return true
		end
	end

	return false
end

function BattleUnit.AddLabelTag(self, tag)
	-- labelTagList: table<number, string>
	table.insert(self._labelTagList, tag)
	-- labelTag: table<string, number>，是一个属性
	local currentLabelTag = BattleAttr.GetCurrent(self, "labelTag")

	currentLabelTag[tag] = (currentLabelTag[tag] or 0) + 1
end

function BattleUnit.RemoveLabelTag(self, tag)
	for index, labelTag in ipairs(self._labelTagList) do
		if labelTag == tag then
			table.remove(self._labelTagList, index)

			local currentLabelTag = BattleAttr.GetCurrent(self, "labelTag")

			currentLabelTag[tag] = currentLabelTag[tag] - 1

			break
		end
	end
end
-- 用于设定标准标签
-- 包括国籍标签N_和舰种标签T_
function BattleUnit.setStandardLabelTag(self)
	local nationalityTag = "N_" .. self._tmpData.nationality
	local typeTag = "T_" .. self._tmpData.type

	self:AddLabelTag(nationalityTag)
	self:AddLabelTag(typeTag)
end

function BattleUnit.GetRarity(self)
	return
end

function BattleUnit.GetIntimacy(self)
	return 0
end

function BattleUnit.IsBoss(self)
	return false
end

function BattleUnit.GetSpeedRatio(self)
	return BattleVariable.GetSpeedRatio(self:GetSpeedExemptKey(), self._IFF)
end

function BattleUnit.GetSpeedExemptKey(self)
	return self._speedExemptKey
end

function BattleUnit.SetMoveCast(self, moveCast)
	self._moveCast = moveCast
end

function BattleUnit.IsMoveCast(self)
	return self._moveCast
end

-- TODO: 舰船碰撞时的处理逻辑
function BattleUnit.SetCrash(self, crash)
	self._isCrash = crash

	if crash then
		local crashBuff = ys.Battle.BattleBuffUnit.New(BattleConfig.SHIP_CLD_BUFF)

		self:AddBuff(crashBuff)
	else
		self:RemoveBuff(BattleConfig.SHIP_CLD_BUFF)
	end
end

function BattleUnit.IsCrash(self)
	return self._isCrash
end

function BattleUnit.OverrideDeadFX(self, deadFX)
	self._deadFX = deadFX
end

function BattleUnit.GetDeadFX(self)
	return self._deadFX
end

-- TODO
-- 被BattleDataFunction.CreateBattleUnitData调用
function BattleUnit.SetEquipment(self, equipmentList)
	self._equipmentList = equipmentList
	self._autoWeaponList = {}
	self._manualTorpedoList = {}
	self._chargeList = {}
	self._AAList = {}
	self._fleetAAList = {}
	self._fleetRangeAAList = {}
	self._hiveList = {}
	self._totalWeapon = {}

	self:setWeapon(equipmentList)
end

function BattleUnit.GetEquipment(self)
	return self._equipmentList
end

function BattleUnit.SetProficiencyList(self, proficiencyList)
	self._proficiencyList = proficiencyList
end

function BattleUnit.SetSpWeapon(self, spWeapon)
	self._spWeapon = spWeapon
end

function BattleUnit.GetSpWeapon(self)
	return self._spWeapon
end
-- TODO
function BattleUnit.setWeapon(self, equipmentList)
	for equipIndex, equipData in ipairs(equipmentList) do
		local weaponIDs = equipData.equipment.weapon_id

		for _, weaponID in ipairs(weaponIDs) do
			if weaponID ~= -1 then
				local weapon = ys.Battle.BattleDataFunction.CreateWeaponUnit(weaponID, self, nil, equipIndex)

				self._totalWeapon[#self._totalWeapon + 1] = weapon

				local weaponType = weapon:GetTemplateData().type

				if weaponType == BattleConst.EquipmentType.MANUAL_TORPEDO then
					self._manualTorpedoList[#self._manualTorpedoList + 1] = weapon

					self._weaponQueue:AppendWeapon(weapon)
				elseif weaponType == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
					-- block empty
				else
					assert(#weaponIDs < 2, "自动武器一组不允许配置多个")
					self:AddAutoWeapon(weapon)
				end

				if weaponType == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or weaponType == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
					self._hiveList[#self._hiveList + 1] = weapon
				end

				if weaponType == BattleConst.EquipmentType.ANTI_AIR then
					self._AAList[#self._AAList + 1] = weapon
				end
			end
		end
	end
end

function BattleUnit.CheckWeaponInitial(self)
	self._weaponQueue:CheckWeaponInitalCD()

	if self._airAssistQueue then
		self._airAssistQueue:CheckWeaponInitalCD()
	end

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_COOL_DOWN, {}))
end

function BattleUnit.FlushReloadingWeapon(self)
	self._weaponQueue:FlushWeaponReloadRequire()

	if self._airAssistQueue then
		self._airAssistQueue:FlushWeaponReloadRequire()
	end
end

-- BattleBuffNewWeapon
function BattleUnit.AddNewAutoWeapon(self, weaponID)
	local weapon = BattleDataFunction.CreateWeaponUnit(weaponID, self)

	self:AddAutoWeapon(weapon)
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleBuffEvent.BUFF_EFFECT_NEW_WEAPON, {
		weapon = weapon
	}))

	return weapon
end

function BattleUnit.AddAutoWeapon(self, weapon)
	self._autoWeaponList[#self._autoWeaponList + 1] = weapon

	self._weaponQueue:AppendWeapon(weapon)
end

function BattleUnit.RemoveAutoWeapon(self, autoWeapon)
	self._weaponQueue:RemoveWeapon(autoWeapon)

	local index = 1
	local autoWeaponNum = #self._autoWeaponList

	while index <= autoWeaponNum do
		if self._autoWeaponList[index] == autoWeapon then
			self:DispatchEvent(ys.Event.New(BattleUnitEvent.REMOVE_WEAPON, {
				weapon = autoWeapon
			}))
			table.remove(self._autoWeaponList, index)

			break
		end

		index = index + 1
	end
end

function BattleUnit.RemoveAutoWeaponByWeaponID(self, weaponID)
	for _, weapon in ipairs(self._autoWeaponList) do
		if weapon:GetWeaponId() == weaponID then
			weapon:Clear()
			self:RemoveAutoWeapon(weapon)

			break
		end
	end
end

-- BattleSkillRemoveAllWeapon
function BattleUnit.RemoveAllAutoWeapon(self)
	local autoWeaponNum = #self._autoWeaponList

	while autoWeaponNum > 0 do
		local autoWeapon = self._autoWeaponList[autoWeaponNum]

		autoWeapon:Clear()
		self:RemoveAutoWeapon(autoWeapon)

		autoWeaponNum = autoWeaponNum - 1
	end
end

function BattleUnit.AddFleetAntiAirWeapon(self, weapon)
	return
end

function BattleUnit.RemoveFleetAntiAirWeapon(self, weapon)
	return
end

function BattleUnit.AttachFleetRangeAAWeapon(self, weapon)
	self._fleetRangeAA = weapon

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.CREATE_TEMPORARY_WEAPON, {
		weapon = weapon
	}))
end

function BattleUnit.DetachFleetRangeAAWeapon(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.REMOVE_WEAPON, {
		weapon = self._fleetRangeAA
	}))

	self._fleetRangeAA = nil
end

function BattleUnit.GetFleetRangeAAWeapon(self)
	return self._fleetRangeAA
end

function BattleUnit.ShiftWeapon(self, removeWeaponIDs, addWeaponIDs)
	for _, wID in ipairs(removeWeaponIDs) do
		self:RemoveAutoWeaponByWeaponID(wID)
	end

	for _, wID in ipairs(addWeaponIDs) do
		self:AddNewAutoWeapon(wID):InitialCD()
	end
end

-- 被BattleBuffMountExpand调用
function BattleUnit.ExpandWeaponMount(self, mountType)
	if mountType == "airAssist" then
		BattleDataFunction.ExpandAllinStrike(self)
	end
end

function BattleUnit.ReduceWeaponMount(self, mountType)
	return
end

function BattleUnit.CeaseAllWeapon(self, ceaseFire)
	self._ceaseFire = ceaseFire
end

function BattleUnit.IsCease(self)
	return self._ceaseFire
end

function BattleUnit.GetAllWeapon(self)
	return self._totalWeapon
end

function BattleUnit.GetTotalWeapon(self)
	return self._weaponQueue:GetTotalWeaponUnit()
end

function BattleUnit.GetAutoWeapons(self)
	return self._autoWeaponList
end

function BattleUnit.GetChargeList(self)
	return self._chargeList
end

function BattleUnit.GetChargeQueue(self)
	return self._weaponQueue:GetChargeWeaponQueue()
end

function BattleUnit.GetAntiAirWeapon(self)
	return self._AAList
end

function BattleUnit.GetFleetAntiAirList(self)
	return self._fleetAAList
end

function BattleUnit.GetFleetRangeAntiAirList(self)
	return self._fleetRangeAAList
end

function BattleUnit.GetTorpedoList(self)
	return self._manualTorpedoList
end

function BattleUnit.GetTorpedoQueue(self)
	return self._weaponQueue:GetManualTorpedoQueue()
end

function BattleUnit.GetWeaponByIndex(self, equipmentIndex)
	for _, weapon in ipairs(self._totalWeapon) do
		if weapon:GetEquipmentIndex() == equipmentIndex then
			return weapon
		end
	end
end

function BattleUnit.GetHiveList(self)
	return self._hiveList
end
-- TODO
function BattleUnit.SetAirAssistList(self, airAssistList)
	self._airAssistList = airAssistList
	self._airAssistQueue = ys.Battle.ManualWeaponQueue.New(self:GetManualWeaponParallel()[BattleConst.ManualWeaponIndex.AIR_ASSIST])

	for _, airAssist in ipairs(self._airAssistList) do
		self._airAssistQueue:AppendWeapon(airAssist)
	end
end

function BattleUnit.GetAirAssistList(self)
	return self._airAssistList
end

function BattleUnit.GetAirAssistQueue(self)
	return self._airAssistQueue
end

function BattleUnit.GetManualWeaponParallel(self)
	return {
		1,
		1,
		1
	}
end

function BattleUnit.configWeaponQueueParallel(self)
	local manualWeaponParallel = self:GetManualWeaponParallel()

	self._weaponQueue:ConfigParallel(manualWeaponParallel[BattleConst.ManualWeaponIndex.CALIBRATION], manualWeaponParallel[BattleConst.ManualWeaponIndex.TORPEDO])
end

function BattleUnit.ClearWeapon(self)
	self._weaponQueue:ClearAllWeapon()

	local airAssistList = self._airAssistList

	if airAssistList then
		for _, airAssist in ipairs(airAssistList) do
			airAssist:Clear()
		end
	end
end

function BattleUnit.GetSpeed(self)
	return self._move:GetSpeed()
end

function BattleUnit.GetPosition(self)
	return self._move:GetPos()
end

function BattleUnit.GetBornPosition(self)
	return self._bornPos
end

function BattleUnit.GetCLDZCenterPosition(self)
	local currentFrame = self._battleProxy.FrameIndex

	if self._zCenterFrame ~= currentFrame then
		self._zCenterFrame = currentFrame

		local cldBox = self:GetCldBox()

		self._cldZCenterCache = (cldBox.min + cldBox.max) * 0.5
	end

	return self._cldZCenterCache
end


function BattleUnit.GetBeenAimedPosition(self)
	local zCenter = self:GetCLDZCenterPosition()

	if not zCenter then
		return zCenter
	end

	local aimOffset = self:GetTemplate() and self:GetTemplate().aim_offset

	if not aimOffset then
		return zCenter
	end

	local aimPosition = Vector3(zCenter.x + aimOffset[1], zCenter.y + aimOffset[2], zCenter.z + aimOffset[3])

	self:biasAimPosition(aimPosition)

	return aimPosition
end

function BattleUnit.biasAimPosition(self, aimPosition)
	local aimBias = BattleAttr.GetCurrent(self, "aimBias")

	if aimBias > 0 then
		local aimBias2 = aimBias * 2
		local aimBiasX = math.random() * aimBias2 - aimBias
		local aimBiasZ = math.random() * aimBias2 - aimBias

		aimPosition:Set(aimPosition.x + aimBiasX, aimPosition.y, aimPosition.z + aimBiasZ)
	end

	return aimPosition
end

function BattleUnit.CancelFollowTeam(self)
	self._move:CancelFormationCtrl()
end

function BattleUnit.UpdateFormationOffset(self, offset)
	self._move:SetFormationCtrlInfo(Vector3(offset.x, offset.y, offset.z))
end

function BattleUnit.GetDistance(self, targetUnit)
	local currentFrame = self._battleProxy.FrameIndex

	if self._frame ~= currentFrame then
		self._distanceBackup = {}
		self._frame = currentFrame
	end

	local cachedDistance = self._distanceBackup[targetUnit]

	if cachedDistance == nil then
		cachedDistance = Vector3.Distance(self:GetPosition(), targetUnit:GetPosition())
		self._distanceBackup[targetUnit] = cachedDistance

		targetUnit:backupDistance(self, cachedDistance)
	end

	return cachedDistance
end

function BattleUnit.backupDistance(self, otherUnit, dist)
	local currentFrame = self._battleProxy.FrameIndex

	if self._frame ~= currentFrame then
		self._distanceBackup = {}
		self._frame = currentFrame
	end

	self._distanceBackup[otherUnit] = dist
end

function BattleUnit.GetDirection(self)
	return self._dir
end

function BattleUnit.SetBornPosition(self, bornPos)
	self._bornPos = bornPos
end

function BattleUnit.SetPosition(self, pos)
	self._move:SetPos(pos)
end

function BattleUnit.IsMoving(self)
	local speed = self._move:GetSpeed()

	return speed.x ~= 0 or speed.z ~= 0
end

function BattleUnit.SetUncontrollableSpeedWithYAngle(self, yAngle, speed, duration)
	local radian = math.deg2Rad * yAngle
	local dirVec = Vector3(math.cos(radian), 0, math.sin(radian))

	self:SetUncontrollableSpeed(dirVec, speed, duration)
end

function BattleUnit.SetUncontrollableSpeedWithDir(self, dir, speed, duration)
	local dirLen = math.sqrt(dir.x * dir.x + dir.z * dir.z)

	self:SetUncontrollableSpeed(dir / dirLen, speed, duration)
end

function BattleUnit.SetUncontrollableSpeed(self, dir, speed, duration)
	if not speed or not duration then
		return
	end

	self._move:SetForceMove(dir, speed, duration, speed / duration)
end

function BattleUnit.ClearUncontrollableSpeed(self)
	self._move:ClearForceMove()
end

function BattleUnit.SetAdditiveSpeed(self, speedVec)
	self._move:UpdateAdditiveSpeed(speedVec)
end

function BattleUnit.RemoveAdditiveSpeed(self)
	self._move:RemoveAdditiveSpeed()
end

function BattleUnit.Boost(self, dir, speed, acc, duration, friction)
	self._move:SetForceMove(dir, speed, acc, duration, friction)
end

function BattleUnit.ActiveUnstoppable(self, duration)
	self._move:ActiveUnstoppable(duration)
end

function BattleUnit.SetImmuneCommonBulletCLD(self)
	self._immuneCommonBulletCLD = true
end

function BattleUnit.IsImmuneCommonBulletCLD(self)
	return self._immuneCommonBulletCLD
end

function BattleUnit.SetWeaponPreCastBound(self, bound)
	self._preCastBound = bound

	self:UpdatePrecastMoveLimit()
end

function BattleUnit.EnterGCD(self, duration, gcdKey)
	if self._GCDTimerList[gcdKey] ~= nil then
		return
	end

	local function onGCDEnd()
		self:RemoveGCDTimer(gcdKey)
	end

	self._weaponQueue:QueueEnterGCD(gcdKey, duration)

	self._GCDTimerList[gcdKey] = pg.TimeMgr.GetInstance():AddBattleTimer("weaponGCD", 0, duration, onGCDEnd, true)

	self:UpdatePrecastMoveLimit()
end

function BattleUnit.RemoveGCDTimer(self, gcdKey)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._GCDTimerList[gcdKey])

	self._GCDTimerList[gcdKey] = nil

	self:UpdatePrecastMoveLimit()
end

function BattleUnit.UpdatePrecastMoveLimit(self)
	self:UpdateMoveLimit()
end

-- 切换一次是否能移动的状态
-- BattleBuffStun调用
function BattleUnit.UpdateMoveLimit(self)
	local moveable = self:IsMoveAble()

	self._move:SetStaticState(not moveable)
end

-- note: 单位添加Buff主逻辑
function BattleUnit.AddBuff(self, buff, ifStock)
	local buffID = buff:GetID()
	local args = {
		unit_id = self._uniqueID,
		buff_id = buffID
	}
	-- self._buffList: table<number, BattleBuffUnit>
	local oldBuff = self:GetBuff(buffID)

	if oldBuff then
		-- 目前只看到BattleBuffAura和EffectBullet的ifStock参数会传true，表现为同一Buff ID可以存在多个实例互不影响
		if ifStock then
			-- self._buffStockList: table<number, table<number, BattleBuffUnit>>
			-- 同一Buff ID对应多个Buff实例的列表
			local buffStockItem = self._buffStockList[buffID] or {}

			table.insert(buffStockItem, buff)

			self._buffStockList[buffID] = buffStockItem
		else
			local oldBuffLevel = oldBuff:GetLv()
			local buffLevel = buff:GetLv()
			local oldBuffGroupLevel = oldBuff:GetGroupLevel()
			local buffGroupLevel = buff:GetGroupLevel()
			-- 取较高的Buff等级
			args.buff_level = math.max(oldBuffLevel, buffLevel)
			-- 若新Buff Group等级不高于旧Buff Group等级，或者旧Buff能强制叠层，则进行叠层
			if oldBuff:IsForceStack() or buffGroupLevel <= oldBuffGroupLevel then
				oldBuff:Stack(self)

				args.stack_count = oldBuff:GetStack()

				self:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_STACK, args))
			else
				self:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_CAST, args))
				self:RemoveBuff(buffID)

				self._buffList[buffID] = buff

				buff:Attach(self)
				self:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_ATTACH, args))
			end
		end
	else
		self:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_CAST, args))

		self._buffList[buffID] = buff

		buff:Attach(self)

		args.buff_level = buff:GetLv()

		self:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_ATTACH, args))
	end

	self:TriggerBuff(BattleConst.BuffEffectType.ON_BUFF_ADDED, {
		buffID = buffID
	})
end

function BattleUnit.SetBuffStack(self, buffId, buffLevel, stack)
	if stack <= 0 then
		self:RemoveBuff(buffId)
	else
		local buff = self:GetBuff(buffId)

		if buff then
			buff:UpdateStack(self, stack)

			return buff
		else
			local newBuff = ys.Battle.BattleBuffUnit.New(buffId, buffLevel)

			self:AddBuff(newBuff)
			newBuff:UpdateStack(self, stack)

			return newBuff
		end
	end
end

function BattleUnit.UpdateBuff(self, timeStamp)
	local buffList = self._buffList

	for buffID, buff in pairs(buffList) do
		buff:Update(self, timeStamp)

		if not self:IsAlive() then
			break
		end
	end
end

-- 消耗指定Buff的层数，层数不足则移除Buff
-- 被BattleSkillConsumeBuff.DoDataEffect调用
function BattleUnit.ConsumeBuffStack(self, buffID, count)
	local buff = self:GetBuff(buffID)

	if buff then
		if not count then
			self:RemoveBuff(buffID)
		else
			local stack = buff:GetStack()
			local stackAfterConsume = math.max(0, stack - count)

			if stackAfterConsume == 0 then
				self:RemoveBuff(buffID)
			else
				buff:UpdateStack(self, stackAfterConsume)
			end
		end
	end
end

-- 单位移除Buff逻辑
function BattleUnit.RemoveBuff(self, buffID, ifStock)
	if ifStock and self._buffStockList[buffID] then
		local stockedBuff = table.remove(self._buffStockList[buffID])

		if stockedBuff then
			stockedBuff:Clear()

			return
		end
	end

	local buff = self:GetBuff(buffID)

	if buff then
		buff:Remove()
	end

	self:TriggerBuff(BattleConst.BuffEffectType.ON_BUFF_REMOVED, {
		buffID = buffID
	})
end

function BattleUnit.ClearBuff(self)
	local buffList = self._buffList

	for buffID, buff in pairs(buffList) do
		buff:Clear()
	end

	local buffStockList = self._buffStockList

	for stockID, stockBuffs in pairs(buffStockList) do
		for _, stockBuff in pairs(stockBuffs) do
			stockBuff:Clear()
		end
	end
end

--- @class BattleUnit
--- @param effectType string
--- @param arg_list table<string, any>
--- @return nil
--- BattleUnit的Buff触发接口
--- - 调用BattleBuffUnit的静态方法Trigger
function BattleUnit.TriggerBuff(self, effectType, arg_list)
	ys.Battle.BattleBuffUnit.Trigger(self, effectType, arg_list)
end

function BattleUnit.GetBuffList(self)
	return self._buffList
end

function BattleUnit.GetBuff(self, buffID)
	self._buffList = self._buffList

	return self._buffList[buffID]
end

function BattleUnit.DispatchSkillFloat(self, skillName, commander, coverHrzIcon)
	local eventData = {
		coverHrzIcon = coverHrzIcon,
		commander = commander,
		skillName = skillName
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SKILL_FLOAT, eventData))
end

function BattleUnit.DispatchCutIn(self, skill, commander)
	local eventData = {
		caster = self,
		skill = skill
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.CUT_INT, eventData))
end

function BattleUnit.DispatchCastClock(self, isActive, buffEffect, iconType, interrupt, reverse)
	local eventData = {
		isActive = isActive,
		buffEffect = buffEffect,
		iconType = iconType,
		interrupt = interrupt,
		reverse = reverse
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.ADD_BUFF_CLOCK, eventData))
end

function BattleUnit.SetAI(self, aiID)
	local aiTmpData = BattleDataFunction.GetAITmpDataFromID(aiID)

	self._autoPilotAI = ys.Battle.AutoPilot.New(self, aiTmpData)
	self._move:CancelFormationCtrl()
end

function BattleUnit.AddPhaseSwitcher(self, phaseSwitcher)
	self._phaseSwitcher = phaseSwitcher
end

function BattleUnit.GetPhaseSwitcher(self)
	return self._phaseSwitcher
end

function BattleUnit.StateChange(self, stateName, args)
	self._unitState:ChangeState(stateName, args)
end

function BattleUnit.UpdateAction(self)
	local speedX = self:GetSpeed().x * self._IFF

	if self._oxyState and self._oxyState:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
		if speedX >= 0 then
			self._unitState:ChangeState(UnitState.STATE_DIVE)
		else
			self._unitState:ChangeState(UnitState.STATE_DIVELEFT)
		end
	elseif speedX >= 0 then
		self._unitState:ChangeState(UnitState.STATE_MOVE)
	else
		self._unitState:ChangeState(UnitState.STATE_MOVELEFT)
	end
end

function BattleUnit.SetActionKeyOffset(self, offset)
	self._actionKeyOffset = offset

	self._unitState:FreshActionKeyOffset()
end

function BattleUnit.GetActionKeyOffset(self)
	return self._actionKeyOffset
end

function BattleUnit.GetCurrentState(self)
	return self._unitState:GetCurrentStateName()
end

function BattleUnit.NeedWeaponCache(self)
	return self._unitState:NeedWeaponCache()
end

function BattleUnit.CharacterActionTriggerCallback(self)
	self._unitState:OnActionTrigger()
end

function BattleUnit.CharacterActionEndCallback(self)
	self._unitState:OnActionEnd()
end

function BattleUnit.CharacterActionStartCallback(self)
	return
end

function BattleUnit.DispatchChat(self, content, duration, key)
	if not content or #content == 0 then
		return
	end

	local eventData = {
		content = HXSet.hxLan(content),
		duration = duration,
		key = key
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.POP_UP, eventData))
end

function BattleUnit.DispatchVoice(self, voiceKey)
	local intimacy = self:GetIntimacy()
	local _, word, cv = ShipWordHelper.GetWordAndCV(self:GetSkinID(), voiceKey, 1, true, intimacy)

	if word then
		local eventData = {
			content = word,
			key = voiceKey
		}

		self:DispatchEvent(ys.Event.New(BattleUnitEvent.VOICE, eventData))
	end
end

function BattleUnit.GetHostileCldList(self)
	return self._hostileCldList
end

function BattleUnit.AppendHostileCld(self, key, timer)
	self._hostileCldList[key] = timer
end

function BattleUnit.RemoveHostileCld(self, key)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._hostileCldList[key])

	self._hostileCldList[key] = nil
end

function BattleUnit.GetExtraInfo(self)
	return self._extraInfo
end

function BattleUnit.GetTemplate(self)
	return nil
end

function BattleUnit.GetGroupID(self)
	return nil
end

function BattleUnit.GetTemplateValue(self, key)
	return self:GetTemplate()[key]
end

function BattleUnit.GetUniqueID(self)
	return self._uniqueID
end

function BattleUnit.SetIFF(self, iff)
	self._IFF = iff

	if iff == BattleConfig.FRIENDLY_CODE then
		self._dir = BattleConst.UnitDir.RIGHT
	elseif iff == BattleConfig.FOE_CODE then
		self._dir = BattleConst.UnitDir.LEFT
	end
end

function BattleUnit.GetIFF(self)
	return self._IFF
end

function BattleUnit.GetUnitType(self)
	return self._type
end

function BattleUnit.GetHPRate(self)
	return self._currentHPRate
end

function BattleUnit.GetHP(self)
	return self._currentHP, self:GetMaxHP()
end

function BattleUnit.GetCurrentHP(self)
	return self._currentHP
end

function BattleUnit.SetCurrentHP(self, hp)
	self._currentHP = hp
	self._currentHPRate = self._currentHP / self:GetMaxHP()
	self._currentDMGRate = 1 - self._currentHPRate

	BattleAttr.SetCurrent(self, "HPRate", self._currentHPRate)
	BattleAttr.SetCurrent(self, "DMGRate", self._currentDMGRate)
end

function BattleUnit.GetAttr(self)
	return BattleAttr.GetAttr(self)
end

function BattleUnit.GetAttrByName(self, attrName)
	return BattleAttr.GetCurrent(self, attrName)
end

function BattleUnit.GetMaxHP(self)
	return self:GetAttrByName("maxHP")
end

function BattleUnit.GetReload(self)
	return self:GetAttrByName("loadSpeed")
end

function BattleUnit.GetTorpedoPower(self)
	return self:GetAttrByName("torpedoPower")
end

function BattleUnit.CanDoAntiSub(self)
	return self:GetAttrByName("antiSubPower") > 0
end

function BattleUnit.IsShowHPBar(self)
	return false
end

-- 检测单位是否存活：检查一次当前HP是否大于0以及_aliveState标记
function BattleUnit.IsAlive(self)
	local currentHP = self:GetCurrentHP()

	return self._aliveState and currentHP > 0
end

function BattleUnit.SetMainFleetUnit(self)
	self._isMainFleetUnit = true

	self:SetMainUnitStatic(true)
end

function BattleUnit.IsMainFleetUnit(self)
	return self._isMainFleetUnit
end

function BattleUnit.SetMainUnitStatic(self, isStatic)
	self._isMainStatic = isStatic

	self._move:SetStaticState(isStatic)
end

function BattleUnit.SetMainUnitIndex(self, index)
	self._mainUnitIndex = index
end

function BattleUnit.GetMainUnitIndex(self)
	return self._mainUnitIndex or 1
end

-- 判定单位能否移动: 通过看isStun/MoveCast(仅敌方)
-- BattleUnit.UpdateMoveLimit调用
function BattleUnit.IsMoveAble(self)
	local inCD = table.getCount(self._GCDTimerList) > 0 or self._preCastBound
	local isStun = BattleAttr.IsStun(self)
	local isMoveCast = self:IsMoveCast()

	return not self._isMainStatic and (isMoveCast or not inCD) and not isStun
end

function BattleUnit.Reinforce(self)
	self._isReinforcement = true
end

function BattleUnit.IsReinforcement(self)
	return self._isReinforcement
end

function BattleUnit.SetReinforceCastTime(self, castTime)
	self._reinforceCastTime = castTime
end

function BattleUnit.GetReinforceCastTime(self)
	return self._reinforceCastTime
end

function BattleUnit.GetFleetVO(self)
	return
end

function BattleUnit.SetFormationIndex(self, formationIndex)
	return
end

function BattleUnit.SetMaster(self)
	return
end

function BattleUnit.GetMaster(self)
	return nil
end

function BattleUnit.IsSpectre(self)
	return
end

function BattleUnit.Clear(self)
	self._aliveState = false

	for key, _ in pairs(self._hostileCldList) do
		self:RemoveHostileCld(key)
	end

	self:ClearWeapon()
	self:ClearBuff()

	self._distanceBackup = {}
end

function BattleUnit.Dispose(self)
	self._exposedList = nil
	self._phaseSwitcher = nil

	self._weaponQueue:Dispose()

	if self._airAssistQueue then
		self._airAssistQueue:Clear()

		self._airAssistQueue = nil
	end

	self._equipmentList = nil
	self._totalWeapon = nil

	local airAssistList = self._airAssistList

	if airAssistList then
		for _, airAssist in ipairs(airAssistList) do
			airAssist:Dispose()
		end
	end

	for _, faaWeapon in ipairs(self._fleetAAList) do
		faaWeapon:Dispose()
	end

	for _, fraaWeapon in ipairs(self._fleetRangeAAList) do
		fraaWeapon:Dispose()
	end

	local buffList = self._buffList

	for _, buff in pairs(buffList) do
		buff:Dispose()
	end

	local buffStockList = self._buffStockList

	for _, stockBuffs in pairs(buffStockList) do
		for _, stockBuff in pairs(stockBuffs) do
			stockBuff:Clear()
		end
	end

	self._fleetRangeAA = nil
	self._aimBias = nil
	self._buffList = nil
	self._buffStockList = nil
	self._cldZCenterCache = nil
	self._remoteBoundBone = nil

	self:RemoveSummonSickness()
	ys.EventDispatcher.DetachEventDispatcher(self)
end

function BattleUnit.InitCldComponent(self)
	local cldBox = self:GetTemplate().cld_box
	local cldOffset = self:GetTemplate().cld_offset
	local offsetX = cldOffset[1]

	if self:GetDirection() == BattleConst.UnitDir.LEFT then
		offsetX = offsetX * -1
	end

	self._cldComponent = ys.Battle.BattleCubeCldComponent.New(cldBox[1], cldBox[2], cldBox[3], offsetX, cldOffset[3] + cldBox[3] / 2)
end

function BattleUnit.GetBoxSize(self)
	return self._cldComponent:GetCldBoxSize()
end

function BattleUnit.GetCldBox(self)
	return self._cldComponent:GetCldBox(self:GetPosition())
end

function BattleUnit.GetCldData(self)
	return self._cldComponent:GetCldData()
end

-- BattleBuffShiftCLDBox调用
function BattleUnit.ShiftCldComponent(self, cldBox, cldOffset)
	self:updateCldComponet(cldBox, cldOffset)
end

function BattleUnit.ResetCldComponent(self)
	local cldBox = self:GetTemplate().cld_box
	local cldOffset = self:GetTemplate().cld_offset

	self:updateCldComponet(cldBox, cldOffset)
end

function BattleUnit.updateCldComponet(self, cldBox, cldOffset)
	local offsetX = cldOffset[1]

	if self:GetDirection() == BattleConst.UnitDir.LEFT then
		offsetX = offsetX * -1
	end

	self._cldComponent:ResetOffset(offsetX, cldOffset[3] + cldBox[3] / 2)
	self._cldComponent:ResetSize(cldBox[1], cldBox[2], cldBox[3])
end

-- TODO
function BattleUnit.InitOxygen(self)
	self._maxOxy = self:GetAttrByName("oxyMax")
	self._currentOxy = self:GetAttrByName("oxyMax")
	self._oxyRecovery = self:GetAttrByName("oxyRecovery")
	self._oxyRecoveryBench = self:GetAttrByName("oxyRecoveryBench")
	self._oxyRecoverySurface = self:GetAttrByName("oxyRecoverySurface")
	self._oxyConsume = self:GetAttrByName("oxyCost")
	self._oxyState = ys.Battle.OxyState.New(self)

	self._oxyState:OnDiveState()
	self:ConfigBubbleFX()

	return self._oxyState
end
-- TODO
function BattleUnit.UpdateOxygen(self, timeStamp)
	if self._oxyState then
		self._lastOxyUpdateStamp = self._lastOxyUpdateStamp or timeStamp

		self._oxyState:UpdateOxygen()

		if self._oxyState:GetNextBubbleStamp() and timeStamp > self._oxyState:GetNextBubbleStamp() then
			self._oxyState:FlashBubbleStamp(timeStamp)
			self:PlayFX(self._bubbleFX, true)
		end

		self._lastOxyUpdateStamp = timeStamp

		self:updateSonarExposeTag()
	end
end

function BattleUnit.OxyRecover(self, state)
	local recoveryRate

	if state == ys.Battle.OxyState.STATE_FREE_BENCH then
		recoveryRate = self._oxyRecoveryBench
	elseif state == ys.Battle.OxyState.STATE_FREE_FLOAT then
		recoveryRate = self._oxyRecovery
	else
		recoveryRate = self._oxyRecoverySurface
	end

	local deltaTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._lastOxyUpdateStamp

	self._currentOxy = math.min(self._maxOxy, self._currentOxy + recoveryRate * deltaTime)
end

function BattleUnit.OxyConsume(self)
	local deltaTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._lastOxyUpdateStamp

	self._currentOxy = math.max(0, self._currentOxy - self._oxyConsume * deltaTime)
end
-- TODO
function BattleUnit.ChangeOxygenState(self, state)
	self._oxyState:ChangeState(state)
end

function BattleUnit.ChangeWeaponDiveState(self)
	for _, weapon in ipairs(self._autoWeaponList) do
		weapon:ChangeDiveState()
	end
end

function BattleUnit.GetOxygenProgress(self)
	return self._currentOxy / self._maxOxy
end

function BattleUnit.GetCuurentOxygen(self)
	return self._currentOxy or 0
end

function BattleUnit.ConfigBubbleFX(self)
	return
end

function BattleUnit.SetDiveInvisible(self, invisible)
	self._diveInvisible = invisible

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_VISIBLE))
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_DETECTED))
	self:dispatchDetectedTrigger()
end

function BattleUnit.GetDiveInvisible(self)
	return self._diveInvisible
end

function BattleUnit.GetOxygenVisible(self)
	return self._oxyState and self._oxyState:GetBarVisible()
end

function BattleUnit.SetForceVisible(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_FORCE_DETECTED))
end

-- BattleIndieSonar.Detect调用
function BattleUnit.Detected(self, duration)
	local detected

	if self._exposedToSnoar == false and not self._exposedOverTimeStamp then
		detected = true
	end

	if duration then
		self:updateExposeTimeStamp(duration)
	else
		self._exposedToSnoar = true
	end

	if detected then
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_DETECTED, {}))
		self:dispatchDetectedTrigger()
	end
end

function BattleUnit.Undetected(self)
	self._exposedToSnoar = false

	self:updateExposeTimeStamp(BattleConfig.SUB_EXPOSE_LASTING_DURATION)
end

function BattleUnit.RemoveSonarExpose(self)
	self._exposedToSnoar = false
	self._exposedOverTimeStamp = nil
end

function BattleUnit.updateSonarExposeTag(self)
	if self._exposedOverTimeStamp and not self._exposedToSnoar and pg.TimeMgr.GetInstance():GetCombatTime() > self._exposedOverTimeStamp then
		self._exposedOverTimeStamp = nil

		self:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_DETECTED, {
			detected = false
		}))
		self:dispatchDetectedTrigger()
	end
end

function BattleUnit.updateExposeTimeStamp(self, duration)
	local newStamp = pg.TimeMgr.GetInstance():GetCombatTime() + duration

	self._exposedOverTimeStamp = self._exposedOverTimeStamp or 0
	self._exposedOverTimeStamp = newStamp < self._exposedOverTimeStamp and self._exposedOverTimeStamp or newStamp
end

function BattleUnit.IsRunMode(self)
	return self._oxyState and self._oxyState:GetRundMode()
end

function BattleUnit.GetDiveDetected(self)
	return self:GetDiveInvisible() and (self._exposedOverTimeStamp or self._exposedToSnoar)
end

function BattleUnit.GetForceExpose(self)
	return self._oxyState and self._oxyState:GetForceExpose()
end

function BattleUnit.dispatchDetectedTrigger(self)
	if self:GetDiveDetected() then
		self:TriggerBuff(BattleConst.BuffEffectType.ON_SUB_DETECTED, {})
	else
		self:TriggerBuff(BattleConst.BuffEffectType.ON_SUB_UNDETECTED, {})
	end
end

function BattleUnit.GetRaidDuration(self)
	return self:GetAttrByName("oxyMax") / self:GetAttrByName("oxyCost")
end

function BattleUnit.EnterRaidRange(self)
	if self:GetPosition().x > self._subRaidLine then
		return true
	else
		return false
	end
end

function BattleUnit.EnterRetreatRange(self)
	if self:GetPosition().x < self._subRetreatLine then
		return true
	else
		return false
	end
end

function BattleUnit.GetOxyState(self)
	return self._oxyState
end

function BattleUnit.GetCurrentOxyState(self)
	if not self._oxyState then
		return BattleConst.OXY_STATE.FLOAT
	else
		return self._oxyState:GetCurrentDiveState()
	end
end

function BattleUnit.InitAntiSubState(self, sonarRange, sonarFrequency)
	self._antiSubVigilanceState = ys.Battle.AntiSubState.New(self)

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_ANIT_SUB_VIGILANCE, {
		sonarRange = sonarRange
	}))

	return self._antiSubVigilanceState
end

function BattleUnit.GetAntiSubState(self)
	return self._antiSubVigilanceState
end

-- 根据是否是幽灵单位来设置隐身状态：如果是幽灵单位且不是可见幽灵单位，则设置为隐身(不可见),否则取消隐身
-- BattleBuffSetBattleUnitType.flash调用
function BattleUnit.UpdateBlindInvisibleBySpectre(self)
	local _, battleUnitType = self:IsSpectre()

	-- VISIBLE_SPECTRE_UNIT_TYPE是特殊的幽灵单位类型，它是可见的.(其他幽灵不可见，且没有碰撞体)
	-- VISIBLE_SPECTRE_UNIT_TYPE = -100
	if battleUnitType <= BattleConfig.SPECTRE_UNIT_TYPE and battleUnitType ~= BattleConfig.VISIBLE_SPECTRE_UNIT_TYPE then
		-- SetBlindInvisible(true) -> GetExposed返回False -> Render.enabled = false -> 不可见
		self:SetBlindInvisible(true)
	else
		-- 其余正常单位+(-100)的幽灵单位可见
		self:SetBlindInvisible(false)
	end
end

function BattleUnit.SetBlindInvisible(self, blindInvisible)
	self._exposedList = blindInvisible and {} or nil
	self._blindInvisible = blindInvisible
	-- BattleCharacter.onUpdateBlindInvisible
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.BLIND_VISIBLE))
end

function BattleUnit.GetBlindInvisible(self)
	return self._blindInvisible
end

function BattleUnit.GetExposed(self)
	if not self._blindInvisible then
		return true
	end

	for _, _ in pairs(self._exposedList) do
		return true
	end
end

function BattleUnit.AppendExposed(self, key)
	if not self._blindInvisible then
		return
	end

	local wasExposed = self._exposedList[key]

	self._exposedList[key] = true

	if not wasExposed then
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.BLIND_EXPOSE))
	end
end

function BattleUnit.RemoveExposed(self, key)
	if not self._blindInvisible then
		return
	end

	self._exposedList[key] = nil

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.BLIND_EXPOSE))
end

function BattleUnit.SetWorldDeathMark(self)
	self._worldDeathMark = true
end

function BattleUnit.GetWorldDeathMark(self)
	return self._worldDeathMark
end

--- 隐匿组件相关 ---
function BattleUnit.InitCloak(self)
	self._cloak = ys.Battle.BattleUnitCloakComponent.New(self)

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_CLOAK))

	return self._cloak
end

-- 被BattleBuffDOT.UpdateCloakLock调用
function BattleUnit.CloakOnFire(self, exposedValue)
	if self._cloak then
		self._cloak:UpdateDotExpose(exposedValue)
	end
end

function BattleUnit.CloakExpose(self, exposeValue)
	if self._cloak then
		self._cloak:AppendExpose(exposeValue)
	end
end

function BattleUnit.StrikeExpose(self)
	if self._cloak then
		self._cloak:AppendStrikeExpose()
	end
end

function BattleUnit.BombardExpose(self)
	if self._cloak then
		self._cloak:AppendBombardExpose()
	end
end

function BattleUnit.UpdateCloak(self, timeStamp)
	self._cloak:Update(timeStamp)
end

function BattleUnit.UpdateCloakConfig(self)
	if self._cloak then
		self._cloak:UpdateCloakConfig()
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_CLOAK_CONFIG))
	end
end

function BattleUnit.DispatchCloakStateUpdate(self)
	if self._cloak then
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_CLOAK_STATE))
	end
end

function BattleUnit.GetCloak(self)
	return self._cloak
end

function BattleUnit.AttachAimBias(self, aimBias)
	self._aimBias = aimBias

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_AIMBIAS))
end

function BattleUnit.DetachAimBias(self)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.REMOVE_AIMBIAS))
	self._aimBias:RemoveCrew(self)

	self._aimBias = nil
end

function BattleUnit.ExitSmokeArea(self)
	self._aimBias:SmokeExitPause()
end

function BattleUnit.UpdateAimBiasSkillState(self)
	if self._aimBias and self._aimBias:GetHost() == self then
		self._aimBias:UpdateSkillLock()
	end
end

function BattleUnit.HostAimBias(self)
	if self._aimBias then
		self:DispatchEvent(ys.Event.New(BattleUnitEvent.HOST_AIMBIAS))
	end
end

function BattleUnit.GetAimBias(self)
	return self._aimBias
end

function BattleUnit.SwitchSpine(self, skin, HPBarOffset)
	self:DispatchEvent(ys.Event.New(BattleUnitEvent.SWITCH_SPINE, {
		skin = skin,
		HPBarOffset = HPBarOffset
	}))
end

function BattleUnit.Freeze(self)
	for _, weapon in ipairs(self._totalWeapon) do
		weapon:StartJamming()
	end

	if self._airAssistList then
		for _, airAssist in ipairs(self._airAssistList) do
			airAssist:StartJamming()
		end
	end
end

function BattleUnit.ActiveFreeze(self)
	for _, weapon in ipairs(self._totalWeapon) do
		weapon:JammingEliminate()
	end

	if self._airAssistList then
		for _, airAssist in ipairs(self._airAssistList) do
			airAssist:JammingEliminate()
		end
	end
end

function BattleUnit.ActiveWeaponSectorView(self, weapon, isActive)
	local eventData = {
		weapon = weapon,
		isActive = isActive
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.WEAPON_SECTOR, eventData))
end
