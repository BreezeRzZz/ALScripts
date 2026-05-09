ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattlePlayerWeaponVO = class("BattlePlayerWeaponVO")
ys.Battle.BattlePlayerWeaponVO.__name = "BattlePlayerWeaponVO"

local BattlePlayerWeaponVO = ys.Battle.BattlePlayerWeaponVO

--- @class BattlePlayerWeaponVO
--- @field _GCD number 全局冷却时间(GCD)
--- @field _weaponList table 武器列表
--- @field _readyList table 就绪武器列表
--- @field _overHeatList table 过热武器列表
--- @field _chargingList table 冷却中武器列表
--- @field _current number 当前冷却进度
--- @field _max number 最大冷却值
--- @field _count number 就绪武器数量
--- @field _total number 武器总数
--- @field _focus boolean 是否正在聚焦
--- @field _focusTimer any 聚焦定时器
--- @field _isOverLoad boolean 是否处于过载状态
--- @field _reloadStartTime number 装填开始时间
--- @field _jammingStarTime number 干扰开始时间

--- 构造函数
--- @param GCD number 全局冷却时间
function BattlePlayerWeaponVO.Ctor(self, GCD)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._GCD = GCD

	self:Reset()
end

--- 重置所有状态
function BattlePlayerWeaponVO.Reset(self)
	self._isOverLoad = false
	self._current = self._GCD
	self._max = self._GCD
	self._count = 0
	self._total = 0
	self._weaponList = {}
	self._overHeatList = {}
	self._readyList = {}
	self._chargingList = {}
end

--- 每帧更新冷却进度和过载状态
--- @param timeStamp number 当前时间戳
function BattlePlayerWeaponVO.Update(self, timeStamp)
	if self._current < self._max then
		local elapsed = timeStamp - self._reloadStartTime

		if elapsed >= self._max then
			self._current = self._max
			self._reloadStartTime = nil

			for _, weapon in ipairs(self._chargingList) do
				weapon:UpdateReload()
			end

			self:DispatchOverLoadChange()
		else
			self._current = elapsed
		end
	end
end

--- @param character BattleUnit 聚焦目标角色
--- @param afterFocusFunc function 聚焦完成后的回调
--- @return nil
--- 将镜头聚焦到指定角色的相关函数
--- - FocusCharacter: 镜头聚焦
--- - ZoomCamara: 镜头缩放
--- - BulletTime: 子弹时间
function BattlePlayerWeaponVO.PlayFocus(self, character, afterFocusFunc)
	ys.Battle.BattleCameraUtil.GetInstance():FocusCharacter(character, BattleConfig.CAST_CAM_ZOOM_IN_DURATION)
	ys.Battle.BattleCameraUtil.GetInstance():ZoomCamara(nil, BattleConfig.CAST_CAM_ZOOM_SIZE, BattleConfig.CAST_CAM_ZOOM_IN_DURATION, true)
	ys.Battle.BattleCameraUtil.GetInstance():BulletTime(BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER, BattleConfig.FOCUS_MAP_RATE, character)

	self._focus = true

	if self._focusTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._focusTimer)
	end

	local function onFocusCompleteFunc()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._focusTimer)

		self._focusTimer = nil

		afterFocusFunc()
	end

	self._focusTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", -1, BattleConfig.CAST_CAM_ZOOM_IN_DURATION, onFocusCompleteFunc, true)
end

--- 切入立绘
--- @param character BattleUnit 角色
--- @param duration number 切入持续时间
function BattlePlayerWeaponVO.PlayCutIn(self, character, duration)
	ys.Battle.BattleCameraUtil.GetInstance():CutInPainting(character, duration)
end

function BattlePlayerWeaponVO.ResetFocus(self)
	return
end

--- 取消聚焦
function BattlePlayerWeaponVO.CancelFocus(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._focusTimer)

	self._focusTimer = nil
end

--- 获取武器列表
--- @return table
function BattlePlayerWeaponVO.GetWeaponList(self)
	return self._weaponList
end

