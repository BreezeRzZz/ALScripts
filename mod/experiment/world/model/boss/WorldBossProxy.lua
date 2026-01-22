local WorldBossProxy = class("WorldBossProxy", import("....BaseEntity"))
local WorldbossFleet = "WorldbossFleet"
local WorldbossFleetForArchives = "WorldbossFleet_for_archives"

WorldBossProxy.Fields = {
	summonPtDailyAcc = "number",
	ptTime = "number",
	otherBosses = "table",
	boss = "table",
	highestDamage = "number",
	isSetup = "boolean",
	guildSupport = "number",
	currentBossLV = "number",
	ranks = "table",
	summonPt = "number",
	isFetched = "boolean",
	cacheBosses = "table",
	archivesId = "number",
	fleet = "table",
	timers = "table",
	summonPtOld = "number",
	cacheLock = "number",
	tipProgress = "boolean",
	summonFree = "number",
	fleetForArchives = "table",
	autoFightFinishTime = "number",
	summonPtOldDailyAcc = "number",
	worldSupport = "number",
	friendSupport = "number",
	pt = "number",
	refreshBossesTime = "number"
}
WorldBossProxy.REFRESH_BOSSES_TIME = 300
WorldBossProxy.EventProcessBossListUpdated = "WorldBossProxy.EventProcessBossListUpdated"
WorldBossProxy.EventCacheBossListUpdated = "WorldBossProxy.EventCacheBossListUpdated"
WorldBossProxy.EventBossUpdated = "WorldBossProxy.EventBossUpdated"
WorldBossProxy.EventFleetUpdated = "WorldBossProxy.EventFleetUpdated"
WorldBossProxy.EventPtUpdated = "WorldBossProxy.EventPtUpdated"
WorldBossProxy.EventRankListUpdated = "WorldBossProxy.EventRankListUpdated"
WorldBossProxy.EventUnlockProgressUpdated = "WorldBossProxy.EventUnlockProgressUpdated"

function WorldBossProxy.Setup(arg_1_0, arg_1_1)
	arg_1_0.pt = arg_1_0:GetMaxPt() - (arg_1_1.fight_count or 0)

	if arg_1_1.self_boss then
		local var_1_0 = WorldBoss.New()
		local var_1_1 = getProxy(PlayerProxy):getData()

		var_1_0:Setup(arg_1_1.self_boss, var_1_1)

		if var_1_0:Active() then
			arg_1_0.boss = var_1_0
		end
	end

	arg_1_0.summonPt = arg_1_1.summon_pt or 0
	arg_1_0.summonPtOld = arg_1_1.summon_pt_old or 0
	arg_1_0.summonPtDailyAcc = arg_1_1.summon_pt_daily_acc or 0
	arg_1_0.summonPtOldDailyAcc = arg_1_1.summon_pt_old_daily_acc or 0
	arg_1_0.autoFightFinishTime = arg_1_1.auto_fight_finish_time or 0
	arg_1_0.summonFree = arg_1_1.summon_free or 0
	arg_1_0.archivesId = arg_1_1.default_boss_id or 0
	arg_1_0.highestDamage = arg_1_1.auto_fight_max_damage or 0
	arg_1_0.guildSupport = arg_1_1.guild_support or 0
	arg_1_0.friendSupport = arg_1_1.friend_support or 0
	arg_1_0.worldSupport = arg_1_1.world_support or 0
	arg_1_0.currentBossLV = arg_1_1.self_boss_lv or 1
	arg_1_0.cacheBosses = {}
	arg_1_0.ranks = {}
	arg_1_0.timers = {}
	arg_1_0.fleet = nil
	arg_1_0.fleetForArchives = nil

	arg_1_0:GenFleet()

	arg_1_0.refreshBossesTime = 0
	arg_1_0.isSetup = true
	arg_1_0.isFetched = false
end

function WorldBossProxy.CheckRemouldShip(arg_2_0)
	if arg_2_0.fleet and arg_2_0.fleetForArchives then
		arg_2_0:GenFleet()
	end
end

