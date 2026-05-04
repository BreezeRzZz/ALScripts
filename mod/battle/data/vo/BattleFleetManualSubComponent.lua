ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr2 = ys.Battle.BattleAttr -- 与BattleAttr重复引用，未使用

local BattleFleetManualSubComponent = class("BattleFleetManualSubComponent")

ys.Battle.BattleFleetManualSubComponent = BattleFleetManualSubComponent
BattleFleetManualSubComponent.__name = "BattleFleetManualSubComponent"

--- @class BattleFleetManualSubComponent
--- @param self BattleFleetManualSubComponent
--- @param fleetVO BattleFleetVO 所属舰队VO
--- 构造函数：保存舰队引用，初始化组件并挂载方法到fleetVO
function BattleFleetManualSubComponent.Ctor(self, fleetVO)
	self._fleetVO = fleetVO

	self:init()
	self:attachFunction()
end

--- 将手动潜艇相关方法挂载到fleetVO上（通过委托模式扩展fleetVO的接口）
--- @param self BattleFleetManualSubComponent
function BattleFleetManualSubComponent.attachFunction(self)
	self._fleetVO.GetSubBench = BattleFleetManualSubComponent.GetSubBench
	self._fleetVO.GetSubFreeDiveVO = BattleFleetManualSubComponent.GetSubFreeDiveVO
	self._fleetVO.GetSubFreeFloatVO = BattleFleetManualSubComponent.GetSubFreeFloatVO
	self._fleetVO.GetSubBoostVO = BattleFleetManualSubComponent.GetSubBoostVO
	self._fleetVO.GetSubSpecialVO = BattleFleetManualSubComponent.GetSubSpecialVO
	self._fleetVO.GetSubShiftVO = BattleFleetManualSubComponent.GetSubShiftVO
	self._fleetVO.AddManualSubmarine = BattleFleetManualSubComponent.AddManualSubmarine
end

--- 每AI帧更新手动潜艇列表中各单位氧气
--- 被BattleFleetVO.UpdateAutoComponent调用
--- @param self BattleFleetManualSubComponent
--- @param timeStamp number 当前战斗时间
function BattleFleetManualSubComponent.UpdateAutoComponent(self, timeStamp)
	for _, manualSubUnit in ipairs(self._manualSubList) do
		manualSubUnit:UpdateOxygen(timeStamp)
	end
end

--- 更新手动武器VO（下潜/上浮/冲刺/切换的冷却计时）
--- @param self BattleFleetManualSubComponent
--- @param timeStamp number 当前战斗时间
function BattleFleetManualSubComponent.UpdateManualWeaponVO(self, timeStamp)
	self._submarineDiveVO:Update(timeStamp)
	self._submarineFloatVO:Update(timeStamp)
	self._submarineBoostVO:Update(timeStamp)
	self._submarineShiftVO:Update(timeStamp)
end

--- 从舰队中移除玩家单位：从subList和manualSubList中删除
--- @param self BattleFleetManualSubComponent
--- @param unit BattleUnit 要移除的单位
function BattleFleetManualSubComponent.RemovePlayerUnit(self, unit)
	for index, subUnit in ipairs(self._subList, i) do
		if subUnit == unit then
			table.remove(self._subList, index)

			break
		end
	end

	for index2, manualSubUnit in ipairs(self._manualSubList) do
		if manualSubUnit == unit then
			table.remove(self._manualSubList, index2)

			break
		end
	end

	if not self._manualSubUnit then
		self:refreshFleetFormation(indexList)
	end
end

