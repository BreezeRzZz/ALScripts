ys = ys or {}

local ys = ys
local effect_offset = pg.effect_offset

ys.Battle.BattleBuffBarrier = class("BattleBuffBarrier", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffBarrier.__name = "BattleBuffBarrier"

local BattleBuffBarrier = ys.Battle.BattleBuffBarrier

-- 此Effect是基于Wall的护盾，抵挡伤害
-- 算是Shield和ShieldWall的一个结合体?
function BattleBuffBarrier.Ctor(self, effectData)
	BattleBuffBarrier.super.Ctor(self, effectData)
end

function BattleBuffBarrier.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._durability = arg_list.durability
	self._dir = owner:GetDirection()
	self._unit = owner
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._centerPos = owner:GetPosition()

	local function cldFun(bullet)
		self._dataProxy:HandleDamage(bullet, self._unit)
		bullet:Intercepted()
		self._dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
	end

	local cld_data = arg_list.cld_data
	local box = cld_data.box
	local offset = Clone(cld_data.offset)

	if owner:GetDirection() == ys.Battle.BattleConst.UnitDir.LEFT then
		offset[1] = -offset[1]
	end

	self._wall = self._dataProxy:SpawnWall(self, cldFun, box, offset)
end

function BattleBuffBarrier.onUpdate(self, owner, buff, args)
	local timeStamp = args.timeStamp
	-- 更新位置
	self._centerPos = owner:GetPosition()
end

function BattleBuffBarrier.onTakeDamage(self, owner, buff, args)
	if self:damageCheck(args) then
		local damage = args.damage

		self._durability = self._durability - damage

		if self._durability > 0 then
			args.damage = 0
		else
			args.damage = -self._durability

			buff:SetToCancel()
		end
	end
end

function BattleBuffBarrier.onAttach(self, owner, buff, args)
	if self._unit:IsBoss() then
		self._unit:BarrierStateChange(self._durability, buff:GetDuration())
	end
end

function BattleBuffBarrier.onRemove(self, owner, buff, args)
	if self._unit:IsBoss() then
		self._unit:BarrierStateChange(0)
	end
end

function BattleBuffBarrier.GetIFF(self)
	return self._unit:GetIFF()
end

function BattleBuffBarrier.GetPosition(self)
	return self._centerPos
end

function BattleBuffBarrier.IsWallActive(self)
	return self._durability > 0
end
