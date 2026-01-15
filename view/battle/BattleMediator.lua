local BattleMediator = class("BattleMediator", import("..base.ContextMediator"))

BattleMediator.ON_BATTLE_RESULT = "BattleMediator:ON_BATTLE_RESULT"
BattleMediator.ON_PAUSE = "BattleMediator:ON_PAUSE"
BattleMediator.ENTER = "BattleMediator:ENTER"
BattleMediator.ON_BACK_PRE_SCENE = "BattleMediator:ON_BACK_PRE_SCENE"
BattleMediator.ON_LEAVE = "BattleMediator:ON_LEAVE"
BattleMediator.ON_QUIT_BATTLE_MANUALLY = "BattleMediator:ON_QUIT_BATTLE_MANUALLY"
BattleMediator.HIDE_ALL_BUTTONS = "BattleMediator:HIDE_ALL_BUTTONS"
BattleMediator.ON_CHAT = "BattleMediator:ON_CHAT"
BattleMediator.CLOSE_CHAT = "BattleMediator:CLOSE_CHAT"
BattleMediator.ON_AUTO = "BattleMediator:ON_AUTO"
BattleMediator.UPDATE_AUTO_COUNT = "BattleMediator:UPDATE_AUTO_COUNT"
BattleMediator.ON_PUZZLE_RELIC = "BattleMediator.ON_PUZZLE_RELIC"
BattleMediator.ON_PUZZLE_CARD = "BattleMediator.ON_PUZZLE_CARD"

function BattleMediator.register(self)
	pg.BrightnessMgr.GetInstance():SetScreenNeverSleep(true)
	self:GenBattleData()

	self.contextData.battleData = self._battleData

	local battleState = ys.Battle.BattleState.GetInstance()
	local system = self.contextData.system

	self:bind(BattleMediator.ON_BATTLE_RESULT, function(arg_2_0, arg_2_1)
		self:sendNotification(GAME.FINISH_STAGE, {
			token = self.contextData.token,
			mainFleetId = self.contextData.mainFleetId,
			stageId = self.contextData.stageId,
			rivalId = self.contextData.rivalId,
			memory = self.contextData.memory,
			bossId = self.contextData.bossId,
			exitCallback = self.contextData.exitCallback,
			system = system,
			statistics = arg_2_1,
			actId = self.contextData.actId,
			mode = self.contextData.mode,
			puzzleCombatID = self.contextData.puzzleCombatID,
			useVariableTicket = self.contextData.useVariableTicket,
			isSimulate = self.contextData.isSimulate
		})
	end)
	self:bind(BattleMediator.ON_AUTO, function(arg_3_0, arg_3_1)
		self:onAutoBtn(arg_3_1)
	end)
	self:bind(BattleMediator.ON_PAUSE, function(arg_4_0)
		self:onPauseBtn()
	end)
	self:bind(BattleMediator.ON_LEAVE, function(arg_5_0)
		self:warnFunc()
	end)
	self:bind(BattleMediator.ON_CHAT, function(arg_6_0, arg_6_1)
		self:addSubLayers(Context.New({
			mediator = NotificationMediator,
			viewComponent = NotificationLayer,
			data = {
				form = NotificationLayer.FORM_BATTLE
			}
		}))
	end)
	self:bind(BattleMediator.ENTER, function(arg_7_0)
		battleState:EnterBattle(self._battleData, self.contextData.prePause)
	end)
	self:bind(BattleMediator.ON_BACK_PRE_SCENE, function()
		local var_8_0 = getProxy(ContextProxy)
		local var_8_1 = var_8_0:getContextByMediator(DailyLevelMediator)
		local var_8_2 = var_8_0:getContextByMediator(LevelMediator2)
		local var_8_3 = var_8_0:getContextByMediator(ChallengeMainMediator)
		local var_8_4 = var_8_0:getContextByMediator(ActivityBossMediatorTemplate)
		local var_8_5 = var_8_0:getContextByMediator(WorldMediator)
		local var_8_6 = var_8_0:getContextByMediator(WorldBossMediator)
		local var_8_7, var_8_8 = var_8_0:getContextByMediator(BossSinglePreCombatMediator)

		if var_8_6 and self.contextData.bossId then
			self:sendNotification(GAME.WORLD_BOSS_BATTLE_QUIT, {
				id = self.contextData.bossId
			})

			local var_8_9 = var_8_6:getContextByMediator(WorldBossFormationMediator)

			if var_8_9 then
				var_8_6:removeChild(var_8_9)
			end
		elseif var_8_5 then
			local var_8_10 = var_8_5:getContextByMediator(WorldPreCombatMediator) or var_8_5:getContextByMediator(WorldBossInformationMediator)

			if var_8_10 then
				var_8_5:removeChild(var_8_10)
			end
		elseif var_8_1 then
			local var_8_11 = var_8_1:getContextByMediator(PreCombatMediator)

			var_8_1:removeChild(var_8_11)
		elseif var_8_3 then
			self:sendNotification(GAME.CHALLENGE2_RESET, {
				mode = self.contextData.mode
			})

			local var_8_12 = var_8_3:getContextByMediator(ChallengePreCombatMediator)

			var_8_3:removeChild(var_8_12)
		elseif var_8_2 then
			if system == SYSTEM_DUEL then
				-- block empty
			elseif system == SYSTEM_SCENARIO then
				local var_8_13 = var_8_2:getContextByMediator(ChapterPreCombatMediator)

				if var_8_13 then
					var_8_2:removeChild(var_8_13)
				end
			elseif system ~= SYSTEM_PERFORM and system ~= SYSTEM_SIMULATION then
				local var_8_14 = var_8_2:getContextByMediator(PreCombatMediator)

				if var_8_14 then
					var_8_2:removeChild(var_8_14)
				end
			end
		elseif var_8_4 then
			local var_8_15 = var_8_4:getContextByMediator(PreCombatMediator)

			if var_8_15 then
				var_8_4:removeChild(var_8_15)
			end
		elseif var_8_7 then
			local var_8_16 = var_8_8:removeChild(var_8_7)
		end

		self:sendNotification(GAME.GO_BACK)
	end)
	self:bind(BattleMediator.ON_QUIT_BATTLE_MANUALLY, function(arg_9_0)
		if system == SYSTEM_SCENARIO then
			getProxy(ChapterProxy):StopAutoFight(ChapterConst.AUTOFIGHT_STOP_REASON.MANUAL)
		elseif system == SYSTEM_WORLD then
			nowWorld():TriggerAutoFight(false)
		elseif system == SYSTEM_ACT_BOSS then
			if getProxy(ContextProxy):getCurrentContext():getContextByMediator(ContinuousOperationMediator) then
				getProxy(ContextProxy):GetPrevContext(1):addChild(Context.New({
					mediator = ActivityBossTotalRewardPanelMediator,
					viewComponent = ActivityBossTotalRewardPanel,
					data = {
						isAutoFight = false,
						isLayer = true,
						rewards = getProxy(ChapterProxy):PopActBossRewards(),
						continuousBattleTimes = self.contextData.continuousBattleTimes,
						totalBattleTimes = self.contextData.totalBattleTimes
					}
				}))
			end
		elseif system == SYSTEM_BOSS_RUSH or system == SYSTEM_BOSS_RUSH_COLLABRATE then
			if getProxy(ContextProxy):getCurrentContext():getContextByMediator(ContinuousOperationMediator) then
				local var_9_0 = getProxy(ActivityProxy):PopBossRushAwards()

				getProxy(ContextProxy):GetPrevContext(1):addChild(Context.New({
					mediator = BossRushTotalRewardPanelMediator,
					viewComponent = BossRushTotalRewardPanel,
					data = {
						isAutoFight = false,
						isLayer = true,
						rewards = var_9_0
					}
				}))
			end
		elseif (system == SYSTEM_BOSS_SINGLE or system == SYSTEM_BOSS_SINGLE_VARIABLE) and getProxy(ContextProxy):getCurrentContext():getContextByMediator(BossSingleContinuousOperationMediator) then
			getProxy(ContextProxy):GetPrevContext(1):addChild(Context.New({
				mediator = BossSingleTotalRewardPanelMediator,
				viewComponent = BossSingleTotalRewardPanel,
				data = {
					isAutoFight = false,
					isLayer = true,
					rewards = getProxy(ChapterProxy):PopBossSingleRewards(),
					continuousBattleTimes = self.contextData.continuousBattleTimes,
					totalBattleTimes = self.contextData.totalBattleTimes
				}
			}))
		end
	end)
	self:bind(BattleMediator.ON_PUZZLE_RELIC, function(arg_10_0, arg_10_1)
		self:addSubLayers(Context.New({
			mediator = CardPuzzleRelicDeckMediator,
			viewComponent = CardPuzzleRelicDeckLayerCombat,
			data = arg_10_1
		}))
		battleState:Pause()
	end)
	self:bind(BattleMediator.ON_PUZZLE_CARD, function(arg_11_0, arg_11_1)
		self:addSubLayers(Context.New({
			mediator = CardPuzzleCardDeckMediator,
			viewComponent = CardPuzzleCardDeckLayerCombat,
			data = arg_11_1
		}))
		battleState:Pause()
	end)

	if self.contextData.continuousBattleTimes and self.contextData.continuousBattleTimes > 0 then
		if system == SYSTEM_BOSS_SINGLE or system == SYSTEM_BOSS_SINGLE_VARIABLE then
			if not getProxy(ContextProxy):getCurrentContext():getContextByMediator(BossSingleContinuousOperationMediator) then
				local var_1_2 = CreateShell(self.contextData)

				self:addSubLayers(Context.New({
					mediator = BossSingleContinuousOperationMediator,
					viewComponent = BossSingleContinuousOperationPanel,
					data = var_1_2
				}))
			end
		elseif not getProxy(ContextProxy):getCurrentContext():getContextByMediator(ContinuousOperationMediator) then
			local var_1_3 = CreateShell(self.contextData)

			self:addSubLayers(Context.New({
				mediator = ContinuousOperationMediator,
				viewComponent = ContinuousOperationPanel,
				data = var_1_3
			}))
		end

		self.contextData.battleData.hideAllButtons = true
	end

	local var_1_4 = getProxy(PlayerProxy)

	if var_1_4 then
		self.player = var_1_4:getData()

		var_1_4:setFlag("battle", true)
	end
