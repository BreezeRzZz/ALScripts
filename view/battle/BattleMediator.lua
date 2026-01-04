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
	else
		var_27_3 = i18n("battle_battleMediator_quest_exist")
	end

	local function var_27_6()
		if arg_27_1 then
			arg_27_1()
		end

		local var_29_0 = arg_27_0.viewComponent.leaveBtn:GetComponent(typeof(Animation))

		if var_29_0 then
			var_29_0:Play("msgbox_btn_into")
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

function BattleMediator.guideDispatch(arg_30_0)
	return
end
-- TODO
local function genSingleShipData(system, ship, commanders, inDuel)
	local equipmentInfo = {}

	for _, activeEquipment in ipairs(ship:getActiveEquipments()) do
		if activeEquipment then
			equipmentInfo[#equipmentInfo + 1] = {
				id = activeEquipment.configId,
				skin = activeEquipment.skinId,
				equipmentInfo = activeEquipment
			}
		else
			equipmentInfo[#equipmentInfo + 1] = {
				skin = 0,
				id = activeEquipment,
				equipmentInfo = activeEquipment
			}
		end
	end

	local buffList = {}

	-- 根据模式，转换某些技能ID
	local function remapSkillBySystem(buffData)
		local remapedBuffData = {
			level = buffData.level
		}
		local buffID = buffData.id
		local remapedBuffID = ship:RemapSkillId(buffID, true)

		remapedBuffData.id = ys.Battle.BattleDataFunction.SkillTranform(system, remapedBuffID)

		return remapedBuffData
	end

	local hideBuffList = ys.Battle.BattleDataFunction.GenerateHiddenBuff(ship.configId)

	for _, hideBuffData in pairs(hideBuffList) do
		local buffData = remapSkillBySystem(hideBuffData)

		buffList[buffData.id] = buffData
	end

	for _, shipBuffData in pairs(ship.skills) do
		-- 何意味? 这两个特殊处理...
		if shipBuffData and shipBuffData.id == 14900 and not ship.transforms[16412] then
			-- block empty
		else
			local buffData = remapSkillBySystem(shipBuffData)

			buffList[buffData.id] = buffData
		end
	end

	local equipBuffList = ys.Battle.BattleDataFunction.GetEquipSkill(equipmentInfo)

	for _, equipBuffData in ipairs(equipBuffList) do
		local buffData = {
			level = equipBuffData.buffLV,
			id = ys.Battle.BattleDataFunction.SkillTranform(system, equipBuffData.buffID)
		}

		buffList[buffData.id] = buffData
	end

	local spWeapon

	;(function()
		spWeapon = ship:GetSpWeapon()

		if not spWeapon then
			return
		end

		local spWeaponEffect = spWeapon:GetEffect()

		if spWeaponEffect == 0 then
			return
		end

		local spWeaponEffectData = {}

		spWeaponEffectData.level = 1
		spWeaponEffectData.id = ys.Battle.BattleDataFunction.SkillTranform(system, spWeaponEffect)
		buffList[spWeaponEffectData.id] = spWeaponEffectData
	end)()

	for _, triggerBuffData in pairs(ship:getTriggerSkills()) do
		local buffData = {
			level = triggerBuffData.level,
			id = ys.Battle.BattleDataFunction.SkillTranform(system, triggerBuffData.id)
		}

		buffList[buffData.id] = buffData
	end

	local inWorld = system == SYSTEM_WORLD
	local isBrokenInWorld = false

	if inWorld then
		local worldShip = WorldConst.FetchWorldShip(ship.id)

		if worldShip then
			isBrokenInWorld = worldShip:IsBroken()
		end
	end

	if isBrokenInWorld then
		for buffID, _ in pairs(buffList) do
			local deathMark = pg.skill_data_template[buffID].world_death_mark[1]
			-- 1表示该技能在战损状态下失效，0表示忽略战损状态
			if deathMark == ys.Battle.BattleConst.DEATH_MARK_SKILL.DEACTIVE then
				buffList[buffID] = nil
			elseif deathMark == ys.Battle.BattleConst.DEATH_MARK_SKILL.IGNORE then
				-- block empty
			end
		end
	end
	-- 此处连接Ship和BattleDataProxy
	return {
		id = ship.id,
		tmpID = ship.configId,
		skinId = ship.skinId,
		level = ship.level,
		equipment = equipmentInfo,
		properties = ship:getProperties(commanders, inDuel, inWorld),
		baseProperties = ship:getShipProperties(),
		proficiency = ship:getEquipProficiencyList(),
		rarity = ship:getRarity(),
		intimacy = ship:getCVIntimacy(),
		shipGS = ship:getShipCombatPower(),
		skills = buffList,
		baseList = ship:getBaseList(),
		preloasList = ship:getPreLoadCount(),
		name = ship:getName(),
		deathMark = isBrokenInWorld,
		spWeapon = spWeapon
	}
end

local function var_0_2(arg_34_0, arg_34_1)
	local var_34_0 = arg_34_0:getProperties(arg_34_1)
	local var_34_1 = arg_34_0:getConfig("id")

	return {
		deathMark = false,
		shipGS = 100,
		rarity = 1,
		intimacy = 100,
		id = var_34_1,
		tmpID = var_34_1,
		skinId = arg_34_0:getConfig("skin_id"),
		level = arg_34_0:getConfig("level"),
		equipment = arg_34_0:getConfig("default_equip"),
		properties = var_34_0,
		baseProperties = var_34_0,
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
		name = var_34_1,
		fleetIndex = arg_34_0:getConfig("location")
	}
end

