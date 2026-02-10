ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleCldComponent = class("BattleCldComponent")

ys.Battle.BattleCldComponent = BattleCldComponent
BattleCldComponent.__name = "BattleCldComponent"

function BattleCldComponent.Ctor(self)
	return
end

function BattleCldComponent.SetActive(self, active)
	self._cldData.Active = active
end

function BattleCldComponent.SetImmuneCLD(self, immuneCLD)
	self._cldData.ImmuneCLD = immuneCLD
end

function BattleCldComponent.SetCldData(self, cldData)
	self._cldData = cldData
	self._cldData.distList = {}
	self._cldData.Active = false
	self._cldData.ImmuneCLD = false
	self._cldData.FriendlyCld = false
	self._cldData.Surface = BattleConst.OXY_STATE.FLOAT
	self._box.data = cldData
end

function BattleCldComponent.ActiveFriendlyCld(self)
	self._cldData.FriendlyCld = true
end

function BattleCldComponent.GetCldData(self)
	return self._cldData
end

function BattleCldComponent.GetCldBox(self, position)
	assert(false, "BattleCldComponent.GetCldBox:重写这个方法啦！")
end

function BattleCldComponent.GetCldBoxSize(self)
	assert(false, "BattleCldComponent.GetCldBoxSize:重写这个方法啦！")

	return nil
end

function BattleCldComponent.FixSpeed(self, speed)
	if not self._cldData.FriendlyCld then
		return
	end

	if #self._cldData.distList == 0 then
		return
	end

	if speed.x == 0 and speed.z == 0 then
		self:HandleStaticCld(speed)
	else
		self:HandleDynamicCld(speed)
	end
end

-- 动态碰撞(速度不为0)
-- 让速度为0
function BattleCldComponent.HandleDynamicCld(self, speed)
	local cldX = false
	local cldZ = false

	for _, dist in ipairs(self._cldData.distList) do
		local distX = dist.x

		if not cldX and distX * math.abs(speed.x) / speed.x < 0 then
			speed.x = 0
			cldX = true
		end

		local distZ = dist.z

		if not cldZ and distZ * math.abs(speed.z) / speed.z < 0 then
			speed.z = 0
			cldZ = true
		end

		if cldX and cldZ then
			return
		end
	end
end

-- 静态碰撞(速度为0)
-- 反而会提供一个方向的速度，帮助舰船脱离碰撞
function BattleCldComponent.HandleStaticCld(self, speed)
	local dist = self._cldData.distList[1]
	local dir = Vector3(dist.x, 0, dist.z).normalized

	speed.x = ys.Battle.BattleFormulas.ConvertShipSpeed(dir.x)
	speed.z = ys.Battle.BattleFormulas.ConvertShipSpeed(dir.z)
end
