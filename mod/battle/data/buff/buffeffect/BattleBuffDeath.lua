ys = ys or {}

local ys = ys

ys.Battle.BattleBuffDeath = class("BattleBuffDeath", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffDeath.__name = "BattleBuffDeath"

local BattleBuffDeath = ys.Battle.BattleBuffDeath

-- 此类BuffEffect会在满足条件时让单位死亡，条件可以是时间到了，或者单位离开了指定范围，或者单位的某个countType的count不足了(来自BattleBuffCount)，或者直接瞬间死亡(instant_kill)
-- 使用例: 常见于召唤物的持续时间(时间到了就死)，或者让某个单位立刻死亡(通过瞬移到一个很远的地方来触发离开范围)
function BattleBuffDeath.Ctor(self, effectData)
	BattleBuffDeath.super.Ctor(self, effectData)
end

function BattleBuffDeath.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list
	-- 在Buff Attach时，设定死亡时间点为time秒后
	if arg_list.time then
		self._time = arg_list.time + pg.TimeMgr.GetInstance():GetCombatTime()
	end

	self._maxX = arg_list.maxX
	self._minX = arg_list.minX
	self._maxY = arg_list.maxY
	self._minY = arg_list.minY
	self._countType = arg_list.countType
	self._instantkill = self._tempData.arg_list.instant_kill
end

function BattleBuffDeath.onAttach(self, owner, buff, args)
	if self._instantkill then
		self:DoDead(owner)
	end
end

function BattleBuffDeath.onUpdate(self, owner, buff, args)
	local timeStamp = args.timeStamp

	if self._time and timeStamp > self._time then
		owner:SetDeathReason(ys.Battle.BattleConst.UnitDeathReason.DESTRUCT)
		self:DoDead(owner)
	else
		local position = owner:GetPosition()

		if self._maxX and position.x >= self._maxX then
			owner:SetDeathReason(ys.Battle.BattleConst.UnitDeathReason.LEAVE)
			self:DoDead(owner)
		elseif self._minX and position.x <= self._minX then
			owner:SetDeathReason(ys.Battle.BattleConst.UnitDeathReason.LEAVE)
			self:DoDead(owner)
		elseif self._maxY and position.z >= self._maxY then
			owner:SetDeathReason(ys.Battle.BattleConst.UnitDeathReason.LEAVE)
			self:DoDead(owner)
		elseif self._minY and position.z <= self._minY then
			owner:SetDeathReason(ys.Battle.BattleConst.UnitDeathReason.LEAVE)
			self:DoDead(owner)
		end
	end
end

function BattleBuffDeath.onBattleBuffCount(self, owner, buff, args)
	if args.countType == self._countType then
		self:DoDead(owner)
	end
end

function BattleBuffDeath.DoDead(self, target)
	target:SetCurrentHP(0)
	target:DeadAction()
end