function WorldBossProxy.FriendSupported(arg_3_0)
	return arg_3_0.friendSupport > pg.TimeMgr.GetInstance():GetServerTime()
end

function WorldBossProxy.UpdateFriendSupported(arg_4_0)
	local var_4_0 = pg.gameset.joint_boss_world_time.key_value

	arg_4_0.friendSupport = pg.TimeMgr.GetInstance():GetServerTime() + var_4_0
end

function WorldBossProxy.ClearFriendSupported(arg_5_0)
	arg_5_0.friendSupport = 0
end

function WorldBossProxy.GetNextFriendSupportTime(arg_6_0)
	return arg_6_0.friendSupport
end

function WorldBossProxy.GuildSupported(arg_7_0)
	return arg_7_0.guildSupport > pg.TimeMgr.GetInstance():GetServerTime()
end

function WorldBossProxy.UpdateGuildSupported(arg_8_0)
	local var_8_0 = pg.gameset.joint_boss_world_time.key_value

	arg_8_0.guildSupport = pg.TimeMgr.GetInstance():GetServerTime() + var_8_0
end

function WorldBossProxy.ClearGuildSupported(arg_9_0)
	arg_9_0.guildSupport = 0
end

function WorldBossProxy.GetNextGuildSupportTime(arg_10_0)
	return arg_10_0.guildSupport
end

function WorldBossProxy.WorldSupported(arg_11_0)
	return arg_11_0.worldSupport > pg.TimeMgr.GetInstance():GetServerTime()
end

function WorldBossProxy.UpdateWorldSupported(arg_12_0)
	local var_12_0 = pg.gameset.joint_boss_world_time.key_value

	arg_12_0.worldSupport = pg.TimeMgr.GetInstance():GetServerTime() + var_12_0
end

function WorldBossProxy.ClearWorldSupported(arg_13_0)
	arg_13_0.worldSupport = 0
end

function WorldBossProxy.GetNextWorldSupportTime(arg_14_0)
	return arg_14_0.worldSupport
end

function WorldBossProxy.UpdateAutoBattleFinishTime(arg_15_0, arg_15_1)
	arg_15_0.autoFightFinishTime = arg_15_1
end

function WorldBossProxy.InAutoBattle(arg_16_0)
	return arg_16_0.autoFightFinishTime > 0
end

function WorldBossProxy.ClearAutoBattle(arg_17_0)
	arg_17_0.autoFightFinishTime = 0
end

function WorldBossProxy.GetAutoBattleFinishTime(arg_18_0)
	return arg_18_0.autoFightFinishTime
end

function WorldBossProxy.GetHighestDamage(arg_19_0)
	return arg_19_0.highestDamage
end

function WorldBossProxy.UpdateHighestDamage(arg_20_0, arg_20_1)
	if arg_20_1 > arg_20_0.highestDamage then
		arg_20_0.highestDamage = arg_20_1
	end
end

function WorldBossProxy.ClearHighestDamage(arg_21_0)
	arg_21_0.highestDamage = 0
end

function WorldBossProxy.AddSummonFree(arg_22_0, arg_22_1)
	arg_22_0.summonFree = arg_22_0.summonFree + arg_22_1
end

function WorldBossProxy.GetSummonPt(arg_23_0)
	return arg_23_0.summonPt
end

function WorldBossProxy.AddSummonPt(arg_24_0, arg_24_1)
	local var_24_0, var_24_1, var_24_2 = WorldBossConst.GetCurrBossConsume()

	if var_24_1 < arg_24_0.summonPtDailyAcc + arg_24_1 then
		arg_24_1 = var_24_1 - arg_24_0.summonPtDailyAcc
	end

	if arg_24_1 <= 0 then
		return
	end

	local var_24_3 = arg_24_0.summonPt

	arg_24_0.summonPt = math.min(arg_24_0.summonPt + arg_24_1, var_24_2)

	local var_24_4 = math.min(var_24_2 - var_24_3, arg_24_1)

	arg_24_0.summonPtDailyAcc = math.min(arg_24_0.summonPtDailyAcc + var_24_4, var_24_1)

	arg_24_0:UpdatedUnlockProgress(var_24_3, arg_24_0.summonPt)
