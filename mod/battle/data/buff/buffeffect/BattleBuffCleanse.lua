ys = ys or {}

local ys = ys
local BattleBuffCleanse = class("BattleBuffCleanse", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffCleanse = BattleBuffCleanse
BattleBuffCleanse.__name = "BattleBuffCleanse"

function BattleBuffCleanse.Ctor(self, effectData)
	BattleBuffCleanse.super.Ctor(self, effectData)
end

function BattleBuffCleanse.SetArgs(self, owner, buff)
	self._buffIDList = self._tempData.arg_list.buff_id_list
	self._check_target = self._tempData.arg_list.check_target
	self._minTargetNumber = self._tempData.arg_list.minTargetNumber or 0
	self._maxTargetNumber = self._tempData.arg_list.maxTargetNumber or 10000
end

function BattleBuffCleanse.onTrigger(self, owner, buff, args)
	-- quota - 1，但好像这类effect一般没有quota属性，所以可能没啥用
	BattleBuffCleanse.super.onTrigger(self, owner, buff, args)

	if self._check_target then
		local targetNum = #self:getTargetList(owner, self._check_target, self._tempData.arg_list, args)

		-- 在[minTargetNumber, maxTargetNumber]范围内才清除buff
		-- 根据默认值，可以认为如果没有对应的min/max参数，则相当于不限制这边
		if targetNum >= self._minTargetNumber and targetNum <= self._maxTargetNumber then
			for _, buffID in ipairs(self._buffIDList) do
				owner:RemoveBuff(buffID)
			end
		end
	else
		for _, buffID in ipairs(self._buffIDList) do
			owner:RemoveBuff(buffID)
		end
	end
end
