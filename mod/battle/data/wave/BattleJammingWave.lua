ys = ys or {}

local ys = ys

ys.Battle.BattleJammingWave = class("BattleJammingWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleJammingWave.__name = "BattleJammingWave"

local BattleJammingWave = ys.Battle.BattleJammingWave

--- 电子干扰类型常量
BattleJammingWave.JAMMING_ENGAGE = 1  -- 干扰命中（降低命中率）
BattleJammingWave.JAMMING_DODGE = 2  -- 干扰闪避（降低闪避率）

--- 波次类型：电子干扰波
--- 对场上友方单位施加电子干扰效果（KizunaJamming）。
--- KizunaJamming 是绊爱联动活动的特殊机制，会影响命中/闪避属性。
function BattleJammingWave.Ctor(self)
	BattleJammingWave.super.Ctor(self)
end

--- 执行波次：检查关卡 KizunaJamming 配置 -> 若包含 ENGAGE 类型则施加干扰 -> doFinish
--- KizunaJamming 数据来自 BattleInitData，由关卡配置预设
function BattleJammingWave.DoWave(self)
	BattleJammingWave.super.DoWave(self)

	local dataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local kizunaJamming = dataProxy:GetInitData().KizunaJamming

	-- 如果关卡配置了 KizunaJamming 且包含 JAMMING_ENGAGE 类型，施加干扰效果
	if kizunaJamming and table.contains(kizunaJamming, BattleJammingWave.JAMMING_ENGAGE) then
		dataProxy:KizunaJamming()
	end

	self:doFinish()
end
