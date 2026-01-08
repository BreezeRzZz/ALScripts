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
				-- 支援舰队可添加制空权Buff
				if BattleDataFunction.GetSLGStrategyBuffByCombatBuffID(buffID).type == ChapterConst.AirDominanceStrategyBuffType then
					local buff = ys.Battle.BattleBuffUnit.New(buffID)

					supportUnit:AddBuff(buff)
				end
			end)
		end
	end
end

function BattleDataProxy.InitAllFleetUnitsWeaponCD(arg_10_0)
	for iter_10_0, iter_10_1 in pairs(arg_10_0._fleetList) do
		local var_10_0 = iter_10_1:GetUnitList()

		for iter_10_2, iter_10_3 in ipairs(var_10_0) do
			BattleDataProxy.InitUnitWeaponCD(iter_10_3)
		end
	end
end

function BattleDataProxy.InitUnitWeaponCD(arg_11_0)
	arg_11_0:CheckWeaponInitial()
end

function BattleDataProxy.StartCardPuzzle(arg_12_0)
	for iter_12_0, iter_12_1 in pairs(arg_12_0._fleetList) do
		iter_12_1:GetCardPuzzleComponent():Start()
	end
end

function BattleDataProxy.PausePuzzleComponent(arg_13_0)
	for iter_13_0, iter_13_1 in pairs(arg_13_0._fleetList) do
		local var_13_0 = iter_13_1:GetCardPuzzleComponent()

		if var_13_0 then
			var_13_0:BlockComponentByCard(true)
		end
	end
end

