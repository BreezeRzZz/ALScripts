ys = ys or {}

local ys = ys
local BattleBuffField = class("BattleBuffField", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffField = BattleBuffField
BattleBuffField.__name = "BattleBuffField"

local BattleConst = ys.Battle.BattleConst

function BattleBuffField.Ctor(self, effectData)
	BattleBuffField.super.Ctor(self, effectData)
end

function BattleBuffField.SetArgs(self, owner, buff)
	self._level = buff:GetLv()
	self._caster = buff:GetCaster()

	local arg_list = self._tempData.arg_list

	self._auraBuffID = arg_list.buff_id
	self._target = arg_list.target
	self._check_target = arg_list.check_target or "TargetNull"
	-- 这个字段只有致盲Buff用过
	self._isUpdateAura = arg_list.FAura

	local isFriend = true
	local targetVarType = type(self._target)
	-- 如果是敌人，修改变量，以便后续构建对敌人生效的AOE
	if targetVarType == "string" and self._target == "TargetAllHarm" or targetVarType == "table" and table.contains(self._target, "TargetAllHarm") or targetVarType == "string" and self._target == "TargetAllFoe" or targetVarType == "table" and table.contains(self._target, "TargetAllFoe") then
		isFriend = false
	end

	local function cldFunc(arg_3_0)
		for _, cldData in ipairs(arg_3_0) do
			-- cldData -> cldData
			if cldData.Active then
				local targetList = self:getTargetList(owner, self._target, self._tempData.arg_list)

				for _, target in ipairs(targetList) do
					if target:GetUniqueID() == cldData.UID then
						local auraBuff = ys.Battle.BattleBuffUnit.New(self._auraBuffID, self._level, self._caster)

						target:AddBuff(auraBuff)

						break
					end
				end
			end
		end
	end

	local function exitCldFunc(cldData)
		if cldData.Active then
			local targetList = self:getTargetList(owner, self._target, self._tempData.arg_list)

			for _, target in ipairs(targetList) do
				if target:GetUniqueID() == cldData.UID then
					target:RemoveBuff(self._auraBuffID)

					break
				end
			end
		end
	end

	local endFunc = self._isUpdateAura and exitCldFunc or nil
	local isUpdateAura = self._isUpdateAura and true or false
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local totalUpperBound, totalLowerBound, leftFieldBound, rightFieldBound = battleDataProxy:GetFieldBound()
	local auraCenter = Vector3((leftFieldBound + rightFieldBound) * 0.5, 0, (totalUpperBound + totalLowerBound) * 0.5)
	local auraWidth = math.abs(rightFieldBound - leftFieldBound)
	local auraHeight = math.abs(totalUpperBound - totalLowerBound)
	--- @type BattleLastingAOEData
	self._aura = battleDataProxy:SpawnLastingCubeArea(BattleConst.AOEField.SURFACE, owner:GetIFF(), auraCenter, auraWidth, auraHeight, 0, cldFunc, exitCldFunc, isFriend, nil, endFunc, isUpdateAura)
end

function BattleBuffField.Clear(self)
	self._aura:SetActiveFlag(false)

	self._aura = nil

	BattleBuffField.super.Clear(self)
end
