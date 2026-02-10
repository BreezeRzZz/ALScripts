ys = ys or {}

local ys = ys

ys.Battle.BattleSkillChangeDiveState = class("BattleSkillChangeDiveState", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillChangeDiveState.__name = "BattleSkillChangeDiveState"

local BattleSkillChangeDiveState = ys.Battle.BattleSkillChangeDiveState

-- 此类SkillEffect用于改变目标的水上/水下状态
-- 使用例: 潜艇中常用
function BattleSkillChangeDiveState.Ctor(self, template, level)
	BattleSkillChangeDiveState.super.Ctor(self, template, level)

	self._state = self._tempData.arg_list.state
	self._expose = self._tempData.arg_list.expose
end

function BattleSkillChangeDiveState.DoDataEffect(self, caster, target)
	if target:IsAlive() then
		local oxyState = target:GetOxyState() or target:InitOxygen()

		target:ChangeOxygenState(self._state)
		oxyState:SetForceExpose(self._expose)
	end
end