end

function WorldBossProxy.ConsumeSummonPt(arg_25_0, arg_25_1)
	arg_25_0.summonPt = arg_25_0.summonPt - arg_25_1

	arg_25_0:DispatchEvent(WorldBossProxy.EventUnlockProgressUpdated)
end

function WorldBossProxy.GetSummonPtDailyAcc(arg_26_0)
	return arg_26_0.summonPtDailyAcc
end

function WorldBossProxy.ClearSummonPtDailyAcc(arg_27_0)
	arg_27_0.summonPtDailyAcc = 0

	arg_27_0:DispatchEvent(WorldBossProxy.EventUnlockProgressUpdated)
end

function WorldBossProxy.GetSummonPtOld(arg_28_0)
	return arg_28_0.summonPtOld
end

function WorldBossProxy.AddSummonPtOld(arg_29_0, arg_29_1)
	local var_29_0, var_29_1, var_29_2 = WorldBossConst.GetAchieveBossConsume()

	if var_29_1 < arg_29_0.summonPtOldDailyAcc + arg_29_1 then
		arg_29_1 = var_29_1 - arg_29_0.summonPtOldDailyAcc
	end

	if arg_29_1 <= 0 then
		return
	end

	local var_29_3 = arg_29_0.summonPtOld

	arg_29_0.summonPtOld = math.min(arg_29_0.summonPtOld + arg_29_1, var_29_2)

	local var_29_4 = math.min(var_29_2 - var_29_3, arg_29_1)

	arg_29_0.summonPtOldDailyAcc = math.min(arg_29_0.summonPtOldDailyAcc + var_29_4, var_29_1)
end

function WorldBossProxy.ConsumeSummonPtOld(arg_30_0, arg_30_1)
	arg_30_0.summonPtOld = arg_30_0.summonPtOld - arg_30_1

	arg_30_0:DispatchEvent(WorldBossProxy.EventUnlockProgressUpdated)
end

function WorldBossProxy.ClearSummonPtOldAcc(arg_31_0)
	arg_31_0.summonPtOldDailyAcc = 0

	arg_31_0:DispatchEvent(WorldBossProxy.EventUnlockProgressUpdated)
end

function WorldBossProxy.GetSummonPtOldAcc(arg_32_0)
	return arg_32_0.summonPtOldDailyAcc
end

function WorldBossProxy.GetArchivesId(arg_33_0)
	return arg_33_0.archivesId
end

function WorldBossProxy.SetArchivesId(arg_34_0, arg_34_1)
	arg_34_0.archivesId = arg_34_1
end

function WorldBossProxy.BossId2FleetKey(arg_35_0, arg_35_1)
	local var_35_0 = arg_35_0:GetBossById(arg_35_1)

	if var_35_0 and not WorldBossConst._IsCurrBoss(var_35_0) then
		return WorldbossFleetForArchives
	else
		return WorldbossFleet
	end
end

function WorldBossProxy.GenFleet(arg_36_0)
	local var_36_0 = arg_36_0:GetCacheShips(WorldbossFleet)

	arg_36_0.fleet = TypedFleet.New({
		id = 1,
		name = i18n("world_boss_fleet"),
		ship_list = var_36_0,
		fleetType = FleetType.Normal
	})

	local var_36_1 = arg_36_0:GetCacheShips(WorldbossFleetForArchives)

	arg_36_0.fleetForArchives = Fleet.New({
		id = 1,
		name = i18n("world_boss_fleet"),
		ship_list = var_36_1,
		fleetType = FleetType.Normal
	})
end

