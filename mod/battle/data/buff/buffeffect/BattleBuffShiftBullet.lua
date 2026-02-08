ys = ys or {}

local ys = ys

ys.Battle.BattleBuffShiftBullet = class("BattleBuffShiftBullet", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffShiftBullet.__name = "BattleBuffShiftBullet"

local BattleBuffShiftBullet = ys.Battle.BattleBuffShiftBullet

-- 此类BuffEffect用于显式地切换武器的子弹(将武器的子弹列表全部切换)
-- 和BattleBuffShiftBarrage基本是一样的思路
-- 与BattleBuffOverrideBullet的区别在于，BattleBuffShiftBullet是切换整个子弹, 而BattleBuffOverrideBullet则是修改子弹的部分参数
-- 使用例: 马萨诸塞2技能, 黑棒的装备技能
function BattleBuffShiftBullet.Ctor(self, effectData)
	BattleBuffShiftBullet.super.Ctor(self, effectData)
end

function BattleBuffShiftBullet.SetArgs(self, owner, buff)
	self._bulletID = self._tempData.arg_list.bullet_id
end

function BattleBuffShiftBullet.onAttach(self, owner, buff)
	self:shiftBullet(owner, self._bulletID)
end

function BattleBuffShiftBullet.onRemove(self, owner, buff)
	self:shiftBullet(owner)
end

function BattleBuffShiftBullet.shiftBullet(self, owner, bulletID)
	local weaponList = owner:GetAllWeapon()

	for _, equipIndex in ipairs(self._indexRequire) do
		for _, weapon in ipairs(weaponList) do
			if weapon:GetEquipmentIndex() == equipIndex then
				if bulletID then
					weapon:ShiftBullet(bulletID)
				else
					weapon:RevertBullet()
				end
			end
		end
	end
end
