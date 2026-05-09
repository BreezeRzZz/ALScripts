ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleVariable = ys.Battle.BattleVariable
local BattleCardPuzzleEvent = ys.Battle.BattleCardPuzzleEvent
local BattleDataProxy = singletonClass("BattleDataProxy", ys.MVC.Proxy)

ys.Battle.BattleDataProxy = BattleDataProxy
BattleDataProxy.__name = "BattleDataProxy"

function BattleDataProxy.Ctor(self)
	BattleDataProxy.super.Ctor(self)
end

-- note：战斗初始化主体
-- 被BattleState.EnterBattle调用
function BattleDataProxy.InitBattle(self, battleData)
	self.Update = self.updateInit

	local battleType = battleData.battleType
	local isWorld = battleType == SYSTEM_WORLD or battleType == SYSTEM_WORLD_BOSS
	local isTest = pg.SdkMgr.GetInstance():CheckPretest() and (PlayerPrefs.GetInt("stage_scratch") or 0) == 1
	-- 设置伤害公式
	-- 这几个函数都在BattleDataProxyLogic
	self:SetupCalculateDamage(isTest and GodenFnger or BattleFormulas.CreateContextCalculateDamage(isWorld))
	self:SetupDamageKamikazeAir()
	self:SetupDamageKamikazeShip()
	self:SetupDamageCrush()
	-- 主要是摄像头相关的变量初始化
	BattleVariable.Init()
	self:InitData(battleData)
	self:DispatchEvent(ys.Event.New(BattleEvent.STAGE_DATA_INIT_FINISH))
	self._cameraUtil:Initialize()

	self._cameraTop, self._cameraBottom, self._cameraLeft, self._cameraRight = self._cameraUtil:SetMapData(self:GetTotalBounds())

	self:InitWeatherData()
	self:InitUserShipsData(self._battleInitData.MainUnitList, self._battleInitData.VanguardUnitList, BattleConfig.FRIENDLY_CODE, self._battleInitData.SubUnitList)
	self:InitUserSupportShipsData(BattleConfig.FRIENDLY_CODE, self._battleInitData.SupportUnitList)
	self:InitUserAidData()
	self:SetSubmarinAidData()
	self._cameraUtil:SetFocusFleet(self:GetFleetByIFF(BattleConfig.FRIENDLY_CODE))
	self:StatisticsInit(self._fleetList[BattleConfig.FRIENDLY_CODE]:GetUnitList())
	self:SetFlagShipID(self:GetFleetByIFF(BattleConfig.FRIENDLY_CODE):GetFlagShip())
	self:DispatchEvent(ys.Event.New(BattleEvent.COMMON_DATA_INIT_FINISH, {}))
end

function BattleDataProxy.OnCameraRatioUpdate(self)
	self._cameraTop, self._cameraBottom, self._cameraLeft, self._cameraRight = self._cameraUtil:SetMapData(self:GetTotalBounds())

	self._cameraUtil:setArrowPoint()
end

function BattleDataProxy.Start(self)
	self._startTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime()
end

-- 在BattleDataProxy.updateInit中调用
function BattleDataProxy.TriggerBattleInitBuffs(self)
	for _, fleet in pairs(self._fleetList) do
		local unitList = fleet:GetUnitList()

		fleet:FleetBuffTrigger(BattleConst.BuffEffectType.ON_INIT_GAME)
	end
end

-- 触发战斗开始Buff
function BattleDataProxy.TriggerBattleStartBuffs(self)
	for _, fleet in pairs(self._fleetList) do
		local unitList = fleet:GetUnitList()
		local scoutList = fleet:GetScoutList()
		local leader = scoutList[1]
		local rear = #scoutList > 1 and scoutList[#scoutList] or nil
		local center = #scoutList == 3 and scoutList[2] or nil
		local mainList = fleet:GetMainList()
		local flagShip = mainList[1]
		local upperConsort = mainList[2]
		local lowerConsort = mainList[3]

		for _, unit in ipairs(unitList) do
			underscore.each(self._battleInitData.ChapterBuffIDs or {}, function(buffID)
				local buff = ys.Battle.BattleBuffUnit.New(buffID)

				unit:AddBuff(buff)
			end)
			underscore.each(self._battleInitData.GlobalBuffIDs or {}, function(buffID)
				buffID = tonumber(buffID)

				local buff = ys.Battle.BattleBuffUnit.New(buffID)

				unit:AddBuff(buff)
			end)

			if self._battleInitData.MapAuraSkills then
				for _, mapAuraSkill in ipairs(self._battleInitData.MapAuraSkills) do
					local buff = ys.Battle.BattleBuffUnit.New(mapAuraSkill.id, mapAuraSkill.level)

					unit:AddBuff(buff)
				end
			end

			if self._battleInitData.MapAidSkills then
				for _, mapAidSkill in ipairs(self._battleInitData.MapAidSkills) do
					local buff = ys.Battle.BattleBuffUnit.New(mapAidSkill.id, mapAidSkill.level)

					unit:AddBuff(buff)
				end
			end

			if self._currentStageData.stageBuff then
				for _, stageBuffItem in ipairs(self._currentStageData.stageBuff) do
					local buff = ys.Battle.BattleBuffUnit.New(stageBuffItem.id, stageBuffItem.level)

					unit:AddBuff(buff)
				end
			end
			-- 此处为onStartGame Trigger的BuffEffect的唯一触发点
			unit:TriggerBuff(BattleConst.BuffEffectType.ON_START_GAME)

			if unit == flagShip then
				unit:TriggerBuff(BattleConst.BuffEffectType.ON_FLAG_SHIP)
			elseif unit == upperConsort then
				unit:TriggerBuff(BattleConst.BuffEffectType.ON_UPPER_CONSORT)
			elseif unit == lowerConsort then
				unit:TriggerBuff(BattleConst.BuffEffectType.ON_LOWER_CONSORT)
			elseif unit == leader then
				unit:TriggerBuff(BattleConst.BuffEffectType.ON_LEADER)
			elseif unit == center then
				unit:TriggerBuff(BattleConst.BuffEffectType.ON_CENTER)
			elseif unit == rear then
				unit:TriggerBuff(BattleConst.BuffEffectType.ON_REAR)
			end
		end

		local supportUnitList = fleet:GetSupportUnitList()

		for _, supportUnit in ipairs(supportUnitList) do
			underscore.each(self._battleInitData.ChapterBuffIDs or {}, function(buffID)
				local strategyBuff = BattleDataFunction.GetSLGStrategyBuffByCombatBuffID(buffID)

				if strategyBuff and strategyBuff.type == ChapterConst.AirDominanceStrategyBuffType then
					local buff = ys.Battle.BattleBuffUnit.New(buffID)

					supportUnit:AddBuff(buff)
				end
			end)
		end
	end
end

-- BattleSingleDungeonCommand.DoPrologue调用
function BattleDataProxy.InitAllFleetUnitsWeaponCD(self)
	for _, fleet in pairs(self._fleetList) do
		local unitList = fleet:GetUnitList()

		for _, unit in ipairs(unitList) do
			BattleDataProxy.InitUnitWeaponCD(unit)
		end
	end
end

-- 这是一个静态函数，参数是一个BattleUnit对象
function BattleDataProxy.InitUnitWeaponCD(unit)
	unit:CheckWeaponInitial()
end

function BattleDataProxy.StartCardPuzzle(self)
	for _, fleet in pairs(self._fleetList) do
		fleet:GetCardPuzzleComponent():Start()
	end
end

function BattleDataProxy.PausePuzzleComponent(self)
	for _, fleet in pairs(self._fleetList) do
		local cardPuzzleComponent = fleet:GetCardPuzzleComponent()

		if cardPuzzleComponent then
			cardPuzzleComponent:BlockComponentByCard(true)
		end
	end
end

function BattleDataProxy.ResumePuzzleComponent(self)
	onDelayTick(function()
		for _, fleet in pairs(self._fleetList) do
			local cardPuzzleComponent = fleet:GetCardPuzzleComponent()

			if cardPuzzleComponent then
				cardPuzzleComponent:BlockComponentByCard(false)
			end
		end
	end, 0.06)
end

function BattleDataProxy.GetInitData(self)
	return self._battleInitData
end

function BattleDataProxy.GetDungeonData(self)
	return self._dungeonInfo
end

-- note: 战斗初始化，数据结构搭建
function BattleDataProxy.InitData(self, battleData)
	self.FrameIndex = 1
	self._friendlyCode = 1
	self._foeCode = -1
	BattleConst.FRIENDLY_CODE = 1
	BattleConst.FOE_CODE = -1
	self._completelyRepress = false
	self._repressReduce = 1
	self._repressLevel = 0
	self._repressEnemyHpRant = 1
	self._friendlyShipList = {}
	self._foeShipList = {}
	self._friendlyAircraftList = {}
	self._foeAircraftList = {}
	self._minionShipList = {}
	self._spectreShipList = {}
	self._fleetList = {}
	self._freeShipList = {}
	self._teamList = {}
	self._waveSummonList = {}
	self._aidUnitList = {}
	self._unitList = {}
	self._unitCount = 0
	self._bulletList = {}
	self._bulletCount = 0
	self._aircraftList = {}
	self._aircraftCount = 0
	self._AOEList = {}
	self._AOECount = 0
	self._wallList = {}
	self._wallIndex = 0
	self._shelterList = {}
	self._shelterIndex = 0
	self._environmentList = {}
	self._environmentIndex = 0
	self._deadUnitList = {}
	self._enemySubmarineCount = 0
	self._airFighterList = {}
	self._currentStageIndex = 1
	self._battleInitData = battleData
	self._expeditionID = battleData.StageTmpId
	self._expeditionTmp = pg.expedition_data_template[self._expeditionID]

	self:SetDungeonLevel(battleData.WorldLevel or self._expeditionTmp.level)

	self._dungeonID = self._expeditionTmp.dungeon_id
	self._dungeonInfo = BattleDataFunction.GetDungeonTmpDataByID(self._dungeonID)
	-- map指的是战斗中后面的背景
	if battleData.WorldMapId then
		self._mapId = battleData.WorldMapId
	elseif self._expeditionTmp.map_id then
		local map_id = self._expeditionTmp.map_id

		if #map_id == 1 then
			self._mapId = map_id[1][1]
		else
			local mapPool = {}

			for _, mapInfo in ipairs(map_id) do
				local weight = mapInfo[2] * 100

				table.insert(mapPool, {
					rst = mapInfo[1],
					weight = weight
				})
			end

			self._mapId = BattleFormulas.WeightRandom(mapPool)
		end
	end
	-- expedition相关数据
	self._weahter = battleData.ChapterWeatherIDS or {}
	self._exposeSpeed = self._expeditionTmp.expose_speed
	-- 用于BattleDataProxy.HandleAircraftMissDamage，为舰载机撞线的暴露值
	self._airExpose = self._expeditionTmp.aircraft_expose[1]
	-- 如果最近的单位是轻母/航母/导驱M，这个单位的额外暴露值
	self._airExposeEX = self._expeditionTmp.aircraft_expose[2]
	-- 用于BattleDataProxy.HandleShipMissDamage，为舰船撞线的暴露值
	self._shipExpose = self._expeditionTmp.ship_expose[1]
	self._shipExposeEX = self._expeditionTmp.ship_expose[2]
	-- 指挥喵相关数据
	self._commander = battleData.CommanderList or {}
	self._subCommander = battleData.SubCommanderList or {}
	self._commanderBuff = self.initCommanderBuff(self._commander)
	self._subCommanderBuff = self.initCommanderBuff(self._subCommander)

	if self._battleInitData.RepressInfo then
		local repressInfo = self._battleInitData.RepressInfo
		-- SCENARIO指的就是章节战斗
		if self._battleInitData.battleType == SYSTEM_SCENARIO then
			if repressInfo.repressCount >= repressInfo.repressMax then
				self._completelyRepress = true
			end

			self._repressReduce = BattleFormulas.ChapterRepressReduce(repressInfo.repressReduce)
			self._repressLevel = repressInfo.repressLevel
			self._repressEnemyHpRant = repressInfo.repressEnemyHpRant
		elseif self._battleInitData.battleType == SYSTEM_WORLD or self._battleInitData.battleType == SYSTEM_WORLD_BOSS then
			self._repressEnemyHpRant = repressInfo.repressEnemyHpRant
		end
	end
	-- 连胜（实际是战斗次数），用来一些与战斗次数相关的技能
	self._chapterWinningStreak = self._battleInitData.DefeatCount or 0
	self._waveFlags = table.shallowCopy(battleData.StageWaveFlags) or {}

	self:InitStageData()

	self._cldSystem = ys.Battle.BattleCldSystem.New(self)
	self._cameraUtil = ys.Battle.BattleCameraUtil.GetInstance()

	self:initBGM()
end

