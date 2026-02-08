ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst

ys.Battle.BattleWallData = class("BattleWallData")
ys.Battle.BattleWallData.__name = "BattleWallData"

local BattleWallData = ys.Battle.BattleWallData

BattleWallData.CLD_OBJ_TYPE_BULLET = 1
BattleWallData.CLD_OBJ_TYPE_SHIP = 2

function BattleWallData.Ctor(self, id, host, cldFun, cldBox, cldOffset)
	self._id = id
	self._host = host
	self._cldFun = cldFun
	self._cldBox = cldBox
	self._cldOffset = cldOffset

	self:InitCldComponent()
end

function BattleWallData.InitCldComponent(self)
	local cldBox = self._cldBox
	local cldOffset = self._cldOffset

	-- 根据range字段判断是圆形碰撞还是矩形碰撞
	-- 5是thickness
	if cldBox.range then
		self._cldComponent = ys.Battle.BattleColumnCldComponent.New(cldBox.range, 5, cldOffset[1], cldOffset[3])
	else
		self._cldComponent = ys.Battle.BattleCubeCldComponent.New(cldBox[1], cldBox[2], cldBox[3], cldOffset[1], cldOffset[3])
	end

	local cldData = {
		type = BattleConst.CldType.WALL,
		UID = self:GetUniqueID(),
		func = self:GetCldFunc()
	}

	self._cldComponent:SetCldData(cldData)
	self._cldComponent:SetActive(true)
	self:SetCldObjType()
end

function BattleWallData.IsActive(self)
	return self._host:IsWallActive()
end

function BattleWallData.DeactiveCldBox(self)
	self._cldComponent:SetActive(false)
end

function BattleWallData.GetCldBox(self)
	return self._cldComponent:GetCldBox(self:GetPosition())
end

function BattleWallData.GetCldData(self)
	return self._cldComponent:GetCldData()
end

function BattleWallData.GetBoxSize(self)
	return self._cldComponent:GetCldBoxSize()
end

function BattleWallData.GetHost(self)
	return self._host
end

function BattleWallData.GetIFF(self)
	return self:GetHost():GetIFF()
end

function BattleWallData.GetPosition(self)
	return self:GetHost():GetPosition()
end

function BattleWallData.GetUniqueID(self)
	return self._id
end

function BattleWallData.GetCldFunc(self)
	return self._cldFun
end

function BattleWallData.SetCldObjType(self, cldObjType)
	self._cldObjType = cldObjType or BattleWallData.CLD_OBJ_TYPE_BULLET
end

function BattleWallData.GetCldObjType(self)
	return self._cldObjType
end
