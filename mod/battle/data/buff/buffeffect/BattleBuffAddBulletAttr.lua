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

function BattleBuffAddBulletAttr.onManualBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:calcBulletAttr(args)
end

function BattleBuffAddBulletAttr.onBulletCollideBefore(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:displacementConvert(args, owner)
	self:calcBulletAttr(args)
end

function BattleBuffAddBulletAttr.onBombBulletBang(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:displacementConvert(args, owner)
	self:calcBulletAttr(args)
end

function BattleBuffAddBulletAttr.onTorpedoBulletBang(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	self:displacementConvert(args, owner)
	self:calcBulletAttr(args)
end

-- 处理按距离转换属性加成的逻辑
function BattleBuffAddBulletAttr.displacementConvert(self, args, owner)
	local bullet = args._bullet

	-- 按照子弹飞行距离动态计算距离转换属性加成的逻辑
	if self._displacementConvert then
		local distanceFromSpawn = bullet:GetCurrentDistance()
		local base = self._displacementConvert.base
		local rate = self._displacementConvert.rate
		local max = self._displacementConvert.max

		if rate > 0 then
			self._number = math.min(math.max(distanceFromSpawn - base, 0) * rate, max)
		elseif rate < 0 then
			self._number = math.min(math.max(0, max + (distanceFromSpawn - base) * rate), max)
		elseif rate == 0 then
			self._number = 0
		end
	-- 按照子弹与施法者的距离动态计算距离转换属性加成的逻辑
	elseif self._displacementDynamic then
		local check_caster = self._displacementDynamic.check_caster
		local base = self._displacementDynamic.base
		local rate = self._displacementDynamic.rate
		local max = self._displacementDynamic.max
		local targetList = self:getTargetList(owner, check_caster, self._displacementDynamic)

		if targetList and #targetList > 0 then
			local casterPos = targetList[1]:GetPosition()
			local bulletPos = bullet:GetPosition()
			local distance = Vector3.Distance(casterPos, bulletPos)

			self._number = math.min(math.max(distance - base, 0) * rate, max)
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
