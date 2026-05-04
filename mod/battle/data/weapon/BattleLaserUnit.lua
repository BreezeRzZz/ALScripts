ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleLaserUnit = class("BattleLaserUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleLaserUnit = BattleLaserUnit
BattleLaserUnit.__name = "BattleLaserUnit"
BattleLaserUnit.STATE_ATTACK = "FIB"
BattleLaserUnit.BEAM_STATE_READY = "beamStateReady"
BattleLaserUnit.BEAM_STATE_OVER_HEAT = "beamStateOverHeat"

function BattleLaserUnit.Ctor(self)
	BattleLaserUnit.super.Ctor(self)
end

function BattleLaserUnit.Clear(self)
	if self._alertTimer then
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._alertTimer)
	end

	self._alertTimer = nil

	for _, beam in ipairs(self._beamList) do
		if beam:GetBeamState() == beam.BEAM_STATE_ATTACK then
			self._dataProxy:RemoveAreaOfEffect(beam:GetAoeData():GetUniqueID())
		end

		beam:ClearBeam()
	end

	BattleLaserUnit.super.Clear(self)
end

function BattleLaserUnit.Update(self)
	-- 更新是否装填完毕
	self:UpdateReload()

	if self._currentState == self.STATE_READY then
		-- 更新目前host位置
		self:updateMovementInfo()
		-- 索敌，选择要攻击的目标
		local target = self:Tracking()

		if target then
			if self._preCastInfo.time ~= nil then
				self:PreCast(target)
			else
				self._currentState = self.STATE_PRECAST_FINISH
			end
		end
	end

	if self._currentState == self.STATE_PRECAST then
		-- block empty
	elseif self._currentState == self.STATE_PRECAST_FINISH then
		self:updateMovementInfo()
		self:Fire(self:Tracking())
	end

	if self._attackStartTime then
		self:updateMovementInfo()
		self:updateBeamList()
	end
end

function BattleLaserUnit.DoAttack(self, target)
	if target == nil or not target:IsAlive() or self:outOfFireRange(target) then
		target = nil
	end

	self._attackStartTime = pg.TimeMgr.GetInstance():GetCombatTime()

	if self._tmpData.aim_type == BattleConst.WeaponAimType.AIM and target ~= nil then
		self._aimPos = target:GetBeenAimedPosition()
	end

	self:cacheBulletID()

	for _, beam in ipairs(self._beamList) do
		beam:ChangeBeamState(beam.BEAM_STATE_READY)

		if BattleDataFunction.GetBarrageTmpDataFromID(beam:GetBeamInfoID()).first_delay == 0 then
			self:createBeam(beam)
		end
	end

	ys.Battle.PlayBattleSFX(self._tmpData.fire_sfx)
	self:TriggerBuffOnFire()
	self:CheckAndShake()
end

function BattleLaserUnit.SetTemplateData(self, template)
	BattleLaserUnit.super.SetTemplateData(self, template)
	self:initBeamList()
end

function BattleLaserUnit.initBeamList(self)
	local barrageIdList = self._tmpData.barrage_ID
	local bulletIdList = self._tmpData.bullet_ID

	self._alertList = {}
	self._beamList = {}

	for index, bulletId in ipairs(bulletIdList) do
		-- 用bulletId和barrageId创建BattleBeamUnit
		self._beamList[index] = ys.Battle.BattleBeamUnit.New(bulletId, barrageIdList[index])
	end
end

function BattleLaserUnit.updateBeamList(self)
	local elapsedTime = pg.TimeMgr.GetInstance():GetCombatTime() - self._attackStartTime
	local beamFinishedCount = 0

	for _, beam in ipairs(self._beamList) do
		if beam:GetBeamState() == beam.BEAM_STATE_READY then
			if elapsedTime > BattleDataFunction.GetBarrageTmpDataFromID(beam:GetBeamInfoID()).first_delay then
				self:createBeam(beam)
			end
		elseif beam:GetBeamState() == beam.BEAM_STATE_ATTACK then
			if not beam:IsBeamActive() then
				beam:ClearBeam()

				beamFinishedCount = beamFinishedCount + 1
			else
				beam:UpdateBeamPos(self._hostPos)
				beam:UpdateBeamAngle()

				if beam:CanDealDamage() then
					self:doBeamDamage(beam)
				end
			end
		elseif beam:GetBeamState() == beam.BEAM_STATE_FINISH then
			beamFinishedCount = beamFinishedCount + 1
		end
	end

	if beamFinishedCount == #self._beamList then
		self:EnterCoolDown()
	end
end