function BattleDataProxy.ResumePuzzleComponent(arg_14_0)
	onDelayTick(function()
		for iter_15_0, iter_15_1 in pairs(arg_14_0._fleetList) do
			local var_15_0 = iter_15_1:GetCardPuzzleComponent()

			if var_15_0 then
				var_15_0:BlockComponentByCard(false)
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

function BattleDataProxy.initBGM(arg_19_0)
	arg_19_0._initBGMList = {}
	arg_19_0._otherBGMList = {}

	local var_19_0 = {}
	local var_19_1 = {}

	local function var_19_2(arg_20_0)
		for iter_20_0, iter_20_1 in ipairs(arg_20_0) do
			local var_20_0 = {}

			if iter_20_1.skills then
				for iter_20_2, iter_20_3 in ipairs(iter_20_1.skills) do
					table.insert(var_20_0, iter_20_3)
				end
			end

			if iter_20_1.equipment then
				local var_20_1 = BattleDataFunction.GetEquipSkill(iter_20_1.equipment, arg_19_0._battleInitData.battleType)

				for iter_20_4, iter_20_5 in ipairs(var_20_1) do
					var_20_0[iter_20_5.buffID] = {
						id = iter_20_5.buffID,
						level = iter_20_5.buffLV
					}
				end
			end

			local var_20_2 = BattleDataFunction.GetSongList(var_20_0)

			for iter_20_6, iter_20_7 in pairs(var_20_2.initList) do
				var_19_0[iter_20_6] = true
			end

			for iter_20_8, iter_20_9 in pairs(var_20_2.otherList) do
				var_19_1[iter_20_8] = true
			end
		end
	end

	var_19_2(arg_19_0._battleInitData.MainUnitList)
	var_19_2(arg_19_0._battleInitData.VanguardUnitList)
	var_19_2(arg_19_0._battleInitData.SubUnitList)

	if arg_19_0._battleInitData.RivalMainUnitList then
		var_19_2(arg_19_0._battleInitData.RivalMainUnitList)
	end

	if arg_19_0._battleInitData.RivalVanguardUnitList then
		var_19_2(arg_19_0._battleInitData.RivalVanguardUnitList)
	end

	for iter_19_0, iter_19_1 in pairs(var_19_0) do
		table.insert(arg_19_0._initBGMList, iter_19_0)
	end

	for iter_19_2, iter_19_3 in pairs(var_19_1) do
		table.insert(arg_19_0._otherBGMList, iter_19_2)
	end
end

function BattleDataProxy.initCommanderBuff(arg_21_0)
	local var_21_0 = {}

	for iter_21_0, iter_21_1 in ipairs(arg_21_0) do
		local var_21_1 = iter_21_1[1]
		local var_21_2 = var_21_1:getSkills()[1]:getLevel()

		for iter_21_2, iter_21_3 in ipairs(iter_21_1[2]) do
			table.insert(var_21_0, {
				id = iter_21_3,
				level = var_21_2,
				commander = var_21_1
			})
		end
	end

	return var_21_0
end

function BattleDataProxy.Clear(arg_22_0)
	for iter_22_0, iter_22_1 in pairs(arg_22_0._teamList) do
		arg_22_0:KillNPCTeam(iter_22_1)
	end

	arg_22_0._teamList = nil

	for iter_22_2, iter_22_3 in pairs(arg_22_0._bulletList) do
		arg_22_0:RemoveBulletUnit(iter_22_2)
	end

	arg_22_0._bulletList = nil

	for iter_22_4, iter_22_5 in pairs(arg_22_0._unitList) do
		arg_22_0:KillUnit(iter_22_4)
	end

	arg_22_0._unitList = nil

	for iter_22_6, iter_22_7 in ipairs(arg_22_0._deadUnitList) do
		iter_22_7:Dispose()
	end

	arg_22_0._deadUnitList = nil

	for iter_22_8, iter_22_9 in pairs(arg_22_0._aircraftList) do
		arg_22_0:KillAircraft(iter_22_8)
	end

	arg_22_0._aircraftList = nil

	for iter_22_10, iter_22_11 in pairs(arg_22_0._fleetList) do
		iter_22_11:Dispose()

		arg_22_0._fleetList[iter_22_10] = nil
	end

	arg_22_0._fleetList = nil

	for iter_22_12, iter_22_13 in pairs(arg_22_0._aidUnitList) do
		iter_22_13:Dispose()
	end

	arg_22_0._aidUnitList = nil

	for iter_22_14, iter_22_15 in pairs(arg_22_0._environmentList) do
		arg_22_0:RemoveEnvironment(iter_22_15:GetUniqueID())
	end

	arg_22_0._environmentList = nil

	for iter_22_16, iter_22_17 in pairs(arg_22_0._AOEList) do
		arg_22_0:RemoveAreaOfEffect(iter_22_16)
	end

	arg_22_0._AOEList = nil

	arg_22_0._cldSystem:Dispose()

	arg_22_0._cldSystem = nil
	arg_22_0._dungeonInfo = nil
	arg_22_0._flagShipUnit = nil
	arg_22_0._friendlyShipList = nil
	arg_22_0._foeShipList = nil
	arg_22_0._spectreShipList = nil
	arg_22_0._friendlyAircraftList = nil
	arg_22_0._foeAircraftList = nil
	arg_22_0._fleetList = nil
	arg_22_0._freeShipList = nil
	arg_22_0._countDown = nil
	arg_22_0._lastUpdateTime = nil
	arg_22_0._statistics = nil
	arg_22_0._battleInitData = nil
	arg_22_0._currentStageData = nil

	arg_22_0:ClearFormulas()
	BattleDataFunction.ClearDungeonCfg(arg_22_0._dungeonID)
end

function BattleDataProxy.DeactiveProxy(arg_23_0)
	arg_23_0._state = nil

	arg_23_0:Clear()
	ys.Battle.BattleDataProxy.super.DeactiveProxy(arg_23_0)
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

-- 同样在BattleDataProxy.InitBattle调用，就在InitUserShipsData之后
function BattleDataProxy.InitUserSupportShipsData(self, IFF, supportUnitList)
	local fleet = self:GetFleetByIFF(IFF)

	for _, supportUnitData in ipairs(supportUnitList) do
		local supportUnit = self:SpawnSupportUnit(supportUnitData, IFF)
	end
end

-- BattleTargetChoise.TargetPlayerAidUnit会使用
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
		-- 效率没什么用，跨队武器不会用到，一般都是1
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
function BattleDataProxy.SetSubmarinAidData(arg_27_0)
	arg_27_0:GetFleetByIFF(BattleConfig.FRIENDLY_CODE):SetSubAidData(arg_27_0._battleInitData.TotalSubAmmo, arg_27_0._battleInitData.SubFlag)
end

function BattleDataProxy.AddWeather(arg_28_0, arg_28_1)
	table.insert(arg_28_0._weahter, arg_28_1)
	arg_28_0:InitWeatherData()
end

function BattleDataProxy.InitWeatherData(arg_29_0)
	for iter_29_0, iter_29_1 in ipairs(arg_29_0._weahter) do
		if iter_29_1 == BattleConst.WEATHER.NIGHT then
			for iter_29_2, iter_29_3 in pairs(arg_29_0._fleetList) do
				iter_29_3:AttachNightCloak()
			end

			for iter_29_4, iter_29_5 in pairs(arg_29_0._unitList) do
				BattleDataFunction.AttachWeather(iter_29_5, arg_29_0._weahter)
			end
		end
	end
end

function BattleDataProxy.CelebrateVictory(arg_30_0, arg_30_1)
	local var_30_0

	if arg_30_1 == arg_30_0:GetFoeCode() then
		var_30_0 = arg_30_0._foeShipList
	else
		var_30_0 = arg_30_0._friendlyShipList
	end

	for iter_30_0, iter_30_1 in pairs(var_30_0) do
		iter_30_1:StateChange(ys.Battle.UnitState.STATE_VICTORY)
	end
end

-- TODO
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

function BattleDataProxy.GetTotalBounds(arg_33_0)
	return arg_33_0._totalUpperBound, arg_33_0._totalLowerBound, arg_33_0._totalLeftBound, arg_33_0._totalRightBound
end

function BattleDataProxy.GetTotalRightBound(arg_34_0)
	return arg_34_0._totalRightBound
end

function BattleDataProxy.GetTotalLowerBound(arg_35_0)
	return arg_35_0._totalLowerBound
end

function BattleDataProxy.GetUnitBoundByIFF(arg_36_0, arg_36_1)
	if arg_36_1 == BattleConfig.FRIENDLY_CODE then
		return arg_36_0._leftZoneUpperBound, arg_36_0._leftZoneLowerBound, arg_36_0._leftZoneLeftBound, BattleConfig.MaxRight, BattleConfig.MaxLeft, arg_36_0._leftZoneRightBound
	elseif arg_36_1 == BattleConfig.FOE_CODE then
		return arg_36_0._rightZoneUpperBound, arg_36_0._rightZoneLowerBound, arg_36_0._rightZoneLeftBound, arg_36_0._rightZoneRightBound, arg_36_0._rightZoneLeftBound, BattleConfig.MaxRight
	end
end

function BattleDataProxy.GetFleetBoundByIFF(arg_37_0, arg_37_1)
	if arg_37_1 == BattleConfig.FRIENDLY_CODE then
		return arg_37_0._leftZoneUpperBound, arg_37_0._leftZoneLowerBound, arg_37_0._leftZoneLeftBound, arg_37_0._leftZoneRightBound
	elseif arg_37_1 == BattleConfig.FOE_CODE then
		return arg_37_0._rightZoneUpperBound, arg_37_0._rightZoneLowerBound, arg_37_0._rightZoneLeftBound, arg_37_0._rightZoneRightBound
	end
end

function BattleDataProxy.ShiftFleetBound(arg_38_0, arg_38_1, arg_38_2)
	arg_38_1:GetUnitBound():SwtichDuelAggressive()
	arg_38_1:SetAutobotBound(arg_38_0:GetFleetBoundByIFF(arg_38_2))
	arg_38_1:UpdateScoutUnitBound()
end

function BattleDataProxy.GetFieldBound(arg_39_0)
	if arg_39_0._battleInitData and arg_39_0._battleInitData.battleType == SYSTEM_DUEL then
		return arg_39_0:GetTotalBounds()
	else
		return arg_39_0._totalUpperBound, arg_39_0._totalLowerBound, arg_39_0._leftFieldBound, arg_39_0._rightFieldBound
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

function BattleDataProxy.GetAidUnit(arg_41_0)
	return arg_41_0._aidUnitList
end

function BattleDataProxy.GetFleetList(arg_42_0)
	return arg_42_0._fleetList
end

function BattleDataProxy.GetEnemySubmarineCount(arg_43_0)
	return arg_43_0._enemySubmarineCount
end

function BattleDataProxy.GetCommander(arg_44_0)
	return arg_44_0._commander
end

function BattleDataProxy.GetCommanderBuff(arg_45_0)
	return arg_45_0._commanderBuff, arg_45_0._subCommanderBuff
end

function BattleDataProxy.GetStageInfo(arg_46_0)
	return arg_46_0._currentStageData
end

function BattleDataProxy.GetWinningStreak(arg_47_0)
	return arg_47_0._chapterWinningStreak
end

function BattleDataProxy.GetBGMList(arg_48_0, arg_48_1)
	if not arg_48_1 then
		return arg_48_0._initBGMList
	else
		return arg_48_0._otherBGMList
	end
end

function BattleDataProxy.GetDungeonLevel(arg_49_0)
	return arg_49_0._dungeonLevel
end

function BattleDataProxy.SetDungeonLevel(arg_50_0, arg_50_1)
	arg_50_0._dungeonLevel = arg_50_1
end

function BattleDataProxy.IsCompletelyRepress(arg_51_0)
	return arg_51_0._completelyRepress
end

function BattleDataProxy.GetRepressReduce(arg_52_0)
	return arg_52_0._repressReduce
end

function BattleDataProxy.GetRepressLevel(arg_53_0)
	return arg_53_0._repressLevel
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

function BattleDataProxy.UpdateWeather(arg_57_0, arg_57_1)
	for iter_57_0, iter_57_1 in ipairs(arg_57_0._weahter) do
		if iter_57_1 == BattleConst.WEATHER.NIGHT then
			local var_57_0 = {
				[BattleConfig.FRIENDLY_CODE] = 0,
				[BattleConfig.FOE_CODE] = 0
			}
			local var_57_1 = {
				[BattleConfig.FRIENDLY_CODE] = 0,
				[BattleConfig.FOE_CODE] = 0
			}
			local var_57_2 = {
				[BattleConfig.FRIENDLY_CODE] = 0,
				[BattleConfig.FOE_CODE] = 0
			}

			for iter_57_2, iter_57_3 in pairs(arg_57_0._unitList) do
				local var_57_3 = iter_57_3:GetAimBias()

				if not var_57_3 or var_57_3:GetCurrentState() ~= var_57_3.STATE_SUMMON_SICKNESS then
					local var_57_4 = iter_57_3:GetIFF()
					local var_57_5 = var_57_1[var_57_4]
					local var_57_6 = BattleAttr.GetCurrent(iter_57_3, "attackRating")
					local var_57_7 = BattleAttr.GetCurrent(iter_57_3, "aimBiasExtraACC")

					var_57_1[var_57_4] = math.max(var_57_5, var_57_6)
					var_57_2[var_57_4] = var_57_2[var_57_4] + var_57_7

					if ShipType.ContainInLimitBundle(ShipType.BundleAntiSubmarine, iter_57_3:GetTemplate().type) then
						var_57_0[var_57_4] = math.max(var_57_0[var_57_4], var_57_6)
					end
				end
			end

			for iter_57_4, iter_57_5 in pairs(arg_57_0._fleetList) do
				local var_57_8 = iter_57_5:GetFleetBias()
				local var_57_9 = iter_57_4 * -1

				var_57_8:SetDecayFactor(var_57_1[var_57_9], var_57_2[var_57_9])
				var_57_8:Update(arg_57_1)

				for iter_57_6, iter_57_7 in ipairs(iter_57_5:GetSubList()) do
					local var_57_10 = iter_57_7:GetAimBias()

					if var_57_10:GetDecayFactorType() == var_57_10.DIVING then
						var_57_10:SetDecayFactor(var_57_0[var_57_9], var_57_2[var_57_9])
					else
						var_57_10:SetDecayFactor(var_57_1[var_57_9], var_57_2[var_57_9])
					end

					var_57_10:Update(arg_57_1)
				end
			end

			for iter_57_8, iter_57_9 in pairs(arg_57_0._freeShipList) do
				local var_57_11 = iter_57_9:GetIFF() * -1
				local var_57_12 = iter_57_9:GetAimBias()

				if var_57_12:GetDecayFactorType() == var_57_12.DIVING then
					var_57_12:SetDecayFactor(var_57_0[var_57_11], var_57_2[var_57_11])
				else
					var_57_12:SetDecayFactor(var_57_1[var_57_11], var_57_2[var_57_11])
				end

				var_57_12:Update(arg_57_1)
			end
		end
	end
end

function BattleDataProxy.UpdateEscapeOnly(arg_58_0, arg_58_1)
	for iter_58_0, iter_58_1 in pairs(arg_58_0._foeShipList) do
		iter_58_1:Update(arg_58_1)
	end
end

function BattleDataProxy.UpdateCountDown(arg_59_0, arg_59_1)
	arg_59_0._lastUpdateTime = arg_59_0._lastUpdateTime or arg_59_1

	local var_59_0 = arg_59_0._countDown - (arg_59_1 - arg_59_0._lastUpdateTime)

	if var_59_0 <= 0 then
		var_59_0 = 0
	end

	if math.floor(arg_59_0._countDown - var_59_0) == 0 or var_59_0 == 0 then
		arg_59_0:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_COUNT_DOWN, {}))
	end

	arg_59_0._countDown = var_59_0
	arg_59_0._totalTime = arg_59_1 - arg_59_0._startTimeStamp
	arg_59_0._lastUpdateTime = arg_59_1
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

	if table.contains(TeamType.SubShipType, monsterTmpData.type) then
		enemyUnit:InitOxygen()
		self:UpdateHostileSubmarine(true)
	end

	BattleDataFunction.AttachWeather(enemyUnit, self._weahter)

	self._freeShipList[monsterUID] = enemyUnit
	self._unitList[monsterUID] = enemyUnit

	--敌人幽灵不可见，也没有碰撞体
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

