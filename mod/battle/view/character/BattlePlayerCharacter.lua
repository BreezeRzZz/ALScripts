ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleConst = ys.Battle.BattleConst
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent
local BattlePlayerCharacter = class("BattlePlayerCharacter", ys.Battle.BattleCharacter)

ys.Battle.BattlePlayerCharacter = BattlePlayerCharacter
BattlePlayerCharacter.__name = "BattlePlayerCharacter"

--- 构造函数：调用父类初始化
function BattlePlayerCharacter.Ctor(self)
	BattlePlayerCharacter.super.Ctor(self)
end

--- 设置UnitData并初始化玩家特有武器系统
--- - 蓄力武器列表（chargeWeapon）
--- - 鱼雷武器列表（torpedo）
--- - 空袭辅助列表（airAssist）
--- - 武器扇区列表
--- @param unitData BattlePlayerUnitData 玩家单位数据
function BattlePlayerCharacter.SetUnitData(self, unitData)
	BattlePlayerCharacter.super.SetUnitData(self, unitData)

	self._chargeWeaponList = {}

	for _, chargeWeapon in ipairs(unitData:GetChargeList()) do
		self:InitChargeWeapon(chargeWeapon)
	end

	self._torpedoWeaponList = {}

	for _, torpedoWeapon in ipairs(unitData:GetTorpedoList()) do
		self:InitTorpedoWeapon(torpedoWeapon)
	end

	self._airAssistList = {}

	local airAssistList = unitData:GetAirAssistList()

	if airAssistList ~= nil then
		for _, airAssist in ipairs(airAssistList) do
			self:InitAirAssit(airAssist)
		end
	end

	self._weaponSectorList = {}
end

--- 注册玩家特有事件监听（濒死、武器CD、扇区、空袭等）
function BattlePlayerCharacter.AddUnitEvent(self)
	BattlePlayerCharacter.super.AddUnitEvent(self)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.WILL_DIE, self.onWillDie)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.INIT_COOL_DOWN, self.onInitWeaponCD)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.WEAPON_SECTOR, self.onActiveWeaponSector)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.CREATE_POINT_AIR_STRIKE, self.onCreatePointAirStrike)

	-- 舰队防空武器注册
	if self._unitData:GetFleetRangeAAWeapon() then
		self:RegisterWeaponListener(self._unitData:GetFleetRangeAAWeapon())
	end
end

--- 移除所有事件监听
function BattlePlayerCharacter.RemoveUnitEvent(self)
	if self._unitData:GetFleetRangeAAWeapon() then
		self:UnregisterWeaponListener(self._unitData:GetFleetRangeAAWeapon())
	end

	for _, chargeWeapon in ipairs(self._chargeWeaponList) do
		chargeWeapon:UnregisterEventListener(self, BattleUnitEvent.CHARGE_WEAPON_FINISH)
		self:UnregisterWeaponListener(chargeWeapon)
	end

	for _, torpedoWeapon in ipairs(self._torpedoWeaponList) do
		torpedoWeapon:UnregisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_FIRE)
		torpedoWeapon:UnregisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_PREPAR)
		torpedoWeapon:UnregisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_CANCEL)
		torpedoWeapon:UnregisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_READY)
		self:UnregisterWeaponListener(torpedoWeapon)
	end

	for _, airAssist in ipairs(self._airAssistList) do
		airAssist:UnregisterEventListener(self, BattleUnitEvent.CHARGE_WEAPON_FINISH)
		airAssist:UnregisterEventListener(self, BattleUnitEvent.FIRE)
	end

	self._unitData:UnregisterEventListener(self, BattleUnitEvent.WILL_DIE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.INIT_COOL_DOWN)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.CREATE_POINT_AIR_STRIKE)
	BattlePlayerCharacter.super.RemoveUnitEvent(self)
end

