ys = ys or {}

local ys = ys
local SupportCharacterFactory = singletonClass("BattleSupportCharacterFactory", ys.Battle.BattleCharacterFactory)

ys.Battle.BattleSupportCharacterFactory = SupportCharacterFactory
--- 支援角色工厂（增援/支援舰队单位）。继承自BattleCharacterFactory基类。
--- 与常规敌人/玩家的区别：仅加载模型和更新隐身状态，不创建HP条、箭头、
--- 伤害数字、特效挂点、浪花烟雾等UI组件。支援角色通常由系统自动控制，
--- UI展示较为简洁。
SupportCharacterFactory.__name = "BattleSupportCharacterFactory"

--- @class BattleSupportCharacterFactory
--- @return nil
--- 构造函数：无特殊初始化。
function SupportCharacterFactory.Ctor(self)
	SupportCharacterFactory.super.Ctor(self)
end

--- @class BattleSupportCharacterFactory
--- @return BattleSupportCharacter: 支援角色视觉对象
--- 创建BattleSupportCharacter实例。
function SupportCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleSupportCharacter.New()
end

--- @class BattleSupportCharacterFactory
--- @param character BattleSupportCharacter: 角色视觉对象
--- @return nil
--- 创建支援角色视觉模型：
--- 1) 异步加载模型 -> AddModel
--- 2) 注册到SceneMediator作为敌方角色（AddEnemyCharacter）
--- 3) 更新潜水隐身和致盲隐身
--- 注意：支援角色不创建HP条、箭头、伤害数字、特效挂点、浪花烟雾等。
--- 是最轻量的角色模型创建流程。
function SupportCharacterFactory.MakeModel(self, character)
	local unitData = character:GetUnitData()

	local function onModelLoaded(modelObj)
		character:AddModel(modelObj)

		local mediator = self:GetSceneMediator()

		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
		mediator:AddEnemyCharacter(character)
		character:UpdateDiveInvisible(true)
		character:UpdateBlindInvisible()
	end

	self:GetCharacterPool():InstCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end

--- @class BattleSupportCharacterFactory
--- @param character BattleSupportCharacter: 角色视觉对象
--- @return nil
--- 创建支援角色HP血条（可选）：根据IFF选择友方/敌方条，隐藏船型图标。
--- 注意：MakeModel中不自动调用此方法，仅在需要时由外部调用。
function SupportCharacterFactory.MakeBloodBar(self, character)
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

	-- 支援角色隐藏船型图标
	if typeTf then
		SetActive(typeTf, false)
	end

	character:AddHPBar(hpBar)
	character:UpdateHPBarPosition()
end

--- @class BattleSupportCharacterFactory
--- @param character BattleSupportCharacter: 角色视觉对象
--- @return nil
--- 创建瞄准偏差条：从HP条容器中查找biasBar，附加迷雾特效。
function SupportCharacterFactory.MakeAimBiasBar(self, character)
	local biasBar = character._HPBarTf:Find("biasBar")

	character:AddAimBiasBar(biasBar)
	character:AddAimBiasFogFX()
end

--- @class BattleSupportCharacterFactory
--- @param character BattleSupportCharacter: 角色视觉对象
--- @return nil
--- 创建浪花特效：从模板wave_fx读取自定义名称。空字符串时使用基类默认。
function SupportCharacterFactory.MakeWaveFX(self, character)
	local waveFxName = character:GetUnitData():GetTemplate().wave_fx

	if waveFxName ~= "" then
		character:AddWaveFX(waveFxName)
	end
end

--- @class BattleSupportCharacterFactory
--- @param character BattleSupportCharacter: 角色视觉对象
--- @return nil
--- 移除支援角色：触发屏幕震动后调用基类RemoveCharacter。
function SupportCharacterFactory.RemoveCharacter(self, character)
	ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[ys.Battle.BattleConst.ShakeType.UNIT_DIE])
	SupportCharacterFactory.super.RemoveCharacter(self, character)
end
