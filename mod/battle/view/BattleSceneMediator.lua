ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable
local BattleTargetChoise = ys.Battle.BattleTargetChoise

--- @class BattleSceneMediator : ys.MVC.Mediator
--- @classdesc 战斗场景中介者——战斗视图层（View）的核心协调器。
--- 负责管理和协调所有战斗可见元素的生命周期：角色、子弹、飞机、区域特效（AOE）、
--- 弧线特效、庇护所（Shelter）、瞄准偏差圈（Aim Bias）、防空圈/反潜圈等。
---
--- 监听事件列表（来自 BattleDataProxy 和 CameraUtil）：
---   STAGE_DATA_INIT_FINISH  → 关卡数据初始化完成，开始注册舰队事件、初始化摄像机
---   ADD_UNIT / REMOVE_UNIT   → 单位创建/销毁对应的场景角色
---   REMOVE_BULLET            → 移除子弹场景对象
---   REMOVE_AIR_CRAFT         → 移除舰载机场景对象
---   ADD_AREA / REMOVE_AREA   → 添加/移除区域特效
---   ADD_EFFECT               → 添加一次性特效
---   ADD_SHELTER / REMOVE_SHELTER → 添加/移除庇护所特效
---   ANTI_AIR_AREA            → 更新防空圈显示
---   UPDATE_HOSTILE_SUBMARINE → 更新反潜圈显示
---   ADD_CAMERA_FX            → 添加相机空间特效（如全屏震动、滤镜）
---   ADD_AIM_BIAS / REMOVE_AIM_BIAS → 添加/移除瞄准偏差圈
---   CAMERA_FOCUS_RESET       → 相机焦点重置
---   BULLET_TIME              → 子弹时间特效
---
--- 核心更新循环：Update() 每帧遍历所有角色、飞机、子弹、区域、弧线特效并调用其 Update
---
--- @field _dataProxy BattleDataProxy 数据层代理
--- @field _characterList table<number, BattleCharacter> 当前所有角色的场景对象（key=UID）
--- @field _bulletList table<number, BattleBullet> 当前所有子弹的场景对象（key=UID）
--- @field _particleBulletList table<BattleBullet, boolean> 含粒子系统的子弹集合（用于暂停/恢复）
--- @field _aircraftList table<number, BattleAircraftCharacter> 当前所有飞机的场景对象
--- @field _areaList table<number, BattleEffectArea> 当前区域特效映射
--- @field _shelterList table<number, GameObject> 当前庇护所特效映射
--- @field _arcEffectList table[] BattleArcEffect列表（弧线/抛射特效）
--- @field _fxPool BattleFXPool 特效池引用
--- @field _leftFleet BattleFleetVO 友方舰队
--- @field _leftFleetMotion BattleFleetMotion 友方舰队运动组件
local BattleSceneMediator = class("BattleSceneMediator", ys.MVC.Mediator)

ys.Battle.BattleSceneMediator = BattleSceneMediator
BattleSceneMediator.__name = "BattleSceneMediator"

-- 旗舰标记的UI偏移量（用于将相机空间坐标转为 UI 空间时微调）
local FlagShipMarkOffset = Vector3(0, 0.8, 0)

function BattleSceneMediator.Ctor(self)
	BattleSceneMediator.super.Ctor(self)

	self.FlagShipUIPos = Vector3.zero
end

--- 初始化：获取 DataProxy，初始化角色工厂，注册事件
function BattleSceneMediator.Initialize(self)
	BattleSceneMediator.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)

	self:InitCharacterFactory()
	self:Init()
	self:AddEvent()
end

--- 重置/初始化所有场景状态
function BattleSceneMediator.Init(self)
	self._characterList = {}
	self._bulletList = {}
	self._particleBulletList = {}
	self._aircraftList = {}
	self._areaList = {}
	self._shelterList = {}
	self._arcEffectList = {}
	self._bulletContainer = GameObject.Find("BulletContainer")
	self._fxPool = ys.Battle.BattleFXPool.GetInstance()
	self._aimBiasTFList = {}

	-- 初始化特效容器池（角色身上挂载FX用的容器组）
	ys.Battle.BattleCharacterFXContainersPool.GetInstance():Init()
	self:InitPlayerAntiAirArea()
	self:InitPlayerAntiSubArea()
	self:InitFlagShipMark()
	self:InitSkillAim()
	pg.CameraFixMgr.GetInstance():Adapt()
end

--- 初始化相机（获取 CameraUtil 并注册相机相关事件）
function BattleSceneMediator.InitCamera(self)
	self._cameraUtil = ys.Battle.BattleCameraUtil.GetInstance()

	self._cameraUtil:RegisterEventListener(self, BattleEvent.CAMERA_FOCUS_RESET, self.onCameraFocusReset)
	self._cameraUtil:RegisterEventListener(self, BattleEvent.BULLET_TIME, self.onBulletTime)
end

--- 初始化弹出数字池（伤害数字/得分数字）
function BattleSceneMediator.InitPopNumPool(self)
	local PopNumMgr = ys.Battle.BattlePopNumManager

	self._popNumMgr = PopNumMgr.GetInstance()

	local ui = self._state:GetUI()

	-- Dodgem（躲避游戏）模式使用 ScorePool，普通战斗使用 BundlePool
	if self._dataProxy:GetInitData().battleType == SYSTEM_DODGEM then
		self._popNumMgr:InitialScorePool(ui._tf:Find(PopNumMgr.CONTAINER_CHARACTER_HP .. "/container"))
	else
		self._popNumMgr:InitialBundlePool(ui._tf:Find(PopNumMgr.CONTAINER_CHARACTER_HP .. "/container"))
	end
