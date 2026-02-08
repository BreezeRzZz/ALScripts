ys = ys or {}

local ys = ys
local BattleBuffUnstoppable = class("BattleBuffUnstoppable", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffUnstoppable = BattleBuffUnstoppable
BattleBuffUnstoppable.__name = "BattleBuffUnstoppable"

-- 此类BuffEffect设置单位不可阻挡/不被吸引. 具体效果是使得单位免疫各种吸引效果(不影响吸引tag, tag是另一套逻辑，不相干)
-- 使用例: 某些BOSS的不可阻挡/不被吸引特性
function BattleBuffUnstoppable.Ctor(self, effectData)
	BattleBuffUnstoppable.super.Ctor(self, effectData)
end

function BattleBuffUnstoppable.onAttach(self, owner, buff)
	owner:ActiveUnstoppable(true)
end

function BattleBuffUnstoppable.onRemove(self, owner, buff)
	owner:ActiveUnstoppable(false)
end
