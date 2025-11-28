ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleEvent = ys.Battle.BattleEvent
local BattleDALCollabSingleDungeonCommand = class("BattleDALCollabSingleDungeonCommand", ys.Battle.BattleSingleDungeonCommand)

ys.Battle.BattleDALCollabSingleDungeonCommand = BattleDALCollabSingleDungeonCommand
BattleDALCollabSingleDungeonCommand.__name = "BattleDALCollabSingleDungeonCommand"

function BattleDALCollabSingleDungeonCommand.Ctor(self)
	BattleDALCollabSingleDungeonCommand.super.Ctor(self)
end

function BattleDALCollabSingleDungeonCommand.DoPrologue(self)
	pg.UIMgr.GetInstance():Marching()

	local function defaultPrologue()
		self._uiMediator:OpeningEffect(function()
			self._uiMediator:ShowAutoBtn()
			self._uiMediator:ShowTimer()
			self._state:GetCommandByName(ys.Battle.BattleControllerWeaponCommand.__name):TryAutoSub()
			self._state:ChangeState(ys.Battle.BattleState.BATTLE_STATE_FIGHT)
			self._waveUpdater:Start()

			if self._dataProxy:GetInitData().hideAllButtons then
				self._dataProxy:DispatchEvent(ys.Event.New(ys.Battle.BattleEvent.HIDE_INTERACTABLE_BUTTONS, {
					isActive = false
				}))
			end
		end)
		self._dataProxy:GetFleetByIFF(ys.Battle.BattleConfig.FRIENDLY_CODE):FleetWarcry()
		self._dataProxy:InitAllFleetUnitsWeaponCD()
		self._dataProxy:TirggerBattleStartBuffs()
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._shiftTimer)

		self._shiftTimer = nil
	end

	local function _DALPrologue()
		local _DALAidBuffIDs = self._dataProxy:GetInitData().DALAidBuffIDs
		local buff

		for _, buffID in ipairs(_DALAidBuffIDs) do
			buff = ys.Battle.BattleBuffUnit.New(buffID, 1)
		end

		if buff then
			local fleetList = self._dataProxy:GetFleetList()

			for _, fleet in pairs(fleetList) do
				local allShips = fleet:GetUnitList()
				local flagShip = fleet:GetMainList()[1]

				for _, ship in ipairs(allShips) do
					if ship == flagShip then
						ship:AddBuff(buff)
						ship:TriggerBuff(ys.Battle.BattleConst.BuffEffectType.ON_DAL_COLLAB_FLAG_SHIP)
					end
				end
			end

			self._shiftTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", -1, 2, defaultPrologue, true)
		else
			defaultPrologue()
		end
	end

	self._uiMediator:SeaSurfaceShift(45, 0, nil, _DALPrologue)
end
