ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.WeaponQueue = class("WeaponQueue")
ys.Battle.WeaponQueue.__name = "WeaponQueue"

local WeaponQueue = ys.Battle.WeaponQueue

--- @class WeaponQueue
--- @return nil
--- WeaponQueue类的构造函数。
--- - totalWeapon: [number, BattleWeaponUnit]的table, 所有武器的列表
--- - queueList: [number, [number, BattleWeaponUnit]]的table，武器队列的列表，每个元素是一个队列，记录了在该队列中的武器
--- - GCDTimerList: [number, BattleTimer]的table，GCD计时器的列表，每个元素是一个BattleTimer。该队列的索引与queueList对应
function WeaponQueue.Ctor(self)
	self._totalWeapon = {}
	self._queueList = {}
	self._GCDTimerList = {}
end

--- @class WeaponQueue
--- @param torpedoMaxCount number
--- @param chargeMaxCount number 
--- @return nil
--- 配置手动武器队列，包括鱼雷队列和跨射队列。
function WeaponQueue.ConfigParallel(self, torpedoMaxCount, chargeMaxCount)
	self._torpedoQueue = ys.Battle.ManualWeaponQueue.New(chargeMaxCount)
	self._chargeQueue = ys.Battle.ManualWeaponQueue.New(torpedoMaxCount)
end

--- @class WeaponQueue
--- @return nil
--- 清理所有武器。
function WeaponQueue.ClearAllWeapon(self)
	for _, weapon in ipairs(self._totalWeapon) do
		weapon:Clear()
	end
end

--- @class WeaponQueue
--- @return nil
--- 释放所有武器资源。
--- - 包括两个手动武器队列
function WeaponQueue.Dispose(self)
	self._torpedoQueue:Clear()
	self._chargeQueue:Clear()

	for _, weapon in ipairs(self._totalWeapon) do
		weapon:Dispose()
	end

	self._torpedoQueue = nil
	self._chargeQueue = nil
end

