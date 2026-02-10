ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleFleetBuffBlindAura = class("BattleFleetBuffBlindAura", ys.Battle.BattleFleetBuffEffect)
ys.Battle.BattleFleetBuffBlindAura.__name = "BattleFleetBuffBlindAura"

local BattleFleetBuffBlindAura = ys.Battle.BattleFleetBuffBlindAura

-- 生成一个AOE, 进入AOE的单位是不可见的, 离开AOE的单位会解除隐身
function BattleFleetBuffBlindAura.Ctor(self, tempData)
	BattleFleetBuffBlindAura.super.Ctor(self, tempData)
end

function BattleFleetBuffBlindAura.SetArgs(self, fleetVO, fleetBuff)
	local target = self._tempData.arg_list.target
	local fleetIFF = fleetVO:GetIFF()

	local function cldFunc(cldObjList)
		local targetList = self:getTargetList(fleetVO, target, self._tempData.arg_list)

		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				for _, target in ipairs(targetList) do
					if target:GetUniqueID() == cldObj.UID then
						target:SetBlindInvisible(true)

						break
					end
				end
			end
		end
	end

	local function exitCldFunc(cldObj)
		if cldObj.Active then
			local targetList = self:getTargetList(fleetVO, target, self._tempData.arg_list)

			for _, target in ipairs(targetList) do
				if target:GetUniqueID() == cldObj.UID then
					target:SetBlindInvisible(false)

					break
				end
			end
		end
	end

	self._aura = ys.Battle.BattleDataProxy.GetInstance():SpawnLastingCubeArea(BattleConst.AOEField.SURFACE, fleetIFF, Vector3(-55, 0, 55), 180, 70, 0, cldFunc, exitCldFunc, false)
end

function BattleFleetBuffBlindAura.Clear(self)
	self._aura:SetActiveFlag(false)

	self._aura = nil

	BattleFleetBuffBlindAura.super.Clear(self)
end
