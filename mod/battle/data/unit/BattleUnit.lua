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

--- @class BattleUnit的
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
function BattleUnit.GetTargetedPriority(self)
	local targetedPriority

	if self._aimBias then
		local var_17_1 = self._aimBias:GetCurrentState()

		if var_17_1 == self._aimBias.STATE_SKILL_EXPOSE or var_17_1 == self._aimBias.STATE_TOTAL_EXPOSE then
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

		if BattleAttr.IsInvincible(self) then
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

	self:UpdateHPAction(updateHPargs)

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
--- 对应的Listener: 较多，举其中一个例子: BattleFleeVO.onUnitUpdateHP
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

function BattleUnit.GetTemplateID(arg_34_0)
	return arg_34_0._tmpID
end

function BattleUnit.SetOverrideLevel(arg_35_0, arg_35_1)
	arg_35_0._overrideLevel = arg_35_1
end

function BattleUnit.SetSkinId(arg_36_0)
	return
end

function BattleUnit.SetGearScore(arg_37_0, arg_37_1)
	arg_37_0._GS = arg_37_1
end

function BattleUnit.GetGearScore(arg_38_0)
	return arg_38_0._GS or 0
end

function BattleUnit.GetSkinID(arg_39_0)
	return arg_39_0._tmpID
end

function BattleUnit.GetDefaultSkinID(arg_40_0)
	return arg_40_0._tmpID
end

function BattleUnit.GetSkinAttachmentInfo(arg_41_0)
	return arg_41_0._orbitSkinIDList
end

function BattleUnit.GetWeaponBoundBone(arg_42_0)
	return arg_42_0._tmpData.bound_bone
end

function BattleUnit.ActionKeyOffsetUseable(arg_43_0)
	return true
end

function BattleUnit.RemoveRemoteBoundBone(arg_44_0, arg_44_1)
	arg_44_0._remoteBoundBone[arg_44_1] = nil
end

function BattleUnit.SetRemoteBoundBone(arg_45_0, arg_45_1, arg_45_2, arg_45_3)
	local var_45_0 = arg_45_0._remoteBoundBone[arg_45_1] or {}

	var_45_0[arg_45_2] = arg_45_3
	arg_45_0._remoteBoundBone[arg_45_1] = var_45_0
end
-- tODO
function BattleUnit.GetRemoteBoundBone(self, spawnBound)
	for _, iter_46_1 in pairs(self._remoteBoundBone) do
		local var_46_0 = iter_46_1[spawnBound]

		if var_46_0 then
			local var_46_1 = ys.Battle.BattleTargetChoise.TargetFleetIndex(self, {
				fleetPos = var_46_0
			})[1]

			if var_46_1 and var_46_1:IsAlive() then
				local var_46_2 = Clone(var_46_1:GetPosition())

				var_46_2:Set(var_46_2.x, 1.5, var_46_2.z)

				return var_46_2
			end
		end
	end
end

function BattleUnit.GetLabelTag(arg_47_0)
	return arg_47_0._labelTagList
end

function BattleUnit.ContainsLabelTag(arg_48_0, arg_48_1)
	if arg_48_0._labelTagList == nil then
		return false
	end

	for iter_48_0, iter_48_1 in ipairs(arg_48_1) do
		if table.contains(arg_48_0._labelTagList, iter_48_1) then
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
	for iter_50_0, iter_50_1 in ipairs(self._labelTagList) do
		if iter_50_1 == tag then
			table.remove(self._labelTagList, iter_50_0)

			local currentLabelTag = BattleAttr.GetCurrent(self, "labelTag")

			currentLabelTag[tag] = currentLabelTag[tag] - 1

			break
		end
	end
end
-- 用于设定标准标签
-- 包括国际标签N_和舰种标签T_
function BattleUnit.setStandardLabelTag(self)
	local nationalityTag = "N_" .. self._tmpData.nationality
	local typeTag = "T_" .. self._tmpData.type

	self:AddLabelTag(nationalityTag)
	self:AddLabelTag(typeTag)
end

function BattleUnit.GetRarity(arg_52_0)
	return
end

function BattleUnit.GetIntimacy(arg_53_0)
	return 0
end

function BattleUnit.IsBoss(arg_54_0)
	return false
end

function BattleUnit.GetSpeedRatio(arg_55_0)
	return BattleVariable.GetSpeedRatio(arg_55_0:GetSpeedExemptKey(), arg_55_0._IFF)
end

function BattleUnit.GetSpeedExemptKey(arg_56_0)
	return arg_56_0._speedExemptKey
end

function BattleUnit.SetMoveCast(arg_57_0, arg_57_1)
	arg_57_0._moveCast = arg_57_1
end

function BattleUnit.IsMoveCast(arg_58_0)
	return arg_58_0._moveCast
end

function BattleUnit.SetCrash(arg_59_0, arg_59_1)
	arg_59_0._isCrash = arg_59_1

	if arg_59_1 then
		local var_59_0 = ys.Battle.BattleBuffUnit.New(BattleConfig.SHIP_CLD_BUFF)

		arg_59_0:AddBuff(var_59_0)
	else
		arg_59_0:RemoveBuff(BattleConfig.SHIP_CLD_BUFF)
	end
end

function BattleUnit.IsCrash(arg_60_0)
	return arg_60_0._isCrash
end

function BattleUnit.OverrideDeadFX(arg_61_0, arg_61_1)
	arg_61_0._deadFX = arg_61_1
end

function BattleUnit.GetDeadFX(arg_62_0)
	return arg_62_0._deadFX
end

function BattleUnit.SetEquipment(arg_63_0, arg_63_1)
	arg_63_0._equipmentList = arg_63_1
	arg_63_0._autoWeaponList = {}
	arg_63_0._manualTorpedoList = {}
	arg_63_0._chargeList = {}
	arg_63_0._AAList = {}
	arg_63_0._fleetAAList = {}
	arg_63_0._fleetRangeAAList = {}
	arg_63_0._hiveList = {}
	arg_63_0._totalWeapon = {}

	arg_63_0:setWeapon(arg_63_1)
end

function BattleUnit.GetEquipment(arg_64_0)
	return arg_64_0._equipmentList
end

function BattleUnit.SetProficiencyList(arg_65_0, arg_65_1)
	arg_65_0._proficiencyList = arg_65_1
end

function BattleUnit.SetSpWeapon(arg_66_0, arg_66_1)
	arg_66_0._spWeapon = arg_66_1
end

function BattleUnit.GetSpWeapon(arg_67_0)
	return arg_67_0._spWeapon
end

