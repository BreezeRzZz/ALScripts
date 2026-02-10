ys = ys or {}

local ys = ys
local BattleSkillInstantCoolDown = class("BattleSkillInstantCoolDown", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillInstantCoolDown = BattleSkillInstantCoolDown
BattleSkillInstantCoolDown.__name = "BattleSkillInstantCoolDown"

-- 此类SkillEffect立刻完成指定武器类型的冷却时间
-- 使用例: 快速起飞
function BattleSkillInstantCoolDown.Ctor(self, template, level)
	BattleSkillInstantCoolDown.super.Ctor(self, template, level)

	self._weaponType = self._tempData.arg_list.weaponType
end

function BattleSkillInstantCoolDown.DoDataEffect(self, caster, target)
	local weapon = self:_GetWeapon(caster)

	if weapon then
		-- 有QuickCoolDown方法的只有如下几类:
		-- AllInStrike
		-- ManualTorpedo
		-- PointAirStrike
		-- PointHitWeapon
		weapon:QuickCoolDown()
	end
end

function BattleSkillInstantCoolDown.DoDataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster, nil)
end

function BattleSkillInstantCoolDown._GetWeapon(self, caster)
	local weapon

	if self._weaponType == "AirAssist" then
		weapon = caster:GetAirAssistQueue():GetQueueHead()
	end

	return weapon
end
