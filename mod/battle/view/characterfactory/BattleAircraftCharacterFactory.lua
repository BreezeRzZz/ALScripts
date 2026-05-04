ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local AircraftCharacterFactory = singletonClass("BattleAircraftCharacterFactory", ys.Battle.BattleCharacterFactory)

ys.Battle.BattleAircraftCharacterFactory = AircraftCharacterFactory
--- 飞机角色工厂（舰载机/航空器）
AircraftCharacterFactory.__name = "BattleAircraftCharacterFactory"
--- 飞机专属爆炸特效资源名
AircraftCharacterFactory.BOMB_FX_NAME = "feijibaozha"

--- @class BattleAircraftCharacterFactory
--- @return nil
--- 构造函数（无特殊初始化，HP_BAR_NAME等由MakeBloodBar动态判断）。
function AircraftCharacterFactory.Ctor(self)
	AircraftCharacterFactory.super.Ctor(self)
end

--- @class BattleAircraftCharacterFactory
--- @return BattleAircraftCharacter: 飞机角色视觉对象
--- 创建BattleAircraftCharacter实例。
function AircraftCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleAircraftCharacter.New()
end

--- @class BattleAircraftCharacterFactory
--- @param character BattleAircraftCharacter: 角色视觉对象
--- @return nil
--- 创建飞机视觉模型：
--- 1) 通过InstAirCharacter（飞机专用加载）异步加载模型
--- 2) 装配UI容器、特效挂点、阴影
--- 3) 仅敌方飞机（IFF == FOE_CODE）显示HP条和伤害数字
--- 注意：飞机不显示浪花和烟雾特效。
function AircraftCharacterFactory.MakeModel(self, character)
	local function onModelLoaded(modelObj)
		character:AddModel(modelObj)
		character:InitWeapon()

		local mediator = self:GetSceneMediator()

		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
		mediator:AddAirCraftCharacter(character)
		self:MakeUIComponentContainer(character)
		self:MakeFXContainer(character)
		self:MakeShadow(character)

		-- 仅敌方飞机显示HP条和受击数字
		if character:GetUnitData():GetIFF() == BattleConfig.FOE_CODE then
			self:MakePopNumPool(character)
			self:MakeBloodBar(character)
		end
	end

	self:GetCharacterPool():InstAirCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end

--- @class BattleAircraftCharacterFactory
--- @param character BattleAircraftCharacter: 角色视觉对象
--- @return nil
--- 创建飞机HP血条：根据是否为玩家飞机选择友方/敌方血条。
--- 友方飞机 = HP_BAR_FRIENDLY，敌方飞机 = HP_BAR_FOE。
function AircraftCharacterFactory.MakeBloodBar(self, character)
	local hpBar

	if character:GetUnitData():IsPlayerAircraft() then
		hpBar = self:GetHPBarPool():GetHPBar(ys.Battle.BattleHPBarManager.HP_BAR_FRIENDLY)
	else
		hpBar = self:GetHPBarPool():GetHPBar(ys.Battle.BattleHPBarManager.HP_BAR_FOE)
	end

	character:AddHPBar(hpBar)
	character:UpdateHPBarPosition()
end

--- @class BattleAircraftCharacterFactory
--- @param character BattleAircraftCharacter: 角色视觉对象
--- @param barObj GameObject: HP条GameObject
--- @param extraWidth number: 额外宽度偏移
--- @return nil
--- 设置飞机HP条宽度：飞机使用固定40px宽度（而非模板数据），
--- 因为飞机在屏幕上较小，不需要太长的血条。
function AircraftCharacterFactory.SetHPBarWidth(self, character, barObj, extraWidth)
	local fixedWidth = 40
	local barTf = barObj.transform
	local barHeight = barTf.rect.height

	barTf.sizeDelta = Vector2(fixedWidth, barHeight)

	local bloodTf = barTf:Find("blood").transform
	local bloodHeight = bloodTf.rect.height

	bloodTf.sizeDelta = Vector2(fixedWidth - extraWidth or 0, bloodHeight)
end

--- @class BattleAircraftCharacterFactory
--- @param character BattleAircraftCharacter: 角色视觉对象
--- @return nil
--- 创建飞机阴影：飞机在地面上的投影阴影，增强高度感。
function AircraftCharacterFactory.MakeShadow(self, character)
	character:AddShadow()
	character:UpdateShadow()
end
