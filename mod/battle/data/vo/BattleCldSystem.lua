ys = ys or {}

local ys = ys
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local VectorZero = Vector3.zero
local OxyState = BattleConst.OXY_STATE
local BulletTypeConst = BattleConst.BulletType
local BattleAttr = ys.Battle.BattleAttr
local BattleCldSystem = class("BattleCldSystem")

ys.Battle.BattleCldSystem = BattleCldSystem
BattleCldSystem.__name = "BattleCldSystem"

--- @class BattleCldSystem
--- @param proxy BattleDataProxy 战斗数据代理
--- @return nil
--- 碰撞系统，管理所有碰撞树（舰船、子弹、AOE、飞机、墙壁等）
function BattleCldSystem.Ctor(self, proxy)
	self._proxy = proxy

	self:InitCldTree()

	self._friendlyCode = proxy:GetFriendlyCode()
	self._foeCode = proxy:GetFoeCode()
end

--- @return nil
function BattleCldSystem.Dispose(self)
	self._proxy = nil
	self._shipTree = nil
	self._foeShipTree = nil
	self._aircraftTree = nil
	self._surfaceBulletTree = nil
	self._airBulletTree = nil
	self._bulletTreeList = nil
	self._foeSurafceBulletTree = nil
	self._foeAirbulletTree = nil
	self._foeBulleetTreeList = nil
	self._surfaceAOETree = nil
	self._airAOETree = nil
	self._AOETreeList = nil
	self._wallTree = nil
end

--- @return nil
--- 初始化所有碰撞树（舰船、子弹、AOE、飞机、墙壁），使用proxy的TotalBounds作为边界
function BattleCldSystem.InitCldTree(self)
	local upperBound, lowerBound, leftBound, rightBound = self._proxy:GetTotalBounds()
	local minPos = Vector3(leftBound, 0, lowerBound)
	local maxPos = Vector3(rightBound, 0, upperBound)

	self._shipTree = pg.ColliderTree.New("shipTree", minPos, maxPos, 2)
	self._foeShipTree = pg.ColliderTree.New("foeShipTree", minPos, maxPos, 2)
	self._aircraftTree = pg.ColliderTree.New("aircraftTree", minPos, maxPos, 2)
	self._surfaceBulletTree = pg.ColliderTree.New("surfaceBullets", minPos, maxPos, 4)
	self._airBulletTree = pg.ColliderTree.New("airBullets", minPos, maxPos, 3)
	self._bulletTreeList = {}
	self._bulletTreeList[BattleConst.BulletField.SURFACE] = self._surfaceBulletTree
	self._bulletTreeList[BattleConst.BulletField.AIR] = self._airBulletTree
	self._foeSurafceBulletTree = pg.ColliderTree.New("foeSurfaceBullets", minPos, maxPos, 3)
	self._foeAirbulletTree = pg.ColliderTree.New("foeAirBullets", minPos, maxPos, 3)
	self._foeBulleetTreeList = {}
	self._foeBulleetTreeList[BattleConst.BulletField.SURFACE] = self._foeSurafceBulletTree
	self._foeBulleetTreeList[BattleConst.BulletField.AIR] = self._foeAirbulletTree
	self._surfaceAOETree = pg.ColliderTree.New("surfaceAOE", minPos, maxPos, 2)
	self._airAOETree = pg.ColliderTree.New("airAOE", minPos, maxPos, 2)
	self._bulletAOETree = pg.ColliderTree.New("bulletAOE", minPos, maxPos, 2)
	self._AOETreeList = {}
	self._AOETreeList[BattleConst.AOEField.SURFACE] = self._surfaceAOETree
	self._AOETreeList[BattleConst.AOEField.AIR] = self._airAOETree
	self._AOETreeList[BattleConst.AOEField.BULLET] = self._bulletAOETree
	self._wallTree = pg.ColliderTree.New("wall", minPos, maxPos, 2)
end

