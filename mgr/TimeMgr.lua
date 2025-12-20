pg = pg or {}
-- TODO
local pg = pg

pg.TimeMgr = singletonClass("TimeMgr")

local TimeMgr = pg.TimeMgr

TimeMgr._Timer = nil
TimeMgr._BattleTimer = nil
TimeMgr._sAnchorTime = 0
TimeMgr._AnchorDelta = 0
TimeMgr._serverUnitydelta = 0
TimeMgr._isdstClient = false

local secondsPerHour = 3600
local secondsPerDay = 86400
local secondsPerWeek = 604800

function TimeMgr.Ctor(arg_1_0)
	arg_1_0._battleTimerList = {}
end

function TimeMgr.Init(arg_2_0)
	print("initializing time manager...")

	arg_2_0._Timer = TimeUtil.NewUnityTimer()

	UpdateBeat:Add(arg_2_0.Update, arg_2_0)
	UpdateBeat:Add(arg_2_0.BattleUpdate, arg_2_0)
end

function TimeMgr.Update(arg_3_0)
	arg_3_0._Timer:Schedule()
end

function TimeMgr.BattleUpdate(arg_4_0)
	if arg_4_0._stopCombatTime > 0 then
		arg_4_0._cobTime = arg_4_0._stopCombatTime - arg_4_0._waitTime
	else
		arg_4_0._cobTime = Time.time - arg_4_0._waitTime
	end
end

function TimeMgr.AddTimer(arg_5_0, arg_5_1, arg_5_2, arg_5_3, arg_5_4)
	return arg_5_0._Timer:SetTimer(arg_5_1, arg_5_2 * 1000, arg_5_3 * 1000, arg_5_4)
end

function TimeMgr.RemoveTimer(arg_6_0, arg_6_1)
	if arg_6_1 == nil or arg_6_1 == 0 then
		return
	end

	arg_6_0._Timer:DeleteTimer(arg_6_1)
end

TimeMgr._waitTime = 0
TimeMgr._stopCombatTime = 0
TimeMgr._cobTime = 0

function TimeMgr.GetCombatTime(arg_7_0)
	return arg_7_0._cobTime
end

function TimeMgr.ResetCombatTime(arg_8_0)
	arg_8_0._waitTime = 0
	arg_8_0._cobTime = Time.time
end

function TimeMgr.GetCombatDeltaTime()
	return Time.fixedDeltaTime
end

function TimeMgr.PauseBattleTimer(arg_10_0)
	arg_10_0._stopCombatTime = Time.time

	for iter_10_0, iter_10_1 in pairs(arg_10_0._battleTimerList) do
		iter_10_0:Pause()
	end
end

function TimeMgr.ResumeBattleTimer(arg_11_0)
	arg_11_0._waitTime = arg_11_0._waitTime + Time.time - arg_11_0._stopCombatTime
	arg_11_0._stopCombatTime = 0

	for iter_11_0, iter_11_1 in pairs(arg_11_0._battleTimerList) do
		iter_11_0:Resume()
	end
end

function TimeMgr.AddBattleTimer(self, name, loop, duration, func, scale, prePause)
	loop = loop or -1
	scale = scale or false
	prePause = prePause or false

	local timer = Timer.New(func, duration, loop, scale)

	self._battleTimerList[timer] = true

	if not prePause then
		timer:Start()
	end

	if self._stopCombatTime ~= 0 then
		timer:Pause()
	end

	return timer
end

function TimeMgr.ScaleBattleTimer(arg_13_0, arg_13_1)
	Time.timeScale = arg_13_1
end

function TimeMgr.RemoveBattleTimer(arg_14_0, arg_14_1)
	if arg_14_1 then
		arg_14_0._battleTimerList[arg_14_1] = nil

		arg_14_1:Stop()
	end
end

function TimeMgr.RemoveAllBattleTimer(arg_15_0)
	for iter_15_0, iter_15_1 in pairs(arg_15_0._battleTimerList) do
		iter_15_0:Stop()
	end

	arg_15_0._battleTimerList = {}
end

function TimeMgr.RealtimeSinceStartup(arg_16_0)
	return math.floor(Time.realtimeSinceStartup)
end

function TimeMgr.SetServerTime(arg_17_0, arg_17_1, arg_17_2)
	arg_17_0:_SetServerTime_(arg_17_1, arg_17_2, arg_17_0:RealtimeSinceStartup())
end

function TimeMgr._SetServerTime_(arg_18_0, arg_18_1, arg_18_2, arg_18_3)
	if PLATFORM_CODE == PLATFORM_US then
		SERVER_DAYLIGHT_SAVEING_TIME = false
	end

	arg_18_0._isdstClient = os.date("*t").isdst
	arg_18_0._serverUnitydelta = arg_18_1 - arg_18_3
	arg_18_0._sAnchorTime = arg_18_2 - (SERVER_DAYLIGHT_SAVEING_TIME and 3600 or 0)
	arg_18_0._AnchorDelta = arg_18_2 - os.time({
		year = 2020,
		month = 11,
		hour = 0,
		min = 0,
		sec = 0,
		day = 23,
		isdst = false
	})
