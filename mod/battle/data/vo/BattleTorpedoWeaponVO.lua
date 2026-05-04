ys = ys or {}

local ys = ys
local TorpedoCFG = ys.Battle.BattleConfig.TorpedoCFG
local BattleTorpedoWeaponVO = class("BattleTorpedoWeaponVO", ys.Battle.BattlePlayerWeaponVO)

ys.Battle.BattleTorpedoWeaponVO = BattleTorpedoWeaponVO
BattleTorpedoWeaponVO.__name = "BattleTorpedoWeaponVO"

--- @class BattleTorpedoWeaponVO : BattlePlayerWeaponVO
--- @return nil
--- 鱼雷武器VO的构造函数，GCD来自BattleConfig.TorpedoCFG
function BattleTorpedoWeaponVO.Ctor(self)
	BattleTorpedoWeaponVO.super.Ctor(self, TorpedoCFG.GCD)
end

--- @param weapon BattleTorpedoWeaponUnit
--- @return nil
--- 将鱼雷武器添加到VO，同时反向绑定
function BattleTorpedoWeaponVO.AppendWeapon(self, weapon)
	BattleTorpedoWeaponVO.super.AppendWeapon(self, weapon)
	weapon:SetPlayerTorpedoWeaponVO(self)
end

--- @return number
--- 获取当前武器对应的图标索引（鱼雷固定返回2）
function BattleTorpedoWeaponVO.GetCurrentWeaponIconIndex(self)
	return 2
end