--- @param ship BattleUnit
--- @return nil
--- 更新舰船碰撞：根据IFF决定使用哪个碰撞树，处理敌方/友方碰撞和减速
function BattleCldSystem.UpdateShipCldTree(self, ship)
	local speed = ship:GetSpeed()
	local cldBox = ship:GetCldBox()
	local updateTree
	local isNotCldImmune = not BattleAttr.IsUnitCldImmune(ship)

	if ship:GetIFF() == self._foeCode then
		if isNotCldImmune then
			-- 敌方舰船之间的内部碰撞（FriendlyCld标记的敌方单位互相推挤）
			if ship:GetCldData().FriendlyCld then
				local foeCldList = self._foeShipTree:GetCldList(ship, speed)

				ship:GetCldData().distList = {}

				if #foeCldList > 1 then
					self:HandleEnemyShipCld(foeCldList, ship)
				end
			end

			-- 敌方舰船与我方舰船的碰撞
			local friendlyCldList = self._shipTree:GetCldList(ship, speed)
			local filteredSelfCount = self.surfaceFilterCount(ship, friendlyCldList)

			self._proxy:HandleShipCrashDecelerate(ship, filteredSelfCount)
			self:HandlePlayerShipCld(friendlyCldList, ship)
		end

		updateTree = self._foeShipTree
	elseif ship:GetIFF() == self._friendlyCode then
		if isNotCldImmune then
			local foeCldList = self._foeShipTree:GetCldList(ship, speed)
			local filteredFoeCount = self.surfaceFilterCount(ship, foeCldList)

			self._proxy:HandleShipCrashDecelerate(ship, filteredFoeCount)
		end

		updateTree = self._shipTree
	end

	updateTree:Update(cldBox)
end

