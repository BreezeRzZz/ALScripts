ys = ys or {}

local ys = ys

ys.Battle.BattleCloakBar = class("BattleCloakBar")
ys.Battle.BattleCloakBar.__name = "BattleCloakBar"

local BattleCloakBar = ys.Battle.BattleCloakBar

-- ============================================================
-- 隐身条常量
-- ============================================================
--- 雷达样式（弧形进度条）
BattleCloakBar.FORM_RAD = "radian"
--- 横条样式（水平进度条）
BattleCloakBar.FORM_BAR = "bar"

-- 雷达式进度条参数
--- 进度条最小填充量
BattleCloakBar.MIN = 0.31
--- 进度条最大填充量
BattleCloakBar.MAX = 0.69
--- 刻度总长度
BattleCloakBar.METER_LENGTH = BattleCloakBar.MAX - BattleCloakBar.MIN
--- 恢复标记最小角度（度）
BattleCloakBar.MIN_ANGLE = -31
--- 恢复标记最大角度（度）
BattleCloakBar.MAX_ANGLE = 33
--- 恢复标记角度范围
BattleCloakBar.RESTORE_LEGHTH = BattleCloakBar.MAX_ANGLE - BattleCloakBar.MIN_ANGLE

-- 条形进度条参数
--- 横条左边界
BattleCloakBar.BAR_MIN = -62
--- 横条右边界
BattleCloakBar.BAR_MAX = 62
--- 横条总宽度
BattleCloakBar.BAR_STEP = BattleCloakBar.BAR_MAX - BattleCloakBar.BAR_MIN

--- ============================================================
--- 预设缩放常量（用于隐身条左右朝向翻转）
--- ============================================================
--- 横条左侧翻转（x=-1, 镜像）
local FLIP_LEFT = Vector3.New(-1, 1, 1)
--- 标记容器居中偏左翻转
local FLIP_MARK_LEFT = Vector3.New(-0.5, 0.5, 1)
--- 标记容器居中偏右翻转
local FLIP_MARK_RIGHT = Vector3.New(0.5, 0.5, 1)

--- @class BattleCloakBar
--- 隐身/潜行状态条视图
--- 支持两种显示模式：FORM_RAD（弧形进度条）和FORM_BAR（水平横条）
--- 显示内容：
---   - progress: 当前隐身值进度
---   - lock: 锁定进度（不可恢复的底部值）
---   - restoreMark: 恢复目标标记
---   - exposeFX/标记: 暴露状态视觉效果
--- @param cloakBar Transform 隐身条Transform
--- @param formType string [optional] 显示模式，默认FORM_RAD
function BattleCloakBar.Ctor(self, cloakBar, formType)
	formType = formType or BattleCloakBar.FORM_RAD
	self._cloakBar = cloakBar
	self._cloakBarGO = self._cloakBar.gameObject
	self._progress = self._cloakBar:Find("progress"):GetComponent(typeof(Image))
	self._restoreMark = self._cloakBar:Find("cloak_restore")
	self._lockProgress = self._cloakBar:Find("lock"):GetComponent(typeof(Image))
	self._exposeFX = self._cloakBar:Find("top_effect")
	self._markContainer = self._cloakBar:Find("mark")
	self._exposeMark = self._cloakBar:Find("mark/2")
	self._visionMark = self._cloakBar:Find("mark/1")

	setActive(self._cloakBar, true)
	setActive(self._exposeFX, false)
	setActive(self._exposeMark, false)
	setActive(self._visionMark, false)

	-- 根据模式绑定对应的转换函数
	if formType == BattleCloakBar.FORM_RAD then
		self._restoreMark.localRotation = Vector3(0, 0, 0)
		self.meterConvert = BattleCloakBar.__radMeterConvert
		self.restoreConvert = BattleCloakBar.__radRestoreConvert
	else
		self.meterConvert = BattleCloakBar.__barMeterConvert
		self.restoreConvert = BattleCloakBar.__barRestoreConvert
	end
end

--- 激活/隐藏隐身条
--- @param isActive boolean
function BattleCloakBar.SetActive(self, isActive)
	setActive(self._cloakBar, isActive)
end

--- 绑定隐身组件
--- @param cloakComponent BattleUnitCloakComponent
function BattleCloakBar.ConfigCloak(self, cloakComponent)
	self._cloakComponent = cloakComponent

	self:initCloak()
end

