ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleBeamUnit = class("BattleBeamUnit")
ys.Battle.BattleBeamUnit.__name = "BattleBeamUnit"

local BattleBeamUnit = ys.Battle.BattleBeamUnit

BattleBeamUnit.BEAM_STATE_READY = "ready"
BattleBeamUnit.BEAM_STATE_ATTACK = "attack"
BattleBeamUnit.BEAM_STATE_FINISH = "finish"

-- BEAM类型子弹, 这个类的实例不是真正意义上的子弹, 而是一个激光攻击的载体, 负责管理激光攻击的状态、碰撞体列表、伤害判定时机等
-- 上级武器是BattleLaserUnit
function BattleBeamUnit.Ctor(self, bulletID, beamInfoID)
	self._bulletID = bulletID
	self._beamInfoID = beamInfoID
	self._cldList = {}
	self._beamState = BattleBeamUnit.BEAM_STATE_READY
end

function BattleBeamUnit.IsBeamActive(self)
	return self._aoe:GetActiveFlag()
end

function BattleBeamUnit.ClearBeam(self)
	self._beamState = BattleBeamUnit.BEAM_STATE_FINISH
	self._aoe = nil
	self._cldList = {}
	self._nextDamageTime = nil
end

function BattleBeamUnit.SetAoeData(self, aoe)
	self._aoe = aoe
	-- barrage_template
	self._beamTemp = BattleDataFunction.GetBarrageTmpDataFromID(self._beamInfoID)
	-- bullet_template
	self._bulletTemp = BattleDataFunction.GetBulletTmpDataFromID(self._bulletID)
	self._angle = self._beamTemp.angle

	self._aoe:SetAngle(self._angle + self._aimAngle)

	local diveFilter = self._bulletTemp.extra_param.diveFilter

	if diveFilter then
		self._aoe:SetDiveFilter(diveFilter)
	end
end

function BattleBeamUnit.SetAimAngle(self, aimAngle)
	self._aimAngle = aimAngle or 0
end

function BattleBeamUnit.SetAimPosition(self, aimPos, sourcePos, hostIFF)
	if hostIFF == BattleConfig.FOE_CODE then
		self._aimAngle = math.rad2Deg * math.atan2(sourcePos.z - aimPos.z, sourcePos.x - aimPos.x)
	elseif hostIFF == BattleConfig.FRIENDLY_CODE then
		self._aimAngle = math.rad2Deg * math.atan2(aimPos.z - sourcePos.z, aimPos.x - sourcePos.x)
	end
end

function BattleBeamUnit.getAngleRatio(self)
	return BattleVariable.GetSpeedRatio(self._aoe:GetTimeRationExemptKey(), self._aoe:GetIFF())
end

function BattleBeamUnit.GetAoeData(self)
	return self._aoe
end

function BattleBeamUnit.UpdateBeamPos(self, pos)
	self._aoe:SetPosition(Vector3(pos.x + self._beamTemp.offset_x, 0, pos.z + self._beamTemp.offset_z))
end

function BattleBeamUnit.UpdateBeamAngle(self)
	self._angle = self._angle + self._beamTemp.delta_angle * self:getAngleRatio()

	self._aoe:SetAngle(self._angle + self._aimAngle)
end

function BattleBeamUnit.AddCldUnit(self, unit)
	local UID = unit:GetUniqueID()

	self._cldList[UID] = unit
end

function BattleBeamUnit.RemoveCldUnit(self, unit)
	local UID = unit:GetUniqueID()

	self._cldList[UID] = nil
end

function BattleBeamUnit.ChangeBeamState(self, beamState)
	self._beamState = beamState
end

function BattleBeamUnit.GetBeamState(self)
	return self._beamState
end

function BattleBeamUnit.GetCldUnitList(self)
	return self._cldList
end

-- 经过senior_delay时间，才开始激光攻击，作为focus时间
-- 这个值在barrage_template中
function BattleBeamUnit.BeginFocus(self)
	self._nextDamageTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._beamTemp.senior_delay
end

-- 在激光攻击过程中，每经过delta_delay时间，会对所有碰撞体进行一次伤害判定
-- 这个值在barrage_template中
function BattleBeamUnit.DealDamage(self)
	self._nextDamageTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._beamTemp.delta_delay
end

function BattleBeamUnit.CanDealDamage(self)
	return self._nextDamageTime < pg.TimeMgr.GetInstance():GetCombatTime()
end

function BattleBeamUnit.GetFXID(self)
	return self._bulletTemp.hit_fx
end

function BattleBeamUnit.GetSFXID(self)
	return self._bulletTemp.hit_sfx
end

function BattleBeamUnit.GetBulletID(self)
	return self._bulletID
end

function BattleBeamUnit.GetBeamInfoID(self)
	return self._beamInfoID
end

function BattleBeamUnit.GetBeamExtraParam(self)
	return self._bulletTemp.extra_param
end