--- 每帧Update：更新位置、矩阵、箭头、氧气条、隐藏槽
function BattlePlayerCharacter.Update(self)
	BattlePlayerCharacter.super.Update(self)
	self:UpdatePosition()
	self:UpdateMatrix()

	if not self._inViewArea or not self._alwaysHideArrow then
		self:UpdateArrowBarPosition()
	end

	-- 更新潜艇氧气条
	if self._unitData:GetOxyState() then
		self:UpdateOxygenBar()
	end

	-- 更新隐藏槽时钟
	if self._cloakBar then
		self._cloakBar:UpdateCloakProgress()
		self._hpCloakBar:UpdateCloakProgress()

		if not self._inViewArea or not self._alwaysHideArrow then
			self:UpdateCloakBarPosition()
		end
	end
end

--- 更新箭头位置，外加舰队左边界距离检测
--- - 离左边界太近时降低箭头透明度
--- - 镜像Q版图标支持（MIRROR_QICON）
function BattlePlayerCharacter.UpdateArrowBarPosition(self)
	BattlePlayerCharacter.super.UpdateArrowBarPosition(self)

	local leftBoundDistance = self._unitData:GetFleetVO():GetLeftBoundDistance()

	-- 根据距离左边界调整箭头透明度
	if self._arrowCG and leftBoundDistance then
		if leftBoundDistance < 6 then
			self._arrowCG.alpha = 0.1
		else
			self._arrowCG.alpha = 1
		end
	end

	-- 镜像Q版图标处理
	if self._unitData:GetGroupID() and table.contains(BattleConfig.MIRROR_QICON_SHIP_GROUP, self._unitData:GetGroupID()) then
		local paintingName

		if self._arrowVector.x > 0 then
			paintingName = self._unitData:GetTemplate().painting .. BattleConfig.MIRROR_QICON_KEY
		else
			paintingName = self._unitData:GetTemplate().painting
		end

		local qIcon = ys.Battle.BattleResourceManager.GetInstance():GetCharacterQIcon(paintingName)

		setImageSprite(findTF(self._arrowBar, "icon"), qIcon)
	end
end

--- 更新HP条，外加卡牌迷题模式的矢量条更新
function BattlePlayerCharacter.UpdateHpBar(self)
	BattlePlayerCharacter.super.UpdateHpBar(self)

	if self._unitData.__name == ys.Battle.BattleCardPuzzlePlayerUnit.__name then
		self:UpdateVectorBar()
	end
end

--- 更新氧气条进度显示
function BattlePlayerCharacter.UpdateOxygenBar(self)
	self._oxygenSlider.value = self._unitData:GetOxygenProgress()
end

--- 更新矢量HP条填充量（卡牌迷题模式使用）
function BattlePlayerCharacter.UpdateVectorBar(self)
	local hpRate = self._unitData:GetHPRate()

	self._vectorProgress.fillAmount = hpRate
end

--- 更新UI组件参考坐标，同时处理出生点坐标
function BattlePlayerCharacter.UpdateUIComponentPosition(self)
	BattlePlayerCharacter.super.UpdateUIComponentPosition(self)

	local bornPos = self._unitData:GetBornPosition()

	if bornPos then
		if not self._referenceVectorBorn then
			self._referenceVectorBorn = Vector3.New(bornPos.x, bornPos.y, bornPos.z)
		else
			self._referenceVectorBorn:Set(bornPos.x, bornPos.y, bornPos.z)
		end

		ys.Battle.BattleVariable.CameraPosToUICameraByRef(self._referenceVectorBorn)
	end
end

--- 添加箭头条并设置玩家特有元素：CanvasGroup、头像图标、排序
function BattlePlayerCharacter.AddArrowBar(self, arrowBarObj)
	BattlePlayerCharacter.super.AddArrowBar(self, arrowBarObj)

	self._arrowCG = GetOrAddComponent(self._arrowBarTf, typeof(CanvasGroup))
	self._vectorProgress = self._arrowBarTf:Find("HPBar/HPProgress"):GetComponent(typeof(Image))

	local qIcon = ys.Battle.BattleResourceManager.GetInstance():GetCharacterQIcon(self._unitData:GetTemplate().painting)

	setImageSprite(findTF(self._arrowBar, "icon"), qIcon)

	-- 旗舰（第3位）特殊排序处理
	if self._unitData:IsMainFleetUnit() and self._unitData:GetFleetVO():GetMainList()[3] == self._unitData then
		arrowBarObj.transform:SetSiblingIndex(arrowBarObj.transform.parent.childCount - 3)
	end

	self:UpdateVectorBar()