function BattleUnit.setWeapon(arg_68_0, arg_68_1)
	for iter_68_0, iter_68_1 in ipairs(arg_68_1) do
		local var_68_0 = iter_68_1.equipment.weapon_id

		for iter_68_2, iter_68_3 in ipairs(var_68_0) do
			if iter_68_3 ~= -1 then
				local var_68_1 = ys.Battle.BattleDataFunction.CreateWeaponUnit(iter_68_3, arg_68_0, nil, iter_68_0)

				arg_68_0._totalWeapon[#arg_68_0._totalWeapon + 1] = var_68_1

				local var_68_2 = var_68_1:GetTemplateData().type

				if var_68_2 == BattleConst.EquipmentType.MANUAL_TORPEDO then
					arg_68_0._manualTorpedoList[#arg_68_0._manualTorpedoList + 1] = var_68_1

					arg_68_0._weaponQueue:AppendWeapon(var_68_1)
				elseif var_68_2 == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
					-- block empty
				else
					assert(#var_68_0 < 2, "自动武器一组不允许配置多个")
					arg_68_0:AddAutoWeapon(var_68_1)
				end

				if var_68_2 == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT or var_68_2 == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
					arg_68_0._hiveList[#arg_68_0._hiveList + 1] = var_68_1
				end

				if var_68_2 == BattleConst.EquipmentType.ANTI_AIR then
					arg_68_0._AAList[#arg_68_0._AAList + 1] = var_68_1
				end
			end
		end
	end
end

function BattleUnit.CheckWeaponInitial(arg_69_0)
	arg_69_0._weaponQueue:CheckWeaponInitalCD()

	if arg_69_0._airAssistQueue then
		arg_69_0._airAssistQueue:CheckWeaponInitalCD()
	end

	arg_69_0:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_COOL_DOWN, {}))
end

function BattleUnit.FlushReloadingWeapon(arg_70_0)
	arg_70_0._weaponQueue:FlushWeaponReloadRequire()

	if arg_70_0._airAssistQueue then
		arg_70_0._airAssistQueue:FlushWeaponReloadRequire()
	end
end

function BattleUnit.AddNewAutoWeapon(arg_71_0, arg_71_1)
	local var_71_0 = BattleDataFunction.CreateWeaponUnit(arg_71_1, arg_71_0)

	arg_71_0:AddAutoWeapon(var_71_0)
	arg_71_0:DispatchEvent(ys.Event.New(ys.Battle.BattleBuffEvent.BUFF_EFFECT_NEW_WEAPON, {
		weapon = var_71_0
	}))

	return var_71_0
end

function BattleUnit.AddAutoWeapon(arg_72_0, arg_72_1)
	arg_72_0._autoWeaponList[#arg_72_0._autoWeaponList + 1] = arg_72_1

	arg_72_0._weaponQueue:AppendWeapon(arg_72_1)
end

function BattleUnit.RemoveAutoWeapon(arg_73_0, arg_73_1)
	arg_73_0._weaponQueue:RemoveWeapon(arg_73_1)

	local var_73_0 = 1
	local var_73_1 = #arg_73_0._autoWeaponList

	while var_73_0 <= var_73_1 do
		if arg_73_0._autoWeaponList[var_73_0] == arg_73_1 then
			arg_73_0:DispatchEvent(ys.Event.New(BattleUnitEvent.REMOVE_WEAPON, {
				weapon = arg_73_1
			}))
			table.remove(arg_73_0._autoWeaponList, var_73_0)

			break
		end

		var_73_0 = var_73_0 + 1
	end
end

function BattleUnit.RemoveAutoWeaponByWeaponID(arg_74_0, arg_74_1)
	for iter_74_0, iter_74_1 in ipairs(arg_74_0._autoWeaponList) do
		if iter_74_1:GetWeaponId() == arg_74_1 then
			iter_74_1:Clear()
			arg_74_0:RemoveAutoWeapon(iter_74_1)

			break
		end
	end
end

function BattleUnit.RemoveAllAutoWeapon(arg_75_0)
	local var_75_0 = #arg_75_0._autoWeaponList

	while var_75_0 > 0 do
		local var_75_1 = arg_75_0._autoWeaponList[var_75_0]

		var_75_1:Clear()
		arg_75_0:RemoveAutoWeapon(var_75_1)

		var_75_0 = var_75_0 - 1
	end
end

function BattleUnit.AddFleetAntiAirWeapon(arg_76_0, arg_76_1)
	return
end

function BattleUnit.RemoveFleetAntiAirWeapon(arg_77_0, arg_77_1)
	return
end

function BattleUnit.AttachFleetRangeAAWeapon(arg_78_0, arg_78_1)
	arg_78_0._fleetRangeAA = arg_78_1

	arg_78_0:DispatchEvent(ys.Event.New(BattleUnitEvent.CREATE_TEMPORARY_WEAPON, {
		weapon = arg_78_1
	}))
end

function BattleUnit.DetachFleetRangeAAWeapon(arg_79_0)
	arg_79_0:DispatchEvent(ys.Event.New(BattleUnitEvent.REMOVE_WEAPON, {
		weapon = arg_79_0._fleetRangeAA
	}))

	arg_79_0._fleetRangeAA = nil
end

function BattleUnit.GetFleetRangeAAWeapon(arg_80_0)
	return arg_80_0._fleetRangeAA
end

function BattleUnit.ShiftWeapon(arg_81_0, arg_81_1, arg_81_2)
	for iter_81_0, iter_81_1 in ipairs(arg_81_1) do
		arg_81_0:RemoveAutoWeaponByWeaponID(iter_81_1)
	end

	for iter_81_2, iter_81_3 in ipairs(arg_81_2) do
		arg_81_0:AddNewAutoWeapon(iter_81_3):InitialCD()
	end
end

function BattleUnit.ExpandWeaponMount(arg_82_0, arg_82_1)
	if arg_82_1 == "airAssist" then
		BattleDataFunction.ExpandAllinStrike(arg_82_0)
	end
end

function BattleUnit.ReduceWeaponMount(arg_83_0, arg_83_1)
	return
end

function BattleUnit.CeaseAllWeapon(arg_84_0, arg_84_1)
	arg_84_0._ceaseFire = arg_84_1
end

function BattleUnit.IsCease(arg_85_0)
	return arg_85_0._ceaseFire
end

function BattleUnit.GetAllWeapon(arg_86_0)
	return arg_86_0._totalWeapon
end

function BattleUnit.GetTotalWeapon(arg_87_0)
	return arg_87_0._weaponQueue:GetTotalWeaponUnit()
end

function BattleUnit.GetAutoWeapons(arg_88_0)
	return arg_88_0._autoWeaponList
end

function BattleUnit.GetChargeList(arg_89_0)
	return arg_89_0._chargeList
end

function BattleUnit.GetChargeQueue(arg_90_0)
	return arg_90_0._weaponQueue:GetChargeWeaponQueue()
end

function BattleUnit.GetAntiAirWeapon(arg_91_0)
	return arg_91_0._AAList
end

function BattleUnit.GetFleetAntiAirList(arg_92_0)
	return arg_92_0._fleetAAList
end

function BattleUnit.GetFleetRangeAntiAirList(arg_93_0)
	return arg_93_0._fleetRangeAAList
end

function BattleUnit.GetTorpedoList(arg_94_0)
	return arg_94_0._manualTorpedoList
end

function BattleUnit.GetTorpedoQueue(arg_95_0)
	return arg_95_0._weaponQueue:GetManualTorpedoQueue()
end

function BattleUnit.GetWeaponByIndex(arg_96_0, arg_96_1)
	for iter_96_0, iter_96_1 in ipairs(arg_96_0._totalWeapon) do
		if iter_96_1:GetEquipmentIndex() == arg_96_1 then
			return iter_96_1
		end
	end
end

function BattleUnit.GetHiveList(arg_97_0)
	return arg_97_0._hiveList
end

function BattleUnit.SetAirAssistList(arg_98_0, arg_98_1)
	arg_98_0._airAssistList = arg_98_1
	arg_98_0._airAssistQueue = ys.Battle.ManualWeaponQueue.New(arg_98_0:GetManualWeaponParallel()[BattleConst.ManualWeaponIndex.AIR_ASSIST])

	for iter_98_0, iter_98_1 in ipairs(arg_98_0._airAssistList) do
		arg_98_0._airAssistQueue:AppendWeapon(iter_98_1)
	end
end

function BattleUnit.GetAirAssistList(arg_99_0)
	return arg_99_0._airAssistList
end

function BattleUnit.GetAirAssistQueue(arg_100_0)
	return arg_100_0._airAssistQueue
end

function BattleUnit.GetManualWeaponParallel(arg_101_0)
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

function BattleUnit.ClearWeapon(arg_103_0)
	arg_103_0._weaponQueue:ClearAllWeapon()

	local var_103_0 = arg_103_0._airAssistList

	if var_103_0 then
		for iter_103_0, iter_103_1 in ipairs(var_103_0) do
			iter_103_1:Clear()
		end
	end
end

function BattleUnit.GetSpeed(arg_104_0)
	return arg_104_0._move:GetSpeed()
end

function BattleUnit.GetPosition(arg_105_0)
	return arg_105_0._move:GetPos()
end

function BattleUnit.GetBornPosition(arg_106_0)
	return arg_106_0._bornPos
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

function BattleUnit.CancelFollowTeam(arg_110_0)
	arg_110_0._move:CancelFormationCtrl()
end

function BattleUnit.UpdateFormationOffset(arg_111_0, arg_111_1)
	arg_111_0._move:SetFormationCtrlInfo(Vector3(arg_111_1.x, arg_111_1.y, arg_111_1.z))
end

function BattleUnit.GetDistance(arg_112_0, arg_112_1)
	local var_112_0 = arg_112_0._battleProxy.FrameIndex

	if arg_112_0._frame ~= var_112_0 then
		arg_112_0._distanceBackup = {}
		arg_112_0._frame = var_112_0
	end

	local var_112_1 = arg_112_0._distanceBackup[arg_112_1]

	if var_112_1 == nil then
		var_112_1 = Vector3.Distance(arg_112_0:GetPosition(), arg_112_1:GetPosition())
		arg_112_0._distanceBackup[arg_112_1] = var_112_1

		arg_112_1:backupDistance(arg_112_0, var_112_1)
	end

	return var_112_1
end

function BattleUnit.backupDistance(arg_113_0, arg_113_1, arg_113_2)
	local var_113_0 = arg_113_0._battleProxy.FrameIndex

	if arg_113_0._frame ~= var_113_0 then
		arg_113_0._distanceBackup = {}
		arg_113_0._frame = var_113_0
	end

	arg_113_0._distanceBackup[arg_113_1] = arg_113_2
end

function BattleUnit.GetDirection(arg_114_0)
	return arg_114_0._dir
end

function BattleUnit.SetBornPosition(arg_115_0, arg_115_1)
	arg_115_0._bornPos = arg_115_1
end

function BattleUnit.SetPosition(arg_116_0, arg_116_1)
	arg_116_0._move:SetPos(arg_116_1)
end

function BattleUnit.IsMoving(arg_117_0)
	local var_117_0 = arg_117_0._move:GetSpeed()

	return var_117_0.x ~= 0 or var_117_0.z ~= 0
end

function BattleUnit.SetUncontrollableSpeedWithYAngle(arg_118_0, arg_118_1, arg_118_2, arg_118_3)
	local var_118_0 = math.deg2Rad * arg_118_1
	local var_118_1 = Vector3(math.cos(var_118_0), 0, math.sin(var_118_0))

	arg_118_0:SetUncontrollableSpeed(var_118_1, arg_118_2, arg_118_3)
end

function BattleUnit.SetUncontrollableSpeedWithDir(arg_119_0, arg_119_1, arg_119_2, arg_119_3)
	local var_119_0 = math.sqrt(arg_119_1.x * arg_119_1.x + arg_119_1.z * arg_119_1.z)

	arg_119_0:SetUncontrollableSpeed(arg_119_1 / var_119_0, arg_119_2, arg_119_3)
end

function BattleUnit.SetUncontrollableSpeed(arg_120_0, arg_120_1, arg_120_2, arg_120_3)
	if not arg_120_2 or not arg_120_3 then
		return
	end

	arg_120_0._move:SetForceMove(arg_120_1, arg_120_2, arg_120_3, arg_120_2 / arg_120_3)
end

function BattleUnit.ClearUncontrollableSpeed(arg_121_0)
	arg_121_0._move:ClearForceMove()
end

function BattleUnit.SetAdditiveSpeed(arg_122_0, arg_122_1)
	arg_122_0._move:UpdateAdditiveSpeed(arg_122_1)
end

function BattleUnit.RemoveAdditiveSpeed(arg_123_0)
	arg_123_0._move:RemoveAdditiveSpeed()
end

function BattleUnit.Boost(arg_124_0, arg_124_1, arg_124_2, arg_124_3, arg_124_4, arg_124_5)
	arg_124_0._move:SetForceMove(arg_124_1, arg_124_2, arg_124_3, arg_124_4, arg_124_5)
end

function BattleUnit.ActiveUnstoppable(arg_125_0, arg_125_1)
	arg_125_0._move:ActiveUnstoppable(arg_125_1)
end

function BattleUnit.SetImmuneCommonBulletCLD(arg_126_0)
	arg_126_0._immuneCommonBulletCLD = true
end

function BattleUnit.IsImmuneCommonBulletCLD(arg_127_0)
	return arg_127_0._immuneCommonBulletCLD
end

function BattleUnit.SetWeaponPreCastBound(arg_128_0, arg_128_1)
	arg_128_0._preCastBound = arg_128_1

	arg_128_0:UpdatePrecastMoveLimit()
end

function BattleUnit.EnterGCD(arg_129_0, arg_129_1, arg_129_2)
	if arg_129_0._GCDTimerList[arg_129_2] ~= nil then
		return
	end

	local function var_129_0()
		arg_129_0:RemoveGCDTimer(arg_129_2)
	end

	arg_129_0._weaponQueue:QueueEnterGCD(arg_129_2, arg_129_1)

	arg_129_0._GCDTimerList[arg_129_2] = pg.TimeMgr.GetInstance():AddBattleTimer("weaponGCD", 0, arg_129_1, var_129_0, true)

	arg_129_0:UpdatePrecastMoveLimit()
end

function BattleUnit.RemoveGCDTimer(arg_131_0, arg_131_1)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(arg_131_0._GCDTimerList[arg_131_1])

	arg_131_0._GCDTimerList[arg_131_1] = nil

	arg_131_0:UpdatePrecastMoveLimit()
end

function BattleUnit.UpdatePrecastMoveLimit(arg_132_0)
	arg_132_0:UpdateMoveLimit()
end

function BattleUnit.UpdateMoveLimit(arg_133_0)
	local var_133_0 = arg_133_0:IsMoveAble()

	arg_133_0._move:SetStaticState(not var_133_0)
end

function BattleUnit.AddBuff(arg_134_0, arg_134_1, arg_134_2)
	local var_134_0 = arg_134_1:GetID()
	local var_134_1 = {
		unit_id = arg_134_0._uniqueID,
		buff_id = var_134_0
	}
	local var_134_2 = arg_134_0:GetBuff(var_134_0)

	if var_134_2 then
		if arg_134_2 then
			local var_134_3 = arg_134_0._buffStockList[var_134_0] or {}

			table.insert(var_134_3, arg_134_1)

			arg_134_0._buffStockList[var_134_0] = var_134_3
		else
			local var_134_4 = var_134_2:GetLv()
			local var_134_5 = arg_134_1:GetLv()
			local var_134_6 = var_134_2:GetGroupLevel()
			local var_134_7 = arg_134_1:GetGroupLevel()

			var_134_1.buff_level = math.max(var_134_4, var_134_5)

			if var_134_2:IsForceStack() or var_134_7 <= var_134_6 then
				var_134_2:Stack(arg_134_0)

				var_134_1.stack_count = var_134_2:GetStack()

				arg_134_0:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_STACK, var_134_1))
			else
				arg_134_0:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_CAST, var_134_1))
				arg_134_0:RemoveBuff(var_134_0)

				arg_134_0._buffList[var_134_0] = arg_134_1

				arg_134_1:Attach(arg_134_0)
				arg_134_0:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_ATTACH, var_134_1))
			end
		end
	else
		arg_134_0:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_CAST, var_134_1))

		arg_134_0._buffList[var_134_0] = arg_134_1

		arg_134_1:Attach(arg_134_0)

		var_134_1.buff_level = arg_134_1:GetLv()

		arg_134_0:DispatchEvent(ys.Event.New(BattleBuffEvent.BUFF_ATTACH, var_134_1))
	end

	arg_134_0:TriggerBuff(BattleConst.BuffEffectType.ON_BUFF_ADDED, {
		buffID = var_134_0
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

function BattleUnit.UpdateBuff(arg_136_0, arg_136_1)
	local var_136_0 = arg_136_0._buffList

	for iter_136_0, iter_136_1 in pairs(var_136_0) do
		iter_136_1:Update(arg_136_0, arg_136_1)

		if not arg_136_0:IsAlive() then
			break
		end
	end
end

function BattleUnit.ConsumeBuffStack(arg_137_0, arg_137_1, arg_137_2)
	local var_137_0 = arg_137_0:GetBuff(arg_137_1)

	if var_137_0 then
		if not arg_137_2 then
			arg_137_0:RemoveBuff(arg_137_1)
		else
			local var_137_1 = var_137_0:GetStack()
			local var_137_2 = math.max(0, var_137_1 - arg_137_2)

			if var_137_2 == 0 then
				arg_137_0:RemoveBuff(arg_137_1)
			else
				var_137_0:UpdateStack(arg_137_0, var_137_2)
			end
		end
	end
end

function BattleUnit.RemoveBuff(arg_138_0, arg_138_1, arg_138_2)
	if arg_138_2 and arg_138_0._buffStockList[arg_138_1] then
		local var_138_0 = table.remove(arg_138_0._buffStockList[arg_138_1])

		if var_138_0 then
			var_138_0:Clear()

			return
		end
	end

	local var_138_1 = arg_138_0:GetBuff(arg_138_1)

	if var_138_1 then
		var_138_1:Remove()
	end

	arg_138_0:TriggerBuff(BattleConst.BuffEffectType.ON_BUFF_REMOVED, {
		buffID = arg_138_1
	})
end

function BattleUnit.ClearBuff(arg_139_0)
	local var_139_0 = arg_139_0._buffList

	for iter_139_0, iter_139_1 in pairs(var_139_0) do
		iter_139_1:Clear()
	end

	local var_139_1 = arg_139_0._buffStockList

	for iter_139_2, iter_139_3 in pairs(var_139_1) do
		for iter_139_4, iter_139_5 in pairs(iter_139_3) do
			iter_139_5:Clear()
		end
	end
end

--- @class BattleUnit
--- @param effectType string
--- @param args table<string, any>
--- @return nil
--- BattleUnit的Buff触发接口
--- - 调用BattleBuffUnit的静态方法Trigger
function BattleUnit.TriggerBuff(self, effectType, args)
	ys.Battle.BattleBuffUnit.Trigger(self, effectType, args)
end

function BattleUnit.GetBuffList(arg_141_0)
	return arg_141_0._buffList
end

function BattleUnit.GetBuff(arg_142_0, arg_142_1)
	arg_142_0._buffList = arg_142_0._buffList

	return arg_142_0._buffList[arg_142_1]
end

function BattleUnit.DispatchSkillFloat(arg_143_0, arg_143_1, arg_143_2, arg_143_3)
	local var_143_0 = {
		coverHrzIcon = arg_143_3,
		commander = arg_143_2,
		skillName = arg_143_1
	}

	arg_143_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SKILL_FLOAT, var_143_0))
