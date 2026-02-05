ys = ys or {}

local ys = ys
local BattleBuffAntiSubVigilance = class("BattleBuffAntiSubVigilance", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAntiSubVigilance = BattleBuffAntiSubVigilance
BattleBuffAntiSubVigilance.__name = "BattleBuffAntiSubVigilance"

function BattleBuffAntiSubVigilance.Ctor(self, effectData)
	BattleBuffAntiSubVigilance.super.Ctor(self, effectData)
end

function BattleBuffAntiSubVigilance.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._vigilantRange = arg_list.vigilanceRange
	self._sonarRange = arg_list.sonarRange
	self._sonarFrequency = arg_list.sonarFrequency
end

function BattleBuffAntiSubVigilance.onAttach(self, owner)
	self._vigilantUnit = owner
	self._vigilantState = owner:InitAntiSubState(self._sonarRange, self._sonarFrequency)

	local checkArgs = self:getTargetList(self._vigilantUnit, "TargetHarmNearest", {
		range = 200
	})

	self._vigilantState:InitCheck(#checkArgs)

	self._sonarCheckTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime()
end

function BattleBuffAntiSubVigilance.onUpdate(self)
	if #self:getTargetList(self._vigilantUnit, "TargetHarmNearest", {
		range = self._vigilantRange
	}) > 0 then
		self._vigilantState:VigilantAreaEngage()
	end

	local var_4_0 = #self:getTargetList(self._vigilantUnit, "TargetHarmNearest", {
		range = 200
	})
	local targetList = #self:getTargetList(self._vigilantUnit, {
		"TargetAllFoe",
		"TargetHarmNearest",
		"TargetDiveState"
	}, {
		range = self._sonarRange
	})

	self._vigilantState:Update(var_4_0, targetList)

	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	if currentTime - self._sonarCheckTimeStamp >= self._sonarFrequency then
		self._vigilantState:SonarDetect(targetList)

		self._sonarCheckTimeStamp = currentTime
	end
end

function BattleBuffAntiSubVigilance.onAntiSubHateChain(self)
	self._vigilantState:HateChain()
end

function BattleBuffAntiSubVigilance.onTeammateShipDying(self, owner, buff, args)
	self._vigilantState:MineExplode()
end

function BattleBuffAntiSubVigilance.onSubmarinFreeDive(self, owner, buff, args)
	return
end

function BattleBuffAntiSubVigilance.onSubmarinFreeFloat(self, owner, buff, args)
	self._vigilantState:SubmarineFloat()
end
