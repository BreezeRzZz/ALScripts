ys = ys or {}

local ys = ys

ys.Battle.BattleBuffShiftCLDBox = class("BattleBuffShiftCLDBox", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShiftCLDBox.__name = "BattleBuffShiftCLDBox"

local BattleBuffShiftCLDBox = ys.Battle.BattleBuffShiftCLDBox

-- 此类BuffEffect用于改变单位的碰撞箱，表现为碰撞箱的大小和位置发生变化
-- 使用例: EX困难模式，修改碰撞箱为1x1
function BattleBuffShiftCLDBox.Ctor(self, effectData)
	BattleBuffShiftCLDBox.super.Ctor(self, effectData)
end

function BattleBuffShiftCLDBox.SetArgs(self, owner, buff)
	self._cldBox = self._tempData.arg_list.cld_box
	self._cldOffset = self._tempData.arg_list.cld_offset or {
		0,
		0,
		0
	}
end

function BattleBuffShiftCLDBox.GetEffectType(self)
	return BattleBuffShiftCLDBox.FX_TYPE
end

function BattleBuffShiftCLDBox.onAttach(self, owner, buff)
	owner:ShiftCldComponent(self._cldBox, self._cldOffset)
end

function BattleBuffShiftCLDBox.onRemove(self, owner, buff)
	owner:ResetCldComponent()
end