end

function BattleUnit.DispatchCutIn(arg_144_0, arg_144_1, arg_144_2)
	local var_144_0 = {
		caster = arg_144_0,
		skill = arg_144_1
	}

	arg_144_0:DispatchEvent(ys.Event.New(BattleUnitEvent.CUT_INT, var_144_0))
end

function BattleUnit.DispatchCastClock(arg_145_0, arg_145_1, arg_145_2, arg_145_3, arg_145_4, arg_145_5)
	local var_145_0 = {
		isActive = arg_145_1,
		buffEffect = arg_145_2,
		iconType = arg_145_3,
		interrupt = arg_145_4,
		reverse = arg_145_5
	}

	arg_145_0:DispatchEvent(ys.Event.New(BattleUnitEvent.ADD_BUFF_CLOCK, var_145_0))
end

function BattleUnit.SetAI(arg_146_0, arg_146_1)
	local var_146_0 = BattleDataFunction.GetAITmpDataFromID(arg_146_1)

	arg_146_0._autoPilotAI = ys.Battle.AutoPilot.New(arg_146_0, var_146_0), arg_146_0._move:CancelFormationCtrl()
end

function BattleUnit.AddPhaseSwitcher(arg_147_0, arg_147_1)
	arg_147_0._phaseSwitcher = arg_147_1
