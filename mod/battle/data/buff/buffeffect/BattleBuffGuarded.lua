ys = ys or {}

local ys = ys
local BattleBuffGuarded = class("BattleBuffGuarded", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffGuarded = BattleBuffGuarded
BattleBuffGuarded.__name = "BattleBuffGuarded"

-- 此BuffEffect将单位标记为被保护状态. 影响索敌
-- 当该单位被选为索敌目标时，强制将保护者作为索敌目标.
-- 目前只有武藏3技能用到
function BattleBuffGuarded.Ctor(self, effectData)
	BattleBuffGuarded.super.Ctor(self, effectData)
end

function BattleBuffGuarded.SetArgs(self, owner, buff)
	self._casterUID = buff:GetCaster():GetUniqueID()
end

function BattleBuffGuarded.onAttach(self, owner, buff)
	ys.Battle.BattleAttr.AddGuardianID(owner, self._casterUID)
end

function BattleBuffGuarded.onRemove(self, owner, buff)
	ys.Battle.BattleAttr.RemoveGuardianID(owner, self._casterUID)
end
