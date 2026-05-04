ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleConfig = ys.Battle.BattleConfig
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleBossUnit = class("BattleBossUnit", ys.Battle.BattleEnemyUnit)

ys.Battle.BattleBossUnit = BattleBossUnit
BattleBossUnit.__name = "BattleBossUnit"

--- @class BattleBossUnit
--- @param uid number: 单位唯一ID
--- @param iff number: 阵营(FRIENDLY_CODE/FOE_CODE)
--- @return nil
--- 构造函数：设置_isBoss标记为true
function BattleBossUnit.Ctor(self, uid, iff)
	BattleBossUnit.super.Ctor(self, uid, iff)

	self._isBoss = true
end

--- @class BattleBossUnit
--- @return boolean: 始终返回true
--- Boss单位始终是Boss
function BattleBossUnit.IsBoss(self)
	return true
end

--- @class BattleBossUnit
--- @param barrierDurability number: 护盾耐久
--- @param barrierDuration number: 护盾持续时间
--- @return nil
--- 发送护盾状态变化事件
function BattleBossUnit.BarrierStateChange(self, barrierDurability, barrierDuration)
	local args = {
		barrierDurability = barrierDurability,
		barrierDuration = barrierDuration
	}

	self:DispatchEvent(ys.Event.New(BattleUnitEvent.BARRIER_STATE_CHANGE, args))
end

--- @class BattleBossUnit
--- @param dHP number: 血量变化值
--- @return number: 实际生效的血量变化值
--- Boss单位的血量更新：在父类逻辑基础上，受伤时通知所有自动武器更新装甲
function BattleBossUnit.UpdateHP(self, dHP, arg_4_2, arg_4_3, arg_4_4)
	local dHPResult = BattleBossUnit.super.UpdateHP(self, dHP, arg_4_2, arg_4_3, arg_4_4) or 0

	if dHPResult < 0 then
		for _, weapon in ipairs(self._autoWeaponList) do
			weapon:UpdatePrecastArmor(dHPResult)
		end
	end

	return dHPResult
end