end

function BattleUnit.GetPhaseSwitcher(arg_148_0)
	return arg_148_0._phaseSwitcher
end

function BattleUnit.StateChange(arg_149_0, arg_149_1, arg_149_2)
	arg_149_0._unitState:ChangeState(arg_149_1, arg_149_2)
end

function BattleUnit.UpdateAction(arg_150_0)
	local var_150_0 = arg_150_0:GetSpeed().x * arg_150_0._IFF

	if arg_150_0._oxyState and arg_150_0._oxyState:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
		if var_150_0 >= 0 then
			arg_150_0._unitState:ChangeState(UnitState.STATE_DIVE)
		else
			arg_150_0._unitState:ChangeState(UnitState.STATE_DIVELEFT)
		end
	elseif var_150_0 >= 0 then
		arg_150_0._unitState:ChangeState(UnitState.STATE_MOVE)
	else
		arg_150_0._unitState:ChangeState(UnitState.STATE_MOVELEFT)
	end
end

function BattleUnit.SetActionKeyOffset(arg_151_0, arg_151_1)
	arg_151_0._actionKeyOffset = arg_151_1

	arg_151_0._unitState:FreshActionKeyOffset()
end

function BattleUnit.GetActionKeyOffset(arg_152_0)
	return arg_152_0._actionKeyOffset