end

function BattleMediator.onAutoBtn(arg_12_0, arg_12_1)
	local var_12_0 = arg_12_1.isOn
	local var_12_1 = arg_12_1.toggle
	local var_12_2 = arg_12_1.system

	arg_12_0:sendNotification(GAME.AUTO_BOT, {
		isActiveBot = var_12_0,
		toggle = var_12_1,
		system = var_12_2
	})
end

function BattleMediator.updateAutoCount(arg_13_0, arg_13_1)
	local var_13_0 = ys.Battle.BattleState.GetInstance():GetProxyByName(ys.Battle.BattleDataProxy.__name):AutoStatistics(arg_13_1.isOn)
end

function BattleMediator.onPauseBtn(arg_14_0)
	local var_14_0 = ys.Battle.BattleState.GetInstance()

	if arg_14_0.contextData.system == SYSTEM_PROLOGUE or arg_14_0.contextData.system == SYSTEM_PERFORM then
		local var_14_1 = {}

		if EPILOGUE_SKIPPABLE then
			local var_14_2 = {
				text = "关爱胡德",
				btnType = pg.MsgboxMgr.BUTTON_RED,
				onCallback = function()
					var_14_0:Deactive()
					arg_14_0:sendNotification(GAME.CHANGE_SCENE, SCENE.CREATE_PLAYER)
				end
			}

			table.insert(var_14_1, 1, var_14_2)
		end

		pg.MsgboxMgr.GetInstance():ShowMsgBox({
			type = MSGBOX_TYPE_HELP,
			helps = i18n("help_battle_rule"),
			onClose = function()
				ys.Battle.BattleState.GetInstance():Resume()
			end,
			onNo = function()
				ys.Battle.BattleState.GetInstance():Resume()
			end,
			custom = var_14_1
		})
		var_14_0:Pause()
	elseif arg_14_0.contextData.system == SYSTEM_DODGEM then
		local var_14_3 = {
			text = "text_cancel_fight",
			btnType = pg.MsgboxMgr.BUTTON_RED,
			onCallback = function()
				arg_14_0:warnFunc(function()
					ys.Battle.BattleState.GetInstance():Resume()
				end)
			end
		}

		pg.MsgboxMgr.GetInstance():ShowMsgBox({
			type = MSGBOX_TYPE_HELP,
			helps = i18n("help_battle_warspite"),
			onClose = function()
				ys.Battle.BattleState.GetInstance():Resume()
			end,
			onNo = function()
				ys.Battle.BattleState.GetInstance():Resume()
			end,
			custom = {
				var_14_3
			}
		})
		var_14_0:Pause()
	elseif arg_14_0.contextData.system == SYSTEM_SIMULATION then
		local var_14_4 = {
			text = "text_cancel_fight",
			btnType = pg.MsgboxMgr.BUTTON_RED,
			onCallback = function()
				arg_14_0:warnFunc(function()
					ys.Battle.BattleState.GetInstance():Resume()
				end)
			end
		}

		pg.MsgboxMgr.GetInstance():ShowMsgBox({
			type = MSGBOX_TYPE_HELP,
			helps = i18n("help_battle_rule"),
			onClose = function()
				ys.Battle.BattleState.GetInstance():Resume()
			end,
			onNo = function()
				ys.Battle.BattleState.GetInstance():Resume()
			end,
			custom = {
				var_14_4
			}
		})
		var_14_0:Pause()
	elseif arg_14_0.contextData.system == SYSTEM_SUBMARINE_RUN or arg_14_0.contextData.system == SYSTEM_SUB_ROUTINE or arg_14_0.contextData.system == SYSTEM_REWARD_PERFORM or arg_14_0.contextData.system == SYSTEM_AIRFIGHT then
		var_14_0:Pause()
		arg_14_0:warnFunc(function()
			ys.Battle.BattleState.GetInstance():Resume()
		end)
	elseif arg_14_0.contextData.system == SYSTEM_CARDPUZZLE then
		arg_14_0:addSubLayers(Context.New({
			mediator = CardPuzzleCombatPauseMediator,
			viewComponent = CardPuzzleCombatPauseLayer
		}))
		var_14_0:Pause()
	else
		arg_14_0.viewComponent:updatePauseWindow()
		var_14_0:Pause()
	end
end

function BattleMediator.warnFunc(arg_27_0, arg_27_1)
	local var_27_0 = ys.Battle.BattleState.GetInstance()
	local var_27_1 = arg_27_0.contextData.system
	local var_27_2
	local var_27_3

	local function var_27_4()
		var_27_0:Stop()
	end

	local var_27_5 = arg_27_0.contextData.warnMsg

	if var_27_5 and #var_27_5 > 0 then
		var_27_3 = i18n(var_27_5)
	elseif var_27_1 == SYSTEM_CHALLENGE then
		var_27_3 = i18n("battle_battleMediator_clear_warning")
	elseif var_27_1 == SYSTEM_SIMULATION then
		var_27_3 = i18n("tech_simulate_quit")
	elseif var_27_1 == SYSTEM_SCENARIO_SUB_STRIKE then
		var_27_3 = i18n("battle_battleMediator_quest_exist_submarine_support")

		function var_27_4()
			var_27_0:GetCommandByName(ys.Battle.BattleScenarioSubStrikeCommand.__name):CalcBattleEnd()
			arg_27_0.viewComponent:ClosePauseWindow()
		end
	else
		var_27_3 = i18n("battle_battleMediator_quest_exist")
	end

	local function var_27_6()
		if arg_27_1 then
			arg_27_1()
		end

		local var_30_0 = arg_27_0.viewComponent.leaveBtn:GetComponent(typeof(Animation))

		if var_30_0 then
			var_30_0:Play("msgbox_btn_into")
		end
	end

	pg.MsgboxMgr.GetInstance():ShowMsgBox({
		modal = true,
		hideNo = true,
		hideYes = true,
		content = var_27_3,
		onClose = var_27_6,
		custom = {
			{
				text = "text_cancel",
				onCallback = var_27_6,
				sound = SFX_CANCEL
			},
			{
				text = "text_exit",
				btnType = pg.MsgboxMgr.BUTTON_RED,
				onCallback = var_27_4,
				sound = SFX_CONFIRM
			}
		}
	})
end

function BattleMediator.guideDispatch(arg_31_0)
	return
end