end

--- 初始化旗舰标记（UI层显示旗舰位置的箭头/图标）
function BattleSceneMediator.InitFlagShipMark(self)
	local flagShipMarkObj = self._state:GetUI()._tf:Find("flagShipMark").gameObject

	flagShipMarkObj:SetActive(true)

	self._goFlagShipMarkTf = flagShipMarkObj.transform
end

--- 初始化技能瞄准系统（卡牌塔罗/技能手动瞄准的目标过滤器和目标列表）
function BattleSceneMediator.InitSkillAim(self)
	self._cardAimTargetFilter = {}
	self._cardAimTargetList = {}
end

--- 初始化角色工厂映射——根据 UnitType 关联对应的 CharacterFactory
--- 这样 ADD_UNIT 事件到来时可以根据 unitType 找到正确的工厂来创建场景角色
function BattleSceneMediator.InitCharacterFactory(self)
	local ui = self._state:GetUI()

	-- 初始化 HP 条管理器和箭头管理器
	ys.Battle.BattleHPBarManager.GetInstance():InitialPoolRoot(ui._tf:Find(ys.Battle.BattleHPBarManager.ROOT_NAME))
	ys.Battle.BattleArrowManager.GetInstance():Init(ui._tf:Find(ys.Battle.BattleArrowManager.ROOT_NAME))

	-- 工厂映射表：UnitType → CharacterFactory 单例
	self._characterFactoryList = {
		[BattleConst.UnitType.PLAYER_UNIT] = ys.Battle.BattlePlayerCharacterFactory.GetInstance(),
		[BattleConst.UnitType.ENEMY_UNIT] = ys.Battle.BattleEnemyCharacterFactory.GetInstance(),
		[BattleConst.UnitType.MINION_UNIT] = ys.Battle.BattleMinionCharacterFactory.GetInstance(),
		[BattleConst.UnitType.BOSS_UNIT] = ys.Battle.BattleBossCharacterFactory.GetInstance(),
		[BattleConst.UnitType.AIRCRAFT_UNIT] = ys.Battle.BattleAircraftCharacterFactory.GetInstance(),
		[BattleConst.UnitType.AIRFIGHTER_UNIT] = ys.Battle.BattleAirFighterCharacterFactory.GetInstance(),
		[BattleConst.UnitType.SUB_UNIT] = ys.Battle.BattleSubCharacterFactory.GetInstance(),
		[BattleConst.UnitType.SUPPORT_UNIT] = ys.Battle.BattleSupportCharacterFactory.GetInstance(),
	}
end

--- 初始化友方防空圈特效（蓝色圆圈，默认隐藏）
function BattleSceneMediator.InitPlayerAntiAirArea(self)
	self._antiAirArea = self._fxPool:GetFX("AntiAirArea")
	self._antiAirAreaTF = self._antiAirArea.transform

	self._antiAirArea:SetActive(false)
end

--- 初始化友方反潜圈特效（默认隐藏）
function BattleSceneMediator.InitPlayerAntiSubArea(self)
	self._anitSubArea = self._fxPool:GetFX("AntiSubArea")
	self._anitSubAreaTF = self._anitSubArea.transform

	self._anitSubArea:SetActive(false)

	-- 反潜扫描动画组件
	self._antiSubScanAnima = self._anitSubAreaTF:Find("Quad"):GetComponent(typeof(Animator))
	self._anitSubAreaTFList = {}
	self._anitSubAreaTFList[self._anitSubAreaTF] = true
end

--- 初始化详细反潜圈分层显示（Debug/开发用）
--- 用不同颜色显示反潜圈的各层：基础直径/主力提供/装备提供/技能额外直径
function BattleSceneMediator.InitDetailAntiSubArea(self)
	local baseRange, mainRange, equipRange, skillRange = self._leftFleet:GetFleetSonar():GetTotalRangeDetail()

	--- 创建一个反潜圈显示层
	--- @param range number 该层的直径
	--- @param color Color 该层的颜色
	--- @param label string 该层的说明文本
	local function createSubLayer(range, color, label)
		local subArea = self._fxPool:GetFX("AntiSubArea")
		subArea.name = label

		local subTf = subArea.transform
		subTf.localScale = Vector3(range, 0, range)
		subTf:Find("static"):GetComponent("SpriteRenderer").color = color

		subArea:SetActive(true)

		self._anitSubAreaTFList[subTf] = true
	end

	-- 从最外层到最内层依次创建（白色=技能、绿色=装备、橙色=主力、红色=基础）
	createSubLayer(baseRange + mainRange + equipRange + skillRange, Color.New(1, 1, 1, 1), "技能额外直径：" .. skillRange)
	createSubLayer(baseRange + mainRange + equipRange, Color.New(0.07, 1, 0, 1), "装备提供直径：" .. equipRange)
	createSubLayer(baseRange + mainRange, Color.New(1, 0.32, 0, 1), "主力提供直径：" .. mainRange)
	createSubLayer(baseRange, Color.New(1, 0, 0, 1), "基础直径：" .. baseRange)
end

