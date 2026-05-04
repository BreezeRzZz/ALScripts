ys = ys or {}

--- @class BattleDebugCommand : ys.MVC.Command
--- 调试战斗指令。继承自 ys.MVC.Command（而非 SingleDungeonCommand），
--- 用于开发期间的战斗调试。
--- 特性：
--- - Dispose 时恢复 BattleDataProxy 的 Update 代理函数为正常版本
--- - onPlayerShutDown 中当主力/前卫全灭时自动重刷己方单位（调试无限循环用）
--- - onAddUnit 中含有一个永远为 false 的条件分支（可能是预留的调试逻辑）
--- - 使用 SYSTEM_DEBUG 作为 OpeningEffect 的关卡类型
local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleDebugCommand = class("BattleDebugCommand", ys.MVC.Command)

ys.Battle.BattleDebugCommand = BattleDebugCommand
BattleDebugCommand.__name = "BattleDebugCommand"

function BattleDebugCommand.Ctor(self)
	BattleDebugCommand.super.Ctor(self)
end

--- 初始化指令。不调用 InitProtocol（无网络协议需求）。
function BattleDebugCommand.Initialize(self)
	self:Init()
	BattleDebugCommand.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	self._uiMediator = self._state:GetMediatorByName(ys.Battle.BattleUIMediator.__name)

	self:AddEvent()
end

--- 调试模式的开场，使用 SYSTEM_DEBUG 类型。
function BattleDebugCommand.DoPrologue(self)
	(function()
		self._uiMediator:OpeningEffect(function()
			self._uiMediator:ShowAutoBtn()
			self._uiMediator:ShowTimer()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
		end, SYSTEM_DEBUG)
		self._dataProxy:InitAllFleetUnitsWeaponCD()
		self._dataProxy:TirggerBattleStartBuffs()
	end)()
end

function BattleDebugCommand.Init(self)
	self._unitDataList = {}
end

function BattleDebugCommand.Clear(self)
	for unitID, unit in pairs(self._unitDataList) do
		self:UnregisterUnitEvent(unit)

		self._unitDataList[unitID] = nil
	end
end

function BattleDebugCommand.Reinitialize(self)
	self._state:Deactive()
	self:Clear()
	self:Init()
end

--- Dispose 时恢复 BattleDataProxy 的 Update 代理函数。
--- 调试模式可能替换了 Proxy，退出时需要恢复为正常版本。
function BattleDebugCommand.Dispose(self)
	ys.Battle.BattleDataProxy.Update = ys.Battle.BattleDebugConsole.ProxyUpdateNormal
	ys.Battle.BattleDataProxy.UpdateAutoComponent = ys.Battle.BattleDebugConsole.ProxyUpdateAutoComponentNormal

	self:Clear()
	self:RemoveEvent()
	BattleDebugCommand.super.Dispose(self)
end

function BattleDebugCommand.AddEvent(self)
	self._dataProxy:RegisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH, self.onInitBattle)
	self._dataProxy:RegisterEventListener(self, BattleEvent.ADD_UNIT, self.onAddUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.REMOVE_UNIT, self.onRemoveUnit)
	self._dataProxy:RegisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER, self.onPlayerShutDown)
end

function BattleDebugCommand.RemoveEvent(self)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.STAGE_DATA_INIT_FINISH)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.ADD_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.REMOVE_UNIT)
	self._dataProxy:UnregisterEventListener(self, BattleEvent.SHUT_DOWN_PLAYER)
end

--- 战斗数据初始化完成回调。获取己方舰队引用。
function BattleDebugCommand.onInitBattle(self)
	self._userFleet = self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE)
end

--- 单位添加事件回调。
--- 包含一个永远为 false 的条件分支：
---   unitType != ENEMY and unitType != BOSS and unitType != MINION and unitType != NPC and unitType == BOSS
--- 由于 unitType 不可能同时 != BOSS 又 == BOSS，这个分支永远不执行，
--- 可能是开发者预留的调试逻辑占位。
function BattleDebugCommand.onAddUnit(self, event)
	local unitType = event.Data.type
	local unit = event.Data.unit

	self:RegisterUnitEvent(unit)

	self._unitDataList[unit:GetUniqueID()] = unit

	if unitType ~= ys.Battle.BattleConst.UnitType.ENEMY_UNIT and unitType ~= ys.Battle.BattleConst.UnitType.BOSS_UNIT and unitType ~= ys.Battle.BattleConst.UnitType.MINION_UNIT and unitType ~= ys.Battle.BattleConst.UnitType.NPC_UNIT and unitType == ys.Battle.BattleConst.UnitType.BOSS_UNIT then
		-- block empty
	end