function BattleDataProxy.UpdateHostileSubmarine(arg_62_0, arg_62_1)
	if arg_62_1 then
		arg_62_0._enemySubmarineCount = arg_62_0._enemySubmarineCount + 1
	else
		arg_62_0._enemySubmarineCount = arg_62_0._enemySubmarineCount - 1
	end

	arg_62_0:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_HOSTILE_SUBMARINE))
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

	if table.contains(TeamType.SubShipType, monsterTemplate.type) then
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
			local var_64_0
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

function BattleDataProxy.EnemyEscape(arg_65_0)
	for iter_65_0, iter_65_1 in pairs(arg_65_0._foeShipList) do
		if iter_65_1:ContainsLabelTag(BattleConfig.ESCAPE_EXPLO_TAG) then
			iter_65_1:SetDeathReason(BattleConst.UnitDeathReason.CLS)
			iter_65_1:DeadAction()
		else
			iter_65_1:RemoveAllAutoWeapon()
			iter_65_1:SetAI(BattleConfig.COUNT_DOWN_ESCAPE_AI_ID)
		end
	end
end

function BattleDataProxy.GetNPCTeam(arg_66_0, arg_66_1)
	if not arg_66_0._teamList[arg_66_1] then
		arg_66_0._teamList[arg_66_1] = ys.Battle.BattleTeamVO.New(arg_66_1)
	end

	return arg_66_0._teamList[arg_66_1]
end

function BattleDataProxy.KillNPCTeam(arg_67_0, arg_67_1)
	local var_67_0 = arg_67_0._teamList[arg_67_1]

	if var_67_0 then
		var_67_0:Dispose()

		arg_67_0._teamList[arg_67_1] = nil
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

-- TODO: 生成主力单位
function BattleDataProxy.SpawnMain(self, arg_69_1, arg_69_2)
	local var_69_0
	local var_69_1 = self:GetFleetByIFF(arg_69_2)
	local var_69_2 = #var_69_1:GetMainList() + 1

	if self._currentStageData.mainUnitPosition and self._currentStageData.mainUnitPosition[arg_69_2] then
		var_69_0 = Clone(self._currentStageData.mainUnitPosition[arg_69_2][var_69_2])
	else
		var_69_0 = Clone(BattleConfig.MAIN_UNIT_POS[arg_69_2][var_69_2])
	end

	local var_69_3 = self:generatePlayerUnit(arg_69_1, arg_69_2, var_69_0, self._commanderBuff)

	var_69_3:SetBornPosition(var_69_0)
	var_69_3:SetMainFleetUnit()

	local var_69_4 = var_69_0.x

	if var_69_4 < self._totalLeftBound or var_69_4 > self._totalRightBound then
		var_69_3:SetImmuneCommonBulletCLD()
	end

	var_69_1:AppendPlayerUnit(var_69_3)
	self:setShipUnitBound(var_69_3)
	BattleDataFunction.AttachWeather(var_69_3, self._weahter)
	self._cldSystem:InitShipCld(var_69_3)

	local var_69_5 = {
		type = BattleConst.UnitType.PLAYER_UNIT,
		unit = var_69_3
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, var_69_5))

	return var_69_3
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