end

function BattleUnit.GetCurrentState(arg_153_0)
	return arg_153_0._unitState:GetCurrentStateName()
end

function BattleUnit.NeedWeaponCache(arg_154_0)
	return arg_154_0._unitState:NeedWeaponCache()
end

function BattleUnit.CharacterActionTriggerCallback(arg_155_0)
	arg_155_0._unitState:OnActionTrigger()
end

function BattleUnit.CharacterActionEndCallback(arg_156_0)
	arg_156_0._unitState:OnActionEnd()
end

function BattleUnit.CharacterActionStartCallback(arg_157_0)
	return
end

function BattleUnit.DispatchChat(arg_158_0, arg_158_1, arg_158_2, arg_158_3)
	if not arg_158_1 or #arg_158_1 == 0 then
		return
	end

	local var_158_0 = {
		content = HXSet.hxLan(arg_158_1),
		duration = arg_158_2,
		key = arg_158_3
	}

	arg_158_0:DispatchEvent(ys.Event.New(BattleUnitEvent.POP_UP, var_158_0))
end

function BattleUnit.DispatchVoice(arg_159_0, arg_159_1)
	local var_159_0 = arg_159_0:GetIntimacy()
	local var_159_1, var_159_2, var_159_3 = ShipWordHelper.GetWordAndCV(arg_159_0:GetSkinID(), arg_159_1, 1, true, var_159_0)

	if var_159_2 then
		local var_159_4 = {
			content = var_159_2,
			key = arg_159_1
		}

		arg_159_0:DispatchEvent(ys.Event.New(BattleUnitEvent.VOICE, var_159_4))
	end
end

function BattleUnit.GetHostileCldList(arg_160_0)
	return arg_160_0._hostileCldList
end

function BattleUnit.AppendHostileCld(arg_161_0, arg_161_1, arg_161_2)
	arg_161_0._hostileCldList[arg_161_1] = arg_161_2
end

function BattleUnit.RemoveHostileCld(arg_162_0, arg_162_1)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(arg_162_0._hostileCldList[arg_162_1])

	arg_162_0._hostileCldList[arg_162_1] = nil
end

function BattleUnit.GetExtraInfo(arg_163_0)
	return arg_163_0._extraInfo
end

function BattleUnit.GetTemplate(arg_164_0)
	return nil
end

function BattleUnit.GetGroupID(arg_165_0)
	return nil
end

function BattleUnit.GetTemplateValue(arg_166_0, arg_166_1)
	return arg_166_0:GetTemplate()[arg_166_1]
end

function BattleUnit.GetUniqueID(arg_167_0)
	return arg_167_0._uniqueID
end

function BattleUnit.SetIFF(arg_168_0, arg_168_1)
	arg_168_0._IFF = arg_168_1

	if arg_168_1 == BattleConfig.FRIENDLY_CODE then
		arg_168_0._dir = BattleConst.UnitDir.RIGHT
	elseif arg_168_1 == BattleConfig.FOE_CODE then
		arg_168_0._dir = BattleConst.UnitDir.LEFT
	end
end

function BattleUnit.GetIFF(arg_169_0)
	return arg_169_0._IFF
end

function BattleUnit.GetUnitType(arg_170_0)
	return arg_170_0._type
end

function BattleUnit.GetHPRate(arg_171_0)
	return arg_171_0._currentHPRate
end

function BattleUnit.GetHP(arg_172_0)
	return arg_172_0._currentHP, arg_172_0:GetMaxHP()
end

function BattleUnit.GetCurrentHP(arg_173_0)
	return arg_173_0._currentHP
end

function BattleUnit.SetCurrentHP(arg_174_0, arg_174_1)
	arg_174_0._currentHP = arg_174_1
	arg_174_0._currentHPRate = arg_174_0._currentHP / arg_174_0:GetMaxHP()
	arg_174_0._currentDMGRate = 1 - arg_174_0._currentHPRate

	BattleAttr.SetCurrent(arg_174_0, "HPRate", arg_174_0._currentHPRate)
	BattleAttr.SetCurrent(arg_174_0, "DMGRate", arg_174_0._currentDMGRate)
end

function BattleUnit.GetAttr(arg_175_0)
	return BattleAttr.GetAttr(arg_175_0)
end

function BattleUnit.GetAttrByName(arg_176_0, arg_176_1)
	return BattleAttr.GetCurrent(arg_176_0, arg_176_1)
end

function BattleUnit.GetMaxHP(arg_177_0)
	return arg_177_0:GetAttrByName("maxHP")
end

function BattleUnit.GetReload(arg_178_0)
	return arg_178_0:GetAttrByName("loadSpeed")
end

function BattleUnit.GetTorpedoPower(arg_179_0)
	return arg_179_0:GetAttrByName("torpedoPower")
end

function BattleUnit.CanDoAntiSub(arg_180_0)
	return arg_180_0:GetAttrByName("antiSubPower") > 0
end

function BattleUnit.IsShowHPBar(arg_181_0)
	return false
end

function BattleUnit.IsAlive(arg_182_0)
	local var_182_0 = arg_182_0:GetCurrentHP()

	return arg_182_0._aliveState and var_182_0 > 0
end

function BattleUnit.SetMainFleetUnit(arg_183_0)
	arg_183_0._isMainFleetUnit = true

	arg_183_0:SetMainUnitStatic(true)
