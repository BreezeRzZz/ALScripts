ys = ys or {}

local ys = ys

ys.Battle.BattleBuffShiftBarrage = class("BattleBuffShiftBarrage", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShiftBarrage.__name = "BattleBuffShiftBarrage"

-- 此类BuffEffect用于显式地切换武器的弹幕(将武器的弹幕列表全部切换)
-- 使用例: 驱逐满破增益的鱼雷散布减小
local BattleBuffShiftBarrage = ys.Battle.BattleBuffShiftBarrage

function BattleBuffShiftBarrage.Ctor(self, effectData)
	BattleBuffShiftBarrage.super.Ctor(self, effectData)
end

function BattleBuffShiftBarrage.SetArgs(self, owner, buff)
	self._barrageID = self._tempData.arg_list.barrage_id
end

function BattleBuffShiftBarrage.onAttach(self, owner, buff)
	self:shiftBarrage(owner, self._barrageID)
end

function BattleBuffShiftBarrage.onRemove(self, owner, buff)
	self:shiftBarrage(owner)
end

function BattleBuffShiftBarrage.shiftBarrage(self, owner, barrageID)
	local weaponList = owner:GetAllWeapon()

	for _, equipIndex in ipairs(self._indexRequire) do
		for _, weapon in ipairs(weaponList) do
			if weapon:GetEquipmentIndex() == equipIndex then
				if barrageID then
					weapon:ShiftBarrage(barrageID)
				else
					weapon:RevertBarrage()
				end
			end
		end
	end
end