--- @param cldList table 碰撞列表
--- @param ship BattleUnit 当前舰船
--- @return nil
--- 处理玩家舰船与敌方舰船的碰撞：收集可造成伤害的敌方单位UID列表
function BattleCldSystem.HandlePlayerShipCld(self, cldList, ship)
	local cldData = ship:GetCldData()

	if cldData.Active == false or cldData.ImmuneCLD == true then
		return
	end

	local cldCount = #cldList
	local damageUIDList = {}

	for i = 1, cldCount do
		local otherCldData = cldList[i].data

		if otherCldData.Active == false or otherCldData.ImmuneCLD == true then
			-- 无效或免疫碰撞的单位跳过
		elseif otherCldData.UID == ship:GetUniqueID() then
			-- 自身跳过
		elseif cldData.IFF == otherCldData.IFF then
			-- 同阵营跳过
		elseif cldData.Surface ~= otherCldData.Surface then
			-- 不同平面（水面/水下）跳过
		else
			damageUIDList[#damageUIDList + 1] = otherCldData.UID
		end
	end

	self._proxy:HandleShipCrashDamageList(ship, damageUIDList)
end

--- @param cldList table 碰撞列表
--- @param ship BattleUnit 当前舰船
--- @return nil
--- 处理敌方舰船之间的碰撞：计算与其他敌方单位的距离并记录到distList
function BattleCldSystem.HandleEnemyShipCld(self, cldList, ship)
	local cldData = ship:GetCldData()

	if cldData.Active == false or cldData.ImmuneCLD == true then
		return
	end

	local shipPos = ship:GetPosition()
	local distList = {}
	local cldCount = #cldList

	for i = 1, cldCount do
		local otherCldData = cldList[i].data

		if otherCldData.Active == false or otherCldData.ImmuneCLD == true then
			-- 无效或免疫碰撞的单位跳过
		elseif otherCldData.UID == ship:GetUniqueID() then
			-- 自身跳过
		elseif cldData.IFF ~= otherCldData.IFF then
			-- 不同阵营跳过
		elseif not otherCldData.FriendlyCld then
			-- 没有开启友方碰撞的跳过
		elseif cldData.Surface ~= otherCldData.Surface then
			-- 不同平面跳过
		else
			local distance = shipPos - self:GetShip(otherCldData.UID):GetPosition()

			distList[#distList + 1] = distance
		end
	end

	cldData.distList = distList
end

--- @param ship BattleUnit
--- @param cldList table
--- @return number count
--- 统计与当前舰船在同一平面、不同阵营且碰撞有效的单位数量
--- 用于判断挤在一起的单位数量，决定减速程度
function BattleCldSystem.surfaceFilterCount(ship, cldList)
	local cldData = ship:GetCldData()
	local count = 0
	local cldCount = #cldList

	for i = 1, cldCount do
		local otherCldData = cldList[i].data

		if otherCldData.Active == true and otherCldData.ImmuneCLD == false and otherCldData.UID ~= ship:GetUniqueID() and cldData.IFF ~= otherCldData.IFF and cldData.Surface == otherCldData.Surface then
			count = count + 1
		end
	end

	return count
end

--- @param aircraft BattleAircraftUnit
--- @return nil
--- 更新飞机的碰撞检测：检测与敌对子弹的碰撞
function BattleCldSystem.UpdateAircraftCld(self, aircraft)
	local speed = aircraft:GetSpeed()
	local cldBox = aircraft:GetCldBox()
	local bulletTree

	-- 敌机检测友方子弹，友机检测敌方子弹
	if aircraft:GetIFF() == self._foeCode then
		bulletTree = self:GetBulletTree(BattleConst.BulletField.AIR)
	elseif aircraft:GetIFF() == self._friendlyCode then
		bulletTree = self:GetFoeBulletTree(BattleConst.BulletField.AIR)
	end

	local bulletCldList = bulletTree:GetCldList(cldBox, speed)

	self:HandleBulletCldWithAircraft(bulletCldList, aircraft)
	self._aircraftTree:Update(aircraft:GetCldBox())
end

--- @param cldList table
--- @param aircraft BattleAircraftUnit
--- @return nil
--- 处理子弹与飞机的碰撞：过滤BULLET类型的有效碰撞并触发HandleBulletHit
function BattleCldSystem.HandleBulletCldWithAircraft(self, cldList, aircraft)
	local cldCount = #cldList

	for i = 1, cldCount do
		local cldData = cldList[i].data

		if cldData.type == BattleConst.CldType.BULLET and cldData.Active == true and cldData.ImmuneCLD == false then
			local bullet = self:GetBullet(cldData.UID)

			self._proxy:HandleBulletHit(bullet, aircraft)
		end
	end
end

--- @param bullet BattleBulletUnit
--- @return nil
--- 更新子弹的碰撞检测：检测与舰船的碰撞并更新子弹碰撞树
function BattleCldSystem.UpdateBulletCld(self, bullet)
	local effectField = bullet:GetEffectField()
	local cldBox = bullet:GetCldBox()
	local bulletIFF = bullet:GetCldData().IFF
	local updateTree
	local _ -- unused

	-- 水面子弹与舰船碰撞检测
	if effectField == BattleConst.BulletField.SURFACE then
		local shipTree = bulletIFF == self._foeCode and self._shipTree or self._foeShipTree
		local shipCldList = self:getBulletCldShipList(bullet, shipTree)

		-- 无差别攻击：检测两个阵营的舰船
		if bullet:IsIndiscriminate() then
			local otherShipTree = shipTree == self._shipTree and self._foeShipTree or self._shipTree
			local otherShipCldList = self:getBulletCldShipList(bullet, otherShipTree)

			for _, cldItem in ipairs(otherShipCldList) do
				table.insert(shipCldList, cldItem)
			end
		end

		self:HandleBulletCldWithShip(shipCldList, bullet)
	end

	-- 根据IFF更新对应子弹碰撞树
	if bulletIFF == self._friendlyCode then
		updateTree = self:GetBulletTree(effectField)
	elseif bulletIFF == self._foeCode then
		updateTree = self:GetFoeBulletTree(effectField)
	end

	updateTree:Update(cldBox)
end

--- @param bullet BattleBulletUnit
--- @param shipTree ColliderTree
--- @return table cldList
--- 获取子弹与舰船碰撞树中所有碰撞的舰船列表
--- SCALE类型子弹使用梯度碰撞检测（支持旋转矩形），其他类型使用普通碰撞检测
function BattleCldSystem.getBulletCldShipList(self, bullet, shipTree)
	local cldBox = bullet:GetCldBox()
	local result

	if bullet:GetType() == BulletTypeConst.SCALE then
		local angle, cosAngle, sinAngle = bullet:GetRadian()

		if math.abs(cosAngle) ~= 1 then
			if bullet:GetIFF() == -1 then
				angle = angle + math.pi
			end

			local boxSize = bullet:GetBoxSize()
			local scaleX = boxSize.x * 2
			local scaleZ = boxSize.z * 2
			local bulletPos = bullet:GetPosition()
			local halfX = boxSize.x
			local offsetX = halfX * cosAngle
			local offsetZ = halfX * sinAngle
			local gradientCenter = Vector3(bulletPos.x + offsetX, 1, bulletPos.z + offsetZ)

			result = shipTree:GetCldListGradient(angle, scaleZ, scaleX, gradientCenter)
		else
			result = shipTree:GetCldList(cldBox, VectorZero)
		end
	else
		result = shipTree:GetCldList(cldBox, VectorZero)
	end

	return result
end

--- @param cldList table
--- @param bullet BattleBulletUnit
--- @return nil
--- 处理子弹与舰船的碰撞：过滤SHIP类型的有效碰撞，检查潜艇下潜/免疫状态，触发HandleBulletHit
function BattleCldSystem.HandleBulletCldWithShip(self, cldList, bullet)
	local cldCount = #cldList
	local bulletType = bullet:GetType()

	for i = 1, cldCount do
		local cldData = cldList[i].data

		if cldData.type == BattleConst.CldType.SHIP and cldData.Active == true and cldData.ImmuneCLD == false then
			local ship = self:GetShip(cldData.UID)
			local oxyState = ship:GetCurrentOxyState()
			local isImmuneCommonBullet = ship:IsImmuneCommonBulletCLD()

			-- 潜艇下潜中且子弹非深水类型，跳过
			if oxyState == OxyState.DIVE and bullet:GetCldData().Surface ~= BattleConst.OXY_STATE.DIVE then
				-- 非深水子弹打不到下潜潜艇
			elseif isImmuneCommonBullet then
				-- 免疫普通子弹碰撞
			elseif self._proxy:HandleBulletHit(bullet, ship) then
				-- 命中后退出（子弹只命中一个目标）
				break
			end
		end
	end
end

--- @param aoe BattleAOEObj
--- @return nil
--- 更新AOE的碰撞检测：根据AOE类型（水面/AIR/BULLET）检测与舰船、飞机或子弹的碰撞
function BattleCldSystem.UpdateAOECld(self, aoe)
	local cldBox = aoe:GetCldBox()
	local fieldType = aoe:GetFieldType()
	local opponentAffected = aoe:OpponentAffected()
	local aoeIFF = aoe:GetCldData().IFF
	-- 若opponentAffected为true，则反转IFF（即攻击相反的阵营）
	local targetIFF = opponentAffected and aoeIFF * -1 or aoeIFF
	local _ -- unused

	if fieldType == BattleConst.AOEField.SURFACE then
		local isFoeAOE = aoe:GetCldData().IFF == self._foeCode
		local shipTree = aoe:OpponentAffected() == isFoeAOE and self._shipTree or self._foeShipTree
		local shipCldList = self:getAreaCldShipList(aoe, shipTree)

		-- 无差别AOE同时检测两个阵营
		if aoe:GetIndiscriminate() then
			local otherShipTree = shipTree == self._shipTree and self._foeShipTree or self._shipTree
			local otherShipCldList = self:getAreaCldShipList(aoe, otherShipTree)

			for _, cldItem in ipairs(otherShipCldList) do
				table.insert(shipCldList, cldItem)
			end
		end

		self:HandleAreaCldWithVehicle(aoe, shipCldList)
	elseif fieldType == BattleConst.AOEField.BULLET then
		local bulletTree

		if targetIFF == self._foeCode then
			bulletTree = self._foeSurafceBulletTree
		else
			bulletTree = self._surfaceBulletTree
		end

		local bulletCldList = bulletTree:GetCldList(cldBox, VectorZero)

		aoe:ClearCLDList()
		self:HandleAreaCldWithBullet(aoe, bulletCldList)
	else
		-- AIR类型AOE：检测飞机碰撞
		local aircraftCldList = {}
		local allAircraftCldList = self._aircraftTree:GetCldList(cldBox, VectorZero)

		for _, aircraftCldItem in ipairs(allAircraftCldList) do
			if aircraftCldItem.data.IFF == targetIFF then
				table.insert(aircraftCldList, aircraftCldItem)
			end
		end

		self:HandleAreaCldWithAircraft(aoe, aircraftCldList)
	end
end

--- @param aoe BattleAOEObj
--- @param shipTree ColliderTree
--- @return table cldList
--- 获取AOE范围内的舰船碰撞列表，根据AreaType使用不同的碰撞检测方式
function BattleCldSystem.getAreaCldShipList(self, aoe, shipTree)
	local result
	local areaType = aoe:GetAreaType()

	if areaType == BattleConst.AreaType.COLUMN or aoe:GetAnchorPointAlignment() == Vector3.zero then
		-- 列形或对齐原点：使用普通box碰撞检测
		local cldBox = aoe:GetCldBox()

		result = shipTree:GetCldList(cldBox, VectorZero)
	elseif areaType == BattleConst.AreaType.ELLIPSE then
		-- 椭圆区域
		local width = aoe:GetWidth()
		local height = aoe:GetHeight()

		result = shipTree:GetCldListEllipse(width, height, pos)
	else
		-- 扇形区域
		local isFoe = aoe:GetCldData().IFF == self._foeCode
		local angle = aoe:GetAngle() * math.deg2Rad

		if isFoe then
			angle = angle + math.pi
		end

		local width = aoe:GetWidth()
		local height = aoe:GetHeight()
		local aoePos = aoe:GetPosition()

		result = shipTree:GetCldListGradient(angle, height, width, aoePos)
	end

	return result
end

--- @param aoe BattleAOEObj
--- @param cldList table
--- @return nil
--- 处理AOE与舰船/车辆的碰撞：过滤有效碰撞目标，检查潜水面过滤，附加碰撞对象
function BattleCldSystem.HandleAreaCldWithVehicle(self, aoe, cldList)
	aoe:ClearCLDList()

	local cldData = aoe:GetCldData()
	local opponentAffected = aoe:OpponentAffected()
	local cldCount = #cldList

	for i = 1, cldCount do
		local cldItem = cldList[i].data

		if cldItem.Active == true and cldItem.ImmuneCLD == false then
			local diveFilter = aoe:GetDiveFilter()
			local ship = self:GetShip(cldItem.UID)
			local canHit = true

			-- 潜水过滤：若在潜水filter中则不可命中
			if diveFilter then
				local oxyState = ship:GetCurrentOxyState()

				if table.contains(diveFilter, oxyState) then
					canHit = false
				end
			end

			if canHit and not aoe:IsOutOfAngle(ship) then
				aoe:AppendCldObj(cldItem)
			end
		end
	end
end

--- @param aoe BattleAOEObj
--- @param cldList table
--- @return nil
--- 处理AOE与飞机的碰撞：根据OpponentAffected判断是否应附加到碰撞列表
function BattleCldSystem.HandleAreaCldWithAircraft(self, aoe, cldList)
	aoe:ClearCLDList()

	local cldData = aoe:GetCldData()
	local opponentAffected = aoe:OpponentAffected()
	local cldCount = #cldList

	for i = 1, cldCount do
		local cldItem = cldList[i].data

		-- opponentAffected时，IFF不同则命中；否则IFF相同才命中
		if opponentAffected == (cldItem.IFF ~= cldData.IFF) then
			aoe:AppendCldObj(cldItem)
		end
	end
end

--- @param aoe BattleAOEObj
--- @param cldList table
--- @return nil
--- 处理AOE与子弹的碰撞：直接附加所有碰撞子弹
function BattleCldSystem.HandleAreaCldWithBullet(self, aoe, cldList)
	local cldCount = #cldList

	for i = 1, cldCount do
		local cldItem = cldList[i].data

		aoe:AppendCldObj(cldItem)
	end
end

--- @param wall BattleWallUnit
--- @return nil
--- 更新墙壁碰撞：检测与敌方子弹或敌方舰船的碰撞
function BattleCldSystem.UpdateWallCld(self, wall)
	local cldBox = wall:GetCldBox()
	local cldObjType = wall:GetCldObjType()

	if cldObjType == wall.CLD_OBJ_TYPE_BULLET then
		local bulletCldList

		-- 我方墙壁阻挡敌方子弹，敌方墙壁阻挡我方子弹
		if wall:GetIFF() == self._friendlyCode then
			bulletCldList = self._foeSurafceBulletTree:GetCldList(cldBox, VectorZero)
		else
			bulletCldList = self._surfaceBulletTree:GetCldList(cldBox, VectorZero)
		end

		self:HandleWallCldWithBullet(wall, bulletCldList)
	elseif cldObjType == wall.CLD_OBJ_TYPE_SHIP then
		local shipCldList

		if wall:GetIFF() == self._friendlyCode then
			shipCldList = self._foeShipTree:GetCldList(cldBox, VectorZero)
		else
			shipCldList = self._shipTree:GetCldList(cldBox, VectorZero)
		end

		self:HandleWllCldWithShip(wall, shipCldList)
	end
end

--- @param wall BattleWallUnit
--- @param cldList table
--- @return nil
--- 处理墙壁与子弹的碰撞：过滤BULLET类型有效碰撞，触发HandleWallHitByBullet
function BattleCldSystem.HandleWallCldWithBullet(self, wall, cldList)
	local cldCount = #cldList

	for i = 1, cldCount do
		local cldData = cldList[i].data

		if cldData.type == BattleConst.CldType.BULLET and cldData.Active == true and cldData.ImmuneCLD == false then
			local bullet = self:GetBullet(cldData.UID)

			if not self._proxy:HandleWallHitByBullet(wall, bullet) then
				return
			end
		end
	end
end

--- @param wall BattleWallUnit
--- @param cldList table
--- @return nil
--- 处理墙壁与舰船的碰撞：过滤SHIP类型有效碰撞，排除下潜潜艇，触发HandleWallHitByShip
function BattleCldSystem.HandleWllCldWithShip(self, wall, cldList)
	local cldCount = #cldList
	local shipList = {}

	for i = 1, cldCount do
		local cldData = cldList[i].data

		if cldData.type == BattleConst.CldType.SHIP and cldData.Active == true and cldData.ImmuneCLD == false then
			local ship = self:GetShip(cldData.UID)

			if ship:GetCurrentOxyState() == OxyState.DIVE then
				-- 下潜中的潜艇不碰撞墙壁
			else
				table.insert(shipList, ship)
			end
		end
	end

	self._proxy:HandleWallHitByShip(wall, shipList)
end

--- @param bulletField number 子弹战场（水面/AIR）
--- @param bullet BattleBulletUnit
--- @return nil
--- 将子弹插入对应的碰撞树（根据IFF选择友方或敌方子弹树）
function BattleCldSystem.InsertToBulletCldTree(self, bulletField, bullet)
	local tree
	local cldData = bullet:GetCldData()

	if cldData.IFF == self._foeCode then
		tree = self:GetFoeBulletTree(bulletField)
	elseif cldData.IFF == self._friendlyCode then
		tree = self:GetBulletTree(bulletField)
	end

	local cldBox = bullet:GetCldBox()

	tree:Insert(cldBox)
end

--- @param fieldType number AOE区域类型
--- @param aoe BattleAOEObj
--- @return nil
--- 将AOE插入对应的碰撞树
function BattleCldSystem.InsertToAOECldTree(self, fieldType, aoe)
	local tree = self:GetAOETree(fieldType)
	local cldBox = aoe:GetCldBox()

	tree:Insert(cldBox)
end

--- @param wall BattleWallUnit
--- @return nil
--- 将墙壁插入碰撞树
function BattleCldSystem.InsertToWallCldTree(self, wall)
	local wallTree = self:GetWallTree()
	local cldBox = wall:GetCldBox()

	wallTree:Insert(cldBox)
end

--- @param ship BattleUnit
--- @return nil
--- 将舰船插入碰撞树（根据IFF选择友方或敌方舰船树）
function BattleCldSystem.InsertToShipCldTree(self, ship)
	local cldData = ship:GetCldData()
	local shipTree

	if cldData.IFF == self._foeCode then
		shipTree = self:GetFoeShipTree()
	elseif cldData.IFF == self._friendlyCode then
		shipTree = self:GetShipTree()
	end

	local cldBox = ship:GetCldBox()

	shipTree:Insert(cldBox)
end

--- @param aircraft BattleAircraftUnit
--- @return nil
--- 将飞机插入飞机碰撞树
function BattleCldSystem.InsertToAircraftCldTree(self, aircraft)
	local cldBox = aircraft:GetCldBox()

	self._aircraftTree:Insert(cldBox)
end

--- @param bulletField number
--- @return ColliderTree
function BattleCldSystem.GetBulletTree(self, bulletField)
	return self._bulletTreeList[bulletField]
end

--- @param bulletField number
--- @return ColliderTree
function BattleCldSystem.GetFoeBulletTree(self, bulletField)
	return self._foeBulleetTreeList[bulletField]
end

--- @param fieldType number
--- @return ColliderTree
function BattleCldSystem.GetAOETree(self, fieldType)
	return self._AOETreeList[fieldType]
end

--- @param _ any unused
--- @return ColliderTree
function BattleCldSystem.GetWallTree(self, _)
	return self._wallTree
end

--- @return ColliderTree
function BattleCldSystem.GetShipTree(self)
	return self._shipTree
end

--- @return ColliderTree
function BattleCldSystem.GetFoeShipTree(self)
	return self._foeShipTree
end

--- @return ColliderTree
function BattleCldSystem.GetAircraftTree(self)
	return self._aircraftTree
end

--- @param ship BattleUnit
--- @return nil
--- 从碰撞树中删除舰船的叶子节点
function BattleCldSystem.DeleteShipLeaf(self, ship)
	local shipIFF = ship:GetCldData().IFF

	if shipIFF == self._foeCode then
		self.DeleteCldLeaf(self:GetFoeShipTree(), ship)
	elseif shipIFF == self._friendlyCode then
		self.DeleteCldLeaf(self:GetShipTree(), ship)
	end
end

--- @param bullet BattleBulletUnit
--- @return nil
--- 从碰撞树中删除子弹的叶子节点
function BattleCldSystem.DeleteBulletLeaf(self, bullet)
	local bulletIFF = bullet:GetCldData().IFF

	if bulletIFF == self._foeCode then
		self.DeleteCldLeaf(self:GetFoeBulletTree(bullet:GetEffectField()), bullet)
	elseif bulletIFF == self._friendlyCode then
		self.DeleteCldLeaf(self:GetBulletTree(bullet:GetEffectField()), bullet)
	end
end

--- @param tree ColliderTree
--- @param entity BattleUnit|BattleBulletUnit|BattleAOEObj
--- @return nil
--- 从指定碰撞树中移除实体的碰撞盒
function BattleCldSystem.DeleteCldLeaf(tree, entity)
	local cldBox = entity:GetCldBox()

	tree:Remove(cldBox)
end

--- @param uid number
--- @return BattleUnit
function BattleCldSystem.GetShip(self, uid)
	return self._proxy:GetUnitList()[uid]
end

--- @param uid number
--- @return BattleAircraftUnit
function BattleCldSystem.GetAircraft(self, uid)
	return self._proxy:GetAircraftList()[uid]
end

--- @param uid number
--- @return BattleBulletUnit
function BattleCldSystem.GetBullet(self, uid)
	return self._proxy:GetBulletList()[uid]
end

--- @param uid number
--- @return BattleAOEObj
function BattleCldSystem.GetAOE(self, uid)
	return self._proxy:GetAOEList()[uid]
end

--- @param ship BattleUnit
--- @return nil
function BattleCldSystem.InitShipCld(self, ship)
	self:InsertToShipCldTree(ship)
end

--- @param ship BattleUnit
--- @return nil
function BattleCldSystem.DeleteShipCld(self, ship)
	ship:DeactiveCldBox()
	self:DeleteShipLeaf(ship)
end

--- @param aircraft BattleAircraftUnit
--- @return nil
function BattleCldSystem.InitAircraftCld(self, aircraft)
	self:InsertToAircraftCldTree(aircraft)
end

--- @param aircraft BattleAircraftUnit
--- @return nil
function BattleCldSystem.DeleteAircraftCld(self, aircraft)
	aircraft:DeactiveCldBox()
	self.DeleteCldLeaf(self:GetAircraftTree(), aircraft)
end

--- @param bullet BattleBulletUnit
--- @return nil
function BattleCldSystem.InitBulletCld(self, bullet)
	self:InsertToBulletCldTree(bullet:GetEffectField(), bullet)
end

--- @param bullet BattleBulletUnit
--- @return nil
function BattleCldSystem.DeleteBulletCld(self, bullet)
	bullet:DeactiveCldBox()
	self:DeleteBulletLeaf(bullet)
end

--- @param bullet BattleBulletUnit
--- @return nil
--- 未实现（保留接口）
function BattleCldSystem.ShiftBulletCld(self, bullet)
	return
end

--- @param aoe BattleAOEObj
--- @return nil
function BattleCldSystem.InitAOECld(self, aoe)
	self:InsertToAOECldTree(aoe:GetFieldType(), aoe)
end

--- @param aoe BattleAOEObj
--- @return nil
function BattleCldSystem.DeleteAOECld(self, aoe)
	aoe:DeactiveCldBox()
	self.DeleteCldLeaf(self:GetAOETree(aoe:GetFieldType()), aoe)
end

--- @param wall BattleWallUnit
--- @return nil
function BattleCldSystem.InitWallCld(self, wall)
	self:InsertToWallCldTree(wall)
end

--- @param wall BattleWallUnit
--- @return nil
function BattleCldSystem.DeleteWallCld(self, wall)
	wall:DeactiveCldBox()

	local wallTree = self:GetWallTree()

	if wallTree then
		self.DeleteCldLeaf(wallTree, wall)
	end
end
