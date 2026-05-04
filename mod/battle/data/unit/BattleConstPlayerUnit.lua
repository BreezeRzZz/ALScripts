ys.Battle.BattleConstPlayerUnit = class("BattleConstPlayerUnit", ys.Battle.BattlePlayerUnit)
ys.Battle.BattleConstPlayerUnit.__name = "BattleConstPlayerUnit"

local BattleConstPlayerUnit = ys.Battle.BattleConstPlayerUnit
local EquipmentType = ys.Battle.BattleConst.EquipmentType

--- @class BattleConstPlayerUnit
--- @param weaponConfig table: 武器配置列表
--- @return nil
--- 设置武器：根据模板的base_list和proficiencyList创建武器
function BattleConstPlayerUnit.setWeapon(self, weaponConfig)
	local defaultEquipList = self._tmpData.default_equip_list
	local baseList = self._tmpData.base_list

	self._proficiencyList = {}

	-- 初始化武器熟练度列表
	for iter_1_0 = 1, #defaultEquipList do
		table.insert(self._proficiencyList, self._tmpData.equipment_proficiency[iter_1_0] or 1)
	end

	local proficiencyList = self._proficiencyList
	local preloadCount = self._tmpData.preload_count

	for iter_1_1, iter_1_2 in ipairs(defaultEquipList) do
		if iter_1_1 <= Ship.WEAPON_COUNT then
			local proficiency = proficiencyList[iter_1_1]
			local preloadWeaponCount = preloadCount[iter_1_1]

			-- 内嵌函数：创建武器组
			;(function(weaponID, label, skin)
				local baseCount = baseList[iter_1_1]

				for iter_2_0 = 1, baseCount do
					local weapon = self:AddWeapon(weaponID, label, skin, proficiency, iter_1_1)
					local equipmentType = weapon:GetTemplateData().type

					if iter_2_0 <= preloadWeaponCount and (equipmentType == EquipmentType.POINT_HIT_AND_LOCK or equipmentType == EquipmentType.MANUAL_TORPEDO or equipmentType == EquipmentType.DISPOSABLE_TORPEDO) then
						weapon:SetModifyInitialCD()
					end
				end
			end)(weaponConfig[iter_1_1] or defaultEquipList[iter_1_1])
		end
	end

	-- 固定装备列表
	local defaultEquipCount = #defaultEquipList
	local fixEquipList = self._tmpData.fix_equip_list

	for iter_1_3, iter_1_4 in ipairs(fixEquipList) do
		if iter_1_4 and iter_1_4 ~= -1 then
			local fixProficiency = proficiencyList[iter_1_3 + defaultEquipCount] or 1

			self:AddWeapon(iter_1_4, nil, nil, fixProficiency, iter_1_3 + defaultEquipCount)
		end
	end
end

--- @class BattleConstPlayerUnit
--- @return boolean: 始终返回true
--- 战役模式单位始终存活
function BattleConstPlayerUnit.IsAlive(self)
	return true
end

--- @class BattleConstPlayerUnit
--- @return nil
--- 隐藏波浪特效
function BattleConstPlayerUnit.HideWaveFx(self)
	self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.HIDE_WAVE_FX))
end

--- @class BattleConstPlayerUnit
--- @param args table: 血量更新参数
--- @return nil
--- 血量更新行动：父类逻辑基础上，受伤时添加闪烁效果
function BattleConstPlayerUnit.UpdateHPAction(self, args, ...)
	BattleConstPlayerUnit.super.UpdateHPAction(self, args, ...)

	if args.dHP <= 0 then
		self:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_BLINK, {
			blink = {
				blue = 1,
				peroid = 0.1,
				red = 1,
				green = 1,
				duration = 0.1
			}
		}))
	end
end