-- BattleDataProxy.InitData中调用，主要是为了根据舰船数据生成bgm列表
function BattleDataProxy.initBGM(self)
	self._initBGMList = {}
	self._otherBGMList = {}

	local initList = {}
	local otherList = {}

	local function getSongList(unitList)
		for _, unitData in ipairs(unitList) do
			local buffIDList = {}

			if unitData.skills then
				for _, buffID in ipairs(unitData.skills) do
					table.insert(buffIDList, buffID)
				end
			end

			if unitData.equipment then
				local equipBuffIDList = BattleDataFunction.GetEquipSkill(unitData.equipment, self._battleInitData.battleType)

				for _, equipBuffID in ipairs(equipBuffIDList) do
					buffIDList[equipBuffID.buffID] = {
						id = equipBuffID.buffID,
						level = equipBuffID.buffLV
					}
				end
			end

			local songList = BattleDataFunction.GetSongList(buffIDList)

			for bgm, _ in pairs(songList.initList) do
				initList[bgm] = true
			end

			for bgm, _ in pairs(songList.otherList) do
				otherList[bgm] = true
			end
		end
	end

	getSongList(self._battleInitData.MainUnitList)
	getSongList(self._battleInitData.VanguardUnitList)
	getSongList(self._battleInitData.SubUnitList)

	if self._battleInitData.RivalMainUnitList then
		getSongList(self._battleInitData.RivalMainUnitList)
	end

	if self._battleInitData.RivalVanguardUnitList then
		getSongList(self._battleInitData.RivalVanguardUnitList)
	end

	for bgm, _ in pairs(initList) do
		table.insert(self._initBGMList, bgm)
	end

	for bgm, _ in pairs(otherList) do
		table.insert(self._otherBGMList, bgm)
	end
end

function BattleDataProxy.initCommanderBuff(buffInfoList)
	local commanderBuffList = {}

	for _, buffInfo in ipairs(buffInfoList) do
		local commander = buffInfo[1]
		local level = commander:getSkills()[1]:getLevel()

		for _, buffID in ipairs(buffInfo[2]) do
			table.insert(commanderBuffList, {
				id = buffID,
				level = level,
				commander = commander
			})
		end
	end

	return commanderBuffList
end

function BattleDataProxy.Clear(self)
	-- 清空队伍
	for _, team in pairs(self._teamList) do
		self:KillNPCTeam(team)
	end

	self._teamList = nil

	-- 清空子弹实体
	for bullet, _ in pairs(self._bulletList) do
		self:RemoveBulletUnit(bullet)
	end

	self._bulletList = nil

	-- 清空单位
	for unit, _ in pairs(self._unitList) do
		self:KillUnit(unit)
	end

	self._unitList = nil

	for _, deadUnit in ipairs(self._deadUnitList) do
		deadUnit:Dispose()
	end

	self._deadUnitList = nil

	for _, aircraft in pairs(self._aircraftList) do
		self:KillAircraft(aircraft)
	end

	self._aircraftList = nil

	for _, fleet in pairs(self._fleetList) do
		fleet:Dispose()
	end

	self._fleetList = nil

	for _, aidUnit in pairs(self._aidUnitList) do
		aidUnit:Dispose()
	end

	self._aidUnitList = nil

	for _, environment in pairs(self._environmentList) do
		self:RemoveEnvironment(environment:GetUniqueID())
	end

	self._environmentList = nil

	for AOE, _ in pairs(self._AOEList) do
		self:RemoveAreaOfEffect(AOE)
	end

	self._AOEList = nil

	self._cldSystem:Dispose()

	self._cldSystem = nil
	self._dungeonInfo = nil
	self._flagShipUnit = nil
	self._friendlyShipList = nil
	self._foeShipList = nil
	self._spectreShipList = nil
	self._friendlyAircraftList = nil
	self._foeAircraftList = nil
	self._fleetList = nil
	self._freeShipList = nil
	self._countDown = nil
	self._lastUpdateTime = nil
	self._statistics = nil
	self._battleInitData = nil
	self._currentStageData = nil

	self:ClearFormulas()
	BattleDataFunction.ClearDungeonCfg(self._dungeonID)
end

function BattleDataProxy.DeactiveProxy(self)
	self._state = nil

	self:Clear()
	ys.Battle.BattleDataProxy.super.DeactiveProxy(self)
end

-- note: 战斗初始化，生成我方舰船数据结构
-- 在演习和模拟战中，还会用来生成对手舰船数据结构
-- 被BattleDataProxy.InitBattle调用
function BattleDataProxy.InitUserShipsData(self, mainUnitList, vanguardUnitList, IFF, subUnitList)
	for _, vanguardData in ipairs(vanguardUnitList) do
		local vanguardUnit = self:SpawnVanguard(vanguardData, IFF)
	end

	for _, mainUnitData in ipairs(mainUnitList) do
		local mainUnit = self:SpawnMain(mainUnitData, IFF)
	end

	local fleet = self:GetFleetByIFF(IFF)

	fleet:FleetUnitSpwanFinish()

	local battleType = self._battleInitData.battleType

	if battleType == SYSTEM_SUBMARINE_RUN or battleType == SYSTEM_SUB_ROUTINE then
		for _, subUnitData in ipairs(subUnitList) do
			self:SpawnManualSub(subUnitData, IFF)
		end
		-- 切换为操作潜艇模式
		fleet:ShiftManualSub()
	else
		fleet:SetSubUnitData(subUnitList)
	end
	-- 演习的隐匿值不回复
	if self._battleInitData.battleType == SYSTEM_DUEL then
		for _, cloakUnit in ipairs(fleet:GetCloakList()) do
			cloakUnit:GetCloak():SetRecoverySpeed(0)
		end
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_FLEET, {
		fleetVO = fleet
	}))
end

-- 被BattleDataProxy.InitBattle调用
function BattleDataProxy.InitUserSupportShipsData(self, IFF, supportUnitList)
	local fleet = self:GetFleetByIFF(IFF)

	for _, supportUnitData in ipairs(supportUnitList) do
		local supportUnit = self:SpawnSupportUnit(supportUnitData, IFF)
	end
end

-- BattleTargetChoise.TargetPlayerAidUnit会使用
-- 被BattleDataProxy.InitBattle调用
function BattleDataProxy.InitUserAidData(self)
	for _, aidUnit in ipairs(self._battleInitData.AidUnitList) do
		local aidUnitUID = self:GenerateUnitID()
		-- properties大致来自于Ship.getProperties, 也即计算战斗外属性的部分
		-- 包含的内容只有Ship.PROPERTIES的12项属性
		local templateData = aidUnit.properties
		-- 除此之外，还使用援助者的level
		templateData.level = aidUnit.level
		templateData.formationID = BattleConfig.FORMATION_ID
		templateData.id = aidUnit.id

		BattleFormulas.AttrFixer(self._battleInitData.battleType, templateData)
		-- 效率没什么用，跨队武器不会用到(因为都是技能武器，对不上槽位)，一般都是1
		local proficiencyList = aidUnit.proficiency or {
			1,
			1,
			1
		}
		local aidBattleUnit = BattleDataFunction.CreateBattleUnitData(aidUnitUID, BattleConst.UnitType.PLAYER_UNIT, BattleConfig.FRIENDLY_CODE, aidUnit.tmpID, aidUnit.skinId, aidUnit.equipment, templateData, aidUnit.baseProperties, proficiencyList, aidUnit.baseList, aidUnit.preloasList)

		self._aidUnitList[aidBattleUnit:GetUniqueID()] = aidBattleUnit
	end
end
-- 潜艇的跨队支援还不太一样
--- 设置潜艇跨队支援数据
function BattleDataProxy.SetSubmarinAidData(self)
	self:GetFleetByIFF(BattleConfig.FRIENDLY_CODE):SetSubAidData(self._battleInitData.TotalSubAmmo, self._battleInitData.SubFlag)
end

--- 天气 Weather 相关 ---

--- @param weather number 天气类型/ID
function BattleDataProxy.AddWeather(self, weather)
	table.insert(self._weahter, weather)
	self:InitWeatherData()
end

function BattleDataProxy.InitWeatherData(self)
	for _, weather in ipairs(self._weahter) do
		-- 目前其实只有一种天气: 夜战
		if weather == BattleConst.WEATHER.NIGHT then
			for _, fleet in pairs(self._fleetList) do
				fleet:AttachNightCloak()
			end

			for _, unit in pairs(self._unitList) do
				BattleDataFunction.AttachWeather(unit, self._weahter)
			end
		end
	end
end

-- BattleState.BattleEnd中调用
function BattleDataProxy.CelebrateVictory(self, IFF)
	local shipList

	if IFF == self:GetFoeCode() then
		shipList = self._foeShipList
	else
		shipList = self._friendlyShipList
	end
	-- 播放对应的胜利动画
	for _, ship in pairs(shipList) do
		ship:StateChange(ys.Battle.UnitState.STATE_VICTORY)
	end
end

-- 初始化关卡数据，主要是边界相关
function BattleDataProxy.InitStageData(self)
	self._currentStageData = self._dungeonInfo.stages[self._currentStageIndex]
	self._countDown = self._currentStageData.timeCount

	local totalArea = self._currentStageData.totalArea

	self._totalLeftBound = totalArea[1]
	self._totalRightBound = totalArea[1] + totalArea[3]
	self._totalUpperBound = totalArea[2] + totalArea[4]
	self._totalLowerBound = totalArea[2]

	local playerArea = self._currentStageData.playerArea

	self._leftZoneLeftBound = playerArea[1]
	self._leftZoneRightBound = playerArea[1] + playerArea[3]
	self._leftZoneUpperBound = playerArea[2] + playerArea[4]
	self._leftZoneLowerBound = playerArea[2]
	self._rightZoneLeftBound = self._leftZoneRightBound
	self._rightZoneRightBound = self._totalRightBound
	self._rightZoneUpperBound = self._leftZoneUpperBound
	self._rightZoneLowerBound = self._leftZoneLowerBound
	self._bulletUpperBound = self._totalUpperBound + 3
	self._bulletLowerBound = self._totalLowerBound - 10
	self._bulletLeftBound = self._totalLeftBound - 10
	self._bulletRightBound = self._totalRightBound + 10
	-- BULLET_UPPER_BOUND_VISION_OFFSET = 30
	self._bulletUpperBoundVision = self._totalUpperBound + BattleConfig.BULLET_UPPER_BOUND_VISION_OFFSET
	-- BULLET_LOWER_BOUND_SPLIT_OFFSET = 8
	-- bulletLowerBoundSplit = totalLowerBound - 2
	self._bulletLowerBoundSplit = self._bulletLowerBound + BattleConfig.BULLET_LOWER_BOUND_SPLIT_OFFSET
	-- BULLET_LEFT_BOUND_SPLIT_OFFSET = 8
	-- bulletLeftBoundSplit = totalLeftBound - 2
	self._bulletLeftBoundSplit = self._bulletLeftBound + BattleConfig.BULLET_LEFT_BOUND_SPLIT_OFFSET

	if self._battleInitData.battleType == SYSTEM_DUEL then
		self._leftFieldBound = self._totalLeftBound
		self._rightFieldBound = self._totalRightBound
	else
		local mainUnitPositionX

		if self._currentStageData.mainUnitPosition and self._currentStageData.mainUnitPosition[BattleConfig.FRIENDLY_CODE] then
			mainUnitPositionX = self._currentStageData.mainUnitPosition[BattleConfig.FRIENDLY_CODE][1].x
		else
			mainUnitPositionX = BattleConfig.MAIN_UNIT_POS[BattleConfig.FRIENDLY_CODE][1].x
		end

		self._leftFieldBound = mainUnitPositionX - 1
		-- FIELD_LEFT_BOUND_BIAS = 0
		self._rightFieldBound = self._totalRightBound + BattleConfig.FIELD_RIGHT_BOUND_BIAS
	end
end

-- 获取先锋出生坐标
-- 被BattleDataProxy.SpawnVanguard调用
function BattleDataProxy.GetVanguardBornCoordinate(self, IFF)
	if IFF == BattleConfig.FRIENDLY_CODE then
		return self._currentStageData.fleetCorrdinate
	elseif IFF == BattleConfig.FOE_CODE then
		return self._currentStageData.rivalCorrdinate
	end
end

function BattleDataProxy.GetTotalBounds(self)
	return self._totalUpperBound, self._totalLowerBound, self._totalLeftBound, self._totalRightBound
end

function BattleDataProxy.GetTotalRightBound(self)
	return self._totalRightBound
end

function BattleDataProxy.GetTotalLowerBound(self)
	return self._totalLowerBound
end

function BattleDataProxy.GetUnitBoundByIFF(self, IFF)
	if IFF == BattleConfig.FRIENDLY_CODE then
		return self._leftZoneUpperBound, self._leftZoneLowerBound, self._leftZoneLeftBound, BattleConfig.MaxRight, BattleConfig.MaxLeft, self._leftZoneRightBound
	elseif IFF == BattleConfig.FOE_CODE then
		return self._rightZoneUpperBound, self._rightZoneLowerBound, self._rightZoneLeftBound, self._rightZoneRightBound, self._rightZoneLeftBound, BattleConfig.MaxRight
	end
