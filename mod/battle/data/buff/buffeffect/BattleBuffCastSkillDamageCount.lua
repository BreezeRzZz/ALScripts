ys = ys or {}

local ys = ys
local BattleAttr = ys.Battle.BattleAttr

ys.Battle.BattleBuffCastSkillDamageCount = class("BattleBuffCastSkillDamageCount", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffCastSkillDamageCount.__name = "BattleBuffCastSkillDamageCount"

local BattleBuffCastSkillDamageCount = ys.Battle.BattleBuffCastSkillDamageCount

BattleBuffCastSkillDamageCount.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_CASTER

-- 此BuffEffect是BattleBuffCastSkill的一个变种
-- 记录在Buff持续期间内受到的伤害(按属性分类)
-- Buff结束时，选择造成伤害最多的属性，并释放对应的技能(给定的参数)
-- 不过此BuffEffect只被Buff 600047使用过。主要是用于实现限界挑战-天蝎座的根据受到最多的伤害类型，适应性的减少受到对应伤害的Buff
function BattleBuffCastSkillDamageCount.Ctor(self, effectData)
	BattleBuffCastSkillDamageCount.super.Ctor(self, effectData)
end

function BattleBuffCastSkillDamageCount.SetArgs(self, owner, buff)
	self._level = buff:GetLv()
	self._skillTable = self._tempData.arg_list.damage_attr_list
	self._attrTable = {}
end

function BattleBuffCastSkillDamageCount.onTakeDamage(self, owner, buff, args)
	local damageAttr = args.damageAttr

	if damageAttr then
		-- 记录每个伤害属性造成的伤害总和
		local totalDamage = (self._attrTable[damageAttr] or 0) + args.damage

		self._attrTable[damageAttr] = totalDamage
	end
end

function BattleBuffCastSkillDamageCount.onRemove(self, owner, buff, args)
	local maxAttrDamage = 0
	local maxAttrType

	for attrType, attrTotalDamage in pairs(self._attrTable) do
		if maxAttrDamage <= attrTotalDamage then
			maxAttrDamage = attrTotalDamage
			maxAttrType = attrType
		end
	end

	if not maxAttrType then
		return
	end

	local skillID = self._skillTable[maxAttrType]

	self._skill = ys.Battle.BattleSkillUnit.GenerateSpell(skillID, self._level, owner, args)

	if args and args.target then
		self._skill:SetTarget({
			args.target
		})
	end

	self._skill:Cast(owner, self._commander)
end

function BattleBuffCastSkillDamageCount.Interrupt(self)
	BattleBuffCastSkillDamageCount.super.Interrupt(self)

	if self._skill then
		self._skill:Interrupt()
	end
end

function BattleBuffCastSkillDamageCount.Clear(self)
	BattleBuffCastSkillDamageCount.super.Clear(self)

	if self._skill then
		self._skill:Clear()

		self._skill = nil
	end
end
