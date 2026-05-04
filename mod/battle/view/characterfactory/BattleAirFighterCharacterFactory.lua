ys = ys or {}

local ys = ys

--- @class BattleAirFighterCharacterFactory
--- 敌方战斗机角色工厂。继承自BattleAircraftCharacterFactory。
--- 与通用飞机工厂的区别：始终使用敌方HP条，且初始隐藏HP条（由AI控制何时显示）。
ys.Battle.BattleAirFighterCharacterFactory = singletonClass("BattleAirFighterCharacterFactory", ys.Battle.BattleAircraftCharacterFactory)
ys.Battle.BattleAirFighterCharacterFactory.__name = "BattleAirFighterCharacterFactory"

--- @class BattleAirFighterCharacterFactory
--- @return nil
--- 构造函数：设置HP条为敌方类型。敌方战斗机的HP条初始隐藏，随战斗逻辑激活。
function ys.Battle.BattleAirFighterCharacterFactory.Ctor(self)
	ys.Battle.BattleAirFighterCharacterFactory.super.Ctor(self)

	self.HP_BAR_NAME = ys.Battle.BattleHPBarManager.HP_BAR_FOE
end

--- @class BattleAirFighterCharacterFactory
--- @return BattleAirFighterCharacter: 敌方战斗机视觉对象
--- 创建BattleAirFighterCharacter实例。
function ys.Battle.BattleAirFighterCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleAirFighterCharacter.New()
end

--- @class BattleAirFighterCharacterFactory
--- @param character BattleAirFighterCharacter: 角色视觉对象
--- @return nil
--- 创建敌方战斗机视觉模型：
--- 1) 通过InstAirCharacter异步加载模型
--- 2) 装配全套：UI容器、特效挂点、伤害数字池、HP条（初始隐藏）、阴影
--- 注意：敌方战斗机始终显示HP条和伤害数字，与基类Aircraft的按IFF判断不同。
function ys.Battle.BattleAirFighterCharacterFactory.MakeModel(self, character)
	local function onModelLoaded(modelObj)
		character:AddModel(modelObj)
		character:InitWeapon()

		local mediator = self:GetSceneMediator()

		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
		mediator:AddAirCraftCharacter(character)
		self:MakeUIComponentContainer(character)
		self:MakeFXContainer(character)
		self:MakePopNumPool(character)
		self:MakeBloodBar(character)
		self:MakeShadow(character)
	end

	self:GetCharacterPool():InstAirCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end

--- @class BattleAirFighterCharacterFactory
--- @param character BattleAirFighterCharacter: 角色视觉对象
--- @return nil
--- 创建敌方战斗机HP血条：始终使用敌方HP条，创建后初始隐藏（SetActive(false)），
--- 随战斗逻辑（如进入交战范围）激活显示。更新HP条位置。
function ys.Battle.BattleAirFighterCharacterFactory.MakeBloodBar(self, character)
	local hpBar = self:GetHPBarPool():GetHPBar(self.HP_BAR_NAME)

	character:AddHPBar(hpBar)
	-- 敌方战斗机HP条初始隐藏，由AI/战斗逻辑控制何时显示
	hpBar:SetActive(false)
	character:UpdateHPBarPosition()
end