--- 注册所有数据层事件监听 + 相机宽高比更新事件
function BattleSceneMediator.AddEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH, self.onStageInitFinish)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_BULLET, self.onRemoveBullet)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_AIR_CRAFT, self.onRemoveAircraft)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_AIR_FIGHTER, self.onRemoveAirFighter)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_AREA, self.onAddArea)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_AREA, self.onRemoveArea)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_EFFECT, self.onAddEffect)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_SHELTER, self.onAddShelter)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_SHELTER, self.onRemoveShleter)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ANTI_AIR_AREA, self.onAntiAirArea)
	self._dataProxy:RegisterEventListener(self, BattleEvent.UPDATE_HOSTILE_SUBMARINE, self.onUpdateHostileSubmarine)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_CAMERA_FX, self.onAddCameraFX)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_AIM_BIAS, self.onAddAimBias)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_AIM_BIAS, self.onRemoveAimBias)

	-- 绑定相机宽高比更新事件（屏幕旋转/分屏时需要重新计算边界）
	self._camEventId = pg.CameraFixMgr.GetInstance():bind(pg.CameraFixMgr.ASPECT_RATIO_UPDATE, function()
		self._dataProxy:OnCameraRatioUpdate()
	end)
end

--- 注销所有事件监听
function BattleSceneMediator.RemoveEvent(self)
	self._leftFleet:UnregisterEventListener(self, BattleEvent.SONAR_SCAN)
	self._leftFleet:UnregisterEventListener(self, BattleEvent.SONAR_UPDATE)
	self._leftFleet:UnregisterEventListener(self, BattleEvent.ADD_AIM_BIAS)
	self._leftFleet:UnregisterEventListener(self, BattleEvent.REMOVE_AIM_BIAS)
	self._leftFleet:UnregisterEventListener(self, BattleCardPuzzleEvent.FLEET_MOVE_TO)
	self._leftFleet:UnregisterEventListener(self, BattleCardPuzzleEvent.UPDATE_CARD_TARGET_FILTER)
	self._leftFleet:UnregisterEventListener(self, BattleEvent.ON_BOARD_CLICK)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_BULLET)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_AIR_CRAFT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_AIR_FIGHTER)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_AREA)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_AREA)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_EFFECT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_SHELTER)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_SHELTER)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ANTI_AIR_AREA)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.UPDATE_HOSTILE_SUBMARINE)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_CAMERA_FX)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_AIM_BIAS)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_AIM_BIAS)
	self._cameraUtil:UnregisterEventListener(self, BattleEvent.CAMERA_FOCUS_RESET)
	self._cameraUtil:UnregisterEventListener(self, BattleEvent.BULLET_TIME)
	pg.CameraFixMgr.GetInstance():disconnect(self._camEventId)
end

-- ============================================================
-- 事件处理函数
-- ============================================================

--- 关卡数据初始化完成：获取友方舰队，注册舰队级事件，初始化相机和弹出数字池
function BattleSceneMediator.onStageInitFinish(self, event)
	self._leftFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
	self._leftFleetMotion = self._leftFleet:GetMotion()

	self:InitCamera()

	-- 注册舰队事件：声纳扫描、声纳更新、瞄准偏差、卡牌移动、点击等
	self._leftFleet:RegisterEventListener(self, BattleEvent.SONAR_SCAN, self.onSonarScan)
	self._leftFleet:RegisterEventListener(self, BattleEvent.SONAR_UPDATE, self.onUpdateHostileSubmarine)
	self._leftFleet:RegisterEventListener(self, BattleEvent.ADD_AIM_BIAS, self.onAddAimBias)
	self._leftFleet:RegisterEventListener(self, BattleEvent.REMOVE_AIM_BIAS, self.onRemoveAimBias)
	self._leftFleet:RegisterEventListener(self, BattleCardPuzzleEvent.FLEET_MOVE_TO, self.onUpdateMoveMark)
	self._leftFleet:RegisterEventListener(self, BattleCardPuzzleEvent.ON_BOARD_CLICK, self.onBoardClick)
	self._leftFleet:RegisterEventListener(self, BattleCardPuzzleEvent.UPDATE_CARD_TARGET_FILTER, self.onUpdateSkillAim)

	self:InitPopNumPool()
end

--- 单位添加：根据 unitType 找到对应的工厂，创建场景角色
function BattleSceneMediator.onAddUnit(self, event)
	local unitType = event.Data.type
	local factory = self._characterFactoryList[unitType]
	local eventData = event.Data

	factory:CreateCharacter(eventData)
end

--- 单位移除：通过工厂移除场景角色
function BattleSceneMediator.onRemoveUnit(self, event)
	local unitUID = event.Data.UID
	local deadReason = event.Data.deadReason
	local character = self._characterList[unitUID]

	if character then
		character:GetFactory():RemoveCharacter(character, deadReason)
		self._characterList[unitUID] = nil
	end
end

--- 舰载机移除
function BattleSceneMediator.onRemoveAircraft(self, event)
	local aircraftUID = event.Data.UID
	local aircraftCharacter = self._aircraftList[aircraftUID]

	if aircraftCharacter then
		aircraftCharacter:GetFactory():RemoveCharacter(aircraftCharacter)
		self._aircraftList[aircraftUID] = nil
	end
end

--- 敌方飞机（AirFighter）移除
function BattleSceneMediator.onRemoveAirFighter(self, event)
	local fighterUID = event.Data.UID
	local fighterCharacter = self._aircraftList[fighterUID]

	if fighterCharacter then
		fighterCharacter:GetFactory():RemoveCharacter(fighterCharacter)
		self._aircraftList[fighterUID] = nil
	end
end

--- 子弹移除
function BattleSceneMediator.onRemoveBullet(self, event)
	local bulletUID = event.Data.UID

	self:RemoveBullet(bulletUID)
end

--- 区域特效（AOE）添加
function BattleSceneMediator.onAddArea(self, event)
	local fxID = event.Data.FXID
	local area = event.Data.area

	self:AddArea(area, fxID)
end

--- 区域特效移除
function BattleSceneMediator.onRemoveArea(self, event)
	local areaID = event.Data.id

	self:RemoveArea(areaID)