end

function BattleUnit.IsMainFleetUnit(arg_184_0)
	return arg_184_0._isMainFleetUnit
end

function BattleUnit.SetMainUnitStatic(arg_185_0, arg_185_1)
	arg_185_0._isMainStatic = arg_185_1

	arg_185_0._move:SetStaticState(arg_185_1)
end

function BattleUnit.SetMainUnitIndex(arg_186_0, arg_186_1)
	arg_186_0._mainUnitIndex = arg_186_1
end

function BattleUnit.GetMainUnitIndex(arg_187_0)
	return arg_187_0._mainUnitIndex or 1
end

function BattleUnit.IsMoveAble(arg_188_0)
	local var_188_0 = table.getCount(arg_188_0._GCDTimerList) > 0 or arg_188_0._preCastBound
	local var_188_1 = BattleAttr.IsStun(arg_188_0)
	local var_188_2 = arg_188_0:IsMoveCast()

	return not arg_188_0._isMainStatic and (var_188_2 or not var_188_0) and not var_188_1
end

function BattleUnit.Reinforce(arg_189_0)
	arg_189_0._isReinforcement = true
end

function BattleUnit.IsReinforcement(arg_190_0)
	return arg_190_0._isReinforcement
end

function BattleUnit.SetReinforceCastTime(arg_191_0, arg_191_1)
	arg_191_0._reinforceCastTime = arg_191_1
end

function BattleUnit.GetReinforceCastTime(arg_192_0)
	return arg_192_0._reinforceCastTime
end

function BattleUnit.GetFleetVO(arg_193_0)
	return
end

function BattleUnit.SetFormationIndex(arg_194_0, arg_194_1)
	return
end

function BattleUnit.SetMaster(arg_195_0)
	return
end

function BattleUnit.GetMaster(arg_196_0)
	return nil
end

function BattleUnit.IsSpectre(self)
	return
end

function BattleUnit.Clear(arg_198_0)
	arg_198_0._aliveState = false

	for iter_198_0, iter_198_1 in pairs(arg_198_0._hostileCldList) do
		arg_198_0:RemoveHostileCld(iter_198_0)
	end

	arg_198_0:ClearWeapon()
	arg_198_0:ClearBuff()

	arg_198_0._distanceBackup = {}
end

function BattleUnit.Dispose(arg_199_0)
	arg_199_0._exposedList = nil
	arg_199_0._phaseSwitcher = nil

	arg_199_0._weaponQueue:Dispose()

	if arg_199_0._airAssistQueue then
		arg_199_0._airAssistQueue:Clear()

		arg_199_0._airAssistQueue = nil
	end

	arg_199_0._equipmentList = nil
	arg_199_0._totalWeapon = nil

	local var_199_0 = arg_199_0._airAssistList

	if var_199_0 then
		for iter_199_0, iter_199_1 in ipairs(var_199_0) do
			iter_199_1:Dispose()
		end
	end

	for iter_199_2, iter_199_3 in ipairs(arg_199_0._fleetAAList) do
		iter_199_3:Dispose()
	end

	for iter_199_4, iter_199_5 in ipairs(arg_199_0._fleetRangeAAList) do
		iter_199_5:Dispose()
	end

	local var_199_1 = arg_199_0._buffList

	for iter_199_6, iter_199_7 in pairs(var_199_1) do
		iter_199_7:Dispose()
	end

	local var_199_2 = arg_199_0._buffStockList

	for iter_199_8, iter_199_9 in pairs(var_199_2) do
		for iter_199_10, iter_199_11 in pairs(iter_199_9) do
			iter_199_11:Clear()
		end
	end

	arg_199_0._fleetRangeAA = nil
	arg_199_0._aimBias = nil
	arg_199_0._buffList = nil
	arg_199_0._buffStockList = nil
	arg_199_0._cldZCenterCache = nil
	arg_199_0._remoteBoundBone = nil

	arg_199_0:RemoveSummonSickness()
	ys.EventDispatcher.DetachEventDispatcher(arg_199_0)
end

function BattleUnit.InitCldComponent(arg_200_0)
	local var_200_0 = arg_200_0:GetTemplate().cld_box
	local var_200_1 = arg_200_0:GetTemplate().cld_offset
	local var_200_2 = var_200_1[1]

	if arg_200_0:GetDirection() == BattleConst.UnitDir.LEFT then
		var_200_2 = var_200_2 * -1
	end

	arg_200_0._cldComponent = ys.Battle.BattleCubeCldComponent.New(var_200_0[1], var_200_0[2], var_200_0[3], var_200_2, var_200_1[3] + var_200_0[3] / 2)
end

function BattleUnit.GetBoxSize(arg_201_0)
	return arg_201_0._cldComponent:GetCldBoxSize()
end

function BattleUnit.GetCldBox(arg_202_0)
	return arg_202_0._cldComponent:GetCldBox(arg_202_0:GetPosition())
end

function BattleUnit.GetCldData(arg_203_0)
	return arg_203_0._cldComponent:GetCldData()
end

function BattleUnit.ShiftCldComponent(arg_204_0, arg_204_1, arg_204_2)
	arg_204_0:updateCldComponet(arg_204_1, arg_204_2)
end

function BattleUnit.ResetCldComponent(arg_205_0)
	local var_205_0 = arg_205_0:GetTemplate().cld_box
	local var_205_1 = arg_205_0:GetTemplate().cld_offset

	arg_205_0:updateCldComponet(var_205_0, var_205_1)
end

function BattleUnit.updateCldComponet(arg_206_0, arg_206_1, arg_206_2)
	local var_206_0 = arg_206_2[1]

	if arg_206_0:GetDirection() == BattleConst.UnitDir.LEFT then
		var_206_0 = var_206_0 * -1
	end

	arg_206_0._cldComponent:ResetOffset(var_206_0, arg_206_2[3] + arg_206_1[3] / 2)
	arg_206_0._cldComponent:ResetSize(arg_206_1[1], arg_206_1[2], arg_206_1[3])
end

function BattleUnit.InitOxygen(arg_207_0)
	arg_207_0._maxOxy = arg_207_0:GetAttrByName("oxyMax")
	arg_207_0._currentOxy = arg_207_0:GetAttrByName("oxyMax")
	arg_207_0._oxyRecovery = arg_207_0:GetAttrByName("oxyRecovery")
	arg_207_0._oxyRecoveryBench = arg_207_0:GetAttrByName("oxyRecoveryBench")
	arg_207_0._oxyRecoverySurface = arg_207_0:GetAttrByName("oxyRecoverySurface")
	arg_207_0._oxyConsume = arg_207_0:GetAttrByName("oxyCost")
	arg_207_0._oxyState = ys.Battle.OxyState.New(arg_207_0)

	arg_207_0._oxyState:OnDiveState()
	arg_207_0:ConfigBubbleFX()

	return arg_207_0._oxyState
