ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleCharacterFactory = singletonClass("BattleCharacterFactory")

ys.Battle.BattleCharacterFactory = BattleCharacterFactory
BattleCharacterFactory.__name = "BattleCharacterFactory"

--- 友方HP条资源名（子类覆盖）
BattleCharacterFactory.HP_BAR_NAME = ""
--- 弹出提示UI资源名
BattleCharacterFactory.POPUP_NAME = "popup"
--- 锁定标记UI资源路径
BattleCharacterFactory.TAG_NAME = "ChargeAreaContainer/LockTag"
--- 移动浪花特效偏移位置
BattleCharacterFactory.MOVE_WAVE_FX_POS = Vector3(0, -2.3, -1.5)
--- 移动浪花特效资源名
BattleCharacterFactory.MOVE_WAVE_FX_NAME = "movewave"
--- 烟雾特效资源名
BattleCharacterFactory.SMOKE_FX_NAME = "smoke"
--- 默认爆炸特效资源名
BattleCharacterFactory.BOMB_FX_NAME = "Bomb"
--- 单船浪花特效资源名（小型船只/舢板专用）
BattleCharacterFactory.DANCHUAN_MOVE_WAVE_FX_NAME = "danchuanlanghuazhong2"

--- @class BattleCharacterFactory
--- @return nil
--- 构造函数。子类在Ctor中设置HP_BAR_NAME、ARROW_BAR_NAME等资源名。
function BattleCharacterFactory.Ctor(self)
	return
end

--- @class BattleCharacterFactory
--- @param data table: 创建数据，包含unit字段（BattleUnit数据层对象）
--- @return BattleCharacter: 创建好的角色视觉对象
--- 创建角色的主入口：1) 分配角色对象 2) 绑定工厂和数据层 3) 创建视觉模型。
function BattleCharacterFactory.CreateCharacter(self, data)
	local unit = data.unit
	local character = self:MakeCharacter()

	character:SetFactory(self)
	character:SetUnitData(unit)
	self:MakeModel(character)

	return character
end

--- @class BattleCharacterFactory
--- @return BattleSceneMediator: 场景中介者
--- 获取当前战斗场景的中介者，用于实例化UI组件。
function BattleCharacterFactory.GetSceneMediator(self)
	return ys.Battle.BattleState.GetInstance():GetMediatorByName(ys.Battle.BattleSceneMediator.__name)
end

--- @class BattleCharacterFactory
--- @return BattleFXPool: 特效对象池
--- 获取BattleFXPool（即BattleCharacterFXContainersPool别名，用于角色特效挂点回收）。
function BattleCharacterFactory.GetFXPool(self)
	return ys.Battle.BattleFXPool.GetInstance()
end

--- @class BattleCharacterFactory
--- @return BattleResourceManager: 角色资源管理器
--- 获取角色模型资源管理器（负责加载Spine/模型prefab）。
function BattleCharacterFactory.GetCharacterPool(self)
	return ys.Battle.BattleResourceManager.GetInstance()
end

--- @class BattleCharacterFactory
--- @return BattleHPBarManager: HP条管理器
--- 获取HP条对象池管理器。
function BattleCharacterFactory.GetHPBarPool(self)
	return ys.Battle.BattleHPBarManager.GetInstance()
end

--- @class BattleCharacterFactory
--- @return Color: 潜水滤镜颜色
--- 根据当前地图的潜水滤镜配置返回Color。用于水下场景的颜色校正。
function BattleCharacterFactory.GetDivingFilterColor(self)
	local mapId = ys.Battle.BattleDataProxy.GetInstance()._mapId
	local filterData = ys.Battle.BattleDataFunction.GetDivingFilter(mapId)

	return (Color.New(filterData.r, filterData.g, filterData.b, filterData.a))
end

--- @class BattleCharacterFactory
--- @return BattleCharacterFXContainersPool: 特效挂点容器池
--- 获取角色特效挂点容器池。
function BattleCharacterFactory.GetFXContainerPool(self)
	return ys.Battle.BattleCharacterFXContainersPool.GetInstance()
