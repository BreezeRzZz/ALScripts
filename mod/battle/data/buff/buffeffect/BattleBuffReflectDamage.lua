ys = ys or {}

local ys = ys

ys.Battle.BattleBuffReflectDamage = class("BattleBuffReflectDamage", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffReflectDamage.__name = "BattleBuffReflectDamage"

local BattleBuffReflectDamage = ys.Battle.BattleBuffReflectDamage

-- 此类BuffEffect的触发条件为：当受到伤害时，若伤害值超过一定(最大耐久)比例，则对伤害来源造成反弹伤害
-- 使用例: 光荣META 3技能
function BattleBuffReflectDamage.Ctor(self, effectData)
	BattleBuffReflectDamage.super.Ctor(self, effectData)
end

function BattleBuffReflectDamage.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._triggerValve = arg_list.valve
	self._reflectRate = arg_list.reflectRate
	self._reflectTargetChoice = arg_list.reflectTarget.target_choise
	self._reflectTargetParam = arg_list.reflectTarget.arg_list
end

function BattleBuffReflectDamage.onDamageConclude(self, owner, buff, args)
	if self:damageCheck(args) and not args.isReflect then
		local _, maxHP = owner:GetHP()
		local validDamage = -args.validDHP

		if validDamage >= math.floor(maxHP * self._triggerValve) then
			local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
			local reflectTargetList = self:getTargetList(owner, self._reflectTargetChoice, self._reflectTargetParam, {})

			if #reflectTargetList ~= 0 then
				local reflectTarget = reflectTargetList[1]
				local reflectDamage = math.floor(self._reflectRate * validDamage)

				battleDataProxy:HandleDirectDamage(reflectTarget, reflectDamage, owner, nil, true)
			end
		end
	end
end
