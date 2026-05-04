ys = ys or {}

-- 战斗Command基类，所有具体战斗模式的Command都继承自此类
-- 负责绑定DataProxy、InitProtocol和InitBattleEvent
local ys = ys

ys.Battle.BattleCommand = class("BattleCommand", ys.MVC.Command)
ys.Battle.BattleCommand.__name = "BattleCommand"

--- 构造函数
--- @param self BattleCommand
function ys.Battle.BattleCommand.Ctor(self)
	ys.Battle.BattleCommand.super.Ctor(self)
end

--- 初始化：绑定DataProxy并调用子类的InitProtocol和InitBattleEvent
--- @param self BattleCommand
function ys.Battle.BattleCommand.Initialize(self)
	ys.Battle.BattleCommand.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)

	self:InitProtocol()
	self:InitBattleEvent()
end

--- 激活战斗状态机，正式开始战斗
--- @param self BattleCommand
function ys.Battle.BattleCommand.StartBattle(self)
	self._state:Active()
end

--- 初始化通信协议（子类覆盖）
--- @param self BattleCommand
function ys.Battle.BattleCommand.InitProtocol(self)
	return
end

--- 初始化战斗事件监听（子类覆盖）
--- @param self BattleCommand
function ys.Battle.BattleCommand.InitBattleEvent(self)
	return
end