end

--- 为单位注册事件监听。玩家单位额外监听 SHUT_DOWN_PLAYER。
function BattleDebugCommand.RegisterUnitEvent(self, unit)
	unit:RegisterEventListener(self, BattleUnitEvent.WILL_DIE, self.onWillDie)
	unit:RegisterEventListener(self, BattleUnitEvent.DYING, self.onUnitDying)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:RegisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER, self.onShutDownPlayer)
	end
end

--- 取消单位的注册事件。
function BattleDebugCommand.UnregisterUnitEvent(self, unit)
	unit:UnregisterEventListener(self, BattleUnitEvent.WILL_DIE)
	unit:UnregisterEventListener(self, BattleUnitEvent.DYING)

	if unit:GetUnitType() == ys.Battle.BattleConst.UnitType.PLAYER_UNIT then
		unit:UnregisterEventListener(self, BattleUnitEvent.SHUT_DOWN_PLAYER)
	end
end

--- 单位移除事件回调。
function BattleDebugCommand.onRemoveUnit(self, event)
	local uid = event.Data.UID
	local unit = self._unitDataList[uid]

	if unit == nil then
		return
	end

	self:UnregisterUnitEvent(unit)

	self._unitDataList[uid] = nil
end

--- 调试模式的玩家单位沉没问题。与正常模式不同：
--- 主力全灭时自动清除所有敌方弹幕和敌人，重新生成己方主力。
--- 前卫全灭时自动清除所有敌方弹幕和敌人，重新生成己方前卫。
--- 这允许开发者在调试中无限循环测试而无需重新进入战斗。
function BattleDebugCommand.onPlayerShutDown(self, event)
	-- 注意：此条件 `event.Data.unit == self._userFleet:GetMainList() == 0` 存在逻辑问题
	-- Lua 中比较是左结合的：(unit == GetMainList()) == 0，最终是 boolean == 0
	-- 这总为 true（因为 boolean 永远不等于 0），所以主力总是会被重生。
	-- 这可能是故意的调试行为：只要触发玩家沉没事件就重新生成。
	if event.Data.unit == self._userFleet:GetMainList() == 0 then
		self._dataProxy:KillAllAirStrike()
		self._dataProxy:KillAllEnemy()
		self._dataProxy:CLSBullet(ys.Battle.BattleConfig.FRIENDLY_CODE)
		self._dataProxy:CLSBullet(ys.Battle.BattleConfig.FOE_CODE)

		local mainUnitList = self._dataProxy:GetInitData().MainUnitList

		for _, unitData in ipairs(mainUnitList) do
			self._dataProxy:SpawnMain(unitData, ys.Battle.BattleConfig.FRIENDLY_CODE)
		end
	end

	-- 前卫全灭时重新生成前卫
	if #self._userFleet:GetScoutList() == 0 then
		self._dataProxy:KillAllAirStrike()
		self._dataProxy:KillAllEnemy()
		self._dataProxy:CLSBullet(ys.Battle.BattleConfig.FRIENDLY_CODE)
		self._dataProxy:CLSBullet(ys.Battle.BattleConfig.FOE_CODE)

		local vanguardUnitList = self._dataProxy:GetInitData().VanguardUnitList

		for _, unitData in ipairs(vanguardUnitList) do
			self._dataProxy:SpawnVanguard(unitData, ys.Battle.BattleConfig.FRIENDLY_CODE)
		end
	end
end

--- 单位死亡回调。
function BattleDebugCommand.onUnitDying(self, event)
	local uid = event.Dispatcher:GetUniqueID()

	self._dataProxy:KillUnit(uid)
end

--- 单位即将死亡回调。计算死亡分数，若 Boss 死亡且没有其他 Boss 则清场。
function BattleDebugCommand.onWillDie(self, event)
	local unit = event.Dispatcher

	self._dataProxy:CalcBattleScoreWhenDead(unit)

	local hasBoss = self._dataProxy:IsThereBoss()

	if unit:IsBoss() and not hasBoss then
		self._dataProxy:KillAllEnemy()
	end
end

--- 玩家单位停机回调。
function BattleDebugCommand.onShutDownPlayer(self, event)
	local uid = event.Dispatcher:GetUniqueID()

	self._dataProxy:ShutdownPlayerUnit(uid)
end