end

--- @class BattleCharacterFactory
--- @return BattleCharacter|nil
--- 虚函数：子类重写，创建对应类型的角色数据对象。
function BattleCharacterFactory.MakeCharacter(self)
	return nil
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 虚函数：子类重写，加载并设置角色的视觉模型。
function BattleCharacterFactory.MakeModel(self, character)
	return nil
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 虚函数：子类重写，创建HP血条UI。
function BattleCharacterFactory.MakeBloodBar(self, character)
	return nil
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 虚函数：创建瞄准偏差条（AimBias）。仅当该角色为AimBias宿主时由子类调用。
function BattleCharacterFactory.MakeAimBiasBar(self, character)
	return nil
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @param barObj GameObject: HP条GameObject
--- @param extraWidth number|nil: 额外宽度偏移（如Boss）或nil
--- @return nil
--- 设置HP条宽度：从模板的hp_bar[1]读取基准宽度，分别设置背景和血条fill的sizeDelta。
function BattleCharacterFactory.SetHPBarWidth(self, character, barObj, extraWidth)
	local barWidth = character:GetUnitData():GetTemplate().hp_bar[1]
	local barTf = barObj.transform
	local barHeight = barTf.rect.height

	barTf.sizeDelta = Vector2(barWidth, barHeight)

	local bloodTf = barTf:Find("blood").transform
	local bloodHeight = bloodTf.rect.height

	bloodTf.sizeDelta = Vector2(barWidth + extraWidth or 0, bloodHeight)
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 为角色创建UI组件容器（Popup弹出提示、Tag锁定标记等容器）。
function BattleCharacterFactory.MakeUIComponentContainer(self, character)
	character:AddUIComponentContainer()
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 为角色创建特效挂点容器。从池中弹出一个挂点，附着到角色transform，
--- 并遍历BattleConst.FXContainerIndex从模板中读取各挂点坐标偏移。
function BattleCharacterFactory.MakeFXContainer(self, character)
	local characterTf = character:GetTf()
	local attachPoint = self:GetFXPool():PopCharacterAttachPoint()
	local attachTf = attachPoint.transform

	SetActive(attachTf, true)
	attachTf:SetParent(characterTf, false)

	attachTf.localPosition = Vector3.zero

	local charEulerAngles = characterTf.localEulerAngles

	-- 反转X轴方向以适配挂点坐标（挂点使用独立坐标系）
	attachTf.localEulerAngles = Vector3(charEulerAngles.x * -1, charEulerAngles.y, charEulerAngles.z)

	local fxContainerData = character:GetUnitData():GetTemplate().fx_container
	local fxOffsets = {}

	for index, fxIndexName in ipairs(ys.Battle.BattleConst.FXContainerIndex) do
		local posData = fxContainerData[index]

		fxOffsets[index] = Vector3(posData[1], posData[2], posData[3])
	end

	character:AddFXOffsets(attachPoint, fxOffsets)
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 虚函数：子类重写，创建角色阴影（飞机等空中单位需要）。
function BattleCharacterFactory.MakeShadow(self, character)
	return nil
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建烟雾特效：从模板的smoke配置中读取多组烟雾信息。
--- 每组烟雾包含触发HP百分比阈值（rate）和若干特效资源（smokes）。
--- smokes列表的每个元素包含resID（资源ID）和pos（相对位置偏移）。
function BattleCharacterFactory.MakeSmokeFX(self, character)
	local smokeConfig = character:GetUnitData():GetTemplate().smoke
	local smokeGroups = {}

	for groupIndex, groupData in ipairs(smokeConfig) do
		local smokeList = groupData[2]
		local smokes = {}

		for _, smokeItem in ipairs(smokeList) do
			local smokeEntry = {}

			smokeEntry.unInitialize = true
			smokeEntry.resID = smokeItem[1]
			smokeEntry.pos = Vector3(smokeItem[2][1], smokeItem[2][2], smokeItem[2][3])
			smokes[smokeEntry] = false
		end

		-- groupData[1] 是触发烟雾的HP百分比（除以100得到0~1比例）
		smokeGroups[groupIndex] = {
			active = false,
			rate = groupData[1] / 100,
			smokes = smokes
		}
	end

	character:AddSmokeFXs(smokeGroups)
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建移动浪花特效（默认使用MOVE_WAVE_FX_NAME）。水面单位移动时显示。
function BattleCharacterFactory.MakeWaveFX(self, character)
	character:AddWaveFX(self.MOVE_WAVE_FX_NAME)
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 为角色添加伤害/治疗数字弹出池。
function BattleCharacterFactory.MakePopNumPool(self, character)
	character:AddPopNumPool(self:GetSceneMediator():GetPopNumPool())
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return BattleLockTag: 锁定标记组件
--- 创建锁定标记（显示在角色头顶，用于指示当前被锁定的目标）。
function BattleCharacterFactory.MakeTag(self, character)
	return (ys.Battle.BattleLockTag.New(self:GetSceneMediator():InstantiateCharacterComponent(self.TAG_NAME), character))
