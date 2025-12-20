ys = ys or {}

local ys = ys

ys.Battle.BattleAntiAirBulletFactory = singletonClass("BattleAntiAirBulletFactory", ys.Battle.BattleBulletFactory)
ys.Battle.BattleAntiAirBulletFactory.__name = "BattleAntiAirBulletFactory"

local BattleAntiAirBulletFactory = ys.Battle.BattleAntiAirBulletFactory

function BattleAntiAirBulletFactory.Ctor(self)
	BattleAntiAirBulletFactory.super.Ctor(self)

	self._tmpTimerList = {}
end

function BattleAntiAirBulletFactory.NeutralizeBullet(self)
	for _, tmpTimer in pairs(self._tmpTimerList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(tmpTimer)

		self._tmpTimerList[tmpTimer] = nil
	end
end

-- 被BattleCharacter.SpawnBullet调用
--- @class BattleAntiAirBulletFactory
--- @param tf Transform
--- @param bullet BattleAntiAirBulletUnit
--- @param spawnPosition Vector3
--- @param fireFXID number
--- @param direction Vector3
function BattleAntiAirBulletFactory.CreateBullet(self, tf, bullet, spawnPosition, fireFXID, direction)
	local hit_type = bullet:GetTemplate().hit_type
	local battleDataProxy = self:GetDataProxy()
	local directHitUnit = bullet:GetDirectHitUnit()

	if not directHitUnit then
		battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local directHitUnitID = directHitUnit:GetUniqueID()
	local hitAircraft = self:GetSceneMediator():GetAircraft(directHitUnitID)

	if hitAircraft == nil then
		battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())

		return
	end

	local hitAircraftPos = hitAircraft:GetPosition():Clone()
	local range = hit_type.range

	local function areaCldFunc(cldObjList)
		local candidateList = {}

		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local aircraft = self:GetSceneMediator():GetAircraft(cldObj.UID)

				if aircraft then
					--- @type BattleAircraftUnit
					local aircraftUnit = aircraft:GetUnitData()

					if aircraftUnit:IsVisitable() then
						candidateList[#candidateList + 1] = aircraftUnit
					end
				end
			end
		end

		battleDataProxy:HandleMeteoDamage(bullet, candidateList)
	end

	local function fire()
		battleDataProxy:SpawnColumnArea(bullet:GetEffectField(), bullet:GetIFF(), hitAircraftPos, range, hit_type.time, areaCldFunc)
		battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())
	end

	local function playFx()
		local fxPos

		if directHitUnit:IsAlive() and hitAircraft then
			-- 实质是原位置+(-range/2, range/2)
			fxPos = hitAircraft:GetPosition():Clone():Add(Vector3(math.random(range) - range * 0.5, 0, math.random(range) - range * 0.5))
			hitAircraftPos = fxPos
		else
			fxPos = hitAircraftPos
		end

		local fx, fxOffset = self:GetFXPool():GetFX(bullet:GetTemplate().hit_fx)

		pg.EffectMgr.GetInstance():PlayBattleEffect(fx, fxOffset:Add(fxPos), true)
	end

	local antiAirTimer
	local onFireFXEnds

	local function main()
		if fireFXID == nil then
			fire()
		else
			self:PlayFireFX(tf, bullet, spawnPosition, fireFXID, direction, onFireFXEnds)
		end
	end

	function onFireFXEnds()
		if self._tmpTimerList[antiAirTimer] ~= nil then
			main()
			playFx()
		else
			fire()
		end
	end

	local function onTimerEnds()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(antiAirTimer)

		self._tmpTimerList[antiAirTimer] = nil
		antiAirTimer = nil
	end
	-- 有0.5s的延迟
	antiAirTimer = pg.TimeMgr.GetInstance():AddBattleTimer("antiAirTimer", -1, 0.5, onTimerEnds, true)
	self._tmpTimerList[antiAirTimer] = antiAirTimer

	main()
end
