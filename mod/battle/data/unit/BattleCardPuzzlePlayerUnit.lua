ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConst = ys.Battle.BattleConst
local EquipmentType = BattleConst.EquipmentType
local BattleConfig = ys.Battle.BattleConfig
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent
local BattleAttr2 = ys.Battle.BattleAttr

ys.Battle.BattleCardPuzzlePlayerUnit = class("BattleCardPuzzlePlayerUnit", ys.Battle.BattlePlayerUnit)
ys.Battle.BattleCardPuzzlePlayerUnit.__name = "BattleCardPuzzlePlayerUnit"

local BattleCardPuzzlePlayerUnit = ys.Battle.BattleCardPuzzlePlayerUnit

--- @class BattleCardPuzzlePlayerUnit
--- @param uid number: 单位唯一ID
--- @param iff number: 阵营
--- @return nil
--- 构造函数
function BattleCardPuzzlePlayerUnit.Ctor(self, uid, iff)
	BattleCardPuzzlePlayerUnit.super.Ctor(self, uid, iff)
end

--- @class BattleCardPuzzlePlayerUnit
--- @param dHP number: 血量变化值
--- @param extraInfo table: 额外信息(isMiss/isCri/isHeal等)
--- @return number: 血量变化值
--- 卡牌解谜模式的UpdateHP：简化版的血量更新逻辑
function BattleCardPuzzlePlayerUnit.UpdateHP(self, dHP, extraInfo)
	if not self:IsAlive() then
		return
	end

	local isAliveBeforeUpdate = self:IsAlive()

	if not isAliveBeforeUpdate then
		return
	end

	local isMiss = extraInfo.isMiss
	local isCri = extraInfo.isCri
	local isHeal = extraInfo.isHeal
	local isShare = extraInfo.isShare
	local attr = extraInfo.attr
	local font = extraInfo.font
	local cldPos = extraInfo.cldPos
	local preShieldHP = dHP
	local currentHP = self:GetCurrentHP()

	if not isHeal then
		-- 受到伤害的处理
		local damageInfo = {
			damage = -dHP,
			isShare = isShare,
			miss = isMiss,
			cri = isCri,
			damageSrc = extraInfo.srcID,
			damageAttr = attr
		}

		self:TriggerBuff(BattleConst.BuffEffectType.ON_TAKE_DAMAGE, damageInfo)

		if currentHP <= damageInfo.damage then
			self:TriggerBuff(BattleConst.BuffEffectType.ON_BEFORE_FATAL_DAMAGE, {})
		end

		dHP = -damageInfo.damage

		if BattleAttr2.IsInvincible(self) then
			return 0
		end
	else
		-- 治疗的处理
		local damageInfo = {
			damage = dHP,
			isHeal = isHeal
		}

		self:TriggerBuff(BattleConst.BuffEffectType.ON_TAKE_HEALING, damageInfo)

		isHeal = damageInfo.isHeal
		dHP = damageInfo.damage
	end

	-- 计算实际生效的血量变化值
	local validDHP = math.min(self:GetMaxHP(), math.max(0, currentHP + dHP)) - currentHP
	local updateHPArgs = {
		preShieldHP = preShieldHP,
		dHP = dHP,
		validDHP = validDHP,
		isMiss = isMiss,
		isCri = isCri,
		isHeal = isHeal,
		font = font
	}

	-- 调整碰撞位置到碰撞盒范围内
	if cldPos and not cldPos:EqualZero() then
		local position = self:GetPosition()
		local boxSizeX = self:GetBoxSize().x
		local cldBoxLeft = position.x - boxSizeX
		local cldBoxRight = position.x + boxSizeX
		local actualCldPos = cldPos:Clone()

		actualCldPos.x = Mathf.Clamp(actualCldPos.x, cldBoxLeft, cldBoxRight)
		updateHPArgs.posOffset = position - actualCldPos
	end

	self:UpdateHPAction(updateHPArgs)

	if not self:IsAlive() and isAliveBeforeUpdate then
		self:SetDeathReason(extraInfo.damageReason)
		self:DeadAction()
	end

	if self:IsAlive() then
		self:TriggerBuff(BattleConst.BuffEffectType.ON_HP_RATIO_UPDATE, {
			dHP = dHP,
			unit = self
		})
	end

	return dHP
end

--- @class BattleCardPuzzlePlayerUnit
--- @param args table: 血量更新参数
--- @return nil
--- 发送卡牌解谜模式的UPDATE_COMMON_HP事件和父类UPDATE_HP事件
function BattleCardPuzzlePlayerUnit.UpdateHPAction(self, args)
	self:DispatchEvent(ys.Event.New(BattleCardPuzzleEvent.UPDATE_COMMON_HP, args))
	BattleCardPuzzlePlayerUnit.super.UpdateHPAction(self, args)
end

