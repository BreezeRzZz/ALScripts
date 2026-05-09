ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local UnitState = ys.Battle.UnitState
local BattleEnemyUnit = class("BattleEnemyUnit", ys.Battle.BattleUnit)

ys.Battle.BattleEnemyUnit = BattleEnemyUnit
BattleEnemyUnit.__name = "BattleEnemyUnit"

--- 构造函数：设置单位类型为敌人并获取关卡等级
--- @param uid number: 单位唯一ID
--- @param iff number: 阵营
function BattleEnemyUnit.Ctor(self, uid, iff)
	BattleEnemyUnit.super.Ctor(self, uid, iff)

	self._type = BattleConst.UnitType.ENEMY_UNIT
	self._level = self._battleProxy:GetDungeonLevel()
end

--- 销毁：清理瞄准偏差组件
function BattleEnemyUnit.Dispose(self)
	if self._aimBias then
		self._aimBias:Dispose()
	end

	BattleEnemyUnit.super.Dispose(self)
end

--- 设置边界（覆盖父类以设置武器边界）
--- @param top number: 上边界
--- @param bottom number: 下边界
--- @param left number: 左边界
--- @param right number: 右边界
--- @param weaponTop number: 武器上边界
--- @param weaponBottom number: 武器下边界
function BattleEnemyUnit.SetBound(self, top, bottom, left, right, weaponTop, weaponBottom)
	BattleEnemyUnit.super.SetBound(self, top, bottom, left, right, weaponTop, weaponBottom)

	self._weaponRightBound = weaponTop
	self._weaponLowerBound = weaponBottom
end

--- 更新动作状态：根据氧气状态和速度方向切换动画
function BattleEnemyUnit.UpdateAction(self)
	if self._oxyState and self._oxyState:GetCurrentDiveState() == BattleConst.OXY_STATE.DIVE then
		if self:GetSpeed().x > 0 then
			self._unitState:ChangeState(UnitState.STATE_DIVELEFT)
		else
			self._unitState:ChangeState(UnitState.STATE_DIVE)
		end
	elseif self:GetSpeed().x > 0 then
		self._unitState:ChangeState(UnitState.STATE_MOVELEFT)
	else
		self._unitState:ChangeState(UnitState.STATE_MOVE)
	end
end

--- 更新血量：父类逻辑基础上通知阶段切换器
--- @param dHP number: 血量变化值
--- @param extraInfo table: 额外信息
--- @param isAbsorb boolean: 是否吸收
--- @param isReflect boolean: 是否反射
--- @return number: 实际生效的血量变化值
function BattleEnemyUnit.UpdateHP(self, dHP, extraInfo, isAbsorb, isReflect)
	local dHPResult = BattleEnemyUnit.super.UpdateHP(self, dHP, extraInfo, isAbsorb, isReflect)

	if self._phaseSwitcher then
		self._phaseSwitcher:UpdateHP(self:GetHPRate())
	end

	return dHPResult
end

--- 设置主控单位
--- @param master BattleUnit: 主控单位
function BattleEnemyUnit.SetMaster(self, master)
	self._master = master
end

--- 获取主控单位
--- @return BattleUnit: 主控单位
function BattleEnemyUnit.GetMaster(self)
	return self._master
end

--- 设置模板数据
--- @param templateID number: 模板ID
--- @param extraInfo table: 额外信息（可覆盖模板字段）
function BattleEnemyUnit.SetTemplate(self, templateID, extraInfo)
	BattleEnemyUnit.super.SetTemplate(self, templateID)

	self._tmpData = BattleDataFunction.GetMonsterTmpDataFromID(self._tmpID)

	self:configWeaponQueueParallel()
	self:InitCldComponent()
	self:SetAttr()

	extraInfo = extraInfo or {}

	local entityExtraInfo = self:GetExtraInfo()

	for key, value in pairs(extraInfo) do
		entityExtraInfo[key] = value
	end

	self:setStandardLabelTag()
end

--- 设置所属团队VO
--- @param teamVO BattleTeamVO: 团队视图对象
function BattleEnemyUnit.SetTeamVO(self, teamVO)
	self._team = teamVO
end

--- 设置编队索引
--- @param formationIndex number: 编队索引
function BattleEnemyUnit.SetFormationIndex(self, formationIndex)
	self._formationIndex = formationIndex
end

--- 设置波次索引
--- @param waveIndex number: 波次索引
function BattleEnemyUnit.SetWaveIndex(self, waveIndex)
	self._waveIndex = waveIndex
end

--- 设置敌人属性
function BattleEnemyUnit.SetAttr(self)
	BattleAttr.SetEnemyAttr(self)
	BattleAttr.InitDOTAttr(self._attr, self._tmpData)
end

--- 获取模板数据
--- @return table: 模板数据
function BattleEnemyUnit.GetTemplate(self)
	return self._tmpData
end

--- 获取稀有度
--- @return number: 稀有度
function BattleEnemyUnit.GetRarity(self)
	return self._tmpData.rarity
end

--- 获取等级（优先使用覆盖等级）
--- @return number: 等级
function BattleEnemyUnit.GetLevel(self)
	return self._overrideLevel or self._level or 1
end

--- 获取所属团队
--- @return BattleTeamVO: 团队
function BattleEnemyUnit.GetTeam(self)
	return self._team
end

--- 获取波次索引
--- @return number: 波次索引
function BattleEnemyUnit.GetWaveIndex(self)
	return self._waveIndex
end

--- 是否显示血条
--- @return boolean: 非友方时显示
function BattleEnemyUnit.IsShowHPBar(self)
	return self._IFF ~= BattleConfig.FRIENDLY_CODE
end

--- 是否灵体单位
--- @return boolean, number: 是否灵体, 战斗单位类型
function BattleEnemyUnit.IsSpectre(self)
	local battleUnitType
	local battleUnitTypeAttrKey = ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY

	if self:GetAttr()[battleUnitTypeAttrKey] ~= nil then
		battleUnitType = self:GetAttrByName(battleUnitTypeAttrKey)
	else
		battleUnitType = self._tmpData.battle_unit_type
	end

	return battleUnitType <= BattleConfig.SPECTRE_UNIT_TYPE, battleUnitType
end

--- 初始化碰撞组件：设置舰船类型碰撞数据
function BattleEnemyUnit.InitCldComponent(self)
	BattleEnemyUnit.super.InitCldComponent(self)

	local cldData = {
		type = BattleConst.CldType.SHIP,
		IFF = self:GetIFF(),
		UID = self:GetUniqueID(),
		Mass = BattleConst.CldMass.L1,
		IsBoss = self._isBoss
	}

	self._cldComponent:SetCldData(cldData)

	if self:GetTemplate().friendly_cld ~= 0 then
		self._cldComponent:ActiveFriendlyCld()
	end
end

--- 配置气泡特效（从模板读取）
function BattleEnemyUnit.ConfigBubbleFX(self)
	self._bubbleFX = self._tmpData.bubble_fx[1]

	self._oxyState:SetBubbleTemplate(self._tmpData.bubble_fx[2], self._tmpData.bubble_fx[3])
end