end

function BattleDataProxy.GetFleetBoundByIFF(self, IFF)
	if IFF == BattleConfig.FRIENDLY_CODE then
		return self._leftZoneUpperBound, self._leftZoneLowerBound, self._leftZoneLeftBound, self._leftZoneRightBound
	elseif IFF == BattleConfig.FOE_CODE then
		return self._rightZoneUpperBound, self._rightZoneLowerBound, self._rightZoneLeftBound, self._rightZoneRightBound
	end
end

function BattleDataProxy.ShiftFleetBound(self, fleet, IFF)
	fleet:GetUnitBound():SwtichDuelAggressive()
	fleet:SetAutobotBound(self:GetFleetBoundByIFF(IFF))
	fleet:UpdateScoutUnitBound()
end

function BattleDataProxy.GetFieldBound(self)
	if self._battleInitData and self._battleInitData.battleType == SYSTEM_DUEL then
		return self:GetTotalBounds()
	else
		return self._totalUpperBound, self._totalLowerBound, self._leftFieldBound, self._rightFieldBound
	end
end

-- note: 舰队初始化
function BattleDataProxy.GetFleetByIFF(self, IFF)
	if self._fleetList[IFF] == nil then
		local fleet = ys.Battle.BattleFleetVO.New(IFF)

		self._fleetList[IFF] = fleet
		-- fleet初始化设置的内容
		fleet:SetAutobotBound(self:GetFleetBoundByIFF(IFF))
		fleet:SetTotalBound(self:GetTotalBounds())
		fleet:SetUnitBound(self._currentStageData.totalArea, self._currentStageData.playerArea)
		fleet:SetExposeLine(self._expeditionTmp.horizon_line[IFF], self._expeditionTmp.expose_line[IFF])
		fleet:CalcSubmarineBaseLine(self._battleInitData.battleType)
		fleet:SetChapterPlayType(self._battleInitData.ChapterType)

		if self._battleInitData.battleType == SYSTEM_CARDPUZZLE then
			local cardPuzzleComponent = fleet:AttachCardPuzzleComponent()
			local cardPuzzleData = {
				cardList = self._battleInitData.CardPuzzleCardIDList,
				commonHP = self._battleInitData.CardPuzzleCommonHPValue,
				relicList = self._battleInitData.CardPuzzleRelicList
			}

			cardPuzzleComponent:InitCardPuzzleData(cardPuzzleData)
			cardPuzzleComponent:CustomConfigID(self._battleInitData.CardPuzzleCombatID)
			self:DispatchEvent(ys.Event.New(BattleCardPuzzleEvent.CARD_PUZZLE_INIT))
		end
	end

	return self._fleetList[IFF]
end

function BattleDataProxy.GetAidUnit(self)
	return self._aidUnitList
end

function BattleDataProxy.GetFleetList(self)
	return self._fleetList
end

function BattleDataProxy.GetEnemySubmarineCount(self)
	return self._enemySubmarineCount
end

function BattleDataProxy.GetCommander(self)
	return self._commander
end

function BattleDataProxy.GetCommanderBuff(self)
	return self._commanderBuff, self._subCommanderBuff
end

function BattleDataProxy.GetStageInfo(self)
	return self._currentStageData
end

function BattleDataProxy.GetWinningStreak(self)
	return self._chapterWinningStreak
end

-- 被BattleBuffDiva.onXXX调用
function BattleDataProxy.GetBGMList(self, isOther)
	if not isOther then
		return self._initBGMList
	else
		return self._otherBGMList
	end
end

function BattleDataProxy.GetDungeonLevel(self)
	return self._dungeonLevel
end

function BattleDataProxy.SetDungeonLevel(self, level)
	self._dungeonLevel = level
end

function BattleDataProxy.IsCompletelyRepress(self)
	return self._completelyRepress
end

function BattleDataProxy.GetRepressReduce(self)
	return self._repressReduce
end

function BattleDataProxy.GetRepressLevel(self)
	return self._repressLevel
end

function BattleDataProxy.updateInit(self, timeStamp)
	self:TriggerBattleInitBuffs()

	self.checkCld = true

	self:updateLoop(timeStamp)

	self.Update = self.updateLoop
end

-- note: 核心的每帧更新函数
function BattleDataProxy.updateLoop(self, timeStamp)
	self.FrameIndex = self.FrameIndex + 1

	self:updateDeadList()
	self:UpdateCountDown(timeStamp)
	self:UpdateWeather(timeStamp)

	for _, fleet in pairs(self._fleetList) do
		fleet:UpdateMotion()
	end
	-- checkCld每帧取反，达到交替更新碰撞树的效果
	-- 也就是每2帧才判定一次碰撞
	self.checkCld = not self.checkCld

	-- 记录每帧的最大(对于敌方，指的是最左；对于友方，指的是最右)x位置，用于隐匿系统的判定
	local maxPosXFrame = {
		[BattleConfig.FRIENDLY_CODE] = self._totalLeftBound,
		[BattleConfig.FOE_CODE] = self._totalRightBound
	}
	-- 以下处理隐匿系统的更新、碰撞检测
	for _, unit in pairs(self._unitList) do
		if unit:IsSpectre() then
			-- FUSION_ELEMENT_UNIT_TYPE = -10000
			if unit:GetAttrByName(ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY) <= BattleConfig.FUSION_ELEMENT_UNIT_TYPE then
				-- block empty
			else
				unit:Update(timeStamp)
			end
		else
			if self.checkCld then
				self._cldSystem:UpdateShipCldTree(unit)
			end

			if unit:IsAlive() then
				unit:Update(timeStamp)
			end

			local positionX = unit:GetPosition().x
			local IFF = unit:GetIFF()

			if IFF == BattleConfig.FRIENDLY_CODE then
				maxPosXFrame[IFF] = math.max(maxPosXFrame[IFF], positionX)
			elseif IFF == BattleConfig.FOE_CODE then
				maxPosXFrame[IFF] = math.min(maxPosXFrame[IFF], positionX)
			end
		end
	end
	--- @type BattleFleetVO
	local playerFleet = self._fleetList[BattleConfig.FRIENDLY_CODE]
	local playerExposeLine = playerFleet:GetFleetExposeLine()
	local playerVisionLine = playerFleet:GetFleetVisionLine()
	local enemyMaxPosX = maxPosXFrame[BattleConfig.FOE_CODE]

	if playerExposeLine and enemyMaxPosX < playerExposeLine then
		playerFleet:CloakFatalExpose()
	elseif enemyMaxPosX < playerVisionLine then
		playerFleet:CloakInVision(self._exposeSpeed)
	else
		playerFleet:CloakOutVision()
	end

	if self._fleetList[BattleConfig.FOE_CODE] then
		local enemyFleet = self._fleetList[BattleConfig.FOE_CODE]
		local enemyExposeLine = enemyFleet:GetFleetExposeLine()
		local enemyVisionLine = enemyFleet:GetFleetVisionLine()
		local friendlyMaxPosX = maxPosXFrame[BattleConfig.FRIENDLY_CODE]

		if enemyExposeLine and enemyExposeLine < friendlyMaxPosX then
			enemyFleet:CloakFatalExpose()
		elseif enemyVisionLine < friendlyMaxPosX then
			enemyFleet:CloakInVision(self._exposeSpeed)
		else
			enemyFleet:CloakOutVision()
		end
	end
	-- 以下处理子弹
	for _, bullet in pairs(self._bulletList) do
		local bulletSpeed = bullet:GetSpeed()
		local bulletPosition = bullet:GetPosition()
		local bulletType = bullet:GetType()
		local bulletOutBoundType = bullet:GetOutBound()
		-- 对于Shrapnel类型的子弹的出界判定
		-- 实际来说没什么用，这些位置都是在屏幕外的，实际怎么分裂要找对应的子弹类看
		if bulletOutBoundType == BattleConst.BulletOutBound.SPLIT and bulletType == BattleConst.BulletType.SHRAPNEL and (bulletPosition.x > self._bulletRightBound and bulletSpeed.x > 0 or bulletPosition.x < self._bulletLeftBoundSplit and bulletSpeed.x < 0 or bulletPosition.z > self._bulletUpperBound and bulletSpeed.z > 0 or bulletPosition.z < self._bulletLowerBoundSplit and bulletSpeed.z < 0) then
			if bullet:GetExist() then
				bullet:OutRange()
			else
				self:RemoveBulletUnit(bullet:GetUniqueID())
			end
		-- 对于普通子弹的出界判定
		-- 基本也没用，都是屏幕外的位置
		elseif (bulletOutBoundType == BattleConst.BulletOutBound.COMMON or bulletOutBoundType == BattleConst.BulletOutBound.SHIFT_SPLIT) and (bulletPosition.x > self._bulletRightBound and bulletSpeed.x > 0 or bulletPosition.z < self._bulletLowerBound and bulletSpeed.z < 0) then
			self:RemoveBulletUnit(bullet:GetUniqueID())
		-- 对随机出界类型，对友军随机主力造成伤害
		elseif bulletPosition.x < self._bulletLeftBound and bulletSpeed.x < 0 and bulletType ~= BattleConst.BulletType.BOMB then
			if bulletOutBoundType == BattleConst.BulletOutBound.RANDOM then
				local victim = self._fleetList[BattleConfig.FRIENDLY_CODE]:RandomMainVictim()

				if victim then
					self:HandleDamage(bullet, victim)
				end
			end

			self:RemoveBulletUnit(bullet:GetUniqueID())
		else
			bullet:Update(timeStamp)
			-- 只有Shrapnel类型的子弹才有状态
			local bulletState = bullet.GetCurrentState and bullet:GetCurrentState() or nil

			if bulletState == ys.Battle.BattleShrapnelBulletUnit.STATE_FINAL_SPLIT then
				-- block empty
			elseif bulletState == ys.Battle.BattleShrapnelBulletUnit.STATE_SPLIT and not bullet:IsFragile() then
				-- block empty
			elseif (bulletOutBoundType == BattleConst.BulletOutBound.COMMON or bulletOutBoundType == BattleConst.BulletOutBound.SHIFT_SPLIT) and bulletPosition.z > self._bulletUpperBound and bulletSpeed.z > 0 or bulletOutBoundType == BattleConst.BulletOutBound.VISION and bulletPosition.z > self._bulletUpperBoundVision and bulletSpeed.z > 0 or bullet:IsOutRange(timeStamp) then
				if bullet:GetExist() then
					bullet:OutRange()
				else
					self:RemoveBulletUnit(bullet:GetUniqueID())
				end
			elseif self.checkCld then
				self._cldSystem:UpdateBulletCld(bullet)
			end
		end
	end
	-- 以下处理舰载机
	for _, aircraft in pairs(self._aircraftList) do
		aircraft:Update(timeStamp)
		-- 只返回1个值，因此aircraftBound初始是nil，相当于只是顺便声明了aircraftBound变量
		local aircraftIFF, aircraftBound = aircraft:GetIFF()

		if aircraftIFF == BattleConfig.FRIENDLY_CODE then
			aircraftBound = self._totalRightBound
		elseif aircraftIFF == BattleConfig.FOE_CODE then
			aircraftBound = self._totalLeftBound
		end
		-- 舰载机的出界判定
		if aircraft:GetPosition().x * aircraftIFF > math.abs(aircraftBound) and aircraft:GetSpeed().x * aircraftIFF > 0 then
			aircraft:OutBound()
		else
			self._cldSystem:UpdateAircraftCld(aircraft)
		end

		if not aircraft:IsAlive() then
			self:KillAircraft(aircraft:GetUniqueID())
		end
	end
	-- 以下更新AOE（区域效果）
	-- 例如照明弹等
	for _, aoe in pairs(self._AOEList) do
		self._cldSystem:UpdateAOECld(aoe)
		-- Settle是AOE每帧更新的函数（相当于Update）
		aoe:Settle()

		if aoe:GetActiveFlag() == false then
			aoe:SettleFinale()
			self:RemoveAreaOfEffect(aoe:GetUniqueID())
		end
	end
	-- 以下更新环境效果
	-- 例如灯塔效果
	for _, environment in pairs(self._environmentList) do
		environment:Update()

		if environment:IsExpire(timeStamp) then
			self:RemoveEnvironment(environment:GetUniqueID())
		end
	end
	-- 以下处理Shelter和Wall效果
		-- Shelter 对应 BattleSkillProjectShelter
		-- Wall 对应 BattleBuffShieldWall
	-- 注意SheildWall与耐久护盾(Shield)不同，护盾墙是场景元素
	if self.checkCld then
		for _, shelter in pairs(self._shelterList) do
			if not shelter:IsWallActive() then
				self:RemoveShelter(shelter:GetUniqueID())
			else
				shelter:Update(timeStamp)
			end
		end

		for _, wall in pairs(self._wallList) do
			if wall:IsActive() then
				self._cldSystem:UpdateWallCld(wall)
			end
		end
	end
	-- 处理敌方出界行为
	if self._battleInitData.battleType ~= SYSTEM_DUEL then
		for _, foeShip in pairs(self._foeShipList) do
			if foeShip:GetPosition().x + foeShip:GetBoxSize().x < self._leftZoneLeftBound then
				foeShip:SetDeathReason(BattleConst.UnitDeathReason.TOUCHDOWN)
				foeShip:DeadAction()
				self:KillUnit(foeShip:GetUniqueID())
				self:HandleShipMissDamage(foeShip, self._fleetList[BattleConfig.FRIENDLY_CODE])
			end
		end
	end
