ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleSkillOverrideAutoPilot = class("BattleSkillOverrideAutoPilot", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillOverrideAutoPilot = BattleSkillOverrideAutoPilot
BattleSkillOverrideAutoPilot.__name = "BattleSkillOverrideAutoPilot"

-- 此类SkillEffect用于修改我方的自律逻辑(变为指定AI逻辑)
-- 与BattleBuffNewAI的区别是, BattleBuffNewAI一般不是给我方舰队使用(因为我方优先用RandomStrategy), 而是给我方召唤物/敌方单位使用
-- BattleSkillOverrideAutoPilot则主要给我方舰队使用, 相比之下额外处理了从RandomStrategy切换到AutoPilotStrategy, 然后才能用AI逻辑
-- 使用例: 2024异世界冒险 英灵效果 TB
function BattleSkillOverrideAutoPilot.Ctor(self, template, level)
	BattleSkillOverrideAutoPilot.super.Ctor(self, template, level)

	self._AIID = self._tempData.arg_list.ai_id
end

function BattleSkillOverrideAutoPilot.DoDataEffect(self, caster)
	local fleetVO = caster:GetFleetVO()

	if not fleetVO then
		return
	end

	fleetVO:OverrideJoyStickAutoBot(self._AIID)
end

function BattleSkillOverrideAutoPilot.DataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster)
end