function WorldBossProxy.GetCacheShips(arg_37_0, arg_37_1)
	local function var_37_0(arg_38_0, arg_38_1)
		local var_38_0 = arg_38_0:getTeamType()

		if TeamType.GetTeamShipMax(var_38_0) < arg_38_1 + 1 then
			return true
		end

		return false
	end

	local var_37_1 = PlayerPrefs.GetString(arg_37_1 .. getProxy(PlayerProxy):getRawData().id)
	local var_37_2 = string.split(var_37_1, "|")
	local var_37_3 = {}
	local var_37_4 = {
		[TeamType.Vanguard] = 0,
		[TeamType.Main] = 0,
		[TeamType.Submarine] = 0
	}

	if var_37_2 and #var_37_2 > 0 and (#var_37_2 ~= 1 or var_37_2[1] ~= "") then
		for iter_37_0, iter_37_1 in ipairs(var_37_2) do
			local var_37_5 = tonumber(iter_37_1)
			local var_37_6 = getProxy(BayProxy):getShipById(var_37_5)

			if var_37_6 then
				local var_37_7 = var_37_6:getTeamType()

				if not var_37_0(var_37_6, var_37_4[var_37_7]) then
					var_37_4[var_37_7] = var_37_4[var_37_7] + 1

					table.insert(var_37_3, var_37_5)
				end
			end
		end
	end

	return var_37_3
end

function WorldBossProxy.GetFleet(arg_39_0, arg_39_1)
	local var_39_0 = arg_39_0:BossId2FleetKey(arg_39_1)
	local var_39_1

	if WorldbossFleetForArchives == var_39_0 then
		var_39_1 = arg_39_0.fleetForArchives
	else
		var_39_1 = arg_39_0.fleet
	end

	var_39_1 = var_39_1 or Fleet.New({
		0,
		id = 1,
		name = i18n("world_boss_fleet"),
		ship_list = {}
	})

	for iter_39_0 = #var_39_1.ships, 1, -1 do
		local var_39_2 = var_39_1.ships[iter_39_0]

		if not getProxy(BayProxy):getShipById(var_39_2) then
			var_39_1:removeShipById(var_39_2)
		end
	end

	return var_39_1
end

function WorldBossProxy.UpdateFleet(arg_40_0, arg_40_1, arg_40_2)
	local var_40_0 = arg_40_0:BossId2FleetKey(arg_40_1)

	if WorldbossFleetForArchives == var_40_0 then
		arg_40_0.fleetForArchives = arg_40_2
	else
		arg_40_0.fleet = arg_40_2
	end

	arg_40_0:DispatchEvent(WorldBossProxy.EventFleetUpdated)
end

function WorldBossProxy.SavaCacheShips(arg_41_0, arg_41_1, arg_41_2)
	local var_41_0 = arg_41_0:BossId2FleetKey(arg_41_1)
	local var_41_1 = arg_41_2:getShipIds()
	local var_41_2 = ""

	for iter_41_0, iter_41_1 in ipairs(var_41_1) do
		var_41_2 = var_41_2 .. iter_41_1 .. "|"
	end

	PlayerPrefs.SetString(var_41_0 .. getProxy(PlayerProxy):getRawData().id, var_41_2)
	PlayerPrefs.Save()
end

function WorldBossProxy.ClearCacheShips(arg_42_0, arg_42_1)
	local var_42_0 = arg_42_0:BossId2FleetKey(arg_42_1)

	PlayerPrefs.DeleteKey(var_42_0 .. getProxy(PlayerProxy):getRawData().id)
	PlayerPrefs.Save()
end

function WorldBossProxy.UpdteRefreshBossesTime(arg_43_0)
	arg_43_0.refreshBossesTime = pg.TimeMgr.GetInstance():GetServerTime() + WorldBossProxy.REFRESH_BOSSES_TIME
end

function WorldBossProxy.ShouldRefreshBosses(arg_44_0)
	return pg.TimeMgr.GetInstance():GetServerTime() >= arg_44_0.refreshBossesTime
end

function WorldBossProxy.UpdateCacheBoss(arg_45_0, arg_45_1)
	if arg_45_0:IsSelfBoss(arg_45_1) then
		arg_45_0:UpdateSelfBoss(arg_45_1)
	else
		arg_45_0.cacheBosses[arg_45_1.id] = arg_45_1

		arg_45_0:BalanceMaxBossCnt()
	end
end

