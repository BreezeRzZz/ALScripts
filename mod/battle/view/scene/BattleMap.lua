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

--- @class BattleMap
--- 构造函数，根据地图ID构建所有层的地图对象
--- @param mapID number 地图ID
function BattleMap.Ctor(self, mapID)
	self._go = GameObject.New("scenes")
	self.mapLayerCtrls = {}
	self.seaAnimList = {}

	local mapConfig = pg.map_data[mapID]

	assert(mapConfig, "找不到地图: " .. mapID)

	for _, layerName in ipairs(BattleMap.LAYERS) do
		local layerGO = GameObject.New(layerName .. "Layer")

		setParent(layerGO, self._go, false)

		if layerName ~= "sky" then
			local layerCtrl = GetOrAddComponent(layerGO, "MapLayerCtrl")

			layerCtrl.leftBorder = mapConfig.range_left
			layerCtrl.rightBorder = mapConfig.range_right
			layerCtrl.speedToLeft = mapConfig[layerName .. "_speed"] or 0
			layerCtrl.speedScaler = 1
			layerCtrl.mainCamera = pg.UIMgr.GetInstance().mainCameraComp

			table.insert(self.mapLayerCtrls, layerCtrl)
		end

		local mapResNames = self.GetMapResNames(mapID, layerName)
		local posConfigs = string.split(mapConfig[layerName .. "_pos"], ";")
		local scaleConfigs = string.split(mapConfig[layerName .. "_scale"], ";")

		for index, resName in ipairs(mapResNames) do
			local mapObj = ys.Battle.BattleResourceManager.GetInstance():InstMap(resName)

			tf(mapObj).localScale = string2vector3(scaleConfigs[index])

			setParent(mapObj, layerGO, false)

			tf(mapObj).localPosition = string2vector3(posConfigs[index])

			local seaAnim = mapObj:GetComponent(typeof(SeaAnim))

			if seaAnim then
				table.insert(self.seaAnimList, seaAnim)
			end

			local renderer = mapObj:GetComponent(typeof(Renderer))

			if renderer then
				renderer.sortingOrder = -1500
			end
		end

		-- 海面层特殊处理：获取缓冲区（gelidai）的渲染器
		if layerName == "sea" then
			self._buffer = layerGO.transform:Find("gelidai(Clone)")

			if self._buffer then
				self._bufferRenderer = self._buffer:GetComponent("SpriteRenderer")
				self._bufferRenderer.color = Color.New(1, 1, 1, 0)
				self._bufferRenderer.sortingOrder = -1500
			end
		end
	end

	self:UpdateSpeedScaler()

	return self._go
end

--- 平滑移动海面偏移量（从countStart到countEnd）
--- @param countStart number 起始偏移
--- @param countEnd number 目标偏移
--- @param interval number 每次移动的间隔时间
--- @param callback function|nil 移动完成回调
function BattleMap.ShiftSurface(self, countStart, countEnd, interval, callback)
	if self._shiftTimer then
		return
	end

	local currentOffset = countStart
	local direction

	if countEnd < countStart then
		direction = -1
	elseif countStart < countEnd then
		direction = 1
	else
		return
	end

	-- 定时器回调：逐步调整偏移量
	local function shiftFunc()
		if (countEnd - currentOffset) * direction > 0 then
			ys.Battle.BattleVariable.AppendMapFactor("seaSurfaceShift", currentOffset)
			self:updateSeaSpeed()
			self:UpdateSpeedScaler()

			currentOffset = currentOffset + direction
		else
			pg.TimeMgr.GetInstance():RemoveBattleTimer(self._shiftTimer)

			self._shiftTimer = nil

			if callback then
				callback()
			end
		end
	end

	self._shiftTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", -1, interval, shiftFunc, true)
end

--- 更新所有图层的速度缩放（跟随全局MapSpeedRatio）
function BattleMap.UpdateSpeedScaler(self)
	self:setSpeedScaler(ys.Battle.BattleVariable.MapSpeedRatio)
end

--- 更新缓冲区透明度（根据距离调整，实现渐隐效果）
--- @param distance number 距离值
function BattleMap.UpdateBufferAlpha(self, distance)
	local alpha = distance * 0.1

	self._bufferRenderer.color = Color.New(1, 1, 1, alpha)
end

--- 设置舰队隐身/暴露线（在seaLayer上实例化对应线条）
--- @param iff number 敌我标识（影响线的朝向缩放）
--- @param visionLine number|nil 视野线位置
--- @param exposeLine number|nil 暴露线位置
function BattleMap.SetExposeLine(self, iff, visionLine, exposeLine)
	--- 实例化一条线并放置到正确位置
	--- @param xOffset number X轴偏移（线的实际位置）
	--- @param lineName string 线条资源名（如 "visionLine" / "exposeLine"）
	function instantiateLine(xOffset, lineName)
		local lineObj = ys.Battle.BattleResourceManager.GetInstance():InstMap(lineName)
		local seaLayer = self._go.transform:Find("seaLayer")

		setParent(lineObj, seaLayer, false)

		local spriteRenderer = lineObj:GetComponent("SpriteRenderer")
		local boundsMax = spriteRenderer.bounds.extents.max

		spriteRenderer.sortingOrder = -1501

		local localScale = tf(lineObj).localScale

		tf(lineObj).localScale = Vector3.New(iff * localScale.x, localScale.y, localScale.z)

		local localPosition = tf(lineObj).localPosition
		local halfWidth = spriteRenderer.bounds.extents.x * iff

		tf(lineObj).localPosition = Vector3.New(xOffset - halfWidth, localPosition.y, localPosition.z)
		spriteRenderer.enabled = true
	end

	instantiateLine(visionLine, "visionLine")

	if exposeLine then
		instantiateLine(exposeLine, "exposeLine")
	end
end

--- 设置所有图层的速度缩放
--- @param speed number 速度缩放比例
function BattleMap.setSpeedScaler(self, speed)
	for _, layerCtrl in ipairs(self.mapLayerCtrls) do
		layerCtrl.speedScaler = speed
	end
end

--- 更新海面动画速度
function BattleMap.updateSeaSpeed(self)
	local speedRatio = ys.Battle.BattleVariable.MapSpeedRatio

	for _, seaAnim in ipairs(self.seaAnimList) do
		seaAnim:AdjustAnimSpeed(speedRatio)
	end
end

--- 销毁地图，清理所有对象和定时器
function BattleMap.Dispose(self)
	if self._shiftTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._shiftTimer)
	end

	if self._go then
		Object.Destroy(self._go)

		self._go = nil
		self._buffer = nil
		self._bufferRenderer = nil
	end
end

--- 获取指定地图层级的资源名称列表
--- @param mapID number 地图ID
--- @param layerName string 层级名称（"close"/"mid"/"long"/"sky"/"sea"）
--- @return table 资源名列表
function BattleMap.GetMapResNames(self, mapID, layerName)
	local mapConfig = pg.map_data[mapID]

	return string.split(mapConfig[layerName .. "_shot"], ";")
end

--- 设置地图可见性
--- @param active boolean
function BattleMap.setActive(self, active)
	SetActive(self._go, active)
end
