ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleCameraFollowPilot = class("BattleCameraFollowPilot")
ys.Battle.BattleCameraFollowPilot.__name = "BattleCameraFollowPilot"

local BattleCameraFollowPilot = ys.Battle.BattleCameraFollowPilot

--- @class BattleCameraFollowPilot
--- 摄像机跟随舰队
--- 用于让摄像机跟随舰队移动。通过 FleetVO 获取舰队的运动组件，
--- 计算摄像机应处的位置（考虑黄金比例偏移、正常高度和透视修正）。
--- 这是默认的摄像机跟随模式。

--- @return nil
--- 构造函数，初始化零向量缓存点
function BattleCameraFollowPilot.Ctor(self)
	self.point = Vector3.zero
end

--- @param fleetVO BattleFleetVO 要跟随的舰队 VO
--- @return nil
--- 设置要跟随的舰队 VO，获取其运动组件
function BattleCameraFollowPilot.SetFleetVO(self, fleetVO)
	self._fleetMotion = fleetVO:GetMotion()
end

--- @param goldenOffset number 黄金比例横向偏移值
--- @return nil
--- 设置黄金比例偏移量（用于将舰队置于屏幕黄金比例位置）
--- 该值通过屏幕宽度 * 0.618 计算得出，并被转换为世界坐标偏移
function BattleCameraFollowPilot.SetGoldenRation(self, goldenOffset)
	self._cameraGoldenOffset = goldenOffset
end

--- @return Vector3 跟随舰队的摄像机位置
--- 获取跟随舰队时的摄像机位置
--- 取舰队位置 + 黄金比例偏移 + 正常高度，再根据透视修正 z 轴
function BattleCameraFollowPilot.GetCameraPos(self)
	local fleetPos = self.point:Copy(self._fleetMotion:GetPos())

	-- x 轴叠加黄金比例偏移，使舰队位于画面视觉重心
	fleetPos.x = fleetPos.x + self._cameraGoldenOffset
	-- y 轴抬高到正常观察高度
	fleetPos.y = fleetPos.y + BattleVariable.CameraNormalHeight
	-- 根据高度进行透视修正：z 轴后退
	fleetPos.z = fleetPos.z - fleetPos.y / BattleVariable._camera_radian_x_tan

	return fleetPos
end

--- @return nil
--- 清理函数
function BattleCameraFollowPilot.Dispose(self)
	self._fleetMotion = nil
end