end

--- @class BattleCharacterFactory
--- @return GameObject: 弹出提示GameObject
--- 实例化弹出提示UI组件（用于显示闪避/EVA等提示）。
function BattleCharacterFactory.MakePopup(self)
	return (self:GetSceneMediator():InstantiateCharacterComponent(self.POPUP_NAME))
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建箭头指示条（用于指向敌方位置/船锚目标），通过场景中介者实例化。
function BattleCharacterFactory.MakeArrowBar(self, character)
	local mediator = self:GetSceneMediator()

	character:AddArrowBar(mediator:InstantiateCharacterComponent(self.ARROW_BAR_NAME))
	character:UpdateArrowBarPosition()
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建技能施法时钟（显示技能冷却/施法进度的环形计时器）。
function BattleCharacterFactory.MakeCastClock(self, character)
	local mediator = self:GetSceneMediator()

	character:AddCastClock(mediator:InstantiateCharacterComponent("CastClockContainer/castClock"))
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建Buff时钟（Buff持续时间的环形计时器）。
function BattleCharacterFactory.MakeBuffClock(self, character)
	local mediator = self:GetSceneMediator()

	character:AddBuffClock(mediator:InstantiateCharacterComponent("CastClockContainer/buffClock"))
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建屏障/护盾时钟（护盾持续时间的环形计时器）。
function BattleCharacterFactory.MakeBarrierClock(self, character)
	local mediator = self:GetSceneMediator()

	character:AddBarrierClock(mediator:InstantiateCharacterComponent("CastClockContainer/shieldClock"))
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建对潜警戒条（反潜探测/索敌进度条）。
function BattleCharacterFactory.MakeVigilantBar(self, character)
	local mediator = self:GetSceneMediator()

	character:AddVigilantBar(mediator:InstantiateCharacterComponent("AntiSubVigilantContainer/antiSubMeter"))
	character:UpdateVigilantBarPosition()
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建隐形/潜行条（潜艇隐蔽进度条，显示何时完全暴露）。
function BattleCharacterFactory.MakeCloakBar(self, character)
	local mediator = self:GetSceneMediator()

	character:AddCloakBar(mediator:InstantiateCharacterComponent("CloakContainer/cloakMeter"))
	character:UpdateCloakBarPosition()
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @return nil
--- 创建皮肤环绕轨道特效（orbit effect）。根据角色的皮肤附件信息（equip_skin），
--- 实例化对应的环绕特效。支持双人角色（IsDoubleChar）的左右分侧轨道分配：
---   - double_char_bone[1]=1 表示char2也有轨道
---   - double_char_bone[2]=1 表示默认位置（右侧）
---   - double_char_bone[3]=1 表示char1（左侧）
function BattleCharacterFactory.MakeSkinOrbit(self, character)
	local skinAttachmentInfo = character:GetUnitData():GetSkinAttachmentInfo()

	if skinAttachmentInfo then
		for _, equipSkinID in ipairs(skinAttachmentInfo) do
			local equipSkinData = ys.Battle.BattleDataFunction.GetEquipSkinDataFromID(equipSkinID)

			if character:IsDoubleChar() then
				-- 双人角色：需要左右两侧分别实例化
				local orbitForCharA = ys.Battle.BattleResourceManager.GetInstance():InstOrbit(equipSkinData.orbit_combat)
				local orbitForCharB = ys.Battle.BattleResourceManager.GetInstance():InstOrbit(equipSkinData.orbit_combat)
				local doubleCharBone = equipSkinData.double_char_bone

				if doubleCharBone and #doubleCharBone > 0 and doubleCharBone[1] == 1 then
					character:AddOrbit(orbitForCharB, equipSkinData, "char2")
				end

				if doubleCharBone and #doubleCharBone > 0 and doubleCharBone[2] == 1 then
					character:AddOrbit(orbitForCharA, equipSkinData)
				end

				if doubleCharBone and #doubleCharBone > 0 and doubleCharBone[3] == 1 then
					character:AddOrbit(orbitForCharA, equipSkinData, "char1")
				end
			else
				-- 单角色：实例化一份即即
				local orbit = ys.Battle.BattleResourceManager.GetInstance():InstOrbit(equipSkinData.orbit_combat)

				character:AddOrbit(orbit, equipSkinData)
			end
		end
	end
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @param reason UnitDeathReason|nil: 死亡原因（KILLED/撤退等）
--- @return nil
--- 移除角色（死亡/撤退时调用）：
---   1) 根据国籍决定爆炸特效：甜甜圈国籍跳过，非KILLED死亡原因跳过
---   2) 播放死亡特效（BOMB_FX_NAME或模板指定的DeadFX）
---   3) Dispose角色，回收挂点
function BattleCharacterFactory.RemoveCharacter(self, character, reason)
	local nationality = character:GetUnitData():GetTemplate().nationality

	-- 甜甜圈国籍（SWEET_DEATH_NATIONALITY 表包含的国籍）不播常规爆炸
	if nationality and table.contains(BattleConfig.SWEET_DEATH_NATIONALITY, nationality) then
		-- 由特殊死亡动画系统处理，跳过爆炸
	elseif reason and reason ~= ys.Battle.BattleConst.UnitDeathReason.KILLED then
		-- 非被击杀（如撤退、切换等），不播爆炸特效
	else
		local deadFXID = character:GetUnitData():GetDeadFX()
		local fxName, fxTarget = self:GetFXPool():GetFX(deadFXID or self.BOMB_FX_NAME)

		pg.EffectMgr.GetInstance():PlayBattleEffect(fxName, fxTarget:Add(character:GetPosition()), true)
	end

	character:Dispose()
	self:GetFXPool():PushCharacterAttachPoint(character:GetAttachPoint())
end

--- @class BattleCharacterFactory
--- @param character BattleCharacter: 角色视觉对象
--- @param skinID number|nil: 皮肤ID。nil时使用角色默认皮肤模型。
--- @return nil
--- 切换角色的Spine动画模型（换肤）。根据皮肤ID获取prefab路径，
--- 异步加载新模型后调用SwitchModel替换。
function BattleCharacterFactory.SwitchCharacterSpine(self, character, skinID)
	local modelID

	if skinID then
		modelID = ys.Battle.BattleDataFunction.GetPlayerShipSkinDataFromID(skinID).prefab
	else
		modelID = character:GetModleID()
	end

	local function applyNewModel(newModel)
		character:SwitchModel(newModel, skinID)
		character:CameraOrthogonal(ys.Battle.BattleCameraUtil.GetInstance():GetCamera())
	end

	self:GetCharacterPool():InstCharacter(modelID, function(newModel)
		applyNewModel(newModel)
	end)
end
