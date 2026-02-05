ys = ys or {}

local ys = ys
local BattleBuffAura = class("BattleBuffAura", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAura = BattleBuffAura
BattleBuffAura.__name = "BattleBuffAura"

local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig

function BattleBuffAura.Ctor(self, effectData)
	BattleBuffAura.super.Ctor(self, effectData)
end

function BattleBuffAura.SetArgs(self, owner, buff)
	self._buffLevel = buff:GetLv()

	local arg_list = self._tempData.arg_list

	self._auraRange = arg_list.cld_data.box.range
	self._buffID = arg_list.buff_id
	-- BattleBuffAura 默认是对敌方生效的
	self._friendly = arg_list.friendly_fire or false

	local areaCldFunc, exitCldFunc, endFunc = self:getAreaCldFunc(owner)

	self._aura = ys.Battle.BattleDataProxy.GetInstance():SpawnLastingColumnArea(BattleConst.AOEField.SURFACE, owner:GetIFF(), owner:GetPosition(), self._auraRange, 0, areaCldFunc, exitCldFunc, self._friendly, nil, endFunc, false)
	self._angle = arg_list.cld_data.angle

	if self._angle then
		self._aura:SetSectorAngle(self._angle, owner:GetDirection())
	end
	-- 跟随移动的AOE? 可能是跟随owner移动
	local mobillizedAOE = ys.Battle.BattleAOEMobilizedComponent.New(self._aura)

	mobillizedAOE:SetReferenceUnit(owner)
	mobillizedAOE:ConfigData(mobillizedAOE.FOLLOW)
end

function BattleBuffAura.getAreaCldFunc(self, owner)
	local function areaCldFunc(cldObjList)
		local candidateList = self:getTargetList(owner, {
			"TargetEntityUnit"
		})

		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				for _, candidate in ipairs(candidateList) do
					if candidate:GetUniqueID() == cldObj.UID then
						local buff = ys.Battle.BattleBuffUnit.New(self._buffID, self._buffLevel, self._caster)

						candidate:AddBuff(buff, true)

						break
					end
				end
			end
		end
	end

	local function exitCldFunc(cldObj)
		if cldObj.Active then
			local candidateList = self:getTargetList(owner, {
				"TargetEntityUnit"
			})

			for _, candidate in ipairs(candidateList) do
				if candidate:GetUniqueID() == cldObj.UID then
					candidate:RemoveBuff(self._buffID, true)

					break
				end
			end
		end
	end

	local function endFunc(cldObj)
		if cldObj.Active then
			local candidateList = self:getTargetList(owner, {
				"TargetEntityUnit"
			})

			for _, candidate in ipairs(candidateList) do
				if candidate:GetUniqueID() == cldObj.UID then
					candidate:RemoveBuff(self._buffID, true)

					break
				end
			end
		end
	end

	return areaCldFunc, exitCldFunc, endFunc
end

function BattleBuffAura.Clear(self)
	self._aura:SetActiveFlag(false)

	self._aura = nil

	BattleBuffAura.super.Clear(self)
end
