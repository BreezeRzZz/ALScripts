ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local EquipmentType = ys.Battle.BattleConst.EquipmentType

ys.Battle.BattleChargeWeaponVO = class("BattleChargeWeaponVO", ys.Battle.BattlePlayerWeaponVO)
ys.Battle.BattleChargeWeaponVO.__name = "BattleChargeWeaponVO"

local BattleChargeWeaponVO = ys.Battle.BattleChargeWeaponVO

-- BattleConfig.ChargeWeaponConfig.GCD = 1
-- 表示ChargeWeapon（跨射武器）的GCD为1s
BattleChargeWeaponVO.GCD = BattleConfig.ChargeWeaponConfig.GCD

--- @return nil
--- 构造函数
function BattleChargeWeaponVO.Ctor(self)
	BattleChargeWeaponVO.super.Ctor(self, BattleChargeWeaponVO.GCD)
end

--- @param weapon BattleWeaponUnit
--- @return nil
--- 为VO(View Object?)添加武器
--- - 这里的武器可能为BattlePointHitWeapon(主要)/BattlePointAirStrikeUnit等
function BattleChargeWeaponVO.AppendWeapon(self, weapon)
	BattleChargeWeaponVO.super.AppendWeapon(self, weapon)
	weapon:SetPlayerChargeWeaponVO(self)
end

--- @return nil
--- 获取当前武器图标索引(跨射图标会随之变化)
function BattleChargeWeaponVO.GetCurrentWeaponIconIndex(self)
	local currentWeapon = self:GetHeadWeapon()

	if currentWeapon == nil then
		return 1
	else
		local var_3_1 = currentWeapon:GetType()

		if var_3_1 == EquipmentType.POINT_HIT_AND_LOCK then
			return 1
		elseif var_3_1 == EquipmentType.MANUAL_MISSILE then
			return 10
		elseif var_3_1 == EquipmentType.MANUAL_METEOR then
			return 11
		elseif var_3_1 == EquipmentType.POINT_AIR_STRIKE then
			return 12
		end
	end
end

--- @param weapon BattleWeaponUnit
--- @return nil
--- 将武器的弹药扣除
function BattleChargeWeaponVO.Deduct(self, weapon)
	BattleChargeWeaponVO.super.Deduct(self, weapon)
	self:ResetFocus()
end

--- @return nil
--- 将镜头重置为默认位置
function BattleChargeWeaponVO.ResetFocus(self)
	if self._focus then
		local battleCameraUtilInstance = ys.Battle.BattleCameraUtil.GetInstance()

		-- 此处的参数是(nil, 0.1, 0.04)
			-- FocusCharacter函数
			-- 在unit参数为nil的情况下，转回默认镜头位置
		battleCameraUtilInstance:FocusCharacter(nil, BattleConfig.CAST_CAM_ZOOM_OUT_DURATION_CANNON, BattleConfig.CAST_CAM_ZOOM_OUT_EXTRA_DELAY_CANNON)
		-- 此处的参数是(14, 24, 0.1)
		battleCameraUtilInstance:ZoomCamara(BattleConfig.CAST_CAM_ZOOM_SIZE, BattleConfig.CAST_CAM_OVERLOOK_SIZE, BattleConfig.CAST_CAM_ZOOM_OUT_DURATION_CANNON)

		-- CAST_CAM_ZOOM_OUT_DURATION_CANNON = 0.1
		-- CAST_CAM_ZOOM_OUT_EXTRA_DELAY_CANNON = 0.04
		-- 因此 castCamZoomOutTime = 0.14(秒)
		local castCamZoomOutTime = BattleConfig.CAST_CAM_ZOOM_OUT_DURATION_CANNON + BattleConfig.CAST_CAM_ZOOM_OUT_EXTRA_DELAY_CANNON

		LeanTween.delayedCall(go(battleCameraUtilInstance:GetCamera()), castCamZoomOutTime, System.Action(function()
			self._focus = false

			-- 此处的参数是("focusCharacter", nil)
			battleCameraUtilInstance:BulletTime(BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER, nil)
			-- 此处的参数是(nil, nil, 1.5)
			-- CAST_CAM_OVERLOOK_REVERT_DURATION = 1.5
			battleCameraUtilInstance:ZoomCamara(nil, nil, BattleConfig.CAST_CAM_OVERLOOK_REVERT_DURATION)
		end))
	end
end
