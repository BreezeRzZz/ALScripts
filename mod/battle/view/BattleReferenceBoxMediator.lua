ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig

--- @class BattleReferenceBoxMediator : ys.MVC.Mediator
--- @classdesc 战斗引用盒中介者——用于 Debug/开发阶段的碰撞盒可视化。
--- 可切换显示三类碰撞盒：单位碰撞盒、子弹碰撞盒、墙体碰撞盒。
--- 还管理 BattleUnitDetailView（单位详细信息面板）。
---
--- 碰撞盒类型：
---   - Cylinder/Cube_friendly: 友方单位（圆筒形/立方体）
---   - Cylinder/Cube_foe: 敌方单位（圆筒形/立方体）
---   - Cube_friendly/Cube_foe: 子弹碰撞盒（立方体）
--- @field _dataProxy BattleDataProxy 数据层代理
--- @field _sceneMediator BattleSceneMediator 场景中介者（用于实例化UI组件）
--- @field _boxContainer UnityEngine.GameObject 碰撞盒根容器
--- @field _detailContainer UnityEngine.GameObject 单位详情面板容器
--- @field _unitBoxList table<number, GameObject> 单位碰撞盒映射
--- @field _bulletBoxList table<number, GameObject> 子弹碰撞盒映射
--- @field _wallBoxList table<number, GameObject> 墙体碰撞盒映射
--- @field _detailViewList table<number, BattleUnitDetailView> 单位详情视图映射
local BattleReferenceBoxMediator = class("BattleReferenceBoxMediator", ys.MVC.Mediator)

ys.Battle.BattleReferenceBoxMediator = BattleReferenceBoxMediator
BattleReferenceBoxMediator.__name = "BattleReferenceBoxMediator"

function BattleReferenceBoxMediator.Ctor(self)
	BattleReferenceBoxMediator.super.Ctor(self)
end

--- 初始化：获取 dataProxy/sceneMediator，创建容器，注册事件
function BattleReferenceBoxMediator.Initialize(self)
	BattleReferenceBoxMediator.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	self._sceneMediator = self._state:GetSceneMediator()
	self._boxContainer = GameObject("BoxContainer")
	self._detailContainer = self._state:GetUI()._tf:Find("CharacterDetailContainer").gameObject
	self._unitBoxList = {}
	self._bulletBoxList = {}
	self._wallBoxList = {}
	self._detailViewList = {}
	self._unitBoxActive = false
	self._bulletBoxActive = false
	self._detailViewActive = false

	self:initUnitEvent()
end

--- 切换单位碰撞盒显示
--- @param active boolean 是否显示
function BattleReferenceBoxMediator.ActiveUnitBoxes(self, active)
	if active and not self._unitBoxActive then
		self._unitBoxActive = true
		-- 为已存在的所有单位创建碰撞盒
		self:createExistBoxes()
	elseif not active and self._unitBoxActive then
		self._unitBoxActive = false
		self:removeAllBoxes()
	end
end

--- 切换子弹碰撞盒显示
--- @param active boolean 是否显示
function BattleReferenceBoxMediator.ActiveBulletBoxes(self, active)
	if active and not self._bulletBoxActive then
		self:initBulletEvent()
		self._bulletBoxActive = true
	elseif not active and self._bulletBoxActive then
		self:disInitBulletEvent()
		self:removeAllBulletBoxes()
		self._bulletBoxActive = false
	end
end

--- 切换单位详情面板显示
--- @param active boolean 是否显示
function BattleReferenceBoxMediator.ActiveUnitDetail(self, active)
	SetActive(self._detailContainer, active)

	if active and not self._detailViewActive then
		-- 为所有舰队单位创建详情面板
		for _, fleet in ipairs(self._dataProxy:GetFleetList()) do
			local unitList = fleet:GetUnitList()
			for _, unit in ipairs(unitList) do
				self:createDetail(unit)
			end
		end

		-- 为标记的敌方单位创建详情面板
		for unitID, unit in pairs(self._dataProxy:GetUnitList()) do
			if table.contains(ys.Battle.BattleUnitDetailView.EnemyMarkList, unit:GetTemplate().id) then
				self:createDetail(unit)
			end
		end

		self._detailViewActive = true
	elseif not active and self._detailViewActive then
		self._detailViewActive = false
		self:removeAllDetail()
	end
end