--- 每帧更新隐身值进度条和暴露状态视觉效果
--- 根据当前隐身状态（STATE_CLOAK/STATE_UNCLOAK）控制exposeFX的显隐
--- 根据暴露速度控制exposeMark/visionMark的显隐
function BattleCloakBar.UpdateCloakProgress(self)
	local cloakRatio = self._cloakComponent:GetCloakValue() / self._meterMaxValue

	self._progress.fillAmount = self.meterConvert(cloakRatio)

	local currentState = self._cloakComponent:GetCurrentState()

	-- 隐身中：隐藏暴露特效
	if currentState == ys.Battle.BattleUnitCloakComponent.STATE_CLOAK then
		setActive(self._exposeFX, false)
	elseif currentState == ys.Battle.BattleUnitCloakComponent.STATE_UNCLOAK then
		setActive(self._exposeFX, true)
	end

	-- 根据暴露状态和速度控制标记
	if currentState == ys.Battle.BattleUnitCloakComponent.STATE_UNCLOAK then
		setActive(self._exposeMark, true)
		setActive(self._visionMark, false)
	elseif self._cloakComponent:GetExposeSpeed() > 0 then
		-- 正在暴露中
		setActive(self._exposeMark, false)
		setActive(self._visionMark, true)
	else
		setActive(self._exposeMark, false)
		setActive(self._visionMark, false)
	end
end

--- 更新隐身条屏幕位置，根据角色x坐标决定左右翻转
--- x < 0 时条在角色右侧，x > 0 时条翻转到左侧（避免遮挡角色）
--- @param worldPos Vector3 角色世界坐标
function BattleCloakBar.UpdateCloarBarPosition(self, worldPos)
	if worldPos.x < 0 then
		-- 角色在左侧，进度条在右侧
		self._cloakBar.position = worldPos + Vector3.right
		self._cloakBar.localScale = Vector3.one
		self._markContainer.localScale = FLIP_MARK_RIGHT
	else
		-- 角色在右侧，进度条翻转到左侧
		self._cloakBar.position = worldPos + Vector3.left
		self._cloakBar.localScale = FLIP_LEFT
		self._markContainer.localScale = FLIP_MARK_LEFT
	end
end

--- 更新隐身配置（重新初始化）
function BattleCloakBar.UpdateCloakConfig(self)
	self:initCloak()
end

--- 更新锁定进度（隐身值不可恢复的下限）
function BattleCloakBar.UpdateCloakLock(self)
	local lockRatio = self._cloakComponent:GetCloakBottom() / self._meterMaxValue

	self._lockProgress.fillAmount = self.meterConvert(lockRatio)
end

--- 初始化隐身值相关参数
function BattleCloakBar.initCloak(self)
	self._meterMaxValue = self._cloakComponent:GetCloakMax()

	self:updateRestoreMark()
end

--- 更新恢复标记位置（显示隐身值恢复到哪个值）
function BattleCloakBar.updateRestoreMark(self)
	local restoreRatio = self._cloakComponent:GetCloakRestoreValue() / self._meterMaxValue

	self.restoreConvert(restoreRatio, self._restoreMark)
end

--- 雷达式进度条转换：隐身率 -> fillAmount
--- [0, 1] -> [MIN, MAX] (0.31 ~ 0.69)
--- @param ratio number 0~1
--- @return number fillAmount
function BattleCloakBar.__radMeterConvert(ratio)
	return BattleCloakBar.METER_LENGTH * ratio + BattleCloakBar.MIN
end

--- 雷达式恢复标记转换：隐身率 -> 旋转角度
--- [0, 1] -> [MIN_ANGLE, MAX_ANGLE] (-31 ~ 33)
--- @param ratio number 0~1
--- @param targetTF Transform 恢复标记Transform
function BattleCloakBar.__radRestoreConvert(ratio, targetTF)
	local angle = BattleCloakBar.RESTORE_LEGHTH * ratio + BattleCloakBar.MIN_ANGLE

	targetTF.localRotation = Quaternion.Euler(0, 0, angle)
end

--- 横条式进度条转换：隐身率 -> 直接透传
--- @param ratio number
--- @return number
function BattleCloakBar.__barMeterConvert(ratio)
	return ratio
end

--- 横条式恢复标记转换：隐身率 -> 水平位移
--- [0, 1] -> [BAR_MIN, BAR_MAX] (-62 ~ 62)
--- @param ratio number 0~1
--- @param targetTF Transform 恢复标记Transform
function BattleCloakBar.__barRestoreConvert(ratio, targetTF)
	local posX = BattleCloakBar.BAR_STEP * ratio + BattleCloakBar.BAR_MIN

	targetTF.localPosition = Vector3(posX, 0, 0)
end

--- 销毁隐身条
function BattleCloakBar.Dispose(self)
	self._cloakComponent = nil
	self._cloakBar = nil
	self._progress = nil
	self._restoreMark = nil
	self._exposeFX = nil

	Object.Destroy(self._cloakBarGO)

	self._cloakBarGO = nil
end
