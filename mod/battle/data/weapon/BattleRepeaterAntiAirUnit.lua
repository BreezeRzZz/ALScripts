ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable
local BattleRepeaterAntiAirUnit = class("BattleRepeaterAntiAirUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleRepeaterAntiAirUnit = BattleRepeaterAntiAirUnit
BattleRepeaterAntiAirUnit.__name = "BattleRepeaterAntiAirUnit"

function BattleRepeaterAntiAirUnit.Ctor(self)
	BattleRepeaterAntiAirUnit.super.Ctor(self)

	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
end

function BattleRepeaterAntiAirUnit.FilterTarget(self)
	local aircraftList = self._dataProxy:GetAircraftList()
	local targetList = {}
	local hostIFF = self._host:GetIFF()
	local index = 1

	for _, aircraft in pairs(aircraftList) do
		if aircraft:GetIFF() ~= hostIFF and aircraft:IsVisitable() then
			targetList[index] = aircraft
			index = index + 1
		end
	end

	return targetList
end

function BattleRepeaterAntiAirUnit.Fire(self)
	local function areaCldFunc(cldObjList)
		if not self._dataProxy then
			return
		end

		local targetList = {}
		local aircraftList = self._dataProxy:GetAircraftList()

		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local aircraft = aircraftList[cldObj.UID]

				if aircraft and aircraft:IsVisitable() then
					targetList[#targetList + 1] = aircraft
				end
			end
		end

		local repeaterAATotalDamage = BattleFormulas.CalculateRepaterAnitiAirTotalDamage(self)

		while repeaterAATotalDamage > 0 and #targetList > 0 do
			local index = math.random(#targetList)
			local target = targetList[index]
			local targetMaxHP = target:GetMaxHP()
			-- BattleConfig.AnitAirRepeaterConfig.upper_range = 35
			-- BattleConfig.AnitAirRepeaterConfig.lower_range = 15
			repeaterAATotalDamage = repeaterAATotalDamage - (targetMaxHP + math.random(BattleConfig.AnitAirRepeaterConfig.lower_range, BattleConfig.AnitAirRepeaterConfig.upper_range))

			if repeaterAATotalDamage < 0 then
				targetMaxHP = targetMaxHP + repeaterAATotalDamage
			end

			if not BattleFormulas.RollRepeaterHitDice(self, target) then
				table.remove(targetList, index)
				self._dataProxy:HandleDirectDamage(target, targetMaxHP, self:GetHost())
			end
		end
	end

	self._dataProxy:SpawnColumnArea(BattleConst.AOEField.AIR, self._host:GetIFF(), self._host:GetPosition(), self._tmpData.range * 2, -1, areaCldFunc)
	self:EnterCoolDown()
	self._host:PlayFX(self._tmpData.fire_fx, true)
	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)
end
