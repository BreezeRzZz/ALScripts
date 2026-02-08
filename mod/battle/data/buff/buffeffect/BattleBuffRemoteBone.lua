ys = ys or {}

local ys = ys
local BattleBuffRemoteBone = class("BattleBuffRemoteBone", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffRemoteBone = BattleBuffRemoteBone
BattleBuffRemoteBone.__name = "BattleBuffRemoteBone"

-- 此BuffEffect将单位的某个骨骼绑定到另一个单位上，表现为该骨骼跟随目标单位移动
-- 使用例: 目前只有复仇2技能用到，实现"队伍中旗舰位为其他战列或战巡时，自身主炮由旗舰位置发射"的效果
function BattleBuffRemoteBone.Ctor(self, effectData)
	BattleBuffRemoteBone.super.Ctor(self, effectData)
end

function BattleBuffRemoteBone.SetArgs(self, owner, buff)
	self._group = buff:GetID()
	self._targetChoice = self._tempData.arg_list.bone_target
	self._bone = self._tempData.arg_list.bone_name
end

function BattleBuffRemoteBone.onAttach(self, owner, buff)
	owner:SetRemoteBoundBone(self._group, self._bone, self._targetChoice)
end

function BattleBuffRemoteBone.onRemove(self, owner, buff)
	owner:RemoveRemoteBoundBone(self._group)
end
