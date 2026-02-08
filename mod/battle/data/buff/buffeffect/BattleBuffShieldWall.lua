ys = ys or {}

local ys = ys
local effect_offset = pg.effect_offset

ys.Battle.BattleBuffShieldWall = class("BattleBuffShieldWall", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShieldWall.__name = "BattleBuffShieldWall"

local BattleBuffShieldWall = ys.Battle.BattleBuffShieldWall

-- 此BuffEffect会在单位周围生成一个护盾墙，持续一段时间。护盾墙能阻挡指定类型的子弹类型的碰撞(子弹消失), 当碰撞次数达到指定数量后，护盾墙会消失
-- 游戏中将这种和BattleBuffShield都叫做“护盾”。实际区别很大：Shield是一个有血量的护盾，受到伤害时会先扣Shield的血量，血量扣完后才会对单位造成伤害; 而ShieldWall是一个有碰撞次数的护盾，能阻挡一定数量的子弹，碰撞次数用完后就会消失
function BattleBuffShieldWall.Ctor(self, effectData)
	BattleBuffShieldWall.super.Ctor(self, effectData)
end

function BattleBuffShieldWall.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._buffID = buff:GetID()
	self._dir = owner:GetDirection()
	self._count = arg_list.count
	self._bulletType = arg_list.bulletType or ys.Battle.BattleConst.BulletType.CANNON
	self._doWhenHit = arg_list.do_when_hit
	self._unit = owner
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	self._centerPos = owner:GetPosition()
	self._startTime = pg.TimeMgr.GetInstance():GetCombatTime()

	local function cldFunc(bullet)
		return self:onWallCld(bullet)
	end

	local baseScale = owner:GetTemplate().scale / 50
	local cldData = arg_list.cld_list[1]
	local cldBox = cldData.box
	local cldOffset = Clone(cldData.offset)

	if owner:GetDirection() == ys.Battle.BattleConst.UnitDir.LEFT then
		cldOffset[1] = -cldOffset[1] * baseScale
	else
		cldOffset[1] = cldOffset[1] * baseScale
	end

	self._wall = self._dataProxy:SpawnWall(self, cldFunc, cldBox, cldOffset)

	local fxOffset
	local effectOffsetData = effect_offset[arg_list.effect]

	if effectOffsetData then
		local container_index = effectOffsetData.container_index
		local effectOffsetVector = Vector3(effectOffsetData.offset[1], effectOffsetData.offset[2], effectOffsetData.offset[3])
		local fxContainer = owner:GetTemplate().fx_container[container_index]
		local fxContainerVector = Vector3(fxContainer[1], fxContainer[2], fxContainer[3])

		fxContainerVector:Add(effectOffsetVector)

		fxOffset = fxContainerVector
	end

	if fxOffset then
		function self._centerPosFun(pos)
			local var_4_0
			local centerPos = arg_list.centerPosFun(pos):Add(fxOffset)

			centerPos.x = centerPos.x * self._dir

			return centerPos
		end
	else
		self._centerPosFun = arg_list.centerPosFun
	end

	self._currentTimeCount = 0

	if arg_list.effect then
		self._effectIndex = "BattleBuffShieldWall" .. self._buffID .. self._tempData.id

		local _centerPosFun

		if fxOffset then
			function _centerPosFun(pos)
				local var_5_0

				return (arg_list.centerPosFun(pos):Add(fxOffset))
			end
		else
			_centerPosFun = arg_list.centerPosFun
		end

		self._unit = owner
		self._evtData = {
			effect = arg_list.effect,
			posFun = _centerPosFun,
			index = self._effectIndex,
			rotationFun = arg_list.rotationFun
		}

		owner:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, self._evtData))
	end
end

function BattleBuffShieldWall.onStack(self, owner, buff)
	-- 重复叠加时，刷新护盾墙的持续时间(这是基于Buff的)和碰撞次数
	self._count = self._tempData.arg_list.count

	self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, self._evtData))
end

function BattleBuffShieldWall.onUpdate(self, owner, buff, args)
	local ownerPos = owner:GetPosition()
	local ownerBaseScale = owner:GetTemplate().scale * 0.02
	local timeStamp = args.timeStamp

	if self._centerPosFun then
		self._currentTimeCount = timeStamp - self._startTime
		ownerPos = self._centerPosFun(self._currentTimeCount):Mul(ownerBaseScale):Add(ownerPos)
	end

	self._centerPos = ownerPos
end

function BattleBuffShieldWall.onWallCld(self, bullet)
	-- 子弹不是穿盾的、子弹类型符合要求、碰撞次数还没用完，才会发生护盾墙拦截效果
	if not bullet:GetIgnoreShield() and bullet:GetType() == self._bulletType and self._count > 0 then
		-- intercept: 直接拦截子弹，子弹消失
		if self._doWhenHit == "intercept" then
			bullet:Intercepted()
			self._dataProxy:RemoveBulletUnit(bullet:GetUniqueID())

			self._count = self._count - 1
		-- ;reflect: 反弹子弹，子弹飞回去(但不会伤害自己)
		elseif self._doWhenHit == "reflect" and self:GetIFF() ~= bullet:GetIFF() then
			bullet:Reflected()

			self._count = self._count - 1
		end

		if self._count <= 0 then
			self:Deactive()
		end
	end

	return self._count > 0
end

function BattleBuffShieldWall.GetIFF(self)
	return self._unit:GetIFF()
end

function BattleBuffShieldWall.GetPosition(self)
	return self._centerPos
end

function BattleBuffShieldWall.IsWallActive(self)
	return self._count > 0
end

function BattleBuffShieldWall.Deactive(self)
	if self._effectIndex then
		local deactiveEffectArgs = {
			index = self._effectIndex
		}

		self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.DEACTIVE_EFFECT, deactiveEffectArgs))
	end

	if self._unit:IsAlive() then
		self._unit:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_SHIELD_BROKEN, {
			shieldBuffID = self._buffID
		})
	end
end

function BattleBuffShieldWall.Clear(self)
	if self._effectIndex then
		local cancelEffectArgs = {
			index = self._effectIndex
		}

		self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.CANCEL_EFFECT, cancelEffectArgs))
	end

	self._dataProxy:RemoveWall(self._wall:GetUniqueID())
end
