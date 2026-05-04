local BattleDataProxy = ys.Battle.BattleDataProxy
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable

--- Debug用碰撞更新循环：跳过碰撞检测，仅更新运动、子弹出界等逻辑
--- @param self BattleDataProxy
--- @param timeStamp number 时间戳
function BattleDataProxy.__debug__BlockCldUpdate__(self, timeStamp)
	self:UpdateCountDown(timeStamp)

	-- 更新舰队运动
	for _, fleet in pairs(self._fleetList) do
		fleet:UpdateMotion()
	end

	-- 更新所有单位
	for _, unit in pairs(self._unitList) do
		unit:Update(timeStamp)
	end

	-- 更新所有子弹（含出界判定）
	for _, bullet in pairs(self._bulletList) do
		local speed = bullet:GetSpeed()
		local pos = bullet:GetPosition()

		-- 右侧/底部出界
		if pos.x > self._bulletRightBound and speed.x > 0 or pos.z < self._bulletLowerBound and speed.z < 0 then
			self:RemoveBulletUnit(bullet:GetUniqueID())
		-- 左侧出界（炸弹类型除外，炸弹允许飞天）
		elseif pos.x < self._bulletLeftBound and speed.x < 0 and bullet:GetType() ~= BattleConst.BulletType.BOMB then
			self:RemoveBulletUnit(bullet:GetUniqueID())
		else
			bullet:Update(timeStamp)

			-- 顶部出界或射程耗尽
			if pos.z > self._bulletUpperBound and speed.z > 0 or bullet:IsOutRange(timeStamp) then
				bullet:OutRange()
			end
		end
	end

	-- 更新所有舰载机（含出界判定）
	for _, aircraft in pairs(self._aircraftList) do
		aircraft:Update(timeStamp)

		local iff, bound = aircraft:GetIFF()

		-- 根据敌我阵营确定出界边界
		if iff == BattleConfig.FRIENDLY_CODE then
			bound = self._totalRightBound
		elseif iff == BattleConfig.FOE_CODE then
			bound = self._totalLeftBound
		end

		-- 飞出边界时触发OutBound
		if aircraft:GetPosition().x * iff > math.abs(bound) and aircraft:GetSpeed().x * iff > 0 then
			aircraft:OutBound()
		end

		-- 飞机死亡移除
		if not aircraft:IsAlive() then
			self:KillAircraft(aircraft:GetUniqueID())
		end
	end

	-- AOE区域结算
	for _, aoe in pairs(self._AOEList) do
		aoe:Settle()

		if aoe:GetActiveFlag() == false then
			self:RemoveAreaOfEffect(aoe:GetUniqueID())
		end
	end

	-- 敌方舰船超左边界强制死亡处理
	for _, foeShip in pairs(self._foeShipList) do
		if foeShip:GetPosition().x + foeShip:GetBoxSize().x < self._leftZoneLeftBound then
			foeShip:DeadAction()
			self:KillUnit(foeShip:GetUniqueID())
			self:HandleShipMissDamage(foeShip, self._fleetList[BattleConfig.FRIENDLY_CODE])
		end
	end
end