-- 准备舰船数据(舰船、装备、属性、技能等)
-- 会多次调用
local function PrepareShipData(system, ship, commanders, inDuel)
	local equipments = {}

	for _, equipment in ipairs(ship:getActiveEquipments()) do
		if equipment then
			equipments[#equipments + 1] = {
				id = equipment.configId,
				skin = equipment.skinId,
				equipmentInfo = equipment
			}
		else
			equipments[#equipments + 1] = {
				skin = 0,
				id = equipment,
				equipmentInfo = equipment
			}
		end
	end
	-- 实际是buffList, 只是为了跟下面的写法对应上
	-- 自己知道舰船的skill实际对应的是战斗中的buff概念即可，并区分战斗中的skill概念
	local skills = {}

	-- 根据已有的初始Buff(各种技能)数据，转换为实际的Buff数据(专武升级和战斗系统转换)
	local function MapBuffData(buffData)
		local mapedBuffData = {
			level = buffData.level
		}
		local buffID = buffData.id
		-- 对专武的技能升级进行转换
		local mapedBuffID = ship:RemapSkillId(buffID, true)
		-- 进行系统转换(演习/大世界特供等)
		mapedBuffData.id = ys.Battle.BattleDataFunction.SkillTranform(system, mapedBuffID)

		return mapedBuffData
	end
	-- key: hideBuffID, value: {level=1, id=hideBuffID}
	local hideBuffList = ys.Battle.BattleDataFunction.GenerateHiddenBuff(ship.configId)

	-- 映射舰船的隐藏技能
	for _, hideBuffData in pairs(hideBuffList) do
		local actualHideBuffData = MapBuffData(hideBuffData)

		skills[actualHideBuffData.id] = actualHideBuffData
	end

	-- 实际上是又映射了一次隐藏技能
	for _, skill in pairs(ship.skills) do
		-- 这是什么玩意？还有这种特殊处理的？
		-- 查了下，说的是Buff 14900和改造项目16412
		-- 对应的是夕立的改造技能，但我也不懂这么写是要干什么
		if skill and skill.id == 14900 and not ship.transforms[16412] then
			-- block empty
		else
			local actualSkill = MapBuffData(skill)

			skills[actualSkill.id] = actualSkill
		end
	end

	-- 映射装备的技能
	local equipSkills = ys.Battle.BattleDataFunction.GetEquipSkill(equipments)

	for _, equipSkill in ipairs(equipSkills) do
		local actualEquipSkill = {
			level = equipSkill.buffLV,
			id = ys.Battle.BattleDataFunction.SkillTranform(system, equipSkill.buffID)
		}

		skills[actualEquipSkill.id] = actualEquipSkill
	end

	local spWeapon
	-- 映射专武的技能(effect)
	;(function()
		spWeapon = ship:GetSpWeapon()

		if not spWeapon then
			return
		end

		local spWeaponEffect = spWeapon:GetEffect()

		if spWeaponEffect == 0 then
			return
		end

		local actualSpWeaponEffect = {}

		actualSpWeaponEffect.level = 1
		actualSpWeaponEffect.id = ys.Battle.BattleDataFunction.SkillTranform(system, spWeaponEffect)
		skills[actualSpWeaponEffect.id] = actualSpWeaponEffect
	end)()

	-- 映射TriggerSkill
	-- 实际就是舰船的常规技能
	for _, triggerSkill in pairs(ship:getTriggerSkills()) do
		local actualTriggerSkill = {
			level = triggerSkill.level,
			id = ys.Battle.BattleDataFunction.SkillTranform(system, triggerSkill.id)
		}

		skills[actualTriggerSkill.id] = actualTriggerSkill
	end

	local inWorld = system == SYSTEM_WORLD
	local isBroken = false

	if inWorld then
		local worldShip = WorldConst.FetchWorldShip(ship.id)

		if worldShip then
			isBroken = worldShip:IsBroken()
		end
	end
	-- 如果为战损，则移除部分技能
	if isBroken then
		for skillID, _ in pairs(skills) do
			local worldDeathMark = pg.skill_data_template[skillID].world_death_mark[1]

			if worldDeathMark == ys.Battle.BattleConst.DEATH_MARK_SKILL.DEACTIVE then
				skills[skillID] = nil
			elseif worldDeathMark == ys.Battle.BattleConst.DEATH_MARK_SKILL.IGNORE then
				-- block empty
			end
		end
	end
	-- 返回最终的数据结构: 舰船、装备、属性、技能等
	return {
		id = ship.id,
		tmpID = ship.configId,
		skinId = ship.skinId,
		level = ship.level,
		equipment = equipments,
		properties = ship:getProperties(commanders, inDuel, inWorld),
		baseProperties = ship:getShipProperties(),
		proficiency = ship:getEquipProficiencyList(),
		rarity = ship:getRarity(),
		intimacy = ship:getCVIntimacy(),
		shipGS = ship:getShipCombatPower(),
		skills = skills,
		baseList = ship:getBaseList(),
		preloasList = ship:getPreLoadCount(),
		name = ship:getName(),
		deathMark = isBroken,
		spWeapon = spWeapon
	}
end

-- 鉴于CardPuzzle是个废案，不用管这个函数
local function PrepareCardPuzzleShipData(ship, commanders)
	local properties = ship:getProperties(commanders)
	local shipID = ship:getConfig("id")

	return {
		deathMark = false,
		shipGS = 100,
		rarity = 1,
		intimacy = 100,
		id = shipID,
		tmpID = shipID,
		skinId = ship:getConfig("skin_id"),
		level = ship:getConfig("level"),
		equipment = ship:getConfig("default_equip"),
		properties = properties,
		baseProperties = properties,
		proficiency = {
			1,
			1,
			1
		},
		skills = {},
		baseList = {
			1,
			1,
			1
		},
		preloasList = {
			0,
			0,
			0
		},
		name = shipID,
		fleetIndex = ship:getConfig("location")
	}
end

