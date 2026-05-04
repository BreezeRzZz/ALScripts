ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr
local AntiAirConfig = BattleConfig.AntiAirConfig

ys.Battle.BattleAntiAirWeaponVO = class("BattleAntiAirWeaponVO", ys.Battle.BattlePlayerWeaponVO)
ys.Battle.BattleAntiAirWeaponVO.__name = "BattleAntiAirWeaponVO"

local BattleAntiAirWeaponVO = ys.Battle.BattleAntiAirWeaponVO

--- @class BattleAntiAirWeaponVO : BattlePlayerWeaponVO
--- @param GCD number 防空炮全局冷却时间
--- @return nil
function BattleAntiAirWeaponVO.Ctor(self, GCD)
	BattleAntiAirWeaponVO.super.Ctor(self, GCD)

	self._restoreDenominator = AntiAirConfig.const_A

	self:ResetCost()

	self._restoreInterval = AntiAirConfig.Restore_Interval
end

--- @param battleFleetVO BattleFleetVO 所属舰队VO
--- @return nil
function BattleAntiAirWeaponVO.SetBattleFleetVO(self, battleFleetVO)
	self._battleFleetVO = battleFleetVO
end

--- @param weapon BattleAntiAirWeaponUnit
--- @return nil
--- 添加防空武器，并设置耐久度信息
function BattleAntiAirWeaponVO.AppendWeapon(self, weapon)
	BattleAntiAirWeaponVO.super.AppendWeapon(self, weapon)
	weapon:SetTotalDurabilityInfo(self)
end

--- @param weapon BattleAntiAirWeaponUnit
--- @return number removedIndex 被移除的武器索引，-1表示未找到
function BattleAntiAirWeaponVO.RemoveWeapon(self, weapon)
	local removedIndex = self.deleteElementFromArray(weapon, self._weaponList)

	self._total = self._total - 1
	self._count = self._count - 1

	return removedIndex
end

--- @param maxCount number 最大弹药数
--- @return nil
--- 设置最大弹药数，同时按比例调整当前弹药
function BattleAntiAirWeaponVO.SetMax(self, maxCount)
	if maxCount > self._max then
		self._current = self._current + (maxCount - self._max)
	end

	BattleAntiAirWeaponVO.super.SetMax(self, maxCount)

	if self._current > self._max then
		self._current = self._max
	end
end

--- @param fleetReload number 舰队平均装填值
--- @return nil
function BattleAntiAirWeaponVO.SetAverageReload(self, fleetReload)
	self._fleetReload = fleetReload
end

--- @return number maxRange
--- 获取舰队中所有防空武器的最大射程
function BattleAntiAirWeaponVO.GetMaxRange(self)
	local scoutList = self._battleFleetVO:GetScoutList()
	local maxRange = 0
	local scoutCount = #scoutList

	if scoutCount > 0 then
		local firstScoutWithAA

		for i = 1, scoutCount do
			if #scoutList[i]:GetAntiAirWeapon() > 0 then
				firstScoutWithAA = scoutList[i]

				break
			end
		end

		if firstScoutWithAA then
			local aaWeaponList = firstScoutWithAA:GetAntiAirWeapon()

			for _, aaWeapon in ipairs(aaWeaponList) do
				maxRange = math.max(maxRange, aaWeapon:GetTemplateData().range)
			end
		end
	end

	return maxRange
end

--- @param isActive boolean
--- @return nil
function BattleAntiAirWeaponVO.SetActive(self, isActive)
	for _, weapon in ipairs(self._weaponList) do
		weapon:SetActive(isActive)
	end
end

--- @return nil
--- 每帧恢复：current += fleetReload / restoreDenominator
function BattleAntiAirWeaponVO.Restore(self)
	self._current = self._current + self._fleetReload / self._restoreDenominator

	self:checkRestorState()
end

--- @param rate number 恢复比例（相对于max）
--- @return nil
--- 按比例恢复弹药
function BattleAntiAirWeaponVO.RestoreRate(self, rate)
	self._current = self._current + self._max * rate

	self:checkRestorState()
end

--- @return nil
--- 检查是否恢复到满，若满则重置回const_A恢复速率
function BattleAntiAirWeaponVO.checkRestorState(self)
	if self._current >= self._max then
		self._current = self._max
		self._restoreDenominator = AntiAirConfig.const_A
		self._isOverLoad = false

		self:RemoveRestoreTimer()
		self:DispatchOverLoadChange()
	end
end

--- @return nil
--- 消耗一次防空弹药，若耗尽则切换到const_B（更慢的恢复速率）
function BattleAntiAirWeaponVO.Consume(self)
	self:RemoveRestoreTimer()

	self._current = self._current - self._consumeNormal

	if self._current <= 0 then
		self._current = 0
		self._restoreDenominator = AntiAirConfig.const_B
		self._isOverLoad = true

		self:DispatchOverLoadChange()
	end
end

--- @param consumeNormal number 每次消耗量，默认取AntiAirConfig.const_N
--- @return nil
function BattleAntiAirWeaponVO.ResetCost(self, consumeNormal)
	self._consumeNormal = consumeNormal or AntiAirConfig.const_N
end

--- @return nil
--- 添加防空弹药恢复计时器（无限循环）
function BattleAntiAirWeaponVO.AddRestoreTimer(self)
	if self._restoreTimer or self._current >= self._max then
		return
	end

	local function restoreFunc()
		self:Restore()
	end

	self._restoreTimer = pg.TimeMgr.GetInstance():AddBattleTimer("AARestoreTimer", -1, self._restoreInterval, restoreFunc, true)
end

--- @return nil
--- 移除恢复计时器
function BattleAntiAirWeaponVO.RemoveRestoreTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._restoreTimer)

	self._restoreTimer = nil
end

--- @return nil
function BattleAntiAirWeaponVO.Dispose(self)
	self._battleFleetVO = nil

	BattleAntiAirWeaponVO.super.Dispose(self)
end
