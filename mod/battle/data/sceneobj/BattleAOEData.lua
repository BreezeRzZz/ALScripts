ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleAOEData = class("BattleAOEData")

ys.Battle.BattleAOEData = BattleAOEData
BattleAOEData.__name = "BattleAOEData"
BattleAOEData.ALIGNMENT_LEFT = "left"
BattleAOEData.ALIGNMENT_RIGHT = "right"
BattleAOEData.ALIGNMENT_MIDDLE = "middle"
BattleAOEData.SOURCE_BULLET_9 = "bulletType9"

--- @class BattleAOEData
--- @param areaUID number 区域唯一ID
--- @param IFF number 敌我识别
--- @param areaCldFunc function 碰撞回调函数
--- @param endFunc function 结束回调函数
--- AOE区域数据构造
function BattleAOEData.Ctor(self, areaUID, IFF, areaCldFunc, endFunc)
	self._areaUniqueID = areaUID
	self._areaCldFunc = areaCldFunc
	self._endFunc = endFunc
	self._IFF = IFF
	self._cldObjList = {}
	self._cldObjDistanceList = {}
	-- tickness是y轴上的厚度
	-- (难道不应该是thickness吗？)
	self:SetTickness(10)

	self._alignment = Vector3.zero
	self._angle = 0
	self._component = {}
	self._timeExemptKey = "aoe_" .. self._areaUniqueID
end

--- 启动生命计时器。若生命周期为-1则永久存在
function BattleAOEData.StartTimer(self)
	if self._lifeTime == -1 then
		self._flag = false

		return
	end

	self._flag = true

	if self._lifeTime > 0 then
		self._lifeTimer = pg.TimeMgr.GetInstance():AddBattleTimer("areaTimer", 0, self._lifeTime, function()
			self:RemoveTimer()
		end, true)
	end
end

--- 获取时间豁免key，用于区分不同AOE的区域豁免
function BattleAOEData.GetTimeRationExemptKey(self)
	return self._timeExemptKey
end

--- 移除生命周期计时器
function BattleAOEData.RemoveTimer(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._lifeTimer)

	self._lifeTimer = nil
	self._flag = false
end

--- 清空碰撞对象列表
function BattleAOEData.ClearCLDList(self)
	self._cldObjList = {}
end

