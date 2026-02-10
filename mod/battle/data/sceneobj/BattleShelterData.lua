ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local effect_offset = pg.effect_offset

ys.Battle.BattleShelterData = class("BattleShelterData")
ys.Battle.BattleShelterData.__name = "BattleShelterData"

local BattleShelterData = ys.Battle.BattleShelterData

function BattleShelterData.Ctor(self, id)
	self._id = id
end

function BattleShelterData.SetIFF(self, IFF)
	self._IFF = IFF
end

function BattleShelterData.SetArgs(self, count, duration, box, pos, fxID)
	self._duration = duration
	self._bulletType = ys.Battle.BattleConst.BulletType.CANNON
	self._count = count
	self._effect = fxID
	self._doWhenHit = "intercept"

	local function cldFun(bullet)
		if bullet:GetType() == self._bulletType and self:IsWallActive() then
			self:DoWhenHit(bullet)
		end

		return self._count > 0
	end

	local cldOffset = {
		0,
		0,
		0
	}

	self._wall = ys.Battle.BattleDataProxy.GetInstance():SpawnWall(self, cldFun, box, cldOffset)
	self._centerPos = pos
end

function BattleShelterData.SetStartTimeStamp(self, timeStamp)
	self._startTimeStamp = timeStamp
end

function BattleShelterData.Update(self, timeStamp)
	if timeStamp - self._startTimeStamp > self._duration then
		self._startTimeStamp = nil
	end
end

function BattleShelterData.DoWhenHit(self, bullet)
	if not bullet:GetIgnoreShield() then
		if self._doWhenHit == "intercept" then
			bullet:Intercepted()
			ys.Battle.BattleDataProxy.GetInstance():RemoveBulletUnit(bullet:GetUniqueID())

			self._count = self._count - 1
		elseif self._doWhenHit == "reflect" and self:GetIFF() ~= bullet:GetIFF() then
			bullet:Reflected()

			self._count = self._count - 1
		end
	end
end

function BattleShelterData.GetUniqueID(self)
	return self._id
end

function BattleShelterData.GetIFF(self)
	return self._IFF
end

function BattleShelterData.GetFXID(self)
	return self._effect
end

function BattleShelterData.GetPosition(self)
	return self._centerPos
end

function BattleShelterData.Deactive(self)
	ys.Battle.BattleDataProxy.GetInstance():RemoveWall(self._wall:GetUniqueID())
end

function BattleShelterData.IsWallActive(self)
	return self._count > 0 and self._startTimeStamp
end