function BattleDataProxy.SpawnManualSub(arg_71_0, arg_71_1, arg_71_2)
	local var_71_0 = arg_71_0:GetVanguardBornCoordinate(arg_71_2)
	local var_71_1 = arg_71_0:generatePlayerUnit(arg_71_1, arg_71_2, BuildVector3(var_71_0), arg_71_0._commanderBuff)

	arg_71_0:GetFleetByIFF(arg_71_2):AddManualSubmarine(var_71_1)
	arg_71_0:setShipUnitBound(var_71_1)
	arg_71_0._cldSystem:InitShipCld(var_71_1)

	local var_71_2 = {
		type = BattleConst.UnitType.SUB_UNIT,
		unit = var_71_1
	}

	arg_71_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, var_71_2))

	return var_71_1
end

-- 被BattleDataProxy.InitUserSupportShipsData调用
function BattleDataProxy.SpawnSupportUnit(self, supportUnitData, IFF)
	local supportUnit = self:generateSupportPlayerUnit(supportUnitData, IFF)

	self:GetFleetByIFF(IFF):AppendSupportUnit(supportUnit)

	return supportUnit
end

function BattleDataProxy.ShutdownPlayerUnit(arg_73_0, arg_73_1)
	local var_73_0 = arg_73_0._unitList[arg_73_1]
	local var_73_1 = var_73_0:GetIFF()
	local var_73_2 = arg_73_0:GetFleetByIFF(var_73_1)

	var_73_2:RemovePlayerUnit(var_73_0)

	local var_73_3 = {}

	if var_73_2:GetFleetAntiAirWeapon():GetRange() == 0 then
		var_73_3.isShow = false
	end

	arg_73_0:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, var_73_3))

	local var_73_4 = {
		unit = var_73_0
	}

	arg_73_0:DispatchEvent(ys.Event.New(BattleEvent.SHUT_DOWN_PLAYER, var_73_4))
end

function BattleDataProxy.updateDeadList(arg_74_0)
	local var_74_0 = #arg_74_0._deadUnitList

	while var_74_0 > 0 do
		arg_74_0._deadUnitList[var_74_0]:Dispose()

		arg_74_0._deadUnitList[var_74_0] = nil
		var_74_0 = var_74_0 - 1
	end
end

function BattleDataProxy.KillUnit(arg_75_0, arg_75_1)
	local var_75_0 = arg_75_0._unitList[arg_75_1]

	if var_75_0 == nil then
		return
	end

	local var_75_1 = var_75_0:GetUnitType()

	arg_75_0._cldSystem:DeleteShipCld(var_75_0)
	var_75_0:Clear()

	arg_75_0._unitList[arg_75_1] = nil

	if arg_75_0._freeShipList[arg_75_1] then
		arg_75_0._freeShipList[arg_75_1] = nil
	end

	local var_75_2 = var_75_0:GetIFF()
	local var_75_3 = var_75_0:GetDeathReason()

	if var_75_0:GetAimBias() then
		local var_75_4 = var_75_0:GetAimBias()

		var_75_4:RemoveCrew(var_75_0)

		if var_75_4:GetCurrentState() == var_75_4.STATE_EXPIRE then
			arg_75_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIM_BIAS, {
				aimBias = var_75_0:GetAimBias()
			}))
		end
	end

	if var_75_0:IsSpectre() then
		arg_75_0._spectreShipList[arg_75_1] = nil
	elseif var_75_2 == BattleConfig.FOE_CODE then
		arg_75_0._foeShipList[arg_75_1] = nil

		if var_75_1 == BattleConst.UnitType.ENEMY_UNIT or var_75_1 == BattleConst.UnitType.BOSS_UNIT then
			if var_75_0:GetTeam() then
				var_75_0:GetTeam():RemoveUnit(var_75_0)
			end

			local var_75_5 = var_75_0:GetTemplate().type

			if table.contains(TeamType.SubShipType, var_75_5) then
				arg_75_0:UpdateHostileSubmarine(false)
			end

			local var_75_6 = var_75_0:GetWaveIndex()

			if var_75_6 and arg_75_0._waveSummonList[var_75_6] then
				arg_75_0._waveSummonList[var_75_6][var_75_0] = nil
			end
		end
	elseif var_75_2 == BattleConfig.FRIENDLY_CODE then
		arg_75_0._friendlyShipList[arg_75_1] = nil
	end

	local var_75_7 = {
		UID = arg_75_1,
		type = var_75_1,
		deadReason = var_75_3,
		unit = var_75_0
	}

	arg_75_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_UNIT, var_75_7))
	table.insert(arg_75_0._deadUnitList, var_75_0)
end

function BattleDataProxy.KillAllEnemy(arg_76_0)
	for iter_76_0, iter_76_1 in pairs(arg_76_0._unitList) do
		if iter_76_1:GetIFF() == BattleConfig.FOE_CODE and iter_76_1:IsAlive() and not iter_76_1:IsBoss() then
			iter_76_1:DeadAction()
		end
	end
end

function BattleDataProxy.KillSubmarineByIFF(arg_77_0, arg_77_1)
	for iter_77_0, iter_77_1 in pairs(arg_77_0._unitList) do
		if iter_77_1:GetIFF() == arg_77_1 and iter_77_1:IsAlive() and table.contains(TeamType.SubShipType, iter_77_1:GetTemplate().type) and not iter_77_1:IsBoss() then
			iter_77_1:DeadAction()
		end
	end
end

function BattleDataProxy.KillAllAircraft(arg_78_0)
	for iter_78_0, iter_78_1 in pairs(arg_78_0._aircraftList) do
		iter_78_1:Clear()

		local var_78_0 = {
			UID = iter_78_0
		}

		arg_78_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, var_78_0))

		arg_78_0._aircraftList[iter_78_0] = nil
	end
end

function BattleDataProxy.KillWaveSummonMonster(arg_79_0, arg_79_1)
	local var_79_0 = arg_79_0._waveSummonList[arg_79_1]

	if var_79_0 then
		for iter_79_0, iter_79_1 in pairs(var_79_0) do
			local var_79_1 = iter_79_0:GetUniqueID()

			arg_79_0:KillUnit(var_79_1)
		end
	end

	arg_79_0._waveSummonList[arg_79_1] = nil
end

function BattleDataProxy.IsThereBoss(arg_80_0)
	return arg_80_0:GetActiveBossCount() > 0
end

function BattleDataProxy.GetActiveBossCount(arg_81_0)
	local var_81_0 = 0

	for iter_81_0, iter_81_1 in pairs(arg_81_0:GetUnitList()) do
		if iter_81_1:IsBoss() and iter_81_1:IsAlive() then
			var_81_0 = var_81_0 + 1
		end
	end

	return var_81_0
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

	self._spectreShipList[UID] = supportUnit

	supportUnit:SetPosition(Clone(BattleConfig.AirSupportUnitPos))

	return supportUnit
