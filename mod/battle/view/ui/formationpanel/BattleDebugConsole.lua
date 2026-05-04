ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleDebugConsole = class("BattleDebugConsole")
ys.Battle.BattleDebugConsole.__name = "BattleDebugConsole"

local BattleDebugConsole = ys.Battle.BattleDebugConsole

-- 保存原始的Proxy方法以便恢复
BattleDebugConsole.ProxyUpdateNormal = ys.Battle.BattleDataProxy.Update
BattleDebugConsole.ProxyUpdateAutoComponentNormal = ys.Battle.BattleDataProxy.UpdateAutoComponent
-- 自动组件功能键名
BattleDebugConsole.UPDATE_PLAYER_WEAPON = "updatePlayerWeapon"
BattleDebugConsole.UPDATE_MONSTER_WEAPON = "updateMonsterWeapon"
BattleDebugConsole.UPDATE_MONSTER_AI = "updateMonsterAI"

--- 战斗调试控制台，仅在SYSTEM_DEBUG或SYSTEM_CARDPUZZLE模式下启用
--- @param go GameObject 控制台的GameObject
--- @param state table 战斗状态对象
function BattleDebugConsole.Ctor(self, go, state)
	self._go = go
	self._state = state
	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)

	self:initComponent()

	-- 只在调试或卡牌战斗模式下启用完整功能
	if self._dataProxy:GetInitData().battleType == SYSTEM_DEBUG or self._dataProxy:GetInitData().battleType == SYSTEM_CARDPUZZLE then
		self:initData()
		self:initDebug()
	else
		SetActive(self._debug, false)
	end
end

