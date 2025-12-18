ys = ys or {}

local ys = ys
local pg = pg

ys.MVC = ys.MVC or {}
ys.MVC.Facade = singletonClass("MVC.Facade")
ys.MVC.Facade.__name = "MVC.Facade"

function ys.MVC.Facade.Ctor(self)
	self:Initialize()
end

function ys.MVC.Facade.AddDataProxy(self, dataProxy)
	assert(dataProxy.__name ~= nil and type(dataProxy.__name) == "string", self.__name .. ".AddDataProxy: dataProxy.__name expected a string value")
	assert(self._proxyList[dataProxy.__name] == nil, self.__name .. ".AddDataProxy: same dataProxy exist")

	dataProxy._state = self

	dataProxy:ActiveProxy()

	self._proxyList[dataProxy.__name] = dataProxy

	return dataProxy
end

function ys.MVC.Facade.AddMediator(self, mediator)
	if mediator.__name == nil or type(mediator.__name) ~= "string" then
		assert(false, self.__name .. ".AddMediator: mediator.__name expected a string value")
	end

	assert(self._mediatorList[mediator.__name] == nil, self.__name .. ".AddMediator: same mediator exist")

	self._mediatorList[mediator.__name] = mediator
	mediator._state = self

	mediator:Initialize()

	return mediator
end

function ys.MVC.Facade.AddCommand(self, command)
	if command.__name == nil or type(command.__name) ~= "string" then
		assert(false, self.__name .. ".AddCommand: command.__name expected a string value")
	end

	assert(self._commandList[command.__name] == nil, self.__name .. ".AddCommand: same command exist")

	self._commandList[command.__name] = command
	command._state = self

	command:Initialize()

	return command
end

function ys.MVC.Facade.GetProxyByName(self, proxyName)
	assert(type(proxyName) == "string", self.__name .. ".GetProxyByName: expect a string value")

	return self._proxyList[proxyName]
end

function ys.MVC.Facade.GetMediatorByName(self, mediatorName)
	assert(type(mediatorName) == "string", self.__name .. ".GetMediatorByName: expect a string value")

	return self._mediatorList[mediatorName]
end

function ys.MVC.Facade.GetCommandByName(self, commandName)
	assert(type(commandName) == "string", self.__name .. ".GetCommandByName: expect a string value")

	return self._commandList[commandName]
end

function ys.MVC.Facade.RemoveMediator(self, mediator)
	if type(mediator) == "string" then
		mediator = self._mediatorList[mediator]
	end

	assert(mediator ~= nil, self.__name .. ".RemoveMediator: try to remove a nil mediator")
	mediator:Dispose()

	self._mediatorList[mediator.__name] = nil
end

function ys.MVC.Facade.RemoveCommand(self, command)
	if type(command) == "string" then
		command = self._commandList[command]
	end

	assert(command ~= nil, self.__name .. ".RemoveCommand: try to remove a nil command")
	command:Dispose()

	self._commandList[command.__name] = nil
end

function ys.MVC.Facade.RemoveProxy(self, proxy)
	if type(proxy) == "string" then
		proxy = self._proxyList[proxy]
	end

	assert(proxy ~= nil, self.__name .. ".RemoveProxy: try to remove a nil proxy")
	proxy:DeactiveProxy()

	self._proxyList[proxy.__name] = nil
end

function ys.MVC.Facade.Initialize(self)
	self._proxyList = {}
	self._commandList = {}
	self._mediatorList = {}
end

function ys.MVC.Facade.Active(self)
	if not self._isPause then
		return
	end

	self._isPause = false

	pg.TimeMgr.GetInstance():ResumeBattleTimer()
end

function ys.MVC.Facade.Deactive(self)
	if self._isPause then
		return
	end

	self._isPause = true

	pg.TimeMgr.GetInstance():PauseBattleTimer()
end

function ys.MVC.Facade.ActiveEscape(self)
	self._escapeAITimer = pg.TimeMgr.GetInstance():AddTimer("escapeTimer", 0, ys.Battle.BattleConfig.viewInterval, function()
		self:escapeUpdate()
	end)
end

function ys.MVC.Facade.DeactiveEscape(self)
	pg.TimeMgr.GetInstance():RemoveTimer(self._escapeAITimer)
end

function ys.MVC.Facade.RemoveAllTimer(self)
	pg.TimeMgr.GetInstance():RemoveAllBattleTimer()

	self._calcTimer = nil
	self._AITimer = nil
end

function ys.MVC.Facade.ResetTimer(self)
	local timeMgr = pg.TimeMgr.GetInstance()

	timeMgr:ResetCombatTime()
	timeMgr:RemoveBattleTimer(self._calcTimer)
	timeMgr:RemoveBattleTimer(self._AITimer)
	-- note: 每帧update->proxy update + command update
	self._calcTimer = timeMgr:AddBattleTimer("calcTimer", -1, ys.Battle.BattleConfig.calcInterval, function()
		self:calcUpdate()
	end)
end

function ys.MVC.Facade.ActiveAutoComponentTimer(self)
	-- 每ai帧(0.1s) update一次auto component
	-- 对应BattleDataProxy:UpdateAutoComponent
	self._AITimer = pg.TimeMgr.GetInstance():AddBattleTimer("aiTimer", -1, ys.Battle.BattleConfig.AIInterval, function()
		self:aiUpdate()
	end)
end

function ys.MVC.Facade.calcUpdate(self)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	for _, proxy in pairs(self._proxyList) do
		proxy:Update(currentTime)
	end

	for _, command in pairs(self._commandList) do
		command:Update(currentTime)
	end
end
-- note: aiUpdate对应BattleDataProxy:UpdateAutoComponent
function ys.MVC.Facade.aiUpdate(self)
	self:GetProxyByName(ys.Battle.BattleDataProxy.__name):UpdateAutoComponent(pg.TimeMgr.GetInstance():GetCombatTime())
end

function ys.MVC.Facade.escapeUpdate(self)
	local battleDataProxy = self:GetProxyByName(ys.Battle.BattleDataProxy.__name)
	local currentTIme = pg.TimeMgr.GetInstance():GetCombatTime()

	battleDataProxy:UpdateEscapeOnly(currentTIme)
	self:GetMediatorByName(ys.Battle.BattleSceneMediator.__name):UpdateEscapeOnly(currentTIme)
end