end

-- TODO
-- 切换幽灵状态
function BattleDataProxy.SwitchSpectreUnit(arg_86_0, arg_86_1)
	local var_86_0 = arg_86_1:GetUniqueID()
	local var_86_1 = arg_86_1:GetIFF() == BattleConfig.FRIENDLY_CODE and arg_86_0._friendlyShipList or arg_86_0._foeShipList

	if arg_86_1:IsSpectre() then
		var_86_1[var_86_0] = nil
		arg_86_0._spectreShipList[var_86_0] = arg_86_1

		for iter_86_0, iter_86_1 in pairs(arg_86_0._AOEList) do
			iter_86_1:ForceExit(arg_86_1:GetUniqueID())
		end

		arg_86_0._cldSystem:DeleteShipCld(arg_86_1)
	else
		arg_86_0._spectreShipList[var_86_0] = nil
		var_86_1[var_86_0] = arg_86_1

		arg_86_1:ActiveCldBox()
		arg_86_0._cldSystem:InitShipCld(arg_86_1)
	end
end

function BattleDataProxy.GetUnitList(arg_87_0)
	return arg_87_0._unitList
end

function BattleDataProxy.GetFriendlyShipList(arg_88_0)
	return arg_88_0._friendlyShipList
end

function BattleDataProxy.GetFoeShipList(arg_89_0)
	return arg_89_0._foeShipList
end

function BattleDataProxy.GetFoeAircraftList(arg_90_0)
	return arg_90_0._foeAircraftList
end

function BattleDataProxy.GetFreeShipList(arg_91_0)
	return arg_91_0._freeShipList
end

function BattleDataProxy.GetSpectreShipList(arg_92_0)
	return arg_92_0._spectreShipList
end

function BattleDataProxy.GenerateUnitID(arg_93_0)
	arg_93_0._unitCount = arg_93_0._unitCount + 1

	return arg_93_0._unitCount
end

function BattleDataProxy.GetCountDown(arg_94_0)
	return arg_94_0._countDown
end

-- 有点没怎么用过，一般都是走通用的SpawnAircraft
-- 这是敌方飞机的生成，没有Mother Unit的
function BattleDataProxy.SpawnAirFighter(arg_95_0, arg_95_1)
	local var_95_0 = #arg_95_0._airFighterList + 1
	local var_95_1 = BattleDataFunction.GetFormationTmpDataFromID(arg_95_1.formation).pos_offset
	local var_95_2 = {
		currentNumber = 0,
		templateID = arg_95_1.templateID,
		totalNumber = arg_95_1.totalNumber or 0,
		onceNumber = arg_95_1.onceNumber,
		timeDelay = arg_95_1.interval or 3,
		maxTotalNumber = arg_95_1.maxTotalNumber or 15
	}

	local function var_95_3(arg_96_0)
		local var_96_0 = var_95_2.currentNumber

		if var_96_0 < var_95_2.totalNumber then
			var_95_2.currentNumber = var_96_0 + 1

			local var_96_1 = arg_95_0:CreateAirFighter(arg_95_1)

			var_96_1:SetFormationOffset(var_95_1[arg_96_0])
			var_96_1:SetFormationIndex(arg_96_0)
			var_96_1:SetDeadCallBack(function()
				var_95_2.totalNumber = var_95_2.totalNumber - 1
				var_95_2.currentNumber = var_95_2.currentNumber - 1

				arg_95_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_FIGHTER_ICON, {
					index = var_95_0
				}))
				arg_95_0:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_AIR_SUPPORT_LABEL, {}))
			end)
			var_96_1:SetLiveCallBack(function()
				var_95_2.currentNumber = var_95_2.currentNumber - 1
			end)
		end
	end

	local function var_95_4()
		local var_99_0 = var_95_2.onceNumber

		if var_95_2.totalNumber > 0 then
			for iter_99_0 = 1, var_99_0 do
				var_95_3(iter_99_0)
			end
		else
			pg.TimeMgr.GetInstance():RemoveBattleTimer(var_95_2.timer)

			var_95_2.timer = nil
		end
	end

	arg_95_0._airFighterList[var_95_0] = var_95_2

	arg_95_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_AIR_FIGHTER_ICON, {
		index = var_95_0
	}))
	arg_95_0:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_AIR_SUPPORT_LABEL, {}))

	var_95_2.timer = pg.TimeMgr.GetInstance():AddBattleTimer("striker", -1, arg_95_1.interval, var_95_4)
end

function BattleDataProxy.ClearAirFighterTimer(arg_100_0)
	for iter_100_0, iter_100_1 in ipairs(arg_100_0._airFighterList) do
		pg.TimeMgr.GetInstance():RemoveBattleTimer(iter_100_1.timer)

		iter_100_1.timer = nil
	end

	arg_100_0._airFighterList = {}
end

function BattleDataProxy.KillAllAirStrike(arg_101_0)
	for iter_101_0, iter_101_1 in pairs(arg_101_0._aircraftList) do
		if iter_101_1.__name == ys.Battle.BattleAirFighterUnit.__name then
			arg_101_0._cldSystem:DeleteAircraftCld(iter_101_1)

			iter_101_1._aliveState = false
			arg_101_0._aircraftList[iter_101_0] = nil
			arg_101_0._foeAircraftList[iter_101_0] = nil

			local var_101_0 = {
				UID = iter_101_0
			}

			arg_101_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, var_101_0))
		end
	end

	local var_101_1 = true

	for iter_101_2, iter_101_3 in pairs(arg_101_0._foeAircraftList) do
		var_101_1 = false

		break
	end

	if var_101_1 then
		arg_101_0:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, {
			isShow = false
		}))
	end

	for iter_101_4, iter_101_5 in ipairs(arg_101_0._airFighterList) do
		iter_101_5.totalNumber = 0

		arg_101_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_FIGHTER_ICON, {
			index = iter_101_4
		}))
		pg.TimeMgr.GetInstance():RemoveBattleTimer(iter_101_5.timer)

		iter_101_5.timer = nil
	end

	arg_101_0._airFighterList = {}
end

function BattleDataProxy.GetAirFighterInfo(arg_102_0, arg_102_1)
	return arg_102_0._airFighterList[arg_102_1]
end

function BattleDataProxy.GetAirFighterList(arg_103_0)
	return arg_103_0._airFighterList
end

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

function BattleDataProxy.CreateAirFighter(arg_105_0, arg_105_1)
	local var_105_0 = arg_105_0:GenerateAircraftID()
	local var_105_1 = BattleDataFunction.CreateAirFighterUnit(var_105_0, arg_105_1)

	arg_105_0:doCreateAirUnit(var_105_0, var_105_1, BattleConst.UnitType.AIRFIGHTER_UNIT, true)

	return var_105_1
end