--- 添加手动潜艇单位到舰队
--- 被BattleFleetVO.AddManualSubmarine委托
--- @param self BattleFleetManualSubComponent
--- @param subUnit BattleUnit 潜艇单位
function BattleFleetManualSubComponent.AddManualSubmarine(self, subUnit)
	self._unitList[#self._unitList + 1] = subUnit
	self._manualSubList[#self._manualSubList + 1] = subUnit
	self._manualSubBench[#self._manualSubBench + 1] = subUnit
	self._maxCount = self._maxCount + 1

	subUnit:InitOxygen()
	subUnit:SetFleetVO(self)
	subUnit:SetMotion(self._motionVO)
	subUnit:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.onUnitUpdateHP)
end

--- 获取手动潜艇替补席列表
--- @param self BattleFleetManualSubComponent
--- @return table 替补席列表
function BattleFleetManualSubComponent.GetSubBench(self)
	return self._manualSubBench
end

--- 获取自由下潜功能VO
--- @param self BattleFleetManualSubComponent
--- @return BattleSubmarineFuncVO
function BattleFleetManualSubComponent.GetSubFreeDiveVO(self)
	return self._manualSubComponent._submarineDiveVO
end

--- 获取自由上浮功能VO
--- @param self BattleFleetManualSubComponent
--- @return BattleSubmarineFuncVO
function BattleFleetManualSubComponent.GetSubFreeFloatVO(self)
	return self._manualSubComponent._submarineFloatVO
end

--- 获取冲刺功能VO
--- @param self BattleFleetManualSubComponent
--- @return BattleSubmarineFuncVO
function BattleFleetManualSubComponent.GetSubBoostVO(self)
	return self._manualSubComponent._submarineBoostVO
end

--- 获取特殊技能VO
--- @param self BattleFleetManualSubComponent
--- @return BattleSubmarineAidVO
function BattleFleetManualSubComponent.GetSubSpecialVO(self)
	return self._manualSubComponent._submarineSpecialVO
end

--- 获取切换功能VO
--- @param self BattleFleetManualSubComponent
--- @return BattleSubmarineFuncVO
function BattleFleetManualSubComponent.GetSubShiftVO(self)
	return self._manualSubComponent._submarineShiftVO
end

--- 初始化组件：创建各潜艇功能VO（下潜/上浮/冲刺/切换）并初始化列表
--- @param self BattleFleetManualSubComponent
function BattleFleetManualSubComponent.init(self)
	-- 创建下潜、上浮功能VO并加入潜艇VO列表
	self._submarineDiveVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.DIVE_CD)
	self._submarineFloatVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.FLOAT_CD)
	self._submarineVOList = {
		self._submarineDiveVO,
		self._submarineFloatVO
	}
	-- 创建冲刺、切换功能VO
	self._submarineBoostVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.BOOST_CD)
	self._submarineShiftVO = ys.Battle.BattleSubmarineFuncVO.New(BattleConfig.SR_CONFIG.SHIFT_CD)
	-- 创建特殊技能VO（初始1次可用）
	self._submarineSpecialVO = ys.Battle.BattleSubmarineAidVO.New()

	self._submarineSpecialVO:SetCount(1)
	self._submarineSpecialVO:SetTotal(1)

	self._manualSubList = {}
	self._manualSubBench = {}
	self._unitList = {}
	self._maxCount = 0
end

--- 设置潜艇单位数据列表
--- @param self BattleFleetManualSubComponent
--- @param subUnitDataList table 潜艇数据列表
function BattleFleetManualSubComponent.SetSubUnitData(self, subUnitDataList)
	self._subUntiDataList = subUnitDataList
end

--- 获取潜艇单位数据列表
--- @param self BattleFleetManualSubComponent
--- @return table 潜艇数据列表
function BattleFleetManualSubComponent.GetSubUnitData(self)
	return self._subUntiDataList
end

--- 获取潜艇单位列表
--- @param self BattleFleetManualSubComponent
--- @return table 潜艇列表
function BattleFleetManualSubComponent.GetSubList(self)
	return self._subList
end