end

function TimeMgr.GetServerTime(arg_19_0)
	return arg_19_0:RealtimeSinceStartup() + arg_19_0._serverUnitydelta
end

function TimeMgr.GetServerTimeMs(arg_20_0)
	return math.ceil((Time.realtimeSinceStartup + arg_20_0._serverUnitydelta) * 1000)
end

function TimeMgr.GetServerWeek(arg_21_0)
	local var_21_0 = arg_21_0:GetServerTime()

	return arg_21_0:GetServerTimestampWeek(var_21_0)
end

function TimeMgr.GetServerOverWeek(arg_22_0, arg_22_1)
	local var_22_0 = arg_22_1 - (arg_22_0:GetServerTimestampWeek(arg_22_1) - 1) * 86400

	return (math.ceil((arg_22_0:GetServerTime() - var_22_0) / 604800))
end

function TimeMgr.GetServerDay(arg_23_0, arg_23_1)
	return (math.ceil((arg_23_0:GetServerTime() - arg_23_1) / 86400))
end

function TimeMgr.GetServerTimestampWeek(arg_24_0, arg_24_1)
	local var_24_0 = arg_24_1 - arg_24_0._sAnchorTime

	return math.ceil((var_24_0 % secondsPerWeek + 1) / secondsPerDay)
end

function TimeMgr.GetServerHour(arg_25_0)
	local var_25_0 = arg_25_0:GetServerTime() - arg_25_0._sAnchorTime

	return math.floor(var_25_0 % secondsPerDay / secondsPerHour)
end

function TimeMgr.Table2ServerTime(arg_26_0, arg_26_1)
	arg_26_1.isdst = arg_26_0._isdstClient

	if arg_26_0._isdstClient ~= SERVER_DAYLIGHT_SAVEING_TIME then
		if SERVER_DAYLIGHT_SAVEING_TIME then
			return arg_26_0._AnchorDelta + os.time(arg_26_1) - secondsPerHour
		else
			return arg_26_0._AnchorDelta + os.time(arg_26_1) + secondsPerHour
		end
	else
		return arg_26_0._AnchorDelta + os.time(arg_26_1)
	end
end

function TimeMgr.CTimeDescC(arg_27_0, arg_27_1, arg_27_2)
	arg_27_2 = arg_27_2 or "%Y%m%d%H%M%S"

	return os.date(arg_27_2, arg_27_1)
end

function TimeMgr.STimeDescC(arg_28_0, arg_28_1, arg_28_2, arg_28_3)
	arg_28_2 = arg_28_2 or "%Y/%m/%d %H:%M:%S"

	if arg_28_3 then
		return os.date(arg_28_2, arg_28_1 + os.time() - arg_28_0:GetServerTime())
	else
		return os.date(arg_28_2, arg_28_1)
	end
end

function TimeMgr.STimeDescS(arg_29_0, arg_29_1, arg_29_2)
	arg_29_2 = arg_29_2 or "%Y/%m/%d %H:%M:%S"

	local var_29_0 = 0

	if arg_29_0._isdstClient ~= SERVER_DAYLIGHT_SAVEING_TIME then
		var_29_0 = SERVER_DAYLIGHT_SAVEING_TIME and 3600 or -3600
	end

	return os.date(arg_29_2, arg_29_1 - arg_29_0._AnchorDelta + var_29_0)
end

function TimeMgr.CurrentSTimeDesc(arg_30_0, arg_30_1, arg_30_2)
	if arg_30_2 then
		return arg_30_0:STimeDescS(arg_30_0:GetServerTime(), arg_30_1)
	else
		return arg_30_0:STimeDescC(arg_30_0:GetServerTime(), arg_30_1)
	end
end

function TimeMgr.ChieseDescTime(arg_31_0, arg_31_1, arg_31_2)
	local var_31_0 = "%Y/%m/%d"
	local var_31_1

	if arg_31_2 then
		var_31_1 = os.date(var_31_0, arg_31_1)
	else
		var_31_1 = os.date(var_31_0, arg_31_1 + os.time() - arg_31_0:GetServerTime())
	end

	local var_31_2 = split(var_31_1, "/")

	return NumberToChinese(var_31_2[1], false) .. "年" .. NumberToChinese(var_31_2[2], true) .. "月" .. NumberToChinese(var_31_2[3], true) .. "日"
end

