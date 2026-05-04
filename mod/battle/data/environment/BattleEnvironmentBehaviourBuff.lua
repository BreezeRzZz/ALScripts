ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourBuff = class("BattleEnvironmentBehaviourBuff", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourBuff = BattleEnvironmentBehaviourBuff
BattleEnvironmentBehaviourBuff.__name = "BattleEnvironmentBehaviourBuff"

--- @class BattleEnvironmentBehaviourBuff : BattleEnvironmentBehaviour
--- 环境Buff行为：对碰撞区域内的所有存活单位施加指定Buff
function BattleEnvironmentBehaviourBuff.Ctor(self)
	BattleEnvironmentBehaviourBuff.super.Ctor(self)
end

--- 读取buff_id和等级
--- @param tmpData table 行为配置（含buff_id和level）
function BattleEnvironmentBehaviourBuff.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourBuff.super.SetTemplate(self, tmpData)

	self._buffID = self._tmpData.buff_id
	self._buffLevel = self._tmpData.level or 1
end

--- 对区域内每个存活单位创建并添加Buff
function BattleEnvironmentBehaviourBuff.doBehaviour(self)
	for _, unit in ipairs(self._cldUnitList) do
		if unit:IsAlive() then
			local buff = ys.Battle.BattleBuffUnit.New(self._buffID, self._buffLevel)

			unit:AddBuff(buff)
		end
	end

	BattleEnvironmentBehaviourBuff.super.doBehaviour(self)
end