end

-- note: 自律组件更新
-- 在Facade.aiUpdate中调用
function BattleDataProxy.UpdateAutoComponent(self, timeStamp)
	for _, fleet in pairs(self._fleetList) do
		-- 对应fleetVO的UpdateAutoComponent
		fleet:UpdateAutoComponent(timeStamp)
	end
	-- team: BattleTeamVO
	-- 比如，前排被当作一个整体移动，每个单体的移动由team来控制
	-- 死掉一个team成员时，team会处理剩余成员的移动
	for teamID, team in pairs(self._teamList) do
		if team:IsFatalDamage() then
			self:KillNPCTeam(teamID)
		else
			team:UpdateMotion()
		end
	end
	-- 指的是潜艇和风帆S，他们属于freeShip
	for _, freeShip in pairs(self._freeShipList) do
		freeShip:UpdateOxygen(timeStamp)
		freeShip:UpdateWeapon(timeStamp)
		freeShip:UpdatePhaseSwitcher()
	end
end

-- 如夜战天气等的更新
-- BattleDataProxy.updateLoop调用
function BattleDataProxy.UpdateWeather(self, timeStamp)
	for _, weather in ipairs(self._weahter) do
		if weather == BattleConst.WEATHER.NIGHT then
			local divingDecayFactor = {
				[BattleConfig.FRIENDLY_CODE] = 0,
				[BattleConfig.FOE_CODE] = 0
			}
			local normalDecayFactor = {
				[BattleConfig.FRIENDLY_CODE] = 0,
				[BattleConfig.FOE_CODE] = 0
			}
			local extraDecaySpeed = {
				[BattleConfig.FRIENDLY_CODE] = 0,
				[BattleConfig.FOE_CODE] = 0
			}
			-- 1. 计算场上所有单位的Decay Factor(只记录). 包括友方和敌方
			for _, unit in pairs(self._unitList) do
				local aimBias = unit:GetAimBias()

				if not aimBias or aimBias:GetCurrentState() ~= aimBias.STATE_SUMMON_SICKNESS then
					local unitIFF = unit:GetIFF()
					local maxNormalDecayFactor = normalDecayFactor[unitIFF]
					local attackRating = BattleAttr.GetCurrent(unit, "attackRating")
					local aimBiasExtraACC = BattleAttr.GetCurrent(unit, "aimBiasExtraACC")
					-- 实质就是取命中的最大值作为(对手的)Decay Factor
					normalDecayFactor[unitIFF] = math.max(maxNormalDecayFactor, attackRating)
					extraDecaySpeed[unitIFF] = extraDecaySpeed[unitIFF] + aimBiasExtraACC

					-- 驱逐/轻巡/导驱V
					if ShipType.ContainInLimitBundle(ShipType.BundleAntiSubmarine, unit:GetTemplate().type) then
						divingDecayFactor[unitIFF] = math.max(divingDecayFactor[unitIFF], attackRating)
					end
				end
			end
			-- 2. 实际将Decay Factor用到两方的Aim Bias上(SetDecayFactor)
			for fleetIFF, fleet in pairs(self._fleetList) do
				local fleetBias = fleet:GetFleetBias()
				local opponentIFF = fleetIFF * -1

				fleetBias:SetDecayFactor(normalDecayFactor[opponentIFF], extraDecaySpeed[opponentIFF])
				fleetBias:Update(timeStamp)

				for _, subUnit in ipairs(fleet:GetSubList()) do
					local subAimBias = subUnit:GetAimBias()

					if subAimBias:GetDecayFactorType() == subAimBias.DIVING then
						subAimBias:SetDecayFactor(divingDecayFactor[opponentIFF], extraDecaySpeed[opponentIFF])
					else
						subAimBias:SetDecayFactor(normalDecayFactor[opponentIFF], extraDecaySpeed[opponentIFF])
					end

					subAimBias:Update(timeStamp)
				end
			end

			for _, freeShip in pairs(self._freeShipList) do
				local opponentIFF = freeShip:GetIFF() * -1
				local freeShipAimBias = freeShip:GetAimBias()

				if freeShipAimBias:GetDecayFactorType() == freeShipAimBias.DIVING then
					freeShipAimBias:SetDecayFactor(divingDecayFactor[opponentIFF], extraDecaySpeed[opponentIFF])
				else
					freeShipAimBias:SetDecayFactor(normalDecayFactor[opponentIFF], extraDecaySpeed[opponentIFF])
				end

				freeShipAimBias:Update(timeStamp)
			end
		end
	end
end

function BattleDataProxy.UpdateEscapeOnly(self, timeStamp)
	for _, foeShip in pairs(self._foeShipList) do
		foeShip:Update(timeStamp)
	end
end

function BattleDataProxy.UpdateCountDown(self, timeStamp)
	self._lastUpdateTime = self._lastUpdateTime or timeStamp
	-- 新的倒计时 = 旧的倒计时 - (当前时间戳 - 上次更新时间戳)
	local newCountDown = self._countDown - (timeStamp - self._lastUpdateTime)

	if newCountDown <= 0 then
		newCountDown = 0
	end

	if math.floor(self._countDown - newCountDown) == 0 or newCountDown == 0 then
		self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_COUNT_DOWN, {}))
	end

	self._countDown = newCountDown
	self._totalTime = timeStamp - self._startTimeStamp
	self._lastUpdateTime = timeStamp
end

-- IMPORTANT: 敌人生成主函数逻辑
-- 被各种command调用，如BattleSingleDungeonCommand.initWaveModule
function BattleDataProxy.SpawnMonster(self, spawnItem, waveIndex, enemyType, IFF, extraEnhanceFunc)
	local monsterUID = self:GenerateUnitID()
	local monsterTmpData = BattleDataFunction.GetMonsterTmpDataFromID(spawnItem.monsterTemplateID)
	local weaponIDList = {}

	for _, weaponID in ipairs(monsterTmpData.equipment_list) do
		table.insert(weaponIDList, {
			id = weaponID
		})
	end
	-- 示例:
	-- random_equipment_list = {{2021004,2021012}},random_nub = {1}
	local random_equipment_list = monsterTmpData.random_equipment_list
	local random_nub = monsterTmpData.random_nub
	-- 简单来说，就是每次从random_equipment_list的每个子表中，随机选出random_nub对应数量的武器加入weaponIDList，并且不会重复选取
	for index, randomWeaponIDList in ipairs(random_equipment_list) do
		local randomWeaponNum = random_nub[index]
		local _randomWeaponIDList = Clone(randomWeaponIDList)

		for _ = 1, randomWeaponNum do
			local randomIndex = math.random(#_randomWeaponIDList)

			table.insert(weaponIDList, {
				id = _randomWeaponIDList[randomIndex]
			})
			table.remove(_randomWeaponIDList, randomIndex)
		end
	end

	local enemyUnit = BattleDataFunction.CreateBattleUnitData(monsterUID, enemyType, IFF, spawnItem.monsterTemplateID, nil, weaponIDList, spawnItem.extraInfo, nil, nil, nil, nil, spawnItem.level)

	BattleAttr.MonsterAttrFixer(self._battleInitData.battleType, enemyUnit)

	local currentHP

	if spawnItem.immuneHPInherit then
		currentHP = enemyUnit:GetMaxHP()
	else
		currentHP = math.ceil(enemyUnit:GetMaxHP() * self._repressEnemyHpRant)
	end

	if currentHP <= 0 then
		currentHP = 1
	end

	enemyUnit:SetCurrentHP(currentHP)

	local spawnPos = BattleFormulas.RandomPos(spawnItem.corrdinate)

	enemyUnit:SetPosition(spawnPos)
	enemyUnit:SetAI(spawnItem.pilotAITemplateID or monsterTmpData.pilot_ai_template_id)
	self:setShipUnitBound(enemyUnit)

	if table.contains(ShipType.SubShipType, monsterTmpData.type) then
		enemyUnit:InitOxygen()	
		self:UpdateHostileSubmarine(true)
	end

	BattleDataFunction.AttachWeather(enemyUnit, self._weahter)

	self._freeShipList[monsterUID] = enemyUnit
	self._unitList[monsterUID] = enemyUnit

	--敌人幽灵(大部分)不可见，也没有碰撞体
	if enemyUnit:IsSpectre() then
		enemyUnit:UpdateBlindInvisibleBySpectre()
	else
		self._cldSystem:InitShipCld(enemyUnit)
	end

	local sicknessDuration = spawnItem.sickness or BattleConst.SUMMONING_SICKNESS_DURATION

	enemyUnit:SummonSickness(sicknessDuration)
	enemyUnit:SetMoveCast(spawnItem.moveCast == true)

	if enemyUnit:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self._friendlyShipList[monsterUID] = enemyUnit
	else
		if enemyUnit:IsSpectre() then
			self._spectreShipList[monsterUID] = enemyUnit
		else
			self._foeShipList[monsterUID] = enemyUnit
		end

		enemyUnit:SetWaveIndex(waveIndex)
	end

	if spawnItem.reinforce then
		enemyUnit:Reinforce()
	end

	if spawnItem.reinforceDelay then
		enemyUnit:SetReinforceCastTime(spawnItem.reinforceDelay)
	end

	if spawnItem.team then
		self:GetNPCTeam(spawnItem.team):AppendUnit(enemyUnit)
	end

	if spawnItem.phase then
		ys.Battle.BattleUnitPhaseSwitcher.New(enemyUnit):SetTemplateData(spawnItem.phase)
	end
	-- 目前，只有BattleSingleChallengeCommand会传入这个参数
	if extraEnhanceFunc then
		extraEnhanceFunc(enemyUnit)
	end

	local addUnitArgs = {
		type = enemyType,
		unit = enemyUnit,
		bossData = spawnItem.bossData,
		extraInfo = spawnItem.extraInfo
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, addUnitArgs))

	local function generateBuffList(buffList)
		for _, buffInfo in ipairs(buffList) do
			local buffID
			local buffLevel

			if type(buffInfo) == "number" then
				buffID = buffInfo
				buffLevel = 1
			else
				buffID = buffInfo.ID
				buffLevel = buffInfo.LV or 1
			end

			local buff = ys.Battle.BattleBuffUnit.New(buffID, buffLevel, enemyUnit)

			enemyUnit:AddBuff(buff)
		end
	end

	local tmpBuffList = enemyUnit:GetTemplate().buff_list
	local spawnBuffList = spawnItem.buffList or {}
	local extraBuffList = self._battleInitData.ExtraBuffList or {}
	local affixBuffList = self._battleInitData.AffixBuffList or {}

	generateBuffList(tmpBuffList)
	generateBuffList(extraBuffList)
	generateBuffList(spawnBuffList)

	if spawnItem.affix then
		generateBuffList(affixBuffList)
	end

	local summonWaveIndex = spawnItem.summonWaveIndex

	if summonWaveIndex then
		self._waveSummonList[summonWaveIndex] = self._waveSummonList[summonWaveIndex] or {}
		self._waveSummonList[summonWaveIndex][enemyUnit] = true
	end

	enemyUnit:CheckWeaponInitial()

	if self._battleInitData.CMDArgs and enemyUnit:GetTemplateID() == self._battleInitData.CMDArgs then
		self:InitSpecificEnemyStatistics(enemyUnit)
	end

	enemyUnit:OverrideDeadFX(spawnItem.deadFX)

	if BATTLE_ENEMY_AIMBIAS_RANGE and enemyUnit:GetAimBias() then
		self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIM_BIAS, {
			aimBias = enemyUnit:GetAimBias()
		}))
	end

	return enemyUnit
end

function BattleDataProxy.UpdateHostileSubmarine(self, isAdding)
	if isAdding then
		self._enemySubmarineCount = self._enemySubmarineCount + 1
	else
		self._enemySubmarineCount = self._enemySubmarineCount - 1
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_HOSTILE_SUBMARINE))
end