-- 核心：从战斗外的数据结构转换为战斗内的数据结构
-- 几乎全部的数据准备工作都在这里完成，后续只是传递和使用battleData这个表
function BattleMediator.GenBattleData(self)
	local battleData = {}
	-- 关于contextData: 这个是服务端传递过来的
	-- 所以在客户端本地逆向，没法知道是怎么构建的(只能靠推测)
	local system = self.contextData.system

	self._battleData = battleData
	battleData.battleType = self.contextData.system
	battleData.StageTmpId = self.contextData.stageId
	battleData.CMDArgs = self.contextData.cmdArgs
	battleData.isMemory = self.contextData.memory
	battleData.MainUnitList = {}
	battleData.VanguardUnitList = {}
	battleData.SubUnitList = {}
	battleData.AidUnitList = {}
	battleData.SupportUnitList = {}
	battleData.SubFlag = -1
	battleData.ActID = self.contextData.actId
	battleData.bossLevel = self.contextData.bossLevel
	battleData.bossConfigId = self.contextData.bossConfigId

	-- 判定这种battleSystem全局Buff能不能生效
	if pg.battle_cost_template[system].global_buff_effected > 0 then
		local globalBuffs = BuffHelper.GetBattleBuffs(system)
		local globalBuffIDs = {}
		-- globalBuffs: 对应benefit_buff_template
		for _, globalBuff in ipairs(globalBuffs) do
			local benefitCondition = globalBuff:getConfig("benefit_condition")
			local satisfied = false

			if benefitCondition[1] == "chapter" then
				if system == SYSTEM_SCENARIO and table.contains(benefitCondition[2], getProxy(ChapterProxy):getActiveChapter().id) then
					satisfied = true
				end
			else
				satisfied = true
			end

			if satisfied then
				table.insert(globalBuffIDs, globalBuff:getConfig("benefit_effect"))
			end
		end

		battleData.GlobalBuffIDs = globalBuffIDs
	end
	-- 战斗类型对应的石油/心情等消耗
	local systemCostTmp = pg.battle_cost_template[system]
	-- bayProxy: 船坞Proxy
	local bayProxy = getProxy(BayProxy)
	local var_36_8 = {}

	-- 下面，根据不同的战斗类型，准备不同的数据
	-- 第一类：Chapter类(主线/活动等)，最常见的战斗类型
	if system == SYSTEM_SCENARIO then
		local chapterProxy = getProxy(ChapterProxy)
		local activeChapter = chapterProxy:getActiveChapter()

		battleData.RepressInfo = activeChapter:getRepressInfo()

		self.viewComponent:setChapter(activeChapter)
		--- @type ChapterFleet
		local fleet = activeChapter.fleet

		battleData.KizunaJamming = activeChapter:getExtraFlags()
		battleData.DefeatCount = fleet:getDefeatCount()
		battleData.ChapterBuffIDs, battleData.CommanderList = activeChapter:getFleetBattleBuffs(fleet)
		battleData.StageWaveFlags = activeChapter:GetStageFlags()
		battleData.ChapterWeatherIDS = activeChapter:GetWeather(fleet.line.row, fleet.line.column)
		battleData.MapAuraSkills = chapterProxy.GetChapterAuraBuffs(activeChapter)
		battleData.MapAidSkills = {}
		battleData.ChapterType = activeChapter:getPlayType()

		local chapterAidBuffs = chapterProxy.GetChapterAidBuffs(activeChapter)
		-- 准备跨队支援的舰船数据
		for ship, shipAidList in pairs(chapterAidBuffs) do
			local fleet = activeChapter:getFleetByShipVO(ship)
			local commanders = _.values(fleet:getCommanders())
			-- 请注意PrepareShipData这个函数，会多次调用
			-- 后续在BattleDataProxy实际用的也是里面的字段
			local shipData = PrepareShipData(system, ship, commanders)

			table.insert(battleData.AidUnitList, shipData)

			for _, shipAidSkill in ipairs(shipAidList) do
				table.insert(battleData.MapAidSkills, shipAidSkill)
			end
		end

		local mainShips = fleet:getShipsByTeam(TeamType.Main, false)
		local vanguardShips = fleet:getShipsByTeam(TeamType.Vanguard, false)
		local subShips = {}
		local commanders = _.values(fleet:getCommanders())
		local subCommanders = {}
		-- 是否有潜艇支援(判定是否在潜艇狩猎范围内、潜艇是否还有弹药等)
		local subAidFlag, subFleet = chapterProxy.getSubAidFlag(activeChapter, self.contextData.stageId)

		if subAidFlag == true or subAidFlag > 0 then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
			subShips = subFleet:getShipsByTeam(TeamType.Submarine, false)
			subCommanders = _.values(subFleet:getCommanders())

			local _, subCommanderBuffList = activeChapter:getFleetBattleBuffs(subFleet)

			battleData.SubCommanderList = subCommanderBuffList
		else
			battleData.SubFlag = subAidFlag

			if subAidFlag ~= ys.Battle.BattleConst.SubAidFlag.AID_EMPTY then
				battleData.TotalSubAmmo = 0
			end
		end

		self.mainShips = {}

		local function var_36_25(arg_37_0, arg_37_1, arg_37_2)
			local var_37_0 = arg_37_0.id
			local var_37_1 = arg_37_0.hpRant * 0.0001

			if table.contains(var_36_8, var_37_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = var_37_0

			local var_37_2 = PrepareShipData(system, arg_37_0, arg_37_1)

			var_37_2.initHPRate = var_37_1

			table.insert(self.mainShips, arg_37_0)
			table.insert(arg_37_2, var_37_2)
		end

		for iter_36_6, iter_36_7 in ipairs(mainShips) do
			var_36_25(iter_36_7, commanders, battleData.MainUnitList)
		end

		for iter_36_8, iter_36_9 in ipairs(vanguardShips) do
			var_36_25(iter_36_9, commanders, battleData.VanguardUnitList)
		end

		for iter_36_10, iter_36_11 in ipairs(subShips) do
			var_36_25(iter_36_11, subCommanders, battleData.SubUnitList)
		end

		local var_36_26 = activeChapter:getChapterSupportFleet()

		if var_36_26 then
			local var_36_27 = var_36_26:getShips()

			for iter_36_12, iter_36_13 in pairs(var_36_27) do
				var_36_25(iter_36_13, {}, battleData.SupportUnitList)
			end
		end

		self.viewComponent:setFleet(mainShips, vanguardShips, subShips)
	elseif system == SYSTEM_CHALLENGE then
		local var_36_28 = self.contextData.mode
		local var_36_29 = getProxy(ChallengeProxy):getUserChallengeInfo(var_36_28)

		battleData.ChallengeInfo = var_36_29

		self.viewComponent:setChapter(var_36_29)

		local var_36_30 = var_36_29:getRegularFleet()

		battleData.CommanderList = var_36_30:buildBattleBuffList()

		local var_36_31 = _.values(var_36_30:getCommanders())
		local var_36_32 = {}
		local var_36_33 = var_36_30:getShipsByTeam(TeamType.Main, false)
		local var_36_34 = var_36_30:getShipsByTeam(TeamType.Vanguard, false)
		local var_36_35 = {}
		local var_36_36 = var_36_29:getSubmarineFleet()
		local var_36_37 = var_36_36:getShipsByTeam(TeamType.Submarine, false)

		if #var_36_37 > 0 then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
			var_36_32 = _.values(var_36_36:getCommanders())
			battleData.SubCommanderList = var_36_36:buildBattleBuffList()
		else
			battleData.SubFlag = 0
			battleData.TotalSubAmmo = 0
		end

		self.mainShips = {}

		local function var_36_38(arg_38_0, arg_38_1, arg_38_2)
			local var_38_0 = arg_38_0.id
			local var_38_1 = arg_38_0.hpRant * 0.0001

			if table.contains(var_36_8, var_38_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = var_38_0

			local var_38_2 = PrepareShipData(system, arg_38_0, arg_38_1)

			var_38_2.initHPRate = var_38_1

			table.insert(self.mainShips, arg_38_0)
			table.insert(arg_38_2, var_38_2)
		end

		for iter_36_14, iter_36_15 in ipairs(var_36_33) do
			var_36_38(iter_36_15, var_36_31, battleData.MainUnitList)
		end

		for iter_36_16, iter_36_17 in ipairs(var_36_34) do
			var_36_38(iter_36_17, var_36_31, battleData.VanguardUnitList)
		end

		for iter_36_18, iter_36_19 in ipairs(var_36_37) do
			var_36_38(iter_36_19, var_36_32, battleData.SubUnitList)
		end

		self.viewComponent:setFleet(var_36_33, var_36_34, var_36_37)
	elseif system == SYSTEM_WORLD then
		--- @type World
		local world = nowWorld()
		--- @type WorldMap
		local worldMap = world:GetActiveMap()
		local worldFleet = worldMap:GetFleet()
		--- @type WorldMapAttachment
		local enemyAttachment = worldMap:GetCell(worldFleet.row, worldFleet.column):GetStageEnemy()

		if self.contextData.hpRate then
			battleData.RepressInfo = {
				repressEnemyHpRant = self.contextData.hpRate
			}
		end

		battleData.AffixBuffList = table.mergeArray(enemyAttachment:GetBattleLuaBuffs(), worldMap:GetBattleLuaBuffs(WorldMap.FactionEnemy, enemyAttachment))

		local function var_36_43(arg_39_0)
			local var_39_0 = {}

			for iter_39_0, iter_39_1 in ipairs(arg_39_0) do
				local var_39_1 = {
					id = ys.Battle.BattleDataFunction.SkillTranform(system, iter_39_1.id),
					level = iter_39_1.level
				}

				table.insert(var_39_0, var_39_1)
			end

			return var_39_0
		end

		battleData.DefeatCount = worldFleet:getDefeatCount()
		battleData.ChapterBuffIDs, battleData.CommanderList = worldMap:getFleetBattleBuffs(worldFleet, true)
		battleData.MapAuraSkills = worldMap:GetChapterAuraBuffs()
		battleData.MapAuraSkills = var_36_43(battleData.MapAuraSkills)
		battleData.MapAidSkills = {}

		local var_36_44 = worldMap:GetChapterAidBuffs()

		for iter_36_20, iter_36_21 in pairs(var_36_44) do
			local var_36_45 = worldMap:GetFleet(iter_36_20.fleetId)
			local var_36_46 = _.values(var_36_45:getCommanders(true))
			local var_36_47 = PrepareShipData(system, WorldConst.FetchShipVO(iter_36_20.id), var_36_46)

			table.insert(battleData.AidUnitList, var_36_47)

			battleData.MapAidSkills = table.mergeArray(battleData.MapAidSkills, var_36_43(iter_36_21))
		end

		local var_36_48 = worldFleet:GetTeamShipVOs(TeamType.Main, false)
		local var_36_49 = worldFleet:GetTeamShipVOs(TeamType.Vanguard, false)
		local var_36_50 = {}
		local var_36_51 = _.values(worldFleet:getCommanders(true))
		local var_36_52 = {}
		local var_36_53 = world:GetSubAidFlag()

		if var_36_53 == true then
			local var_36_54 = worldMap:GetSubmarineFleet()

			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
			var_36_50 = var_36_54:GetTeamShipVOs(TeamType.Submarine, false)
			var_36_52 = _.values(var_36_54:getCommanders(true))

			local var_36_55, var_36_56 = worldMap:getFleetBattleBuffs(var_36_54, true)

			battleData.SubCommanderList = var_36_56
		else
			battleData.SubFlag = 0

			if var_36_53 ~= ys.Battle.BattleConst.SubAidFlag.AID_EMPTY then
				battleData.TotalSubAmmo = 0
			end
		end

		self.mainShips = {}

		for iter_36_22, iter_36_23 in ipairs(var_36_48) do
			local var_36_57 = iter_36_23.id
			local var_36_58 = WorldConst.FetchWorldShip(iter_36_23.id).hpRant * 0.0001

			if table.contains(var_36_8, var_36_57) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = var_36_57

			local var_36_59 = PrepareShipData(system, iter_36_23, var_36_51)

			var_36_59.initHPRate = var_36_58

			table.insert(self.mainShips, iter_36_23)
			table.insert(battleData.MainUnitList, var_36_59)
		end

		for iter_36_24, iter_36_25 in ipairs(var_36_49) do
			local var_36_60 = iter_36_25.id
			local var_36_61 = WorldConst.FetchWorldShip(iter_36_25.id).hpRant * 0.0001

			if table.contains(var_36_8, var_36_60) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = var_36_60

			local var_36_62 = PrepareShipData(system, iter_36_25, var_36_51)

			var_36_62.initHPRate = var_36_61

			table.insert(self.mainShips, iter_36_25)
			table.insert(battleData.VanguardUnitList, var_36_62)
		end

		for iter_36_26, iter_36_27 in ipairs(var_36_50) do
			local var_36_63 = iter_36_27.id
			local var_36_64 = WorldConst.FetchWorldShip(iter_36_27.id).hpRant * 0.0001

			if table.contains(var_36_8, var_36_63) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = var_36_63

			local var_36_65 = PrepareShipData(system, iter_36_27, var_36_52)

			var_36_65.initHPRate = var_36_64

			table.insert(self.mainShips, iter_36_27)
			table.insert(battleData.SubUnitList, var_36_65)
		end

		self.viewComponent:setFleet(var_36_48, var_36_49, var_36_50)

		local expeditionTmpData = pg.expedition_data_template[self.contextData.stageId]
		-- 计算大型作战的敌人等级
		-- difficulty == 4
		if expeditionTmpData.difficulty == ys.Battle.BattleConst.Difficulty.WORLD then
			battleData.WorldMapId = worldMap.config.expedition_map_id
			battleData.WorldLevel = WorldConst.WorldLevelCorrect(worldMap.config.expedition_level, expeditionTmpData.type)
		end
	elseif system == SYSTEM_WORLD_BOSS then
		local var_36_67 = nowWorld():GetBossProxy()
		local var_36_68 = self.contextData.bossId
		local var_36_69 = var_36_67:GetFleet(var_36_68)
		local var_36_70 = var_36_67:GetBossById(var_36_68)

		if self.contextData.hpRate then
			battleData.RepressInfo = {
				repressEnemyHpRant = self.contextData.hpRate
			}
		end

		local var_36_71 = _.values(var_36_69:getCommanders())

		battleData.CommanderList = var_36_69:buildBattleBuffList()
		self.mainShips = bayProxy:getShipsByFleet(var_36_69)

		local var_36_72 = {}
		local var_36_73 = {}
		local var_36_74 = {}
		local var_36_75 = var_36_69:getTeamByName(TeamType.Main)

		for iter_36_28, iter_36_29 in ipairs(var_36_75) do
			if table.contains(var_36_8, iter_36_29) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = iter_36_29

			local var_36_76 = bayProxy:getShipById(iter_36_29)
			local var_36_77 = PrepareShipData(system, var_36_76, var_36_71)

			table.insert(var_36_72, var_36_76)
			table.insert(battleData.MainUnitList, var_36_77)
		end

		local var_36_78 = var_36_69:getTeamByName(TeamType.Vanguard)

		for iter_36_30, iter_36_31 in ipairs(var_36_78) do
			if table.contains(var_36_8, iter_36_31) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = iter_36_31

			local var_36_79 = bayProxy:getShipById(iter_36_31)
			local var_36_80 = PrepareShipData(system, var_36_79, var_36_71)

			table.insert(var_36_73, var_36_79)
			table.insert(battleData.VanguardUnitList, var_36_80)
		end

		self.viewComponent:setFleet(var_36_72, var_36_73, var_36_74)

		battleData.MapAidSkills = {}

		if var_36_70 and var_36_70:IsSelf() then
			local var_36_81, var_36_82, var_36_83 = var_36_67.GetSupportValue()

			if var_36_81 then
				table.insert(battleData.MapAidSkills, {
					level = 1,
					id = var_36_83
				})
			end
		end
	elseif system == SYSTEM_HP_SHARE_ACT_BOSS or system == SYSTEM_ACT_BOSS or system == SYSTEM_ACT_BOSS_SP or system == SYSTEM_BOSS_EXPERIMENT then
		if self.contextData.mainFleetId then
			local var_36_84 = getProxy(FleetProxy):getActivityFleets()[self.contextData.actId]
			local var_36_85 = var_36_84[self.contextData.mainFleetId]
			local var_36_86 = _.values(var_36_85:getCommanders())

			battleData.CommanderList = var_36_85:buildBattleBuffList()
			self.mainShips = {}

			local var_36_87 = {}
			local var_36_88 = {}
			local var_36_89 = {}

			local function var_36_90(arg_40_0, arg_40_1, arg_40_2, arg_40_3)
				if table.contains(var_36_8, arg_40_0) then
					BattleVertify.cloneShipVertiry = true
				end

				var_36_8[#var_36_8 + 1] = arg_40_0

				local var_40_0 = bayProxy:getShipById(arg_40_0)
				local var_40_1 = PrepareShipData(system, var_40_0, arg_40_1)

				table.insert(self.mainShips, var_40_0)
				table.insert(arg_40_3, var_40_0)
				table.insert(arg_40_2, var_40_1)
			end

			local var_36_91 = var_36_85:getTeamByName(TeamType.Main)
			local var_36_92 = var_36_85:getTeamByName(TeamType.Vanguard)

			for iter_36_32, iter_36_33 in ipairs(var_36_91) do
				var_36_90(iter_36_33, var_36_86, battleData.MainUnitList, var_36_87)
			end

			for iter_36_34, iter_36_35 in ipairs(var_36_92) do
				var_36_90(iter_36_35, var_36_86, battleData.VanguardUnitList, var_36_88)
			end

			local var_36_93 = var_36_84[self.contextData.mainFleetId + 10]
			local var_36_94 = _.values(var_36_93:getCommanders())
			local var_36_95 = var_36_93:getTeamByName(TeamType.Submarine)

			for iter_36_36, iter_36_37 in ipairs(var_36_95) do
				var_36_90(iter_36_37, var_36_94, battleData.SubUnitList, var_36_89)
			end

			local var_36_96 = getProxy(PlayerProxy):getRawData()
			local var_36_97 = getProxy(ActivityProxy):getActivityById(self.contextData.actId)
			local var_36_98 = var_36_97:getConfig("config_id")
			local var_36_99 = pg.activity_event_worldboss[var_36_98].use_oil_limit[self.contextData.mainFleetId]
			local var_36_100 = var_36_97:IsOilLimit(self.contextData.stageId)
			local var_36_101 = 0
			local var_36_102 = systemCostTmp.oil_cost > 0

			local function var_36_103(arg_41_0, arg_41_1)
				if var_36_102 then
					local var_41_0 = arg_41_0:getEndCost().oil

					if arg_41_1 > 0 then
						local var_41_1 = arg_41_0:getStartCost().oil

						cost = math.clamp(arg_41_1 - var_41_1, 0, var_41_0)
					end

					var_36_101 = var_36_101 + var_41_0
				end
			end

			if system == SYSTEM_ACT_BOSS_SP then
				local var_36_104 = getProxy(ActivityProxy):GetActivityBossRuntime(self.contextData.actId).buffIds
				local var_36_105 = _.map(var_36_104, function(arg_42_0)
					return ActivityBossBuff.New({
						configId = arg_42_0
					})
				end)

				battleData.ExtraBuffList = _.map(_.select(var_36_105, function(arg_43_0)
					return arg_43_0:CastOnEnemy()
				end), function(arg_44_0)
					return arg_44_0:GetBuffID()
				end)
				battleData.ChapterBuffIDs = _.map(_.select(var_36_105, function(arg_45_0)
					return not arg_45_0:CastOnEnemy()
				end), function(arg_46_0)
					return arg_46_0:GetBuffID()
				end)
			else
				var_36_103(var_36_85, var_36_100 and var_36_99[1] or 0)
				var_36_103(var_36_93, var_36_100 and var_36_99[2] or 0)
			end

			if var_36_93:isLegalToFight() == true and (system == SYSTEM_BOSS_EXPERIMENT or var_36_101 <= var_36_96.oil) then
				battleData.SubFlag = 1
				battleData.TotalSubAmmo = 1
			end

			battleData.SubCommanderList = var_36_93:buildBattleBuffList()

			self.viewComponent:setFleet(var_36_87, var_36_88, var_36_89)
		end
	elseif system == SYSTEM_GUILD then
		local var_36_106 = getProxy(GuildProxy):getRawData():GetActiveEvent():GetBossMission()
		local var_36_107 = var_36_106:GetMainFleet()
		local var_36_108 = _.values(var_36_107:getCommanders())

		battleData.CommanderList = var_36_107:BuildBattleBuffList()
		self.mainShips = {}

		local var_36_109 = {}
		local var_36_110 = {}
		local var_36_111 = {}

		local function var_36_112(arg_47_0, arg_47_1, arg_47_2, arg_47_3)
			local var_47_0 = PrepareShipData(system, arg_47_0, arg_47_1)

			table.insert(self.mainShips, arg_47_0)
			table.insert(arg_47_3, arg_47_0)
			table.insert(arg_47_2, var_47_0)
		end

		local var_36_113 = {}
		local var_36_114 = {}
		local var_36_115 = var_36_107:GetShips()

		for iter_36_38, iter_36_39 in pairs(var_36_115) do
			local var_36_116 = iter_36_39.ship

			if var_36_116:getTeamType() == TeamType.Main then
				table.insert(var_36_113, var_36_116)
			elseif var_36_116:getTeamType() == TeamType.Vanguard then
				table.insert(var_36_114, var_36_116)
			end
		end

		for iter_36_40, iter_36_41 in ipairs(var_36_113) do
			var_36_112(iter_36_41, var_36_108, battleData.MainUnitList, var_36_109)
		end

		for iter_36_42, iter_36_43 in ipairs(var_36_114) do
			var_36_112(iter_36_43, var_36_108, battleData.VanguardUnitList, var_36_110)
		end

		local var_36_117 = var_36_106:GetSubFleet()
		local var_36_118 = _.values(var_36_117:getCommanders())
		local var_36_119 = {}
		local var_36_120 = var_36_117:GetShips()

		for iter_36_44, iter_36_45 in pairs(var_36_120) do
			local var_36_121 = iter_36_45.ship

			if var_36_121:getTeamType() == TeamType.Submarine then
				table.insert(var_36_119, var_36_121)
			end
		end

		for iter_36_46, iter_36_47 in ipairs(var_36_119) do
			var_36_112(iter_36_47, var_36_118, battleData.SubUnitList, var_36_111)
		end

		if #var_36_111 > 0 then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
		end

		battleData.SubCommanderList = var_36_117:BuildBattleBuffList()

		self.viewComponent:setFleet(var_36_109, var_36_110, var_36_111)
	elseif system == SYSTEM_BOSS_RUSH or system == SYSTEM_BOSS_RUSH_EX or system == SYSTEM_BOSS_RUSH_COLLABRATE then
		local var_36_122 = getProxy(ActivityProxy):getActivityById(self.contextData.actId):GetSeriesData()

		assert(var_36_122)

		local var_36_123 = var_36_122:GetStaegLevel() + 1
		local var_36_124 = var_36_122:GetFleetIds()
		local var_36_125 = var_36_124[var_36_123]
		local var_36_126 = var_36_124[#var_36_124]

		if var_36_122:GetMode() == BossRushSeriesData.MODE.SINGLE then
			var_36_125 = var_36_124[1]
		end

		local var_36_127 = getProxy(FleetProxy):getActivityFleets()[self.contextData.actId]

		self.mainShips = {}

		local var_36_128 = {}
		local var_36_129 = {}
		local var_36_130 = {}

		local function var_36_131(arg_48_0, arg_48_1, arg_48_2, arg_48_3)
			if table.contains(var_36_8, arg_48_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = arg_48_0

			local var_48_0 = bayProxy:getShipById(arg_48_0)
			local var_48_1 = PrepareShipData(system, var_48_0, arg_48_1)

			table.insert(self.mainShips, var_48_0)
			table.insert(arg_48_3, var_48_0)
			table.insert(arg_48_2, var_48_1)
		end

		local var_36_132 = var_36_127[var_36_125]
		local var_36_133 = _.values(var_36_132:getCommanders())

		battleData.CommanderList = var_36_132:buildBattleBuffList()

		local var_36_134 = var_36_132:getTeamByName(TeamType.Main)
		local var_36_135 = var_36_132:getTeamByName(TeamType.Vanguard)

		for iter_36_48, iter_36_49 in ipairs(var_36_134) do
			var_36_131(iter_36_49, var_36_133, battleData.MainUnitList, var_36_128)
		end

		for iter_36_50, iter_36_51 in ipairs(var_36_135) do
			var_36_131(iter_36_51, var_36_133, battleData.VanguardUnitList, var_36_129)
		end

		local var_36_136 = var_36_127[var_36_126]
		local var_36_137 = _.values(var_36_136:getCommanders())

		battleData.SubCommanderList = var_36_136:buildBattleBuffList()

		local var_36_138 = var_36_136:getTeamByName(TeamType.Submarine)

		for iter_36_52, iter_36_53 in ipairs(var_36_138) do
			var_36_131(iter_36_53, var_36_137, battleData.SubUnitList, var_36_130)
		end

		local var_36_139 = getProxy(PlayerProxy):getRawData()
		local var_36_140 = 0
		local var_36_141 = var_36_122:GetOilLimit()
		local var_36_142 = systemCostTmp.oil_cost > 0

		local function var_36_143(arg_49_0, arg_49_1)
			local var_49_0 = 0

			if var_36_142 then
				local var_49_1 = arg_49_0:getStartCost().oil
				local var_49_2 = arg_49_0:getEndCost().oil

				var_49_0 = var_49_2

				if arg_49_1 > 0 then
					var_49_0 = math.clamp(arg_49_1 - var_49_1, 0, var_49_2)
				end
			end

			return var_49_0
		end

		local var_36_144 = var_36_140 + var_36_143(var_36_132, var_36_141[1]) + var_36_143(var_36_136, var_36_141[2])

		if var_36_136:isLegalToFight() == true and var_36_144 <= var_36_139.oil then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
		end

		self.viewComponent:setFleet(var_36_128, var_36_129, var_36_130)

		if system == SYSTEM_BOSS_RUSH_COLLABRATE then
			battleData.ChapterBuffIDs = {}

			local var_36_145 = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_BUILDING_BUFF)
			local var_36_146 = var_36_145:GetBuildingIds()

			for iter_36_54, iter_36_55 in ipairs(var_36_146) do
				local var_36_147 = var_36_145:GetBuildingLevel(iter_36_55)
				local var_36_148 = var_36_145:GetBuildingConfigTable(iter_36_55).buff[var_36_147]

				if var_36_148 ~= 0 then
					local var_36_149 = ActivityBuff.New(var_36_145.id, var_36_148)

					if var_36_149:isActivate() and var_36_149:getConfig("benefit_type") == ys.Battle.BattleConst.BATTLE_GLOBAL_BUFF then
						local var_36_150 = var_36_149:getConfig("benefit_effect")

						table.insert(battleData.ChapterBuffIDs, var_36_150)
					end
				end
			end

			battleData.DALAidBuffIDs = {}

			local var_36_151 = var_36_122:getConfig("aid_buff")

			if var_36_122:GetBossHpRate() <= var_36_151[1] then
				table.insert(battleData.DALAidBuffIDs, var_36_151[2])
			end
		end
	elseif system == SYSTEM_LIMIT_CHALLENGE then
		local var_36_152 = LimitChallengeConst.GetChallengeIDByStageID(self.contextData.stageId)

		battleData.ExtraBuffList = AcessWithinNull(pg.expedition_constellation_challenge_template[var_36_152], "buff_id")

		local var_36_153 = FleetProxy.CHALLENGE_FLEET_ID
		local var_36_154 = FleetProxy.CHALLENGE_SUB_FLEET_ID
		local var_36_155 = getProxy(FleetProxy)
		local var_36_156 = var_36_155:getFleetById(var_36_153)
		local var_36_157 = var_36_155:getFleetById(var_36_154)

		self.mainShips = {}

		local var_36_158 = {}
		local var_36_159 = {}
		local var_36_160 = {}

		local function var_36_161(arg_50_0, arg_50_1, arg_50_2, arg_50_3)
			if table.contains(var_36_8, arg_50_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_36_8[#var_36_8 + 1] = arg_50_0

			local var_50_0 = bayProxy:getShipById(arg_50_0)
			local var_50_1 = PrepareShipData(system, var_50_0, arg_50_1)

			table.insert(self.mainShips, var_50_0)
			table.insert(arg_50_3, var_50_0)
			table.insert(arg_50_2, var_50_1)
		end

		local var_36_162 = _.values(var_36_156:getCommanders())

		battleData.CommanderList = var_36_156:buildBattleBuffList()

		local var_36_163 = var_36_156:getTeamByName(TeamType.Main)
		local var_36_164 = var_36_156:getTeamByName(TeamType.Vanguard)

		for iter_36_56, iter_36_57 in ipairs(var_36_163) do
			var_36_161(iter_36_57, var_36_162, battleData.MainUnitList, var_36_158)
		end

		for iter_36_58, iter_36_59 in ipairs(var_36_164) do
			var_36_161(iter_36_59, var_36_162, battleData.VanguardUnitList, var_36_159)
		end

		local var_36_165 = _.values(var_36_157:getCommanders())

		battleData.SubCommanderList = var_36_157:buildBattleBuffList()

		local var_36_166 = var_36_157:getTeamByName(TeamType.Submarine)

		for iter_36_60, iter_36_61 in ipairs(var_36_166) do
			var_36_161(iter_36_61, var_36_165, battleData.SubUnitList, var_36_160)
		end

		local var_36_167 = getProxy(PlayerProxy):getRawData()
		local var_36_168 = 0
		local var_36_169 = systemCostTmp.oil_cost > 0

		local function var_36_170(arg_51_0, arg_51_1)
			local var_51_0 = 0

			if var_36_169 then
				local var_51_1 = arg_51_0:getStartCost().oil
				local var_51_2 = arg_51_0:getEndCost().oil

				var_51_0 = var_51_2

				if arg_51_1 > 0 then
					var_51_0 = math.clamp(arg_51_1 - var_51_1, 0, var_51_2)
				end
			end

			return var_51_0
		end

		local var_36_171 = var_36_168 + var_36_170(var_36_156, 0) + var_36_170(var_36_157, 0)

		if var_36_157:isLegalToFight() == true and var_36_171 <= var_36_167.oil then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
		end

		self.viewComponent:setFleet(var_36_158, var_36_159, var_36_160)
	elseif system == SYSTEM_CARDPUZZLE then
		local var_36_172 = {}
		local var_36_173 = {}
		local var_36_174 = self.contextData.relics

		for iter_36_62, iter_36_63 in ipairs(self.contextData.cardPuzzleFleet) do
			local var_36_175 = PrepareCardPuzzleShipData(iter_36_63, var_36_174)
			local var_36_176 = var_36_175.fleetIndex

			if var_36_176 == 1 then
				table.insert(var_36_173, var_36_175)
				table.insert(battleData.VanguardUnitList, var_36_175)
			elseif var_36_176 == 2 then
				table.insert(var_36_172, var_36_175)
				table.insert(battleData.MainUnitList, var_36_175)
			end
		end

		battleData.CardPuzzleCardIDList = self.contextData.cards
		battleData.CardPuzzleCommonHPValue = self.contextData.hp
		battleData.CardPuzzleRelicList = var_36_174
		battleData.CardPuzzleCombatID = self.contextData.puzzleCombatID
	elseif system == SYSTEM_BOSS_SINGLE or system == SYSTEM_BOSS_SINGLE_VARIABLE then
		if self.contextData.mainFleetId then
			local var_36_177 = getProxy(FleetProxy):getActivityFleets()[self.contextData.actId]
			local var_36_178 = var_36_177[self.contextData.mainFleetId]
			local var_36_179 = _.values(var_36_178:getCommanders())

			battleData.CommanderList = var_36_178:buildBattleBuffList()
			self.mainShips = {}

			local var_36_180 = {}
			local var_36_181 = {}
			local var_36_182 = {}

			local function var_36_183(arg_52_0, arg_52_1, arg_52_2, arg_52_3)
				if table.contains(var_36_8, arg_52_0) then
					BattleVertify.cloneShipVertiry = true
				end

				var_36_8[#var_36_8 + 1] = arg_52_0

				local var_52_0 = bayProxy:getShipById(arg_52_0)
				local var_52_1 = PrepareShipData(system, var_52_0, arg_52_1)

				table.insert(self.mainShips, var_52_0)
				table.insert(arg_52_3, var_52_0)
				table.insert(arg_52_2, var_52_1)
			end

			local var_36_184 = var_36_178:getTeamByName(TeamType.Main)
			local var_36_185 = var_36_178:getTeamByName(TeamType.Vanguard)

			for iter_36_64, iter_36_65 in ipairs(var_36_184) do
				var_36_183(iter_36_65, var_36_179, battleData.MainUnitList, var_36_180)
			end

			for iter_36_66, iter_36_67 in ipairs(var_36_185) do
				var_36_183(iter_36_67, var_36_179, battleData.VanguardUnitList, var_36_181)
			end

			local var_36_186 = system == SYSTEM_BOSS_SINGLE_VARIABLE and 100 or 10
			local var_36_187 = var_36_177[self.contextData.mainFleetId + var_36_186]

			if var_36_187 then
				local var_36_188 = _.values(var_36_187:getCommanders())
				local var_36_189 = var_36_187:getTeamByName(TeamType.Submarine)

				for iter_36_68, iter_36_69 in ipairs(var_36_189) do
					var_36_183(iter_36_69, var_36_188, battleData.SubUnitList, var_36_182)
				end
			end

			local var_36_190 = getProxy(PlayerProxy):getRawData()
			local var_36_191 = getProxy(ActivityProxy):getActivityById(self.contextData.actId)

			battleData.ChapterBuffIDs = var_36_191:GetBuffIdsByStageId(self.contextData.stageId)

			local var_36_192 = pg.strategy_data_template

			if self.contextData.variableBuffList then
				for iter_36_70, iter_36_71 in ipairs(self.contextData.variableBuffList) do
					table.insert(battleData.ChapterBuffIDs, var_36_192[iter_36_71].buff_id)
				end
			end

			local var_36_193 = var_36_191:GetEnemyDataByStageId(self.contextData.stageId):GetOilLimit()
			local var_36_194 = 0
			local var_36_195 = systemCostTmp.oil_cost > 0

			local function var_36_196(arg_53_0, arg_53_1)
				if var_36_195 then
					local var_53_0 = arg_53_0:getEndCost().oil

					if arg_53_1 > 0 then
						local var_53_1 = arg_53_0:getStartCost().oil

						cost = math.clamp(arg_53_1 - var_53_1, 0, var_53_0)
					end

					var_36_194 = var_36_194 + var_53_0
				end
			end

			var_36_196(var_36_178, var_36_193[1] or 0)

			if var_36_187 then
				var_36_196(var_36_187, var_36_193[2] or 0)

				if var_36_187:isLegalToFight() == true and var_36_194 <= var_36_190.oil then
					battleData.SubFlag = 1
					battleData.TotalSubAmmo = 1
				end

				battleData.SubCommanderList = var_36_187:buildBattleBuffList()
			end

			self.viewComponent:setFleet(var_36_180, var_36_181, var_36_182)
		end
	elseif system == SYSTEM_SCENARIO_SUB_STRIKE then
		local var_36_197 = {}

		self.mainShips = {}

		local function var_36_198(arg_54_0, arg_54_1, arg_54_2)
			for iter_54_0, iter_54_1 in ipairs(arg_54_0) do
				if table.contains(var_36_8, iter_54_1) then
					BattleVertify.cloneShipVertiry = true
				end

				var_36_8[#var_36_8 + 1] = iter_54_1

				local var_54_0 = bayProxy:getShipById(iter_54_1)
				local var_54_1 = PrepareShipData(system, var_54_0, nil)

				table.insert(arg_54_1, var_54_0)
				table.insert(self.mainShips, var_54_0)
				table.insert(arg_54_2, var_54_1)
			end
		end

		local var_36_199 = getProxy(ChapterProxy):getActiveChapter()

		self.viewComponent:setChapter(var_36_199)
		self.viewComponent:setFleet(nil, nil, var_36_197)

		local var_36_200 = var_36_199:getChapterSupportFleet():getTeamByName(TeamType.Submarine)

		var_36_198(var_36_200, var_36_197, battleData.SubUnitList)
	elseif self.contextData.mainFleetId then
		local var_36_201 = system == SYSTEM_DUEL
		local var_36_202 = getProxy(FleetProxy)
		local var_36_203
		local var_36_204
		local var_36_205 = var_36_202:getFleetById(self.contextData.mainFleetId)

		self.mainShips = bayProxy:getShipsByFleet(var_36_205)

		local var_36_206 = {}
		local var_36_207 = {}
		local var_36_208 = {}

		local function var_36_209(arg_55_0, arg_55_1, arg_55_2)
			for iter_55_0, iter_55_1 in ipairs(arg_55_0) do
				if table.contains(var_36_8, iter_55_1) then
					BattleVertify.cloneShipVertiry = true
				end

				var_36_8[#var_36_8 + 1] = iter_55_1

				local var_55_0 = bayProxy:getShipById(iter_55_1)
				local var_55_1 = PrepareShipData(system, var_55_0, nil, var_36_201)

				table.insert(arg_55_1, var_55_0)
				table.insert(arg_55_2, var_55_1)
			end
		end

		local var_36_210 = var_36_205:getTeamByName(TeamType.Main)
		local var_36_211 = var_36_205:getTeamByName(TeamType.Vanguard)
		local var_36_212 = var_36_205:getTeamByName(TeamType.Submarine)

		var_36_209(var_36_210, var_36_206, battleData.MainUnitList)
		var_36_209(var_36_211, var_36_207, battleData.VanguardUnitList)
		var_36_209(var_36_212, var_36_208, battleData.SubUnitList)
		self.viewComponent:setFleet(var_36_206, var_36_207, var_36_208)

		if BATTLE_DEBUG and BATTLE_FREE_SUBMARINE then
			local var_36_213 = var_36_202:getFleetById(11)
			local var_36_214 = var_36_213:getTeamByName(TeamType.Submarine)

			if #var_36_214 > 0 then
				battleData.SubFlag = 1
				battleData.TotalSubAmmo = 1

				local var_36_215 = _.values(var_36_213:getCommanders())

				battleData.SubCommanderList = var_36_213:buildBattleBuffList()

				for iter_36_72, iter_36_73 in ipairs(var_36_214) do
					local var_36_216 = bayProxy:getShipById(iter_36_73)
					local var_36_217 = PrepareShipData(system, var_36_216, var_36_215, var_36_201)

					table.insert(var_36_208, var_36_216)
					table.insert(battleData.SubUnitList, var_36_217)
				end
			end
		end
	end

	if system == SYSTEM_WORLD then
		local var_36_218 = nowWorld()
		local var_36_219 = var_36_218:GetActiveMap()
		local var_36_220 = var_36_219:GetFleet()
		local var_36_221 = var_36_219:GetCell(var_36_220.row, var_36_220.column):GetStageEnemy()
		local var_36_222 = pg.world_expedition_data[self.contextData.stageId]
		local var_36_223 = var_36_218:GetWorldMapDifficultyBuffLevel()

		battleData.EnemyMapRewards = {
			var_36_223[1] * (1 + var_36_222.expedition_sairenvalueA / 10000),
			var_36_223[2] * (1 + var_36_222.expedition_sairenvalueB / 10000),
			var_36_223[3] * (1 + var_36_222.expedition_sairenvalueC / 10000)
		}
		battleData.FleetMapRewards = var_36_218:GetWorldMapBuffLevel()
	end

	battleData.RivalMainUnitList, battleData.RivalVanguardUnitList = {}, {}

	local var_36_224

	if system == SYSTEM_DUEL and self.contextData.rivalId then
		local var_36_225 = getProxy(MilitaryExerciseProxy)

		var_36_224 = var_36_225:getRivalById(self.contextData.rivalId)
		self.oldRank = var_36_225:getSeasonInfo()
	end

	if var_36_224 then
		battleData.RivalVO = var_36_224

		local var_36_226 = 0

		for iter_36_74, iter_36_75 in ipairs(var_36_224.mainShips) do
			var_36_226 = var_36_226 + iter_36_75.level
		end

		for iter_36_76, iter_36_77 in ipairs(var_36_224.vanguardShips) do
			var_36_226 = var_36_226 + iter_36_77.level
		end

		BattleVertify = BattleVertify or {}
		BattleVertify.rivalLevel = var_36_226

		for iter_36_78, iter_36_79 in ipairs(var_36_224.mainShips) do
			if not iter_36_79.hpRant or iter_36_79.hpRant > 0 then
				local var_36_227 = PrepareShipData(system, iter_36_79, nil, true)

				if iter_36_79.hpRant then
					var_36_227.initHPRate = iter_36_79.hpRant * 0.0001
				end

				table.insert(battleData.RivalMainUnitList, var_36_227)
			end
		end

		for iter_36_80, iter_36_81 in ipairs(var_36_224.vanguardShips) do
			if not iter_36_81.hpRant or iter_36_81.hpRant > 0 then
				local var_36_228 = PrepareShipData(system, iter_36_81, nil, true)

				if iter_36_81.hpRant then
					var_36_228.initHPRate = iter_36_81.hpRant * 0.0001
				end

				table.insert(battleData.RivalVanguardUnitList, var_36_228)
			end
		end
	end

	local var_36_229 = self.contextData.prefabFleet.main_unitList
	local var_36_230 = self.contextData.prefabFleet.vanguard_unitList
	local var_36_231 = self.contextData.prefabFleet.submarine_unitList

	if var_36_229 then
		for iter_36_82, iter_36_83 in ipairs(var_36_229) do
			local var_36_232 = {}

			for iter_36_84, iter_36_85 in ipairs(iter_36_83.equipment) do
				var_36_232[#var_36_232 + 1] = {
					skin = 0,
					id = iter_36_85
				}
			end

			local var_36_233 = {
				id = iter_36_83.id,
				tmpID = iter_36_83.configId,
				skinId = iter_36_83.skinId,
				level = iter_36_83.level,
				equipment = var_36_232,
				properties = iter_36_83.properties,
				baseProperties = iter_36_83.properties,
				proficiency = {
					1,
					1,
					1
				},
				skills = iter_36_83.skills
			}

			table.insert(battleData.MainUnitList, var_36_233)
		end
	end

	if var_36_230 then
		for iter_36_86, iter_36_87 in ipairs(var_36_230) do
			local var_36_234 = {}

			for iter_36_88, iter_36_89 in ipairs(iter_36_87.equipment) do
				var_36_234[#var_36_234 + 1] = {
					skin = 0,
					id = iter_36_89
				}
			end

			local var_36_235 = {
				id = iter_36_87.id,
				tmpID = iter_36_87.configId,
				skinId = iter_36_87.skinId,
				level = iter_36_87.level,
				equipment = var_36_234,
				properties = iter_36_87.properties,
				baseProperties = iter_36_87.properties,
				proficiency = {
					1,
					1,
					1
				},
				skills = iter_36_87.skills
			}

			table.insert(battleData.VanguardUnitList, var_36_235)
		end
	end

	if var_36_231 then
		for iter_36_90, iter_36_91 in ipairs(var_36_231) do
			local var_36_236 = {}

			for iter_36_92, iter_36_93 in ipairs(iter_36_91.equipment) do
				var_36_236[#var_36_236 + 1] = {
					skin = 0,
					id = iter_36_93
				}
			end

			local var_36_237 = {
				id = iter_36_91.id,
				tmpID = iter_36_91.configId,
				skinId = iter_36_91.skinId,
				level = iter_36_91.level,
				equipment = var_36_236,
				properties = iter_36_91.properties,
				baseProperties = iter_36_91.properties,
				proficiency = {
					1,
					1,
					1
				},
				skills = iter_36_91.skills
			}

			table.insert(battleData.SubUnitList, var_36_237)

			if system == SYSTEM_SIMULATION and #battleData.SubUnitList > 0 then
				battleData.SubFlag = 1
				battleData.TotalSubAmmo = 1
			end
		end
	end
end

function BattleMediator.listNotificationInterests(arg_56_0)
	return {
		GAME.FINISH_STAGE_DONE,
		GAME.FINISH_STAGE_ERROR,
		GAME.STORY_BEGIN,
		GAME.STORY_END,
		GAME.END_GUIDE,
		GAME.START_GUIDE,
		GAME.PAUSE_BATTLE,
		GAME.RESUME_BATTLE,
		BattleMediator.CLOSE_CHAT,
		GAME.QUIT_BATTLE,
		BattleMediator.HIDE_ALL_BUTTONS,
		BattleMediator.UPDATE_AUTO_COUNT
	}
end

function BattleMediator.handleNotification(arg_57_0, arg_57_1)
	local var_57_0 = arg_57_1:getName()
	local var_57_1 = arg_57_1:getBody()
	local var_57_2 = ys.Battle.BattleState.GetInstance()
	local var_57_3 = arg_57_0.contextData.system

	if var_57_0 == GAME.FINISH_STAGE_DONE then
		pg.MsgboxMgr.GetInstance():hide()

		local var_57_4 = var_57_1.system

		if var_57_4 == SYSTEM_PROLOGUE then
			ys.Battle.BattleState.GetInstance():Deactive()
			arg_57_0:sendNotification(GAME.CHANGE_SCENE, SCENE.CREATE_PLAYER)
		elseif var_57_4 == SYSTEM_PERFORM or var_57_4 == SYSTEM_SIMULATION then
			ys.Battle.BattleState.GetInstance():Deactive()
			arg_57_0.viewComponent:exitBattle()

			if var_57_1.exitCallback then
				var_57_1.exitCallback()
			end
		else
			local var_57_5 = BattleResultMediator.GetResultView(var_57_4)
			local var_57_6 = {}

			if var_57_4 == SYSTEM_SCENARIO then
				var_57_6 = getProxy(ChapterProxy):getActiveChapter().operationBuffList
			end

			arg_57_0:addSubLayers(Context.New({
				mediator = NewBattleResultMediator,
				viewComponent = NewBattleResultScene,
				data = {
					system = var_57_4,
					rivalId = arg_57_0.contextData.rivalId,
					mainFleetId = arg_57_0.contextData.mainFleetId,
					stageId = arg_57_0.contextData.stageId,
					oldMainShips = arg_57_0.mainShips or {},
					oldPlayer = arg_57_0.player,
					oldRank = arg_57_0.oldRank,
					statistics = var_57_1.statistics,
					score = var_57_1.score,
					drops = var_57_1.drops,
					bossId = var_57_1.bossId,
					name = var_57_1.name,
					prefabFleet = var_57_1.prefabFleet,
					commanderExps = var_57_1.commanderExps,
					actId = arg_57_0.contextData.actId,
					result = var_57_1.result,
					extraDrops = var_57_1.extraDrops,
					extraBuffList = var_57_6,
					isLastBonus = var_57_1.isLastBonus,
					continuousBattleTimes = arg_57_0.contextData.continuousBattleTimes,
					totalBattleTimes = arg_57_0.contextData.totalBattleTimes,
					mode = arg_57_0.contextData.mode,
					cmdArgs = arg_57_0.contextData.cmdArgs,
					variableBuffList = arg_57_0.contextData.variableBuffList,
					useVariableTicket = arg_57_0.contextData.useVariableTicket
				}
			}))
		end
	elseif var_57_0 == GAME.STORY_BEGIN then
		var_57_2:Pause()
	elseif var_57_0 == GAME.STORY_END then
		var_57_2:Resume()
	elseif var_57_0 == GAME.START_GUIDE then
		var_57_2:Pause()
	elseif var_57_0 == GAME.END_GUIDE then
		var_57_2:Resume()
	elseif var_57_0 == GAME.PAUSE_BATTLE then
		if not var_57_2:IsPause() then
			arg_57_0:onPauseBtn()
		end
	elseif var_57_0 == GAME.RESUME_BATTLE then
		var_57_2:Resume()
	elseif var_57_0 == GAME.FINISH_STAGE_ERROR then
		gcAll(true)

		local var_57_7 = getProxy(ContextProxy)
		local var_57_8 = var_57_7:getContextByMediator(DailyLevelMediator)
		local var_57_9 = var_57_7:getContextByMediator(LevelMediator2)
		local var_57_10 = var_57_7:getContextByMediator(ChallengeMainMediator)
		local var_57_11 = var_57_7:getContextByMediator(ActivityBossMediatorTemplate)

		if var_57_8 then
			local var_57_12 = var_57_8:getContextByMediator(PreCombatMediator)

			var_57_8:removeChild(var_57_12)
		elseif var_57_10 then
			local var_57_13 = var_57_10:getContextByMediator(ChallengePreCombatMediator)

			var_57_10:removeChild(var_57_13)
		elseif var_57_9 then
			if var_57_3 == SYSTEM_DUEL then
				-- block empty
			elseif var_57_3 == SYSTEM_SCENARIO then
				local var_57_14 = var_57_9:getContextByMediator(ChapterPreCombatMediator)

				var_57_9:removeChild(var_57_14)
			elseif var_57_3 ~= SYSTEM_PERFORM and var_57_3 ~= SYSTEM_SIMULATION then
				local var_57_15 = var_57_9:getContextByMediator(PreCombatMediator)

				if var_57_15 then
					var_57_9:removeChild(var_57_15)
				end
			end
		elseif var_57_11 then
			local var_57_16 = var_57_11:getContextByMediator(PreCombatMediator)

			if var_57_16 then
				var_57_11:removeChild(var_57_16)
			end
		end

		arg_57_0:sendNotification(GAME.GO_BACK)
	elseif var_57_0 == BattleMediator.CLOSE_CHAT then
		arg_57_0.viewComponent:OnCloseChat()
	elseif var_57_0 == BattleMediator.HIDE_ALL_BUTTONS then
		ys.Battle.BattleState.GetInstance():GetProxyByName(ys.Battle.BattleDataProxy.__name):DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.HIDE_INTERACTABLE_BUTTONS, {
			isActive = var_57_1
		}))
	elseif var_57_0 == GAME.QUIT_BATTLE then
		var_57_2:Stop()
	elseif var_57_0 == BattleMediator.UPDATE_AUTO_COUNT then
		arg_57_0:updateAutoCount(var_57_1)
	end
end

function BattleMediator.remove(arg_58_0)
	pg.BrightnessMgr.GetInstance():SetScreenNeverSleep(false)
end

return BattleMediator