--- 切换手动潜艇：将当前上场潜艇放入替补席，从替补席取出下一个上场
--- @param self BattleFleetManualSubComponent
function BattleFleetManualSubComponent.ShiftManualSub(self)
	-- 保存用于定位新上场潜艇的参考位置
	local lastPos

	if self._manualSubUnit then
		-- 移除当前潜艇的所有鱼雷武器
		local torpedoList = self._manualSubUnit:GetTorpedoList()

		for _, torpedo in ipairs(torpedoList) do
			if torpedo:IsAttacking() then
				self:CancelTorpedo()
			end

			self._torpedoWeaponVO:RemoveWeapon(torpedo)
		end

		-- 若存活则放回替补席
		if self._manualSubUnit:IsAlive() then
			table.insert(self._manualSubBench, self._manualSubUnit)
		end

		lastPos = self._motionVO:GetPos():Clone()
	else
		lastPos = self._manualSubList[1]:GetPosition():Clone()
	end

	-- 从替补席取出第一个作为新的手动潜艇
	self._manualSubUnit = table.remove(self._manualSubBench, 1)
	self._scoutList[1] = self._manualSubUnit

	-- 构建indexList用于刷新阵型：先收集替补席单位在unitList中的位置
	local indexList = {}

	for _, benchUnit in ipairs(self._manualSubBench) do
		for unitIndex, unit in ipairs(self._unitList) do
			if unit == benchUnit then
				table.insert(indexList, unitIndex)

				break
			end
		end
	end

	-- 将新上场单位的位置插入到indexList最前面
	for unitIndex2, unit2 in ipairs(self._unitList) do
		if unit2 == self._manualSubUnit then
			table.insert(indexList, 1, unitIndex2)

			break
		end
	end

	-- 刷新阵型并设置新单位状态
	self:refreshFleetFormation(indexList)
	self._manualSubUnit:SetMainUnitStatic(false)
	self._manualSubUnit:SetPosition(lastPos)
	self:UpdateMotion()
	-- 默认特殊技能不可用，后续检查buff
	self._submarineSpecialVO:SetUseable(false)

	-- 检查新上场单位是否有潜艇特殊技能buff
	local buffList = self._manualSubUnit:GetBuffList()

	for _, buff in pairs(buffList) do
		if buff:IsSubmarineSpecial() then
			self._submarineSpecialVO:SetCount(1)
			self._submarineSpecialVO:SetUseable(true)

			break
		end
	end

	-- 切换到自由下潜状态并重置鱼雷武器
	self:ChangeSubmarineState(ys.Battle.OxyState.STATE_FREE_DIVE)
	self._torpedoWeaponVO:Reset()

	-- 重新添加鱼雷武器：先添加非过热状态，再添加过热状态
	local torpedoList2 = self._manualSubUnit:GetTorpedoList()

	for _, torpedo2 in ipairs(torpedoList2) do
		if torpedo2:GetCurrentState() ~= torpedo2.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(torpedo2)
		end
	end

	for _, torpedo3 in ipairs(torpedoList2) do
		if torpedo3:GetCurrentState() == torpedo3.STATE_OVER_HEAT then
			self._torpedoWeaponVO:AppendWeapon(torpedo3)
		end
	end

	-- 根据氧气最大值设置下潜/上浮是否可用
	if BattleAttr.GetCurrent(self._manualSubUnit, "oxyMax") <= 0 then
		self._submarineDiveVO:SetActive(false)
		self._submarineFloatVO:SetActive(false)
	else
		self._submarineDiveVO:SetActive(true)
		self._submarineFloatVO:SetActive(true)
	end

	-- 替补席中的潜艇移到对应位置，设为静止/自由替补状态
	for index3, benchUnit2 in ipairs(self._manualSubBench) do
		benchUnit2:SetPosition(BattleConfig.SUB_BENCH_POS[index3])
		benchUnit2:SetMainUnitStatic(true)
		benchUnit2:ChangeOxygenState(ys.Battle.OxyState.STATE_FREE_BENCH)
	end

	self._submarineShiftVO:ResetCurrent()

	if #self._manualSubBench == 0 then
		self._submarineShiftVO:SetActive(false)
	end
end

--- 切换潜艇当前氧气状态（下潜/上浮）
--- @param self BattleFleetManualSubComponent
--- @param state number 目标氧气状态
--- @param resetCD boolean 是否重置相关冷却
function BattleFleetManualSubComponent.ChangeSubmarineState(self, state, resetCD)
	if not self._manualSubUnit then
		return
	end

	self._manualSubUnit:ChangeOxygenState(state)

	if resetCD then
		-- 重置所有潜艇VO的充能
		for _, vo in ipairs(self._submarineVOList) do
			vo:ResetCurrent()
		end

		-- 计算切换VO剩余冷却时间
		local remainingTime = self._submarineShiftVO:GetMax() - self._submarineShiftVO:GetCurrent()

		-- 如果切换VO处于过载且剩余时间超过下潜CD则不做处理，否则重置
		if self._submarineShiftVO:IsOverLoad() and remainingTime > BattleConfig.SR_CONFIG.DIVE_CD then
			-- block empty
		else
			self._submarineShiftVO:SetMax(BattleConfig.SR_CONFIG.DIVE_CD)
			self._submarineShiftVO:ResetCurrent()
		end
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.MANUAL_SUBMARINE_SHIFT, {
		state = state
	}))
end

--- 潜艇冲刺：沿右方向以配置的加速度和持续时间推进
--- @param self BattleFleetManualSubComponent
function BattleFleetManualSubComponent.SubmarinBoost(self)
	self._manualSubUnit:Boost(Vector3.right, BattleConfig.SR_CONFIG.BOOST_SPEED, BattleConfig.SR_CONFIG.BOOST_DECAY, BattleConfig.SR_CONFIG.BOOST_DURATION, BattleConfig.SR_CONFIG.BOOST_DECAY_STAMP)
	self._submarineBoostVO:ResetCurrent()
end

--- 释放潜艇特殊技能
--- @param self BattleFleetManualSubComponent
function BattleFleetManualSubComponent.UnleashSubmarineSpecial(self)
	if self:GetWeaponBlock() then
		return
	end

	self._submarineSpecialVO:Cast()
	self._manualSubUnit:TriggerBuff(BattleConst.BuffEffectType.ON_SUBMARINE_FREE_SPECIAL)
end