-- note: 生成基础战斗数据，用于在后续的BattleState和BattleDataProxy来实际构建各种战斗中的数据结构
function BattleMediator.GenBattleData(self)
	local battleData = {}
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
	-- battle_cost_template是根据不同的战斗系统(场景)来配置油耗数据
	-- 并可以定义global_buff_effected来指定是否启用全局buff
	if pg.battle_cost_template[system].global_buff_effected > 0 then
		local battleBuffs = BuffHelper.GetBattleBuffs(system)
		local globalBuffIDs = {}
		-- buff: CommonBuff类
		-- 这里的Buff指的都是全局Buff，比如活动提供的全局增益buff
		for _, buff in ipairs(battleBuffs) do
			-- 可以到benefit_buff_template中查看
			local benefit_condition = buff:getConfig("benefit_condition")
			local isActive = false

			if benefit_condition[1] == "chapter" then
				-- 在指定的章节中生效
				if system == SYSTEM_SCENARIO and table.contains(benefit_condition[2], getProxy(ChapterProxy):getActiveChapter().id) then
					isActive = true
				end
			else
				isActive = true
			end

			if isActive then
				table.insert(globalBuffIDs, buff:getConfig("benefit_effect"))
			end
		end

		battleData.GlobalBuffIDs = globalBuffIDs
	end

	local battleCostTmp = pg.battle_cost_template[system]
	-- bayProxy指的是船坞proxy
	local bayProxy = getProxy(BayProxy)
	local var_35_8 = {}
	-- SCENARIO指的是最常见的模式(Chapter)
	if system == SYSTEM_SCENARIO then
		local chapterProxy = getProxy(ChapterProxy)
		--- @type ChapterLevelData
		local activeChapter = chapterProxy:getActiveChapter()

		battleData.RepressInfo = activeChapter:getRepressInfo()

		self.viewComponent:setChapter(activeChapter)
		--- @type ChapterFleet
		local chapterFleet = activeChapter.fleet

		battleData.KizunaJamming = activeChapter.extraFlagList
		battleData.DefeatCount = chapterFleet:getDefeatCount()
		battleData.ChapterBuffIDs, battleData.CommanderList = activeChapter:getFleetBattleBuffs(chapterFleet)
		battleData.StageWaveFlags = activeChapter:GetStageFlags()
		battleData.ChapterWeatherIDS = activeChapter:GetWeather(chapterFleet.line.row, chapterFleet.line.column)
		battleData.MapAuraSkills = chapterProxy.GetChapterAuraBuffs(activeChapter)
		battleData.MapAidSkills = {}
		battleData.ChapterType = activeChapter:getPlayType()

		local chapterAidBuffs = chapterProxy.GetChapterAidBuffs(activeChapter)

		for ship, shipAidList in pairs(chapterAidBuffs) do
			local fleet = activeChapter:getFleetByShipVO(ship)
			-- underscore.values表示获取table中的所有value，返回一个数组
			local commanders = _.values(fleet:getCommanders())
			local shipData = genSingleShipData(system, ship, commanders)

			table.insert(battleData.AidUnitList, shipData)

			for _, shipAidData in ipairs(shipAidList) do
				table.insert(battleData.MapAidSkills, shipAidData)
			end
		end
		
		local mainShipList = chapterFleet:getShipsByTeam(TeamType.Main, false)
		local vanguardShipList = chapterFleet:getShipsByTeam(TeamType.Vanguard, false)
		local subShipList = {}
		local commanders = _.values(chapterFleet:getCommanders())
		local subCommanders = {}
		local subAidFlag, subFleet = chapterProxy.getSubAidFlag(activeChapter, self.contextData.stageId)

		if subAidFlag == true or subAidFlag > 0 then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
			subShipList = subFleet:getShipsByTeam(TeamType.Submarine, false)
			subCommanders = _.values(subFleet:getCommanders())

			local _, subCommanderList = activeChapter:getFleetBattleBuffs(subFleet)
			-- ? 具体都是什么数据结构?
			battleData.SubCommanderList = subCommanderList
		else
			battleData.SubFlag = subAidFlag

			if subAidFlag ~= ys.Battle.BattleConst.SubAidFlag.AID_EMPTY then
				battleData.TotalSubAmmo = 0
			end
		end

		self.mainShips = {}

		local function insertShipToList(ship, commanders, unitList)
			local shipID = ship.id
			-- rant是0~10000的整数表示，所以需要乘以0.0001转换为0~1的小数
			local hpRate = ship.hpRant * 0.0001

			if table.contains(var_35_8, shipID) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = shipID

			local shipData = genSingleShipData(system, ship, commanders)

			shipData.initHPRate = hpRate

			table.insert(self.mainShips, ship)
			table.insert(unitList, shipData)
		end

		for _, mainShip in ipairs(mainShipList) do
			insertShipToList(mainShip, commanders, battleData.MainUnitList)
		end

		for _, vanguardShip in ipairs(vanguardShipList) do
			insertShipToList(vanguardShip, commanders, battleData.VanguardUnitList)
		end

		for _, subShip in ipairs(subShipList) do
			insertShipToList(subShip, subCommanders, battleData.SubUnitList)
		end

		local chapterSupportFleet = activeChapter:getChapterSupportFleet()

		if chapterSupportFleet then
			local supportShips = chapterSupportFleet:getShips()

			for _, supportShip in pairs(supportShips) do
				insertShipToList(supportShip, {}, battleData.SupportUnitList)
			end
		end

		self.viewComponent:setFleet(mainShipList, vanguardShipList, subShipList)
	elseif system == SYSTEM_CHALLENGE then
		local var_35_28 = self.contextData.mode
		local var_35_29 = getProxy(ChallengeProxy):getUserChallengeInfo(var_35_28)

		battleData.ChallengeInfo = var_35_29

		self.viewComponent:setChapter(var_35_29)

		local var_35_30 = var_35_29:getRegularFleet()

		battleData.CommanderList = var_35_30:buildBattleBuffList()

		local var_35_31 = _.values(var_35_30:getCommanders())
		local var_35_32 = {}
		local var_35_33 = var_35_30:getShipsByTeam(TeamType.Main, false)
		local var_35_34 = var_35_30:getShipsByTeam(TeamType.Vanguard, false)
		local var_35_35 = {}
		local var_35_36 = var_35_29:getSubmarineFleet()
		local var_35_37 = var_35_36:getShipsByTeam(TeamType.Submarine, false)

		if #var_35_37 > 0 then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
			var_35_32 = _.values(var_35_36:getCommanders())
			battleData.SubCommanderList = var_35_36:buildBattleBuffList()
		else
			battleData.SubFlag = 0
			battleData.TotalSubAmmo = 0
		end

		self.mainShips = {}

		local function var_35_38(arg_37_0, arg_37_1, arg_37_2)
			local var_37_0 = arg_37_0.id
			local var_37_1 = arg_37_0.hpRant * 0.0001

			if table.contains(var_35_8, var_37_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = var_37_0

			local var_37_2 = genSingleShipData(system, arg_37_0, arg_37_1)

			var_37_2.initHPRate = var_37_1

			table.insert(self.mainShips, arg_37_0)
			table.insert(arg_37_2, var_37_2)
		end

		for iter_35_14, iter_35_15 in ipairs(var_35_33) do
			var_35_38(iter_35_15, var_35_31, battleData.MainUnitList)
		end

		for iter_35_16, iter_35_17 in ipairs(var_35_34) do
			var_35_38(iter_35_17, var_35_31, battleData.VanguardUnitList)
		end

		for iter_35_18, iter_35_19 in ipairs(var_35_37) do
			var_35_38(iter_35_19, var_35_32, battleData.SubUnitList)
		end

		self.viewComponent:setFleet(var_35_33, var_35_34, var_35_37)
	-- from here, TODO
	elseif system == SYSTEM_WORLD then
		local var_35_39 = nowWorld()
		local var_35_40 = var_35_39:GetActiveMap()
		local var_35_41 = var_35_40:GetFleet()
		local var_35_42 = var_35_40:GetCell(var_35_41.row, var_35_41.column):GetStageEnemy()

		if self.contextData.hpRate then
			battleData.RepressInfo = {
				repressEnemyHpRant = self.contextData.hpRate
			}
		end

		battleData.AffixBuffList = table.mergeArray(var_35_42:GetBattleLuaBuffs(), var_35_40:GetBattleLuaBuffs(WorldMap.FactionEnemy, var_35_42))

		local function var_35_43(arg_38_0)
			local var_38_0 = {}

			for iter_38_0, iter_38_1 in ipairs(arg_38_0) do
				local var_38_1 = {
					id = ys.Battle.BattleDataFunction.SkillTranform(system, iter_38_1.id),
					level = iter_38_1.level
				}

				table.insert(var_38_0, var_38_1)
			end

			return var_38_0
		end

		battleData.DefeatCount = var_35_41:getDefeatCount()
		battleData.ChapterBuffIDs, battleData.CommanderList = var_35_40:getFleetBattleBuffs(var_35_41, true)
		battleData.MapAuraSkills = var_35_40:GetChapterAuraBuffs()
		battleData.MapAuraSkills = var_35_43(battleData.MapAuraSkills)
		battleData.MapAidSkills = {}

		local var_35_44 = var_35_40:GetChapterAidBuffs()

		for iter_35_20, iter_35_21 in pairs(var_35_44) do
			local var_35_45 = var_35_40:GetFleet(iter_35_20.fleetId)
			local var_35_46 = _.values(var_35_45:getCommanders(true))
			local var_35_47 = genSingleShipData(system, WorldConst.FetchShipVO(iter_35_20.id), var_35_46)

			table.insert(battleData.AidUnitList, var_35_47)

			battleData.MapAidSkills = table.mergeArray(battleData.MapAidSkills, var_35_43(iter_35_21))
		end

		local var_35_48 = var_35_41:GetTeamShipVOs(TeamType.Main, false)
		local var_35_49 = var_35_41:GetTeamShipVOs(TeamType.Vanguard, false)
		local var_35_50 = {}
		local var_35_51 = _.values(var_35_41:getCommanders(true))
		local var_35_52 = {}
		local var_35_53 = var_35_39:GetSubAidFlag()

		if var_35_53 == true then
			local var_35_54 = var_35_40:GetSubmarineFleet()

			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
			var_35_50 = var_35_54:GetTeamShipVOs(TeamType.Submarine, false)
			var_35_52 = _.values(var_35_54:getCommanders(true))

			local var_35_55, var_35_56 = var_35_40:getFleetBattleBuffs(var_35_54, true)

			battleData.SubCommanderList = var_35_56
		else
			battleData.SubFlag = 0

			if var_35_53 ~= ys.Battle.BattleConst.SubAidFlag.AID_EMPTY then
				battleData.TotalSubAmmo = 0
			end
		end

		self.mainShips = {}

		for iter_35_22, iter_35_23 in ipairs(var_35_48) do
			local var_35_57 = iter_35_23.id
			local var_35_58 = WorldConst.FetchWorldShip(iter_35_23.id).hpRant * 0.0001

			if table.contains(var_35_8, var_35_57) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = var_35_57

			local var_35_59 = genSingleShipData(system, iter_35_23, var_35_51)

			var_35_59.initHPRate = var_35_58

			table.insert(self.mainShips, iter_35_23)
			table.insert(battleData.MainUnitList, var_35_59)
		end

		for iter_35_24, iter_35_25 in ipairs(var_35_49) do
			local var_35_60 = iter_35_25.id
			local var_35_61 = WorldConst.FetchWorldShip(iter_35_25.id).hpRant * 0.0001

			if table.contains(var_35_8, var_35_60) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = var_35_60

			local var_35_62 = genSingleShipData(system, iter_35_25, var_35_51)

			var_35_62.initHPRate = var_35_61

			table.insert(self.mainShips, iter_35_25)
			table.insert(battleData.VanguardUnitList, var_35_62)
		end

		for iter_35_26, iter_35_27 in ipairs(var_35_50) do
			local var_35_63 = iter_35_27.id
			local var_35_64 = WorldConst.FetchWorldShip(iter_35_27.id).hpRant * 0.0001

			if table.contains(var_35_8, var_35_63) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = var_35_63

			local var_35_65 = genSingleShipData(system, iter_35_27, var_35_52)

			var_35_65.initHPRate = var_35_64

			table.insert(self.mainShips, iter_35_27)
			table.insert(battleData.SubUnitList, var_35_65)
		end

		self.viewComponent:setFleet(var_35_48, var_35_49, var_35_50)

		local var_35_66 = pg.expedition_data_template[self.contextData.stageId]

		if var_35_66.difficulty == ys.Battle.BattleConst.Difficulty.WORLD then
			battleData.WorldMapId = var_35_40.config.expedition_map_id
			battleData.WorldLevel = WorldConst.WorldLevelCorrect(var_35_40.config.expedition_level, var_35_66.type)
		end
	elseif system == SYSTEM_WORLD_BOSS then
		local var_35_67 = nowWorld():GetBossProxy()
		local var_35_68 = self.contextData.bossId
		local var_35_69 = var_35_67:GetFleet(var_35_68)
		local var_35_70 = var_35_67:GetBossById(var_35_68)

		if self.contextData.hpRate then
			battleData.RepressInfo = {
				repressEnemyHpRant = self.contextData.hpRate
			}
		end

		local var_35_71 = _.values(var_35_69:getCommanders())

		battleData.CommanderList = var_35_69:buildBattleBuffList()
		self.mainShips = bayProxy:getShipsByFleet(var_35_69)

		local var_35_72 = {}
		local var_35_73 = {}
		local var_35_74 = {}
		local var_35_75 = var_35_69:getTeamByName(TeamType.Main)

		for iter_35_28, iter_35_29 in ipairs(var_35_75) do
			if table.contains(var_35_8, iter_35_29) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = iter_35_29

			local var_35_76 = bayProxy:getShipById(iter_35_29)
			local var_35_77 = genSingleShipData(system, var_35_76, var_35_71)

			table.insert(var_35_72, var_35_76)
			table.insert(battleData.MainUnitList, var_35_77)
		end

		local var_35_78 = var_35_69:getTeamByName(TeamType.Vanguard)

		for iter_35_30, iter_35_31 in ipairs(var_35_78) do
			if table.contains(var_35_8, iter_35_31) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = iter_35_31

			local var_35_79 = bayProxy:getShipById(iter_35_31)
			local var_35_80 = genSingleShipData(system, var_35_79, var_35_71)

			table.insert(var_35_73, var_35_79)
			table.insert(battleData.VanguardUnitList, var_35_80)
		end

		self.viewComponent:setFleet(var_35_72, var_35_73, var_35_74)

		battleData.MapAidSkills = {}

		if var_35_70 and var_35_70:IsSelf() then
			local var_35_81, var_35_82, var_35_83 = var_35_67.GetSupportValue()

			if var_35_81 then
				table.insert(battleData.MapAidSkills, {
					level = 1,
					id = var_35_83
				})
			end
		end
	elseif system == SYSTEM_HP_SHARE_ACT_BOSS or system == SYSTEM_ACT_BOSS or system == SYSTEM_ACT_BOSS_SP or system == SYSTEM_BOSS_EXPERIMENT then
		if self.contextData.mainFleetId then
			local var_35_84 = getProxy(FleetProxy):getActivityFleets()[self.contextData.actId]
			local var_35_85 = var_35_84[self.contextData.mainFleetId]
			local var_35_86 = _.values(var_35_85:getCommanders())

			battleData.CommanderList = var_35_85:buildBattleBuffList()
			self.mainShips = {}

			local var_35_87 = {}
			local var_35_88 = {}
			local var_35_89 = {}

			local function var_35_90(arg_39_0, arg_39_1, arg_39_2, arg_39_3)
				if table.contains(var_35_8, arg_39_0) then
					BattleVertify.cloneShipVertiry = true
				end

				var_35_8[#var_35_8 + 1] = arg_39_0

				local var_39_0 = bayProxy:getShipById(arg_39_0)
				local var_39_1 = genSingleShipData(system, var_39_0, arg_39_1)

				table.insert(self.mainShips, var_39_0)
				table.insert(arg_39_3, var_39_0)
				table.insert(arg_39_2, var_39_1)
			end

			local var_35_91 = var_35_85:getTeamByName(TeamType.Main)
			local var_35_92 = var_35_85:getTeamByName(TeamType.Vanguard)

			for iter_35_32, iter_35_33 in ipairs(var_35_91) do
				var_35_90(iter_35_33, var_35_86, battleData.MainUnitList, var_35_87)
			end

			for iter_35_34, iter_35_35 in ipairs(var_35_92) do
				var_35_90(iter_35_35, var_35_86, battleData.VanguardUnitList, var_35_88)
			end

			local var_35_93 = var_35_84[self.contextData.mainFleetId + 10]
			local var_35_94 = _.values(var_35_93:getCommanders())
			local var_35_95 = var_35_93:getTeamByName(TeamType.Submarine)

			for iter_35_36, iter_35_37 in ipairs(var_35_95) do
				var_35_90(iter_35_37, var_35_94, battleData.SubUnitList, var_35_89)
			end

			local var_35_96 = getProxy(PlayerProxy):getRawData()
			local var_35_97 = getProxy(ActivityProxy):getActivityById(self.contextData.actId)
			local var_35_98 = var_35_97:getConfig("config_id")
			local var_35_99 = pg.activity_event_worldboss[var_35_98].use_oil_limit[self.contextData.mainFleetId]
			local var_35_100 = var_35_97:IsOilLimit(self.contextData.stageId)
			local var_35_101 = 0
			local var_35_102 = battleCostTmp.oil_cost > 0

			local function var_35_103(arg_40_0, arg_40_1)
				if var_35_102 then
					local var_40_0 = arg_40_0:getEndCost().oil

					if arg_40_1 > 0 then
						local var_40_1 = arg_40_0:getStartCost().oil

						cost = math.clamp(arg_40_1 - var_40_1, 0, var_40_0)
					end

					var_35_101 = var_35_101 + var_40_0
				end
			end

			if system == SYSTEM_ACT_BOSS_SP then
				local var_35_104 = getProxy(ActivityProxy):GetActivityBossRuntime(self.contextData.actId).buffIds
				local var_35_105 = _.map(var_35_104, function(arg_41_0)
					return ActivityBossBuff.New({
						configId = arg_41_0
					})
				end)

				battleData.ExtraBuffList = _.map(_.select(var_35_105, function(arg_42_0)
					return arg_42_0:CastOnEnemy()
				end), function(arg_43_0)
					return arg_43_0:GetBuffID()
				end)
				battleData.ChapterBuffIDs = _.map(_.select(var_35_105, function(arg_44_0)
					return not arg_44_0:CastOnEnemy()
				end), function(arg_45_0)
					return arg_45_0:GetBuffID()
				end)
			else
				var_35_103(var_35_85, var_35_100 and var_35_99[1] or 0)
				var_35_103(var_35_93, var_35_100 and var_35_99[2] or 0)
			end

			if var_35_93:isLegalToFight() == true and (system == SYSTEM_BOSS_EXPERIMENT or var_35_101 <= var_35_96.oil) then
				battleData.SubFlag = 1
				battleData.TotalSubAmmo = 1
			end

			battleData.SubCommanderList = var_35_93:buildBattleBuffList()

			self.viewComponent:setFleet(var_35_87, var_35_88, var_35_89)
		end
	elseif system == SYSTEM_GUILD then
		local var_35_106 = getProxy(GuildProxy):getRawData():GetActiveEvent():GetBossMission()
		local var_35_107 = var_35_106:GetMainFleet()
		local var_35_108 = _.values(var_35_107:getCommanders())

		battleData.CommanderList = var_35_107:BuildBattleBuffList()
		self.mainShips = {}

		local var_35_109 = {}
		local var_35_110 = {}
		local var_35_111 = {}

		local function var_35_112(arg_46_0, arg_46_1, arg_46_2, arg_46_3)
			local var_46_0 = genSingleShipData(system, arg_46_0, arg_46_1)

			table.insert(self.mainShips, arg_46_0)
			table.insert(arg_46_3, arg_46_0)
			table.insert(arg_46_2, var_46_0)
		end

		local var_35_113 = {}
		local var_35_114 = {}
		local var_35_115 = var_35_107:GetShips()

		for iter_35_38, iter_35_39 in pairs(var_35_115) do
			local var_35_116 = iter_35_39.ship

			if var_35_116:getTeamType() == TeamType.Main then
				table.insert(var_35_113, var_35_116)
			elseif var_35_116:getTeamType() == TeamType.Vanguard then
				table.insert(var_35_114, var_35_116)
			end
		end

		for iter_35_40, iter_35_41 in ipairs(var_35_113) do
			var_35_112(iter_35_41, var_35_108, battleData.MainUnitList, var_35_109)
		end

		for iter_35_42, iter_35_43 in ipairs(var_35_114) do
			var_35_112(iter_35_43, var_35_108, battleData.VanguardUnitList, var_35_110)
		end

		local var_35_117 = var_35_106:GetSubFleet()
		local var_35_118 = _.values(var_35_117:getCommanders())
		local var_35_119 = {}
		local var_35_120 = var_35_117:GetShips()

		for iter_35_44, iter_35_45 in pairs(var_35_120) do
			local var_35_121 = iter_35_45.ship

			if var_35_121:getTeamType() == TeamType.Submarine then
				table.insert(var_35_119, var_35_121)
			end
		end

		for iter_35_46, iter_35_47 in ipairs(var_35_119) do
			var_35_112(iter_35_47, var_35_118, battleData.SubUnitList, var_35_111)
		end

		if #var_35_111 > 0 then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
		end

		battleData.SubCommanderList = var_35_117:BuildBattleBuffList()

		self.viewComponent:setFleet(var_35_109, var_35_110, var_35_111)
	elseif system == SYSTEM_BOSS_RUSH or system == SYSTEM_BOSS_RUSH_EX or system == SYSTEM_BOSS_RUSH_COLLABRATE then
		local var_35_122 = getProxy(ActivityProxy):getActivityById(self.contextData.actId):GetSeriesData()

		assert(var_35_122)

		local var_35_123 = var_35_122:GetStaegLevel() + 1
		local var_35_124 = var_35_122:GetFleetIds()
		local var_35_125 = var_35_124[var_35_123]
		local var_35_126 = var_35_124[#var_35_124]

		if var_35_122:GetMode() == BossRushSeriesData.MODE.SINGLE then
			var_35_125 = var_35_124[1]
		end

		local var_35_127 = getProxy(FleetProxy):getActivityFleets()[self.contextData.actId]

		self.mainShips = {}

		local var_35_128 = {}
		local var_35_129 = {}
		local var_35_130 = {}

		local function var_35_131(arg_47_0, arg_47_1, arg_47_2, arg_47_3)
			if table.contains(var_35_8, arg_47_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = arg_47_0

			local var_47_0 = bayProxy:getShipById(arg_47_0)
			local var_47_1 = genSingleShipData(system, var_47_0, arg_47_1)

			table.insert(self.mainShips, var_47_0)
			table.insert(arg_47_3, var_47_0)
			table.insert(arg_47_2, var_47_1)
		end

		local var_35_132 = var_35_127[var_35_125]
		local var_35_133 = _.values(var_35_132:getCommanders())

		battleData.CommanderList = var_35_132:buildBattleBuffList()

		local var_35_134 = var_35_132:getTeamByName(TeamType.Main)
		local var_35_135 = var_35_132:getTeamByName(TeamType.Vanguard)

		for iter_35_48, iter_35_49 in ipairs(var_35_134) do
			var_35_131(iter_35_49, var_35_133, battleData.MainUnitList, var_35_128)
		end

		for iter_35_50, iter_35_51 in ipairs(var_35_135) do
			var_35_131(iter_35_51, var_35_133, battleData.VanguardUnitList, var_35_129)
		end

		local var_35_136 = var_35_127[var_35_126]
		local var_35_137 = _.values(var_35_136:getCommanders())

		battleData.SubCommanderList = var_35_136:buildBattleBuffList()

		local var_35_138 = var_35_136:getTeamByName(TeamType.Submarine)

		for iter_35_52, iter_35_53 in ipairs(var_35_138) do
			var_35_131(iter_35_53, var_35_137, battleData.SubUnitList, var_35_130)
		end

		local var_35_139 = getProxy(PlayerProxy):getRawData()
		local var_35_140 = 0
		local var_35_141 = var_35_122:GetOilLimit()
		local var_35_142 = battleCostTmp.oil_cost > 0

		local function var_35_143(arg_48_0, arg_48_1)
			local var_48_0 = 0

			if var_35_142 then
				local var_48_1 = arg_48_0:getStartCost().oil
				local var_48_2 = arg_48_0:getEndCost().oil

				var_48_0 = var_48_2

				if arg_48_1 > 0 then
					var_48_0 = math.clamp(arg_48_1 - var_48_1, 0, var_48_2)
				end
			end

			return var_48_0
		end

		local var_35_144 = var_35_140 + var_35_143(var_35_132, var_35_141[1]) + var_35_143(var_35_136, var_35_141[2])

		if var_35_136:isLegalToFight() == true and var_35_144 <= var_35_139.oil then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
		end

		self.viewComponent:setFleet(var_35_128, var_35_129, var_35_130)

		if system == SYSTEM_BOSS_RUSH_COLLABRATE then
			battleData.ChapterBuffIDs = {}

			local var_35_145 = getProxy(ActivityProxy):getActivityByType(ActivityConst.ACTIVITY_TYPE_BUILDING_BUFF)
			local var_35_146 = var_35_145:GetBuildingIds()

			for iter_35_54, iter_35_55 in ipairs(var_35_146) do
				local var_35_147 = var_35_145:GetBuildingLevel(iter_35_55)
				local var_35_148 = var_35_145:GetBuildingConfigTable(iter_35_55).buff[var_35_147]

				if var_35_148 ~= 0 then
					local var_35_149 = ActivityBuff.New(var_35_145.id, var_35_148)

					if var_35_149:isActivate() and var_35_149:getConfig("benefit_type") == ys.Battle.BattleConst.BATTLE_GLOBAL_BUFF then
						local var_35_150 = var_35_149:getConfig("benefit_effect")

						table.insert(battleData.ChapterBuffIDs, var_35_150)
					end
				end
			end

			battleData.DALAidBuffIDs = {}

			local var_35_151 = var_35_122:getConfig("aid_buff")

			if var_35_122:GetBossHpRate() <= var_35_151[1] then
				table.insert(battleData.DALAidBuffIDs, var_35_151[2])
			end
		end
	elseif system == SYSTEM_LIMIT_CHALLENGE then
		local var_35_152 = LimitChallengeConst.GetChallengeIDByStageID(self.contextData.stageId)

		battleData.ExtraBuffList = AcessWithinNull(pg.expedition_constellation_challenge_template[var_35_152], "buff_id")

		local var_35_153 = FleetProxy.CHALLENGE_FLEET_ID
		local var_35_154 = FleetProxy.CHALLENGE_SUB_FLEET_ID
		local var_35_155 = getProxy(FleetProxy)
		local var_35_156 = var_35_155:getFleetById(var_35_153)
		local var_35_157 = var_35_155:getFleetById(var_35_154)

		self.mainShips = {}

		local var_35_158 = {}
		local var_35_159 = {}
		local var_35_160 = {}

		local function var_35_161(arg_49_0, arg_49_1, arg_49_2, arg_49_3)
			if table.contains(var_35_8, arg_49_0) then
				BattleVertify.cloneShipVertiry = true
			end

			var_35_8[#var_35_8 + 1] = arg_49_0

			local var_49_0 = bayProxy:getShipById(arg_49_0)
			local var_49_1 = genSingleShipData(system, var_49_0, arg_49_1)

			table.insert(self.mainShips, var_49_0)
			table.insert(arg_49_3, var_49_0)
			table.insert(arg_49_2, var_49_1)
		end

		local var_35_162 = _.values(var_35_156:getCommanders())

		battleData.CommanderList = var_35_156:buildBattleBuffList()

		local var_35_163 = var_35_156:getTeamByName(TeamType.Main)
		local var_35_164 = var_35_156:getTeamByName(TeamType.Vanguard)

		for iter_35_56, iter_35_57 in ipairs(var_35_163) do
			var_35_161(iter_35_57, var_35_162, battleData.MainUnitList, var_35_158)
		end

		for iter_35_58, iter_35_59 in ipairs(var_35_164) do
			var_35_161(iter_35_59, var_35_162, battleData.VanguardUnitList, var_35_159)
		end

		local var_35_165 = _.values(var_35_157:getCommanders())

		battleData.SubCommanderList = var_35_157:buildBattleBuffList()

		local var_35_166 = var_35_157:getTeamByName(TeamType.Submarine)

		for iter_35_60, iter_35_61 in ipairs(var_35_166) do
			var_35_161(iter_35_61, var_35_165, battleData.SubUnitList, var_35_160)
		end

		local var_35_167 = getProxy(PlayerProxy):getRawData()
		local var_35_168 = 0
		local var_35_169 = battleCostTmp.oil_cost > 0

		local function var_35_170(arg_50_0, arg_50_1)
			local var_50_0 = 0

			if var_35_169 then
				local var_50_1 = arg_50_0:getStartCost().oil
				local var_50_2 = arg_50_0:getEndCost().oil

				var_50_0 = var_50_2

				if arg_50_1 > 0 then
					var_50_0 = math.clamp(arg_50_1 - var_50_1, 0, var_50_2)
				end
			end

			return var_50_0
		end

		local var_35_171 = var_35_168 + var_35_170(var_35_156, 0) + var_35_170(var_35_157, 0)

		if var_35_157:isLegalToFight() == true and var_35_171 <= var_35_167.oil then
			battleData.SubFlag = 1
			battleData.TotalSubAmmo = 1
		end

		self.viewComponent:setFleet(var_35_158, var_35_159, var_35_160)
	elseif system == SYSTEM_CARDPUZZLE then
		local var_35_172 = {}
		local var_35_173 = {}
		local var_35_174 = self.contextData.relics

		for iter_35_62, iter_35_63 in ipairs(self.contextData.cardPuzzleFleet) do
			local var_35_175 = var_0_2(iter_35_63, var_35_174)
			local var_35_176 = var_35_175.fleetIndex

			if var_35_176 == 1 then
				table.insert(var_35_173, var_35_175)
				table.insert(battleData.VanguardUnitList, var_35_175)
			elseif var_35_176 == 2 then
				table.insert(var_35_172, var_35_175)
				table.insert(battleData.MainUnitList, var_35_175)
			end
		end

		battleData.CardPuzzleCardIDList = self.contextData.cards
		battleData.CardPuzzleCommonHPValue = self.contextData.hp
		battleData.CardPuzzleRelicList = var_35_174
		battleData.CardPuzzleCombatID = self.contextData.puzzleCombatID
	elseif system == SYSTEM_BOSS_SINGLE or system == SYSTEM_BOSS_SINGLE_VARIABLE then
		if self.contextData.mainFleetId then
			local var_35_177 = getProxy(FleetProxy):getActivityFleets()[self.contextData.actId]
			local var_35_178 = var_35_177[self.contextData.mainFleetId]
			local var_35_179 = _.values(var_35_178:getCommanders())

			battleData.CommanderList = var_35_178:buildBattleBuffList()
			self.mainShips = {}

			local var_35_180 = {}
			local var_35_181 = {}
			local var_35_182 = {}

			local function var_35_183(arg_51_0, arg_51_1, arg_51_2, arg_51_3)
				if table.contains(var_35_8, arg_51_0) then
					BattleVertify.cloneShipVertiry = true
				end

				var_35_8[#var_35_8 + 1] = arg_51_0

				local var_51_0 = bayProxy:getShipById(arg_51_0)
				local var_51_1 = genSingleShipData(system, var_51_0, arg_51_1)

				table.insert(self.mainShips, var_51_0)
				table.insert(arg_51_3, var_51_0)
				table.insert(arg_51_2, var_51_1)
			end

			local var_35_184 = var_35_178:getTeamByName(TeamType.Main)
			local var_35_185 = var_35_178:getTeamByName(TeamType.Vanguard)

			for iter_35_64, iter_35_65 in ipairs(var_35_184) do
				var_35_183(iter_35_65, var_35_179, battleData.MainUnitList, var_35_180)
			end

			for iter_35_66, iter_35_67 in ipairs(var_35_185) do
				var_35_183(iter_35_67, var_35_179, battleData.VanguardUnitList, var_35_181)
			end

			local var_35_186 = system == SYSTEM_BOSS_SINGLE_VARIABLE and 100 or 10
			local var_35_187 = var_35_177[self.contextData.mainFleetId + var_35_186]

			if var_35_187 then
				local var_35_188 = _.values(var_35_187:getCommanders())
				local var_35_189 = var_35_187:getTeamByName(TeamType.Submarine)

				for iter_35_68, iter_35_69 in ipairs(var_35_189) do
					var_35_183(iter_35_69, var_35_188, battleData.SubUnitList, var_35_182)
				end
			end

			local var_35_190 = getProxy(PlayerProxy):getRawData()
			local var_35_191 = getProxy(ActivityProxy):getActivityById(self.contextData.actId)

			battleData.ChapterBuffIDs = var_35_191:GetBuffIdsByStageId(self.contextData.stageId)

			local var_35_192 = pg.strategy_data_template

			if self.contextData.variableBuffList then
				for iter_35_70, iter_35_71 in ipairs(self.contextData.variableBuffList) do
					table.insert(battleData.ChapterBuffIDs, var_35_192[iter_35_71].buff_id)
				end
			end

			local var_35_193 = var_35_191:GetEnemyDataByStageId(self.contextData.stageId):GetOilLimit()
			local var_35_194 = 0
			local var_35_195 = battleCostTmp.oil_cost > 0

			local function var_35_196(arg_52_0, arg_52_1)
				if var_35_195 then
					local var_52_0 = arg_52_0:getEndCost().oil

					if arg_52_1 > 0 then
						local var_52_1 = arg_52_0:getStartCost().oil

						cost = math.clamp(arg_52_1 - var_52_1, 0, var_52_0)
					end

					var_35_194 = var_35_194 + var_52_0
				end
			end

			var_35_196(var_35_178, var_35_193[1] or 0)

			if var_35_187 then
				var_35_196(var_35_187, var_35_193[2] or 0)

				if var_35_187:isLegalToFight() == true and var_35_194 <= var_35_190.oil then
					battleData.SubFlag = 1
					battleData.TotalSubAmmo = 1
				end

				battleData.SubCommanderList = var_35_187:buildBattleBuffList()
			end

			self.viewComponent:setFleet(var_35_180, var_35_181, var_35_182)
		end
	elseif self.contextData.mainFleetId then
		local var_35_197 = system == SYSTEM_DUEL
		local var_35_198 = getProxy(FleetProxy)
		local var_35_199
		local var_35_200
		local var_35_201 = var_35_198:getFleetById(self.contextData.mainFleetId)

		self.mainShips = bayProxy:getShipsByFleet(var_35_201)

		local var_35_202 = {}
		local var_35_203 = {}
		local var_35_204 = {}

		local function var_35_205(arg_53_0, arg_53_1, arg_53_2)
			for iter_53_0, iter_53_1 in ipairs(arg_53_0) do
				if table.contains(var_35_8, iter_53_1) then
					BattleVertify.cloneShipVertiry = true
				end

				var_35_8[#var_35_8 + 1] = iter_53_1

				local var_53_0 = bayProxy:getShipById(iter_53_1)
				local var_53_1 = genSingleShipData(system, var_53_0, nil, var_35_197)

				table.insert(arg_53_1, var_53_0)
				table.insert(arg_53_2, var_53_1)
			end
		end

		local var_35_206 = var_35_201:getTeamByName(TeamType.Main)
		local var_35_207 = var_35_201:getTeamByName(TeamType.Vanguard)
		local var_35_208 = var_35_201:getTeamByName(TeamType.Submarine)

		var_35_205(var_35_206, var_35_202, battleData.MainUnitList)
		var_35_205(var_35_207, var_35_203, battleData.VanguardUnitList)
		var_35_205(var_35_208, var_35_204, battleData.SubUnitList)
		self.viewComponent:setFleet(var_35_202, var_35_203, var_35_204)

		if BATTLE_DEBUG and BATTLE_FREE_SUBMARINE then
			local var_35_209 = var_35_198:getFleetById(11)
			local var_35_210 = var_35_209:getTeamByName(TeamType.Submarine)

			if #var_35_210 > 0 then
				battleData.SubFlag = 1
				battleData.TotalSubAmmo = 1

				local var_35_211 = _.values(var_35_209:getCommanders())

				battleData.SubCommanderList = var_35_209:buildBattleBuffList()

				for iter_35_72, iter_35_73 in ipairs(var_35_210) do
					local var_35_212 = bayProxy:getShipById(iter_35_73)
					local var_35_213 = genSingleShipData(system, var_35_212, var_35_211, var_35_197)

					table.insert(var_35_204, var_35_212)
					table.insert(battleData.SubUnitList, var_35_213)
				end
			end
		end
	end

	if system == SYSTEM_WORLD then
		local var_35_214 = nowWorld()
		local var_35_215 = var_35_214:GetActiveMap()
		local var_35_216 = var_35_215:GetFleet()
		local var_35_217 = var_35_215:GetCell(var_35_216.row, var_35_216.column):GetStageEnemy()
		local var_35_218 = pg.world_expedition_data[self.contextData.stageId]
		local var_35_219 = var_35_214:GetWorldMapDifficultyBuffLevel()

		battleData.EnemyMapRewards = {
			var_35_219[1] * (1 + var_35_218.expedition_sairenvalueA / 10000),
			var_35_219[2] * (1 + var_35_218.expedition_sairenvalueB / 10000),
			var_35_219[3] * (1 + var_35_218.expedition_sairenvalueC / 10000)
		}
		battleData.FleetMapRewards = var_35_214:GetWorldMapBuffLevel()
	end

	battleData.RivalMainUnitList, battleData.RivalVanguardUnitList = {}, {}

	local var_35_220

	if system == SYSTEM_DUEL and self.contextData.rivalId then
		local var_35_221 = getProxy(MilitaryExerciseProxy)

		var_35_220 = var_35_221:getRivalById(self.contextData.rivalId)
		self.oldRank = var_35_221:getSeasonInfo()
	end

	if var_35_220 then
		battleData.RivalVO = var_35_220

		local var_35_222 = 0

		for iter_35_74, iter_35_75 in ipairs(var_35_220.mainShips) do
			var_35_222 = var_35_222 + iter_35_75.level
		end

		for iter_35_76, iter_35_77 in ipairs(var_35_220.vanguardShips) do
			var_35_222 = var_35_222 + iter_35_77.level
		end

		BattleVertify = BattleVertify or {}
		BattleVertify.rivalLevel = var_35_222

		for iter_35_78, iter_35_79 in ipairs(var_35_220.mainShips) do
			if not iter_35_79.hpRant or iter_35_79.hpRant > 0 then
				local var_35_223 = genSingleShipData(system, iter_35_79, nil, true)

				if iter_35_79.hpRant then
					var_35_223.initHPRate = iter_35_79.hpRant * 0.0001
				end

				table.insert(battleData.RivalMainUnitList, var_35_223)
			end
		end

		for iter_35_80, iter_35_81 in ipairs(var_35_220.vanguardShips) do
			if not iter_35_81.hpRant or iter_35_81.hpRant > 0 then
				local var_35_224 = genSingleShipData(system, iter_35_81, nil, true)

				if iter_35_81.hpRant then
					var_35_224.initHPRate = iter_35_81.hpRant * 0.0001
				end

				table.insert(battleData.RivalVanguardUnitList, var_35_224)
			end
		end
	end

	local var_35_225 = self.contextData.prefabFleet.main_unitList
	local var_35_226 = self.contextData.prefabFleet.vanguard_unitList
	local var_35_227 = self.contextData.prefabFleet.submarine_unitList

	if var_35_225 then
		for iter_35_82, iter_35_83 in ipairs(var_35_225) do
			local var_35_228 = {}

			for iter_35_84, iter_35_85 in ipairs(iter_35_83.equipment) do
				var_35_228[#var_35_228 + 1] = {
					skin = 0,
					id = iter_35_85
				}
			end

			local var_35_229 = {
				id = iter_35_83.id,
				tmpID = iter_35_83.configId,
				skinId = iter_35_83.skinId,
				level = iter_35_83.level,
				equipment = var_35_228,
				properties = iter_35_83.properties,
				baseProperties = iter_35_83.properties,
				proficiency = {
					1,
					1,
					1
				},
				skills = iter_35_83.skills
			}

			table.insert(battleData.MainUnitList, var_35_229)
		end
	end

	if var_35_226 then
		for iter_35_86, iter_35_87 in ipairs(var_35_226) do
			local var_35_230 = {}

			for iter_35_88, iter_35_89 in ipairs(iter_35_87.equipment) do
				var_35_230[#var_35_230 + 1] = {
					skin = 0,
					id = iter_35_89
				}
			end

			local var_35_231 = {
				id = iter_35_87.id,
				tmpID = iter_35_87.configId,
				skinId = iter_35_87.skinId,
				level = iter_35_87.level,
				equipment = var_35_230,
				properties = iter_35_87.properties,
				baseProperties = iter_35_87.properties,
				proficiency = {
					1,
					1,
					1
				},
				skills = iter_35_87.skills
			}

			table.insert(battleData.VanguardUnitList, var_35_231)
		end
	end

	if var_35_227 then
		for iter_35_90, iter_35_91 in ipairs(var_35_227) do
			local var_35_232 = {}

			for iter_35_92, iter_35_93 in ipairs(iter_35_91.equipment) do
				var_35_232[#var_35_232 + 1] = {
					skin = 0,
					id = iter_35_93
				}
			end

			local var_35_233 = {
				id = iter_35_91.id,
				tmpID = iter_35_91.configId,
				skinId = iter_35_91.skinId,
				level = iter_35_91.level,
				equipment = var_35_232,
				properties = iter_35_91.properties,
				baseProperties = iter_35_91.properties,
				proficiency = {
					1,
					1,
					1
				},
				skills = iter_35_91.skills
			}

			table.insert(battleData.SubUnitList, var_35_233)

			if system == SYSTEM_SIMULATION and #battleData.SubUnitList > 0 then
				battleData.SubFlag = 1
				battleData.TotalSubAmmo = 1
			end
		end
	end
end

function BattleMediator.listNotificationInterests(arg_54_0)
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

function BattleMediator.handleNotification(self, arg_55_1)
	local var_55_0 = arg_55_1:getName()
	local var_55_1 = arg_55_1:getBody()
	local var_55_2 = ys.Battle.BattleState.GetInstance()
	local var_55_3 = self.contextData.system

	if var_55_0 == GAME.FINISH_STAGE_DONE then
		pg.MsgboxMgr.GetInstance():hide()

		local var_55_4 = var_55_1.system

		if var_55_4 == SYSTEM_PROLOGUE then
			ys.Battle.BattleState.GetInstance():Deactive()
			self:sendNotification(GAME.CHANGE_SCENE, SCENE.CREATE_PLAYER)
		elseif var_55_4 == SYSTEM_PERFORM or var_55_4 == SYSTEM_SIMULATION then
			ys.Battle.BattleState.GetInstance():Deactive()
			self.viewComponent:exitBattle()

			if var_55_1.exitCallback then
				var_55_1.exitCallback()
			end
		else
			local var_55_5 = BattleResultMediator.GetResultView(var_55_4)
			local var_55_6 = {}

			if var_55_4 == SYSTEM_SCENARIO then
				var_55_6 = getProxy(ChapterProxy):getActiveChapter().operationBuffList
			end

			self:addSubLayers(Context.New({
				mediator = NewBattleResultMediator,
				viewComponent = NewBattleResultScene,
				data = {
					system = var_55_4,
					rivalId = self.contextData.rivalId,
					mainFleetId = self.contextData.mainFleetId,
					stageId = self.contextData.stageId,
					oldMainShips = self.mainShips or {},
					oldPlayer = self.player,
					oldRank = self.oldRank,
					statistics = var_55_1.statistics,
					score = var_55_1.score,
					drops = var_55_1.drops,
					bossId = var_55_1.bossId,
					name = var_55_1.name,
					prefabFleet = var_55_1.prefabFleet,
					commanderExps = var_55_1.commanderExps,
					actId = self.contextData.actId,
					result = var_55_1.result,
					extraDrops = var_55_1.extraDrops,
					extraBuffList = var_55_6,
					isLastBonus = var_55_1.isLastBonus,
					continuousBattleTimes = self.contextData.continuousBattleTimes,
					totalBattleTimes = self.contextData.totalBattleTimes,
					mode = self.contextData.mode,
					cmdArgs = self.contextData.cmdArgs,
					variableBuffList = self.contextData.variableBuffList,
					useVariableTicket = self.contextData.useVariableTicket
				}
			}))
		end
	elseif var_55_0 == GAME.STORY_BEGIN then
		var_55_2:Pause()
	elseif var_55_0 == GAME.STORY_END then
		var_55_2:Resume()
	elseif var_55_0 == GAME.START_GUIDE then
		var_55_2:Pause()
	elseif var_55_0 == GAME.END_GUIDE then
		var_55_2:Resume()
	elseif var_55_0 == GAME.PAUSE_BATTLE then
		if not var_55_2:IsPause() then
			self:onPauseBtn()
		end
	elseif var_55_0 == GAME.RESUME_BATTLE then
		var_55_2:Resume()
	elseif var_55_0 == GAME.FINISH_STAGE_ERROR then
		gcAll(true)

		local var_55_7 = getProxy(ContextProxy)
		local var_55_8 = var_55_7:getContextByMediator(DailyLevelMediator)
		local var_55_9 = var_55_7:getContextByMediator(LevelMediator2)
		local var_55_10 = var_55_7:getContextByMediator(ChallengeMainMediator)
		local var_55_11 = var_55_7:getContextByMediator(ActivityBossMediatorTemplate)

		if var_55_8 then
			local var_55_12 = var_55_8:getContextByMediator(PreCombatMediator)

			var_55_8:removeChild(var_55_12)
		elseif var_55_10 then
			local var_55_13 = var_55_10:getContextByMediator(ChallengePreCombatMediator)

			var_55_10:removeChild(var_55_13)
		elseif var_55_9 then
			if var_55_3 == SYSTEM_DUEL then
				-- block empty
			elseif var_55_3 == SYSTEM_SCENARIO then
				local var_55_14 = var_55_9:getContextByMediator(ChapterPreCombatMediator)

				var_55_9:removeChild(var_55_14)
			elseif var_55_3 ~= SYSTEM_PERFORM and var_55_3 ~= SYSTEM_SIMULATION then
				local var_55_15 = var_55_9:getContextByMediator(PreCombatMediator)

				if var_55_15 then
					var_55_9:removeChild(var_55_15)
				end
			end
		elseif var_55_11 then
			local var_55_16 = var_55_11:getContextByMediator(PreCombatMediator)

			if var_55_16 then
				var_55_11:removeChild(var_55_16)
			end
		end

		self:sendNotification(GAME.GO_BACK)
	elseif var_55_0 == BattleMediator.CLOSE_CHAT then
		self.viewComponent:OnCloseChat()
	elseif var_55_0 == BattleMediator.HIDE_ALL_BUTTONS then
		ys.Battle.BattleState.GetInstance():GetProxyByName(ys.Battle.BattleDataProxy.__name):DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.HIDE_INTERACTABLE_BUTTONS, {
			isActive = var_55_1
		}))
	elseif var_55_0 == GAME.QUIT_BATTLE then
		var_55_2:Stop()
	elseif var_55_0 == BattleMediator.UPDATE_AUTO_COUNT then
		self:updateAutoCount(var_55_1)
	end
end

function BattleMediator.remove(arg_56_0)
	pg.BrightnessMgr.GetInstance():SetScreenNeverSleep(false)
end

return BattleMediator