end

--- 获取参考坐标：视野内使用父类方法，视野外使用箭头位置
--- @param comparePos Vector3|nil 比较坐标
--- @return Vector3 参考坐标
function BattlePlayerCharacter.GetReferenceVector(self, comparePos)
	if self._inViewArea then
		return BattlePlayerCharacter.super.GetReferenceVector(self, comparePos)
	else
		return self._arrowVector
	end
end

--- 禁用鱼雷轨道显示
function BattlePlayerCharacter.DisableWeaponTrack(self)
	if self._torpedoTrack then
		self._torpedoTrack:SetActive(false)
	end
end

--- 声纳激活：控制声纳标注的Animator启用状态
function BattlePlayerCharacter.SonarAcitve(self, isActive)
	if ys.Battle.BattleAttr.HasSonar(self._unitData) then
		self._sonar:GetComponent(typeof(Animator)).enabled = isActive
	end
end

--- 更新下潜隐身：额外控制潜水标记和氧气条的显示
function BattlePlayerCharacter.UpdateDiveInvisible(self)
	BattlePlayerCharacter.super.UpdateDiveInvisible(self)

	local diveInvisible = self._unitData:GetDiveInvisible()

	SetActive(self._diveMark, diveInvisible)

	local oxygenVisible = self._unitData:GetOxygenVisible()

	SetActive(self._oxygenBar, oxygenVisible)
end

--- 销毁玩家角色：清理鱼雷图标、声纳、武器扇区等
function BattlePlayerCharacter.Dispose(self)
	self._torpedoIcons = nil
	self._renderer = nil
	self._sonar = nil
	self._diveMark = nil
	self._oxygenBar = nil
	self._oxygenSlider = nil

	Object.Destroy(self._arrowBar)

	for _, sector in ipairs(self._weaponSectorList) do
		sector:Dispose()
	end

	self._weaponSectorList = nil

	BattlePlayerCharacter.super.Dispose(self)
end

--- @return string 模型prefab名称
function BattlePlayerCharacter.GetModleID(self)
	return self._unitData:GetTemplate().prefab
end

--- HP更新事件：更新矢量条
--- @param event table HP更新事件数据
function BattlePlayerCharacter.OnUpdateHP(self, event)
	BattlePlayerCharacter.super.OnUpdateHP(self, event)
	self:UpdateVectorBar()
end

--- 初始化武器CD完成回调
function BattlePlayerCharacter.onInitWeaponCD(self, event)
	self:onTorepedoReady()
end

--- 蓄力技能闪烁特效
--- @param event table {Data = {callbackFunc, timeScale}}
function BattlePlayerCharacter.onCastBlink(self, event)
	local callbackFunc = event.Data.callbackFunc
	local timeScale = event.Data.timeScale

	self:AddFX("jineng", false, timeScale, callbackFunc)
end

--- 鱼雷发射事件：隐藏轨道并更新弹药显示
function BattlePlayerCharacter.onTorpedoWeaponFire(self, event)
	self._torpedoTrack:SetActive(false)
	self:onTorepedoReady()
end

--- 鱼雷瞄准准备：显示鱼雷轨道并根据子弹模板设置缩放
function BattlePlayerCharacter.onTorpedoPrepar(self, event)
	self._torpedoTrack:SetActive(true)

	local bulletTemplate = ys.Battle.BattleDataFunction.GetBulletTmpDataFromID(event.Dispatcher:GetTemplateData().bullet_ID[1])

	self._torpedoTrack:SetScale(Vector3(bulletTemplate.range / BattleConfig.SPINE_SCALE, bulletTemplate.cld_box[3] / BattleConfig.SPINE_SCALE, 1))
end

