ys = ys or {}

local ys = ys

ys.Battle.BattleBuffActionKeyOffset = class("BattleBuffActionKeyOffset", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffActionKeyOffset.__name = "BattleBuffActionKeyOffset"

local BattleBuffActionKeyOffset = ys.Battle.BattleBuffActionKeyOffset

function BattleBuffActionKeyOffset.Ctor(self, effectData)
	BattleBuffActionKeyOffset.super.Ctor(self, effectData)
end

function BattleBuffActionKeyOffset.SetArgs(self, owner, buff)
	self._actionKey = self._tempData.arg_list.key
end

--- @class BattleBuffActionKeyOffset
--- @param owner BattleUnit
--- @param buff BattleBuffUnit
--- @return nil
--- 当Effect附加时调用该回调
--- - 关于BattleBuffActionKeyOffset: 从名字看不太懂
--- - 看了一些实例，大致的用途有：隐藏舰装、切换形态等，偏向视觉效果
function BattleBuffActionKeyOffset.onAttach(self, owner, buff)
	if owner:ActionKeyOffsetUseable() then
		owner:SetActionKeyOffset(self._actionKey)
	end
end

function BattleBuffActionKeyOffset.onRemove(self, owner, buff)
	if owner:ActionKeyOffsetUseable() then
		owner:SetActionKeyOffset(nil)
	end
end