--- 每帧更新：更新碰撞盒位置/缩放/旋转以匹配实际数据模型的位置
function BattleReferenceBoxMediator.Update(self)
	-- 更新单位碰撞盒位置
	for unitID, unit in pairs(self._dataProxy:GetUnitList()) do
		local box = self._unitBoxList[unitID]
		if box then
			box.transform.localPosition = unit:GetPosition()
		end
	end

	-- 更新子弹碰撞盒（仅在激活状态下）
	if self._bulletBoxActive then
		for bulletID, bullet in pairs(self._dataProxy:GetBulletList()) do
			local box = self._bulletBoxList[bulletID] or self:createBulletBox(bullet)
			box.transform.localPosition = bullet:GetPosition()
			box.transform.localEulerAngles = Vector3(0, -bullet:GetYAngle(), 0)

			local boxSize = bullet:GetBoxSize() * 2
			box.transform.localScale = Vector3(boxSize.x, boxSize.y, boxSize.z)
		end

		for wallID, wall in pairs(self._dataProxy:GetWallList()) do
			(self._wallBoxList[wallID] or self:createWallBox(wall)).transform.localPosition = wall:GetPosition()
		end
	end

	-- 更新详情面板
	if self._detailViewActive then
		for unitID, detailView in pairs(self._detailViewList) do
			detailView:Update()
		end
	end
end

--- 注册单位的添加/移除事件
function BattleReferenceBoxMediator.initUnitEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
end

--- 注销单位的添加/移除事件
function BattleReferenceBoxMediator.disInitUnitEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
end

--- 处理单位添加事件：若碰撞盒已激活则创建碰撞盒，若详情已激活则创建详情
--- @param event ys.Event 事件对象，Data 中包含 type 和 unit
function BattleReferenceBoxMediator.onAddUnit(self, event)
	local unitType = event.Data.type
	local unit = event.Data.unit

	if self._unitBoxActive then
		local box = self:createBox(unit)
		self._unitBoxList[unit:GetUniqueID()] = box
	end

	if self._detailViewActive then
		if unitType == BattleConst.UnitType.PLAYER_UNIT then
			self:createDetail(unit)
		elseif table.contains(ys.Battle.BattleUnitDetailView.EnemyMarkList, unit:GetTemplate().id) then
			self:createDetail(unit)
		end
	end
end

--- 为指定单位创建一个碰撞盒可视化GameObject
--- @param unit table 战斗单位数据
--- @return UnityEngine.GameObject 碰撞盒GameObject
function BattleReferenceBoxMediator.createBox(self, unit)
	local boxObj
	local boxSize = unit:GetBoxSize()
	local sideTag -- 碰撞盒预制件后缀，区分友方/敌方 "_friendly" / "_foe"
	local iffTag = unit:GetIFF() == 1 and "_friendly" or "_foe"

	if boxSize.range then
		-- 圆形碰撞（声纳等），用 Cylinder 预制件
		boxObj = self._sceneMediator:InstantiateCharacterComponent("Cylinder" .. iffTag)
	else
		-- 方形碰撞，用 Cube 预制件
		boxObj = self._sceneMediator:InstantiateCharacterComponent("Cube" .. iffTag)
		boxSize = boxSize * 2
	end

	boxObj.transform:SetParent(self._boxContainer.transform)
	boxObj.layer = LayerMask.NameToLayer("Default")

	if boxSize.range then
		boxObj.transform.localScale = Vector3(boxSize.range * 2, boxSize.tickness * 2, boxSize.range * 2)
	else
		boxObj.transform.localScale = Vector3(boxSize.x, boxSize.y, boxSize.z)
	end

	SetActive(boxObj, true)

	return boxObj
end

--- 为当前所有已存在的单位批量创建碰撞盒
function BattleReferenceBoxMediator.createExistBoxes(self)
	for unitID, unit in pairs(self._dataProxy:GetUnitList()) do
		self._unitBoxList[unitID] = self:createBox(unit)
	end
end

--- 创建单位详情视图
--- @param unit table 战斗单位
--- @return BattleUnitDetailView
function BattleReferenceBoxMediator.createDetail(self, unit)
	local detailView = ys.Battle.BattleUnitDetailView.New()
	local unitIFF = unit:GetIFF()
	local detailParent = self._state:GetUI()._tf:Find("CharacterDetailContainer/" .. unit:GetIFF())
	local detailPanel = self._sceneMediator:InstantiateCharacterComponent("CharacterDetailContainer/detailPanel")

	detailPanel.transform:SetParent(detailParent, true)
	detailView:ConfigSkin(detailPanel)
	detailView:SetUnit(unit)

	self._detailViewList[unit:GetUniqueID()] = detailView

	return detailView