function BattleDataProxy.SpawnNPC(self, spawnData, caster)
	local UID = self:GenerateUnitID()
	local MINION_UNIT = BattleConst.UnitType.MINION_UNIT
	local monsterTemplate = BattleDataFunction.GetMonsterTmpDataFromID(spawnData.monsterTemplateID)
	local equipmentList = {}

	for _, equipment in ipairs(monsterTemplate.equipment_list) do
		table.insert(equipmentList, {
			id = equipment
		})
	end

	local unit = BattleDataFunction.CreateBattleUnitData(UID, MINION_UNIT, caster:GetIFF(), spawnData.monsterTemplateID, nil, equipmentList, spawnData.extraInfo, nil, nil, nil, nil, spawnData.level, caster)
	local maxHP = unit:GetMaxHP()

	unit:SetCurrentHP(maxHP)

	local pos
	-- 若指定坐标则在指定坐标生成，否则在召唤者位置生成
	-- 虽然有随机功能，但传入的参数一般没有设定随机参数
	if spawnData.corrdinate then
		pos = BattleFormulas.RandomPos(spawnData.corrdinate)
	else
		pos = Clone(caster:GetPosition())
	end

	unit:SetPosition(pos)
	unit:SetAI(spawnData.pilotAITemplateID or monsterTemplate.pilot_ai_template_id)
	self:setShipUnitBound(unit)

	if table.contains(ShipType.SubShipType, monsterTemplate.type) then
		unit:InitOxygen()

		if unit:GetIFF() ~= BattleConfig.FRIENDLY_CODE then
			self:UpdateHostileSubmarine(true)
		end
	end

	BattleDataFunction.AttachWeather(unit, self._weahter)

	self._freeShipList[UID] = unit
	self._unitList[UID] = unit

	self._cldSystem:InitShipCld(unit)
	-- 设定出生的虚弱期
	local sickness = spawnData.sickness or BattleConst.SUMMONING_SICKNESS_DURATION

	unit:SummonSickness(sickness)
	unit:SetMoveCast(spawnData.moveCast == true)

	self._minionShipList[UID] = unit

	if spawnData.phase then
		ys.Battle.BattleUnitPhaseSwitcher.New(unit):SetTemplateData(spawnData.phase)
	end

	local args = {
		type = MINION_UNIT,
		unit = unit,
		bossData = spawnData.bossData,
		extraInfo = spawnData.extraInfo
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, args))

	local function initBuff(buffList)
		for _, buff in ipairs(buffList) do
			local buffId
			local buffLevel

			if type(buff) == "number" then
				buffId = buff
				buffLevel = 1
			else
				buffId = buff.ID
				buffLevel = buff.LV or 1
			end

			local newBuff = ys.Battle.BattleBuffUnit.New(buffId, buffLevel, unit)

			unit:AddBuff(newBuff)
		end
	end

	local buffList = unit:GetTemplate().buff_list
	local spawnBuffList = spawnData.buffList or {}

	initBuff(buffList)
	initBuff(spawnBuffList)
	unit:CheckWeaponInitial()

	return unit
end

-- 可能用于类似鱼雷艇的超时撤退
-- BattleSingleDungeonCommand.onUpdateCountDown调用
function BattleDataProxy.EnemyEscape(self)
	for _, foeShip in pairs(self._foeShipList) do
		-- "unexit"
		if foeShip:ContainsLabelTag(BattleConfig.ESCAPE_EXPLO_TAG) then
			foeShip:SetDeathReason(BattleConst.UnitDeathReason.CLS)
			foeShip:DeadAction()
		else
			foeShip:RemoveAllAutoWeapon()
			-- 80006
			foeShip:SetAI(BattleConfig.COUNT_DOWN_ESCAPE_AI_ID)
		end
	end
end

function BattleDataProxy.GetNPCTeam(self, teamID)
	if not self._teamList[teamID] then
		self._teamList[teamID] = ys.Battle.BattleTeamVO.New(teamID)
	end

	return self._teamList[teamID]
end

function BattleDataProxy.KillNPCTeam(self, teamID)
	local team = self._teamList[teamID]

	if team then
		team:Dispose()

		self._teamList[teamID] = nil
	end
end

-- note: 生成先锋单位
-- 被BattleDataProxy.InitUserShipsData调用
function BattleDataProxy.SpawnVanguard(self, vanguardData, IFF)
	local spawnPos = self:GetVanguardBornCoordinate(IFF)
	local vanguardUnit = self:generatePlayerUnit(vanguardData, IFF, BuildVector3(spawnPos), self._commanderBuff)

	self:GetFleetByIFF(IFF):AppendPlayerUnit(vanguardUnit)
	self:setShipUnitBound(vanguardUnit)
	BattleDataFunction.AttachWeather(vanguardUnit, self._weahter)
	self._cldSystem:InitShipCld(vanguardUnit)

	local args = {
		type = BattleConst.UnitType.PLAYER_UNIT,
		unit = vanguardUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, args))

	return vanguardUnit
end

-- 生成主力单位
-- 被BattleDataProxy.InitUserShipsData调用
function BattleDataProxy.SpawnMain(self, mainUnitData, IFF)
	local spawnPos
	local fleet = self:GetFleetByIFF(IFF)
	local mainIndex = #fleet:GetMainList() + 1

	if self._currentStageData.mainUnitPosition and self._currentStageData.mainUnitPosition[IFF] then
		spawnPos = Clone(self._currentStageData.mainUnitPosition[IFF][mainIndex])
	else
		spawnPos = Clone(BattleConfig.MAIN_UNIT_POS[IFF][mainIndex])
	end

	local mainUnit = self:generatePlayerUnit(mainUnitData, IFF, spawnPos, self._commanderBuff)

	mainUnit:SetBornPosition(spawnPos)
	mainUnit:SetMainFleetUnit()

	local spawnPosX = spawnPos.x
	-- 一般来说，主力舰队是免疫普通子弹碰撞的(基本都在totalLeftBound之外)
	if spawnPosX < self._totalLeftBound or spawnPosX > self._totalRightBound then
		mainUnit:SetImmuneCommonBulletCLD()
	end

	fleet:AppendPlayerUnit(mainUnit)
	self:setShipUnitBound(mainUnit)
	BattleDataFunction.AttachWeather(mainUnit, self._weahter)
	self._cldSystem:InitShipCld(mainUnit)

	local addUnitArgs = {
		type = BattleConst.UnitType.PLAYER_UNIT,
		unit = mainUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, addUnitArgs))

	return mainUnit
end

-- 生成潜艇单位
-- 被BattleDataProxy.SubmarineStrike调用
function BattleDataProxy.SpawnSub(self, subUnitData, IFF)
	local spawnPos
	local fleet = self:GetFleetByIFF(IFF)
	local newIndex = #fleet:GetSubList() + 1
	-- SUB_UNIT_OFFSET_X = -5
	local spawnOffsetX = BattleConfig.SUB_UNIT_OFFSET_X + (BattleDataFunction.GetPlayerShipTmpDataFromID(subUnitData.tmpID).summon_offset or 0)

	if IFF == BattleConfig.FRIENDLY_CODE then
		spawnPos = Vector3(spawnOffsetX + self._totalLeftBound, 0, BattleConfig.SUB_UNIT_POS_Z[newIndex])
	else
		spawnPos = Vector3(self._totalRightBound - spawnOffsetX, 0, BattleConfig.SUB_UNIT_POS_Z[newIndex])
	end

	local subUnit = self:generatePlayerUnit(subUnitData, IFF, spawnPos, self._subCommanderBuff)

	fleet:AddSubMarine(subUnit)
	self:setShipUnitBound(subUnit)
	BattleDataFunction.AttachWeather(subUnit, self._weahter)
	self._cldSystem:InitShipCld(subUnit)

	local args = {
		type = BattleConst.UnitType.PLAYER_UNIT,
		unit = subUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, args))

	return subUnit
end

-- 破交作战生成潜艇
--- 破交作战生成潜艇
function BattleDataProxy.SpawnManualSub(self, unitData, IFF)
	local spawnPos = self:GetVanguardBornCoordinate(IFF)
	local manualSubUnit = self:generatePlayerUnit(unitData, IFF, BuildVector3(spawnPos), self._commanderBuff)

	self:GetFleetByIFF(IFF):AddManualSubmarine(manualSubUnit)
	self:setShipUnitBound(manualSubUnit)
	self._cldSystem:InitShipCld(manualSubUnit)

	local addUnitArgs = {
		type = BattleConst.UnitType.SUB_UNIT,
		unit = manualSubUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, addUnitArgs))

	return manualSubUnit
end

-- 支援单位生成(包括潜艇支援和航空支援)
-- 被BattleDataProxy.InitUserSupportShipsData调用
function BattleDataProxy.SpawnSupportUnit(self, supportUnitData, IFF)
	local supportUnit = self:generateSupportPlayerUnit(supportUnitData, IFF)
	local fleet = self:GetFleetByIFF(IFF)

	fleet:AppendSupportUnit(supportUnit)

	local supportUnitShipType = supportUnit:GetTemplate().type
	-- qian: 潜艇/潜母/风帆S
	if table.contains(ShipType.BundleList.qian, supportUnitShipType) then
		supportUnit:SetPosition(Clone(BattleConfig.SubSupportUnitPosList[#fleet:GetSupportUnitList()]))
	else
		supportUnit:SetPosition(Clone(BattleConfig.AirSupportUnitPos))
	end

	local addUnitArgs = {
		type = BattleConst.UnitType.SUPPORT_UNIT,
		unit = supportUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, addUnitArgs))

	return supportUnit
end

--- 关闭玩家单位（从舰队中移除并派发事件）
function BattleDataProxy.ShutdownPlayerUnit(self, unitID)
	local unit = self._unitList[unitID]
	local unitIFF = unit:GetIFF()
	local fleet = self:GetFleetByIFF(unitIFF)

	fleet:RemovePlayerUnit(unit)

	local antiAreaArgs = {}

	if fleet:GetFleetAntiAirWeapon():GetRange() == 0 then
		antiAreaArgs.isShow = false
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, antiAreaArgs))

	local shutDownArgs = {
		unit = unit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.SHUT_DOWN_PLAYER, shutDownArgs))
end

function BattleDataProxy.updateDeadList(self)
	local deadCount = #self._deadUnitList

	while deadCount > 0 do
		self._deadUnitList[deadCount]:Dispose()

		self._deadUnitList[deadCount] = nil
		deadCount = deadCount - 1
	end
end

-- note: 击杀单位核心逻辑
function BattleDataProxy.KillUnit(self, unitID)
	local unit = self._unitList[unitID]

	if unit == nil then
		return
	end

	local unitType = unit:GetUnitType()

	self._cldSystem:DeleteShipCld(unit)
	unit:Clear()

	self._unitList[unitID] = nil

	if self._freeShipList[unitID] then
		self._freeShipList[unitID] = nil
	end

	local unitIFF = unit:GetIFF()
	local deathReason = unit:GetDeathReason()

	if unit:GetAimBias() then
		local aimBias = unit:GetAimBias()

		aimBias:RemoveCrew(unit)

		if aimBias:GetCurrentState() == aimBias.STATE_EXPIRE then
			self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIM_BIAS, {
				aimBias = unit:GetAimBias()
			}))
		end
	end

	if unit:IsSpectre() then
		self._spectreShipList[unitID] = nil
	elseif unitIFF == BattleConfig.FOE_CODE then
		self._foeShipList[unitID] = nil

		if unitType == BattleConst.UnitType.ENEMY_UNIT or unitType == BattleConst.UnitType.BOSS_UNIT then
			if unit:GetTeam() then
				unit:GetTeam():RemoveUnit(unit)
			end

			local shipType = unit:GetTemplate().type

			if table.contains(ShipType.SubShipType, shipType) then
				self:UpdateHostileSubmarine(false)
			end

			local waveIndex = unit:GetWaveIndex()

			if waveIndex and self._waveSummonList[waveIndex] then
				self._waveSummonList[waveIndex][unit] = nil
			end
		end
	elseif unitIFF == BattleConfig.FRIENDLY_CODE then
		self._friendlyShipList[unitID] = nil
	end

	local removeArgs = {
		UID = unitID,
		type = unitType,
		deadReason = deathReason,
		unit = unit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_UNIT, removeArgs))
	table.insert(self._deadUnitList, unit)
end

function BattleDataProxy.KillAllEnemy(self)
	for _, unit in pairs(self._unitList) do
		if unit:GetIFF() == BattleConfig.FOE_CODE and unit:IsAlive() and not unit:IsBoss() then
			unit:DeadAction()
		end
	end
end

function BattleDataProxy.KillSubmarineByIFF(self, IFF)
	for _, unit in pairs(self._unitList) do
		if unit:GetIFF() == IFF and unit:IsAlive() and table.contains(ShipType.SubShipType, unit:GetTemplate().type) and not unit:IsBoss() then
			unit:DeadAction()
		end
	end
end

function BattleDataProxy.KillAllAircraft(self)
	for aircraftID, aircraft in pairs(self._aircraftList) do
		aircraft:Clear()

		local removeArgs = {
			UID = aircraftID
		}

		self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, removeArgs))

		self._aircraftList[aircraftID] = nil
	end
end

function BattleDataProxy.KillWaveSummonMonster(self, waveIndex)
	local summonList = self._waveSummonList[waveIndex]

	if summonList then
		for summonUnit, _ in pairs(summonList) do
			local unitUID = summonUnit:GetUniqueID()

			self:KillUnit(unitUID)
		end
	end

	self._waveSummonList[waveIndex] = nil
end

function BattleDataProxy.IsThereBoss(self)
	return self:GetActiveBossCount() > 0
end

