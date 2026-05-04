ys = ys or {}

local ys = ys
local BossCharacterFactory = singletonClass("BattleBossCharacterFactory", ys.Battle.BattleEnemyCharacterFactory)

ys.Battle.BattleBossCharacterFactory = BossCharacterFactory
--- Boss敌人角色工厂
BossCharacterFactory.__name = "BattleBossCharacterFactory"
--- Boss专属爆炸特效资源名
BossCharacterFactory.BOMB_FX_NAME = "Bossbomb"

--- @class BattleBossCharacterFactory
--- @return nil
--- 构造函数：设置Boss专用HP条资源名（heroBlood）和双Boss条（ivory/ebony配色）。
--- Boss的爆炸特效也覆盖为"Bossbomb"。
function BossCharacterFactory.Ctor(self)
	BossCharacterFactory.super.Ctor(self)

	self.HP_BAR_NAME = "BossBarContainer/heroBlood"
	-- 双Boss模式下的两套HP条（象牙白/乌木黑）
	self.DUAL_BAR_NAME = {
		"BossBarContainer/heroBlood_ivory",
		"BossBarContainer/heroBlood_ebony"
	}
end

--- @class BattleBossCharacterFactory
--- @param data table: 创建数据，包含unit和bossData字段
--- @return BattleBossCharacter: Boss角色视觉对象
--- 创建Boss角色：与基类相比，额外设置BossData并添加施法时钟+护盾时钟。
function BossCharacterFactory.CreateCharacter(self, data)
	local unit = data.unit
	local character = self:MakeCharacter()

	character:SetFactory(self)
	character:SetUnitData(unit)
	character:SetBossData(data.bossData)
	self:MakeModel(character)
	self:MakeCastClock(character)
	self:MakeBarrierClock(character)

	return character
end

--- @class BattleBossCharacterFactory
--- @return BattleBossCharacter: Boss角色视觉对象
--- 创建BattleBossCharacter实例。
function BossCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleBossCharacter:New()
end

--- @class BattleBossCharacterFactory
--- @param character BattleBossCharacter: 角色视觉对象
--- @return nil
--- 创建Boss HP血条：
---   - 如果Boss有BossIndex（双Boss模式），使用双色HP条（ivory/ebony）
---   - 否则使用默认Boss条（heroBlood），标记isMain=true
function BossCharacterFactory.MakeBloodBar(self, character)
	local mediator = self:GetSceneMediator()
	local bossIndex = character:GetBossIndex()

	if bossIndex then
		-- 双Boss模式：按索引选择颜色方案
		character:AddHPBar(mediator:InstantiateCharacterComponent(self.DUAL_BAR_NAME[bossIndex]))
	else
		-- 单Boss模式：使用默认Boss条
		character:AddHPBar(mediator:InstantiateCharacterComponent(self.HP_BAR_NAME), true)
	end
end

--- @class BattleBossCharacterFactory
--- @param character BattleBossCharacter: 角色视觉对象
--- @return nil
--- 创建Boss瞄准偏差条：与常规敌人不同，Boss使用敌方HP条的模板但隐藏bg和blood子节点，
--- 将其改造为纯偏差指示条。
function BossCharacterFactory.MakeAimBiasBar(self, character)
	local foeBarTf = self:GetHPBarPool():GetHPBar(ys.Battle.BattleHPBarManager.HP_BAR_FOE).transform

	-- 隐藏常规HP条元素，保留框架作为偏差条底板
	setActive(foeBarTf:Find("bg"), false)
	setActive(foeBarTf:Find("blood"), false)
	character:AddAimBiasBar(foeBarTf)
	character:AddAimBiasFogFX()
end

--- @class BattleBossCharacterFactory
--- @param character BattleBossCharacter: 角色视觉对象
--- @return nil
--- 移除Boss角色：直接调用父类（BattleEnemyCharacterFactory）的RemoveCharacter。
function BossCharacterFactory.RemoveCharacter(self, character)
	BossCharacterFactory.super.RemoveCharacter(self, character)
end