end

--- 一次性特效添加
function BattleSceneMediator.onAddEffect(self, event)
	local fxID = event.Data.FXID
	local position = event.Data.position
	local scale = event.Data.localScale

	self:AddEffect(fxID, position, scale)
end

--- 庇护所（Shelter）特效添加
--- 庇护所是场景中的防护性特效（如技能产生的护盾墙视觉效果）
function BattleSceneMediator.onAddShelter(self, event)
	local shelter = event.Data.shelter
	local shelterGO, offset = self._fxPool:GetFX(shelter:GetFXID())
	local shelterPos = shelter:GetPosition()

	pg.EffectMgr.GetInstance():PlayBattleEffect(shelterGO, shelterPos:Add(offset), true)

	-- 敌方庇护所需要Y轴翻转180度（因为敌方朝向与友方相反）
	if shelter:GetIFF() == BattleConfig.FOE_CODE then
		local shelterTf = shelterGO.transform
		local euler = shelterTf.localEulerAngles
		euler.y = 180
		shelterTf.localEulerAngles = euler
	end

	self._shelterList[shelter:GetUniqueID()] = shelterGO
end

--- 庇护所特效移除
function BattleSceneMediator.onRemoveShleter(self, event)
	local shelterUID = event.Data.uid
	local shelterGO = self._shelterList[shelterUID]

	if shelterGO then
		ys.Battle.BattleResourceManager.GetInstance():DestroyOb(shelterGO)
		self._shelterList[shelterUID] = nil
	end
end

--- 更新防空圈显示——根据是否有敌方飞机来切换防空圈可见性和尺寸
function BattleSceneMediator.onAntiAirArea(self, event)
	local isShow = event.Data.isShow

	if isShow ~= nil then
		self._antiAirArea.gameObject:SetActive(event.Data.isShow)

		if isShow == true then
			-- 防空圈直径 = 舰队防空武器射程 * 2
			local range = self._leftFleet:GetFleetAntiAirWeapon():GetRange() * 2

			self._antiAirAreaTF.localScale = Vector3(range, 0, range)
		end
	end
end

--- 防空过载动画控制——过载时禁用防空圈的呼吸动画
function BattleSceneMediator.onAntiAirOverload(self, event)
	local antiAirWeapon = event.Dispatcher
	local animator = self._antiAirAreaTF:Find("Quad"):GetComponent(typeof(Animator))

	if antiAirWeapon:IsOverLoad() then
		animator.enabled = false
	else
		animator.enabled = true
	end
end

--- 敌方潜艇数量变化时更新声纳视图
function BattleSceneMediator.onUpdateHostileSubmarine(self, event)
	self:updateSonarView()
end

--- 更新声纳/反潜圈视图
function BattleSceneMediator.updateSonarView(self)
	local hasEnemySub = self._dataProxy:GetEnemySubmarineCount() > 0

	self._sonarActive = hasEnemySub

	-- 通知所有角色声纳状态变化（敌方角色头上的声纳标记）
	for _, character in pairs(self._characterList) do
		character:SonarAcitve(hasEnemySub)
	end

	-- 友方反潜圈：仅当声纳系统启用且存在敌方潜艇时才显示
	local sonarEnabled = self._leftFleet:GetFleetSonar():GetCurrentState() ~= ys.Battle.BattleFleetStaticSonar.STATE_DISABLE and hasEnemySub

	self._anitSubArea.gameObject:SetActive(sonarEnabled)

	if sonarEnabled then
		local sonarRange = self._leftFleet:GetFleetSonar():GetRange()

		self._anitSubAreaTF.localScale = Vector3(sonarRange, 0, sonarRange)
	end
end

--- 声纳扫描动画播放
function BattleSceneMediator.onSonarScan(self, event)
	if event.Data.indieSonar then
		-- 独立声纳（单体反潜扫描）——创建一个新的扫描圈并播放动画
		local scanAreaTf = self._fxPool:GetFX("AntiSubArea").transform

		scanAreaTf.localScale = Vector3(100, 0, 100)

		SetActive(scanAreaTf:Find("static"), false)

		local quadTf = scanAreaTf:Find("Quad")
		local animator = quadTf:GetComponent(typeof(Animator))

		animator.enabled = true
		animator:Play("antiSubZoom", -1, 0)

		self._anitSubAreaTFList[scanAreaTf] = true

		-- 动画结束后从列表中移除
		quadTf:GetComponent("DftAniEvent"):SetEndEvent(function()
			self._anitSubAreaTFList[scanAreaTf] = nil
		end)
	elseif self._antiSubScanAnima and self._sonarActive then
		-- 舰队反潜扫描——使用已有的扫描动画组件
		self._antiSubScanAnima.enabled = true
		self._antiSubScanAnima:Play("antiSubZoom", -1, 0)
	end
end

--- 瞄准偏差圈（Aim Bias）添加——创建"瞄准偏差区域"特效的Transform并记录
function BattleSceneMediator.onAddAimBias(self, event)
	local aimBias = event.Data.aimBias
	local aimBiasTf = self._fxPool:GetFX("AimBiasArea").transform

	self._aimBiasTFList[aimBias] = {
		tf = aimBiasTf,
		vector = Vector3(5, 0, 5),
	}
end

--- 瞄准偏差圈移除——销毁对应的特效GameObject
function BattleSceneMediator.onRemoveAimBias(self, event)
	local aimBias = event.Data.aimBias
	local aimBiasData = self._aimBiasTFList[aimBias]

	if aimBiasData then
		local gobj = aimBiasData.tf.gameObject

		ys.Battle.BattleResourceManager.GetInstance():DestroyOb(gobj)
		self._aimBiasTFList[aimBias] = nil
	end