function BattleDataProxy.GetActiveBossCount(self)
	local count = 0

	for _, unit in pairs(self:GetUnitList()) do
		if unit:IsBoss() and unit:IsAlive() then
			count = count + 1
		end
	end

	return count
end

-- note: 设置舰船可活动区域
function BattleDataProxy.setShipUnitBound(self, unit)
	local iff = unit:GetIFF()

	if unit:GetFleetVO() then
		unit:SetBound(unit:GetFleetVO():GetUnitBound():GetBound())
	else
		unit:SetBound(self:GetUnitBoundByIFF(iff))
	end
end

-- note: 被BattleDataProxy的各个Spawn函数调用，生成玩家单位
function BattleDataProxy.generatePlayerUnit(self, unitData, IFF, spawnPos, commanderBuffList)
	local UID = self:GenerateUnitID()
	local properties = unitData.properties

	properties.level = unitData.level
	-- FORMATION_ID写死为10001，formationID也没用过
	-- 看了下formation_template，可能最早期的时候阵型设计是用于改变战斗中实际的位置的，不是现在提供Buff
	properties.formationID = BattleConfig.FORMATION_ID
	properties.id = unitData.id

	BattleAttr.AttrFixer(self._battleInitData.battleType, properties)

	local proficiency = unitData.proficiency or {
		1,
		1,
		1
	}
	-- 正常来说，unitType都是PLAYER_UNIT
	local unitType = BattleConst.UnitType.PLAYER_UNIT
	local battleType = self._battleInitData.battleType

	if battleType == SYSTEM_SUBMARINE_RUN or battleType == SYSTEM_SUB_ROUTINE then
		unitType = BattleConst.UnitType.SUB_UNIT
	elseif battleType == SYSTEM_AIRFIGHT then
		unitType = BattleConst.UnitType.CONST_UNIT
	elseif battleType == SYSTEM_CARDPUZZLE then
		unitType = BattleConst.UnitType.CARDPUZZLE_PLAYER_UNIT
	end

	--- @type BattlePlayerUnit
	local playerUnit = BattleDataFunction.CreateBattleUnitData(UID, unitType, IFF, unitData.tmpID, unitData.skinId, unitData.equipment, properties, unitData.baseProperties, proficiency, unitData.baseList, unitData.preloasList)
	-- 计算驱逐舰满破增益
	BattleDataFunction.AttachUltimateBonus(playerUnit)
	playerUnit:InitCurrentHP(unitData.initHPRate or 1)
	playerUnit:SetRarity(unitData.rarity)
	playerUnit:SetIntimacy(unitData.intimacy)
	playerUnit:SetShipName(unitData.name)

	if unitData.spWeapon then
		playerUnit:SetSpWeapon(unitData.spWeapon)
		-- 把spWeapon的标签也加到unit上
		_.each(unitData.spWeapon:GetLabel(), function(labelTag)
			playerUnit:AddLabelTag(labelTag)
		end)
	end
	-- 记录到unitList、friendlyShipList或foeShipList
	self._unitList[UID] = playerUnit

	if playerUnit:GetIFF() == BattleConfig.FRIENDLY_CODE then
		self._friendlyShipList[UID] = playerUnit
	elseif playerUnit:GetIFF() == BattleConfig.FOE_CODE then
		self._foeShipList[UID] = playerUnit
	end

	if battleType == SYSTEM_WORLD then
		local healingRate = BattleFormulas.WorldMapRewardHealingRate(self._battleInitData.EnemyMapRewards, self._battleInitData.FleetMapRewards)

		BattleAttr.SetCurrent(playerUnit, "healingRate", healingRate)
	end

	playerUnit:SetPosition(spawnPos)
	-- 初始化技能、装备、指挥喵技能
	BattleDataFunction.InitUnitSkill(unitData, playerUnit, battleType)
	BattleDataFunction.InitEquipSkill(unitData.equipment, playerUnit, battleType)
	BattleDataFunction.InitCommanderSkill(commanderBuffList, playerUnit, battleType)
	playerUnit:SetGearScore(unitData.shipGS)

	if unitData.deathMark then
		playerUnit:SetWorldDeathMark()
	end

	return playerUnit
end

-- 生成支援舰队单位，与generatePlayerUnit不同
-- 被BattleDataProxy.SpawnSupportUnit调用
function BattleDataProxy.generateSupportPlayerUnit(self, unitData, IFF)
	local UID = self:GenerateUnitID()
	local properties = unitData.properties

	properties.level = unitData.level
	properties.formationID = BattleConfig.FORMATION_ID
	properties.id = unitData.id

	BattleAttr.AttrFixer(self._battleInitData.battleType, properties)

	local proficiency = unitData.proficiency or {
		1,
		1,
		1
	}
	local supportUnit = BattleDataFunction.CreateBattleUnitData(UID, BattleConst.UnitType.SUPPORT_UNIT, IFF, unitData.tmpID, unitData.skinId, unitData.equipment, properties, unitData.baseProperties, proficiency, unitData.baseList, unitData.preloasList)

	supportUnit:InitCurrentHP(1)
	supportUnit:SetShipName(unitData.name)
	-- note: 本质上supportUnit是作为幽灵单位存在的(因此没有模型，没有碰撞体)
	self._spectreShipList[UID] = supportUnit

	return supportUnit
end


-- 根据battle_unit_type，切换幽灵状态
function BattleDataProxy.SwitchSpectreUnit(self, unit)
	local unitUID = unit:GetUniqueID()
	local shipList = unit:GetIFF() == BattleConfig.FRIENDLY_CODE and self._friendlyShipList or self._foeShipList
	-- IsSpectre的判断逻辑就只看battle_unit_type <= -99 是否成立
	if unit:IsSpectre() then
		-- 从正常列表移除，加入幽灵列表
		shipList[unitUID] = nil
		self._spectreShipList[unitUID] = unit
		-- 如果该单位在AOE范围内，则强制退出
		for _, aoe in pairs(self._AOEList) do
			aoe:ForceExit(unit:GetUniqueID())
		end
		-- 移除碰撞体
		self._cldSystem:DeleteShipCld(unit)
	else
		self._spectreShipList[unitUID] = nil
		shipList[unitUID] = unit

		unit:ActiveCldBox()
		self._cldSystem:InitShipCld(unit)
	end
end

function BattleDataProxy.GetUnitList(self)
	return self._unitList
end

function BattleDataProxy.GetFriendlyShipList(self)
	return self._friendlyShipList
end

function BattleDataProxy.GetFoeShipList(self)
	return self._foeShipList
end

function BattleDataProxy.GetFoeAircraftList(self)
	return self._foeAircraftList
end

function BattleDataProxy.GetFreeShipList(self)
	return self._freeShipList
end

function BattleDataProxy.GetSpectreShipList(self)
	return self._spectreShipList
end

function BattleDataProxy.GenerateUnitID(self)
	self._unitCount = self._unitCount + 1

	return self._unitCount
end

function BattleDataProxy.GetCountDown(self)
	return self._countDown
end

-- note: 这是敌方飞机的生成，没有Mother Unit
-- 在各种Command的initWaveModule中，作为回调注册到WaveInfo中
-- 对应到波次配置文件中的airFighter
function BattleDataProxy.SpawnAirFighter(self, tmpData)
	-- 新增Index
	local airFighterIndex = #self._airFighterList + 1
	-- formation_template中定义的阵型偏移
	local formationOffset = BattleDataFunction.GetFormationTmpDataFromID(tmpData.formation).pos_offset
	local spawnArgs = {
		currentNumber = 0,
		templateID = tmpData.templateID,
		totalNumber = tmpData.totalNumber or 0,
		onceNumber = tmpData.onceNumber,
		timeDelay = tmpData.interval or 3,
		-- 这玩意没用啊，也不删了...
		maxTotalNumber = tmpData.maxTotalNumber or 15
	}

	local function generateOneFighter(formationIndex)
		local currentNumber = spawnArgs.currentNumber

		if currentNumber < spawnArgs.totalNumber then
			spawnArgs.currentNumber = currentNumber + 1

			local airFighter = self:CreateAirFighter(tmpData)
			-- 从formation_template来看，每波的onceNumber不会超过对应阵型的飞机数量
			airFighter:SetFormationOffset(formationOffset[formationIndex])
			airFighter:SetFormationIndex(formationIndex)
			-- 死亡时的回调
			airFighter:SetDeadCallBack(function()
				spawnArgs.totalNumber = spawnArgs.totalNumber - 1
				spawnArgs.currentNumber = spawnArgs.currentNumber - 1

				self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_FIGHTER_ICON, {
					index = airFighterIndex
				}))
				self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_AIR_SUPPORT_LABEL, {}))
			end)
			airFighter:SetLiveCallBack(function()
				spawnArgs.currentNumber = spawnArgs.currentNumber - 1
			end)
		end
	end

	local function generateOnce()
		local onceNumber = spawnArgs.onceNumber

		if spawnArgs.totalNumber > 0 then
			for i = 1, onceNumber do
				generateOneFighter(i)
			end
		else
			pg.TimeMgr.GetInstance():RemoveBattleTimer(spawnArgs.timer)

			spawnArgs.timer = nil
		end
	end

	self._airFighterList[airFighterIndex] = spawnArgs

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIR_FIGHTER_ICON, {
		index = airFighterIndex
	}))
	self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_AIR_SUPPORT_LABEL, {}))
	-- 每波之间有Interval秒的间隔
	spawnArgs.timer = pg.TimeMgr.GetInstance():AddBattleTimer("striker", -1, tmpData.interval, generateOnce)
end

function BattleDataProxy.ClearAirFighterTimer(self)
	for _, airFighter in ipairs(self._airFighterList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(airFighter.timer)

		airFighter.timer = nil
	end

	self._airFighterList = {}
end

function BattleDataProxy.KillAllAirStrike(self)
	for aircraftID, aircraft in pairs(self._aircraftList) do
		if aircraft.__name == ys.Battle.BattleAirFighterUnit.__name then
			self._cldSystem:DeleteAircraftCld(aircraft)

			aircraft._aliveState = false
			self._aircraftList[aircraftID] = nil
			self._foeAircraftList[aircraftID] = nil

			local removeArgs = {
				UID = aircraftID
			}

			self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, removeArgs))
		end
	end

	local allCleared = true

	for _, _ in pairs(self._foeAircraftList) do
		allCleared = false

		break
	end

	if allCleared then
		self:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, {
			isShow = false
		}))
	end

	for index, airFighterInfo in ipairs(self._airFighterList) do
		airFighterInfo.totalNumber = 0

		self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_FIGHTER_ICON, {
			index = index
		}))
		pg.TimeMgr.GetInstance():RemoveBattleTimer(airFighterInfo.timer)

		airFighterInfo.timer = nil
	end

	self._airFighterList = {}
end

function BattleDataProxy.GetAirFighterInfo(self, index)
	return self._airFighterList[index]
end

function BattleDataProxy.GetAirFighterList(self)
	return self._airFighterList
end

-- 创建舰载机单位主逻辑
-- 被BattleHiveUnit/BattleSupportHiveUnit.SpawnAircraft调用
function BattleDataProxy.CreateAircraft(self, host, aircraftId, potential, skinId)
	local aircraftUID = self:GenerateAircraftID()
	local aircraft = BattleDataFunction.CreateAircraftUnit(aircraftUID, aircraftId, host, potential)

	if skinId then
		aircraft:SetSkinID(skinId)
	end

	local isEnemy

	if host:GetIFF() == BattleConfig.FRIENDLY_CODE then
		-- block empty
	else
		isEnemy = true
	end

	self:doCreateAirUnit(aircraftUID, aircraft, BattleConst.UnitType.AIRCRAFT_UNIT, isEnemy)

	return aircraft
end

-- AirFighter一般指的是敌方的舰载机，与己方的区分开（但也有不少共用逻辑）
-- 被BattleDataProxy.SpawnAirFighter调用
function BattleDataProxy.CreateAirFighter(self, tmpData)
	local aircraftUID = self:GenerateAircraftID()
	local airFighter = BattleDataFunction.CreateAirFighterUnit(aircraftUID, tmpData)
	-- airFighter一定是敌方的(最后一个参数isEnemy传true)
	self:doCreateAirUnit(aircraftUID, airFighter, BattleConst.UnitType.AIRFIGHTER_UNIT, true)

	return airFighter
end

-- 舰载机相关：处理碰撞、摄像机、事件派发, 设置边界等
function BattleDataProxy.doCreateAirUnit(self, aircraftUID, aircraft, unitType, isEnemy)
	self._aircraftList[aircraftUID] = aircraft

	self._cldSystem:InitAircraftCld(aircraft)
	-- self._leftZoneUpperBound = playerArea[2] + playerArea[4]
	-- self._leftZoneLowerBound = playerArea[2]
	aircraft:SetBound(self._leftZoneUpperBound, self._leftZoneLowerBound)
	aircraft:SetViewBoundData(self._cameraTop, self._cameraBottom, self._cameraLeft, self._cameraRight)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, {
		unit = aircraft,
		type = unitType
	}))

	isEnemy = isEnemy or false

	if isEnemy then
		self._foeAircraftList[aircraftUID] = aircraft

		self:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, {
			isShow = true
		}))
	end
