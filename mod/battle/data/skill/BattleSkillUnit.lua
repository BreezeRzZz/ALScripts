ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleSkillUnit = class("BattleSkillUnit")
ys.Battle.BattleSkillUnit.__name = "BattleSkillUnit"

local BattleSkillUnit = ys.Battle.BattleSkillUnit

function BattleSkillUnit.Ctor(self, skillId, skillLevel)
	self._id = skillId
	self._level = skillLevel
	-- 获得skill_*.lua对应等级的技能数据
	self._tempData = ys.Battle.BattleDataFunction.GetSkillTemplate(skillId, skillLevel)
	self._cd = self._tempData.cd
	self._effectList = {}
	self._lastEffectTarget = {}

	for index, effect in ipairs(self._tempData.effect_list) do
		local effectType = effect.type
		-- 构建的是BattleSkillEffect的子类实例
		self._effectList[index] = ys.Battle[effectType].New(effect, skillLevel)
	end

	self._finaleEffectCount = 0
	self._dataProxy = ys.Battle.BattleDataProxy.GetInstance()
end

--- 类函数
function BattleSkillUnit.GenerateSpell(skillId, skillLevel, owner, attachData)
	local skill = ys.Battle.BattleSkillUnit.New(skillId, skillLevel)

	skill._attachData = attachData

	return skill
end

function BattleSkillUnit.GetSkillEffectList(self)
	return self._effectList
end

function BattleSkillUnit.Cast(self, owner, commander)
	local battleState = ys.Battle.BattleState.GetInstance()

	if self._tempData.focus_duration then
		owner:DispatchCutIn(self._tempData)
	end

	if self._tempData.painting == 1 then
		if commander then
			owner:DispatchSkillFloat(commander:getSkills()[1]:getConfig("name"), commander:getPainting())
		else
			owner:DispatchSkillFloat(self._tempData.name)
		end
	elseif type(self._tempData.painting) == "string" then
		owner:DispatchSkillFloat(self._tempData.name, nil, self._tempData.painting)
	end

	local castCV = type(self._tempData.castCV)

	if castCV == "string" then
		owner:DispatchVoice(self._tempData.castCV)
	elseif castCV == "table" then
		local _, wordSfx, _ = ShipWordHelper.GetWordAndCV(self._tempData.castCV.skinID, self._tempData.castCV.key)

		pg.CriMgr.GetInstance():PlaySoundEffect_V3(wordSfx)
	end

	if self._tempData.sfx then
		ys.Battle.PlayBattleSFX(self._tempData.sfx)
	end

	local attachData = self._attachData
	--- effect: BattleSkillEffect
	for _, effect in ipairs(self._effectList) do
		--- @type BattleUnit | table<BattleUnit>
		local targetList = effect:GetTarget(owner, self)

		self._lastEffectTarget = targetList

		effect:SetCommander(commander)

		if effect:IsFinaleEffect() then
			self._finaleEffectCount = self._finaleEffectCount + 1

			local function finaleCallBack()
				-- 变为STATE_SKILL_END
				self:callbackCount(owner)
			end

			effect:SetFinaleCallback(finaleCallBack)
		end

		effect:Effect(owner, targetList, attachData)
	end

	local aniEffect = self._tempData.aniEffect

	if aniEffect and aniEffect ~= "" then
		local addEffectArgs = {
			effect = aniEffect.effect,
			time = aniEffect.time,
			offset = aniEffect.offset,
			posFun = aniEffect.posFun
		}

		owner:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, addEffectArgs))
	end

	if self._tempData.action then
		owner:StateChange(ys.Battle.UnitState.STATE_SKILL_START)
	end
end

function BattleSkillUnit.SetTarget(self, target)
	self._lastEffectTarget = target
end

function BattleSkillUnit.Interrupt(self)
	for _, effect in ipairs(self._effectList) do
		effect:Interrupt()
	end
end

function BattleSkillUnit.Clear(self)
	for _, effect in ipairs(self._effectList) do
		effect:Clear()
	end
end

function BattleSkillUnit.callbackCount(self, owner)
	self._finaleEffectCount = self._finaleEffectCount - 1

	if self._finaleEffectCount == 0 and self._tempData.action then
		owner:StateChange(ys.Battle.UnitState.STATE_SKILL_END)
	end
end

function BattleSkillUnit.GetDamageSum(self)
	local damageSum = 0

	for _, effect in ipairs(self._effectList) do
		damageSum = effect:GetDamageSum() + damageSum
	end

	return damageSum
end

function BattleSkillUnit.IsFireSkill(self, skillID)
	local isFireSkill = false
	local skillTempData = ys.Battle.BattleDataFunction.GetSkillTemplate(self, skillID)

	for _, effect in ipairs(skillTempData.effect_list) do
		if effect.type == ys.Battle.BattleSkillFire.__name or effect.type == ys.Battle.BattleSkillFireSupport.__name then
			isFireSkill = true

			break
		end
	end

	return isFireSkill
end
