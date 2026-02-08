ys = ys or {}

local ys = ys

ys.Battle.BattleBuffCoverSpine = class("BattleBuffCoverSpine", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffCoverSpine.__name = "BattleBuffCoverSpine"

local BattleBuffCoverSpine = ys.Battle.BattleBuffCoverSpine

-- 此BuffEffect会在附加时切换单位的Spine，在移除时切换回原来的Spine
-- (仅视觉效果，不会改变单位的属性等)
-- 使用例: 主要是SSSS阵营的几个机甲变身时使用了这个BuffEffect，来切换机甲的Spine
-- 宝多六花专武、南梦芽专武
function BattleBuffCoverSpine.Ctor(self, effectData)
	BattleBuffCoverSpine.super.Ctor(self, effectData)
end

function BattleBuffCoverSpine.SetArgs(self, owner, buff)
	self._skin = self._tempData.arg_list.ship_skin_id
	self._hpbarOffset = self._tempData.arg_list.hp_bar_offset or 0
end

function BattleBuffCoverSpine.onAttach(self, owner, buff, args)
	owner:SwitchSpine(self._skin, self._hpbarOffset)
end

function BattleBuffCoverSpine.onRemove(self, owner, buff, args)
	owner:SwitchSpine(nil, self._hpbarOffset * -1)
end