function TimeMgr.GetTimeToNextTime(arg_32_0, arg_32_1, arg_32_2, arg_32_3)
	arg_32_1 = arg_32_1 or arg_32_0:GetServerTime()
	arg_32_2 = arg_32_2 or secondsPerDay
	arg_32_3 = arg_32_3 or 0

	local var_32_0 = arg_32_1 - (arg_32_0._sAnchorTime + arg_32_3)

	return math.floor(var_32_0 / arg_32_2 + 1) * arg_32_2 + arg_32_0._sAnchorTime + arg_32_3
end

function TimeMgr.GetNextTime(arg_33_0, arg_33_1, arg_33_2, arg_33_3, arg_33_4)
	return arg_33_0:GetTimeToNextTime(nil, arg_33_4, arg_33_1 * secondsPerHour + arg_33_2 * 60 + arg_33_3)
end

function TimeMgr.GetNextTimeByTimeStamp(arg_34_0, arg_34_1)
	return arg_34_0:GetTimeToNextTime(arg_34_1) - secondsPerDay
end

function TimeMgr.GetNextWeekTime(arg_35_0, arg_35_1, arg_35_2, arg_35_3, arg_35_4)
	return arg_35_0:GetNextTime((arg_35_1 - 1) * 24 + arg_35_2, arg_35_3, arg_35_4, secondsPerWeek)
end

function TimeMgr.ParseTime(arg_36_0, arg_36_1)
	local var_36_0 = tonumber(arg_36_1)
	local var_36_1 = var_36_0 % 100
	local var_36_2 = var_36_0 / 100
	local var_36_3 = var_36_2 % 100
	local var_36_4 = var_36_2 / 100
	local var_36_5 = var_36_4 % 100
	local var_36_6 = var_36_4 / 100
	local var_36_7 = var_36_6 % 100
	local var_36_8 = var_36_6 / 100
	local var_36_9 = var_36_8 % 100
	local var_36_10 = var_36_8 / 100

	return arg_36_0:Table2ServerTime({
		year = var_36_10,
		month = var_36_9,
		day = var_36_7,
		hour = var_36_5,
		min = var_36_3,
		sec = var_36_1
	})
end

function TimeMgr.ParseTimeEx(arg_37_0, arg_37_1, arg_37_2)
	if arg_37_2 == nil then
		arg_37_2 = "(%d+)%-(%d+)%-(%d+)%s(%d+)%:(%d+)%:(%d+)"
	end

	local var_37_0, var_37_1, var_37_2, var_37_3, var_37_4, var_37_5 = arg_37_1:match(arg_37_2)

	return arg_37_0:Table2ServerTime({
		year = var_37_0,
		month = var_37_1,
		day = var_37_2,
		hour = var_37_3,
		min = var_37_4,
		sec = var_37_5
	})
end

function TimeMgr.parseTimeFromConfig(arg_38_0, arg_38_1)
	return arg_38_0:Table2ServerTime({
		year = arg_38_1[1][1],
		month = arg_38_1[1][2],
		day = arg_38_1[1][3],
		hour = arg_38_1[2][1],
		min = arg_38_1[2][2],
		sec = arg_38_1[2][3]
	})
end

function TimeMgr.DescDateFromConfig(arg_39_0, arg_39_1, arg_39_2)
	arg_39_2 = arg_39_2 or "%d.%02d.%02d"

	return string.format(arg_39_2, arg_39_1[1][1], arg_39_1[1][2], arg_39_1[1][3])
end

function TimeMgr.DescCDTime(arg_40_0, arg_40_1)
	local var_40_0 = math.floor(arg_40_1 / 3600)

	arg_40_1 = arg_40_1 % 3600

	local var_40_1 = math.floor(arg_40_1 / 60)

	arg_40_1 = arg_40_1 % 60

	return string.format("%02d:%02d:%02d", var_40_0, var_40_1, arg_40_1)
end

function TimeMgr.DescCDTimeForMinute(arg_41_0, arg_41_1)
	local var_41_0 = math.floor(arg_41_1 / 3600)

	arg_41_1 = arg_41_1 % 3600

	local var_41_1 = math.floor(arg_41_1 / 60)

	arg_41_1 = arg_41_1 % 60

	return string.format("%02d:%02d", var_41_1, arg_41_1)
end

function TimeMgr.parseTimeFrom(arg_42_0, arg_42_1)
	local var_42_0 = math.floor(arg_42_1 / secondsPerDay)
	local var_42_1 = math.fmod(math.floor(arg_42_1 / 3600), 24)
	local var_42_2 = math.fmod(math.floor(arg_42_1 / 60), 60)
	local var_42_3 = math.fmod(arg_42_1, 60)

	return var_42_0, var_42_1, var_42_2, var_42_3
end

