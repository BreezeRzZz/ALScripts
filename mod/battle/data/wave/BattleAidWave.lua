ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleAidWave = class("BattleAidWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleAidWave.__name = "BattleAidWave"

local BattleAidWave = ys.Battle.BattleAidWave

--- 波次类型：友军增援波
--- 在战斗中生成友方增援单位（先锋、主力、潜艇）。
--- 支持"撤退击杀列表"：先将指定 templateID 的友方单位撤退，再生成增援。
--- 生成完成后初始化装备 CD 和统计数据，然后 doPass。
function BattleAidWave.Ctor(self)
	BattleAidWave.super.Ctor(self)
end

--- 设置波次数据，读取增援配置
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleAidWave.SetWaveData(self, waveData)
	BattleAidWave.super.SetWaveData(self, waveData)

	self._vanguardUnitList = self._param.vanguard_unitList  -- 先锋增援列表
	self._mainUnitList     = self._param.main_unitList      -- 主力增援列表
	self._subUnitList      = self._param.sub_unitList       -- 潜艇增援列表
	self._killList         = self._param.kill_list          -- 需要先撤退的 unit templateID 列表
end

--- 执行波次：
--- 1. 如果有 killList，遍历场上友方单位，匹配 templateID 后撤退
--- 2. 依次生成 vanguardUnitList、mainUnitList、subUnitList 中的增援单位
--- 3. 每个单位生成后初始化武器 CD 和统计数据
--- 4. 所有操作完成后 doPass
function BattleAidWave.DoWave(self)
	BattleAidWave.super.DoWave(self)

	local dataProxy = ys.Battle.BattleDataProxy.GetInstance()

	-- Step 1：处理撤退列表。先撤退场上指定模板的友方单位
	if self._killList ~= nil then
		local friendlyShipList = dataProxy:GetFriendlyShipList()

		for _, killTemplateID in ipairs(self._killList) do
			for _, shipUnit in pairs(friendlyShipList) do
				if shipUnit:GetTemplateID() == killTemplateID then
					shipUnit:Retreat()
				end
			end
		end
	end

	-- Step 2：生成先锋增援
	if self._vanguardUnitList ~= nil then
		for _, vanguardUnit in ipairs(self._vanguardUnitList) do
			-- 构建装备列表：{ skin = 0, id = equipmentID }
			local equipmentList = {}

			for _, equipmentID in ipairs(vanguardUnit.equipment) do
				equipmentList[#equipmentList + 1] = {
					skin = 0,
					id   = equipmentID,
				}
			end

			local unitData = Clone(vanguardUnit)

			unitData.equipment      = equipmentList
			unitData.baseProperties = vanguardUnit.properties

			-- 生成先锋单位（以友方 IFF 加入战场）
			local spawnedUnit = dataProxy:SpawnVanguard(unitData, BattleConfig.FRIENDLY_CODE)

			dataProxy.InitUnitWeaponCD(spawnedUnit)
			dataProxy:InitAidUnitStatistics(spawnedUnit)
		end
	end

	-- Step 3：生成主力增援
	if self._mainUnitList ~= nil then
		for _, mainUnit in ipairs(self._mainUnitList) do
			local equipmentList = {}

			for _, equipmentID in ipairs(mainUnit.equipment) do
				equipmentList[#equipmentList + 1] = {
					skin = 0,
					id   = equipmentID,
				}
			end

			local unitData = Clone(mainUnit)

			unitData.equipment      = equipmentList
			unitData.baseProperties = mainUnit.properties

			local spawnedUnit = dataProxy:SpawnMain(unitData, BattleConfig.FRIENDLY_CODE)

			dataProxy.InitUnitWeaponCD(spawnedUnit)
			dataProxy:InitAidUnitStatistics(spawnedUnit)
		end
	end

	-- Step 4：生成潜艇增援
	if self._subUnitList ~= nil then
		for _, subUnit in ipairs(self._subUnitList) do
			local equipmentList = {}

			for _, equipmentID in ipairs(subUnit.equipment) do
				equipmentList[#equipmentList + 1] = {
					skin = 0,
					id   = equipmentID,
				}
			end

			local unitData = Clone(subUnit)

			unitData.equipment      = equipmentList
			unitData.baseProperties = subUnit.properties

			local spawnedUnit = dataProxy:SpawnSub(unitData, BattleConfig.FRIENDLY_CODE)

			dataProxy:InitAidUnitStatistics(spawnedUnit)
		end
	end

	self:doPass()
end
