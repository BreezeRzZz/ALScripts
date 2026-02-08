ys = ys or {}

local ys = ys
local BattleBuffDiva = class("BattleBuffDiva", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffDiva = BattleBuffDiva
BattleBuffDiva.__name = "BattleBuffDiva"

-- 这类BuffEffect会播放BGM。如果有多首，随机播放一首。
function BattleBuffDiva.Ctor(self, effectData)
	BattleBuffDiva.super.Ctor(self, effectData)
end

function BattleBuffDiva.onInitGame(self, owner, buff)
	local bgmList = ys.Battle.BattleDataProxy.GetInstance():GetBGMList()
	local randomBgm = bgmList[math.random(#bgmList)]

	pg.BgmMgr.GetInstance():Push(BattleScene.__cname, randomBgm)
end

function BattleBuffDiva.onTrigger(self)
	local bgmList = ys.Battle.BattleDataProxy.GetInstance():GetBGMList(true)
	local randomBgm = bgmList[math.random(#bgmList)]

	pg.BgmMgr.GetInstance():Push(BattleScene.__cname, randomBgm)
end