function WorldBossProxy.BalanceMaxBossCnt(arg_46_0)
	local var_46_0 = pg.gameset.boss_cnt_limit.description

	if table.getCount(arg_46_0.cacheBosses) < var_46_0[1] then
		return
	end

	local var_46_1 = {}
	local var_46_2 = {}
	local var_46_3 = {}
	local var_46_4 = {}

	for iter_46_0, iter_46_1 in pairs(arg_46_0.cacheBosses) do
		local var_46_5 = iter_46_1:GetType()

		if iter_46_1:isDeath() or iter_46_1:IsExpired() then
			table.insert(var_46_4, iter_46_1)
		elseif var_46_5 == WorldBoss.BOSS_TYPE_FRIEND then
			table.insert(var_46_3, iter_46_1)
		elseif var_46_5 == WorldBoss.BOSS_TYPE_GUILD then
			table.insert(var_46_2, iter_46_1)
		elseif var_46_5 == WorldBoss.BOSS_TYPE_WORLD then
			table.insert(var_46_1, iter_46_1)
		end
	end

	if #var_46_1 > var_46_0[2] then
		table.sort(var_46_1, function(arg_47_0, arg_47_1)
			return arg_47_0:GetJoinTime() < arg_47_1:GetJoinTime()
		end)

		if var_46_1[1] then
			table.insert(var_46_4, var_46_1[1])
		end
	end

	if #var_46_2 > var_46_0[3] then
		table.sort(var_46_2, function(arg_48_0, arg_48_1)
			return arg_48_0:GetJoinTime() < arg_48_1:GetJoinTime()
		end)

		if var_46_2[1] then
			table.insert(var_46_4, var_46_2[1])
		end
	end

	if #var_46_3 > var_46_0[4] then
		table.sort(var_46_3, function(arg_49_0, arg_49_1)
			return arg_49_0:GetJoinTime() < arg_49_1:GetJoinTime()
		end)

		if var_46_3[1] then
			table.insert(var_46_4, var_46_3[1])
		end
	end

	if #var_46_4 > 0 then
		for iter_46_2, iter_46_3 in ipairs(var_46_4) do
			if arg_46_0.cacheBosses[iter_46_3.id] and iter_46_3.id ~= arg_46_0.cacheLock then
				arg_46_0.cacheBosses[iter_46_3.id] = nil
			end
		end

		arg_46_0:DispatchEvent(WorldBossProxy.EventCacheBossListUpdated)
	end
end

function WorldBossProxy.RemoveCacheBoss(arg_50_0, arg_50_1)
	if arg_50_0.cacheBosses[arg_50_1] then
		arg_50_0.cacheBosses[arg_50_1] = nil

		arg_50_0:DispatchEvent(WorldBossProxy.EventCacheBossListUpdated)
	end
end

function WorldBossProxy.GetCacheBoss(arg_51_0, arg_51_1)
	return arg_51_0.cacheBosses[arg_51_1]
end

function WorldBossProxy.LockCacheBoss(arg_52_0, arg_52_1)
	arg_52_0.cacheLock = arg_52_1
end

function WorldBossProxy.UnlockCacheBoss(arg_53_0)
	arg_53_0.cacheLock = nil
end

function WorldBossProxy.canGetSelfAward(arg_54_0)
	local var_54_0 = arg_54_0:GetSelfBoss()

	return var_54_0 and var_54_0:isDeath()
end

function WorldBossProxy.UpdateSelfBoss(arg_55_0, arg_55_1)
	if arg_55_0.boss and arg_55_1 and not arg_55_1:isSameLevel(arg_55_0.boss) then
		arg_55_0.fleet:clearFleet()
	end

	arg_55_0.boss = arg_55_1

	arg_55_0:DispatchEvent(WorldBossProxy.EventBossUpdated)
end

function WorldBossProxy.RemoveSelfBoss(arg_56_0)
	if arg_56_0.boss then
		arg_56_0:UpdateSelfBoss(nil)
	end

	arg_56_0:ClearHighestDamage()
	arg_56_0:ClearAutoBattle()
	arg_56_0:ClearFriendSupported()
	arg_56_0:ClearGuildSupported()
	arg_56_0:ClearWorldSupported()
end

