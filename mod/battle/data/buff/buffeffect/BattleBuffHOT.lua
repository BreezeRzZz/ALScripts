ys = ys or {}

local ys = ys

ys.Battle.BattleBuffHOT = class("BattleBuffHOT", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffHOT.__name = "BattleBuffHOT"

-- 此类BuffEffect会在持续时间内定期为单位恢复HP，number参数控制每次恢复的基础HP，time参数控制恢复间隔，maxHPRatio和currentHPRatio参数控制恢复量随当前HP和最大HP的比例
-- HOT即Healing Over Time
-- 但这类BuffEffect使用很少, 一般这类需求是用BattleSkillHeal更多.
-- 使用例: 翡绿之心的1技能
function ys.Battle.BattleBuffHOT.Ctor(self, effectData)
	ys.Battle.BattleBuffHOT.super.Ctor(self, effectData)
end

function ys.Battle.BattleBuffHOT.SetArgs(self, owner, buff)
	self._number = self._tempData.arg_list.number or 0
	self._numberBase = self._number
	self._time = self._tempData.arg_list.time or 0
	self._nextEffectTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._time
	self._maxHPRatio = self._tempData.arg_list.maxHPRatio or 0
	self._currentHPRatio = self._tempData.arg_list.currentHPRatio or 0
	self._incorruptible = self._tempData.arg_list.incorrupt
end

function ys.Battle.BattleBuffHOT.onStack(self, owner, buff)
	return
end

function ys.Battle.BattleBuffHOT.onUpdate(self, owner, buff, args)
	if args.timeStamp >= self._nextEffectTime then
		local healNumber = self:CalcNumber(owner, buff)
		local extraInfo = {
			isMiss = false,
			isCri = false,
			isHeal = true,
			incorrupt = self._incorruptible
		}

		owner:UpdateHP(healNumber, extraInfo)

		if owner:IsAlive() then
			self._nextEffectTime = self._nextEffectTime + self._time
		end
	end
end

function ys.Battle.BattleBuffHOT.onRemove(self, owner, buff)
	local healNumber = self:CalcNumber(owner, buff)
	local extraInfo = {
		isMiss = false,
		isCri = false,
		isHeal = true,
		incorrupt = self._incorruptible
	}

	owner:UpdateHP(healNumber, extraInfo)
end

function ys.Battle.BattleBuffHOT.CalcNumber(self, owner, buff)
	local currentHP, maxHP = owner:GetHP()
	local healingRate = owner:GetAttrByName("healingRate")
	local healNumber = math.max(0, currentHP * self._currentHPRatio + maxHP * self._maxHPRatio + self._number)
	-- 可叠层恢复量
	return (math.floor(healNumber * buff._stack * healingRate))
end