end

function BattleUnit.UpdateOxygen(arg_208_0, arg_208_1)
	if arg_208_0._oxyState then
		arg_208_0._lastOxyUpdateStamp = arg_208_0._lastOxyUpdateStamp or arg_208_1

		arg_208_0._oxyState:UpdateOxygen()

		if arg_208_0._oxyState:GetNextBubbleStamp() and arg_208_1 > arg_208_0._oxyState:GetNextBubbleStamp() then
			arg_208_0._oxyState:FlashBubbleStamp(arg_208_1)
			arg_208_0:PlayFX(arg_208_0._bubbleFX, true)
		end

		arg_208_0._lastOxyUpdateStamp = arg_208_1

		arg_208_0:updateSonarExposeTag()
	end
end

function BattleUnit.OxyRecover(arg_209_0, arg_209_1)
	local var_209_0

	if arg_209_1 == ys.Battle.OxyState.STATE_FREE_BENCH then
		var_209_0 = arg_209_0._oxyRecoveryBench
	elseif arg_209_1 == ys.Battle.OxyState.STATE_FREE_FLOAT then
		var_209_0 = arg_209_0._oxyRecovery
	else
		var_209_0 = arg_209_0._oxyRecoverySurface
	end

	local var_209_1 = pg.TimeMgr.GetInstance():GetCombatTime() - arg_209_0._lastOxyUpdateStamp

	arg_209_0._currentOxy = math.min(arg_209_0._maxOxy, arg_209_0._currentOxy + var_209_0 * var_209_1)
end

function BattleUnit.OxyConsume(arg_210_0)
	local var_210_0 = pg.TimeMgr.GetInstance():GetCombatTime() - arg_210_0._lastOxyUpdateStamp

	arg_210_0._currentOxy = math.max(0, arg_210_0._currentOxy - arg_210_0._oxyConsume * var_210_0)
end

function BattleUnit.ChangeOxygenState(arg_211_0, arg_211_1)
	arg_211_0._oxyState:ChangeState(arg_211_1)
end

function BattleUnit.ChangeWeaponDiveState(arg_212_0)
	for iter_212_0, iter_212_1 in ipairs(arg_212_0._autoWeaponList) do
		iter_212_1:ChangeDiveState()
	end
end

function BattleUnit.GetOxygenProgress(arg_213_0)
	return arg_213_0._currentOxy / arg_213_0._maxOxy
end

function BattleUnit.GetCuurentOxygen(arg_214_0)
	return arg_214_0._currentOxy or 0
end

function BattleUnit.ConfigBubbleFX(arg_215_0)
	return
end

function BattleUnit.SetDiveInvisible(arg_216_0, arg_216_1)
	arg_216_0._diveInvisible = arg_216_1

	arg_216_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_VISIBLE))
	arg_216_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_DETECTED))
	arg_216_0:dispatchDetectedTrigger()
end

function BattleUnit.GetDiveInvisible(arg_217_0)
	return arg_217_0._diveInvisible
end

function BattleUnit.GetOxygenVisible(arg_218_0)
	return arg_218_0._oxyState and arg_218_0._oxyState:GetBarVisible()
end

function BattleUnit.SetForceVisible(arg_219_0)
	arg_219_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_FORCE_DETECTED))
end

function BattleUnit.Detected(arg_220_0, arg_220_1)
	local var_220_0

	if arg_220_0._exposedToSnoar == false and not arg_220_0._exposedOverTimeStamp then
		var_220_0 = true
	end

	if arg_220_1 then
		arg_220_0:updateExposeTimeStamp(arg_220_1)
	else
		arg_220_0._exposedToSnoar = true
	end

	if var_220_0 then
		arg_220_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_DETECTED, {}))
		arg_220_0:dispatchDetectedTrigger()
	end
end

function BattleUnit.Undetected(arg_221_0)
	arg_221_0._exposedToSnoar = false

	arg_221_0:updateExposeTimeStamp(BattleConfig.SUB_EXPOSE_LASTING_DURATION)
end

function BattleUnit.RemoveSonarExpose(arg_222_0)
	arg_222_0._exposedToSnoar = false
	arg_222_0._exposedOverTimeStamp = nil
end

function BattleUnit.updateSonarExposeTag(arg_223_0)
	if arg_223_0._exposedOverTimeStamp and not arg_223_0._exposedToSnoar and pg.TimeMgr.GetInstance():GetCombatTime() > arg_223_0._exposedOverTimeStamp then
		arg_223_0._exposedOverTimeStamp = nil

		arg_223_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SUBMARINE_DETECTED, {
			detected = false
		}))
		arg_223_0:dispatchDetectedTrigger()
	end
end

function BattleUnit.updateExposeTimeStamp(arg_224_0, arg_224_1)
	local var_224_0 = pg.TimeMgr.GetInstance():GetCombatTime() + arg_224_1

	arg_224_0._exposedOverTimeStamp = arg_224_0._exposedOverTimeStamp or 0
	arg_224_0._exposedOverTimeStamp = var_224_0 < arg_224_0._exposedOverTimeStamp and arg_224_0._exposedOverTimeStamp or var_224_0
end

function BattleUnit.IsRunMode(arg_225_0)
	return arg_225_0._oxyState and arg_225_0._oxyState:GetRundMode()
end

function BattleUnit.GetDiveDetected(arg_226_0)
	return arg_226_0:GetDiveInvisible() and (arg_226_0._exposedOverTimeStamp or arg_226_0._exposedToSnoar)
end

function BattleUnit.GetForceExpose(arg_227_0)
	return arg_227_0._oxyState and arg_227_0._oxyState:GetForceExpose()
end

function BattleUnit.dispatchDetectedTrigger(arg_228_0)
	if arg_228_0:GetDiveDetected() then
		arg_228_0:TriggerBuff(BattleConst.BuffEffectType.ON_SUB_DETECTED, {})
	else
		arg_228_0:TriggerBuff(BattleConst.BuffEffectType.ON_SUB_UNDETECTED, {})
	end
end

function BattleUnit.GetRaidDuration(arg_229_0)
	return arg_229_0:GetAttrByName("oxyMax") / arg_229_0:GetAttrByName("oxyCost")
end

function BattleUnit.EnterRaidRange(arg_230_0)
	if arg_230_0:GetPosition().x > arg_230_0._subRaidLine then
		return true
	else
		return false
	end
end

function BattleUnit.EnterRetreatRange(arg_231_0)
	if arg_231_0:GetPosition().x < arg_231_0._subRetreatLine then
		return true
	else
		return false
	end
end

function BattleUnit.GetOxyState(arg_232_0)
	return arg_232_0._oxyState
end

function BattleUnit.GetCurrentOxyState(arg_233_0)
	if not arg_233_0._oxyState then
		return BattleConst.OXY_STATE.FLOAT
	else
		return arg_233_0._oxyState:GetCurrentDiveState()
	end
