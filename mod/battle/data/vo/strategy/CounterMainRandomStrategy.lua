ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.CounterMainRandomStrategy = class("CounterMainRandomStrategy", ys.Battle.RandomStrategy)

local CounterMainRandomStrategy = ys.Battle.CounterMainRandomStrategy

CounterMainRandomStrategy.__name = "CounterMainRandomStrategy"

--- 固定前移比例：目标点 X 坐标始终在战场宽度的 50% 处
CounterMainRandomStrategy.FIX_FRONT = 0.5

--- AI 策略：反击敌方主力舰队
--- 继承 RandomStrategy 的随机移动逻辑，但重写 generateTargetPoint。
--- 区别：Z 轴目标范围不再用固定的 upper_rate/lower_rate，
---       而是根据敌方主力位置动态调整，使友方舰队向敌方主力方向靠拢。
function CounterMainRandomStrategy.Ctor(self, fleetVO)
	CounterMainRandomStrategy.super.Ctor(self, fleetVO)
end

--- 获取策略类型标识
--- @return number 策略类型：BattleJoyStickAutoBot.COUNTER_MAIN
function CounterMainRandomStrategy.GetStrategyType(self)
	return ys.Battle.BattleJoyStickAutoBot.COUNTER_MAIN
end

--- 生成目标点（核心差异方法）
--- 与父类 RandomStrategy.generateTargetPoint 的区别：
---   Z 轴上下界不再用 personality 的 upper_rate/lower_rate，
---   而是根据敌方主力（foeShipList）的 Z 坐标动态计算。
---   友方舰队会向敌方主力所在区域移动。
--- @return Vector3 随机目标点坐标
function CounterMainRandomStrategy.generateTargetPoint(self)
	-- 从敌方主力位置计算 Z 轴范围
	local zUpperBound = self._upperBound
	local zLowerBound = self._lowerBound

	-- 遍历敌方主力舰船列表，用敌舰 Z 坐标收紧上/下界
	for _, foeShip in pairs(self._foeShipList) do
		local foeZ = foeShip:GetPosition().z

		-- 不断缩小 Z 轴搜索范围到敌方主力所在区间
		zUpperBound = math.min(foeZ, zUpperBound)
		zLowerBound = math.max(foeZ, zLowerBound)
	end

	local personalityData = self._fleetVO:GetLeaderPersonality()

	local frontRate = CounterMainRandomStrategy.FIX_FRONT  -- 固定前移比例 0.5
	local rearRate  = personalityData.rear_rate             -- 后移比例（默认 0.3）

	if self._fleetVO:GetIFF() == BattleConfig.FRIENDLY_CODE then
		frontRate = 1 - frontRate
		rearRate  = 1 - rearRate
	end

	-- X 轴范围用固定 frontRate + personality rearRate 计算
	local randomRightBound = self._totalWidth * frontRate + self._leftBound
	local randomLeftBound  = self._totalWidth * rearRate  + self._leftBound

	-- Z 轴范围用 personality 的 upper_rate/lower_rate（与敌方位置 range 取交集区域）
	local randomUpperBound = self._totalHeight * personalityData.upper_rate + self._lowerBound
	local randomLowerBound = self._totalHeight * personalityData.lower_rate + self._lowerBound

	-- Z 轴范围收紧到敌方主力区域与 personality 区域的交集
	local zMax = math.min(zUpperBound, randomUpperBound)
	local zMin = math.max(zLowerBound, randomLowerBound)

	local targetX = math.random(randomLeftBound, randomRightBound)
	local targetZ = math.random(zMin, zMax)

	return (Vector3(targetX, 0, targetZ))
end
