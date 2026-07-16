ys = ys or {}

local ys = ys
local BattlePlayerCharacterFactory = singletonClass("BattlePlayerCharacterFactory", ys.Battle.BattleCharacterFactory)

ys.Battle.BattlePlayerCharacterFactory = BattlePlayerCharacterFactory
BattlePlayerCharacterFactory.__name = "BattlePlayerCharacterFactory"

--- @class BattlePlayerCharacterFactory
--- @return nil
--- 构造函数：设置友方HP条、CD条、蓄力区域、主/副箭头等UI资源名。
--- 箭头名称："EnemyArrowContainer/MainArrow"（主箭头，指向敌方）和
--- "EnemyArrowContainer/SubArrow"（副箭头，潜艇用）。
function BattlePlayerCharacterFactory.Ctor(self)
	BattlePlayerCharacterFactory.super.Ctor(self)

	self.HP_BAR_NAME = ys.Battle.BattleHPBarManager.HP_BAR_FRIENDLY
	self.CD_BAR_NAME = "CDBarContainer/chargeWeaponCD"
	self.CHARGE_AREA_NAME = "ChargeAreaContainer/ChargeArea"
	self.ARROW_BAR_NAME = "EnemyArrowContainer/MainArrow"
	self.SUB_ARROW_BAR = "EnemyArrowContainer/SubArrow"
end

--- @class BattlePlayerCharacterFactory
--- @return BattlePlayerCharacter: 玩家角色视觉对象
--- 创建BattlePlayerCharacter实例。
function BattlePlayerCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattlePlayerCharacter.New()
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter: 角色视觉对象
--- @param extraParam any|nil: 额外参数（由BattleMainFleetCharacterFactory等子类传入）
--- @return nil
--- 创建玩家角色视觉模型：
--- 1) 异步加载Spine模型 -> AddModel
--- 2) 装配全套UI组件：HP条、箭头、雷击轨道、隐形/潜行条、皮肤环绕、特效容器等
--- 3) 如果角色有AimBias且为宿主，创建瞄准偏差条
--- 该函数通过BattleResourceManager.InstCharacter异步加载模型。
function BattlePlayerCharacterFactory.MakeModel(self, character, extraParam)
	local function onModelLoaded(modelObj)
		character:AddModel(modelObj)

		local mediator = self:GetSceneMediator()

		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
		mediator:AddPlayerCharacter(character)
		self:MakeUIComponentContainer(character)
		self:MakeFXContainer(character)
		self:MakePopNumPool(character)
		self:MakeBloodBar(character)
		self:MakeArrowBar(character)
		self:MakeWaveFX(character)
		self:MakeSmokeFX(character)
		self:MakeSkinOrbit(character)

		local unitData = character:GetUnitData()

		-- 如果单位有潜行能力（潜艇），添加隐形进度条
		if unitData:GetCloak() then
			self:MakeCloakBar(character)
		end

		character:UpdateDiveInvisible()

		-- 有鱼雷武器时显示鱼雷轨道提示
		if #unitData:GetTorpedoList() > 0 then
			self:MakeTorpedoTrack(character)
		end

		-- AimBias宿主：创建瞄准偏差条
		if unitData:GetAimBias() and unitData:GetAimBias():GetHost() == unitData then
			self:MakeAimBiasBar(character)
		end
	end

	self:GetCharacterPool():InstCharacter(character:GetModleID(), function(modelObj)
		onModelLoaded(modelObj)
	end)
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter: 角色视觉对象
--- @return nil
--- 创建友方HP血条：从HPBarManager获取友方HP条，激活鱼雷图标显示子节点。
function BattlePlayerCharacterFactory.MakeBloodBar(self, character)
	local hpBar = self:GetHPBarPool():GetHPBar(self.HP_BAR_NAME)
	local hpBarTf = hpBar.transform

	-- 玩家角色显示鱼雷图标（torpedoIcons子节点）
	LuaHelper.SetTFChildActive(hpBarTf, "torpedoIcons", true)
	character:AddHPBar(hpBar)
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter: 角色视觉对象
--- @return nil
--- 创建瞄准偏差条：从角色已附加的HP条容器中查找biasBar子对象。
function BattlePlayerCharacterFactory.MakeAimBiasBar(self, character)
	local biasBar = character._HPBarTf:Find("biasBar")

	character:AddAimBiasBar(biasBar)
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter 角色视觉对象
--- @return nil
--- 创建护盾条UI（RecoilShield 专用）。从血条下查找 shieldBar 节点并绑定。
function BattlePlayerCharacterFactory.MakeShieldBar(self, character)
	local shieldBarTF = character._HPBarTf:Find("shieldBar")

	character:AddShieldBar(shieldBarTF)
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter 角色视觉对象
--- @return nil
--- 创建蓄力区域UI（某些技能需要蓄力/CD时显示）。旋转60度适配战场透视角度。
function BattlePlayerCharacterFactory.MakeChargeArea(self, character)
	local chargeArea = self:GetSceneMediator():InstantiateCharacterComponent(self.CHARGE_AREA_NAME)

	chargeArea.transform.localEulerAngles = Vector3(60, 0, 0)

	character:AddChargeArea(chargeArea)
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter: 角色视觉对象
--- @return nil
--- 创建鱼雷轨道提示：从FX池获取"SquareAlert"特效，显示鱼雷发射轨道范围。
function BattlePlayerCharacterFactory.MakeTorpedoTrack(self, character)
	local torpedoTrack = self:GetFXPool():GetFX("SquareAlert", character:GetTf())

	character:AddTorpedoTrack(torpedoTrack)
end

--- @class BattlePlayerCharacterFactory
--- @param character BattlePlayerCharacter: 角色视觉对象
--- @param reason UnitDeathReason|nil: 死亡原因
--- @return nil
--- 移除玩家角色：被击杀(KILLED)时触发屏幕震动，然后调用基类RemoveCharacter。
--- 撤退等非击杀原因不震动。
function BattlePlayerCharacterFactory.RemoveCharacter(self, character, reason)
	local mediator = self:GetSceneMediator()

	if reason and reason ~= ys.Battle.BattleConst.UnitDeathReason.KILLED then
		-- 非被击杀：不触发震动
	else
		ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[ys.Battle.BattleConst.ShakeType.UNIT_DIE])
	end

	BattlePlayerCharacterFactory.super.RemoveCharacter(self, character, reason)
end
