ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleOpticalSightView = class("BattleOpticalSightView")

local BattleOpticalSightView = ys.Battle.BattleOpticalSightView

BattleOpticalSightView.__name = "BattleOpticalSightView"
-- 跨射瞄准镜的三种常量（来自ChargeWeaponConfig）
BattleOpticalSightView.SIGHT_A = BattleConfig.ChargeWeaponConfig.SIGHT_A
BattleOpticalSightView.SIGHT_B = BattleConfig.ChargeWeaponConfig.SIGHT_B
BattleOpticalSightView.SIGHT_C = BattleConfig.ChargeWeaponConfig.SIGHT_C

--- 跨射/炮击瞄准镜视图
--- 显示瞄准镜UI，跟随舰队位置并受边界限制
--- @param goTF Transform 瞄准镜父物体的Transform
function BattleOpticalSightView.Ctor(self, goTF)
	self._sightTF = goTF:Find("Sight")
	self._rulerTF = goTF:Find("Ruler")
	self._cornerTF = goTF:Find("Corners")
	self._active = false
end

--- 设置瞄准镜的活动区域边界
--- @param leftBound number 左边界X
--- @param rightBound number 右边界X
function BattleOpticalSightView.SetAreaBound(self, leftBound, rightBound)
	self._totalLeftBound = leftBound
	self._totalRightBound = rightBound
end

--- 显示/隐藏瞄准镜
--- @param isActive boolean
function BattleOpticalSightView.SetActive(self, isActive)
	self._active = isActive

	SetActive(self._sightTF, isActive)
	SetActive(self._rulerTF, isActive)
	SetActive(self._cornerTF, isActive)
end

--- 更新瞄准镜的位置（跟随舰队移动，受边界限制）
function BattleOpticalSightView.Update(self)
	if not self._active then
		return
	end

	-- 基于舰队X位置 + SIGHT_C偏移计算瞄准位置
	local targetX = self._fleetVO:GetMotion():GetPos().x + BattleOpticalSightView.SIGHT_C
	local clampedX = math.min(targetX, self._totalRightBound)
	-- 将3D坐标转换为UI坐标
	local uiPos = ys.Battle.BattleVariable.CameraPosToUICamera(Vector3.New(clampedX, 0, 5 + self._fleetVO:GetMotion():GetPos().z))

	self._sightTF.position = uiPos

	-- 标尺只跟随Y位置
	local rulerPos = Vector3.New(0, uiPos.y)

	self._rulerTF.position = rulerPos
end

--- 设置要跟踪的舰队VO
--- @param fleetVO table 舰队VO对象
function BattleOpticalSightView.SetFleetVO(self, fleetVO)
	self._fleetVO = fleetVO
end

--- 清理引用
function BattleOpticalSightView.Dispose(self)
	self._sightTF = nil
	self._rulerTF = nil
	self._cornerTF = nil
	self._fleetVO = nil
end
