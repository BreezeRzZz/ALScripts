ys = ys or {}

local BattleNodeBuff = class("BattleNodeBuff", ys.Battle.BattleBuffEffect)

ys.Battle.BattleNodeBuff = BattleNodeBuff
BattleNodeBuff.__name = "BattleNodeBuff"

-- 看来看去不知道是干啥的
-- 反正是废弃的
function BattleNodeBuff.Ctor(self, effectData)
	BattleNodeBuff.super.Ctor(self, effectData)
end

function BattleNodeBuff.SetArgs(self, owner, buff)
	self._rate = self._tempData.arg_list.rate
end

function BattleNodeBuff.onFire(self, owner, buff)
	if not ys.Battle.BattleFormulas.IsHappen(self._rate) then
		return
	end

	local arg_list = self._tempData.arg_list
	local node = arg_list.node
	local weaponID = arg_list.weapon
	local SeqCenter = ys.Battle.BattleDataProxy.GetInstance():GetSeqCenter()

	for _, weapon in ipairs(owner:GetAutoWeapons()) do
		if weapon:GetWeaponId() == weaponID then
			local seq = SeqCenter:NewSeq("buff" .. self._id)
			local nodeData = ys.Battle.NodeData.New(owner, {
				weapon = weapon
			}, seq)

			pg.NodeMgr.GetInstance():GenNode(nodeData, pg.BattleNodesCfg[node], seq)

			break
		end
	end
end