function WorldBossProxy.updateBossHp(arg_57_0, arg_57_1, arg_57_2)
	if arg_57_0.boss and arg_57_1 == arg_57_0.boss.id then
		arg_57_0.boss:UpdateHp(arg_57_2)
		arg_57_0:UpdateSelfBoss(arg_57_0.boss)
	else
		local var_57_0 = arg_57_0.cacheBosses[arg_57_1]

		if var_57_0 then
			var_57_0:UpdateHp(arg_57_2)
			arg_57_0:UpdateCacheBoss(var_57_0)
		end
	end
end

function WorldBossProxy.GetBossById(arg_58_0, arg_58_1)
	if arg_58_0.boss and arg_58_0.boss.id == arg_58_1 then
		return arg_58_0.boss
	end

	local var_58_0 = arg_58_0.cacheBosses[arg_58_1]

	if var_58_0 then
		return var_58_0
	end
end

function WorldBossProxy.GetSelfBoss(arg_59_0)
	return arg_59_0.boss
end

function WorldBossProxy.IsSelfBoss(arg_60_0, arg_60_1)
	assert(arg_60_1)

	return arg_60_0.boss and arg_60_0.boss.id == arg_60_1.id or arg_60_1:IsSelf()
end

function WorldBossProxy.GetBoss(arg_61_0)
	return arg_61_0.boss
end

function WorldBossProxy.ExistSelfBoss(arg_62_0)
	return arg_62_0.boss ~= nil and not arg_62_0.boss:IsExpired()
end

function WorldBossProxy.GetCacheBossList(arg_63_0)
	local var_63_0 = {}

	for iter_63_0, iter_63_1 in pairs(arg_63_0.cacheBosses) do
		if not arg_63_0:IsSelfBoss(iter_63_1) then
			table.insert(var_63_0, iter_63_1)
		end
	end

	return var_63_0
end

function WorldBossProxy.reducePt(arg_64_0)
	arg_64_0.pt = arg_64_0.pt - 1

	arg_64_0:DispatchEvent(WorldBossProxy.EventPtUpdated)
end

function WorldBossProxy.increasePt(arg_65_0)
	local var_65_0 = arg_65_0:GetMaxPt()

	arg_65_0.pt = math.min(var_65_0, arg_65_0.pt + pg.gameset.joint_boss_ap_recove_cnt_pre_day.key_value)

	arg_65_0:DispatchEvent(WorldBossProxy.EventPtUpdated)
end

