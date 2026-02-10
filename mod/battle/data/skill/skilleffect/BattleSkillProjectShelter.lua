ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleSkillProjectShelter = class("BattleSkillProjectShelter", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillProjectShelter = BattleSkillProjectShelter
BattleSkillProjectShelter.__name = "BattleSkillProjectShelter"

-- 此类SkillEffect用于生成Shelter
-- Shelter: 本质和Wall几乎是一样的, 但Shelter不会随生成者移动(固定在生成位置)
-- 使用例: 英格拉罕1技能
function BattleSkillProjectShelter.Ctor(self, template, level)
	BattleSkillProjectShelter.super.Ctor(self, template, level)

	self._duration = self._tempData.arg_list.duration
	self._offset = self._tempData.arg_list.offset
	self._fxID = self._tempData.arg_list.effect
	self._box = self._tempData.arg_list.box
	self._count = self._tempData.arg_list.count
end

function BattleSkillProjectShelter.DoDataEffect(self, caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local shelter = battleDataProxy:SpawnShelter(self._box, self._duration)
	local casterIFF = caster:GetIFF()

	if casterIFF == BattleConfig.FOE_CODE then
		self._offset[1] = self._offset[1] * -1
	end

	local shelterPos = caster:GetPosition() + BuildVector3(self._offset)

	shelter:SetIFF(casterIFF)
	shelter:SetArgs(self._count, self._duration, self._box, shelterPos, self._fxID)
	shelter:SetStartTimeStamp(pg.TimeMgr.GetInstance():GetCombatTime())

	local addShelterArgs = {
		shelter = shelter
	}

	battleDataProxy:DispatchEvent(ys.Event.New(BattleEvent.ADD_SHELTER, addShelterArgs))
end

function BattleSkillProjectShelter.DataEffectWithoutTarget(self, caster)
	self:DoDataEffect(caster)
end
