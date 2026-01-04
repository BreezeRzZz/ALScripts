ys = ys or {}

local ys = ys
local IPilot = class("IPilot")

ys.Battle.IPilot = IPilot
IPilot.__name = "IPilot"

--- @class IPilot
--- @param index number
--- @param pilot AutoPilot
function IPilot.Ctor(self, index, pilot)
	self._index = index
	self._pilot = pilot
end

function IPilot.SetParameter(self, paramList, toIndex)
	self._paramList = paramList
	-- 默认的AutoPilot.PILOT_VALVE = 0.5
	-- 吐槽：这里表达的应该是"阈值"(threshold)而不是"阀值"(valve)吧...英语差就算了，怎么汉字也搞不明白...
	self._valve = paramList.valve or ys.Battle.AutoPilot.PILOT_VALVE
	self._toIndex = toIndex
	self._duration = paramList.duration or -1
end

function IPilot.GetIndex(self)
	return self._index
end

function IPilot.GetToIndex(self)
	return self._toIndex
end

function IPilot.Active(self, target)
	self._startTime = pg.TimeMgr.GetInstance():GetCombatTime()
end

function IPilot.IsExpired(self)
	if self._duration > 0 and pg.TimeMgr.GetInstance():GetCombatTime() - self._startTime > self._duration then
		return true
	else
		return false
	end
end
-- 子类实现，是根据单位的当前位置，以及各AIStep的逻辑，返回一个方向向量（将要前进的方向）
function IPilot.GetDirection(self, position)
	return
end

function IPilot.Finish(self)
	self._pilot:NextStep()
end
