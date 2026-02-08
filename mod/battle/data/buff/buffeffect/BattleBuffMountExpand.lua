ys = ys or {}

local ys = ys
local BattleBuffMountExpand = class("BattleBuffMountExpand", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffMountExpand = BattleBuffMountExpand
BattleBuffMountExpand.__name = "BattleBuffMountExpand"

-- 这个BuffEffect可能是用于额外扩展机库的
-- 但目前没有用过
function BattleBuffMountExpand.Ctor(self, effectData)
	BattleBuffMountExpand.super.Ctor(self, effectData)
end

function BattleBuffMountExpand.SetArgs(self, owner, buff)
	self._weaponIndex = self._tempData.arg_list.index
end

function BattleBuffMountExpand.onAttach(self, owner, buff)
	owner:ExpandWeaponMount(self._weaponIndex)
end