-- TODO
-- 处理碰撞、摄像机、事件派发等
function BattleDataProxy.doCreateAirUnit(arg_106_0, arg_106_1, arg_106_2, arg_106_3, arg_106_4)
	arg_106_0._aircraftList[arg_106_1] = arg_106_2

	arg_106_0._cldSystem:InitAircraftCld(arg_106_2)
	arg_106_2:SetBound(arg_106_0._leftZoneUpperBound, arg_106_0._leftZoneLowerBound)
	arg_106_2:SetViewBoundData(arg_106_0._cameraTop, arg_106_0._cameraBottom, arg_106_0._cameraLeft, arg_106_0._cameraRight)
	arg_106_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, {
		unit = arg_106_2,
		type = arg_106_3
	}))

	arg_106_4 = arg_106_4 or false

	if arg_106_4 then
		arg_106_0._foeAircraftList[arg_106_1] = arg_106_2

		arg_106_0:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, {
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

	local var_107_2 = true

	for iter_107_0, iter_107_1 in pairs(self._foeAircraftList) do
		var_107_2 = false

		break
	end

	if var_107_2 then
		self:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, {
			isShow = false
		}))
	end

	local var_107_3 = {
		UID = aircraftID
	}

	self:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, var_107_3))
end

function BattleDataProxy.GetAircraftList(arg_108_0)
	return arg_108_0._aircraftList
end

function BattleDataProxy.GenerateAircraftID(arg_109_0)
	arg_109_0._aircraftCount = arg_109_0._aircraftCount + 1

	return arg_109_0._aircraftCount
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

function BattleDataProxy.RemoveBulletUnit(arg_111_0, arg_111_1)
	local var_111_0 = arg_111_0._bulletList[arg_111_1]

	if var_111_0 == nil then
		return
	end

	var_111_0:DamageUnitListWriteback()

	if var_111_0:GetIsCld() then
		arg_111_0._cldSystem:DeleteBulletCld(var_111_0)
	end

	arg_111_0._bulletList[arg_111_1] = nil

	local var_111_1 = {
		UID = arg_111_1
	}

	arg_111_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_BULLET, var_111_1))
	var_111_0:Dispose()
end

function BattleDataProxy.GetBulletList(arg_112_0)
	return arg_112_0._bulletList
end

function BattleDataProxy.GenerateBulletID(arg_113_0)
	local var_113_0 = arg_113_0._bulletCount + 1

	arg_113_0._bulletCount = var_113_0

	return var_113_0
end
-- TODO
function BattleDataProxy.CLSBullet(arg_114_0, arg_114_1, arg_114_2)
	local var_114_0 = true

	if arg_114_0._battleInitData.battleType == SYSTEM_DUEL then
		var_114_0 = false
	end

	if var_114_0 then
		for iter_114_0, iter_114_1 in pairs(arg_114_0._bulletList) do
			if iter_114_1:GetIFF() ~= arg_114_1 or not iter_114_1:GetExist() or iter_114_1:ImmuneCLS() or iter_114_1:ImmuneBombCLS() and arg_114_2 then
				-- block empty
			else
				arg_114_0:RemoveBulletUnit(iter_114_0)
			end
		end
	end
end

function BattleDataProxy.CLSAircraft(arg_115_0, arg_115_1)
	for iter_115_0, iter_115_1 in pairs(arg_115_0._aircraftList) do
		if iter_115_1:GetIFF() == arg_115_1 then
			iter_115_1:Clear()

			local var_115_0 = {
				UID = iter_115_0
			}

			arg_115_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIR_CRAFT, var_115_0))

			arg_115_0._aircraftList[iter_115_0] = nil
		end
	end
end

function BattleDataProxy.CLSMinion(arg_116_0)
	for iter_116_0, iter_116_1 in pairs(arg_116_0._unitList) do
		if iter_116_1:GetIFF() == BattleConfig.FOE_CODE and iter_116_1:IsAlive() and not iter_116_1:IsBoss() then
			iter_116_1:SetDeathReason(BattleConst.UnitDeathReason.CLS)
			iter_116_1:DeadAction()
		end
	end
end

function var_0_9.CLSAOE(self)
	for iter_117_0, iter_117_1 in pairs(self._AOEList) do
		if iter_117_1:GetSource() == iter_117_1.SOURCE_BULLET_9 then
			self:RemoveAreaOfEffect(iter_117_0)
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

function BattleDataProxy.SpawnCubeArea(arg_118_0, arg_118_1, arg_118_2, arg_118_3, arg_118_4, arg_118_5, arg_118_6, arg_118_7, arg_118_8, arg_118_9)
	arg_118_8 = arg_118_8 or false

	local var_118_0 = arg_118_0:GenerateAreaID()
	local var_118_1 = ys.Battle.BattleAOEData.New(var_118_0, arg_118_2, arg_118_7, arg_118_9)
	local var_118_2 = Clone(arg_118_3)

	var_118_1:SetPosition(var_118_2)
	var_118_1:SetWidth(arg_118_4)
	var_118_1:SetHeight(arg_118_5)
	var_118_1:SetAreaType(BattleConst.AreaType.CUBE)
	var_118_1:SetLifeTime(arg_118_6)
	var_118_1:SetFieldType(arg_118_1)
	var_118_1:SetOpponentAffected(not arg_118_7)
	arg_118_0:CreateAreaOfEffect(var_118_1)

	return var_118_1
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

function BattleDataProxy.SpawnLastingEllipseArea(arg_120_0, arg_120_1, arg_120_2, arg_120_3, arg_120_4, arg_120_5, arg_120_6, arg_120_7, arg_120_8, arg_120_9, arg_120_10, arg_120_11, arg_120_12)
	arg_120_9 = arg_120_9 or false

	local var_120_0 = arg_120_0:GenerateAreaID()
	local var_120_1 = ys.Battle.BattleLastingAOEData.New(var_120_0, arg_120_2, arg_120_7, arg_120_8, arg_120_11, arg_120_12)
	local var_120_2 = Clone(arg_120_3)

	var_120_1:SetPosition(var_120_2)
	var_120_1:SetWidth(arg_120_4)
	var_120_1:SetHeight(arg_120_5)
	var_120_1:SetAreaType(BattleConst.AreaType.ELLIPSE)
	var_120_1:SetLifeTime(arg_120_6)
	var_120_1:SetFieldType(arg_120_1)
	var_120_1:SetOpponentAffected(not arg_120_8)
	arg_120_0:CreateAreaOfEffect(var_120_1)

	if arg_120_9 and arg_120_9 ~= "" then
		local var_120_3 = {
			area = var_120_1,
			FXID = arg_120_9
		}

		arg_120_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_AREA, var_120_3))
	end

	return var_120_1
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

function BattleDataProxy.CreateAreaOfEffect(arg_123_0, arg_123_1)
	arg_123_0._AOEList[arg_123_1:GetUniqueID()] = arg_123_1

	arg_124_0._cldSystem:InitAOECld(arg_124_1)
	arg_124_1:StartTimer()
end

