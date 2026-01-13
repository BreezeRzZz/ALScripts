ys = ys or {}

local ys = ys

ys.Battle.BattleVariable = ys.Battle.BattleVariable or {}

local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig
-- TODO
function BattleVariable.Init(arg_1_0)
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

	if not arg_1_0 then
		setActive(mainCamera, true)
	end

	BattleVariable._camera = mainCamera:GetComponent(typeof(Camera))
	BattleVariable._cameraTF = BattleVariable._camera.transform
	BattleVariable._uiCamera = GameObject.Find("UICamera"):GetComponent(typeof(Camera))

	local var_1_1 = math.deg2Rad * BattleVariable._cameraTF.localEulerAngles.x

	BattleVariable._camera_radian_x_sin = math.sin(var_1_1)
	BattleVariable._camera_radian_x_cos = math.cos(var_1_1)
	BattleVariable._camera_radian_x_tan = BattleVariable._camera_radian_x_sin / BattleVariable._camera_radian_x_cos
	BattleVariable.CameraNormalHeight = BattleVariable._camera_radian_x_cos * BattleConfig.CAMERA_SIZE + BattleConfig.CAMERA_BASE_HEIGH
	BattleVariable.CameraFocusHeight = BattleVariable._camera_radian_x_cos * BattleConfig.CAST_CAM_ZOOM_SIZE + BattleConfig.CAMERA_BASE_HEIGH
end

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

local var_0_3 = 0
local var_0_4 = 0
local var_0_5 = 0
local var_0_6 = 0
local var_0_7 = 0
local var_0_8 = 0

function BattleVariable.UpdateCameraPositionArgs()
	local var_3_0 = BattleVariable._cameraTF.position
	local var_3_1 = CameraMgr.instance:GetCameraOrthographicSize(BattleVariable._camera)

	if BattleVariable._lastCameraPos == var_3_0 and BattleVariable._lastCameraSize == var_3_1 then
		return
	else
		BattleVariable._lastCameraPos = var_3_0
		BattleVariable._lastCameraSize = var_3_1
	end

	local var_3_2 = pg.CameraFixMgr.GetInstance()
	local var_3_3 = BattleVariable._camera:ScreenToWorldPoint(var_3_2.leftBottomVector)
	local var_3_4 = BattleVariable._camera:ScreenToWorldPoint(var_3_2.rightTopVector)
	local var_3_5 = BattleVariable._uiCamera:ScreenToWorldPoint(var_3_2.leftBottomVector)
	local var_3_6 = BattleVariable._uiCamera:ScreenToWorldPoint(var_3_2.rightTopVector)

	var_0_3 = var_3_3.x
	var_0_4 = var_3_5.x
	var_0_5 = (var_3_6.x - var_3_5.x) / (var_3_4.x - var_3_3.x)

	local var_3_7 = var_3_3.y * 0.866 + var_3_3.z * 0.5
	local var_3_8 = var_3_4.y * 0.866 + var_3_4.z * 0.5

	var_0_6 = var_3_7
	var_0_7 = var_3_5.y
	var_0_8 = (var_3_6.y - var_3_5.y) / (var_3_8 - var_3_7)
end

function BattleVariable.CameraPosToUICamera(arg_4_0)
	BattleVariable.CameraPosToUICameraByRef(arg_4_0)

	return arg_4_0
end

function BattleVariable.CameraPosToUICameraByRef(arg_5_0)
	local var_5_0 = (arg_5_0.x - var_0_3) * var_0_5 + var_0_4

	arg_5_0.y, arg_5_0.x = (arg_5_0.y * 0.866 + arg_5_0.z * 0.5 - var_0_6) * var_0_8 + var_0_7, var_5_0
	arg_5_0.z = 0
end

function BattleVariable.UIPosToScenePos(arg_6_0, arg_6_1)
	local var_6_0 = pg.CameraFixMgr.GetInstance()
	local var_6_1 = var_6_0:GetCurrentWidth()
	local var_6_2 = var_6_0:GetCurrentHeight()
	local var_6_3 = var_6_1 / 1920
	local var_6_4 = var_6_2 / 1080

	arg_6_0 = Vector2(var_6_3 * arg_6_0.x, var_6_4 * arg_6_0.y)

	local var_6_5 = BattleVariable._uiCamera:ScreenToWorldPoint(arg_6_0)
	local var_6_6 = (var_6_5.x - var_0_4) / var_0_5 + var_0_3
	local var_6_7 = (var_6_5.y - var_0_7) / var_0_8 + var_0_6
	local var_6_8 = math.tan(30 * Mathf.Deg2Rad)
	local var_6_9 = var_6_7 / var_6_8 + var_6_7 * var_6_8 * 0.5

	arg_6_1:Set(var_6_6, 0, var_6_9)
end

function BattleVariable.AppendMapFactor(arg_7_0, arg_7_1)
	if BattleVariable.MapSpeedFacotrList[arg_7_0] ~= nil then
		BattleVariable.RemoveMapFactor(arg_7_0)
	end

	BattleVariable.MapSpeedRatio = BattleVariable.MapSpeedRatio * arg_7_1
	BattleVariable.MapSpeedFacotrList[arg_7_0] = arg_7_1
end

function BattleVariable.RemoveMapFactor(arg_8_0)
	local var_8_0 = BattleVariable.MapSpeedFacotrList[arg_8_0]

	if var_8_0 ~= nil then
		BattleVariable.MapSpeedRatio = BattleVariable.MapSpeedRatio / var_8_0
		BattleVariable.MapSpeedFacotrList[arg_8_0] = nil
	end
end

function BattleVariable.AppendIFFFactor(arg_9_0, arg_9_1, arg_9_2)
	local var_9_0 = BattleVariable.IFFFactorList[arg_9_0]

	if var_9_0[arg_9_1] ~= nil then
		BattleVariable.RemoveIFFFactor(arg_9_0, arg_9_1)
	end

	BattleVariable.speedRatioByIFF[arg_9_0] = BattleVariable.speedRatioByIFF[arg_9_0] * arg_9_2
	var_9_0[arg_9_1] = arg_9_2
	BattleVariable.focusExemptList = {}
end

function BattleVariable.RemoveIFFFactor(arg_10_0, arg_10_1)
	local var_10_0 = BattleVariable.IFFFactorList[arg_10_0]
	local var_10_1 = var_10_0[arg_10_1]

	if var_10_1 ~= nil then
		BattleVariable.speedRatioByIFF[arg_10_0] = BattleVariable.speedRatioByIFF[arg_10_0] / var_10_1
		var_10_0[arg_10_1] = nil
		BattleVariable.focusExemptList = {}
	end
end

function BattleVariable.GetSpeedRatio(arg_11_0, arg_11_1)
	return BattleVariable.focusExemptList[arg_11_0] or BattleVariable.speedRatioByIFF[arg_11_1]
end

-- 应该是用于子弹时间时，时间流速变慢，动画速度不变之类的
function BattleVariable.AddExempt(exemptKey, IFF, speedFactor)
	local speed = BattleVariable.IFFFactorList[IFF][speedFactor]

	if speed ~= nil then
		BattleVariable.focusExemptList[exemptKey] = BattleVariable.speedRatioByIFF[IFF] / speed
	end
end
