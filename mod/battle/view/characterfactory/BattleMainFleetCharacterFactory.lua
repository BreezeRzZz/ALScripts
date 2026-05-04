ys = ys or {}

local ys = ys

--- @class BattleMainFleetCharacterFactory
--- 主力舰队角色工厂（后排主力/旗舰）。继承自BattlePlayerCharacterFactory。
--- 与父类的区别：箭头固定使用MainArrow（主箭头），不显示皮肤环绕特效、
--- 不检查潜行/鱼雷轨道/AimBias。主力舰队角色通常在后排，UI组件更简洁。
ys.Battle.BattleMainFleetCharacterFactory = singletonClass("BattleMainFleetCharacterFactory", ys.Battle.BattlePlayerCharacterFactory)
ys.Battle.BattleMainFleetCharacterFactory.__name = "BattleMainFleetCharacterFactory"

local MainFleetCharacterFactory = ys.Battle.BattleMainFleetCharacterFactory

--- @class BattleMainFleetCharacterFactory
--- @return nil
--- 构造函数：覆盖箭头为MainArrow（主箭头，指向敌方），
--- 主力舰队不使用SubArrow。
function MainFleetCharacterFactory.Ctor(self)
	MainFleetCharacterFactory.super.Ctor(self)

	self.ARROW_BAR_NAME = "EnemyArrowContainer/MainArrow"
end

--- @class BattleMainFleetCharacterFactory
--- @return BattleMainFleetCharacter: 主力舰队角色视觉对象
--- 创建BattleMainFleetCharacter实例。
function MainFleetCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleMainFleetCharacter.New()
end

--- @class BattleMainFleetCharacterFactory
--- @param character BattleMainFleetCharacter: 角色视觉对象
--- @param extraParam any|nil: 额外参数
--- @return nil
--- 创建主力舰队视觉模型：
--- 1) 异步加载Spine模型 -> AddModel
--- 2) 注册为玩家角色（AddPlayerCharacter）
--- 3) 装配：UI容器、特效挂点、伤害数字、HP条、浪花、烟雾、箭头
--- 注意：与父类BattlePlayerCharacterFactory.MakeModel不同，主力舰队：
---   - 不创建皮肤环绕特效（MakeSkinOrbit）
---   - 不检查潜行/鱼雷轨道/AimBias（后排不需要这些）
function MainFleetCharacterFactory.MakeModel(self, character, extraParam)
	local function onModelLoaded(modelObj)
		character:AddModel(modelObj)

		local mediator = self:GetSceneMediator()

		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
		mediator:AddPlayerCharacter(character)
		self:MakeUIComponentContainer(character)
		self:MakeFXContainer(character)
		self:MakePopNumPool(character)
		self:MakeBloodBar(character)
		self:MakeWaveFX(character)
		self:MakeSmokeFX(character)
		self:MakeArrowBar(character)
	end

	self:GetCharacterPool():InstCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end