end

--- 处理单位移除事件
function BattleReferenceBoxMediator.onRemoveUnit(self, event)
	local unitType = event.Data.type

	if self._unitBoxActive then
		self:removeBox(event.Data.UID)
	end

	if self._detailViewActive
		and (unitType ~= BattleConst.UnitType.PLAYER_UNIT or unitType ~= BattleConst.UnitType.ENEMY_UNIT or unitType ~= BattleConst.UnitType.BOSS_UNIT)
		and self._detailViewList[event.Data.UID] then
		self:removeDetail(event.Data.UID)
	end
end

--- 移除单位碰撞盒
--- @param unitID number 单位UID
function BattleReferenceBoxMediator.removeBox(self, unitID)
	GameObject.Destroy(self._unitBoxList[unitID])
	self._unitBoxList[unitID] = nil
end

--- 移除单位详情视图
--- @param unitID number 单位UID
function BattleReferenceBoxMediator.removeDetail(self, unitID)
	self._detailViewList[unitID]:Dispose()
	self._detailViewList[unitID] = nil
end

--- 移除所有单位碰撞盒
function BattleReferenceBoxMediator.removeAllBoxes(self)
	for unitID, _ in pairs(self._dataProxy:GetUnitList()) do
		self:removeBox(unitID)
	end
end

--- 移除所有单位详情
function BattleReferenceBoxMediator.removeAllDetail(self)
	for unitID, _ in pairs(self._detailViewList) do
		self:removeDetail(unitID)
	end
end

--- 注册子弹移除事件（用于同步移除碰撞盒）
function BattleReferenceBoxMediator.initBulletEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_BULLET, self.onRemoveBullet)
end

--- 注销子弹移除事件
function BattleReferenceBoxMediator.disInitBulletEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_BULLET)
end

--- 处理子弹移除事件
function BattleReferenceBoxMediator.onRemoveBullet(self, event)
	self:removeBulletBox(event.Data.UID)
end

--- 移除子弹碰撞盒
--- @param bulletID number 子弹UID
function BattleReferenceBoxMediator.removeBulletBox(self, bulletID)
	GameObject.Destroy(self._bulletBoxList[bulletID])
	self._bulletBoxList[bulletID] = nil
end

--- 移除所有子弹碰撞盒
function BattleReferenceBoxMediator.removeAllBulletBoxes(self)
	for bulletID, _ in pairs(self._bulletBoxList) do
		self:removeBulletBox(bulletID)
	end
end

--- 为指定子弹创建碰撞盒可视化（每帧首次出现时惰性创建）
--- @param bullet table 子弹数据
--- @return UnityEngine.GameObject 碰撞盒GameObject
function BattleReferenceBoxMediator.createBulletBox(self, bullet)
	local boxObj

	if bullet:GetIFF() == 1 then
		boxObj = self._sceneMediator:InstantiateCharacterComponent("Cube_friendly")
	else
		boxObj = self._sceneMediator:InstantiateCharacterComponent("Cube_foe")
	end

	boxObj.transform:SetParent(self._boxContainer.transform)
	boxObj.layer = LayerMask.NameToLayer("Default")

	local boxSize = bullet:GetBoxSize() * 2
	boxObj.transform.localScale = Vector3(boxSize.x, boxSize.y, boxSize.z)

	SetActive(boxObj, true)

	self._bulletBoxList[bullet:GetUniqueID()] = boxObj

	return boxObj
end

--- 创建墙体碰撞盒可视化
--- @param wall table 墙体数据
--- @return UnityEngine.GameObject
function BattleReferenceBoxMediator.createWallBox(self, wall)
	local box = self:createBox(wall)
	self._wallBoxList[wall:GetUniqueID()] = box
	return box
end

--- 销毁中介者：清理所有碰撞盒和详情视图
function BattleReferenceBoxMediator.Dispose(self)
	self:disInitUnitEvent()

	for _, box in pairs(self._unitBoxList) do
		GameObject.Destroy(box)
	end

	for _, bulletBox in pairs(self._bulletBoxList) do
		GameObject.Destroy(bulletBox)
	end

	for _, wallBox in pairs(self._wallBoxList) do
		GameObject.Destroy(wallBox)
	end

	self._unitBoxList = nil
	self._wallBoxList = nil
	self._bulletBoxList = nil

	self:removeAllDetail()
	self._detailViewList = nil

	GameObject.Destroy(self._boxContainer)
	BattleReferenceBoxMediator.super.Dispose(self)
end
