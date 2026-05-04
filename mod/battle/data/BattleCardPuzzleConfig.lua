ys.Battle.BattleCardPuzzleConfig = ys.Battle.BattleCardPuzzleConfig or {}

local BattleCardPuzzleConfig = ys.Battle.BattleCardPuzzleConfig

-- 基础能量回复速度（每秒）
BattleCardPuzzleConfig.baseEnergyGenerateSpeedPerSecond = 1
-- 初始能量
BattleCardPuzzleConfig.baseEnergyInitial = 5
-- 手牌上限
BattleCardPuzzleConfig.BASE_MAX_HAND = 6
-- 移动卡能量回复速度（每秒）
BattleCardPuzzleConfig.moveCardGenerateSpeedPerSecond = 0.5
-- 移动次数上限
BattleCardPuzzleConfig.BASE_MAX_MOVE = 30
-- 基础移动技能ID
BattleCardPuzzleConfig.BASE_MOVE_ID = 20001
-- 自定义属性初始化列表
BattleCardPuzzleConfig.CustomAttrInitList = {
	CardComboMin = 0,
	CardComboMax = 50
}
-- 舰队属性钳制范围（min/max对应属性名）
BattleCardPuzzleConfig.FleetAttrClamp = {
	CardCombo = {
		max = "CardComboMax",
		min = "CardComboMin"
	}
}
-- 舰队图标注册属性
BattleCardPuzzleConfig.FleetIconRegisterAttr = {
	CardCombo = 202,
	CardAntiaircraft = 202
}
-- 舰队图标注册Buff（BuffID -> 图标类型）
BattleCardPuzzleConfig.FleetIconRegisterBuff = {
	[530050] = 202
}
