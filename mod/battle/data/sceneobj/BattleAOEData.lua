ys = ys or {}

local var_0_0 = ys
local var_0_1 = var_0_0.Battle.BattleConst
local BattleAOEData = class("BattleAOEData")

var_0_0.Battle.BattleAOEData = BattleAOEData
BattleAOEData.__name = "BattleAOEData"
BattleAOEData.ALIGNMENT_LEFT = "left"
BattleAOEData.ALIGNMENT_RIGHT = "right"
BattleAOEData.ALIGNMENT_MIDDLE = "middle"

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

function BattleAOEData.StartTimer(arg_2_0)
	if arg_2_0._lifeTime == -1 then
		arg_2_0._flag = false

		return
	end

	arg_2_0._flag = true

	if arg_2_0._lifeTime > 0 then
		arg_2_0._lifeTimer = pg.TimeMgr.GetInstance():AddBattleTimer("areaTimer", 0, arg_2_0._lifeTime, function()
			arg_2_0:RemoveTimer()
		end, true)
	end
end

function BattleAOEData.GetTimeRationExemptKey(arg_4_0)
	return arg_4_0._timeExemptKey
end

function BattleAOEData.RemoveTimer(arg_5_0)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(arg_5_0._lifeTimer)

	arg_5_0._lifeTimer = nil
	arg_5_0._flag = false
end

function BattleAOEData.ClearCLDList(arg_6_0)
	arg_6_0._cldObjList = {}
end