end

function BattleDataProxy.KillAircraft(self, aircraftID)
	local aircraft = self._aircraftList[aircraftID]

	if aircraft == nil then
		return
	end

	aircraft:Clear()
	self._cldSystem:DeleteAircraftCld(aircraft)

	if aircraft:IsUndefeated() and aircraft:GetCurrentState() ~= aircraft.STRIKE_STATE_RECYCLE then
		local opponentIFF = aircraft:GetIFF() * -1

		self:HandleAircraftMissDamage(aircraft, self._fleetList[opponentIFF])
	end

	aircraft._aliveState = false
	self._aircraftList[aircraftID] = nil
	self._foeAircraftList[aircraftID] = nil

	local allCleared = true

	for _, _ in pairs(self._foeAircraftList) do
		allCleared = false

		break
	end

	if allCleared then
		self:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, {
			isShow = false
		}))
	end

	local removeArgs = {
		UID = aircraftID
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, removeArgs))
end

function BattleDataProxy.GetAircraftList(self)
	return self._aircraftList
end

function BattleDataProxy.GenerateAircraftID(self)
	self._aircraftCount = self._aircraftCount + 1

	return self._aircraftCount
end
-- 被BattleWeaponUnit.Spawn调用，实际构建子弹
function BattleDataProxy.CreateBulletUnit(self, bulletID, host, weapon, targetPos)
	local bulletUID = self:GenerateBulletID()
	local bullet, isCld = BattleDataFunction.CreateBattleBulletData(bulletUID, bulletID, host, weapon, targetPos)

	if isCld then
		self._cldSystem:InitBulletCld(bullet)
	end

	local fixBulletRange, bulletOffsetRange = weapon:GetFixBulletRange()

	if fixBulletRange or bulletOffsetRange then
		bullet:FixRange(fixBulletRange, bulletOffsetRange)
	end

	self._bulletList[bulletUID] = bullet

	return bullet
end

function BattleDataProxy.RemoveBulletUnit(self, bulletID)
	local bullet = self._bulletList[bulletID]

	if bullet == nil then
		return
	end

	bullet:DamageUnitListWriteback()

	if bullet:GetIsCld() then
		self._cldSystem:DeleteBulletCld(bullet)
	end

	self._bulletList[bulletID] = nil

	local removeArgs = {
		UID = bulletID
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_BULLET, removeArgs))
	bullet:Dispose()
end

function BattleDataProxy.GetBulletList(self)
	return self._bulletList
end

function BattleDataProxy.GenerateBulletID(self)
	local newID = self._bulletCount + 1

	self._bulletCount = newID

	return newID
end

-- 消除子弹
-- 典型如航母空袭时会消弹(BattleFleetVO.UnleashAllInStrike -> BattleAllInStrike.CLSBullet -> BattleDataProxy.CLSBullet), 或BattleSkillCLS
-- 被BattleAllInStrike.CLSBullet调用
function BattleDataProxy.CLSBullet(self, oppositeIFF, bombCLS)
	local canCLS = true
	-- 演习模式不消弹
	if self._battleInitData.battleType == SYSTEM_DUEL then
		canCLS = false
	end

	if canCLS then
		for bulletUID, bullet in pairs(self._bulletList) do
			if bullet:GetIFF() ~= oppositeIFF or not bullet:GetExist() or bullet:ImmuneCLS() or bullet:ImmuneBombCLS() and bombCLS then
				-- block empty
			else
				self:RemoveBulletUnit(bulletUID)
			end
		end
	end
end

function BattleDataProxy.CLSAircraft(self, IFF)
	for aircraftID, aircraft in pairs(self._aircraftList) do
		if aircraft:GetIFF() == IFF then
			aircraft:Clear()

			local removeArgs = {
				UID = aircraftID
			}

			self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, removeArgs))

			self._aircraftList[aircraftID] = nil
		end
	end
end

function BattleDataProxy.CLSMinion(self)
	for _, unit in pairs(self._unitList) do
		if unit:GetIFF() == BattleConfig.FOE_CODE and unit:IsAlive() and not unit:IsBoss() then
			unit:SetDeathReason(BattleConst.UnitDeathReason.CLS)
			unit:DeadAction()
		end
	end
end

function BattleDataProxy.CLSAOE(self)
	for aoeID, aoe in pairs(self._AOEList) do
		if aoe:GetSource() == aoe.SOURCE_BULLET_9 then
			self:RemoveAreaOfEffect(aoeID)
		end
	end
end

function BattleDataProxy.SpawnColumnArea(self, fieldType, ownerIFF, position, range, lifetime, areaCldFunc, friendly, endFunc)
	friendly = friendly or false

	local aoeID = self:GenerateAreaID()
	local aoeData = ys.Battle.BattleAOEData.New(aoeID, ownerIFF, areaCldFunc, endFunc)
	local pos = Clone(position)

	aoeData:SetPosition(pos)
	aoeData:SetRange(range)
	aoeData:SetAreaType(BattleConst.AreaType.COLUMN)
	aoeData:SetLifeTime(lifetime)
	aoeData:SetFieldType(fieldType)
	aoeData:SetOpponentAffected(not friendly)
	self:CreateAreaOfEffect(aoeData)

	return aoeData
end

--- 生成立方体AOE区域
function BattleDataProxy.SpawnCubeArea(self, fieldType, ownerIFF, position, width, height, lifetime, cldFunc, friendly, endFunc)
	friendly = friendly or false

	local aoeID = self:GenerateAreaID()
	local aoeData = ys.Battle.BattleAOEData.New(aoeID, ownerIFF, cldFunc, endFunc)
	local pos = Clone(position)

	aoeData:SetPosition(pos)
	aoeData:SetWidth(width)
	aoeData:SetHeight(height)
	aoeData:SetAreaType(BattleConst.AreaType.CUBE)
	aoeData:SetLifeTime(lifetime)
	aoeData:SetFieldType(fieldType)
	aoeData:SetOpponentAffected(not friendly)
	self:CreateAreaOfEffect(aoeData)

	return aoeData
end

function BattleDataProxy.SpawnLastingColumnArea(self, fieldType, ownerIFF, position, range, lifetime, areaCldFunc, exitCldFunc, friendly, fxID, endFunc, frequent)
	friendly = friendly or false

	local aoeID = self:GenerateAreaID()
	local lastingAoeData = ys.Battle.BattleLastingAOEData.New(aoeID, ownerIFF, areaCldFunc, exitCldFunc, endFunc, frequent)
	local pos = Clone(position)

	lastingAoeData:SetPosition(pos)
	lastingAoeData:SetRange(range)
	lastingAoeData:SetAreaType(BattleConst.AreaType.COLUMN)
	lastingAoeData:SetLifeTime(lifetime)
	lastingAoeData:SetFieldType(fieldType)
	lastingAoeData:SetOpponentAffected(not friendly)
	self:CreateAreaOfEffect(lastingAoeData)

	if fxID and fxID ~= "" then
		local args = {
			area = lastingAoeData,
			FXID = fxID
		}

		self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AREA, args))
	end

	return lastingAoeData
end

-- BattleEffectBulletUnit.SpawnArea用到
-- 字面意思似乎是生成一个椭圆AOE
-- 但从BattleAOEData的实现来看, 椭圆和矩形使用的CldComponent都是Cube
-- 使用例: 目前只有白凤EX的烟雾玉
function BattleDataProxy.SpawnLastingEllipseArea(self, fieldType, ownerIFF, position, width, height, lifetime, areaCldFunc, exitCldFunc, friendly, fxID, endFunc, frequent)
	friendly = friendly or false

	local areaID = self:GenerateAreaID()
	local lastingAoeData = ys.Battle.BattleLastingAOEData.New(areaID, ownerIFF, areaCldFunc, exitCldFunc, endFunc, frequent)
	local pos = Clone(position)

	lastingAoeData:SetPosition(pos)
	lastingAoeData:SetWidth(width)
	lastingAoeData:SetHeight(height)
	lastingAoeData:SetAreaType(BattleConst.AreaType.ELLIPSE)
	lastingAoeData:SetLifeTime(lifetime)
	lastingAoeData:SetFieldType(fieldType)
	lastingAoeData:SetOpponentAffected(not friendly)
	self:CreateAreaOfEffect(lastingAoeData)

	if fxID and fxID ~= "" then
		local args = {
			area = lastingAoeData,
			FXID = fxID
		}

		self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AREA, args))
	end

	return lastingAoeData
end

function BattleDataProxy.SpawnLastingCubeArea(self, fieldType, ownerIFF, position, areaWidth, areaHeight, lifetime, areaCldFunc, exitCldFunc, friendly, fxID, endFunc, frequent)
	friendly = friendly or false

	local aoeID = self:GenerateAreaID()
	local lastingAoeData = ys.Battle.BattleLastingAOEData.New(aoeID, ownerIFF, areaCldFunc, exitCldFunc, endFunc, frequent)
	local pos = Clone(position)

	lastingAoeData:SetPosition(pos)
	lastingAoeData:SetWidth(areaWidth)
	lastingAoeData:SetHeight(areaHeight)
	lastingAoeData:SetAreaType(BattleConst.AreaType.CUBE)
	lastingAoeData:SetLifeTime(lifetime)
	lastingAoeData:SetFieldType(fieldType)
	lastingAoeData:SetOpponentAffected(not friendly)
	self:CreateAreaOfEffect(lastingAoeData)

	if fxID and fxID ~= "" then
		local args = {
			area = lastingAoeData,
			FXID = fxID
		}

		self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AREA, args))
	end

	return lastingAoeData
end

function BattleDataProxy.SpawnTriggerColumnArea(self, effectField, iff, explodePos, range, time, friendly, miss_fx, cldFunc)
	friendly = friendly or false

	local aoeID = self:GenerateAreaID()
	local aoeData = ys.Battle.BattleTriggerAOEData.New(aoeID, iff, cldFunc)
	local pos = Clone(explodePos)

	aoeData:SetPosition(pos)
	aoeData:SetRange(range)
	aoeData:SetAreaType(BattleConst.AreaType.COLUMN)
	aoeData:SetLifeTime(time)
	aoeData:SetFieldType(effectField)
	aoeData:SetOpponentAffected(not friendly)
	self:CreateAreaOfEffect(aoeData)

	if miss_fx and miss_fx ~= "" then
		local args = {
			area = aoeData,
			FXID = miss_fx
		}

		self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AREA, args))
	end

	return aoeData
end

--- 将AOE数据注册到AOE列表并初始化碰撞、启动计时器
function BattleDataProxy.CreateAreaOfEffect(self, aoeData)
	self._AOEList[aoeData:GetUniqueID()] = aoeData

	self._cldSystem:InitAOECld(aoeData)
	aoeData:StartTimer()
end

--- 从AOE列表移除并清理
function BattleDataProxy.RemoveAreaOfEffect(self, aoeID)
	local aoeData = self._AOEList[aoeID]

	if not aoeData then
		return
	end

	aoeData:Dispose()

	self._AOEList[aoeID] = nil

	self._cldSystem:DeleteAOECld(aoeData)
	self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AREA, {
		id = aoeID
	}))
end

function BattleDataProxy.GetAOEList(self)
	return self._AOEList
end

function BattleDataProxy.GenerateAreaID(self)
	self._AOECount = self._AOECount + 1

	return self._AOECount
end

-- 生成墙体
-- Wall是游戏中的护盾墙
function BattleDataProxy.SpawnWall(self, host, cldFun, cldBox, cldOffset)
	local wallID = self:GenerateWallID()
	local wallData = ys.Battle.BattleWallData.New(wallID, host, cldFun, cldBox, cldOffset)

	self._wallList[wallID] = wallData

	self._cldSystem:InitWallCld(wallData)

	return wallData
end

function BattleDataProxy.RemoveWall(self, wallID)
	local wallData = self._wallList[wallID]

	self._wallList[wallID] = nil

	self._cldSystem:DeleteWallCld(wallData)
end

-- BattleSkillProjectShelter使用
-- Shelter: 本质来讲
function BattleDataProxy.SpawnShelter(self, box, duration)
	local ShelterID = self:GernerateShelterID()
	local ShelterData = ys.Battle.BattleShelterData.New(ShelterID)

	self._shelterList[ShelterID] = ShelterData

	return ShelterData
end

function BattleDataProxy.RemoveShelter(self, shelterID)
	local shelterData = self._shelterList[shelterID]
	local removeArgs = {
		uid = shelterID
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_SHELTER, removeArgs))
	shelterData:Deactive()

	self._shelterList[shelterID] = nil
end

function BattleDataProxy.GetWallList(self)
	return self._wallList
end

function BattleDataProxy.GenerateWallID(self)
	self._wallIndex = self._wallIndex + 1

	return self._wallIndex
end

function BattleDataProxy.GernerateShelterID(self)
	self._shelterIndex = self._shelterIndex + 1

	return self._shelterIndex
