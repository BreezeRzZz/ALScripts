ys = ys or {}

local ys = ys

ys.Battle.BattleSwitchBGMWave = class("BattleSwitchBGMWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleSwitchBGMWave.__name = "BattleSwitchBGMWave"

local BattleSwitchBGMWave = ys.Battle.BattleSwitchBGMWave

--- 波次类型：BGM 切换波
--- 切换当前战斗场景的背景音乐。不阻塞战斗，执行后立即通过。
function BattleSwitchBGMWave.Ctor(self)
	BattleSwitchBGMWave.super.Ctor(self)
end

--- 设置波次数据，从 triggerParams.bgm 读取 BGM 名称
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleSwitchBGMWave.SetWaveData(self, waveData)
	BattleSwitchBGMWave.super.SetWaveData(self, waveData)

	self._bgmName = self._param.bgm
end

--- 执行波次：向 BgmMgr 压入新 BGM -> doPass
function BattleSwitchBGMWave.DoWave(self)
	BattleSwitchBGMWave.super.DoWave(self)
	pg.BgmMgr.GetInstance():Push(BattleScene.__cname, self._bgmName)
	self:doPass()
end