function WorldBossProxy.SetRank(arg_66_0, arg_66_1, arg_66_2)
	arg_66_0.ranks[arg_66_1] = arg_66_2

	local var_66_0 = arg_66_0:GetBossById(arg_66_1)

	if var_66_0 then
		var_66_0:SetRankCnt(#arg_66_2)
	end

	arg_66_0:addTimer(arg_66_1)
	arg_66_0:DispatchEvent(WorldBossProxy.EventRankListUpdated, arg_66_1)
end

function WorldBossProxy.GetRank(arg_67_0, arg_67_1)
	return arg_67_0.ranks[arg_67_1]
end

function WorldBossProxy.ClearRank(arg_68_0, arg_68_1)
	arg_68_0.ranks[arg_68_1] = nil
end

function WorldBossProxy.addTimer(arg_69_0, arg_69_1)
	if not arg_69_1 then
		return
	end

	if arg_69_0.timers[arg_69_1] then
		arg_69_0.timers[arg_69_1]:Stop()

		arg_69_0.timers[arg_69_1] = nil
	end

	arg_69_0.timers[arg_69_1] = Timer.New(function()
		if arg_69_0.ranks then
			arg_69_0.ranks[arg_69_1] = nil
		end

		if arg_69_0.timer and arg_69_0.timers[arg_69_1] then
			arg_69_0.timers[arg_69_1]:Stop()

			arg_69_0.timers[arg_69_1] = nil
		end
	end, 300, 1)

	arg_69_0.timers[arg_69_1]:Start()
end

function WorldBossProxy.GetPt(arg_71_0)
	return arg_71_0.pt
end

function WorldBossProxy.GetMaxPt(arg_72_0)
	return pg.gameset.joint_boss_ap_max.key_value
end

function WorldBossProxy.isMaxPt(arg_73_0)
	return arg_73_0.pt == arg_73_0:GetMaxPt()
end

function WorldBossProxy.GetRecoverPtTime(arg_74_0)
	return pg.gameset.joint_boss_ap_recover_time.key_value
end

function WorldBossProxy.GetNextReconveTime(arg_75_0)
	return arg_75_0.ptTime
end

function WorldBossProxy.updatePtTime(arg_76_0, arg_76_1)
	arg_76_0.ptTime = arg_76_1
end

function WorldBossProxy.Dispose(arg_77_0)
	WorldBossProxy.super.Dispose(arg_77_0)

	for iter_77_0, iter_77_1 in pairs(arg_77_0.timers or {}) do
		iter_77_1:Stop()
	end

	arg_77_0.timers = nil
end

function WorldBossProxy.NeedTip(arg_78_0)
	return (function()
		if arg_78_0.boss and arg_78_0.boss:isDeath() and not arg_78_0.boss:IsExpired() and not arg_78_0.boss:ShouldWaitForResult() then
			return true
		end

		return false
	end)()
end

function WorldBossProxy.UpdatedUnlockProgress(arg_80_0, arg_80_1, arg_80_2)
	if arg_80_2 <= arg_80_1 or not nowWorld():IsSystemOpen(WorldConst.SystemWorldBoss) then
		arg_80_0.tipProgress = false
	elseif not (pg.NewStoryMgr.GetInstance():IsPlayed("WorldG190") or not GUIDE_WROLD) then
		arg_80_0.tipProgress = true
	else
		local var_80_0 = getProxy(SettingsProxy):GetWorldBossProgressTipTable()

		if #var_80_0 == 0 then
			arg_80_0.tipProgress = false
		else
			arg_80_0.tipProgress = _.any(var_80_0, function(arg_81_0)
				return arg_80_1 < tonumber(arg_81_0) and arg_80_2 >= tonumber(arg_81_0)
			end)
		end
	end

	arg_80_0:DispatchEvent(WorldBossProxy.EventUnlockProgressUpdated)
end

function WorldBossProxy.ShouldTipProgress(arg_82_0)
	return arg_82_0.tipProgress
end

function WorldBossProxy.ClearTipProgress(arg_83_0)
	arg_83_0.tipProgress = false
end

function WorldBossProxy.GetCanGetAwardBoss(arg_84_0)
	return nil
end

function WorldBossProxy.ExistSelfBossAward(arg_85_0)
	if arg_85_0.boss and arg_85_0.boss:isDeath() and not arg_85_0.boss:IsExpired() then
		return true
	end

	return false
end

function WorldBossProxy.ExistCacheBoss(arg_86_0)
	return table.getCount(arg_86_0.cacheBosses) ~= 0
end

function WorldBossProxy.IsOpen(arg_87_0)
	return WorldBossConst.GetCurrBossID() ~= nil
end

-- 判断META BOSS是否需要支援(基于日期)
function WorldBossProxy.IsNeedSupport()
	local curBossDayIndex = WorldBossConst.GetCurrBossDayIndex()
	local supportDesc = pg.gameset.world_metaboss_supportattack.description
	local selfBoss = nowWorld():GetBossProxy():GetSelfBoss()

	if not selfBoss then
		return
	end

	if not WorldBossConst._IsCurrBoss(selfBoss) then
		return
	end
	-- 31天及之后才支援
	if curBossDayIndex < supportDesc[1] then
		return
	end

	return true
end

-- META BOSS 支援相关
function WorldBossProxy.GetSupportValue()
	if not WorldBossProxy.IsNeedSupport() then
		return
	end

	local supportDesc = pg.gameset.world_metaboss_supportattack.description
	local var_89_1 = 0

	assert(supportDesc[6], "Missing WorldBoss SupportAttack Buff")
	-- supportDesc[6]: 支援Buff ID
	-- 至于META 支援伤害计算公式，参考BattleFormulas.CaclulateMetaDotaDamage
	return true, var_89_1, supportDesc[6]
end

return WorldBossProxy
