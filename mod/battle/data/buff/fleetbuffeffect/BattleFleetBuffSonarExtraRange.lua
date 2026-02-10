ys = ys or {}

local ys = ys

ys.Battle.BattleFleetBuffSonarExtraRange = class("BattleFleetBuffSonarExtraRange", ys.Battle.BattleFleetBuffEffect)
ys.Battle.BattleFleetBuffSonarExtraRange.__name = "BattleFleetBuffSonarExtraRange"

local BattleFleetBuffSonarExtraRange = ys.Battle.BattleFleetBuffSonarExtraRange

-- 为舰队声纳(FleetSonar)提供额外范围(与技能声纳IndieSonar区分开)
function BattleFleetBuffSonarExtraRange.Ctor(self, tempData)
	BattleFleetBuffSonarExtraRange.super.Ctor(self, tempData)
end

function BattleFleetBuffSonarExtraRange.SetArgs(self, fleetVO, fleetBuff)
	self._extraRange = self._tempData.arg_list.range
end

function BattleFleetBuffSonarExtraRange.onAttach(self, fleetVO, fleetBuff)
	self:appendRange(fleetVO)
end

function BattleFleetBuffSonarExtraRange.onStack(self, fleetVO, fleetBuff)
	self:appendRange(fleetVO)
end

function BattleFleetBuffSonarExtraRange.appendRange(self, fleetVO)
	fleetVO:GetFleetSonar():AppendExtraSkillRange(self._extraRange)
end