function BattleLaserUnit.createBeam(self, beam)
	local function cldFunc(cldObjList)
		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local unit = self._dataProxy:GetUnitList()[cldObj.UID]

				beam:AddCldUnit(unit)
			end
		end
	end

	local function exitCldFunc(cldObjList)
		if cldObjList.Active then
			local unit = self._dataProxy:GetUnitList()[cldObjList.UID]

			beam:RemoveCldUnit(unit)
		end
	end
	-- beamInfo本质是barrage_template的内容
	local beamInfo = BattleDataFunction.GetBarrageTmpDataFromID(beam:GetBeamInfoID())
	local bulletInfo = BattleDataFunction.GetBulletTmpDataFromID(beam:GetBulletID())
	local offsetX = beamInfo.offset_x
	local offsetZ = beamInfo.offset_z
	local deltaOffsetX = beamInfo.delta_offset_x
	local deltaOffsetZ = beamInfo.delta_offset_z
	local delay = beamInfo.delay
	local hostIFF = self._host:GetIFF()
	local sourcePos = Vector3(self._hostPos.x + offsetX, 0, self._hostPos.z + offsetZ)
	-- 这里deltaOffsetX作为了AOE的width(x轴方向)，deltaOffsetZ作为了AOE的height(z轴方向)
	local lastingCubeAOE = self._dataProxy:SpawnLastingCubeArea(BattleConst.AOEField.SURFACE, hostIFF, sourcePos, deltaOffsetX, deltaOffsetZ, delay, cldFunc, exitCldFunc, false, bulletInfo.modle_ID)

	if self._aimPos == nil then
		beam:SetAimAngle(0)
	elseif beamInfo.offset_prioritise then
		beam:SetAimPosition(self._aimPos, sourcePos, hostIFF)
	else
		local aimAngle

		if hostIFF == BattleConfig.FRIENDLY_CODE then
			aimAngle = math.rad2Deg * math.atan2(self._aimPos.z - self._hostPos.z, self._aimPos.x - self._hostPos.x)
		elseif hostIFF == BattleConfig.FOE_CODE then
			aimAngle = math.rad2Deg * math.atan2(self._hostPos.z - self._aimPos.z, self._hostPos.x - self._aimPos.x)
		end

		beam:SetAimAngle(aimAngle)
	end
	-- TODO
	if hostIFF == BattleConfig.FRIENDLY_CODE then
		lastingCubeAOE:SetAnchorPointAlignment(lastingCubeAOE.ALIGNMENT_LEFT)
	elseif hostIFF == BattleConfig.FOE_CODE then
		lastingCubeAOE:SetAnchorPointAlignment(lastingCubeAOE.ALIGNMENT_RIGHT)
	end

	lastingCubeAOE:SetFXStatic(true)
	beam:SetAoeData(lastingCubeAOE)
	beam:BeginFocus()
	beam:ChangeBeamState(beam.BEAM_STATE_ATTACK)
end

function BattleLaserUnit.doBeamDamage(self, beam)
	beam:DealDamage()
	-- 未设置目标则设定targetPos = Vector3.zero
	-- 路径：BattleWeaponUnit.Spawn -> BattleDataProxy.CreateBulletUnit -> BattleDataFunction.CreateBattleBulletData
	-- 实际创建的是BattleAntiAirBulletUnit
	-- 可以看出，激光的伤害机制是：每隔一段时间对碰撞到的单位进行一次伤害计算，不是对每个单位单独维护一个计时器
	-- 例：某激光每0.5秒对碰撞单位造成一次伤害，碰撞单位有A、B、C三个
	-- 机制1：如果A、B、C分别在0.4s、0.5s、0.6s时刻进入碰撞范围，则A、B都在0.5s时刻受到伤害，C在1.0s时刻受到伤害
	-- 机制2：如果A、B、C分别在0.4s、0.5s、0.6s时刻进入碰撞范围，则A在0.4s、0.9s时刻受到伤害，B在0.5s、1.0s时刻受到伤害，C在0.6s、1.1s时刻受到伤害
	-- 激光的实际机制是机制1，不是机制2，容易混淆特此说明
	local bullet = self:Spawn(beam:GetBulletID())
	local cldUnitList = beam:GetCldUnitList()

	for _, cldUnit in pairs(cldUnitList) do
		if not cldUnit:IsAlive() or beam:GetBeamExtraParam().mainFilter == true and cldUnit:IsMainFleetUnit() then
			-- block empty
		else
			self._dataProxy:HandleDamage(bullet, cldUnit)

			local fxRes, offset = ys.Battle.BattleFXPool.GetInstance():GetFX(beam:GetFXID())

			pg.EffectMgr.GetInstance():PlayBattleEffect(fxRes, offset:Add(cldUnit:GetPosition()), true)
			ys.Battle.PlayBattleSFX(beam:GetSFXID())
		end
	end

	self._dataProxy:RemoveBulletUnit(bullet:GetUniqueID())
end

function BattleLaserUnit.EnterCoolDown(self)
	self._attackStartTime = nil

	BattleLaserUnit.super.EnterCoolDown(self)
end
