ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEvent = ys.Battle.BattleEvent
local BattleSkillProjectArea = class("BattleSkillProjectArea", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillProjectArea = BattleSkillProjectArea
BattleSkillProjectArea.__name = "BattleSkillProjectArea"

function BattleSkillProjectArea.Ctor(self, effectData)
	BattleSkillProjectArea.super.Ctor(self, effectData, lv)

	self._posX = self._tempData.arg_list.offset_x
	self._posZ = self._tempData.arg_list.offset_z
	self._width = self._tempData.arg_list.width
	self._height = self._tempData.arg_list.height
	self._lifeTime = self._tempData.arg_list.life_time
	self._fx = self._tempData.arg_list.effect
	self._expendDuration = self._tempData.arg_list.expend_duration
	self._widthSpeed = self._tempData.arg_list.width_expend_speed
	self._heightSpeed = self._tempData.arg_list.height_expend_speed
	self._buffID = self._tempData.arg_list.cld_buff_id
end

function BattleSkillProjectArea.DoDataEffect(self, caster)
	self:doSpawnAOE(caster)
end

function BattleSkillProjectArea.DoDataEffectWithoutTarget(self, caster)
	self:doSpawnAOE(caster)
end

-- 这类SkillEffect会在caster位置(加上偏移)生成一个AOE，进入AOE的单位会被添加buff，离开AOE会移除buff
function BattleSkillProjectArea.doSpawnAOE(self, caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()

	local function areaCldFunc(cldObjList)
		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local unit = battleDataProxy:GetUnitList()[cldObj.UID]
				local buff = ys.Battle.BattleBuffUnit.New(self._buffID)

				unit:AddBuff(buff, true)
			end
		end
	end

	local function exitCldFunc(cldObj)
		if cldObj.Active then
			battleDataProxy:GetUnitList()[cldObj.UID]:RemoveBuff(self._buffID, true)
		end
	end

	local casterPos = caster:GetPosition()
	local position = Vector3(casterPos.x + self._posX, 0, casterPos.z + self._posZ)
	local aoeData = battleDataProxy:SpawnLastingCubeArea(BattleConst.AOEField.SURFACE, caster:GetIFF(), position, self._width, self._height, self._lifeTime, areaCldFunc, exitCldFunc, true, self._fx, nil)
	-- 如果指定了扩展时间，则添加扩展组件: 区域会随时间变大/变小
	if self._expendDuration > 0 then
		local scaleableComponent = ys.Battle.BattleAOEScaleableComponent.New(aoeData)

		scaleableComponent:SetReferenceUnit(caster)

		local configData = {
			expendDuration = self._expendDuration,
			widthSpeed = self._widthSpeed,
			heightSpeed = self._heightSpeed
		}

		scaleableComponent:ConfigData(scaleableComponent.EXPEND, configData)
	end
end