--- @param obj BattleUnit 要加入碰撞检测的对象
function BattleAOEData.AppendCldObj(self, obj)
	self._cldObjList[#self._cldObjList + 1] = obj
end

--- AOE结算：对碰撞列表排序后执行碰撞函数
function BattleAOEData.Settle(self)
	self.SortCldObjList(self._cldObjList)
	self._cldComponent:GetCldData().func(self._cldObjList)
end

--- AOE终结结算：若存在endFunc则在碰撞列表排序后执行
function BattleAOEData.SettleFinale(self)
	if self._endFunc then
		self.SortCldObjList(self._cldObjList)
		self._endFunc(self._cldObjList)
	end
end

--- 强制退出（子类可覆写）
function BattleAOEData.ForceExit(self)
	return
end

--- 碰撞列表排序：Boss优先，同优先级按UID升序
function BattleAOEData.SortCldObjList(self)
	table.sort(self, BattleAOEData._Fun_SortCldObjList)
end

--- 碰撞排序比较函数：Boss靠前，否则按UID升序
function BattleAOEData._Fun_SortCldObjList(a, b)
	if a.IsBoss ~= b.IsBoss then
		if b.IsBoss then
			return true
		else
			return false
		end
	else
		return a.UID < b.UID
	end
end

function BattleAOEData.SetOpponentAffected(self, opponentAffected)
	self._opponentAffected = opponentAffected
end

function BattleAOEData.OpponentAffected(self)
	return self._opponentAffected
end

function BattleAOEData.SetIndiscriminate(self, indiscriminate)
	self._indicriminate = indiscriminate
end

function BattleAOEData.GetIndiscriminate(self)
	return self._indicriminate
end

function BattleAOEData.GetActiveFlag(self)
	return self._flag
end

function BattleAOEData.SetActiveFlag(self, flag)
	self._flag = flag
end

--- 销毁：遍历组件列表并释放，移除计时器
function BattleAOEData.Dispose(self)
	for _, component in ipairs(self._component) do
		component:Dispose()
	end

	self._component = nil

	self:RemoveTimer()

	self._cldObjList = nil
end

function BattleAOEData.GetUniqueID(self)
	return self._areaUniqueID
end

function BattleAOEData.GetIFF(self)
	return self._IFF
end

function BattleAOEData.GetAreaType(self)
	return self._areaType
end

function BattleAOEData.GetPosition(self)
	return self._pos
end

function BattleAOEData.GetTickness(self)
	return self._tickness
end

function BattleAOEData.GetLifeTime(self)
	return self._lifeTime
end

function BattleAOEData.GetFieldType(self)
	return self._fieldType
end

function BattleAOEData.GetDiveFilter(self)
	return self._diveFilter
end

function BattleAOEData.GetCldFunc(self)
	return self._areaCldFunc
end

--- @return BattleUnit|nil AOE来源
function BattleAOEData.GetSource(self)
	return self._source
end

function BattleAOEData.GetHeight(self)
	return self._height
end

function BattleAOEData.GetWidth(self)
	return self._width
end

function BattleAOEData.GetAngle(self)
	return self._angle
end

function BattleAOEData.GetRange(self)
	return self._range
end

function BattleAOEData.GetSectorAngle(self)
	return self._sectorAngle
end

--- 设置区域类型并初始化对应的碰撞组件
function BattleAOEData.SetAreaType(self, areaType)
	self._areaType = areaType

	self:InitCldComponent()
end

function BattleAOEData.SetDiveFilter(self, diveFilter)
	self._diveFilter = diveFilter
end

function BattleAOEData.SetPosition(self, pos)
	self._pos = pos
end

function BattleAOEData.SetTickness(self, tickness)
	self._tickness = tickness
end

function BattleAOEData.SetFieldType(self, fieldType)
	self._fieldType = fieldType
end

function BattleAOEData.SetLifeTime(self, lifeTime)
	self._lifeTime = lifeTime
end

function BattleAOEData.SetSource(self, source)
	self._source = source
end

function BattleAOEData.SetHeight(self, height)
	self._height = height
end

function BattleAOEData.SetWidth(self, width)
	self._width = width
end

function BattleAOEData.SetAngle(self, angle)
	self._angle = angle
end

function BattleAOEData.SetRange(self, range)
	self._range = range
end

--- 设置扇形角度及方向，计算归一化相关偏移量
function BattleAOEData.SetSectorAngle(self, sectorAngle, sectorDir)
	self._sectorAngle = sectorAngle
	self._sectorDir = sectorDir

	local halfAngle = self._sectorAngle / 2

	self._upperEdge = math.deg2Rad * halfAngle
	self._lowerEdge = -1 * self._upperEdge

	local angleOffset = 0

	if sectorDir == BattleConst.UnitDir.LEFT then
		self._normalizeOffset = math.pi - angleOffset
	elseif sectorDir == BattleConst.UnitDir.RIGHT then
		self._normalizeOffset = angleOffset
	end

	self._wholeCircle = math.pi - self._normalizeOffset
	self._negativeCircle = -math.pi - self._normalizeOffset
	self._wholeCircleNormalizeOffset = self._normalizeOffset - math.pi * 2
	self._negativeCircleNormalizeOffset = self._normalizeOffset + math.pi * 2
end

--- 设置锚点对齐：左对齐/右对齐时调整alignment偏移
function BattleAOEData.SetAnchorPointAlignment(self, alignment)
	if alignment == BattleAOEData.ALIGNMENT_LEFT then
		self._alignment = Vector3(self._width * 0.5, 0, 0)
	elseif alignment == BattleAOEData.ALIGNMENT_RIGHT then
		self._alignment = Vector3(self._width * -0.5, 0, 0)
	end
end

function BattleAOEData.GetAnchorPointAlignment(self)
	return self._alignment
end

function BattleAOEData.GetFXStatic(self)
	return self._fxStatic
end

function BattleAOEData.SetFXStatic(self, fxStatic)
	self._fxStatic = fxStatic
end

function BattleAOEData.AppendComponent(self, component)
	table.insert(self._component, component)
end

--- 根据areaType初始化对应的碰撞组件（Cube/Ellipse/Column）
function BattleAOEData.InitCldComponent(self)
	if self._areaType == BattleConst.AreaType.CUBE or self._areaType == BattleConst.AreaType.ELLIPSE then
		self._cldComponent = ys.Battle.BattleCubeCldComponent.New(self._width, self._tickness, self._height, 0, 0)
	elseif self._areaType == BattleConst.AreaType.COLUMN then
		self._cldComponent = ys.Battle.BattleColumnCldComponent.New(self._range, self._tickness)
	end

	local cldData = {
		type = BattleConst.CldType.AOE,
		UID = self:GetUniqueID(),
		IFF = self:GetIFF(),
		func = self:GetCldFunc()
	}

	self._cldComponent:SetCldData(cldData)
	self._cldComponent:SetActive(true)
end

function BattleAOEData.GetCldComponent(self)
	return self._cldComponent
end

function BattleAOEData.DeactiveCldBox(self)
	self._cldComponent:SetActive(false)
end

function BattleAOEData.GetCldBox(self)
	return self._cldComponent:GetCldBox(self:GetPosition() + self._alignment)
end

function BattleAOEData.GetCldData(self)
	return self._cldComponent:GetCldData()
end

--- 更新所有碰撞对象到AOE中心的距离信息
--- 用于子类或碰撞后处理中获取距离
function BattleAOEData.UpdateDistanceInfo(self)
	for _, cldObj in ipairs(self._cldObjList) do
		local distance
		local leftBound = cldObj.LeftBound
		local rightBound = cldObj.RightBound
		local upperBound = cldObj.UpperBound
		local lowerBound = cldObj.LowerBound
		local posX = self._pos.x
		local inRangeX
		local cldPointX

		if leftBound <= posX and posX <= rightBound then
			inRangeX = true
		elseif posX < leftBound then
			cldPointX = leftBound
		elseif rightBound < posX then
			cldPointX = rightBound
		end

		local posZ = self._pos.z
		local inRangeZ
		local cldPointZ

		if lowerBound <= posZ and posZ <= upperBound then
			inRangeZ = true
		elseif posZ < lowerBound then
			cldPointZ = lowerBound
		elseif upperBound < posZ then
			cldPointZ = upperBound
		end

		if inRangeX and inRangeZ then
			distance = 0
		elseif inRangeX then
			distance = math.abs(cldPointZ - posZ)
		elseif inRangeZ then
			distance = math.abs(cldPointX - posX)
		else
			distance = math.sqrt((cldPointX - posX)^2 + (cldPointZ - posZ)^2)
		end

		self._cldObjDistanceList[cldObj.UID] = distance
	end
end

function BattleAOEData.GetDistance(self, uid)
	return self._cldObjDistanceList[uid]
end

--- 判断目标是否在扇形区域角度之外
function BattleAOEData.IsOutOfAngle(self, target)
	if not self._sectorAngle or self._sectorAngle >= 360 then
		return false
	else
		local targetPos = target:GetPosition()
		local angle = math.atan2(targetPos.z - self._pos.z, targetPos.x - self._pos.x)

		if angle > self._wholeCircle then
			angle = angle + self._wholeCircleNormalizeOffset
		elseif angle < self._negativeCircle then
			angle = angle + self._negativeCircleNormalizeOffset
		else
			angle = angle + self._normalizeOffset
		end

		if angle > self._lowerEdge and angle < self._upperEdge then
			return false
		else
			return true
		end
	end
end
