ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleAllInStrikeVO = class("BattleAllInStrikeVO", ys.Battle.BattlePlayerWeaponVO)
ys.Battle.BattleAllInStrikeVO.__name = "BattleAllInStrikeVO"

local BattleAllInStrikeVO = ys.Battle.BattleAllInStrikeVO

-- BattleConfig.AirAssistCFG.GCD
-- 空袭支援的全局冷却时间
BattleAllInStrikeVO.GCD = BattleConfig.AirAssistCFG.GCD

--- @class BattleAllInStrikeVO : BattlePlayerWeaponVO
--- @return nil
--- 空袭VO的构造函数，GCD来自AirAssistCFG
function BattleAllInStrikeVO.Ctor(self)
	BattleAllInStrikeVO.super.Ctor(self, BattleAllInStrikeVO.GCD)
end

--- @param airAssist BattleAllInStrikeUnit
--- @return nil
--- 添加空袭武器到VO，同时反向绑定
function BattleAllInStrikeVO.AppendWeapon(self, airAssist)
	airAssist:SetAllInWeaponVO(self)
	BattleAllInStrikeVO.super.AppendWeapon(self, airAssist)
end

--- @return number
--- 获取当前武器图标索引（空袭固定返回3）
function BattleAllInStrikeVO.GetCurrentWeaponIconIndex(self)
	return 3
end