--- @class BattleCardPuzzlePlayerUnit
--- @param templateID number: 模板ID
--- @param extraAttr table: 额外属性
--- @param extraInfo table: 额外信息
--- @return nil
--- 设置模板：从PuzzleShipDataTemplate获取模板数据
function BattleCardPuzzlePlayerUnit.SetTemplate(self, templateID, extraAttr, extraInfo)
	self._tmpID = templateID
	self._tmpData = Clone(BattleDataFunction.GetPuzzleShipDataTemplate(self._tmpID))
	self._tmpData.scale = 100
	self._tmpData.parallel_max = {
		1,
		1,
		1
	}

	self:configWeaponQueueParallel()
	self:overrideSkin(self._tmpData.skin_id, true)
	self:InitCldComponent()
	self:setAttrFromOutBattle(extraAttr, extraInfo)

	self._personality = BattleDataFunction.GetShipPersonality(2)

	BattleFormulas.SetCurrent(self, "srcShipType", self._tmpData.type)

	for _, tag in ipairs(self._tmpData.tag) do
		self:AddLabelTag(tag)
	end
end

--- @class BattleCardPuzzlePlayerUnit
--- @return table: 模板数据
--- 获取模板数据
function BattleCardPuzzlePlayerUnit.GetTemplate(self)
	return self._tmpData
end

--- @class BattleCardPuzzlePlayerUnit
--- @return nil
--- 初始化当前HP(卡牌模式不执行)
function BattleCardPuzzlePlayerUnit.InitCurrentHP(self)
	return
end

--- @class BattleCardPuzzlePlayerUnit
--- @param initHPRate number: 初始血量比例
--- @return nil
--- 初始化舰队当前HP
function BattleCardPuzzlePlayerUnit.InitFleetCurrentHP(self, initHPRate)
	self:TriggerBuff(BattleConst.BuffEffectType.ON_HP_RATIO_UPDATE, {})
end

--- @class BattleCardPuzzlePlayerUnit
--- @param hp number: 血量值
--- @return nil
--- 设置当前HP(卡牌模式不执行，由fleetCardPuzzleComponent管理)
function BattleCardPuzzlePlayerUnit.SetCurrentHP(self, hp)
	return
end

--- @class BattleCardPuzzlePlayerUnit
--- @return number: 从fleetCardPuzzleComponent获取的当前共享HP
--- 获取当前HP
function BattleCardPuzzlePlayerUnit.GetCurrentHP(self)
	return self._fleetCardPuzzleComponent:GetCurrentCommonHP()
end

--- @class BattleCardPuzzlePlayerUnit
--- @return number: 从fleetCardPuzzleComponent获取的最大共享HP
--- 获取最大HP
function BattleCardPuzzlePlayerUnit.GetMaxHP(self)
	return self._fleetCardPuzzleComponent:GetTotalCommonHP()
end

--- @class BattleCardPuzzlePlayerUnit
--- @return number, number: 当前HP, 最大HP
--- 获取HP对
function BattleCardPuzzlePlayerUnit.GetHP(self)
	return self:GetCurrentHP(), self:GetMaxHP()
end

--- @class BattleCardPuzzlePlayerUnit
--- @return number: HP比例
--- 获取HP比例
function BattleCardPuzzlePlayerUnit.GetHPRate(self)
	return self:GetCurrentHP() / self:GetMaxHP()
end

--- @class BattleCardPuzzlePlayerUnit
--- @param fleetVO BattleFleetVO: 舰队VO
--- @return nil
--- 设置FleetVO并获取卡牌解谜组件
function BattleCardPuzzlePlayerUnit.SetFleetVO(self, fleetVO)
	BattleCardPuzzlePlayerUnit.super.SetFleetVO(self, fleetVO)

	self._fleetCardPuzzleComponent = fleetVO:GetCardPuzzleComponent()
end

--- @class BattleCardPuzzlePlayerUnit
--- @return nil
--- 旗舰设定：warningValue设为1
function BattleCardPuzzlePlayerUnit.LeaderSetting(self)
	self._warningValue = 1
end

--- @class BattleCardPuzzlePlayerUnit
--- @param isMainStatic boolean: 是否仍是主舰队
--- @return nil
--- 设置为主舰队单位
function BattleCardPuzzlePlayerUnit.SetMainFleetUnit(self, isMainStatic)
	self._isMainFleetUnit = true

	self:SetMainUnitStatic(true)

	self._mainUnitWarningValue = 1
end

--- @class BattleCardPuzzlePlayerUnit
--- @return nil
--- 检查武器初始冷却(卡牌模式不执行)
function BattleCardPuzzlePlayerUnit.CheckWeaponInitial(self)
	return
end

--- @class BattleCardPuzzlePlayerUnit
--- @return nil
--- 设置武器：从default_equip列表读取武器配置并创建WeaponUnit
--- 注意：原代码中weaponType变量未定义，可能存在bug
function BattleCardPuzzlePlayerUnit.setWeapon(self)
	local defaultEquipList = self._tmpData.default_equip

	for _, equipID in ipairs(defaultEquipList) do
		if equipID ~= 0 then
			local weaponData = BattleDataFunction.GetWeaponDataFromID(equipID)

			for _, weaponID in ipairs(weaponData) do
				if weaponID ~= -1 then
					local weapon = ys.Battle.BattleDataFunction.CreateWeaponUnit(weaponID, self, nil, equipID)

					self._totalWeapon[#self._totalWeapon + 1] = weapon

					if weaponType == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
						-- block empty
					else
						assert(#weaponData < 2, "自动武器一组不允许配置多个")
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
end
