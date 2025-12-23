ys = ys or {}
-- TODO
local ys = ys

ys.Battle.BattleBuffAddBulletAttr = class("BattleBuffAddBulletAttr", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffAddBulletAttr.__name = "BattleBuffAddBulletAttr"

local BattleBuffAddBulletAttr = ys.Battle.BattleBuffAddBulletAttr

function BattleBuffAddBulletAttr.Ctor(self, effectData)
	BattleBuffAddBulletAttr.super.Ctor(self, effectData)
end

function BattleBuffAddBulletAttr.SetArgs(self, owner, buff)
	self._attr = self._tempData.arg_list.attr
	self._number = self._tempData.arg_list.number
	self._rate = self._tempData.arg_list.rate or 10000
	self._bulletID = self._tempData.arg_list.bulletID
	self._weaponIndexList = self._tempData.arg_list.index
	self._numberBase = self._number
	self._displacementConvert = self._tempData.arg_list.displacement_convert
	self._displacementDynamic = self._tempData.arg_list.displacement_convert_dynamic
end

function BattleBuffAddBulletAttr.onStack(self, owner, buff)
	self._number = self._numberBase * buff._stack
end

function BattleBuffAddBulletAttr.onBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:calcBulletAttr(args)
end

function BattleBuffAddBulletAttr.onInternalBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:calcBulletAttr(args)
end

function BattleBuffAddBulletAttr.onManualBulletCreate(self, arg_6_1, arg_6_2, arg_6_3)
	if not self:equipIndexRequire(arg_6_3.equipIndex) then
		return
	end

	self:calcBulletAttr(arg_6_3)
end

function BattleBuffAddBulletAttr.onBulletCollideBefore(self, arg_7_1, arg_7_2, arg_7_3)
	if not self:equipIndexRequire(arg_7_3.equipIndex) then
		return
	end

	self:displacementConvert(arg_7_3, arg_7_1)
	self:calcBulletAttr(arg_7_3)
end

function BattleBuffAddBulletAttr.onBombBulletBang(self, arg_8_1, arg_8_2, arg_8_3)
	if not self:equipIndexRequire(arg_8_3.equipIndex) then
		return
	end

	self:displacementConvert(arg_8_3, arg_8_1)
	self:calcBulletAttr(arg_8_3)
end

function BattleBuffAddBulletAttr.onTorpedoBulletBang(self, arg_9_1, arg_9_2, arg_9_3)
	if not self:equipIndexRequire(arg_9_3.equipIndex) then
		return
	end

	self:displacementConvert(arg_9_3, arg_9_1)
	self:calcBulletAttr(arg_9_3)
end

function BattleBuffAddBulletAttr.displacementConvert(self, arg_10_1, arg_10_2)
	local var_10_0 = arg_10_1._bullet

	if self._displacementConvert then
		local var_10_1 = var_10_0:GetCurrentDistance()
		local var_10_2 = self._displacementConvert.base
		local var_10_3 = self._displacementConvert.rate
		local var_10_4 = self._displacementConvert.max

		if var_10_3 > 0 then
			self._number = math.min(math.max(var_10_1 - var_10_2, 0) * var_10_3, var_10_4)
		elseif var_10_3 < 0 then
			self._number = math.min(math.max(0, var_10_4 + (var_10_1 - var_10_2) * var_10_3), var_10_4)
		elseif var_10_3 == 0 then
			self._number = 0
		end
	elseif self._displacementDynamic then
		local var_10_5 = self._displacementDynamic.check_caster
		local var_10_6 = self._displacementDynamic.base
		local var_10_7 = self._displacementDynamic.rate
		local var_10_8 = self._displacementDynamic.max
		local var_10_9 = self:getTargetList(arg_10_2, var_10_5, self._displacementDynamic)

		if var_10_9 and #var_10_9 > 0 then
			local var_10_10 = var_10_9[1]:GetPosition()
			local var_10_11 = var_10_0:GetPosition()
			local var_10_12 = Vector3.Distance(var_10_10, var_10_11)

			self._number = math.min(math.max(var_10_12 - var_10_6, 0) * var_10_7, var_10_8)
		else
			self._number = 0
		end
	end
end

function BattleBuffAddBulletAttr.calcBulletAttr(self, args)
	if ys.Battle.BattleFormulas.IsHappen(self._rate) then
		local bullet = args._bullet
		local equipIndex = bullet:GetWeapon():GetEquipmentIndex()
		local satisfied = false

		if not self._weaponIndexList then
			satisfied = true
		elseif #self._weaponIndexList == 0 and equipIndex == nil then
			satisfied = true
		elseif table.contains(self._weaponIndexList, equipIndex) then
			satisfied = true
		end

		if satisfied then
			if self._bulletID then
				if bullet:GetTemplate().id == self._bulletID then
					ys.Battle.BattleAttr.Increase(bullet, self._attr, self._number)
				end
			else
				ys.Battle.BattleAttr.Increase(bullet, self._attr, self._number)
			end
		end
	end
end
