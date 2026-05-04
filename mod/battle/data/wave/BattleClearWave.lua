ys = ys or {}

local ys = ys

ys.Battle.BattleClearWave = class("BattleClearWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleClearWave.__name = "BattleClearWave"

local BattleClearWave = ys.Battle.BattleClearWave

--- 波次类型：清场波
--- 立即清除场上所有敌方飞机、潜艇、子弹/鱼雷，然后通过。
--- 通常用于一波敌人清完后，确保场上没有残留弹幕再进入下一波。
function BattleClearWave.Ctor(self)
	BattleClearWave.super.Ctor(self)
end

--- 执行波次：KillAllAircraft -> KillSubmarineByIFF(敌方) -> 所有子弹无害化 -> doPass
--- AllBulletNeutralize 使子弹消失但不触发伤害判定（与直接销毁不同）
function BattleClearWave.DoWave(self)
	BattleClearWave.super.DoWave(self)

	local battleState = ys.Battle.BattleState.GetInstance()
	local dataProxy = battleState:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	local sceneMediator = battleState:GetMediatorByName(ys.Battle.BattleSceneMediator.__name)

	-- 清空所有空中单位（飞机）
	dataProxy:KillAllAircraft()
	-- 清除敌方潜艇
	dataProxy:KillSubmarineByIFF(ys.Battle.BattleConfig.FOE_CODE)
	-- 场上所有子弹/鱼雷无害化（消失但不断裂伤害判定）
	sceneMediator:AllBulletNeutralize()
	self:doPass()
end
