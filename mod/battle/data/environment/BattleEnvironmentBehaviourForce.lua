ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourForce = class("BattleEnvironmentBehaviourForce", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourForce = BattleEnvironmentBehaviourForce
BattleEnvironmentBehaviourForce.__name = "BattleEnvironmentBehaviourForce"

--- @class BattleEnvironmentBehaviourForce : BattleEnvironmentBehaviour
--- 环境力场行为：沿预设路线匀速移动AOE区域，边界反弹
--- @field _route table 移动路线表（每条: {方向Vector3, 速度, 持续时间}）
--- @field _moveEndTime number 当前段移动结束时间
--- @field _lastSpeed Vector3 上一段速度
--- @field _speed Vector3 当前速度向量
--- @field _targetIndex number 当前路线索引
--- @field _bounds table 碰撞边界 {bottomZ, topZ, leftX, rightX}
function BattleEnvironmentBehaviourForce.Ctor(self)
	self._moveEndTime = nil
	self._lastSpeed = nil
	self._speed = Vector3.zero
	self._targetIndex = 0

	BattleEnvironmentBehaviourForce.super.Ctor(self)
end

--- 读取路线和计算边界（含碰撞数据偏移）
--- @param tmpData table
function BattleEnvironmentBehaviourForce.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourForce.super.SetTemplate(self, tmpData)

	self._route = tmpData.route or {}
	self._moveEndTime = pg.TimeMgr.GetInstance():GetCombatTime()

	local template = self._unit:GetTemplate()
	local cldX
	local cldZ

	if #template.cld_data == 1 then
		cldX = template.cld_data[1]
		cldZ = cldX
	elseif #template.cld_data == 2 then
		cldX, cldZ = unpack(template.cld_data)
	end

	local bounds = {
		ys.Battle.BattleDataProxy.GetInstance():GetTotalBounds()
	}

	bounds[3] = bounds[3] + cldX
	bounds[4] = bounds[4] - cldX
	bounds[2] = bounds[2] + cldZ
	bounds[1] = bounds[1] - cldZ
	self._bounds = bounds
end

--- 每帧推进位置：路线点到达后切换方向和速度，遇边界反弹
function BattleEnvironmentBehaviourForce.doBehaviour(self)
	local now = pg.TimeMgr.GetInstance():GetCombatTime()

	if self._moveEndTime and now >= self._moveEndTime then
		self._targetIndex = self._targetIndex + 1
		self._moveEndTime = nil

		if self._lastSpeed then
			self._speed:Add(self._lastSpeed)

			self._lastSpeed = nil
		end

		local routeEntry = self._route[self._targetIndex]

		if routeEntry then
			self._lastSpeed = Vector3(unpack(routeEntry)):Normalize() * routeEntry[4]
			self._moveEndTime = now + routeEntry[5]
		end
	end

	local position = self._unit._aoeData:GetPosition()
	local newPos = self:UpdateAndRestrictPosition(position)

	self._unit._aoeData:SetPosition(newPos)
	BattleEnvironmentBehaviourForce.super.doBehaviour(self)
end

--- 根据当前速度和边界计算新位置，遇边界则反弹速度方向
--- @param position Vector3 当前位置
--- @return Vector3 限制后的新位置
function BattleEnvironmentBehaviourForce.UpdateAndRestrictPosition(self, position)
	if self._speed:SqrMagnitude() < 0.01 then
		return position
	end

	local bounds = self._bounds
	local newPos = position + self._speed

	if newPos.x < bounds[3] then
		self._speed.x = math.abs(self._speed.x)
		newPos.x = bounds[3] + math.abs(newPos.x - bounds[3])
	elseif bounds[4] < newPos.x then
		self._speed.x = -math.abs(self._speed.x)
		newPos.x = bounds[4] - math.abs(newPos.x - bounds[4])
	end

	if newPos.z < bounds[2] then
		self._speed.z = math.abs(self._speed.z)
		newPos.z = bounds[2] + math.abs(newPos.z - bounds[2])
	elseif bounds[1] < newPos.z then
		self._speed.z = -math.abs(self._speed.z)
		newPos.z = bounds[1] - math.abs(newPos.z - bounds[1])
	end

	return newPos
end

function BattleEnvironmentBehaviourForce.Dispose(self)
	BattleEnvironmentBehaviourForce.super.Dispose(self)
	table.clear(self)
end
