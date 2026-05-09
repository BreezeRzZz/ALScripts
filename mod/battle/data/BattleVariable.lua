ys = ys or {}

local ys = ys

ys.Battle.BattleVariable = ys.Battle.BattleVariable or {}

local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig

--- 初始化战斗变量（速度倍率、摄像机参数等）
--- @param headlessFlag boolean: 是否为无头模式（不激活摄像机）
function BattleVariable.Init(headlessFlag)
	BattleVariable.speedRatioByIFF = {
		[0] = 1,
		1,
		[-1] = 1
	}
	BattleVariable.focusExemptList = {}
	BattleVariable.MapSpeedRatio = 1
	BattleVariable.MapSpeedFacotrList = {}
	BattleVariable.IFFFactorList = {}

	for iff, _ in pairs(BattleVariable.speedRatioByIFF) do
		BattleVariable.IFFFactorList[iff] = {}
	end

	BattleVariable._lastCameraPos = nil

	local mainCamera = pg.UIMgr.GetInstance():GetMainCamera()

	if not headlessFlag then
		setActive(mainCamera, true)
	end

	BattleVariable._camera = mainCamera:GetComponent(typeof(Camera))
	BattleVariable._cameraTF = BattleVariable._camera.transform
	BattleVariable._uiCamera = GameObject.Find("UICamera"):GetComponent(typeof(Camera))

	local cameraRadianX = math.deg2Rad * BattleVariable._cameraTF.localEulerAngles.x

	BattleVariable._camera_radian_x_sin = math.sin(cameraRadianX)
	BattleVariable._camera_radian_x_cos = math.cos(cameraRadianX)
	BattleVariable._camera_radian_x_tan = BattleVariable._camera_radian_x_sin / BattleVariable._camera_radian_x_cos
	BattleVariable.CameraNormalHeight = BattleVariable._camera_radian_x_cos * BattleConfig.CAMERA_SIZE + BattleConfig.CAMERA_BASE_HEIGH
	BattleVariable.CameraFocusHeight = BattleVariable._camera_radian_x_cos * BattleConfig.CAST_CAM_ZOOM_SIZE + BattleConfig.CAMERA_BASE_HEIGH
end

--- 清除所有战斗变量
function BattleVariable.Clear()
	BattleVariable.speedRatioByIFF = nil
	BattleVariable.focusExemptList = nil
	BattleVariable.MapSpeedRatio = nil
	BattleVariable.MapSpeedFacotrList = nil
	BattleVariable.IFFFactorList = nil
	BattleVariable._lastCameraPos = nil
	BattleVariable._camera = nil
	BattleVariable._cameraTF = nil
	BattleVariable._uiCamera = nil
	BattleVariable._camera_radian_x_sin = nil
	BattleVariable._camera_radian_x_cos = nil
	BattleVariable._camera_radian_x_tan = nil
	BattleVariable.CameraNormalHeight = nil
	BattleVariable.CameraFocusHeight = nil
end

-- 摄像机投影变换缓存变量
-- 战斗场景坐标 → UI摄像机坐标的变换参数
local cameraLeftX = 0           -- 战斗摄像机左下角世界坐标X
local uiCameraLeftX = 0        -- UI摄像机左下角世界坐标X
local uiToCameraScaleX = 0     -- UI摄像机→战斗摄像机X轴缩放比
local cameraLeftY = 0          -- 战斗摄像机左下角世界坐标Y（投影后）
local uiCameraLeftY = 0        -- UI摄像机左下角世界坐标Y
local uiToCameraScaleY = 0     -- UI摄像机→战斗摄像机Y轴缩放比

--- 更新摄像机位置参数（计算坐标变换缓存）
--- 在每帧渲染前调用，用于将战斗场景坐标映射到UI坐标
function BattleVariable.UpdateCameraPositionArgs()
	local cameraPos = BattleVariable._cameraTF.position
	local cameraOrthoSize = CameraMgr.instance:GetCameraOrthographicSize(BattleVariable._camera)

	if BattleVariable._lastCameraPos == cameraPos and BattleVariable._lastCameraSize == cameraOrthoSize then
		return
	else
		BattleVariable._lastCameraPos = cameraPos
		BattleVariable._lastCameraSize = cameraOrthoSize
	end

	local cameraFixMgr = pg.CameraFixMgr.GetInstance()
	local cameraBottomLeft = BattleVariable._camera:ScreenToWorldPoint(cameraFixMgr.leftBottomVector)
	local cameraTopRight = BattleVariable._camera:ScreenToWorldPoint(cameraFixMgr.rightTopVector)
	local uiCameraBottomLeft = BattleVariable._uiCamera:ScreenToWorldPoint(cameraFixMgr.leftBottomVector)
	local uiCameraTopRight = BattleVariable._uiCamera:ScreenToWorldPoint(cameraFixMgr.rightTopVector)

	cameraLeftX = cameraBottomLeft.x
	uiCameraLeftX = uiCameraBottomLeft.x
	uiToCameraScaleX = (uiCameraTopRight.x - uiCameraBottomLeft.x) / (cameraTopRight.x - cameraBottomLeft.x)

	-- 将Y轴投影（等轴测视角：cos(30°)=0.866, sin(30°)=0.5）
	local cameraBottomLeftY = cameraBottomLeft.y * 0.866 + cameraBottomLeft.z * 0.5
	local cameraTopRightY = cameraTopRight.y * 0.866 + cameraTopRight.z * 0.5

	cameraLeftY = cameraBottomLeftY
	uiCameraLeftY = uiCameraBottomLeft.y
	uiToCameraScaleY = (uiCameraTopRight.y - uiCameraBottomLeft.y) / (cameraTopRightY - cameraBottomLeftY)
