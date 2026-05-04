ys = ys or {}

local ys = ys
local BattleDrops = class("BattleDrops")

ys.Battle.BattleDrops = BattleDrops
BattleDrops.__name = "BattleDrops"

--- @class BattleDrops
--- @param dropDataTable table 掉落配置表，key为waveIndex，value为该波的掉落列表
--- @return nil
--- 战斗掉落管理类，管理每波敌舰的掉落数据
function BattleDrops.Ctor(self, dropDataTable)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._dropList = dropDataTable
	self._resourceCount = 0
	self._itemCount = 0
end

--- @param waveIndex number 波次索引
--- @return table dropData 该波的掉落数据
--- 创建指定波次的掉落，从掉落列表中取出最后一个元素（栈顶）
function BattleDrops.CreateDrops(self, waveIndex)
	local dropData = {}
	local waveDropList = self._dropList[waveIndex]

	if waveDropList ~= nil and #waveDropList > 0 then
		dropData = waveDropList[#waveDropList]
		waveDropList[#waveDropList] = nil
	end

	if dropData.resourceCount ~= nil then
		self._resourceCount = self._resourceCount + dropData.resourceCount
	end

	if dropData.itemCount ~= nil then
		self._itemCount = self._itemCount + dropData.itemCount
	end

	return dropData
end

--- @return number resourceCount, number itemCount
--- 获取已掉落的资源总数和道具总数
function BattleDrops.GetDropped(self)
	return self._resourceCount, self._itemCount
end

--- @return nil
function BattleDrops.Dispose(self)
	ys.EventDispatcher.DetachEventDispatcher(self)
end