end

--- 卡牌塔罗模式：更新舰队移动标记位置
function BattleSceneMediator.onUpdateMoveMark(self, event)
	local targetPos = event.Data.pos

	-- 延迟创建移动标记FX（首次使用才从池中获取）
	if not self._moveMarkFXTF then
		self._moveMarkFX = self._fxPool:GetFX("kapai_weizhi")
		self._moveMarkFXTF = self._moveMarkFX.transform
	end

	if targetPos then
		setActive(self._moveMarkFXTF, true)
		self._moveMarkFXTF.position = targetPos
	else
		setActive(self._moveMarkFXTF, false)
	end
end

--- 卡牌塔罗模式：处理棋盘点击（click/drag/release）
function BattleSceneMediator.onBoardClick(self, event)
	local clickState = event.Data.click
	local touchPoint = self._leftFleet:GetCardPuzzleComponent():GetTouchScreenPoint()

	if clickState == ys.Battle.CardPuzzleBoardClicker.CLICK_STATE_CLICK then
		self._clickMarkFxTF = self._fxPool:GetFX("kapai_weizhi").transform
		self._clickMarkFxTF.position = touchPoint
	elseif clickState == ys.Battle.CardPuzzleBoardClicker.CLICK_STATE_DRAG then
		self._clickMarkFxTF.position = touchPoint
	elseif clickState == ys.Battle.CardPuzzleBoardClicker.CLICK_STATE_RELEASE and self._clickMarkFxTF then
		ys.Battle.BattleResourceManager.GetInstance():DestroyOb(self._clickMarkFxTF.gameObject)
	end
end

--- 相机焦点重置
function BattleSceneMediator.onCameraFocusReset(self, event)
	self:ResetFocus()
end

--- 相机空间特效添加（如从相机空间播放的全屏特效）
function BattleSceneMediator.onAddCameraFX(self, event)
	local fxID = event.Data.FXID
	local position = event.Data.position
	local localScale = event.Data.localScale
	local orderDiff = event.Data.orderDiff

	self:AddCameraFX(orderDiff, fxID, position, localScale)
end

--- 向相机空间添加特效（orderDiff控制层级，缩放需根据相机缩放系数调整）
--- @param orderDiff number 相机层级偏移
--- @param fxID string 特效ID
--- @param position Vector3 世界坐标位置
--- @param scale number|nil 缩放比例（默认1）
function BattleSceneMediator.AddCameraFX(self, orderDiff, fxID, position, scale)
	local fxGO = self._fxPool:GetFX(fxID)
	local cameraScale = self._cameraUtil:Add2Camera(fxGO, orderDiff)

	scale = scale or 1
	fxGO.transform.localScale = Vector3(scale / cameraScale.x, scale / cameraScale.y, scale / cameraScale.z)

	pg.EffectMgr.GetInstance():PlayBattleEffect(fxGO, position, true)
end

--- 技能瞄准目标过滤器更新（卡牌模式）
function BattleSceneMediator.onUpdateSkillAim(self, event)
	self._cardAimTargetFilter = event.Data.targetFilterList
end

-- ============================================================
-- 核心更新循环
-- ============================================================

--- 每帧更新：遍历所有角色、飞机、子弹、区域、弧线特效并更新其状态
function BattleSceneMediator.Update(self)
	for _, character in pairs(self._characterList) do
		character:Update()
	end

	for _, aircraftChar in pairs(self._aircraftList) do
		aircraftChar:Update()
	end

	for _, bullet in pairs(self._bulletList) do
		bullet:Update()
	end

	for _, area in pairs(self._areaList) do
		area:Update()
	end

	for _, arcEffect in ipairs(self._arcEffectList) do
		arcEffect:Update()
	end

	self:updateCardAim()
	self:UpdateAntiAirArea()
	self:UpdateAimBiasArea()
	self:UpdateFlagShipMark()
end

--- 暂停时的更新：仅更新UI组件位置和HP条位置（不更新动画/逻辑）
function BattleSceneMediator.UpdatePause(self)
	for _, character in pairs(self._characterList) do
		character:UpdateUIComponentPosition()
		character:UpdateHPBarPosition()
	end

	for _, aircraftChar in pairs(self._aircraftList) do
		aircraftChar:UpdateUIComponentPosition()

		if aircraftChar:GetUnitData():GetUniqueID() == BattleConfig.FOE_CODE then
			aircraftChar:UpdateHPBarPosition()
		end
	end

	self:UpdateFlagShipMark()
end

--- 仅更新逃跑中的敌方角色（战斗结束倒计时阶段）
function BattleSceneMediator.UpdateEscapeOnly(self, timeStamp)
	for _, character in pairs(self._characterList) do
		if character.__name == ys.Battle.BattleEnemyCharacter.__name or character.__name == ys.Battle.BattleBossCharacter.__name then
			character:Update(timeStamp)
		end
	end
end

--- 暂停所有场景效果（角色动画 + 粒子系统 + 相机震动）
function BattleSceneMediator.Pause(self)
	self:PauseCharacterAction(true)

	-- 暂停区域特效中的粒子系统
	for _, area in pairs(self._areaList) do
		local particles = area._go:GetComponentsInChildren(typeof(ParticleSystem)):ToTable()

		for _, ps in ipairs(particles) do
			ps:Pause()
		end
	end

	self._cameraUtil:PauseShake()

	-- 暂停弧线特效中的粒子系统
	for _, arcEffect in ipairs(self._arcEffectList) do
		local particles = arcEffect._go:GetComponentsInChildren(typeof(ParticleSystem)):ToTable()

		for _, ps in ipairs(particles) do
			ps:Pause()
		end
	end

	-- 暂停粒子子弹中的粒子系统
	for _, particleBullet in pairs(self._particleBulletList) do
		local particles = particleBullet._go:GetComponentsInChildren(typeof(ParticleSystem)):ToTable()

		for _, ps in ipairs(particles) do
			ps:Pause()
		end
	end
