ys = ys or {}

local ys = ys
local BattleEffectBulletUnit = class("BattleEffectBulletUnit", ys.Battle.BattleBulletUnit)

ys.Battle.BattleEffectBulletUnit = BattleEffectBulletUnit
BattleEffectBulletUnit.__name = "BattleEffectBulletUnit"

-- 对应EFFECT类型子弹
function BattleEffectBulletUnit.Ctor(self, UID, IFF)
	BattleEffectBulletUnit.super.Ctor(self, UID, IFF)
end

function BattleEffectBulletUnit.Update(self, timeStamp)
	BattleEffectBulletUnit.super.Update(self, timeStamp)

	if self._flare then
		self._flare:SetPosition(pg.Tool.FilterY(self:GetPosition():Clone()))
	end
end

function BattleEffectBulletUnit.IsFlare(self)
	return self:GetTemplate().attach_buff[1].flare
end

function BattleEffectBulletUnit.OutRange(self)
	BattleEffectBulletUnit.super.OutRange(self)

	if self._flare then
		self._flare:SetActiveFlag(false)

		self._flare = nil
	end
end

function BattleEffectBulletUnit.spawnArea(self, isFlare)
	local tempData = self:GetTemplate()
	local hit_type = tempData.hit_type
	local attach_buff = tempData.attach_buff[1]
	local buffID = attach_buff.buff_id
	local buffLevel = attach_buff.buff_level or 1

	local function areaCldFunc(cldObjList)
		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local unit = self._battleProxy:GetUnitList()[cldObj.UID]
				local buff = ys.Battle.BattleBuffUnit.New(buffID, buffLevel)

				unit:AddBuff(buff, true)
			end
		end
	end

	local function exitCldFunc(cldObj)
		if cldObj.Active then
			self._battleProxy:GetUnitList()[cldObj.UID]:RemoveBuff(buffID, true)
		end
	end

	time = hit_type.time

	local aoe

	if tempData.extra_param.ellipse_range then
		aoe = self._battleProxy:SpawnLastingEllipseArea(self:GetEffectField(), self:GetIFF(), pg.Tool.FilterY(self:GetPosition():Clone()), hit_type.range, tempData.extra_param.ellipse_range, time, areaCldFunc, exitCldFunc, attach_buff.friendly, attach_buff.effect_id)
	else
		aoe = self._battleProxy:SpawnLastingColumnArea(self:GetEffectField(), self:GetIFF(), pg.Tool.FilterY(self:GetPosition():Clone()), hit_type.range, time, areaCldFunc, exitCldFunc, attach_buff.friendly, attach_buff.effect_id)
	end

	if isFlare then
		self._flare = aoe
	end

	aoe:SetSource(aoe.SOURCE_BULLET_9)

	return aoe
end

function BattleEffectBulletUnit.GetExplodePostion(self)
	return self._explodePos
end

function BattleEffectBulletUnit.SetExplodePosition(self, explodePos)
	self._explodePos = explodePos
end
