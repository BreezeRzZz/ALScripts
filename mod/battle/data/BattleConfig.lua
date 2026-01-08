ys.Battle.BattleConfig = ys.Battle.BattleConfig or {}

local BattleConfig = ys.Battle.BattleConfig

BattleConfig.COMBAT_DELAY_ACTIVE = 0.6
BattleConfig.calcFPS = 30
BattleConfig.viewFPS = 30
BattleConfig.AIFPS = 10
BattleConfig.calcInterval = 1 / BattleConfig.calcFPS
BattleConfig.viewInterval = 1 / BattleConfig.viewFPS
BattleConfig.AIInterval = 1 / BattleConfig.AIFPS
BattleConfig.FRIENDLY_CODE = 1
BattleConfig.FOE_CODE = -1
BattleConfig.SHIELD_CENTER_CONST = 3.14
BattleConfig.SHIELD_CENTER_CONST_2 = 2.0933333333333333
BattleConfig.SHIELD_CENTER_CONST_4 = 4.1866666666666665
BattleConfig.SHIELD_ROTATE_CONST = 30 / math.pi * 18
BattleConfig.K1 = 6
BattleConfig.K2 = 100
BattleConfig.K3 = 3.14
BattleConfig.AIR_ASSIST_RELOAD_RATIO = 220
BattleConfig.RANDOM_DAMAGE_MIN = 0
BattleConfig.RANDOM_DAMAGE_MAX = 2
BattleConfig.BASIC_TIME_SCALE = 1
BattleConfig.SPINE_SCALE = 2
BattleConfig.BULLET_UPPER_BOUND_VISION_OFFSET = 30
BattleConfig.BULLET_LEFT_BOUND_SPLIT_OFFSET = 8
BattleConfig.BULLET_LOWER_BOUND_SPLIT_OFFSET = 8
BattleConfig.BULLET_SPLIT_SHIFT_DELAY = 0.2
BattleConfig.CAMERA_INIT_POS = Vector3(0, 62, -10)
BattleConfig.CAMERA_SIZE = 20
BattleConfig.CAMERA_BASE_HEIGH = 8
BattleConfig.CAMERA_GOLDEN_RATE = 0.618
BattleConfig.AntiAirConfig = {}
BattleConfig.AntiAirConfig.const_n = 10
BattleConfig.AntiAirConfig.const_K = 1000
BattleConfig.AntiAirConfig.const_N = 5
BattleConfig.AntiAirConfig.const_A = 20
BattleConfig.AntiAirConfig.const_B = 40
BattleConfig.AntiAirConfig.Restore_Interval = 1
BattleConfig.AntiAirConfig.Precast_duration = 0.25
BattleConfig.AntiAirConfig.RangeBulletID = 2001
BattleConfig.AntiAirConfig.RangeBarrageID = 1
BattleConfig.AntiAirConfig.RangeAntiAirBone = "rangeantiaircraft"
BattleConfig.AirSupportUnitPos = Vector3(-105, 0, 58)
BattleConfig.SubSupportUnitPosList = {
	Vector3(-36, 0, 58),
	Vector3(-30, 0, 78),
	Vector3(-30, 0, 38)
}
BattleConfig.SubSupportDelay = 5
BattleConfig.AnitAirRepeaterConfig = {}
BattleConfig.AnitAirRepeaterConfig.const_A = 32
BattleConfig.AnitAirRepeaterConfig.const_B = 12
BattleConfig.AnitAirRepeaterConfig.const_C = 220
BattleConfig.AnitAirRepeaterConfig.upper_range = 35
BattleConfig.AnitAirRepeaterConfig.lower_range = 15
BattleConfig.ChargeWeaponConfig = {}
BattleConfig.ChargeWeaponConfig.a1 = 0
BattleConfig.ChargeWeaponConfig.K1 = 0
BattleConfig.ChargeWeaponConfig.K2 = 1000
BattleConfig.ChargeWeaponConfig.FIX_CD = 7
BattleConfig.ChargeWeaponConfig.MEGA_FIX_CD = 3
BattleConfig.ChargeWeaponConfig.GCD = 1
BattleConfig.ChargeWeaponConfig.Enhance = 1.2
BattleConfig.ChargeWeaponConfig.SIGHT_A = 0.35
BattleConfig.ChargeWeaponConfig.SIGHT_B = -40
BattleConfig.ChargeWeaponConfig.SIGHT_C = 38
BattleConfig.TorpedoCFG = {}
BattleConfig.TorpedoCFG.T = 10
BattleConfig.TorpedoCFG.N = 1000
BattleConfig.TorpedoCFG.GCD = 0.5
BattleConfig.AirAssistCFG = {}
BattleConfig.AirAssistCFG.GCD = 0.5
BattleConfig.HammerCFG = {}
BattleConfig.HammerCFG.PreventUpperBound = 0.8
BattleConfig.BulletHeight = 1
BattleConfig.HeightOffsetRate = 1.5
BattleConfig.CharacterFeetHight = -0.5
BattleConfig.BombDetonateHeight = 1.2
BattleConfig.CameraSizeChangeSpeed = 0.04
BattleConfig.AircraftHeight = 10
BattleConfig.AirFighterOffsetZ = 3
BattleConfig.AirFighterHeight = 10
BattleConfig.CommonBone = {
	rangeantiaircraft = {
		{
			1.5,
			1.1,
			0
		}
	}
}
BattleConfig.MaxLeft = -10000
BattleConfig.MaxRight = 10000
BattleConfig.BornOffset = Vector3(0, 0, 0.1)
BattleConfig.FORMATION_ID = 10001
BattleConfig.CelebrateDuration = 3
BattleConfig.EscapeDuration = 5
BattleConfig.BulletMotionRate = 0.4
BattleConfig.BulletSpeedConvertConst = 0.1
BattleConfig.ShipSpeedConvertConst = 0.01
BattleConfig.AircraftSpeedConvertConst = 0.01
BattleConfig.PLAYER_WEAPON_GLOBAL_COOL_DOWN_DURATION = 0.5
BattleConfig.PLAYER_DEFAULT = 0
BattleConfig.SPECTRE_UNIT_TYPE = -99
BattleConfig.VISIBLE_SPECTRE_UNIT_TYPE = -100
BattleConfig.FUSION_ELEMENT_UNIT_TYPE = -10000
BattleConfig.COUNT_DOWN_ESCAPE_AI_ID = 80006
BattleConfig.ESCAPE_EXPLO_TAG = {
	"unexit"
}
BattleConfig.RESOURCE_STEP = 10
BattleConfig.RESOURCE_STAY_DURATION = 2
BattleConfig.CAST_CAM_ZOOM_SIZE = 14
BattleConfig.CAST_CAM_ZOOM_IN_DURATION = 0.1
BattleConfig.CAST_CAM_ZOOM_IN_DURATION_SKILL = 0.04
BattleConfig.CAST_CAM_ZOOM_OUT_DURATION_CANNON = 0.1
BattleConfig.CAST_CAM_ZOOM_OUT_EXTRA_DELAY_CANNON = 0.04
BattleConfig.CAST_CAM_ZOOM_OUT_DELAY_CANNON = 0
BattleConfig.CAST_CAM_ZOOM_OUT_DURATION_AIR = 0.1
BattleConfig.CAST_CAM_ZOOM_OUT_EXTRA_DELAY_AIR = 0.03
BattleConfig.CAST_CAM_ZOOM_OUT_DELAY_AIR = 0.05
BattleConfig.AIR_ASSIST_SPEED_RATE = 2.8
BattleConfig.CAST_CAM_ZOOM_OUT_DURATION_SKILL = 0.04
BattleConfig.CAST_CAM_ZOOM_OUT_EXTRA_DELAY_SKILL = 0
BattleConfig.CAST_CAM_ZOOM_OUT_DELAY_SKILL = 0
BattleConfig.CALIBRATE_ACCELERATION = 1.2
BattleConfig.CAST_CAM_OVERLOOK_SIZE = 24
BattleConfig.CAST_CAM_OVERLOOK_REVERT_DURATION = 1.5
BattleConfig.CAM_RESET_DURATION = 0.7
BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER = "focusCharacter"
BattleConfig.FOCUS_MAP_RATE = 0.1
BattleConfig.MAIN_UNIT_POS = {
	[BattleConfig.FRIENDLY_CODE] = {
		Vector3(-105, 0, 58),
		Vector3(-105, 0, 78),
		Vector3(-105, 0, 38)
	},
	[BattleConfig.FOE_CODE] = {
		Vector3(15, 0, 58),
		Vector3(15, 0, 78),
		Vector3(15, 0, 38)
	}
}
BattleConfig.FIELD_RIGHT_BOUND_BIAS = 0
BattleConfig.SUB_UNIT_POS_Z = {
	58,
	78,
	38
}
BattleConfig.SUB_UNIT_OFFSET_X = -5
BattleConfig.SUB_BENCH_POS = {
	Vector3(-325, 0, 228),
	Vector3(-325, 0, 128)
}
BattleConfig.SHIP_CLD_INTERVAL = 1
BattleConfig.SHIP_CLD_BUFF = 8010
BattleConfig.START_SPEED_CONST_A = 2.5
BattleConfig.START_SPEED_CONST_B = 0.25
BattleConfig.START_SPEED_CONST_C = 0.3
BattleConfig.START_SPEED_CONST_D = 2.5
BattleConfig.GRAVITY = -0.05
BattleConfig.DUEL_MAIN_RAGE_BUFF = 6
BattleConfig.DULE_BALANCE_BUFF = 19
BattleConfig.SIMULATION_BALANCE_BUFF = 49
BattleConfig.ARENA_LIST = {
	80000,
	80001,
	80002,
	80003
}
BattleConfig.SIMULATION_FREE_BUFF = 41
BattleConfig.SIMULATION_ADVANTAGE_BUFF = 42
BattleConfig.SIMULATION_ADVANTAGE_CANCEL_LIST = {
	42,
	44,
	45
}
BattleConfig.SIMULATION_DISADVANTAGE_BUFF = 43
BattleConfig.SIMULATION_RIVAL_RAGE_TOTAL_COUNT = 30
BattleConfig.CHALLENGE_INVINCIBLE_BUFF = 50
BattleConfig.WARNING_HP_RATE = 0.7
BattleConfig.WARNING_HP_RATE_MAIN = 0.3
BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE = {}
BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[1] = {
	x = 0.924,
	scale = 1,
	y = 0.135
}
BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[2] = {
	x = 0.81,
	scale = 1,
	y = 0.135
}
BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[3] = {
	x = 0.696,
	scale = 1,
	y = 0.135
}
BattleConfig.SKILL_BUTTON_DEFAULT_PREFERENCE[4] = {
	x = 0.58,
	scale = 1,
	y = 0.135
}
BattleConfig.JOY_STICK_DEFAULT_PREFERENCE = {
	x = 0.12,
	scale = 1,
	y = 0.183
}
BattleConfig.AUTO_DEFAULT_PREFERENCE = {
	x = 0.0625,
	scale = 1,
	y = 0.925
}
BattleConfig.DOT_CONFIG = {}
BattleConfig.DOT_CONFIG[1] = {
	reduce = "igniteReduce",
	shorten = "igniteShorten",
	prolong = "igniteProlong",
	resist = "igniteResist",
	enhance = "igniteEnhance",
	hit = "ignite_accuracy"
}
BattleConfig.DOT_CONFIG[2] = {
	reduce = "floodingReduce",
	shorten = "floodingShorten",
	prolong = "floodingProlong",
	resist = "floodingResist",
	enhance = "floodingEnhance",
	hit = "flooding_accuracy"
}
BattleConfig.DOT_CONFIG[10] = {}
BattleConfig.DOT_CONFIG[20516] = {}
BattleConfig.DOT_CONFIG_DEFAULT = {
	reduce = 0,
	shorten = 0,
	prolong = 0,
	resist = 0,
	enhance = 0,
	hit = 0
}
BattleConfig.AMMO_DAMAGE_ENHANCE = {
	"damageRatioByAmmoType_1",
	"damageRatioByAmmoType_2",
	"damageRatioByAmmoType_3",
	"damageRatioByAmmoType_4",
	nil,
	nil,
	"damageRatioByAmmoType_7"
}
BattleConfig.AMMO_DAMAGE_REDUCE = {
	"damageReduceFromAmmoType_1",
	"damageReduceFromAmmoType_2",
	"damageReduceFromAmmoType_3",
	"damageReduceFromAmmoType_4",
	nil,
	nil,
	"damageReduceFromAmmoType_7"
}
BattleConfig.DAMAGE_AMMO_TO_ARMOR_RATE_ENHANCE = {
	"damageAmmoToArmorRateEnhance_1",
	"damageAmmoToArmorRateEnhance_2",
	"damageAmmoToArmorRateEnhance_3"
}
BattleConfig.DAMAGE_TO_ARMOR_RATE_ENHANCE = {
	"damageToArmorRateEnhance_1",
	"damageToArmorRateEnhance_2",
	"damageToArmorRateEnhance_3"
}
BattleConfig.SHIP_TYPE_ACCURACY_ENHANCE = {
	[ShipType.QuZhu] = "accuracyToShipType_1",
	[ShipType.QingXun] = "accuracyToShipType_2",
	[ShipType.ZhongXun] = "accuracyToShipType_3",
	[ShipType.ZhanXun] = "accuracyToShipType_4",
	[ShipType.ZhanLie] = "accuracyToShipType_5",
	[ShipType.QingHang] = "accuracyToShipType_6",
	[ShipType.ZhengHang] = "accuracyToShipType_7",
	[ShipType.QianTing] = "accuracyToShipType_8",
	[ShipType.HangXun] = "accuracyToShipType_9",
	[ShipType.HangZhan] = "accuracyToShipType_10",
	[ShipType.LeiXun] = "accuracyToShipType_11",
	[ShipType.WeiXiu] = "accuracyToShipType_12",
	[ShipType.ZhongPao] = "accuracyToShipType_13",
	[ShipType.YuLeiTing] = "accuracyToShipType_14",
	[ShipType.JinBi] = "accuracyToShipType_15",
	[ShipType.ZiBao] = "accuracyToShipType_16",
	[ShipType.QianMu] = "accuracyToShipType_17",
	[ShipType.ChaoXun] = "accuracyToShipType_18",
	[ShipType.Yunshu] = "accuracyToShipType_19",
	[ShipType.DaoQuV] = "accuracyToShipType_20",
	[ShipType.DaoQuM] = "accuracyToShipType_21",
	[ShipType.FengFanS] = "accuracyToShipType_22",
	[ShipType.FengFanV] = "accuracyToShipType_23",
	[ShipType.FengFanM] = "accuracyToShipType_24"
}
BattleConfig.OXY_RAID_BASE_LINE_PVE = -20
BattleConfig.OXY_RAID_BASE_LINE_PVP = -20
BattleConfig.SUB_DEFAULT_STAY_AI = 10006
BattleConfig.SUB_DEFAULT_ENGAGE_AI = 90001
BattleConfig.SUB_DEFAULT_RETREAT_AI = 90002
BattleConfig.SONAR_DURATION_K = 0.1
BattleConfig.SONAR_INTERVAL_K = 0.1
BattleConfig.VAN_SONAR_PROPERTY = {
	[ShipType.QuZhu] = {
		maxRange = 100,
		a = 2,
		minRange = 45,
		b = 32
	},
	[ShipType.QingXun] = {
		maxRange = 80,
		a = 2.86,
		minRange = 30,
		b = 0
	},
	[ShipType.DaoQuV] = {
		maxRange = 100,
		a = 2,
		minRange = 45,
		b = 32
	}
}
BattleConfig.MAIN_SONAR_PROPERTY = {
	maxRange = 15,
	a = 24,
	minRange = 0
}
BattleConfig.SUB_EXPOSE_LASTING_DURATION = 0.5
BattleConfig.SUB_FADE_IN_DURATION = 0.5
BattleConfig.SUB_FADE_OUT_DURATION = 0.5
BattleConfig.SUB_DIVE_IMMUNE_IGNITE_BUFF = 314
BattleConfig.SUB_FLOAT_DISIMMUNE_IGNITE_BUFF = 315
BattleConfig.PLAYER_SUB_BUBBLE_FX = "bubble"
BattleConfig.PLAYER_SUB_BUBBLE_INIT = 200
BattleConfig.PLAYER_SUB_BUBBLE_INTERVAL = 3
BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_K = 50
BattleConfig.MONSTER_SUB_KAMIKAZE_DUAL_P = 0.15
BattleConfig.BATTLE_SHADER = {}
BattleConfig.BATTLE_SHADER.SEMI_TRANSPARENT = "M02/Unlit_Colored_Semitransparent"
BattleConfig.BATTLE_SHADER.GRID_TRANSPARENT = "M02/Skeleton Colored_Additive"
BattleConfig.BATTLE_SHADER.COLORED_ALPHA = "M02/Unlit Colored_Alpha"
BattleConfig.BATTLE_DODGEM_STAGES = {
	1140101,
	1140102,
	1140103
}
BattleConfig.BATTLE_DODGEM_PASS_SCORE = 10
BattleConfig.SR_CONFIG = {}
BattleConfig.SR_CONFIG.FLOAT_CD = 2
BattleConfig.SR_CONFIG.DIVE_CD = 2
BattleConfig.SR_CONFIG.BOOST_CD = 10
BattleConfig.SR_CONFIG.SHIFT_CD = 5
BattleConfig.SR_CONFIG.BOOST_SPEED = 2
BattleConfig.SR_CONFIG.BOOST_DECAY = 0.2
BattleConfig.SR_CONFIG.BOOST_DURATION = 12
BattleConfig.SR_CONFIG.BOOST_DECAY_STAMP = 9
BattleConfig.SR_CONFIG.BASE_POINT = 100
BattleConfig.SR_CONFIG.POINT = 10
BattleConfig.SR_CONFIG.DEAD_POINT = 15
BattleConfig.SR_CONFIG.M = 2
BattleConfig.CHALLENGE_ENHANCE = {}
BattleConfig.CHALLENGE_ENHANCE.K = 1
BattleConfig.CHALLENGE_ENHANCE.X = 3
BattleConfig.CHALLENGE_ENHANCE.A = 2
BattleConfig.CHALLENGE_ENHANCE.X1 = 5
BattleConfig.CHALLENGE_ENHANCE.X2 = 5
BattleConfig.CHALLENGE_ENHANCE.Y1 = 10
BattleConfig.CHALLENGE_ENHANCE.Y2 = 5
BattleConfig.LOADING_TIPS_LIMITED_SYSTEM = {
	SYSTEM_WORLD
}
BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_B = 80
BattleConfig.WORLD_ENEMY_ENHANCEMENT_CONST_C = 1.1
BattleConfig.BULLET_DECREASE_DMG_FONT = {
	4,
	0.9
}
BattleConfig.CLOAK_EXPOSE_CONST = 50
BattleConfig.CLOAK_EXPOSE_BASE_MIN = 100
BattleConfig.CLOAK_EXPOSE_SKILL_MIN = 60
BattleConfig.CLOAK_BASE_RESTORE_DELTA = -60
BattleConfig.CLOAK_RECOVERY = 5
BattleConfig.BASE_ARP = 0.1
BattleConfig.CLOAK_STRIKE_ADDITIVE = 6
BattleConfig.CLOAK_STRIKE_ADDITIVE_LIMIT = 60
BattleConfig.CLOAK_BOMBARD_BASE_EXPOSE = 10
BattleConfig.AIM_BIAS_FLEET_RANGE_MOD = 0.18
BattleConfig.AIM_BIAS_SUB_RANGE_MOD = 0.18
BattleConfig.AIM_BIAS_MONSTER_RANGE_MOD = 0.4
BattleConfig.AIM_BIAS_DECAY_MOD = 0.01
BattleConfig.AIM_BIAS_DECAY_MOD_MONSTER = 0.01
BattleConfig.AIM_BIAS_DECAY_BASE = 0
BattleConfig.AIM_BIAS_DECAY_SUB_CONST = 50
BattleConfig.AIM_BIAS_DECAY_SMOKE = 1
BattleConfig.AIM_BIAS_DECAY_SMOKE_NIGHT = 0.8
BattleConfig.AIM_BIAS_SMOKE_RESTORE_DURATION = 3
BattleConfig.AIM_BIAS_SMOKE_RECOVERY_RATE = 0.6
BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SCOUT = 3
BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_MONSTER = 3
BattleConfig.AIM_BIAS_DECAY_SPEED_MAX_SUB = 100
BattleConfig.AIM_BIAS_MIN_RANGE_SCOUT = {
	3,
	4,
	5,
	5
}
BattleConfig.AIM_BIAS_MIN_RANGE_MONSTER = 4
BattleConfig.AIM_BIAS_MIN_RANGE_SUB = 4
BattleConfig.AIM_BIAS_MAX_RANGE_SCOUT = 25
BattleConfig.AIM_BIAS_MAX_RANGE_MONSTER = 60
BattleConfig.AIM_BIAS_MAX_RANGE_SUB = 25
BattleConfig.AIM_BIAS_ENEMY_INIT_TIME = 1.5
BattleConfig.FLEET_ATTR_CAP = {
	shenpanzhijian = 6,
	yuanchou = 9,
	Judgement = 12,
	YumiaManaFlow = 10,
	kuangsanshijian = 50,
	ReisalinAP = 99,
	KansasSP = 3,
	YumiaMANA = 100,
	huohun = 5
}
BattleConfig.TARGET_SELECT_PRIORITY = {
	C14_1 = 10,
	leastHP = 998,
	QEM_highlight = 99,
	C14_highlight = 11,
	farthest = 999,
	highlight = 99,
	xuzhang_hude = 1
}
BattleConfig.EQUIPMENT_ACTIVE_LIMITED_BY_TYPE = {
	[31] = {
		21
	},
	[32] = {
		20
	}
}
BattleConfig.TRIGGER_PRIORITY = {
	[ys.Battle.BattleConst.BuffEffectType.ON_TAKE_DAMAGE] = {
		BattleBuffHPLink = 15,
		BattleBuffCount = 30,
		BattleBuffShield = 20,
		BattleBuffLockHealth = 10,
		BattleBuffOverHealingShield = 20,
		BattleBuffRecordShield = 20,
		BattleBuffBarrier = 20,
		BattleBuffCastSkillDamageCount = 25
	}
}
BattleConfig.TRIGGER_PRIORITY_LOWEST = 99
BattleConfig.SWEET_DEATH_NATIONALITY = {
	107
}
BattleConfig.ALCHEMIST_AP_UI = {
	109
}
BattleConfig.ALCHEMIST_AP_NAME = "ReisalinAP"
BattleConfig.YUMIA_MANA_UI = {
	113
}
BattleConfig.YUMIA_MANA_NAME = "YumiaMANA"
BattleConfig.MIRROR_QICON_KEY = "_turn"
BattleConfig.MIRROR_QICON_SHIP_GROUP = {
	1150005
}