end

--- 恢复所有场景效果
function BattleSceneMediator.Resume(self)
	self:PauseCharacterAction(false)

	for _, area in pairs(self._areaList) do
		local particles = area._go:GetComponentsInChildren(typeof(ParticleSystem)):ToTable()

		for _, ps in ipairs(particles) do
			ps:Pause()
		end
	end

	self._cameraUtil:ResumeShake()

	for _, arcEffect in ipairs(self._arcEffectList) do
		local particles = arcEffect._go:GetComponentsInChildren(typeof(ParticleSystem)):ToTable()

		for _, ps in ipairs(particles) do
			ps:Pause()
		end
	end

	for _, particleBullet in pairs(self._particleBulletList) do
		local particles = particleBullet._go:GetComponentsInChildren(typeof(ParticleSystem)):ToTable()

		for _, ps in ipairs(particles) do
			ps:Pause()
		end
	end
end

--- 子弹时间（慢动作）处理
--- 对两方（除豁免单位外）施加时间缩放因子，豁免单位动画速度为 1/speed 补偿
function BattleSceneMediator.onBulletTime(self, event)
	local bulletTimeData = event.Data
	local speedKey = bulletTimeData.key
	local speedValue = bulletTimeData.speed

	if speedValue then
		-- 进入子弹时间
		local exemptUID = bulletTimeData.exemptUnit:GetUniqueID()

		BattleVariable.AppendIFFFactor(BattleConfig.FOE_CODE, speedKey, speedValue)
		BattleVariable.AppendIFFFactor(BattleConfig.FRIENDLY_CODE, speedKey, speedValue)

		-- 豁免单位保持正常速度（补偿时间缩放）
		for uid, character in pairs(self._characterList) do
			if uid == exemptUID then
				character:SetAnimaSpeed(1 / speedValue)
				break
			end
		end
	else
		-- 退出子弹时间：移除速度因子，恢复所有动画速度
		BattleVariable.RemoveIFFFactor(BattleConfig.FOE_CODE, speedKey)
		BattleVariable.RemoveIFFFactor(BattleConfig.FRIENDLY_CODE, speedKey)

		for _, character in pairs(self._characterList) do
			character:SetAnimaSpeed(1)
		end

		for _, bullet in pairs(self._bulletList) do
			bullet:SetAnimaSpeed(1)
		end
	end
end

--- 重置相机焦点：移除聚焦速度因子，恢复所有动画速度为1，平滑缩放回默认
function BattleSceneMediator.ResetFocus(self)
	BattleVariable.RemoveIFFFactor(BattleConfig.FOE_CODE, BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER)
	BattleVariable.RemoveIFFFactor(BattleConfig.FRIENDLY_CODE, BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER)

	for _, character in pairs(self._characterList) do
		character:SetAnimaSpeed(1)
	end

	for _, bullet in pairs(self._bulletList) do
		bullet:SetAnimaSpeed(1)
	end

	self._cameraUtil:ZoomCamara(nil, nil, BattleConfig.CAM_RESET_DURATION)
end

-- ============================================================
-- UI 位置更新
-- ============================================================

--- 更新旗舰标记的UI位置（跟随友方舰队移动）
function BattleSceneMediator.UpdateFlagShipMark(self)
	local fleetUIPos = self.FlagShipUIPos:Copy(self._leftFleetMotion:GetPos())

	self._goFlagShipMarkTf.position = BattleVariable.CameraPosToUICamera(fleetUIPos):Add(FlagShipMarkOffset)
end

--- 更新防空圈和反潜圈位置（跟随友方舰队移动）
function BattleSceneMediator.UpdateAntiAirArea(self)
	self._antiAirAreaTF.position = self._leftFleetMotion:GetPos()

	for subAreaTf, _ in pairs(self._anitSubAreaTFList) do
		subAreaTf.position = self._leftFleetMotion:GetPos()
	end
end

--- 更新瞄准偏差圈——根据瞄准偏差对象的位置和范围调整特效Transform
function BattleSceneMediator.UpdateAimBiasArea(self)
	for aimBias, aimBiasData in pairs(self._aimBiasTFList) do
		local aimBiasTf = aimBiasData.tf
		local scaleVector = aimBiasData.vector
		local cachedState = aimBiasData.cacheState
		local range = aimBias:GetRange() * 2

		scaleVector:Set(range, 0, range)

		aimBiasTf.position = aimBias:GetPosition()
		aimBiasTf.localScale = scaleVector

		local currentState = aimBias:GetCurrentState()

		-- 当状态从 SKILL_EXPOSE 切换到其他时，显示"缩放"特效
		if currentState ~= cachedState then
			setActive(aimBiasTf:Find("suofang/Quad"), currentState ~= aimBias.STATE_SKILL_EXPOSE)
		end

		aimBiasData.cacheState = currentState
	end
end

