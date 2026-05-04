ys = ys or {}

local ys = ys

ys.Battle.BattleVigilantBar = class("BattleVigilantBar")
ys.Battle.BattleVigilantBar.__name = "BattleVigilantBar"

local BattleVigilantBar = ys.Battle.BattleVigilantBar

-- ============================================================
-- 警戒条常量（雷达式进度条）
-- ============================================================
--- 进度条最小填充量（刻度范围起点）
BattleVigilantBar.MIN = 0.267
--- 进度条最大填充量（刻度范围终点）
BattleVigilantBar.MAX = 0.7335
--- 刻度总长度
BattleVigilantBar.METER_LENGTH = BattleVigilantBar.MAX - BattleVigilantBar.MIN

--- 警戒状态常量
BattleVigilantBar.STATE_CALM = 0        -- 平静
BattleVigilantBar.STATE_SUSPICIOUS = 1  -- 可疑
BattleVigilantBar.STATE_VIGILANT = 2    -- 警戒
BattleVigilantBar.STATE_ENGAGE = 3      -- 交战

--- @class BattleVigilantBar
--- 警戒条/探测条视图
--- 显示敌人对玩家舰队的警戒程度，从 CALM -> SUSPICIOUS -> VIGILANT -> ENGAGE 逐级上升
--- 使用雷达式进度条，包含4个状态标记
--- @param vigilantBar Transform 警戒条Transform
function BattleVigilantBar.Ctor(self, vigilantBar)
	self._vigilantBar = vigilantBar
	self._vigilantBarGO = self._vigilantBar.gameObject
	self._progress = self._vigilantBar:Find("progress"):GetComponent(typeof(Image))
	self._markList = {}
	-- 四个状态标记子节点
	self._markList[BattleVigilantBar.STATE_CALM] = self._vigilantBar:Find("mark/" .. BattleVigilantBar.STATE_CALM)
	self._markList[BattleVigilantBar.STATE_SUSPICIOUS] = self._vigilantBar:Find("mark/" .. BattleVigilantBar.STATE_SUSPICIOUS)
	self._markList[BattleVigilantBar.STATE_VIGILANT] = self._vigilantBar:Find("mark/" .. BattleVigilantBar.STATE_VIGILANT)
	self._markList[BattleVigilantBar.STATE_ENGAGE] = self._vigilantBar:Find("mark/" .. BattleVigilantBar.STATE_ENGAGE)
end

--- 绑定警戒状态数据
--- @param vigilantState BattleUnitVigilantComponent 警戒组件
function BattleVigilantBar.ConfigVigilant(self, vigilantState)
	self._vigilantState = vigilantState
end

--- 每帧更新警戒进度条填充量
--- 从警戒组件获取当前rate，映射到雷达进度条的fillAmount范围
function BattleVigilantBar.UpdateVigilantProgress(self)
	local vigilantRate = self._vigilantState:GetVigilantRate()

	self._progress.fillAmount = self.meterConvert(vigilantRate)
end

--- 更新当前警戒状态标记（高亮对应状态的mark节点）
function BattleVigilantBar.UpdateVigilantMark(self)
	local currentMark = self._vigilantState:GetVigilantMark()

	for markIndex, markTF in ipairs(self._markList) do
		SetActive(markTF, currentMark == markIndex)
	end
end

--- 更新警戒条屏幕位置
--- @param worldPos Vector3 世界坐标
function BattleVigilantBar.UpdateVigilantBarPosition(self, worldPos)
	self._vigilantBar.position = worldPos
end

--- 将警戒率映射到进度条fillAmount范围
--- [0, 1] -> [MIN, MAX]
--- @param rate number 0~1 警戒率
--- @return number fillAmount 0.267~0.7335
function BattleVigilantBar.meterConvert(rate)
	return BattleVigilantBar.METER_LENGTH * rate + BattleVigilantBar.MIN
end

--- 销毁警戒条
function BattleVigilantBar.Dispose(self)
	self._vigilantState = nil

	Object.Destroy(self._vigilantBarGO)

	self._vigilantBar = nil
	self._vigilantBarGO = nil
	self._markList = nil
	self._progress = nil
end
