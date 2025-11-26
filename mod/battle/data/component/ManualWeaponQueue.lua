ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.ManualWeaponQueue = class("ManualWeaponQueue")
ys.Battle.ManualWeaponQueue.__name = "ManualWeaponQueue"
local ManualWeaponQueue = ys.Battle.ManualWeaponQueue

--- @class ManualWeaponQueue
--- @param maxCount number: 手动武器队列的最大容量。从下面来看，实际是指冷却队列的最大容量。
--- @return nil
--- ManualWeaponQueue类的构造函数。
function ManualWeaponQueue.Ctor(self, maxCount)
	self:init()

	self._maxCount = maxCount or 1
end

--- @class ManualWeaponQueue
--- @return nil
--- ManualWeaponQueue的初始化函数。
--- - weaponList: [BattleWeaponUnit, boolean]的table, 表示武器是否存在
--- - overheatQueue: [number, BattleWeaponUnit]的table, 表示过热的武器队列，等待冷却
--- - cooldownList: [number, BattleWeaponUnit]的table, 表示正在冷却中的武器队列
function ManualWeaponQueue.init(self)
	ys.EventListener.AttachEventListener(self)

	self._weaponList = {}
	self._overheatQueue = {}
	self._cooldownList = {}
end

--- @class ManualWeaponQueue
--- @param weapon BattleWeaponUnit: 要添加的武器
--- @return nil
--- 将武器添加到手动武器队列中。
--- - 将weaponList对应weapon置true
--- - 注册相关事件, 详见addWeaponEvent函数
--- - 如果武器处于过热状态，则将其添加到过热队列的末尾
function ManualWeaponQueue.AppendWeapon(self, weapon)
	self._weaponList[weapon] = true

	self:addWeaponEvent(weapon)

	if weapon:GetCurrentState() == weapon.STATE_OVER_HEAT then
		self._overheatQueue[#self._overheatQueue + 1] = weapon
	end
end

--- @class ManualWeaponQueue
--- @param weapon BattleWeaponUnit: 要移除的武器
--- @return nil
--- 将武器从手动武器队列中移除。
--- - 将weaponList对应weapon置false
--- - 注销相关事件, 详见removeWeaponEvent函数
--- - 从过热队列和冷却队列中移除该武器
function ManualWeaponQueue.RemoveWeapon(self, weapon)
	self._weaponList[weapon] = nil

	self:removeWeaponEvent(weapon)

	for i, overheatWeapon in ipairs(self._overheatQueue) do
		if overheatWeapon == weapon then
			table.remove(self._overheatQueue, i)

			break
		end
	end

	for j, cooldownWeapon in ipairs(self._cooldownList) do
		if cooldownWeapon == weapon then
			table.remove(self._cooldownList, j)
		end
	end
end
--- @class ManualWeaponQueue
--- @param weapon BattleWeaponUnit
--- @return boolean
--- 判断手动武器队列中是否包含指定武器。
--- - 吐槽:函数名应为Contains才合理...
function ManualWeaponQueue.Containers(self, weapon)
	return self._weaponList[weapon]
end

--- @class ManualWeaponQueue
--- @return table<BattleWeaponUnit, boolean>
--- 获取当前冷却中的武器列表。
function ManualWeaponQueue.GetCoolDownList(self)
	return self._cooldownList
end

--- @class ManualWeaponQueue
--- @return BattleWeaponUnit
--- 获取当前队列头部的武器。
--- - 返回过热队列的队尾武器
--- - 如果过热队列为空，返回冷却队列的头部武器
function ManualWeaponQueue.GetQueueHead(self)
	return self._overheatQueue[#self._overheatQueue] or self._cooldownList[1]
end

--- @class ManualWeaponQueue
--- @return nil
--- 处理初始冷却。
--- - 将未修改初始冷却的武器添加到过热队列
--- - 从过热队列中持续取出武器，放到冷却队列中开始冷却，直到冷却队列满或过热队列空
--- - 对于剩下在过热队列中的武器，调用其OverHeat方法进入过热状态(STATE_OVER_HEAT)
function ManualWeaponQueue.CheckWeaponInitalCD(self)
	for weapon, _ in pairs(self._weaponList) do
		if not weapon:GetModifyInitialCD() then
			self._overheatQueue[#self._overheatQueue + 1] = weapon
		end
	end

	local cooldownListLength = #self._cooldownList

	while cooldownListLength < self._maxCount and #self._overheatQueue > 0 do
		local overheatWeapon = table.remove(self._overheatQueue, 1)

		overheatWeapon:InitialCD()

		self._cooldownList[#self._cooldownList + 1] = overheatWeapon
		cooldownListLength = #self._cooldownList
	end

	for _, weapon in ipairs(self._overheatQueue) do
		weapon:OverHeat()
	end
end

--- @class ManualWeaponQueue
--- @return nil
--- 刷新所有武器的重新装填需求。
function ManualWeaponQueue.FlushWeaponReloadRequire(self)
	for weapon, _ in pairs(self._weaponList) do
		weapon:FlushReloadRequire()
	end
end

--- @class ManualWeaponQueue
--- @return nil
--- 清理手动武器队列
--- - 注销所有武器事件
--- - 置空weaponList和overheatQueue
--- - 注销手动武器队列相关事件
function ManualWeaponQueue.Clear(self)
	for weapon, _ in pairs(self._weaponList) do
		self:removeWeaponEvent(weapon)
	end

	self._weaponList = nil
	self._overheatQueue = nil

	ys.EventListener.DetachEventListener(self)
end

--- @class ManualWeaponQueue
--- @param weapon BattleWeaponUnit
--- @return nil
--- 注册手动武器相关事件。
--- - 手动武器的开火事件，并关联到回调函数onManualWeaponFire
--- - 手动武器的准备完毕事件，并关联到回调函数onManualWeaponReady
--- - 手动武器的立刻准备完毕事件，并关联到回调函数onManualInstantReady
function ManualWeaponQueue.addWeaponEvent(self, weapon)
	weapon:RegisterEventListener(self, BattleUnitEvent.MANUAL_WEAPON_FIRE, self.onManualWeaponFire)
	weapon:RegisterEventListener(self, BattleUnitEvent.MANUAL_WEAPON_READY, self.onManualWeaponReady)
	weapon:RegisterEventListener(self, BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY, self.onManualInstantReady)
end

--- @class ManualWeaponQueue
--- @param weapon BattleWeaponUnit
--- @return nil
--- 注销手动武器相关事件。
--- - 手动武器的开火事件
--- - 手动武器的准备完毕事件
--- - 手动武器的立刻准备完毕事件
function ManualWeaponQueue.removeWeaponEvent(self, weapon)
	weapon:UnregisterEventListener(self, BattleUnitEvent.MANUAL_WEAPON_READY)
	weapon:UnregisterEventListener(self, BattleUnitEvent.MANUAL_WEAPON_FIRE)
	weapon:UnregisterEventListener(self, BattleUnitEvent.MANUAL_WEAPON_INSTANT_READY)
end

--- @class ManualWeaponQueue
--- @param event Event
--- @return nil
--- 手动武器的开火事件回调函数。
--- - 该手动武器进入过热状态
--- - 将该手动武器添加到过热队列的队尾
--- - 重新计算冷却队列
function ManualWeaponQueue.onManualWeaponFire(self, event)
	local weapon = event.Dispatcher

	weapon:OverHeat()

	self._overheatQueue[#self._overheatQueue + 1] = weapon
	self:fillCooldownList()
end

--- @class ManualWeaponQueue
--- @param event Event
--- @return nil
--- 手动武器的准备完毕事件回调函数。
--- - 将该手动武器从冷却队列中移除
--- - 重新计算冷却队列
function ManualWeaponQueue.onManualWeaponReady(self, event)
	local weapon = event.Dispatcher

	self:removeFromCDList(weapon)
	self:fillCooldownList()
end

--- @class ManualWeaponQueue
--- @param event Event
--- @return nil
--- 手动武器的立刻准备完毕事件回调函数。
--- - 如果该武器在过热队列中，将该手动武器从过热队列中移除
--- - 否则，将该手动武器从冷却队列中移除
--- - 重新计算冷却队列
function ManualWeaponQueue.onManualInstantReady(self, event)
	local weapon = event.Dispatcher
	local isOverheat

	for i, overheatWeapon in ipairs(self._overheatQueue) do
		if weapon == overheatWeapon then
			table.remove(self._overheatQueue, i)

			isOverheat = true

			break
		end
	end

	if not isOverheat then
		self:removeFromCDList(weapon)
	end

	self:fillCooldownList()
end

--- @class ManualWeaponQueue
--- @param weapon BattleWeaponUnit
--- @return nil
--- 从冷却队列中移除指定的手动武器。
function ManualWeaponQueue.removeFromCDList(self, weapon)
	for i, cooldownWeapon in ipairs(self._cooldownList) do
		if weapon == cooldownWeapon then
			table.remove(self._cooldownList, i)

			break
		end
	end
end

--- @class ManualWeaponQueue
--- @return nil
--- 重新计算冷却队列。
--- - 将过热队列中的手动武器依次移入冷却队列，直到冷却队列达到最大容量
--- - 让这些手动武器进入冷却状态，调用它们的EnterCoolDown方法
function ManualWeaponQueue.fillCooldownList(self)
	local cooldownListLength = #self._cooldownList

	while cooldownListLength < self._maxCount and #self._overheatQueue > 0 do
		local overheatWeapon = table.remove(self._overheatQueue, 1)

		overheatWeapon:EnterCoolDown()

		self._cooldownList[#self._cooldownList + 1] = overheatWeapon
		cooldownListLength = #self._cooldownList
	end
end
