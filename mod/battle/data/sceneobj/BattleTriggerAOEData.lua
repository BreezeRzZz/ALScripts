ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleTriggerAOEData = class("BattleTriggerAOEData", ys.Battle.BattleAOEData)

ys.Battle.BattleTriggerAOEData = BattleTriggerAOEData
BattleTriggerAOEData.__name = "BattleTriggerAOEData"

--- @class BattleTriggerAOEData : BattleAOEData
--- @param areaUID number 区域唯一ID
--- @param IFF number 敌我识别
--- @param areaCldFunc function 碰撞回调函数
--- 触发型AOE：构造同父类
function BattleTriggerAOEData.Ctor(self, areaUID, IFF, areaCldFunc)
	BattleTriggerAOEData.super.Ctor(self, areaUID, IFF, areaCldFunc)
end

--- 触发型AOE结算：有碰撞对象时执行一次碰撞回调后立即标记失效
function BattleTriggerAOEData.Settle(self)
	if #self._cldObjList > 0 then
		self.SortCldObjList(self._cldObjList)
		self._cldComponent:GetCldData().func(self._cldObjList)

		self._flag = false
	end
end
