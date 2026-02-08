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

function BattleSkillUnit.SetTarget(arg_6_0, arg_6_1)
	arg_6_0._lastEffectTarget = arg_6_1
end

function BattleSkillUnit.Interrupt(arg_7_0)
	for iter_7_0, iter_7_1 in ipairs(arg_7_0._effectList) do
		iter_7_1:Interrupt()
	end
end

function BattleSkillUnit.Clear(arg_8_0)
	for iter_8_0, iter_8_1 in ipairs(arg_8_0._effectList) do
		iter_8_1:Clear()
	end
end

function BattleSkillUnit.callbackCount(self, owner)
	self._finaleEffectCount = self._finaleEffectCount - 1

	if self._finaleEffectCount == 0 and self._tempData.action then
		owner:StateChange(ys.Battle.UnitState.STATE_SKILL_END)
	end
end

function BattleSkillUnit.GetDamageSum(arg_10_0)
	local var_10_0 = 0

	for iter_10_0, iter_10_1 in ipairs(arg_10_0._effectList) do
		var_10_0 = iter_10_1:GetDamageSum() + var_10_0
	end

	return var_10_0
end

function BattleSkillUnit.IsFireSkill(arg_11_0, arg_11_1)
	local var_11_0 = false
	local var_11_1 = ys.Battle.BattleDataFunction.GetSkillTemplate(arg_11_0, arg_11_1)

	for iter_11_0, iter_11_1 in ipairs(var_11_1.effect_list) do
		if iter_11_1.type == ys.Battle.BattleSkillFire.__name or iter_11_1.type == ys.Battle.BattleSkillFireSupport.__name then
			var_11_0 = true

			break
		end
	end

	return var_11_0
end
