ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleFormulas = ys.Battle.BattleFormulas
local up = Vector3.up
local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig
local BattleConst = ys.Battle.BattleConst
local BattleTargetChoise = ys.Battle.BattleTargetChoise
local BattleColumnAreaBulletUnit = class("BattleColumnAreaBulletUnit", ys.Battle.BattleAreaBulletUnit)

BattleColumnAreaBulletUnit.__name = "BattleColumnAreaBulletUnit"
ys.Battle.BattleColumnAreaBulletUnit = BattleColumnAreaBulletUnit
BattleColumnAreaBulletUnit.AreaType = BattleConst.AreaType.COLUMN

function BattleColumnAreaBulletUnit.InitCldComponent(self)
	local cld_box = self:GetTemplate().cld_box
	local cld_offset = self:GetTemplate().cld_offset

	self._cldComponent = ys.Battle.BattleColumnCldComponent.New(cld_box[1], cld_box[3])

	local cldData = {
		type = BattleConst.CldType.AOE,
		UID = self:GetUniqueID(),
		IFF = self:GetIFF()
	}

	self._cldComponent:SetCldData(cldData)
end

function BattleColumnAreaBulletUnit.GetBoxSize(self)
	local cldBoxSize = self._cldComponent:GetCldBoxSize()

	return Vector3(cldBoxSize.range, cldBoxSize.range, cldBoxSize.tickness)
end
