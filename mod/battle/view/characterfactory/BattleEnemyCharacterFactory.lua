ys = ys or {}

local ys = ys
local BattleEnemyCharacterFactory = singletonClass("BattleEnemyCharacterFactory", ys.Battle.BattleCharacterFactory)

ys.Battle.BattleEnemyCharacterFactory = BattleEnemyCharacterFactory
BattleEnemyCharacterFactory.__name = "BattleEnemyCharacterFactory"

--- @class BattleEnemyCharacterFactory
--- @return nil
--- 构造函数：设置敌方HP条（enemyBlood）和敌方箭头（EnemyArrow）资源名。
function BattleEnemyCharacterFactory.Ctor(self)
	BattleEnemyCharacterFactory.super.Ctor(self)

	self.HP_BAR_NAME = ys.Battle.BattleHPBarManager.HP_BAR_FOE
	self.ARROW_BAR_NAME = "EnemyArrowContainer/EnemyArrow"
end

--- @class BattleEnemyCharacterFactory
--- @return BattleEnemyCharacter: 敌方角色视觉对象
--- 创建BattleEnemyCharacter实例。
function BattleEnemyCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleEnemyCharacter.New()
end

--- @class BattleEnemyCharacterFactory
--- @param character BattleEnemyCharacter: 角色视觉对象
--- @return nil
--- 创建敌方角色视觉模型：
--- 1) 加载模型 -> AddModel -> 注册到SceneMediator
--- 2) 装配UI组件：HP条（含船型图标）、箭头、浪花、烟雾、特效挂点等
--- 3) 更新潜水隐身、强制索敌、致盲隐身状态
--- 4) 添加模板配置的出场特效（appear_fx）
--- 5) 若有AimBias则创建瞄准偏差条
function BattleEnemyCharacterFactory.MakeModel(self, character)
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
		character:UpdateDiveInvisible(true)
		character:UpdateCharacterForceDetected()
		character:UpdateBlindInvisible()

		-- 添加模板中配置的出场特效（如登场光柱等）
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

--- @class BattleEnemyCharacterFactory
--- @param character BattleEnemyCharacter: 角色视觉对象
--- @return nil
--- 创建敌方箭头：从BattleArrowManager获取箭头并附加。箭头用于指示屏幕外的敌方位置。
function BattleEnemyCharacterFactory.MakeArrowBar(self, character)
	local arrow = self:GetArrowPool():GetArrow()

	character:AddArrowBar(arrow)
	character:UpdateArrowBarPosition()
end

--- @class BattleEnemyCharacterFactory
--- @return BattleArrowManager: 箭头管理器
--- 获取敌方箭头对象池管理器。
function BattleEnemyCharacterFactory.GetArrowPool(self)
	return ys.Battle.BattleArrowManager.GetInstance()
end

--- @class BattleEnemyCharacterFactory
--- @param character BattleEnemyCharacter: 角色视觉对象
--- @return nil
--- 创建敌方HP血条：
---   1) 从HPBarManager获取敌方HP条
---   2) 根据模板icon_type设置船型图标（从Atlas加载对应图标）
---   3) 图标非0时显示船型，0时隐藏type节点
---   4) 附加HP条后更新位置
function BattleEnemyCharacterFactory.MakeBloodBar(self, character)
	local hpBar = self:GetHPBarPool():GetHPBar(self.HP_BAR_NAME)
	local iconType = character:GetUnitData():GetTemplate().icon_type
	local typeTf = findTF(hpBar, "type")

	if iconType ~= 0 then
		-- 有船型图标：从shiptype atlas加载对应图标
		local typeIcon = GetSpriteFromAtlas("shiptype", shipType2print(character:GetUnitData():GetTemplate().icon_type))

		setImageSprite(typeTf, typeIcon, true)

		-- 内部也设置同样的图标（可能是不同分辨率/比例）
		local innerType = findTF(typeTf, "type")

		setImageSprite(innerType, typeIcon, true)
		SetActive(typeTf, true)
	else
		-- 无船型图标（icon_type=0）：隐藏
		SetActive(typeTf, false)
	end

	character:AddHPBar(hpBar)
	character:UpdateHPBarPosition()
end

--- @class BattleEnemyCharacterFactory
--- @param character BattleEnemyCharacter: 角色视觉对象
--- @return nil
--- 创建瞄准偏差条：从HP条容器中查找biasBar子对象，附加迷雾特效。
function BattleEnemyCharacterFactory.MakeAimBiasBar(self, character)
	local biasBar = character._HPBarTf:Find("biasBar")

	character:AddAimBiasBar(biasBar)
	character:AddAimBiasFogFX()
end

--- @class BattleEnemyCharacterFactory
--- @param character BattleEnemyCharacter: 角色视觉对象
--- @return nil
--- 创建浪花特效：从模板读取wave_fx字段。若为空字符串则不覆盖基类默认浪花。
--- 非空时使用模板指定的浪花资源名（如某些敌人使用特殊浪花效果）。
function BattleEnemyCharacterFactory.MakeWaveFX(self, character)
	local waveFxName = character:GetUnitData():GetTemplate().wave_fx

	if waveFxName ~= "" then
		character:AddWaveFX(waveFxName)
	end
end

--- @class BattleEnemyCharacterFactory
--- @param character BattleEnemyCharacter: 角色视觉对象
--- @return nil
--- 移除敌方角色：触发屏幕震动后调用基类RemoveCharacter。
--- 敌方死亡始终触发震动（与玩家角色区分，玩家撤退不震动）。
function BattleEnemyCharacterFactory.RemoveCharacter(self, character)
	ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[ys.Battle.BattleConst.ShakeType.UNIT_DIE])
	BattleEnemyCharacterFactory.super.RemoveCharacter(self, character)
end