function BattleDataProxy.RemoveAreaOfEffect(arg_124_0, arg_124_1)
	local var_124_0 = arg_124_0._AOEList[arg_124_1]

	if not var_125_0 then
		return
	end

	var_125_0:Dispose()

	arg_125_0._AOEList[arg_125_1] = nil

	arg_124_0._cldSystem:DeleteAOECld(var_124_0)
	arg_124_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AREA, {
		id = arg_124_1
	}))
end

function BattleDataProxy.GetAOEList(arg_125_0)
	return arg_125_0._AOEList
end

function BattleDataProxy.GenerateAreaID(arg_126_0)
	arg_126_0._AOECount = arg_126_0._AOECount + 1

	return arg_127_0._AOECount
end

function BattleDataProxy.SpawnWall(arg_127_0, arg_127_1, arg_127_2, arg_127_3, arg_127_4)
	local var_127_0 = arg_127_0:GenerateWallID()
	local var_127_1 = ys.Battle.BattleWallData.New(var_127_0, arg_127_1, arg_127_2, arg_127_3, arg_127_4)

	arg_128_0._wallList[var_128_0] = var_128_1

	arg_128_0._cldSystem:InitWallCld(var_128_1)

	return var_128_1
end

function BattleDataProxy.RemoveWall(arg_128_0, arg_128_1)
	local var_128_0 = arg_128_0._wallList[arg_128_1]

	arg_129_0._wallList[arg_129_1] = nil

	arg_129_0._cldSystem:DeleteWallCld(var_129_0)
end

function BattleDataProxy.SpawnShelter(arg_129_0, arg_129_1, arg_129_2)
	local var_129_0 = arg_129_0:GernerateShelterID()
	local var_129_1 = ys.Battle.BattleShelterData.New(var_129_0)

	arg_130_0._shelterList[var_130_0] = var_130_1

	return var_130_1
end

function BattleDataProxy.RemoveShelter(arg_130_0, arg_130_1)
	local var_130_0 = arg_130_0._shelterList[arg_130_1]
	local var_130_1 = {
		uid = arg_130_1
	}

	arg_130_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_SHELTER, var_130_1))
	var_130_0:Deactive()

	arg_131_0._shelterList[arg_131_1] = nil
end

function BattleDataProxy.GetWallList(arg_131_0)
	return arg_131_0._wallList
end

function BattleDataProxy.GenerateWallID(arg_132_0)
	arg_132_0._wallIndex = arg_132_0._wallIndex + 1

	return arg_133_0._wallIndex
end

function BattleDataProxy.GernerateShelterID(arg_133_0)
	arg_133_0._shelterIndex = arg_133_0._shelterIndex + 1

	return arg_134_0._shelterIndex
end

function BattleDataProxy.SpawnEnvironment(arg_134_0, arg_134_1)
	local var_134_0 = arg_134_0:GernerateEnvironmentID()
	local var_134_1 = ys.Battle.BattleEnvironmentUnit.New(var_134_0, BattleConfig.FOE_CODE)

	var_135_1:SetTemplate(arg_135_1)

	local var_135_2 = var_135_1:GetBehaviours()
	local var_135_3 = Vector3(arg_135_1.coordinate[1], arg_135_1.coordinate[2], arg_135_1.coordinate[3])

	local function var_135_4(arg_136_0)
		local var_136_0 = {}

		for iter_136_0, iter_136_1 in ipairs(arg_136_0) do
			if iter_136_1.Active then
				local var_136_1 = arg_135_0._unitList[iter_136_1.UID]

				if not var_136_1:IsSpectre() then
					table.insert(var_136_0, var_136_1)
				end
			end
		end

		var_135_1:UpdateFrequentlyCollide(var_136_0)
	end

	local function var_135_5()
		return
	end

	local function var_135_6()
		return
	end

	local var_134_7 = arg_134_1.field_type or BattleConst.BulletField.SURFACE
	local var_134_8 = arg_134_1.IFF or BattleConfig.FOE_CODE
	local var_134_9 = 0
	local var_134_10

	if #arg_135_1.cld_data == 1 then
		local var_135_11 = arg_135_1.cld_data[1]

		var_135_10 = arg_135_0:SpawnLastingColumnArea(var_135_7, var_135_8, var_135_3, var_135_11, var_135_9, var_135_4, var_135_5, false, arg_135_1.prefab, var_135_6, true)
	else
		local var_135_12 = arg_135_1.cld_data[1]
		local var_135_13 = arg_135_1.cld_data[2]

		var_135_10 = arg_135_0:SpawnLastingCubeArea(var_135_7, var_135_8, var_135_3, var_135_12, var_135_13, var_135_9, var_135_4, var_135_5, false, arg_135_1.prefab, var_135_6, true)
	end

	var_135_1:SetAOEData(var_135_10)

	arg_135_0._environmentList[var_135_0] = var_135_1

	return var_135_1
end

function BattleDataProxy.RemoveEnvironment(arg_138_0, arg_138_1)
	local var_138_0 = arg_138_0._environmentList[arg_138_1]
	local var_138_1 = var_138_0:GetAOEData()

	arg_139_0:RemoveAreaOfEffect(var_139_1:GetUniqueID())
	var_139_0:Dispose()

	arg_139_0._environmentList[arg_139_1] = nil
end

function BattleDataProxy.DispatchWarning(arg_139_0, arg_139_1, arg_139_2)
	arg_139_0:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_ENVIRONMENT_WARNING, {
		isActive = arg_139_1
	}))
end

function BattleDataProxy.GetEnvironmentList(arg_140_0)
	return arg_140_0._environmentList
end

function BattleDataProxy.GernerateEnvironmentID(arg_141_0)
	arg_141_0._environmentIndex = arg_141_0._environmentIndex + 1

	return arg_142_0._environmentIndex
end

function BattleDataProxy.SpawnEffect(arg_142_0, arg_142_1, arg_142_2, arg_142_3)
	arg_142_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_EFFECT, {
		FXID = arg_142_1,
		position = arg_142_2,
		localScale = arg_142_3
	}))
end

function BattleDataProxy.SpawnUIFX(arg_143_0, arg_143_1, arg_143_2, arg_143_3, arg_143_4)
	arg_143_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_UI_FX, {
		FXID = arg_143_1,
		position = arg_143_2,
		localScale = arg_143_3
	}))
end

function BattleDataProxy.SpawnCameraFX(arg_144_0, arg_144_1, arg_144_2, arg_144_3, arg_144_4)
	arg_144_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_CAMERA_FX, {
		FXID = arg_144_1,
		position = arg_144_2,
		localScale = arg_144_3,
		orderDiff = arg_144_4
	}))
end

function BattleDataProxy.GetFriendlyCode(arg_145_0)
	return arg_145_0._friendlyCode
end

function BattleDataProxy.GetFoeCode(arg_146_0)
	return arg_146_0._foeCode
end

function BattleDataProxy.GetOppoSideCode(arg_147_0)
	if arg_147_0 == BattleConfig.FRIENDLY_CODE then
		return BattleConfig.FOE_CODE
	elseif arg_147_0 == BattleConfig.FOE_CODE then
		return BattleConfig.FRIENDLY_CODE
	end
