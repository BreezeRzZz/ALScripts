ys = ys or {}

local ys = ys
local BattleMap = class("BattleMap")

ys.Battle.BattleMap = BattleMap
BattleMap.__name = "BattleMap"

local map_data = pg.map_data

BattleMap.LAYERS = {
	"close",
	"mid",
	"long",
	"sky",
	"sea"
}

function BattleMap.Ctor(arg_1_0, arg_1_1)
	arg_1_0._go = GameObject.New("scenes")
	arg_1_0.mapLayerCtrls = {}
	arg_1_0.seaAnimList = {}

	local var_1_0 = pg.map_data[arg_1_1]

	assert(var_1_0, "找不到地图: " .. arg_1_1)

	for iter_1_0, iter_1_1 in ipairs(BattleMap.LAYERS) do
		local var_1_1 = GameObject.New(iter_1_1 .. "Layer")

		setParent(var_1_1, arg_1_0._go, false)

		if iter_1_1 ~= "sky" then
			local var_1_2 = GetOrAddComponent(var_1_1, "MapLayerCtrl")

			var_1_2.leftBorder = var_1_0.range_left
			var_1_2.rightBorder = var_1_0.range_right
			var_1_2.speedToLeft = var_1_0[iter_1_1 .. "_speed"] or 0
			var_1_2.speedScaler = 1
			var_1_2.mainCamera = pg.UIMgr.GetInstance().mainCameraComp

			table.insert(arg_1_0.mapLayerCtrls, var_1_2)
		end

		local var_1_3 = arg_1_0.GetMapResNames(arg_1_1, iter_1_1)
		local var_1_4 = string.split(var_1_0[iter_1_1 .. "_pos"], ";")
		local var_1_5 = string.split(var_1_0[iter_1_1 .. "_scale"], ";")

		for iter_1_2, iter_1_3 in ipairs(var_1_3) do
			local var_1_6 = ys.Battle.BattleResourceManager.GetInstance():InstMap(iter_1_3)

			tf(var_1_6).localScale = string2vector3(var_1_5[iter_1_2])

			setParent(var_1_6, var_1_1, false)

			tf(var_1_6).localPosition = string2vector3(var_1_4[iter_1_2])

			local var_1_7 = var_1_6:GetComponent(typeof(SeaAnim))

			if var_1_7 then
				table.insert(arg_1_0.seaAnimList, var_1_7)
			end

			local var_1_8 = var_1_6:GetComponent(typeof(Renderer))

			if var_1_8 then
				var_1_8.sortingOrder = -1500
			end
		end

		if iter_1_1 == "sea" then
			arg_1_0._buffer = var_1_1.transform:Find("gelidai(Clone)")

			if arg_1_0._buffer then
				arg_1_0._bufferRenderer = arg_1_0._buffer:GetComponent("SpriteRenderer")
				arg_1_0._bufferRenderer.color = Color.New(1, 1, 1, 0)
				arg_1_0._bufferRenderer.sortingOrder = -1500
			end
		end
	end

	arg_1_0:UpdateSpeedScaler()

	return arg_1_0._go
end

--- @class BattleMap
--- @param countStart number
--- @param countEnd number
--- @param duration number
--- @param callback function
--- @return nil
--- 移动海面
--- - 从 countStart 移动到 countEnd
--- - 每隔 duration 秒移动1次/更新1次
--- - 上层一般传入duration为1帧的时间(0.0333秒)，表示每帧更新一次
function BattleMap.ShiftSurface(self, countStart, countEnd, duration, callback)
	if self._shiftTimer then
		return
	end

	local count = countStart
	local direction

	if countEnd < countStart then
		direction = -1
	elseif countStart < countEnd then
		direction = 1
	else
		return
	end

	local function updateFunc()
		if (countEnd - count) * direction > 0 then
			ys.Battle.BattleVariable.AppendMapFactor("seaSurfaceShift", count)
			self:updateSeaSpeed()
			self:UpdateSpeedScaler()

			count = count + direction
		else
			pg.TimeMgr.GetInstance():RemoveBattleTimer(self._shiftTimer)

			self._shiftTimer = nil

			if callback then
				callback()
			end
		end
	end

	self._shiftTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", -1, duration, updateFunc, true)
end

function BattleMap.UpdateSpeedScaler(arg_4_0)
	arg_4_0:setSpeedScaler(ys.Battle.BattleVariable.MapSpeedRatio)
end

function BattleMap.UpdateBufferAlpha(arg_5_0, arg_5_1)
	local var_5_0 = arg_5_1 * 0.1

	arg_5_0._bufferRenderer.color = Color.New(1, 1, 1, var_5_0)
end

function BattleMap.SetExposeLine(arg_6_0, arg_6_1, arg_6_2, arg_6_3)
	function instantiateLine(arg_7_0, arg_7_1)
		local var_7_0 = ys.Battle.BattleResourceManager.GetInstance():InstMap(arg_7_1)
		local var_7_1 = arg_6_0._go.transform:Find("seaLayer")

		setParent(var_7_0, var_7_1, false)

		local var_7_2 = var_7_0:GetComponent("SpriteRenderer")
		local var_7_3 = var_7_2.bounds.extents.max

		var_7_2.sortingOrder = -1501

		local var_7_4 = tf(var_7_0).localScale

		tf(var_7_0).localScale = Vector3.New(arg_6_1 * var_7_4.x, var_7_4.y, var_7_4.z)

		local var_7_5 = tf(var_7_0).localPosition
		local var_7_6 = var_7_2.bounds.extents.x * arg_6_1

		tf(var_7_0).localPosition = Vector3.New(arg_7_0 - var_7_6, var_7_5.y, var_7_5.z)
		var_7_2.enabled = true
	end

	instantiateLine(arg_6_2, "visionLine")

	if arg_6_3 then
		instantiateLine(arg_6_3, "exposeLine")
	end
end

function BattleMap.setSpeedScaler(arg_8_0, arg_8_1)
	for iter_8_0, iter_8_1 in ipairs(arg_8_0.mapLayerCtrls) do
		iter_8_1.speedScaler = arg_8_1
	end
end

function BattleMap.updateSeaSpeed(arg_9_0)
	local var_9_0 = ys.Battle.BattleVariable.MapSpeedRatio

	for iter_9_0, iter_9_1 in ipairs(arg_9_0.seaAnimList) do
		iter_9_1:AdjustAnimSpeed(var_9_0)
	end
end

function BattleMap.Dispose(arg_10_0)
	if arg_10_0._shiftTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(arg_10_0._shiftTimer)
	end

	if arg_10_0._go then
		Object.Destroy(arg_10_0._go)

		arg_10_0._go = nil
		arg_10_0._buffer = nil
		arg_10_0._bufferRenderer = nil
	end
end

function BattleMap.GetMapResNames(arg_11_0, arg_11_1)
	local var_11_0 = pg.map_data[arg_11_0]

	return string.split(var_11_0[arg_11_1 .. "_shot"], ";")
end

function BattleMap.setActive(arg_12_0, arg_12_1)
	SetActive(arg_12_0._go, arg_12_1)
end