--- 追加武器到列表
--- 新追加的武器会直接进入就绪状态，并更新冷却条
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.AppendWeapon(self, weapon)
	self._weaponList[#self._weaponList + 1] = weapon

	if weapon:GetCurrentState() == weapon.STATE_READY then
		self._count = self._count + 1
	end

	self._total = self._total + 1

	self:DispatchTotalChange()

	self._current = self._max

	self:DispatchOverLoadChange()

	self._readyList[#self._readyList + 1] = weapon
end

--- 追加被冻结(freeze)的武器（即之前被移除后又恢复的武器）
--- 保持武器原有的状态并更新冷却条
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.AppendFreezeWeapon(self, weapon)
	self._weaponList[#self._weaponList + 1] = weapon
	self._total = self._total + 1

	self:DispatchTotalChange()

	if weapon:GetCurrentState() == weapon.STATE_READY then
		self._count = self._count + 1

		table.insert(self._readyList, weapon)
	elseif weapon:GetCDStartTimeStamp() then
		table.insert(self._chargingList, weapon)
	else
		table.insert(self._overHeatList, weapon)
	end

	self:resetCurrent()
	self:refreshCD()
	self:RefreshReloadingBar()
	self:DispatchOverLoadChange()
end

--- 移除武器
--- @param weapon BattleBaseWeaponUnit
--- @return number 被移除武器在weaponList中的索引
function BattlePlayerWeaponVO.RemoveWeapon(self, weapon)
	local index = self.deleteElementFromArray(weapon, self._weaponList)

	self._total = self._total - 1

	if weapon:GetCurrentState() ~= weapon.STATE_OVER_HEAT then
		self._count = self._count - 1

		if self._count < 0 then
			self._count = 0
		end

		local readyIndex = self.deleteElementFromArray(weapon, self._readyList)

		self:DispatchOverLoadChange()
		self:DispatchTotalChange(readyIndex)
	else
		if self.deleteElementFromArray(weapon, self._chargingList) == -1 then
			self.deleteElementFromArray(weapon, self._overHeatList)
		end

		self:DispatchOverLoadChange()
		self:DispatchTotalChange()
	end

	self:refreshCD()

	return index
end

--- 刷新冷却时间
--- 根据readyList和chargingList的状态重新计算_max和_current
function BattlePlayerWeaponVO.refreshCD(self)
	local readyCount = #self._readyList
	local chargingCount = #self._chargingList

	if readyCount ~= 0 then
		self._current = 1
		self._max = 1
	elseif readyCount + chargingCount == 0 then
		self._current = 1
		self._max = 1
	else
		local timeRemaining = self:GetNextTimeStamp() - pg.TimeMgr.GetInstance():GetCombatTime()

		if self._current >= self._GCD then
			self._max = timeRemaining
		else
			local previousMax = math.max(self._max, self._GCD)

			self._max = math.max(previousMax - self._current, timeRemaining)
		end

		self:resetCurrent()
	end
end

--- 刷新装填进度条
--- 当reloadStartTime变更为jammingStarTime时，重新计算_max和_current以保持进度比例
function BattlePlayerWeaponVO.RefreshReloadingBar(self)
	if not self._reloadStartTime or #self._readyList ~= 0 or self._max == self._GCD then
		return
	end

	local nextTimeStamp = self:GetNextTimeStamp()
	local ratio = self._current / self._max

	self._max = nextTimeStamp - self._reloadStartTime
	self._current = ratio * self._max
end

--- 重置当前冷却时间
--- 将_current设为0，_reloadStartTime设为当前时间或干扰开始时间
function BattlePlayerWeaponVO.resetCurrent(self)
	self._current = 0
	self._reloadStartTime = self._jammingStarTime or pg.TimeMgr.GetInstance():GetCombatTime()
end

--- 设置最大冷却值
--- @param max number
function BattlePlayerWeaponVO.SetMax(self, max)
	self._max = max
end

--- 获取最大冷却值
--- @return number
function BattlePlayerWeaponVO.GetMax(self)
	return self._max
end

--- 获取当前冷却进度
--- @return number
function BattlePlayerWeaponVO.GetCurrent(self)
	return self._current
end

--- 是否处于过载状态（冷却未完成 或 无可使用武器）
--- @return boolean
function BattlePlayerWeaponVO.IsOverLoad(self)
	return self._current < self._max or self._count < 1
end

--- 设置武器总数
--- @param total number
function BattlePlayerWeaponVO.SetTotal(self, total)
	self._total = total
end

--- 获取武器总数
--- @return number
function BattlePlayerWeaponVO.GetTotal(self)
	return self._total
end

--- 设置就绪武器数量
--- @param count number
function BattlePlayerWeaponVO.SetCount(self, count)
	self._count = count
end

--- 获取就绪武器数量
--- @return number
function BattlePlayerWeaponVO.GetCount(self)
	return self._count
end

--- 获取下一个武器完成冷却的时间戳
--- 遍历chargingList中找到最早完成冷却的武器
--- @return number 时间戳
--- @return BattleBaseWeaponUnit 最早完成冷却的武器
function BattlePlayerWeaponVO.GetNextTimeStamp(self)
	local earliestWeapon
	local earliestTimeStamp

	if #self._chargingList > 0 then
		earliestWeapon = self._chargingList[1]
		earliestTimeStamp = earliestWeapon:GetReloadFinishTimeStamp()

		for _, weapon in ipairs(self._chargingList) do
			local finishTimeStamp = weapon:GetReloadFinishTimeStamp()

			if finishTimeStamp < earliestTimeStamp then
				earliestWeapon = weapon
				earliestTimeStamp = finishTimeStamp
			end
		end
	end

	return earliestTimeStamp, earliestWeapon
end

--- 获取当前就绪的第一个武器
--- @return BattleBaseWeaponUnit|nil
function BattlePlayerWeaponVO.GetCurrentWeapon(self)
	return self._readyList[1]
end

--- 获取队列头部武器（优先级：就绪 > 冷却中 > 过热）
--- @return BattleBaseWeaponUnit|nil
function BattlePlayerWeaponVO.GetHeadWeapon(self)
	return self:GetCurrentWeapon() or self._chargingList[1] or self._overHeatList[1]
end

--- 获取当前武器图标索引
--- @return number 始终返回0（默认图标）
function BattlePlayerWeaponVO.GetCurrentWeaponIconIndex(self)
	return 0
end

--- 武器完成冷却，从chargingList移到readyList
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.Plus(self, weapon)
	local oldCount = self._count

	self._count = self._count + 1

	self:DispatchCountChange()
	self.deleteElementFromArray(weapon, self._chargingList)

	self._readyList[#self._readyList + 1] = weapon

	local weaponCountPlusEvent = ys.Event.New(ys.Battle.BattleEvent.WEAPON_COUNT_PLUS)

	self:DispatchEvent(weaponCountPlusEvent)
	self:DispatchOverLoadChange(oldCount)
end

--- 武器发射后扣减就绪数量
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.Deduct(self, weapon)
	self:readyToOverheat(weapon)

	if #self._readyList ~= 0 then
		self._max = self._GCD

		self:resetCurrent()
	elseif #self._chargingList ~= 0 then
		local nextTimeStamp = self:GetNextTimeStamp()

		self._max = math.max(self._GCD, nextTimeStamp - pg.TimeMgr.GetInstance():GetCombatTime())

		self:resetCurrent()
	elseif weapon:GetType() == ys.Battle.BattleConst.EquipmentType.DISPOSABLE_TORPEDO then
		-- 一次性鱼雷发射后不需要更新冷却条
		-- block empty
	else
		self._current = 0
	end

	self:DispatchOverLoadChange(nil, true)
end

--- 初始扣减（进入战斗时直接扣减）
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.InitialDeduct(self, weapon)
	self:readyToOverheat(weapon)
	self:DispatchOverLoadChange()
end

--- 武器开始充能/装填，从overHeatList移到chargingList
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.Charge(self, weapon)
	self.deleteElementFromArray(weapon, self._overHeatList)

	self._chargingList[#self._chargingList + 1] = weapon

	-- 按完成冷却时间排序，最早完成的在前
	table.sort(self._chargingList, function(weapon1, weapon2)
		return weapon1:GetReloadFinishTimeStamp() < weapon2:GetReloadFinishTimeStamp()
	end)

	if #self._readyList == 0 then
		local nextTimeStamp = self:GetNextTimeStamp()

		self._max = math.max(self._GCD, nextTimeStamp - pg.TimeMgr.GetInstance():GetCombatTime())

		self:resetCurrent()
	end

	self:DispatchCountChange()
end

--- 装填加速
--- @param weapon BattleBaseWeaponUnit 要加速的武器
--- @param boostRate number 加速倍率
function BattlePlayerWeaponVO.ReloadBoost(self, weapon, boostRate)
	local oldTimeStamp, oldWeapon = self:GetNextTimeStamp()

	weapon:ReloadBoost(boostRate)

	local newTimeStamp, newWeapon = self:GetNextTimeStamp()

	if oldWeapon ~= weapon and newWeapon ~= weapon then
		-- 加速的武器不是下一个冷却完成的，无需更新
		-- block empty
	elseif oldWeapon == weapon and newWeapon == weapon then
		self:RefreshReloadingBar()
	elseif oldWeapon ~= newWeapon then
		self:RefreshReloadingBar()
	end
end

--- 立即完成冷却
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.InstantCoolDown(self, weapon)
	self.deleteElementFromArray(weapon, self._overHeatList)

	if self._current >= self._GCD then
		self._current = self._max
		self._reloadStartTime = nil
	else
		self._max = self._GCD - self._current

		self:resetCurrent()
	end

	self:Plus(weapon)
end

--- 分发按钮闪烁事件
--- @param callback function 可选的回调
function BattlePlayerWeaponVO.DispatchBlink(self, callback)
	local blinkData = {
		value = callback
	}
	local blinkEvent = ys.Event.New(ys.Battle.BattleEvent.WEAPON_BUTTON_BLINK, blinkData)

	self:DispatchEvent(blinkEvent)
end

--- 分发武器总数变更事件
--- @param index number 变更涉及的武器索引
function BattlePlayerWeaponVO.DispatchTotalChange(self, index)
	local totalChangeEvent = ys.Event.New(ys.Battle.BattleEvent.WEAPON_TOTAL_CHANGE, {
		index = index
	})

	self:DispatchEvent(totalChangeEvent)
end

--- 分发过载状态变更事件
--- @param preCast number 发射前就绪数量
--- @param postCast boolean 是否为发射后（post-cast）
function BattlePlayerWeaponVO.DispatchOverLoadChange(self, preCast, postCast)
	local overLoadChangeEvent = ys.Event.New(ys.Battle.BattleEvent.OVER_LOAD_CHANGE, {
		preCast = preCast,
		postCast = postCast
	})

	self:DispatchEvent(overLoadChangeEvent)
end

--- 分发就绪数量变更事件
function BattlePlayerWeaponVO.DispatchCountChange(self)
	local countChangeEvent = ys.Event.New(ys.Battle.BattleEvent.COUNT_CHANGE)

	self:DispatchEvent(countChangeEvent)
end

--- 分发潜艇图标初始化事件
function BattlePlayerWeaponVO.DispatchInitSubIcon(self)
	local initSubIconEvent = ys.Event.New(ys.Battle.BattleEvent.INIT_SUB_ICON)

	self:DispatchEvent(initSubIconEvent)
end

--- 开始干扰（如敌方干扰效果），记录干扰开始时间
function BattlePlayerWeaponVO.StartJamming(self)
	self._jammingStarTime = pg.TimeMgr.GetInstance():GetCombatTime()

	for _, weapon in ipairs(self._chargingList) do
		weapon:StartJamming()
	end
end

--- 干扰消除，恢复正常的冷却计时
function BattlePlayerWeaponVO.JammingEliminate(self)
	for _, weapon in ipairs(self._chargingList) do
		weapon:JammingEliminate()
	end

	if self._reloadStartTime then
		local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

		if #self._readyList ~= 0 then
			self._max = self._GCD
		else
			self._max = self:GetNextTimeStamp() - currentTime + self._current
		end

		self._reloadStartTime = self._reloadStartTime + (currentTime - self._jammingStarTime)
	end

	self._jammingStarTime = nil
end

--- 销毁
function BattlePlayerWeaponVO.Dispose(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._focusTimer)

	self._focusTimer = nil

	ys.EventDispatcher.DetachEventDispatcher(self)
end

--- 将就绪武器移入过热列表
--- @param weapon BattleBaseWeaponUnit
function BattlePlayerWeaponVO.readyToOverheat(self, weapon)
	self.deleteElementFromArray(weapon, self._readyList)

	self._overHeatList[#self._overHeatList + 1] = weapon
	self._count = self._count - 1

	if self._count < 0 then
		self._count = 0
	end

	self:DispatchCountChange()
end

--- 从数组中删除指定元素（不保留空洞，紧凑排列）
--- @param element any 要删除的元素
--- @param array table 目标数组
--- @return number 被删除元素的原索引，-1表示未找到
function BattlePlayerWeaponVO.deleteElementFromArray(self, element, array)
	local elementIndex

	for index, item in ipairs(array) do
		if element == item then
			elementIndex = index

			break
		end
	end

	if elementIndex == nil then
		return -1
	end

	for i = elementIndex, #array do
		if array[i + 1] ~= nil then
			array[i] = array[i + 1]
		else
			array[i] = nil
		end
	end

	return elementIndex
end