end

function BattleDataProxy.GetStatistics(arg_148_0)
	return arg_148_0._statistics
end

function BattleDataProxy.BlockManualCast(arg_149_0, arg_149_1)
	local var_149_0 = arg_149_1 and 1 or -1

	for iter_150_0, iter_150_1 in pairs(arg_150_0._fleetList) do
		iter_150_1:SetWeaponBlock(var_150_0)
	end
end

function BattleDataProxy.JamManualCast(arg_150_0, arg_150_1)
	arg_150_0:DispatchEvent(ys.Event.New(BattleEvent.JAMMING, {
		jammingFlag = arg_150_1
	}))
end

-- TODO
-- 潜艇出击逻辑
-- 被BattleControllerWeaponCommand.TryAutoSub(自律召唤潜艇)或BattleSkillView的_subStriveBtn的callback调用
function BattleDataProxy.SubmarineStrike(self, IFF)
	local fleet = self:GetFleetByIFF(IFF)
	local subAidVO = fleet:GetSubAidVO()

	if fleet:GetWeaponBlock() or subAidVO:GetCurrent() < 1 then
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

function BattleDataProxy.GetWaveFlags(self)
	return self._waveFlags
end

function BattleDataProxy.AddWaveFlag(arg_153_0, arg_153_1)
	if not arg_153_1 then
		return
	end

	local var_154_0 = arg_154_0:GetWaveFlags()

	if table.contains(var_154_0, arg_154_1) then
		return
	end

	table.insert(var_154_0, arg_154_1)
end

function BattleDataProxy.RemoveFlag(arg_154_0, arg_154_1)
	if not arg_154_1 then
		return
	end

	local var_155_0 = arg_155_0:GetWaveFlags()

	if not table.contains(var_155_0, arg_155_1) then
		return
	end

	table.removebyvalue(var_155_0, arg_155_1)
end

function BattleDataProxy.DispatchCustomWarning(arg_155_0, arg_155_1)
	arg_155_0:DispatchEvent(ys.Event.New(BattleEvent.EDIT_CUSTOM_WARNING_LABEL, {
		labelData = arg_155_1
	}))
end

function BattleDataProxy.DispatchGridmanSkill(arg_156_0, arg_156_1, arg_156_2)
	arg_156_0:DispatchEvent(ys.Event.New(BattleEvent.GRIDMAN_SKILL_FLOAT, {
		type = arg_156_1,
		IFF = arg_156_2
	}))
end

function BattleDataProxy.SpawnFusionUnit(arg_157_0, arg_157_1, arg_157_2, arg_157_3, arg_157_4)
	local var_157_0 = Clone(arg_157_1:GetPosition())
	local var_157_1 = arg_157_1:GetIFF()
	local var_157_2 = arg_157_0:generatePlayerUnit(arg_157_2, var_157_1, var_157_0, arg_157_0._commanderBuff)

	BattleAttr.SetFusionAttrFromElement(var_157_2, arg_157_1, arg_157_3, arg_157_4)
	var_157_2:SetCurrentHP(var_157_2:GetMaxHP())
	arg_157_1:GetFleetVO():AppendPlayerUnit(var_157_2)
	arg_157_0:setShipUnitBound(var_157_2)
	BattleDataFunction.AttachWeather(var_157_2, arg_157_0._weahter)
	arg_157_0._cldSystem:InitShipCld(var_157_2)

	local var_157_3 = {
		type = BattleConst.UnitType.PLAYER_UNIT,
		unit = var_157_2
	}

	arg_157_0:DispatchEvent(ys.Event.New(BattleEvent.ADD_UNIT, var_157_3))

	return var_158_2
end

function BattleDataProxy.DefusionUnit(arg_158_0, arg_158_1)
	local var_158_0 = arg_158_1:GetIFF()
	local var_158_1 = arg_158_0:GetFleetByIFF(var_158_0)

	var_159_1:RemovePlayerUnit(arg_159_1)

	local var_159_2 = {}

	if var_159_1:GetFleetAntiAirWeapon():GetRange() == 0 then
		var_159_2.isShow = false
	end

	arg_158_0:DispatchEvent(ys.Event.New(BattleEvent.ANTI_AIR_AREA, var_158_2))
	arg_158_1:SetDeathReason(BattleConst.UnitDeathReason.DEFUSION)
	arg_158_0:KillUnit(arg_158_1:GetUniqueID())
end

function BattleDataProxy.FreezeUnit(arg_159_0, arg_159_1)
	BattleAttr.SetCurrent(arg_159_1, ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY, BattleConfig.FUSION_ELEMENT_UNIT_TYPE)
	arg_159_1:UpdateBlindInvisibleBySpectre()
	arg_159_0:SwitchSpectreUnit(arg_159_1)

	if arg_160_1:GetAimBias() then
		local var_160_0 = arg_160_1:GetAimBias()

		var_160_0:RemoveCrew(arg_160_1)

		if var_159_0:GetCurrentState() == var_159_0.STATE_EXPIRE then
			arg_159_0:DispatchEvent(ys.Event.New(BattleEvent.REMOVE_AIM_BIAS, {
				aimBias = arg_159_1:GetAimBias()
			}))
		end
	end

	arg_160_1:Freeze()

	local var_160_1 = arg_160_1:GetFleetVO()

	if var_160_1 then
		var_160_1:FreezeUnit(arg_160_1)
	end
end

function BattleDataProxy.ActiveFreezeUnit(arg_160_0, arg_160_1)
	BattleAttr.SetCurrent(arg_160_1, ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY, BattleConfig.PLAYER_DEFAULT)
	arg_160_1:UpdateBlindInvisibleBySpectre()
	arg_160_0:SwitchSpectreUnit(arg_160_1)
	BattleDataFunction.AttachWeather(arg_160_1, arg_160_0._weahter)
	arg_160_1:ActiveFreeze()

	local var_161_0 = arg_161_1:GetFleetVO()

	if var_161_0 then
		var_161_0:ActiveFreezeUnit(arg_161_1)
	end
end

function BattleDataProxy.GetFleetLegal(arg_161_0, arg_161_1, arg_161_2)
	if arg_161_2 == SYSTEM_DUEL or arg_161_2 == SYSTEM_PERFORM or arg_161_2 == SYSTEM_SUB_ROUTINE or arg_161_2 == SYSTEM_CARDPUZZLE or arg_161_2 == SYSTEM_PROLOGUE or arg_161_2 == SYSTEM_DODGEM or arg_161_2 == SYSTEM_SIMULATION or arg_161_2 == SYSTEM_SUBMARINE_RUN or arg_161_2 == SYSTEM_DEBUG or arg_161_2 == SYSTEM_AIRFIGHT then
		return true
	else
		local unitList = self:GetFleetByIFF(arg_162_1)

		if #unitList:GetScoutList() == 0 or not unitList:GetFlagShip():IsAlive() then
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

	for _, minion in pairs(self._minionShipList) do
		minion:TriggerBuff(BattleConst.BuffEffectType.ON_FINISH_GAME)
	end
end
