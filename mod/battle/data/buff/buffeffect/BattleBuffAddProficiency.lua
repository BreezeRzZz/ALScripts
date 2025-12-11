ys = ys or {}

local ys = ys
local BattleBuffAddProficiency = class("BattleBuffAddProficiency", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddProficiency = BattleBuffAddProficiency
BattleBuffAddProficiency.__name = "BattleBuffAddProficiency"

function BattleBuffAddProficiency.Ctor(self, effectInfo)
	BattleBuffAddProficiency.super.Ctor(self, effectInfo)
end

function BattleBuffAddProficiency.SetArgs(self, owner, buff)
	self._group = self._tempData.arg_list.group or buff:GetID()
	self._weaponLabelList = self._tempData.arg_list.label or {}
	self._weaponIndexList = self._tempData.arg_list.index
	self._number = self._tempData.arg_list.number
	self._numberBase = self._number
end

function BattleBuffAddProficiency.onAttach(self, owner, buff)
	self:calcEnhancement(owner)
end

function BattleBuffAddProficiency.onStack(self, owner, buff)
	self:resetEnhancement(owner)

	self._number = self._numberBase * buff._stack

	self:calcEnhancement(owner)
end

function BattleBuffAddProficiency.onRemove(self, owner, buff)
	self:resetEnhancement(owner)
end

function BattleBuffAddProficiency.calcEnhancement(self, owner, buff)
	local allWeapons = owner:GetAllWeapon()
	local number = self._number

	for _, weapon in ipairs(allWeapons) do
		local satisfied = 1
		local equipLabel = weapon:GetEquipmentLabel()

		for _, requiredLabel in ipairs(self._weaponLabelList) do
			if not table.contains(equipLabel, requiredLabel) then
				satisfied = 0

				break
			end
		end

		if self._weaponIndexList then
			local equipIndex = weapon:GetEquipmentIndex()

			if not table.contains(self._weaponIndexList, equipIndex) then
				satisfied = satisfied * 0
			end
		end

		if satisfied == 1 then
			local potential = weapon:GetPotential() + number

			weapon:SetPotentialFactor(potential)
		end
	end
end

function BattleBuffAddProficiency.resetEnhancement(self, owner)
	local deduction = self._number * -1
	local allWeapons = owner:GetAllWeapon()

	for _, weapon in ipairs(allWeapons) do
		local satisfied = 1
		local equipLabel = weapon:GetEquipmentLabel()

		for _, requiredLabel in ipairs(self._weaponLabelList) do
			if not table.contains(equipLabel, requiredLabel) then
				satisfied = 0

				break
			end
		end

		if self._weaponIndexList then
			local equipIndex = weapon:GetEquipmentIndex()

			if not table.contains(self._weaponIndexList, equipIndex) then
				satisfied = satisfied * 0
			end
		end

		if satisfied == 1 then
			local potential = weapon:GetPotential() + deduction

			weapon:SetPotentialFactor(potential)
		end
	end
end