end

--- 将战斗场景坐标转换为UI摄像机坐标（返回新Vector3）
--- @param scenePos Vector3: 战斗场景坐标
--- @return Vector3: UI摄像机坐标
function BattleVariable.CameraPosToUICamera(scenePos)
	BattleVariable.CameraPosToUICameraByRef(scenePos)

	return scenePos
end

--- 将战斗场景坐标转换为UI摄像机坐标（原地修改引用）
--- @param scenePos Vector3: 战斗场景坐标（原地修改）
function BattleVariable.CameraPosToUICameraByRef(scenePos)
	local uiX = (scenePos.x - cameraLeftX) * uiToCameraScaleX + uiCameraLeftX

	scenePos.y, scenePos.x = (scenePos.y * 0.866 + scenePos.z * 0.5 - cameraLeftY) * uiToCameraScaleY + uiCameraLeftY, uiX
	scenePos.z = 0
end

--- 将UI屏幕坐标转换为战斗场景坐标
--- @param screenPos Vector2: UI屏幕坐标
--- @param outPos Vector3: 输出的战斗场景坐标
function BattleVariable.UIPosToScenePos(screenPos, outPos)
	local cameraFixMgr = pg.CameraFixMgr.GetInstance()
	local screenWidth = cameraFixMgr:GetCurrentWidth()
	local screenHeight = cameraFixMgr:GetCurrentHeight()
	local widthScale = screenWidth / 1920
	local heightScale = screenHeight / 1080

	screenPos = Vector2(widthScale * screenPos.x, heightScale * screenPos.y)

	local uiWorldPos = BattleVariable._uiCamera:ScreenToWorldPoint(screenPos)
	local sceneX = (uiWorldPos.x - uiCameraLeftX) / uiToCameraScaleX + cameraLeftX
	local sceneY = (uiWorldPos.y - uiCameraLeftY) / uiToCameraScaleY + cameraLeftY
	local tan30 = math.tan(30 * Mathf.Deg2Rad)
	local sceneZ = sceneY / tan30 + sceneY * tan30 * 0.5

	outPos:Set(sceneX, 0, sceneZ)
end

--- 添加地图速度因子
--- @param factorKey string: 速度因子唯一标识
--- @param factorValue number: 速度因子值
function BattleVariable.AppendMapFactor(factorKey, factorValue)
	if BattleVariable.MapSpeedFacotrList[factorKey] ~= nil then
		BattleVariable.RemoveMapFactor(factorKey)
	end

	BattleVariable.MapSpeedRatio = BattleVariable.MapSpeedRatio * factorValue
	BattleVariable.MapSpeedFacotrList[factorKey] = factorValue
end

--- 移除地图速度因子
--- @param factorKey string: 要移除的速度因子标识
function BattleVariable.RemoveMapFactor(factorKey)
	local factorValue = BattleVariable.MapSpeedFacotrList[factorKey]

	if factorValue ~= nil then
		BattleVariable.MapSpeedRatio = BattleVariable.MapSpeedRatio / factorValue
		BattleVariable.MapSpeedFacotrList[factorKey] = nil
	end
end

--- 为指定阵营添加速度倍率因子
--- @param iff number: 阵营
--- @param factorKey string: 因子标识
--- @param factorValue number: 速度倍率
function BattleVariable.AppendIFFFactor(iff, factorKey, factorValue)
	local iffFactorList = BattleVariable.IFFFactorList[iff]

	if iffFactorList[factorKey] ~= nil then
		BattleVariable.RemoveIFFFactor(iff, factorKey)
	end

	BattleVariable.speedRatioByIFF[iff] = BattleVariable.speedRatioByIFF[iff] * factorValue
	iffFactorList[factorKey] = factorValue
	BattleVariable.focusExemptList = {}
end

--- 移除指定阵营的速度倍率因子
--- @param iff number: 阵营
--- @param factorKey string: 因子标识
function BattleVariable.RemoveIFFFactor(iff, factorKey)
	local iffFactorList = BattleVariable.IFFFactorList[iff]
	local factorValue = iffFactorList[factorKey]

	if factorValue ~= nil then
		BattleVariable.speedRatioByIFF[iff] = BattleVariable.speedRatioByIFF[iff] / factorValue
		iffFactorList[factorKey] = nil
		BattleVariable.focusExemptList = {}
	end
end

--- 获取指定单位的速度倍率
--- @param exemptKey string: 速度豁免键
--- @param iff number: 阵营
--- @return number: 速度倍率
function BattleVariable.GetSpeedRatio(exemptKey, iff)
	return BattleVariable.focusExemptList[exemptKey] or BattleVariable.speedRatioByIFF[iff]
end

-- 应该用于子弹时间时，时间流速变慢，动画速度不变之类的
--- @param exemptKey string: 豁免键
--- @param IFF number: 阵营
--- @param speedFactor string: 速度因子标识
function BattleVariable.AddExempt(exemptKey, IFF, speedFactor)
	local speed = BattleVariable.IFFFactorList[IFF][speedFactor]

	if speed ~= nil then
		BattleVariable.focusExemptList[exemptKey] = BattleVariable.speedRatioByIFF[IFF] / speed
	end
end
