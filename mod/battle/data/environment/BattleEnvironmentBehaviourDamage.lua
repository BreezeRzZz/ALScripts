ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourDamage = class("BattleEnvironmentBehaviourDamage", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourDamage = BattleEnvironmentBehaviourDamage
BattleEnvironmentBehaviourDamage.__name = "BattleEnvironmentBehaviourDamage"

--- @class BattleEnvironmentBehaviourDamage : BattleEnvironmentBehaviour
--- 环境伤害行为：对区域内单位造成基于血量比例的伤害
function BattleEnvironmentBehaviourDamage.Ctor(self)
	BattleEnvironmentBehaviourDamage.super.Ctor(self)
end

--- 读取伤害参数：hp_rate(比例) / damage(固定值) / offset(随机浮动)
--- @param tmpData table
function BattleEnvironmentBehaviourDamage.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourDamage.super.SetTemplate(self, tmpData)

	self._rate = self._tmpData.hp_rate or 0
	self._damage = self._tmpData.damage or 0
	self._offset = self._tmpData.offset or 0
end

--- 执行伤害：damage = max(0, floor(curHP * hp_rate) + damage + random(-offset, offset))
--- 单位死亡时调用Spirit沉没和AppendInvincible无敌保护
function BattleEnvironmentBehaviourDamage.doBehaviour(self)
	for _, unit in ipairs(self._cldUnitList) do
		local damageAttr = {
			isMiss = false,
			isCri = false,
			isHeal = false
		}
		local maxHP, curHP = unit:GetHP()
		local damage = math.max(0, math.floor(curHP * self._rate) + self._damage + math.random(-self._offset, self._offset))

		unit:UpdateHP(-damage, damageAttr)

		if not unit:IsAlive() then
			ys.Battle.BattleAttr.Spirit(unit)
			ys.Battle.BattleAttr.AppendInvincible(unit)
		end
	end

	BattleEnvironmentBehaviourDamage.super.doBehaviour(self)
end