--- @class WeaponQueue
--- @param weapon BattleWeaponUnit
--- @return nil
--- 将武器添加到对应的武器队列中，并记录到totalWeapon表。
function WeaponQueue.AppendWeapon(self, weapon)
	local queueIndex = weapon:GetTemplateData().queue
	local queue = self:GetQueueByIndex(queueIndex)

	queue[#queue + 1] = weapon
	self._totalWeapon[#self._totalWeapon + 1] = weapon
end

--- @class WeaponQueue
--- @param weapon BattleWeaponUnit 
--- @return nil
--- 将武器从对应的武器队列中和totalWeapon表中移除。
function WeaponQueue.RemoveWeapon(self, weapon)
	local queueIndex = weapon:GetTemplateData().queue
	local queue = self:GetQueueByIndex(queueIndex)

	local i = 1
	local queueLength = #queue

	while i <= queueLength do
		if queue[i] == weapon then
			table.remove(queue, i)

			break
		end

		i = i + 1
	end

	local j = 1
	local totalWeaponNum = #self._totalWeapon

	while j <= totalWeaponNum do
		if self._totalWeapon[j] == weapon then
			table.remove(self._totalWeapon, j)

			break
		end

		j = j + 1
	end
end

--- @class WeaponQueue
--- @param weapon BattleWeaponUnit 
--- @return nil
--- 添加手动鱼雷武器到手动鱼雷队列中。
function WeaponQueue.AppendManualTorpedo(self, weapon)
	self:AppendWeapon(weapon)
	self._torpedoQueue:AppendWeapon(weapon)
end

--- @class WeaponQueue
--- @param weapon BattleWeaponUnit 
--- @return nil
--- 添加手动跨射武器到手动跨射队列中。
function WeaponQueue.AppendChargeWeapon(self, weapon)
	self:AppendWeapon(weapon)
	self._chargeQueue:AppendWeapon(weapon)
end

--- @class WeaponQueue
--- @param weapon BattleWeaponUnit 
--- @return nil
--- 从手动鱼雷队列中移除手动鱼雷武器。
function WeaponQueue.RemoveManualTorpedo(self, weapon)
	self:RemoveWeapon(weapon)
	self._torpedoQueue:RemoveWeapon(weapon)
end

--- @class WeaponQueue
--- @param weapon BattleWeaponUnit 
--- @return nil
--- 从手动跨射队列中移除手动跨射武器。
function WeaponQueue.RemoveManualChargeWeapon(self, weapon)
	self:RemoveWeapon(weapon)
	self._chargeQueue:RemoveWeapon(weapon)
end

--- @class WeaponQueue
--- @param queueIndex number 
--- @param duration number
--- @return nil
--- 进入全局冷却时间（GCD）。
--- - 对queueIndex的队列添加一个持续时间为duration(单位:秒)的BattleTimer。
function WeaponQueue.QueueEnterGCD(self, queueIndex, duration)
	self:addGCDTimer(duration, queueIndex)
end

--- @class WeaponQueue
--- @return table<number, BattleWeaponUnit>
--- 获取所有武器列表。
function WeaponQueue.GetTotalWeaponUnit(self)
	return self._totalWeapon
end

--- @class WeaponQueue
--- @param queueIndex number
--- @return table<number, BattleWeaponUnit>
--- 获取指定队列索引的武器队列。
function WeaponQueue.GetQueueByIndex(self, queueIndex)
	if self._queueList[queueIndex] == nil then
		self._queueList[queueIndex] = {}
	end

	return self._queueList[queueIndex]
end

--- @class WeaponQueue
--- @return ManualWeaponQueue
--- 获取手动鱼雷武器队列。
function WeaponQueue.GetManualTorpedoQueue(self)
	return self._torpedoQueue
end

--- @class WeaponQueue
--- @return ManualWeaponQueue
--- 获取手动跨射武器队列。
function WeaponQueue.GetChargeWeaponQueue(self)
	return self._chargeQueue
end

--- @class WeaponQueue
--- @param timeStamp number
--- @return nil
--- WeaponQueue的Update函数。
--- - 遍历所有武器队列，如果该武器队列未处于攻击状态，则更新该队列中的武器。
function WeaponQueue.Update(self, timeStamp)
	for queueIndex, _ in pairs(self._queueList) do
		if self:isNotAttacking(queueIndex) then
			self:updateWeapon(queueIndex, timeStamp)
		end
	end
end

--- @class WeaponQueue
--- @return nil
--- 检查所有武器的初始冷却时间。
--- - 遍历所有武器，如果该武器不在手动鱼雷队列和手动跨射队列中，则调用其InitialCD方法。
--- - 调用手动鱼雷队列和手动跨射队列的CheckWeaponInitalCD方法。
function WeaponQueue.CheckWeaponInitalCD(self)
	for _, weapon in ipairs(self._totalWeapon) do
		if not self._torpedoQueue:Containers(weapon) and not self._chargeQueue:Containers(weapon) then
			weapon:InitialCD()
		end
	end

	self._torpedoQueue:CheckWeaponInitalCD()
	self._chargeQueue:CheckWeaponInitalCD()
end

--- @class WeaponQueue
--- @return nil
--- 刷新所有武器的重新装填需求(时间)。
--- - 遍历所有武器，如果该武器不在手动鱼雷队列和手动跨射队列中，则调用其FlushReloadRequire方法。
--- - 调用手动鱼雷队列和手动跨射队列的FlushWeaponReloadRequire方法。
function WeaponQueue.FlushWeaponReloadRequire(self)
	for _, weapon in ipairs(self._totalWeapon) do
		if not self._torpedoQueue:Containers(weapon) and not self._chargeQueue:Containers(weapon) then
			weapon:FlushReloadRequire()
		end
	end

	self._torpedoQueue:FlushWeaponReloadRequire()
	self._chargeQueue:FlushWeaponReloadRequire()
end

--- @class WeaponQueue
--- @param queueIndex number
--- @return boolean
--- 判断指定队列索引的武器队列是否处于攻击状态。
--- - 如果该队列正在GCD，返回false
--- - 如果该队列中存在正在攻击的武器，返回false
--- - 以上均不满足，返回true
function WeaponQueue.isNotAttacking(self, queueIndex)
	if self._GCDTimerList[queueIndex] ~= nil then
		return false
	end

	for _, weapon in ipairs(self._queueList[queueIndex]) do
		if weapon:IsAttacking() then
			return false
		end
	end

	return true
end

--- @class WeaponQueue
--- @param queueIndex number
--- @param timeStamp number
--- @return nil
--- 单个武器队列的Update函数。
--- 遍历该队列的武器：
--- - 如果队列中存在BEAM，且该BEAM处于攻击状态，则调用其Update方法并直接返回
--- - - 这是因为BEAM类武器会持续攻击，占用该队列的攻击时间。在BEAM持续期间，其他武器不会更新
--- - 对于一般武器：
--- - - 如果武器处于PRECAST/READY，或者OVERHEAT且需要重新装填，记flag1 = true
--- - - 若更新后武器处于PRECAST/READY状态，记flag2 = true
--- - 如果flag1为true且flag2为false(表示开火了?)，或者武器处于攻击状态，则跳出循环，不再考察后续武器
--- - - 说明这个武器占用了该队列
--- - 总之，单个武器队列的Update函数最终只会让一个武器同时开火
function WeaponQueue.updateWeapon(self, queueIndex, timeStamp)
	local queue = self._queueList[queueIndex]

	for _, weapon in ipairs(queue) do
		if weapon:GetType() == BattleConst.EquipmentType.BEAM and weapon:GetCurrentState() == weapon.STATE_ATTACK then
			weapon:Update()

			return
		end
	end

	for _, weapon in ipairs(queue) do
		local canBeUpdated = false
		local canFireAfterUpdate = false
		local weaponState = weapon:GetCurrentState()

		if weaponState == weapon.STATE_PRECAST or weaponState == weapon.STATE_READY or weaponState == weapon.STATE_OVER_HEAT and weapon:CheckReloadTimeStamp() then
			canBeUpdated = true
		end

		weapon:Update(timeStamp)

		local weaponStateAfterUpdate = weapon:GetCurrentState()

		if weaponStateAfterUpdate == weapon.STATE_PRECAST or weaponStateAfterUpdate == weapon.STATE_READY then
			canFireAfterUpdate = true
		end

		if queueIndex ~= BattleConst.NON_QUEUE_WEAPON and (canBeUpdated and not canFireAfterUpdate or weapon:IsAttacking()) then
			break
		end
	end
end

--- @class WeaponQueue
--- @param duration number
--- @param queueIndex number
--- @return nil
--- 为指定武器队列添加GCD计时器。
--- - 如果该队列没有GCD计时器，则添加一个新的计时器，持续duration秒，并在计时结束时移除该计时器
--- - 否则，如果有GCD计时器，直接返回（GCD不会覆盖/叠加）
function WeaponQueue.addGCDTimer(self, duration, queueIndex)
	if self._GCDTimerList[queueIndex] ~= nil then
		return
	end

	local function onTimerFinish()
		self:removeGCDTimer(queueIndex)
	end

	self._GCDTimerList[queueIndex] = pg.TimeMgr.GetInstance():AddBattleTimer("weaponGCD", -1, duration, onTimerFinish, true)
end

--- @class WeaponQueue
--- @param queueIndex number
--- @return nil
--- 移除指定武器队列的GCD计时器。
function WeaponQueue.removeGCDTimer(self, queueIndex)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._GCDTimerList[queueIndex])

	self._GCDTimerList[queueIndex] = nil
end