--- 更新卡牌塔罗模式下的技能瞄准标记
function BattleSceneMediator.updateCardAim(self)
	local targetUIDSet = {}

	-- 根据目标过滤器计算当前应瞄准的单位UID集合
	for fleetPos, filterList in pairs(self._cardAimTargetFilter) do
		local fleetUnits = BattleTargetChoise.TargetFleetIndex(nil, {
			fleetPos = fleetPos,
		})[1]

		for _, targetList in ipairs(fleetUnits) do
			local unitGroup

			for _, filterFuncName in ipairs(targetList) do
				unitGroup = BattleTargetChoise[filterFuncName](fleetUnits, nil, unitGroup)
			end

			for _, unit in ipairs(unitGroup) do
				targetUIDSet[unit:GetUniqueID()] = true
			end
		end
	end

	-- 移除不再需要的瞄准标记
	for uid, markGO in pairs(self._cardAimTargetList) do
		if not targetUIDSet[uid] then
			Object.Destroy(go(markGO))
			self._cardAimTargetList[uid] = nil
		end
	end

	-- 为新目标创建瞄准标记（或更新已有标记的位置）
	for uid, _ in pairs(targetUIDSet) do
		local markTf = self._cardAimTargetList[uid] or self:InstantiateCharacterComponent("SkillAimContainer/SkillAim").transform

		self._cardAimTargetList[uid] = markTf

		local character = self._characterList[uid]

		if character then
			markTf.position = character:GetReferenceVector(character.AIM_OFFSET)
		end
	end
end

-- ============================================================
-- 子弹管理
-- ============================================================

--- 添加子弹场景对象并处理粒子特效注册、时间缩放
--- @param bulletView BattleBullet 子弹场景对象（由 BattleBulletFactory 创建）
function BattleSceneMediator.AddBullet(self, bulletView)
	local bulletData = bulletView:GetBulletData()

	self._bulletList[bulletData:GetUniqueID()] = bulletView

	-- 如果子弹有粒子系统组件，记录到粒子子弹列表（用于暂停/恢复）
	local bulletGO = bulletView:GetGO()

	if bulletGO and bulletGO:GetComponent(typeof(ParticleSystem)) then
		self._particleBulletList[bulletView] = true
	end

	-- 如果该子弹的速度豁免键在焦点豁免列表中，应用时间缩放
	if BattleVariable.focusExemptList[bulletData:GetSpeedExemptKey()] then
		local timeScale = self._state:GetTimeScaleRate()

		bulletView:SetAnimaSpeed(1 / timeScale)
	end
end

--- 移除子弹场景对象——从粒子列表移除，调用工厂的 RemoveBullet 回收子弹GO
--- @param bulletUID number 子弹的UUniqueID
function BattleSceneMediator.RemoveBullet(self, bulletUID)
	local bulletView = self._bulletList[bulletUID]

	if bulletView then
		self._particleBulletList[bulletView] = nil

		bulletView:GetFactory():RemoveBullet(bulletView)
	end

	self._bulletList[bulletUID] = nil
end

--- 获取子弹根容器Transform（所有子弹实例的父节点）
function BattleSceneMediator.GetBulletRoot(self)
	return self._bulletContainer
end

--- 启用/禁用弹出容器（伤害数字/得分数字的UI容器）
function BattleSceneMediator.EnablePopContainer(self, containerPath, isActive)
	setActive(self._state:GetUI()._tf:Find(containerPath), isActive)
end

-- ============================================================
-- 角色管理
-- ============================================================

--- 添加玩家角色（额外处理HP条可见性逻辑：主力单位默认隐藏HP条）
function BattleSceneMediator.AddPlayerCharacter(self, character)
	self:AppendCharacter(character)

	local battleType = self._dataProxy:GetInitData().battleType
	local isMainFleet = character:GetUnitData():IsMainFleetUnit()

	if battleType == SYSTEM_DUEL then
		-- 演习模式：不做额外处理
		-- block empty
	elseif battleType == SYSTEM_SUBMARINE_RUN or battleType == SYSTEM_SUB_ROUTINE then
		-- 潜艇模式：始终显示HP条
		character:SetBarHidden(false, false)
	else
		-- 普通模式：主力单位隐藏HP条（因为它们通常在屏幕外），先锋单位显示HP条
		character:SetBarHidden(not isMainFleet, isMainFleet)
	end
end

--- 添加敌方角色（仅添加到角色列表，不修改HP条可见性）
function BattleSceneMediator.AddEnemyCharacter(self, character)
	self:AppendCharacter(character)
end

--- 将角色追加到 _characterList
function BattleSceneMediator.AppendCharacter(self, character)
	local unitData = character:GetUnitData()

	self._characterList[unitData:GetUniqueID()] = character
end

--- 实例化角色UI组件（从UI模板克隆）
--- @param componentPath string UI组件路径（相对于UI根Transform）
--- @return GameObject
function BattleSceneMediator.InstantiateCharacterComponent(self, componentPath)
	local template = self._state:GetUI()._tf:Find(componentPath)

	return cloneTplTo(template, template.parent).gameObject
end

--- 获取所有角色列表
function BattleSceneMediator.GetCharacterList(self)
	return self._characterList
end

--- 获取弹出数字管理器
function BattleSceneMediator.GetPopNumPool(self)
	return self._popNumMgr
end

--- 暂停/恢复所有角色的动作动画
function BattleSceneMediator.PauseCharacterAction(self, paused)
	for _, character in pairs(self._characterList) do
		character:PauseActionAnimation(paused)
	end
end

--- 获取指定UID的角色
function BattleSceneMediator.GetCharacter(self, uid)
	return self._characterList[uid]
end

--- 获取指定UID的飞机场景对象
function BattleSceneMediator.GetAircraft(self, uid)
	return self._aircraftList[uid]
end