--- 初始化调试按钮面板
function BattleDebugConsole.initDebug(self)
	-- 随机生成敌人
	self._randomEngage = self._debug:Find("spawn_enemy")

	onButton(nil, self._randomEngage, function()
		local randomIndex = math.random(#self._monsterArray)

		self:spawnEnemy(self._monsterArray[randomIndex], 15, 25, 25, 65)
	end, SFX_PANEL)

	-- 指定ID生成敌人
	self._summon = self._debug:Find("summon_enemy")
	self._summonID = self._debug:Find("model_id"):GetComponent("InputField")
	self._minX = self._debug:Find("x_min"):GetComponent("InputField")
	self._manX = self._debug:Find("x_max"):GetComponent("InputField")
	self._minZ = self._debug:Find("z_min"):GetComponent("InputField")
	self._manZ = self._debug:Find("z_max"):GetComponent("InputField")

	onButton(nil, self._summon, function()
		local modelID = tonumber(self._summonID.text)
		local xMin = tonumber(self._minX.text)
		local xMax = tonumber(self._manX.text)
		local zMin = tonumber(self._minZ.text)
		local zMax = tonumber(self._manZ.text)

		self:spawnEnemy(modelID, xMin, xMax, zMin, zMax)
	end, SFX_PANEL)

	-- 清空所有敌人
	self._killAllEnemy = self._debug:Find("clear_enemy")

	onButton(nil, self._killAllEnemy, function()
		self._dataProxy:KillAllEnemy()
	end, SFX_PANEL)

	-- 生成空袭
	self._summonStrike = self._debug:Find("spawn_strike")
	self._summonStrikeID = self._debug:Find("air_model_id"):GetComponent("InputField")
	self._summonStrikeTotal = self._debug:Find("total"):GetComponent("InputField")
	self._summonStrikeSingular = self._debug:Find("once"):GetComponent("InputField")
	self._summonStrikeInterval = self._debug:Find("interval"):GetComponent("InputField")

	onButton(nil, self._summonStrike, function()
		local aircraftID = tonumber(self._summonStrikeID.text)
		local totalNum = tonumber(self._summonStrikeTotal.text)
		local onceNum = tonumber(self._summonStrikeSingular.text)
		local interval = tonumber(self._summonStrikeInterval.text)

		self:spawnStrike(aircraftID, totalNum, onceNum, interval)
	end, SFX_PANEL)

	-- 清空所有空袭飞机
	self._killAllStrike = self._debug:Find("clear_strike")

	onButton(nil, self._killAllStrike, function()
		self._dataProxy:KillAllAirStrike()
	end, SFX_PANEL)

	-- 阻塞/恢复各个更新模块的Toggle
	self._blockCld = self._debug:Find("all_cld")
	self._blockPlayerWeapon = self._debug:Find("player_weapon")
	self._blockMonsterWeapon = self._debug:Find("monster_weapon")
	self._blockMonsterAI = self._debug:Find("monster_motion")

	onToggle(nil, self._blockCld, function(isOn)
		if isOn then
			self._dataProxy.Update = BattleDebugConsole.ProxyUpdateNormal
		else
			self._dataProxy.Update = self._dataProxy.__debug__BlockCldUpdate__
		end
	end, SFX_PANEL)
	onToggle(nil, self._blockPlayerWeapon, function(isOn)
		if isOn then
			self._autoComponentFuncList.updatePlayerWeapon = self._updatePlayerWeapon
		else
			self._autoComponentFuncList.updatePlayerWeapon = nil
		end
	end, SFX_PANEL)
	onToggle(nil, self._blockMonsterWeapon, function(isOn)
		if isOn then
			self._autoComponentFuncList.updateMonsterWeapon = self._updateMonsterWeapon
		else
			self._autoComponentFuncList.updateMonsterWeapon = nil
		end
	end, SFX_PANEL)
	onToggle(nil, self._blockMonsterAI, function(isOn)
		if isOn then
			self._autoComponentFuncList.updateMonsterAI = self._updateMonsterAI
		else
			self._autoComponentFuncList.updateMonsterAI = nil
		end
	end, SFX_PANEL)

	-- 设置关卡等级
	self._setDungeonLevel = self._debug:Find("dungeon_level")
	self._dungeonLevel = self._debug:Find("level_input"):GetComponent("InputField")

	onButton(nil, self._setDungeonLevel, function()
		self._dataProxy:SetDungeonLevel(tonumber(self._dungeonLevel.text))
	end, SFX_PANEL)

	-- 清除所有子弹
	self._clsBullet = self._debug:Find("cls_bullet")

	onButton(nil, self._clsBullet, function()
		self._dataProxy:CLSBullet(BattleConfig.FRIENDLY_CODE)
		self._dataProxy:CLSBullet(BattleConfig.FOE_CODE)
	end, SFX_PANEL)
end

--- 初始化调试数据（舰队列表、怪物列表、自动更新函数）
function BattleDebugConsole.initData(self)
	self._fleetList = self._dataProxy:GetFleetList()
	self._freeShipList = self._dataProxy:GetFreeShipList()
	self._monsterArray = {}

	-- 收集所有可用敌人模板ID
	for _, enemyID in ipairs(pg.enemy_data_statistics.all) do
		if type(enemyID) == "number" and enemyID <= 10000000 then
			table.insert(self._monsterArray, enemyID)
		end
	end

	-- 更新玩家武器自动组件
	function self._updatePlayerWeapon(timeStamp)
		for _, fleet in pairs(self._fleetList) do
			fleet:UpdateAutoComponent(timeStamp)
		end
	end

	-- 更新怪物武器
	function self._updateMonsterWeapon(timeStamp)
		for _, ship in pairs(self._freeShipList) do
			ship:UpdateWeapon(timeStamp)
		end
	end

	-- 更新怪物AI/运动
	function self._updateMonsterAI(timeStamp)
		for teamKey, team in pairs(self._dataProxy._teamList) do
			if team:IsFatalDamage() then
				self._dataProxy:KillNPCTeam(teamKey)
			else
				team:UpdateMotion()
			end
		end
	end

	-- 将各更新函数注册到自动组件功能表中
	self._autoComponentFuncList = {}
	self._autoComponentFuncList.updatePlayerWeapon = self._updatePlayerWeapon
	self._autoComponentFuncList.updateMonsterWeapon = self._updateMonsterWeapon
	self._autoComponentFuncList.updateMonsterAI = self._updateMonsterAI

	-- 替换DataProxy的UpdateAutoComponent为调试版本（包含所有注册的功能）
	local function debugUpdateAutoComponent(proxy, timeStamp)
		for _, func in pairs(self._autoComponentFuncList) do
			func(timeStamp)
		end
	end

	self._dataProxy.UpdateAutoComponent = debugUpdateAutoComponent
end

--- 初始化公共组件面板（伤害锁定、波次触发等）
function BattleDebugConsole.initComponent(self)
	self._base = self._go:Find("bg")
	self._common = self._base:Find("common")
	self._debug = self._base:Find("debug")
	self._exitBtn = self._common:Find("close")

	onButton(nil, self._exitBtn, function()
		self:SetActive(false)
	end, SFX_PANEL)

	self._activeReference = self._common:Find("reference_switch")

	onButton(nil, self._activeReference, function()
		self:activeReference()
	end, SFX_PANEL)

	-- 伤害锁定开关
	self._lockCommonDMG = self._common:Find("common_damage")
	self._lockS2MDMG = self._common:Find("ship2main_damage")
	self._lockA2MDMG = self._common:Find("aircraft2main_damage")
	self._lockCrushDMG = self._common:Find("crush_damage")

	onToggle(nil, self._lockCommonDMG, function(isOn)
		self._dataProxy:SetupCalculateDamage(isOn and ys.Battle.BattleFormulas.CalcDamageLock or nil)
	end, SFX_PANEL)
	onToggle(nil, self._lockS2MDMG, function(isOn)
		self._dataProxy:SetupDamageKamikazeAir(isOn and ys.Battle.BattleFormulas.CalcDamageLockA2M or nil)
	end, SFX_PANEL)
	onToggle(nil, self._lockA2MDMG, function(isOn)
		self._dataProxy:SetupDamageKamikazeShip(isOn and ys.Battle.BattleFormulas.CalcDamageLockS2M or nil)
	end, SFX_PANEL)
	onToggle(nil, self._lockCrushDMG, function(isOn)
		self._dataProxy:SetupDamageCrush(isOn and ys.Battle.BattleFormulas.CalcDamageLockCrush or nil)
	end, SFX_PANEL)

	-- 波次触发（仅剧情/日常/活动BOSS模式可用）
	self._triggerWave = self._common:Find("wave_trigger")
	self._waveIndex = self._common:Find("wave_input"):GetComponent("InputField")

	if self._dataProxy:GetInitData().battleType ~= SYSTEM_SCENARIO and self._dataProxy:GetInitData().battleType ~= SYSTEM_ROUTINE and self._dataProxy:GetInitData().battleType ~= SYSTEM_ACT_BOSS then
		SetActive(self._triggerWave, false)
		SetActive(self._waveIndex, false)
	else
		onButton(nil, self._triggerWave, function()
			self:forceTrigger(tonumber(self._waveIndex.text))
		end)
	end

	-- 天气触发
	self._triggerWeather = self._common:Find("weather_trigger")
	self._weatherInput = self._common:Find("weather_input"):GetComponent("InputField")

	onButton(nil, self._triggerWeather, function()
		self._dataProxy:AddWeather(tonumber(self._weatherInput.text))
	end)

	-- 反潜范围显示
	self._antiSubDetailRange = self._common:Find("anti_sub_detail")

	onButton(nil, self._antiSubDetailRange, function()
		self._state:GetMediatorByName("BattleSceneMediator"):InitDetailAntiSubArea()
	end)

	-- 瞬间装填按钮
	self._instantReload = self._common:Find("instant_reload")

	onButton(nil, self._instantReload, function()
		local fleet1 = self._dataProxy._fleetList[1]

		-- 对所有武器VO执行快速冷却
		local function quickCoolAll(weaponVO)
			local weaponList = weaponVO:GetWeaponList()

			for _, weapon in ipairs(weaponList) do
				weapon:QuickCoolDown()
			end
		end

		quickCoolAll(fleet1:GetChargeWeaponVO())
		quickCoolAll(fleet1:GetTorpedoWeaponVO())
		quickCoolAll(fleet1:GetAirAssistVO())
	end)

	-- 白色按钮（对第一艘船造成20点伤害，用于测试）
	self._white = self._base:Find("white_button")

	onButton(nil, self._white, function()
		self._dataProxy._fleetList[1]._scoutList[1]:UpdateHP(-20, {})
	end, SFX_PANEL)
	SetActive(self._white, true)
end

--- 显示/隐藏调试控制台
--- @param isActive boolean
function BattleDebugConsole.SetActive(self, isActive)
	SetActive(self._go, isActive)
end

--- 生成一个敌人单位
--- @param monsterTemplateID number 敌人模板ID
--- @param xMin number X坐标最小值
--- @param xMax number X坐标最大值
--- @param zMin number Z坐标最小值
--- @param zMax number Z坐标最大值
function BattleDebugConsole.spawnEnemy(self, monsterTemplateID, xMin, xMax, zMin, zMax)
	local monsterData = {
		monsterTemplateID = monsterTemplateID,
		corrdinate = {
			math.random(xMin, xMax),
			0,
			math.random(zMin, zMax)
		}
	}

	monsterData.delay = 0
	monsterData.moveCast = true
	monsterData.score = 0
	monsterData.buffList = {
		8001
	}

	self._dataProxy:SpawnMonster(monsterData, 1, BattleConst.UnitType.ENEMY_UNIT, BattleConfig.FOE_CODE)
end

--- 生成空袭飞机编队
--- @param aircraftID number 飞机模板ID
--- @param totalNumber number 总数量
--- @param onceNumber number 每次生成数量
--- @param interval number 生成间隔（实际传递给SpawnAirFighter时会使用默认值）
function BattleDebugConsole.spawnStrike(self, aircraftID, totalNumber, onceNumber, interval)
	local strikeData = {
		templateID = aircraftID,
		weaponID = {},
		attr = {},
		totalNumber = totalNumber,
		onceNumber = onceNumber
	}

	strikeData.formation = 10006
	strikeData.delay = 0
	strikeData.interval = 0.1
	strikeData.score = 0

	self._dataProxy:SpawnAirFighter(strikeData)
end

--- 激活参考面板（速度控制、单位/子弹调试框、属性面板）
function BattleDebugConsole.activeReference(self)
	self._state:ActiveReference()

	local referenceBox = self._state:GetMediatorByName(ys.Battle.BattleReferenceBoxMediator.__name) or self._state:AddMediator(ys.Battle.BattleReferenceBoxMediator.New())

	pg.TipsMgr.GetInstance():ShowTips("┏━━━━━━━━━━━━━━━━━━━┓")
	pg.TipsMgr.GetInstance():ShowTips("┃ヽ(•̀ω•́ )ゝ战斗调试模块初始化成功！(ง •̀_•́)ง┃")
	pg.TipsMgr.GetInstance():ShowTips("┗━━━━━━━━━━━━━━━━━━━┛")

	self._activeReference.transform:GetComponent("Button").enabled = false
	self._activeReference:Find("text"):GetComponent(typeof(Text)).text = "(ﾉ･ω･)ﾉﾞ"
	self._referenceConsole = self._common:Find("reference_btns")

	SetActive(self._referenceConsole, true)

	-- 速度控制按钮
	self._speedUp = self._referenceConsole:Find("speed_up")
	self._speedDown = self._referenceConsole:Find("speed_down")
	self._speedLevel = self._referenceConsole:Find("speed")

	onButton(nil, self._speedUp, function()
		local currentScale = ys.Battle.BattleConfig.BASIC_TIME_SCALE

		if currentScale < 1 then
			ys.Battle.BattleControllerCommand.removeSpeed(2)
		elseif currentScale >= 1 then
			ys.Battle.BattleControllerCommand.addSpeed(2)
		end

		self._speedLevel:GetComponent(typeof(Text)).text = ys.Battle.BattleConfig.BASIC_TIME_SCALE

		self._state:ScaleTimer()
	end, SFX_PANEL)
	onButton(nil, self._speedDown, function()
		local currentScale = ys.Battle.BattleConfig.BASIC_TIME_SCALE

		if currentScale > 1 then
			ys.Battle.BattleControllerCommand.removeSpeed(0.5)
		elseif currentScale <= 1 then
			ys.Battle.BattleControllerCommand.addSpeed(0.5)
		end

		self._speedLevel:GetComponent(typeof(Text)).text = ys.Battle.BattleConfig.BASIC_TIME_SCALE

		self._state:ScaleTimer()
	end, SFX_PANEL)

	-- 单位/子弹调试框和属性面板Toggle
	self._shipBox = self._referenceConsole:Find("ship_box")
	self._bulletBox = self._referenceConsole:Find("bullet_box")
	self._pp = self._referenceConsole:Find("property_panel")

	onToggle(nil, self._shipBox, function(isOn)
		referenceBox:ActiveUnitBoxes(isOn)
	end, SFX_PANEL)
	onToggle(nil, self._bulletBox, function(isOn)
		referenceBox:ActiveBulletBoxes(isOn)
	end, SFX_PANEL)
	onToggle(nil, self._pp, function(isOn)
		referenceBox:ActiveUnitDetail(isOn)
	end, SFX_PANEL)
end

--- 强制触发指定索引的波次（用于调试跳过波次）
--- @param waveIndex number 波次索引
function BattleDebugConsole.forceTrigger(self, waveIndex)
	local waveInfo = self._state:GetCommandByName("BattleSingleDungeonCommand")._waveUpdater._waveInfoList[waveIndex]

	if waveInfo == nil then
		pg.TipsMgr.GetInstance():ShowTips("查无次波")
	elseif waveInfo:GetState() ~= waveInfo.STATE_DEACTIVE then
		pg.TipsMgr.GetInstance():ShowTips("该触发器已经触发")
	else
		waveInfo:DoWave()
	end
end