function BattleAOEData.AppendCldObj(arg_7_0, arg_7_1)
	arg_7_0._cldObjList[#arg_7_0._cldObjList + 1] = arg_7_1
end

function BattleAOEData.Settle(arg_8_0)
	arg_8_0.SortCldObjList(arg_8_0._cldObjList)
	arg_8_0._cldComponent:GetCldData().func(arg_8_0._cldObjList)
end

function BattleAOEData.SettleFinale(arg_9_0)
	if arg_9_0._endFunc then
		arg_9_0.SortCldObjList(arg_9_0._cldObjList)
		arg_9_0._endFunc(arg_9_0._cldObjList)
	end
end

function BattleAOEData.ForceExit(arg_10_0)
	return
end

function BattleAOEData.SortCldObjList(arg_11_0)
	table.sort(arg_11_0, BattleAOEData._Fun_SortCldObjList)
end

function BattleAOEData._Fun_SortCldObjList(arg_12_0, arg_12_1)
	if arg_12_0.IsBoss ~= arg_12_1.IsBoss then
		if arg_12_1.IsBoss then
			return true
		else
			return false
		end
	else
		return arg_12_0.UID < arg_12_1.UID
	end
end

function BattleAOEData.SetOpponentAffected(arg_13_0, arg_13_1)
	arg_13_0._opponentAffected = arg_13_1
end

function BattleAOEData.OpponentAffected(arg_14_0)
	return arg_14_0._opponentAffected
end

function BattleAOEData.SetIndiscriminate(arg_15_0, arg_15_1)
	arg_15_0._indicriminate = arg_15_1
end

function BattleAOEData.GetIndiscriminate(arg_16_0)
	return arg_16_0._indicriminate
end

function BattleAOEData.GetActiveFlag(arg_17_0)
	return arg_17_0._flag
end

function BattleAOEData.SetActiveFlag(arg_18_0, arg_18_1)
	arg_18_0._flag = arg_18_1
end

function BattleAOEData.Dispose(arg_19_0)
	for iter_19_0, iter_19_1 in ipairs(arg_19_0._component) do
		iter_19_1:Dispose()
	end

	arg_19_0._component = nil

	arg_19_0:RemoveTimer()

	arg_19_0._cldObjList = nil
end

function BattleAOEData.GetUniqueID(arg_20_0)
	return arg_20_0._areaUniqueID
end

function BattleAOEData.GetIFF(arg_21_0)
	return arg_21_0._IFF
end

function BattleAOEData.GetAreaType(arg_22_0)
	return arg_22_0._areaType
end

function BattleAOEData.GetPosition(arg_23_0)
	return arg_23_0._pos
end

function BattleAOEData.GetTickness(arg_24_0)
	return arg_24_0._tickness
end

function BattleAOEData.GetLifeTime(arg_25_0)
	return arg_25_0._lifeTime
end

function BattleAOEData.GetFieldType(arg_26_0)
	return arg_26_0._fieldType
end

function BattleAOEData.GetDiveFilter(arg_27_0)
	return arg_27_0._diveFilter
end

function BattleAOEData.GetCldFunc(arg_28_0)
	return arg_28_0._areaCldFunc
end

function BattleAOEData.GetHeight(arg_29_0)
	return arg_29_0._height
end

function BattleAOEData.GetWidth(arg_30_0)
	return arg_30_0._width
end

function BattleAOEData.GetAngle(arg_31_0)
	return arg_31_0._angle
end

function BattleAOEData.GetRange(arg_32_0)
	return arg_32_0._range
end

function BattleAOEData.GetSectorAngle(arg_33_0)
	return arg_33_0._sectorAngle
end

function BattleAOEData.SetAreaType(arg_34_0, arg_34_1)
	arg_34_0._areaType = arg_34_1

	arg_35_0:InitCldComponent()
end

function BattleAOEData.SetDiveFilter(arg_35_0, arg_35_1)
	arg_35_0._diveFilter = arg_35_1
end

function BattleAOEData.SetPosition(arg_36_0, arg_36_1)
	arg_36_0._pos = arg_36_1
end

function BattleAOEData.SetTickness(arg_37_0, arg_37_1)
	arg_37_0._tickness = arg_37_1
end

function BattleAOEData.SetFieldType(arg_38_0, arg_38_1)
	arg_38_0._fieldType = arg_38_1
end

function BattleAOEData.SetLifeTime(arg_39_0, arg_39_1)
	arg_39_0._lifeTime = arg_39_1
end

function BattleAOEData.SetSource(arg_41_0, arg_41_1)
	arg_41_0._source = arg_41_1
end

function BattleAOEData.SetHeight(arg_40_0, arg_40_1)
	arg_40_0._height = arg_40_1
end

function BattleAOEData.SetWidth(arg_41_0, arg_41_1)
	arg_41_0._width = arg_41_1
end

function BattleAOEData.SetAngle(arg_42_0, arg_42_1)
	arg_42_0._angle = arg_42_1
end

function BattleAOEData.SetRange(arg_43_0, arg_43_1)
	arg_43_0._range = arg_43_1
end

function BattleAOEData.SetSectorAngle(arg_44_0, arg_44_1, arg_44_2)
	arg_44_0._sectorAngle = arg_44_1
	arg_44_0._sectorDir = arg_44_2

	local var_46_0 = arg_46_0._sectorAngle / 2

	arg_46_0._upperEdge = math.deg2Rad * var_46_0
	arg_46_0._lowerEdge = -1 * arg_46_0._upperEdge

	local var_46_1 = 0

	if arg_46_2 == var_0_1.UnitDir.LEFT then
		arg_46_0._normalizeOffset = math.pi - var_46_1
	elseif arg_46_2 == var_0_1.UnitDir.RIGHT then
		arg_46_0._normalizeOffset = var_46_1
	end

	arg_46_0._wholeCircle = math.pi - arg_46_0._normalizeOffset
	arg_46_0._negativeCircle = -math.pi - arg_46_0._normalizeOffset
	arg_46_0._wholeCircleNormalizeOffset = arg_46_0._normalizeOffset - math.pi * 2
	arg_46_0._negativeCircleNormalizeOffset = arg_46_0._normalizeOffset + math.pi * 2
end

function BattleAOEData.SetAnchorPointAlignment(arg_45_0, arg_45_1)
	if arg_45_1 == BattleAOEData.ALIGNMENT_LEFT then
		arg_45_0._alignment = Vector3(arg_45_0._width * 0.5, 0, 0)
	elseif arg_45_1 == BattleAOEData.ALIGNMENT_RIGHT then
		arg_45_0._alignment = Vector3(arg_45_0._width * -0.5, 0, 0)
	end
end

function BattleAOEData.GetAnchorPointAlignment(arg_46_0)
	return arg_46_0._alignment
end

function BattleAOEData.GetFXStatic(arg_47_0)
	return arg_47_0._fxStatic
end

function BattleAOEData.SetFXStatic(arg_48_0, arg_48_1)
	arg_48_0._fxStatic = arg_48_1
end

function BattleAOEData.AppendComponent(arg_49_0, arg_49_1)
	table.insert(arg_49_0._component, arg_49_1)
end

function BattleAOEData.InitCldComponent(arg_50_0)
	if arg_50_0._areaType == var_0_1.AreaType.CUBE or arg_50_0._areaType == var_0_1.AreaType.ELLIPSE then
		arg_50_0._cldComponent = var_0_0.Battle.BattleCubeCldComponent.New(arg_50_0._width, arg_50_0._tickness, arg_50_0._height, 0, 0)
	elseif arg_50_0._areaType == var_0_1.AreaType.COLUMN then
		arg_50_0._cldComponent = var_0_0.Battle.BattleColumnCldComponent.New(arg_50_0._range, arg_50_0._tickness)
	end

	local var_52_0 = {
		type = var_0_1.CldType.AOE,
		UID = arg_52_0:GetUniqueID(),
		IFF = arg_52_0:GetIFF(),
		func = arg_52_0:GetCldFunc()
	}

	arg_52_0._cldComponent:SetCldData(var_52_0)
	arg_52_0._cldComponent:SetActive(true)
end

function BattleAOEData.GetCldComponent(arg_51_0)
	return arg_51_0._cldComponent
end

function BattleAOEData.DeactiveCldBox(arg_52_0)
	arg_52_0._cldComponent:SetActive(false)
end

function BattleAOEData.GetCldBox(arg_53_0)
	return arg_53_0._cldComponent:GetCldBox(arg_53_0:GetPosition() + arg_53_0._alignment)
end

function BattleAOEData.GetCldData(arg_54_0)
	return arg_54_0._cldComponent:GetCldData()
end

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

function BattleAOEData.GetDistance(arg_56_0, arg_56_1)
	return arg_56_0._cldObjDistanceList[arg_56_1]
end

function BattleAOEData.IsOutOfAngle(arg_57_0, arg_57_1)
	if not arg_57_0._sectorAngle or arg_57_0._sectorAngle >= 360 then
		return false
	else
		local var_59_0 = arg_59_1:GetPosition()
		local var_59_1 = math.atan2(var_59_0.z - arg_59_0._pos.z, var_59_0.x - arg_59_0._pos.x)

		if var_59_1 > arg_59_0._wholeCircle then
			var_59_1 = var_59_1 + arg_59_0._wholeCircleNormalizeOffset
		elseif var_59_1 < arg_59_0._negativeCircle then
			var_59_1 = var_59_1 + arg_59_0._negativeCircleNormalizeOffset
		else
			var_59_1 = var_59_1 + arg_59_0._normalizeOffset
		end

		if var_59_1 > arg_59_0._lowerEdge and var_59_1 < arg_59_0._upperEdge then
			return false
		else
			return true
		end
	end
end