--- 鱼雷取消：隐藏轨道
function BattlePlayerCharacter.onTorpedoCancel(self, event)
	self._torpedoTrack:SetActive(false)
end

--- 更新鱼雷弹药图标数量显示
function BattlePlayerCharacter.onTorepedoReady(self)
	local readyCount = 0

	for _, torpedoWeapon in ipairs(self._torpedoWeaponList) do
		if torpedoWeapon:GetCurrentState() == torpedoWeapon.STATE_READY then
			readyCount = readyCount + 1
		end
	end

	for i = 1, ys.Battle.BattleConst.MAX_EQUIPMENT_COUNT do
		LuaHelper.SetTFChildActive(self._torpedoIcons, "torpedo_" .. i, i <= readyCount)
	end
end

--- 防空导弹发射后更新弹药显示
function BattlePlayerCharacter.onAAMissileWeaponFire(self, event)
	self:onAAMissileReady()
end

--- 濒死事件：关闭所有烟雾特效
function BattlePlayerCharacter.onWillDie(self, event)
	for _, smokeConfig in ipairs(self._smokeList) do
		if smokeConfig.active == true then
			smokeConfig.active = false

			local smokes = smokeConfig.smokes

			for fxData, fxObj in pairs(smokes) do
				if fxData.unInitialize then
					-- 尚未初始化的跳过
				else
					SetActive(fxObj, false)
				end
			end
		end
	end
end

--- 添加HP条并设置玩家特有UI元素：鱼雷图标、声纳标记、下潜/氧气
function BattlePlayerCharacter.AddHPBar(self, hpBarObj)
	BattlePlayerCharacter.super.AddHPBar(self, hpBarObj)

	self._torpedoIcons = self._HPBarTf:Find("torpedoIcons")

	if #self._torpedoWeaponList <= 0 then
		self._torpedoIcons.gameObject:SetActive(false)
	end

	self._sonar = self._HPBarTf:Find("sonarMark")

	if ys.Battle.BattleAttr.HasSonar(self._unitData) then
		self._sonar.gameObject:SetActive(true)
	else
		self._sonar.gameObject:SetActive(false)
	end

	self._diveMark = self._HPBarTf:Find("diveMark")
	self._oxygenBar = self._HPBarTf:Find("oxygenBar")
	self._oxygenSlider = self._oxygenBar:Find("oxygen"):GetComponent(typeof(Slider))
	self._oxygenSlider.value = 1

	self:onTorepedoReady()
end

--- 添加模型后缓存Renderer组件引用
function BattlePlayerCharacter.AddModel(self, modelGO)
	BattlePlayerCharacter.super.AddModel(self, modelGO)

	self._renderer = self:GetTf():GetComponent(typeof(Renderer))
end

--- 添加蓄力区域对象
--- @param chargeAreaObj GameObject 蓄力区域GameObject
function BattlePlayerCharacter.AddChargeArea(self, chargeAreaObj)
	self._chargeWeaponArea = ys.Battle.BattleChargeArea.New(chargeAreaObj)
end

--- 添加鱼雷瞄准轨道（BossSkillAlert组件）
--- @param torpedoTrackObj GameObject 轨道GameObject
function BattlePlayerCharacter.AddTorpedoTrack(self, torpedoTrackObj)
	self._torpedoTrack = ys.Battle.BossSkillAlert.New(torpedoTrackObj)

	self._torpedoTrack:SetActive(false)
end

--- 添加隐藏槽并创建HP条内嵌隐藏条（FORM_BAR类型）
function BattlePlayerCharacter.AddCloakBar(self, cloakBarObj)
	BattlePlayerCharacter.super.AddCloakBar(self, cloakBarObj)

	local hpCloakBarTF = self._HPBarTf:Find("cloakBar")

	self._hpCloakBar = ys.Battle.BattleCloakBar.New(hpCloakBarTF, ys.Battle.BattleCloakBar.FORM_BAR)

	self._hpCloakBar:ConfigCloak(self._unitData:GetCloak())
	self._hpCloakBar:UpdateCloakProgress()
	self._hpCloakBar:SetActive(true)