function TimeMgr.DiffDay(arg_43_0, arg_43_1, arg_43_2)
	return math.floor((arg_43_2 - arg_43_0._sAnchorTime) / secondsPerDay) - math.floor((arg_43_1 - arg_43_0._sAnchorTime) / secondsPerDay)
end

function TimeMgr.IsSameDay(arg_44_0, arg_44_1, arg_44_2)
	return math.floor((arg_44_1 - arg_44_0._sAnchorTime) / secondsPerDay) == math.floor((arg_44_2 - arg_44_0._sAnchorTime) / secondsPerDay)
end

function TimeMgr.IsSameWeek(arg_45_0, arg_45_1, arg_45_2)
	return math.floor((arg_45_1 - arg_45_0._sAnchorTime) / secondsPerWeek) == math.floor((arg_45_2 - arg_45_0._sAnchorTime) / secondsPerWeek)
end

function TimeMgr.IsPassTimeByZero(arg_46_0, arg_46_1, arg_46_2)
	return arg_46_2 < math.fmod(arg_46_1 - arg_46_0._sAnchorTime, secondsPerDay)
end

function TimeMgr.GetZeroTimeStamp(arg_47_0, arg_47_1)
	return arg_47_1 - (arg_47_1 - arg_47_0._sAnchorTime) % secondsPerDay
end

function TimeMgr.CalcMonthDays(arg_48_0, arg_48_1, arg_48_2)
	local var_48_0 = 30

	if arg_48_2 == 2 then
		var_48_0 = (arg_48_1 % 4 == 0 and arg_48_1 % 100 ~= 0 or arg_48_1 % 400 == 0) and 29 or 28
	elseif _.include({
		1,
		3,
		5,
		7,
		8,
		10,
		12
	}, arg_48_2) then
		var_48_0 = 31
	end

	return var_48_0
end

function TimeMgr.inPeriod(arg_49_0, arg_49_1, arg_49_2)
	if arg_49_1 and type(arg_49_1) == "string" then
		return arg_49_1 == "always"
	end

	if not arg_49_1 or not arg_49_2 then
		return true
	end

	local function var_49_0(arg_50_0)
		return arg_50_0[1] * secondsPerHour + arg_50_0[2] * 60 + arg_50_0[3]
	end

	local var_49_1 = (arg_49_0:GetServerTime() - arg_49_0._sAnchorTime) % secondsPerDay
	local var_49_2 = var_49_0(arg_49_1)
	local var_49_3 = var_49_0(arg_49_2)

	return var_49_2 <= var_49_1 and var_49_1 <= var_49_3
end

function TimeMgr.inTime(arg_51_0, arg_51_1, arg_51_2)
	if not arg_51_1 then
		return true
	end

	if type(arg_51_1) == "string" then
		return arg_51_1 == "always"
	end

	if type(arg_51_1[1]) == "string" then
		arg_51_1 = {
			arg_51_1[2],
			arg_51_1[3]
		}
	end

	local function var_51_0(arg_52_0)
		return {
			year = arg_52_0[1][1],
			month = arg_52_0[1][2],
			day = arg_52_0[1][3],
			hour = arg_52_0[2][1],
			min = arg_52_0[2][2],
			sec = arg_52_0[2][3]
		}
	end

	local var_51_1

	if #arg_51_1 > 0 then
		var_51_1 = var_51_0(arg_51_1[1] or {
			{
				2000,
				1,
				1
			},
			{
				0,
				0,
				0
			}
		})
	end

	local var_51_2

	if #arg_51_1 > 1 then
		var_51_2 = var_51_0(arg_51_1[2] or {
			{
				2000,
				1,
				1
			},
			{
				0,
				0,
				0
			}
		})
	end

	local var_51_3

	if var_51_1 and var_51_2 then
		local var_51_4 = arg_51_2 or arg_51_0:GetServerTime()
		local var_51_5 = arg_51_0:Table2ServerTime(var_51_1)
		local var_51_6 = arg_51_0:Table2ServerTime(var_51_2)

		if var_51_4 < var_51_5 then
			return false, var_51_1
		end

		if var_51_6 < var_51_4 then
			return false, nil
		end

		var_51_3 = var_51_2
	end

	return true, var_51_3
end

function TimeMgr.passTime(arg_53_0, arg_53_1)
	if not arg_53_1 then
		return true
	end

	local var_53_0 = (function(arg_54_0)
		local var_54_0 = {}

		var_54_0.year, var_54_0.month, var_54_0.day = unpack(arg_54_0[1])
		var_54_0.hour, var_54_0.min, var_54_0.sec = unpack(arg_54_0[2])

		return var_54_0
	end)(arg_53_1 or {
		{
			2000,
			1,
			1
		},
		{
			0,
			0,
			0
		}
	})

	if var_53_0 then
		return arg_53_0:GetServerTime() > arg_53_0:Table2ServerTime(var_53_0)
	end

	return true
end
