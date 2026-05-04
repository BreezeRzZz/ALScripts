ys = ys or {}

local ys = ys
local MinionCharacterFactory = singletonClass("BattleMinionCharacterFactory", ys.Battle.BattleCharacterFactory)

ys.Battle.BattleMinionCharacterFactory = MinionCharacterFactory
--- 召唤物/仆从角色工厂（如玩家航母的召唤飞机、敌方召唤单位等）
MinionCharacterFactory.__name = "BattleMinionCharacterFactory"

--- @class BattleMinionCharacterFactory
--- @return nil
--- 构造函数：无特殊初始化，HP条等由方法动态判断。
function MinionCharacterFactory.Ctor(self)
	MinionCharacterFactory.super.Ctor(self)
end

--- @class BattleMinionCharacterFactory
--- @return BattleMinionCharacter: 召唤物视觉对象
--- 创建BattleMinionCharacter实例。
function MinionCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleMinionCharacter.New()
end

--- @class BattleMinionCharacterFactory
--- @param character BattleMinionCharacter: 角色视觉对象
--- @return nil
--- 创建召唤物视觉模型：
--- 1) 异步加载模型 -> AddModel
--- 2) 注册到SceneMediator作为敌方角色（AddEnemyCharacter，因为召唤物通常由玩家编队产生但按敌方逻辑显示）
--- 3) 装配全套UI和特效：HP条（根据IFF动态选类型）、浪花、烟雾、出场特效等
--- 4) 更新潜水隐身和致盲隐身
function MinionCharacterFactory.MakeModel(self, character)
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
		character:UpdateDiveInvisible(true)
		character:UpdateBlindInvisible()

		-- 添加模板配置的出场特效
		local appearFXList = unitData:GetTemplate().appear_fx

		for _, fxID in ipairs(appearFXList) do
			character:AddFX(fxID)
		end

		-- 如果有瞄准偏差系统，创建偏差条
		if character:GetUnitData():GetAimBias() then
			self:MakeAimBiasBar(character)
		end
	end

	self:GetCharacterPool():InstCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end

--- @class BattleMinionCharacterFactory
--- @param character BattleMinionCharacter: 角色视觉对象
--- @return nil
--- 创建召唤物HP血条：根据IFF动态选择友方/敌方条。
--- 若IFF为友方(FRIENDLY_CODE)用heroBlood，否则用enemyBlood。
--- 隐藏船型图标，因为召唤物通常不需要。
function MinionCharacterFactory.MakeBloodBar(self, character)
	local unitData = character:GetUnitData()
	local barName

	if unitData:GetIFF() == ys.Battle.BattleConfig.FRIENDLY_CODE then
		barName = ys.Battle.BattleHPBarManager.HP_BAR_FRIENDLY
	else
		barName = ys.Battle.BattleHPBarManager.HP_BAR_FOE
	end

	local hpBar = self:GetHPBarPool():GetHPBar(barName)
	local iconType = unitData:GetTemplate().icon_type
	local typeTf = findTF(hpBar, "type")

	-- 召唤物隐藏船型图标
	if typeTf then
		SetActive(typeTf, false)
	end

	character:AddHPBar(hpBar)
	character:UpdateHPBarPosition()
end

--- @class BattleMinionCharacterFactory
--- @param character BattleMinionCharacter: 角色视觉对象
--- @return nil
--- 创建瞄准偏差条：从HP条容器中查找biasBar，附加迷雾特效。
function MinionCharacterFactory.MakeAimBiasBar(self, character)
	local biasBar = character._HPBarTf:Find("biasBar")

	character:AddAimBiasBar(biasBar)
	character:AddAimBiasFogFX()
end

--- @class BattleMinionCharacterFactory
--- @param character BattleMinionCharacter: 角色视觉对象
--- @return nil
--- 创建浪花特效：从模板wave_fx读取自定义名称。空字符串时使用基类默认。
function MinionCharacterFactory.MakeWaveFX(self, character)
	local waveFxName = character:GetUnitData():GetTemplate().wave_fx

	if waveFxName ~= "" then
		character:AddWaveFX(waveFxName)
	end
end

--- @class BattleMinionCharacterFactory
--- @param character BattleMinionCharacter: 角色视觉对象
--- @return nil
--- 移除召唤物：触发屏幕震动后调用基类RemoveCharacter。
function MinionCharacterFactory.RemoveCharacter(self, character)
	ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[ys.Battle.BattleConst.ShakeType.UNIT_DIE])
	MinionCharacterFactory.super.RemoveCharacter(self, character)
end