end

--- 生成环境效果（如灯塔）
function BattleDataProxy.SpawnEnvironment(self, envTemplate)
	local envID = self:GernerateEnvironmentID()
	local envUnit = ys.Battle.BattleEnvironmentUnit.New(envID, BattleConfig.FOE_CODE)

	envUnit:SetTemplate(envTemplate)

	local behaviours = envUnit:GetBehaviours()
	local position = Vector3(envTemplate.coordinate[1], envTemplate.coordinate[2], envTemplate.coordinate[3])

	local function areaCldFunc(args)
		local collideList = {}

		for _, collideUnit in ipairs(args) do
			if collideUnit.Active then
				local unit = self._unitList[collideUnit.UID]

				if not unit:IsSpectre() then
					table.insert(collideList, unit)
				end
			end
		end

		envUnit:UpdateFrequentlyCollide(collideList)
	end

	local function exitCldFunc()
		return
	end

	local function endFunc()
		return
	end

	local fieldType = envTemplate.field_type or BattleConst.BulletField.SURFACE
	local ownerIFF = envTemplate.IFF or BattleConfig.FOE_CODE
	local lifetime = 0
	local aoeData

	if #envTemplate.cld_data == 1 then
		local cldWidth = envTemplate.cld_data[1]

		aoeData = self:SpawnLastingColumnArea(fieldType, ownerIFF, position, cldWidth, lifetime, areaCldFunc, exitCldFunc, false, envTemplate.prefab, endFunc, true)
	else
		local cldWidth = envTemplate.cld_data[1]
		local cldHeight = envTemplate.cld_data[2]

		aoeData = self:SpawnLastingCubeArea(fieldType, ownerIFF, position, cldWidth, cldHeight, lifetime, areaCldFunc, exitCldFunc, false, envTemplate.prefab, endFunc, true)
	end

	envUnit:SetAOEData(aoeData)

	self._environmentList[envID] = envUnit

	return envUnit
end

function BattleDataProxy.RemoveEnvironment(self, envID)
	local envUnit = self._environmentList[envID]
	local aoeData = envUnit:GetAOEData()

	self:RemoveAreaOfEffect(aoeData:GetUniqueID())
	envUnit:Dispose()

	self._environmentList[envID] = nil
end

function BattleDataProxy.DispatchWarning(self, isActive, _)
	self:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_ENVIRONMENT_WARNING, {
		isActive = isActive
	}))
end

function BattleDataProxy.GetEnvironmentList(self)
	return self._environmentList
end

function BattleDataProxy.GernerateEnvironmentID(self)
	self._environmentIndex = self._environmentIndex + 1

	return self._environmentIndex
end

function BattleDataProxy.SpawnEffect(self, fxID, position, localScale)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_EFFECT, {
		FXID = fxID,
		position = position,
		localScale = localScale
	}))
end

function BattleDataProxy.SpawnUIFX(self, fxID, position, localScale, orderDiff)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UI_FX, {
		FXID = fxID,
		position = position,
		localScale = localScale,
		orderDiff = orderDiff
	}))
end

function BattleDataProxy.SpawnCameraFX(self, fxID, position, localScale, orderDiff)
	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_CAMERA_FX, {
		FXID = fxID,
		position = position,
		localScale = localScale,
		orderDiff = orderDiff
	}))
end

function BattleDataProxy.GetFriendlyCode(self)
	return self._friendlyCode
end

function BattleDataProxy.GetFoeCode(self)
	return self._foeCode
end

function BattleDataProxy.GetOppoSideCode(sideCode)
	if sideCode == BattleConfig.FRIENDLY_CODE then
		return BattleConfig.FOE_CODE
	elseif sideCode == BattleConfig.FOE_CODE then
		return BattleConfig.FRIENDLY_CODE
	end
end

function BattleDataProxy.GetStatistics(self)
	return self._statistics
end

function BattleDataProxy.BlockManualCast(self, isBlocked)
	local delta = isBlocked and 1 or -1

	for _, fleet in pairs(self._fleetList) do
		fleet:SetWeaponBlock(delta)
	end
end

function BattleDataProxy.JamManualCast(self, jammingFlag)
	self:DispatchEvent(ys.Event.New(BattleEvent.JAMMING, {
		jammingFlag = jammingFlag
	}))
end

-- 潜艇出击逻辑
-- 被BattleControllerWeaponCommand.TryAutoSub(自律召唤潜艇)或BattleSkillView的_subStriveBtn的callback调用
function BattleDataProxy.SubmarineStrike(self, IFF)
	local fleet = self:GetFleetByIFF(IFF)
	local subAidVO = fleet:GetSubAidVO()

	if self._battleInitData.battleType ~= SYSTEM_SCENARIO_SUB_STRIKE and (fleet:GetWeaponBlock() or subAidVO:GetCurrent() < 1) then
		return
	end

	local subUnitList = fleet:GetSubUnitData()

	for _, subUnitData in ipairs(subUnitList) do
		local subUnit = self:SpawnSub(subUnitData, IFF)

		self:InitAidUnitStatistics(subUnit)
	end

	fleet:SubWarcry()

	local subList = fleet:GetSubList()

	for index, subUnit in ipairs(subList) do
		if index == 1 then
			subUnit:TriggerBuff(BattleConst.BuffEffectType.ON_SUB_LEADER)
		elseif index == 2 then
			subUnit:TriggerBuff(BattleConst.BuffEffectType.ON_UPPER_SUB_CONSORT)
		elseif index == 3 then
			subUnit:TriggerBuff(BattleConst.BuffEffectType.ON_LOWER_SUB_CONSORT)
		end

		if subUnit:GetAimBias() then
			self:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIM_BIAS, {
				aimBias = subUnit:GetAimBias()
			}))
		end
	end

	local subLeader = subList[1]

	subAidVO:Cast()
end

-- BattleWaveInfo.IsFlagsPass调用
function BattleDataProxy.GetWaveFlags(self)
	return self._waveFlags
end

-- BattleBuffRegisterWaveFlags.onTrigger调用
-- 注册waveFlag
function BattleDataProxy.AddWaveFlag(self, flag)
	if not flag then
		return
	end

	local waveFlags = self:GetWaveFlags()

	if table.contains(waveFlags, flag) then
		return
	end

	table.insert(waveFlags, flag)
end

function BattleDataProxy.RemoveFlag(self, flag)
	if not flag then
		return
	end

	local waveFlags = self:GetWaveFlags()

	if not table.contains(waveFlags, flag) then
		return
	end

	table.removebyvalue(waveFlags, flag)
end

-- BattleSKillEditCustomWarning调用
function BattleDataProxy.DispatchCustomWarning(self, labelData)
	self:DispatchEvent(ys.Event.New(BattleEvent.EDIT_CUSTOM_WARNING_LABEL, {
		labelData = labelData
	}))
end

-- BattleSkillGridmanFloat调用
function BattleDataProxy.DispatchGridmanSkill(self, type, IFF)
	self:DispatchEvent(ys.Event.New(BattleEvent.GRIDMAN_SKILL_FLOAT, {
		type = type,
		IFF = IFF
	}))
end

-- 创建融合单位
-- 被BattleSkillFusion.doFusion调用
function BattleDataProxy.SpawnFusionUnit(self, caster, fusionUnitData, candidateList, attrInheritList)
	local pos = Clone(caster:GetPosition())
	local IFF = caster:GetIFF()
	local fusionUnit = self:generatePlayerUnit(fusionUnitData, IFF, pos, self._commanderBuff)

	BattleAttr.SetFusionAttrFromElement(fusionUnit, caster, candidateList, attrInheritList)
	fusionUnit:SetCurrentHP(fusionUnit:GetMaxHP())
	caster:GetFleetVO():AppendPlayerUnit(fusionUnit)
	self:setShipUnitBound(fusionUnit)
	BattleDataFunction.AttachWeather(fusionUnit, self._weahter)
	self._cldSystem:InitShipCld(fusionUnit)

	local addUnitArgs = {
		type = BattleConst.UnitType.PLAYER_UNIT,
		unit = fusionUnit
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, addUnitArgs))

	return fusionUnit
end

-- 解除融合单位
-- 被BattleSkillFusion.doFusion调用
function BattleDataProxy.DefusionUnit(self, fusionUnit)
	local fusionUnitIFF = fusionUnit:GetIFF()
	local fleet = self:GetFleetByIFF(fusionUnitIFF)

	fleet:RemovePlayerUnit(fusionUnit)

	local antiAreaArgs = {}

	if fleet:GetFleetAntiAirWeapon():GetRange() == 0 then
		antiAreaArgs.isShow = false
	end

	self:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, antiAreaArgs))
	fusionUnit:SetDeathReason(BattleConst.UnitDeathReason.DEFUSION)
	self:KillUnit(fusionUnit:GetUniqueID())
end

-- 冻结单位
-- 被BattleSkillFusion.doFusion调用
-- 这是在融合期间，参与融合的单位会被冻结，无法行动
-- 取而代之的是，多个单位会融合成一个新的融合单位行动
function BattleDataProxy.FreezeUnit(self, unit)
	-- 设置battle_unit_type = -10000
	BattleAttr.SetCurrent(unit, ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY, BattleConfig.FUSION_ELEMENT_UNIT_TYPE)
	unit:UpdateBlindInvisibleBySpectre()
	-- 变为幽灵状态
	self:SwitchSpectreUnit(unit)

	if unit:GetAimBias() then
		--- @type BattleUnitAimBiasComponent
		local aimBias = unit:GetAimBias()
		-- 不参与瞄准偏差计算
		aimBias:RemoveCrew(unit)

		if aimBias:GetCurrentState() == aimBias.STATE_EXPIRE then
			self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIM_BIAS, {
				aimBias = unit:GetAimBias()
			}))
		end
	end

	unit:Freeze()
	local fleetVO = unit:GetFleetVO()

	if fleetVO then
		fleetVO:FreezeUnit(unit)
	end
end

function BattleDataProxy.ActiveFreezeUnit(self, unit)
	BattleAttr.SetCurrent(unit, ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY, BattleConfig.PLAYER_DEFAULT)
	unit:UpdateBlindInvisibleBySpectre()
	self:SwitchSpectreUnit(unit)
	BattleDataFunction.AttachWeather(unit, self._weahter)
	unit:ActiveFreeze()

	local fleetVO = unit:GetFleetVO()

	if fleetVO then
		fleetVO:ActiveFreezeUnit(unit)
	end
end

-- 判断舰队是否合法（是否有前锋且旗舰存活）
function BattleDataProxy.GetFleetLegal(self, IFF, battleType)
	if battleType == SYSTEM_DUEL or battleType == SYSTEM_PERFORM or battleType == SYSTEM_SUB_ROUTINE or battleType == SYSTEM_CARDPUZZLE or battleType == SYSTEM_PROLOGUE or battleType == SYSTEM_DODGEM or battleType == SYSTEM_SIMULATION or battleType == SYSTEM_SUBMARINE_RUN or battleType == SYSTEM_SCENARIO_SUB_STRIKE or battleType == SYSTEM_DEBUG or battleType == SYSTEM_AIRFIGHT then
		return true
	else
		local fleet = self:GetFleetByIFF(IFF)

		if #fleet:GetScoutList() == 0 or not fleet:GetFlagShip():IsAlive() then
			return false
		else
			return true
		end
	end
end

-- 战斗结算时触发的内容
function BattleDataProxy.TriggerFinishBattle(self)
	for _, fleet in pairs(self._fleetList) do
		local unitList = fleet:GetUnitList()

		for _, unit in ipairs(unitList) do
			unit:TriggerBuff(BattleConst.BuffEffectType.ON_FINISH_GAME)
		end
	end

	for _, minionUnit in pairs(self._minionShipList) do
		minionUnit:TriggerBuff(BattleConst.BuffEffectType.ON_FINISH_GAME)
	end
end

-- 潜艇支援舰队弹幕
-- 被BattleSingleDungeonCommand.DoPrologue调用
function BattleDataProxy.ChapterSupportBarrage(self, IFF, delay)
	local supportBarrageTimer

	local function afterDelay(...)
		for _, supportUnitData in ipairs(self._battleInitData.SupportUnitList) do
			local supportUnitShipType = BattleDataFunction.GetPlayerShipTmpDataFromID(supportUnitData.tmpID).type

			if table.contains(ShipType.BundleList.qian, supportUnitShipType) then
				local supportUnit = self:SpawnSupportUnit(supportUnitData, IFF)
				-- 装填为0，只会打一轮
				BattleAttr.SetCurrent(supportUnit, "loadSpeed", 0)
			end
		end

		pg.TimeMgr.GetInstance():RemoveBattleTimer(supportBarrageTimer)
	end
	-- 这个delay目前都是5s(计时器1.5+5=6.5s时间点触发)
	if delay then
		supportBarrageTimer = pg.TimeMgr.GetInstance():AddBattleTimer("supportBarrageTimer", -1, delay, afterDelay)
	else
		afterDelay()
	end
end