end

function BattleUnit.InitAntiSubState(arg_234_0, arg_234_1, arg_234_2)
	arg_234_0._antiSubVigilanceState = ys.Battle.AntiSubState.New(arg_234_0)

	arg_234_0:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_ANIT_SUB_VIGILANCE, {
		sonarRange = arg_234_1
	}))

	return arg_234_0._antiSubVigilanceState
end

function BattleUnit.GetAntiSubState(arg_235_0)
	return arg_235_0._antiSubVigilanceState
end

function BattleUnit.UpdateBlindInvisibleBySpectre(arg_236_0)
	local var_236_0, var_236_1 = arg_236_0:IsSpectre()

	if var_236_1 <= BattleConfig.SPECTRE_UNIT_TYPE and var_236_1 ~= BattleConfig.VISIBLE_SPECTRE_UNIT_TYPE then
		arg_236_0:SetBlindInvisible(true)
	else
		arg_236_0:SetBlindInvisible(false)
	end
end

function BattleUnit.SetBlindInvisible(arg_237_0, arg_237_1)
	arg_237_0._exposedList = arg_237_1 and {} or nil
	arg_237_0._blindInvisible = arg_237_1

	arg_237_0:DispatchEvent(ys.Event.New(BattleUnitEvent.BLIND_VISIBLE))
end

function BattleUnit.GetBlindInvisible(arg_238_0)
	return arg_238_0._blindInvisible
end

function BattleUnit.GetExposed(arg_239_0)
	if not arg_239_0._blindInvisible then
		return true
	end

	for iter_239_0, iter_239_1 in pairs(arg_239_0._exposedList) do
		return true
	end
end

function BattleUnit.AppendExposed(arg_240_0, arg_240_1)
	if not arg_240_0._blindInvisible then
		return
	end

	local var_240_0 = arg_240_0._exposedList[arg_240_1]

	arg_240_0._exposedList[arg_240_1] = true

	if not var_240_0 then
		arg_240_0:DispatchEvent(ys.Event.New(BattleUnitEvent.BLIND_EXPOSE))
	end
end

function BattleUnit.RemoveExposed(arg_241_0, arg_241_1)
	if not arg_241_0._blindInvisible then
		return
	end

	arg_241_0._exposedList[arg_241_1] = nil

	arg_241_0:DispatchEvent(ys.Event.New(BattleUnitEvent.BLIND_EXPOSE))
end

function BattleUnit.SetWorldDeathMark(arg_242_0)
	arg_242_0._worldDeathMark = true
end

function BattleUnit.GetWorldDeathMark(arg_243_0)
	return arg_243_0._worldDeathMark
end

function BattleUnit.InitCloak(arg_244_0)
	arg_244_0._cloak = ys.Battle.BattleUnitCloakComponent.New(arg_244_0)

	arg_244_0:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_CLOAK))

	return arg_244_0._cloak
end

function BattleUnit.CloakOnFire(arg_245_0, arg_245_1)
	if arg_245_0._cloak then
		arg_245_0._cloak:UpdateDotExpose(arg_245_1)
	end
end

function BattleUnit.CloakExpose(arg_246_0, arg_246_1)
	if arg_246_0._cloak then
		arg_246_0._cloak:AppendExpose(arg_246_1)
	end
end

function BattleUnit.StrikeExpose(arg_247_0)
	if arg_247_0._cloak then
		arg_247_0._cloak:AppendStrikeExpose()
	end
end

function BattleUnit.BombardExpose(arg_248_0)
	if arg_248_0._cloak then
		arg_248_0._cloak:AppendBombardExpose()
	end
end

function BattleUnit.UpdateCloak(arg_249_0, arg_249_1)
	arg_249_0._cloak:Update(arg_249_1)
end

function BattleUnit.UpdateCloakConfig(arg_250_0)
	if arg_250_0._cloak then
		arg_250_0._cloak:UpdateCloakConfig()
		arg_250_0:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_CLOAK_CONFIG))
	end
end

function BattleUnit.DispatchCloakStateUpdate(arg_251_0)
	if arg_251_0._cloak then
		arg_251_0:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_CLOAK_STATE))
	end
end

function BattleUnit.GetCloak(arg_252_0)
	return arg_252_0._cloak
end

function BattleUnit.AttachAimBias(arg_253_0, arg_253_1)
	arg_253_0._aimBias = arg_253_1

	arg_253_0:DispatchEvent(ys.Event.New(BattleUnitEvent.INIT_AIMBIAS))
end

function BattleUnit.DetachAimBias(arg_254_0)
	arg_254_0:DispatchEvent(ys.Event.New(BattleUnitEvent.REMOVE_AIMBIAS))
	arg_254_0._aimBias:RemoveCrew(arg_254_0)

	arg_254_0._aimBias = nil
end

function BattleUnit.ExitSmokeArea(arg_255_0)
	arg_255_0._aimBias:SmokeExitPause()
end

function BattleUnit.UpdateAimBiasSkillState(arg_256_0)
	if arg_256_0._aimBias and arg_256_0._aimBias:GetHost() == arg_256_0 then
		arg_256_0._aimBias:UpdateSkillLock()
	end
end

function BattleUnit.HostAimBias(arg_257_0)
	if arg_257_0._aimBias then
		arg_257_0:DispatchEvent(ys.Event.New(BattleUnitEvent.HOST_AIMBIAS))
	end
end

function BattleUnit.GetAimBias(arg_258_0)
	return arg_258_0._aimBias
end

function BattleUnit.SwitchSpine(arg_259_0, arg_259_1, arg_259_2)
	arg_259_0:DispatchEvent(ys.Event.New(BattleUnitEvent.SWITCH_SPINE, {
		skin = arg_259_1,
		HPBarOffset = arg_259_2
	}))
end

function BattleUnit.Freeze(arg_260_0)
	for iter_260_0, iter_260_1 in ipairs(arg_260_0._totalWeapon) do
		iter_260_1:StartJamming()
	end

	if arg_260_0._airAssistList then
		for iter_260_2, iter_260_3 in ipairs(arg_260_0._airAssistList) do
			iter_260_3:StartJamming()
		end
	end
end

function BattleUnit.ActiveFreeze(arg_261_0)
	for iter_261_0, iter_261_1 in ipairs(arg_261_0._totalWeapon) do
		iter_261_1:JammingEliminate()
	end

	if arg_261_0._airAssistList then
		for iter_261_2, iter_261_3 in ipairs(arg_261_0._airAssistList) do
			iter_261_3:JammingEliminate()
		end
	end
end

function BattleUnit.ActiveWeaponSectorView(arg_262_0, arg_262_1, arg_262_2)
	local var_262_0 = {
		weapon = arg_262_1,
		isActive = arg_262_2
	}

	arg_262_0:DispatchEvent(ys.Event.New(BattleUnitEvent.WEAPON_SECTOR, var_262_0))
end
