ys = ys or {}

local ys = ys
local NPCCharacterFactory = singletonClass("BattleNPCCharacterFactory", ys.Battle.BattleEnemyCharacterFactory)

ys.Battle.BattleNPCCharacterFactory = NPCCharacterFactory
--- NPC角色工厂（剧情/特殊事件中的中立/友好单位，按敌方逻辑渲染但允许自定义）
NPCCharacterFactory.__name = "BattleNPCCharacterFactory"

--- @class BattleNPCCharacterFactory
--- @return nil
--- 构造函数：使用敌方HP条。NPC按敌方视觉逻辑处理但可为中立。
function NPCCharacterFactory.Ctor(self)
	NPCCharacterFactory.super.Ctor(self)

	self.HP_BAR_NAME = ys.Battle.BattleHPBarManager.HP_BAR_FOE
end

--- @class BattleNPCCharacterFactory
--- @param data table: 创建数据，包含unit和extraInfo字段
--- @return BattleNPCCharacter: NPC角色视觉对象
--- 创建NPC角色：与基类不同的地方在于可以从extraInfo中读取自定义
--- modleID（模型ID）、HPColor（HP条颜色）、isUnvisible（初始不可见）。
function NPCCharacterFactory.CreateCharacter(self, data)
	local extraInfo = data.extraInfo
	local unit = data.unit
	local character = self:MakeCharacter()

	character:SetFactory(self)
	character:SetUnitData(unit)

	-- 支持自定义模型ID（如剧情用的特殊模型）
	if extraInfo.modleID then
		character:SetModleID(extraInfo.modleID)
	end

	-- 支持自定义HP条颜色
	if extraInfo.HPColor then
		character:SetHPColor(extraInfo.HPColor)
	end

	-- 支持初始不可见（如需要触发后才出现的NPC）
	if extraInfo.isUnvisible then
		character:SetUnvisible()
	end

	self:MakeModel(character)

	return character
end

--- @class BattleNPCCharacterFactory
--- @param character BattleNPCCharacter: 角色视觉对象
--- @return nil
--- 创建NPC视觉模型：
--- 1) 异步加载模型 -> AddModel
--- 2) 注册到SceneMediator作为敌方角色（AddEnemyCharacter）
--- 3) 装配UI组件：含箭头（指示位置）
--- 4) 添加出场特效
--- 5) 调用MakeVisible确保可见（覆盖extraInfo.isUnvisible设置）
--- 注意：NPC不调用UpdateDiveInvisible和UpdateBlindInvisible，因为它不参与常规战斗逻辑。
function NPCCharacterFactory.MakeModel(self, character)
	local unitData = character:GetUnitData()

	local function onModelLoaded(modelObj)
		character:AddModel(modelObj)

		local mediator = self:GetSceneMediator()

		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
		mediator:AddEnemyCharacter(character)
		self:MakeUIComponentContainer(character)
		self:MakeFXContainer(character)
		self:MakePopNumPool(character)
		self:MakeBloodBar(character)
		self:MakeWaveFX(character)
		self:MakeSmokeFX(character)
		self:MakeArrowBar(character)

		-- 添加出场特效
		local appearFXList = unitData:GetTemplate().appear_fx

		for _, fxID in ipairs(appearFXList) do
			character:AddFX(fxID)
		end

		-- 确保最终可见（覆盖SetUnvisible的默认隐藏）
		character:MakeVisible()
	end

	self:GetCharacterPool():InstCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end

--- @class BattleNPCCharacterFactory
--- @return BattleNPCCharacter: NPC角色视觉对象
--- 创建BattleNPCCharacter实例。
function NPCCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleNPCCharacter.New()
end

--- @class BattleNPCCharacterFactory
--- @param character BattleNPCCharacter: 角色视觉对象
--- @return nil
--- 创建NPC HP血条：使用敌方HP条模板，支持HPColor自定义血条颜色。
--- 如果角色有HPColor设定，则设置blood Image的颜色。
function NPCCharacterFactory.MakeBloodBar(self, character)
	local hpBar = self:GetHPBarPool():GetHPBar(self.HP_BAR_NAME)
	local hpBarTf = hpBar.transform
	local hpColor = character:GetHPColor()

	-- 自定义HP条颜色（如剧情NPC使用特殊颜色区分）
	if hpColor then
		hpBarTf:Find("blood"):GetComponent(typeof(Image)).color = hpColor
	end

	character:AddHPBar(hpBar)
	character:UpdateHPBarPosition()
end