--- 添加飞机场景对象到飞机列表
function BattleSceneMediator.AddAirCraftCharacter(self, aircraftCharacter)
	local unitData = aircraftCharacter:GetUnitData()

	self._aircraftList[unitData:GetUniqueID()] = aircraftCharacter
end

-- ============================================================
-- 区域特效管理
-- ============================================================

--- 添加区域特效（如照明弹、烟雾弹等持续性区域AOE）
--- @param area table 数据层的AOE对象
--- @param fxID string 特效ID
function BattleSceneMediator.AddArea(self, area, fxID)
	local fxGO = self._fxPool:GetFX(fxID)
	local offsetConfig = pg.effect_offset[fxID]
	local isTopCover = false

	-- 检查是否需要顶盖偏移（top_cover_offset = true 时使用不同的渲染顺序）
	if offsetConfig and offsetConfig.top_cover_offset == true then
		isTopCover = true
	end

	local effectArea = ys.Battle.BattleEffectArea.New(fxGO, area, isTopCover)

	self._areaList[area:GetUniqueID()] = effectArea
end

--- 移除区域特效
function BattleSceneMediator.RemoveArea(self, areaUID)
	if self._areaList[areaUID] then
		self._areaList[areaUID]:Dispose()
		self._areaList[areaUID] = nil
	end
end

--- 添加一次性特效（如命中火花、爆炸闪光）——立即播放，不跟踪生命周期
--- @param fxID string 特效ID
--- @param position Vector3 世界坐标
--- @param scale number 缩放（默认1）
function BattleSceneMediator.AddEffect(self, fxID, position, scale)
	local fxGO = self._fxPool:GetFX(fxID)

	scale = scale or 1
	fxGO.transform.localScale = Vector3(scale, 1, scale)

	pg.EffectMgr.GetInstance():PlayBattleEffect(fxGO, position, true)
end

--- 添加弧线特效（如鱼雷轨迹、子弹飞行弧线）
--- @param fxID string 特效ID
--- @param startPos Vector3 起点
--- @param endPos Vector3 终点
--- @param duration number 持续时间
function BattleSceneMediator.AddArcEffect(self, fxID, startPos, endPos, duration)
	local fxGO = self._fxPool:GetFX(fxID)
	local arcEffect = ys.Battle.BattleArcEffect.New(fxGO, startPos, endPos, duration)

	-- 结束后自动从列表中移除
	local function onArcEnd()
		self:RemoveArcEffect(arcEffect)
	end

	arcEffect:ConfigCallback(onArcEnd)
	table.insert(self._arcEffectList, arcEffect)
end

--- 移除弧线特效
function BattleSceneMediator.RemoveArcEffect(self, arcEffect)
	for index, existingArc in ipairs(self._arcEffectList) do
		if existingArc == arcEffect then
			existingArc:Dispose()
			table.remove(self._arcEffectList, index)
			break
		end
	end
end

-- ============================================================
-- 全局操作
-- ============================================================

--- 重新初始化场景（先Clear再Init）
function BattleSceneMediator.Reinitialize(self)
	self:Clear()
	self:Init()
end

--- 中和所有子弹（战斗结束时调用，强制清理所有飞行中的子弹）
function BattleSceneMediator.AllBulletNeutralize(self)
	-- 禁用玩家/潜艇角色的武器追踪
	for _, character in pairs(self._characterList) do
		if character.__name == ys.Battle.BattlePlayerCharacter.__name or character.__name == ys.Battle.BattleSubCharacter.__name then
			character:DisableWeaponTrack()
		end
	end

	-- 关闭防空圈
	self._antiAirArea:SetActive(false)

	local bulletCount = 0

	-- 逐个中和所有子弹
	for _, bullet in pairs(self._bulletList) do
		bulletCount = bulletCount + 1

		bullet:Neutrailze()
	end

	-- 通过工厂清理剩余的子弹模板
	ys.Battle.BattleBulletFactory.NeutralizeBullet()
end

--- 清理所有场景元素（角色、飞机、子弹、区域、弧线特效、瞄准标记等）
function BattleSceneMediator.Clear(self)
	for _, character in pairs(self._characterList) do
		character:GetFactory():RemoveCharacter(character)
	end

	for _, aircraftChar in pairs(self._aircraftList) do
		aircraftChar:GetFactory():RemoveCharacter(aircraftChar)
	end

	self._characterList = nil
	self._characterFactoryList = nil

	for bulletUID, _ in pairs(self._bulletList) do
		self:RemoveBullet(bulletUID)
	end

	-- 清理所有子弹工厂
	local factoryList = ys.Battle.BattleBulletFactory.GetFactoryList()

	for _, factory in pairs(factoryList) do
		factory:Clear()
	end

	self._fxPool:Clear()

	for areaUID, _ in pairs(self._areaList) do
		self:RemoveArea(areaUID)
	end

	self._areaList = nil

	for _, arcEffect in ipairs(self._arcEffectList) do
		arcEffect:Dispose()
	end

	self._arcEffectList = nil

	for _, markGO in pairs(self._cardAimTargetList) do
		Object.Destroy(go(markGO))
	end

	self._cardAimTargetList = nil

	ys.Battle.BattleCharacterFXContainersPool.GetInstance():Clear()
	self._popNumMgr:Clear()
	ys.Battle.BattleHPBarManager.GetInstance():Clear()
	ys.Battle.BattleArrowManager.GetInstance():Clear()

	self._anitSubAreaTFList = nil
end

--- 销毁中介者（清理场景 + 注销事件 + 调用父类Dispose）
function BattleSceneMediator.Dispose(self)
	self:Clear()
	self:RemoveEvent()
	BattleSceneMediator.super.Dispose(self)
end
