ys = ys or {}

local ys = ys

ys.Battle.BattleBuffDeactiveCLDBox = class("BattleBuffDeactiveCLDBox", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffDeactiveCLDBox.__name = "BattleBuffDeactiveCLDBox"

local BattleBuffDeactiveCLDBox = ys.Battle.BattleBuffDeactiveCLDBox

-- 此类BuffEffect会取消掉单位的碰撞箱
-- 使用例: 莫加多尔的1技能
function BattleBuffDeactiveCLDBox.Ctor(self, effectData)
	BattleBuffDeactiveCLDBox.super.Ctor(self, effectData)
end

function BattleBuffDeactiveCLDBox.GetEffectType(self)
	return BattleBuffDeactiveCLDBox.FX_TYPE
end

function BattleBuffDeactiveCLDBox.onAttach(self, owner, buff)
	owner:SetCldBoxImmune(true)
end

function BattleBuffDeactiveCLDBox.onRemove(self, owner, buff)
	owner:SetCldBoxImmune(false)
end
