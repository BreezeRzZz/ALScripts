ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleBuffAddAdditiveSpeed = class("BattleBuffAddAdditiveSpeed", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddAdditiveSpeed = BattleBuffAddAdditiveSpeed
BattleBuffAddAdditiveSpeed.__name = "BattleBuffAddAdditiveSpeed"

function BattleBuffAddAdditiveSpeed.Ctor(self, effectData)
	BattleBuffAddAdditiveSpeed.super.Ctor(self, effectData)
end

function BattleBuffAddAdditiveSpeed.SetArgs(self, owner, buff)
	-- 指的是黑洞的中心位置，往这个位置吸引
	self._singularity = self._tempData.arg_list.singularity or {
		x = 0,
		z = 0
	}
	-- 主要决定施法者会不会影响黑洞的位置
	self._casterGravity = self._tempData.arg_list.gravitationalCaster
	-- 牵引力
	self._force = self._tempData.arg_list.force
	-- 从下面逻辑来看，这个参数决定牵引力是否随距离变化而变化
	self._forceScalteRate = self._tempData.arg_list.scale_rate

	if not self._casterGravity then
		self._staticSingularity = Vector3.New(self._singularity.x, 0, self._singularity.z)
	else
		-- 如果有casterGravity，根据阵营调整黑洞位置
		local iff = buff:GetCaster():GetIFF()

		self._singularityOffset = Vector3.New(self._singularity.x * iff, 0, self._singularity.z)
	end
end

--- @class BattleBuffAddAdditiveSpeed
--- @param owner BattleUnit: 这里指的是被Buff作用的单位
--- @param buff BattleBuffUnit
--- @return nil
function BattleBuffAddAdditiveSpeed.onUpdate(self, owner, buff)
	local singularity

	if self._casterGravity then
		singularity = buff:GetCaster():GetPosition() + self._singularityOffset
	else
		singularity = self._staticSingularity
	end
	-- 计算从单位位置到黑洞中心的向量
	local vector = pg.Tool.FilterY(singularity - owner:GetPosition())
	-- 归一化作为方向
	local direction = vector.normalized
	-- 牵引力数值
	local force = self._force
	-- 距离
	local distance = vector.magnitude

	-- 如果距离很近了，基本不再牵引
	if distance < 2 then
		force = 1e-08
	elseif self._forceScalteRate then
		-- 取min(distance, force/distance)作为牵引力，距离越远牵引力越小
		force = math.min(distance, 1 / distance * force)
	end
	-- 每帧的牵引速度增量
	-- 注：碧蓝航线的"力"是简化的实现，直接改变速度，不是通过加速度来改变速度
	-- 虽然游戏内也确实有加速度机制，但加速度一般是设定的恒定值，与力无关
	local additiveSpeed = direction * force

	owner:SetAdditiveSpeed(additiveSpeed)
end

function BattleBuffAddAdditiveSpeed.onRemove(self, owner, buff)
	owner:RemoveAdditiveSpeed()
end