end

--- 隐藏配置更新：同时更新主隐藏条和内嵌隐藏条
function BattlePlayerCharacter.onUpdateCloakConfig(self, event)
	BattlePlayerCharacter.super.onUpdateCloakConfig(self, event)
	self._hpCloakBar:UpdateCloakConfig()
end

--- 隐藏锁定更新
function BattlePlayerCharacter.onUpdateCloakLock(self, event)
	BattlePlayerCharacter.super.onUpdateCloakLock(self, event)
	self._hpCloakBar:UpdateCloakLock()
end

--- 初始化蓄力武器：注册武器监听和蓄力完成事件
--- @param chargeWeapon BattleChargeWeaponUnit 蓄力武器
function BattlePlayerCharacter.InitChargeWeapon(self, chargeWeapon)
	self._chargeWeaponList[#self._chargeWeaponList + 1] = chargeWeapon

	self:RegisterWeaponListener(chargeWeapon)
	chargeWeapon:RegisterEventListener(self, BattleUnitEvent.CHARGE_WEAPON_FINISH, self.onCastBlink)
end

--- 初始化空袭辅助武器：注册蓄力完成和开火事件
--- @param airAssist BattleAirAssistUnit 空袭辅助单位
function BattlePlayerCharacter.InitAirAssit(self, airAssist)
	self._airAssistList[#self._airAssistList + 1] = airAssist

	airAssist:RegisterEventListener(self, BattleUnitEvent.CHARGE_WEAPON_FINISH, self.onCastBlink)
	airAssist:RegisterEventListener(self, BattleUnitEvent.FIRE, self.onCannonFire)
end

--- 初始化鱼雷武器：注册开火、准备、取消、就绪事件
--- @param torpedoWeapon BattleTorpedoWeaponUnit 鱼雷武器
function BattlePlayerCharacter.InitTorpedoWeapon(self, torpedoWeapon)
	self._torpedoWeaponList[#self._torpedoWeaponList + 1] = torpedoWeapon

	self:RegisterWeaponListener(torpedoWeapon)
	torpedoWeapon:RegisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_FIRE, self.onTorpedoWeaponFire)
	torpedoWeapon:RegisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_PREPAR, self.onTorpedoPrepar)
	torpedoWeapon:RegisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_CANCEL, self.onTorpedoCancel)
	torpedoWeapon:RegisterEventListener(self, BattleUnitEvent.TORPEDO_WEAPON_READY, self.onTorepedoReady)
end

--- 武器扇区激活/停用：创建或销毁射界指示器
--- @param event table {Data = {isActive, weapon}}
function BattlePlayerCharacter.onActiveWeaponSector(self, event)
	local sectorData = event.Data
	local isActive = sectorData.isActive
	local weapon = sectorData.weapon

	if isActive then
		local sectorTf = self._factory:GetFXPool():GetCharacterFX("weaponrange", self).transform
		local sector = ys.Battle.BattleWeaponRangeSector.New(sectorTf)

		sector:ConfigHost(self._unitData, weapon)

		self._weaponSectorList[weapon] = sector
	else
		self._weaponSectorList[weapon]:Dispose()

		self._weaponSectorList[weapon] = nil
	end
end

--- 创建定点空袭武器事件
--- @param event table {Data = {weapon}}
function BattlePlayerCharacter.onCreatePointAirStrike(self, event)
	local weapon = event.Data.weapon

	self:InitChargeWeapon(weapon)
end

--- 动画触发回调：通知UnitData动作触发
function BattlePlayerCharacter.OnAnimatorTrigger(self)
	self._unitData:CharacterActionTriggerCallback()
end

--- 动画结束回调：通知UnitData动作结束
function BattlePlayerCharacter.OnAnimatorEnd(self)
	self._unitData:CharacterActionEndCallback()
end

--- 动画开始回调：通知UnitData动作开始
function BattlePlayerCharacter.OnAnimatorStart(self)
	self._unitData:CharacterActionStartCallback()
end
