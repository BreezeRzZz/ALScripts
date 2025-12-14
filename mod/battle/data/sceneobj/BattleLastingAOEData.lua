ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleLastingAOEData = class("BattleLastingAOEData", ys.Battle.BattleAOEData)

ys.Battle.BattleLastingAOEData = BattleLastingAOEData
BattleLastingAOEData.__name = "BattleLastingAOEData"

function BattleLastingAOEData.Ctor(self, areaUID, IFF, areaCldFunc, exitCldFunc, endFunc, frequent)
	BattleLastingAOEData.super.Ctor(self, areaUID, IFF, areaCldFunc, endFunc)

	self._exitCldFunc = exitCldFunc

	if frequent then
		self.Settle = self.frequentlySettle
	end

	self._handledList = {}
end

function BattleLastingAOEData.Dispose(arg_2_0)
	for iter_2_0, iter_2_1 in pairs(arg_2_0._handledList) do
		arg_2_0._exitCldFunc(iter_2_0)

		arg_2_0._handledList[iter_2_0] = nil
	end

	arg_2_0._exitCldFunc = nil
	arg_2_0._handledList = nil

	BattleLastingAOEData.super.Dispose(arg_2_0)
end

function BattleLastingAOEData.Settle(self)
	local cldObjList = {}
	local existList = {}

	for _, cldObj in ipairs(self._cldObjList) do
		existList[cldObj.UID] = true

		if not self._handledList[cldObj] then
			cldObjList[#cldObjList + 1] = cldObj
			self._handledList[cldObj] = true
		end
	end

	self.SortCldObjList(cldObjList)
	-- 此处的func即为areaCldFunc
	self._cldComponent:GetCldData().func(cldObjList, obj)

	for cldObj, _ in pairs(self._handledList) do
		-- Settle会检查ImmuneCLD属性，frequentlySettle不会
		if not existList[cldObj.UID] or cldObj.ImmuneCLD == true then
			self._exitCldFunc(cldObj)

			self._handledList[cldObj] = nil
		end
	end
end

function BattleLastingAOEData.frequentlySettle(self)
	local existList = {}

	for _, cldObj in ipairs(self._cldObjList) do
		existList[cldObj.UID] = true

		if not self._handledList[cldObj] then
			self._handledList[cldObj] = true
		end
	end

	for cldObj, _ in pairs(self._handledList) do
		if not existList[cldObj.UID] then
			self._exitCldFunc(cldObj)

			self._handledList[cldObj] = nil
		end
	end

	self.SortCldObjList(self._cldObjList)
	self._cldComponent:GetCldData().func(self._cldObjList)
end

function BattleLastingAOEData.ForceExit(arg_5_0, arg_5_1)
	local var_5_0

	for iter_5_0, iter_5_1 in pairs(arg_5_0._handledList) do
		if iter_5_0.UID == arg_5_1 then
			var_5_0 = iter_5_0

			break
		end
	end

	if var_5_0 then
		arg_5_0._exitCldFunc(var_5_0)

		arg_5_0._handledList[var_5_0] = nil
	end
end
