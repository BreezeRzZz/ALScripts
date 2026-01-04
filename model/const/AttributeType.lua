local AttributeType = class("AttributeType")
-- TODO
AttributeType.Durability = "durability"
AttributeType.Cannon = "cannon"
AttributeType.Torpedo = "torpedo"
AttributeType.AntiAircraft = "antiaircraft"
AttributeType.AntiSub = "antisub"
AttributeType.Air = "air"
AttributeType.Reload = "reload"
AttributeType.ArmorType = "armor_type"
AttributeType.Armor = "armor"
AttributeType.Hit = "hit"
AttributeType.Speed = "speed"
AttributeType.Luck = "luck"
AttributeType.Dodge = "dodge"
AttributeType.Expend = "expend"
AttributeType.Intimacy = "intimacy"
AttributeType.AirDominate = "AirDominate"
AttributeType.Damage = "damage"
AttributeType.CD = "cd"
AttributeType.Healthy = "healthy"
AttributeType.Speciality = "speciality"
AttributeType.Range = "range"
AttributeType.Angle = "angle"
AttributeType.Scatter = "scatter"
AttributeType.Ammo = "ammo"
AttributeType.HuntingRange = "hunting_range"
AttributeType.AirDurability = "AirDurability"
AttributeType.AntiSiren = "anti_siren"
AttributeType.Corrected = "corrected"
AttributeType.OxyMax = "oxy_max"
AttributeType.OxyCost = "oxy_cost"
AttributeType.OxyRecovery = "oxy_recovery"
AttributeType.OxyRecoverySurface = "oxy_recovery_surface"
AttributeType.OxyRecoveryBench = "oxy_recovery_bench"
AttributeType.OxyAttackDuration = "attack_duration"
AttributeType.OxyRaidDistance = "raid_distance"
AttributeType.SonarRange = "sonarRange"
AttributeType.Tactics = "tactics"
AttributeType.WorldPower = "world_power"

function AttributeType.Type2Name(arg_1_0)
	return i18n("attribute_" .. arg_1_0)
end
-- TODO
AttributeType.eliteConditionTip = {
	cannon = "elite_condition_cannon",
	air = "elite_condition_air",
	dodge = "elite_condition_dodge",
	torpedo = "elite_condition_torpedo",
	durability = "elite_condition_durability",
	reload = "elite_condition_reload",
	fleet_totle_level = "elite_condition_fleet_totle_level",
	antiaircraft = "elite_condition_antiaircraft",
	antisub = "elite_condition_antisub",
	level = "elite_condition_level"
}

local var_0_1 = {
	[0] = "common_compare_equal",
	"common_compare_larger",
	"common_compare_not_less_than",
	[-1] = "common_compare_smaller",
	[-2] = "common_compare_not_more_than"
}

function AttributeType.eliteConditionCompareTip(arg_2_0)
	return i18n(var_0_1[arg_2_0])
end

function AttributeType.EliteCondition2Name(arg_3_0, ...)
	return i18n(AttributeType.eliteConditionTip[arg_3_0], ...)
end

function AttributeType.EliteConditionCompare(arg_4_0, arg_4_1, arg_4_2)
	if arg_4_0 == 0 then
		return arg_4_1 == arg_4_2
	elseif arg_4_0 == 1 then
		return arg_4_2 < arg_4_1
	elseif arg_4_0 == -1 then
		return arg_4_1 < arg_4_2
	elseif arg_4_0 == 2 then
		return arg_4_2 <= arg_4_1
	elseif arg_4_0 == -2 then
		return arg_4_1 <= arg_4_2
	else
		assert(false, "compare type error")
	end
end
-- TODO
-- 左侧是战斗外属性名，右侧是战斗内属性名
AttributeType.attrNameTable = {
	[AttributeType.Durability] = "maxHP",
	[AttributeType.Cannon] = "cannonPower",
	[AttributeType.Torpedo] = "torpedoPower",
	[AttributeType.AntiAircraft] = "antiAirPower",
	[AttributeType.AntiSub] = "antiSubPower",
	[AttributeType.Air] = "airPower",
	[AttributeType.Reload] = "loadSpeed",
	[AttributeType.Hit] = "attackRating",
	[AttributeType.Speed] = "speed",
	[AttributeType.Luck] = "luck",
	[AttributeType.Dodge] = "dodgeRate",
	[AttributeType.OxyMax] = "oxyMax",
	[AttributeType.OxyCost] = "oxyCost",
	[AttributeType.OxyRecovery] = "oxyRecovery",
	[AttributeType.OxyRecoveryBench] = "oxyRecoveryBench",
	[AttributeType.OxyRecoverySurface] = "oxyRecoverySurface",
	[AttributeType.OxyAttackDuration] = "oxyAtkDuration",
	[AttributeType.OxyRaidDistance] = "raidDist"
}
-- TODO
function AttributeType.ConvertBattleAttrName(arg_5_0)
	if AttributeType.attrNameTable[arg_5_0] then
		return AttributeType.attrNameTable[arg_5_0]
	else
		return arg_5_0
	end
end

AttributeType.PrimalAttr = {
	torpedoPower = true,
	loadSpeed = true,
	antiSubPower = true,
	antiAirPower = true,
	dodgeRate = true,
	airPower = true,
	attackRating = true,
	cannonPower = true,
	velocity = true
}

function AttributeType.IsPrimalBattleAttr(arg_6_0)
	return AttributeType.PrimalAttr[arg_6_0]
end

return AttributeType
